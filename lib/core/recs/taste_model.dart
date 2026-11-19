// Taste-aware recommendations: turns listening signals into per-artist
// affinity, picks Deezer radio seeds from it and ranks the radio tracks.
//
// Pure Dart with no I/O, so it can be unit-tested and scored offline
// (test/recs/). recommendationsProvider gathers the signals and fetches the
// radios; everything that decides *what* to recommend lives here.
import 'dart:math' as math;

import '../models/recommended_track.dart';
import '../utils/title_normalize.dart';

/// One play from the history. [skipped] is true when the song was left in
/// the first 30 seconds.
class ListenEvent {
  final String artist;
  final String title;
  final String? genre;
  final DateTime at;
  final bool skipped;

  const ListenEvent({
    required this.artist,
    required this.title,
    required this.at,
    this.genre,
    this.skipped = false,
  });
}

/// A liked song (library star or liked Deezer track).
class LikedTrack {
  final String artist;
  final String title;
  final String? genre;
  const LikedTrack({required this.artist, required this.title, this.genre});
}

/// Everything the model learns from. Artist keys are as written; the model
/// normalizes them.
class TasteSignals {
  final List<ListenEvent> history;
  final List<LikedTrack> likes;

  /// Navidrome play counts summed per artist (all clients).
  final Map<String, int> serverPlaysByArtist;

  /// Genre per artist from the library, for history rows that lack one.
  final Map<String, String> genreByArtist;

  /// "Not interested: this song", as [keyFor] keys.
  final Set<String> dismissedTracks;

  /// "Not interested: this artist".
  final Set<String> dismissedArtists;

  /// Count of dismissed songs per artist (song-level hides).
  final Map<String, int> dismissalsByArtist;

  /// "More like this" taps per artist.
  final Map<String, int> moreLikeThis;

  /// How many times each track ([keyFor] key) was shown on Home without
  /// being played.
  final Map<String, int> impressions;

  /// Tracks already in the library ([keyFor] keys); never recommended.
  final Set<String> ownedTracks;

  const TasteSignals({
    this.history = const [],
    this.likes = const [],
    this.serverPlaysByArtist = const {},
    this.genreByArtist = const {},
    this.dismissedTracks = const {},
    this.dismissedArtists = const {},
    this.dismissalsByArtist = const {},
    this.moreLikeThis = const {},
    this.impressions = const {},
    this.ownedTracks = const {},
  });
}

/// Weights of the model. Defaults are what the app ships; the offline
/// evaluation tunes against them.
class TasteWeights {
  final double like;
  final double listen;
  final double skip;
  final double halfLifeDays;
  final double moreLikeThis;
  final double dismissal;
  final double genreBoost;
  final double dismissedArtistPenalty;
  final double fatigue;
  final int fatigueFreeShows;
  final double knownArtistBonus;
  final double dislikedArtistFactor;

  /// Boost for artists the user has never played or liked: how adventurous
  /// the list is (the Discovery slider).
  final double discovery;

  /// Sampling sharpness: 1 = proportional to score, higher = greedier.
  final double sharpness;

  /// Use skip flags. Off reproduces what the app can do before it records
  /// listen length.
  final bool useSkips;

  const TasteWeights({
    this.like = 5,
    this.listen = 1,
    this.skip = 0.75,
    this.halfLifeDays = 30,
    this.moreLikeThis = 2,
    this.dismissal = 1.5,
    this.genreBoost = 0.5,
    this.dismissedArtistPenalty = 0.5,
    this.fatigue = 0.6,
    this.fatigueFreeShows = 2,
    this.knownArtistBonus = 0.5,
    this.dislikedArtistFactor = 0.3,
    this.discovery = 0.5,
    this.sharpness = 2,
    this.useSkips = true,
  });

  /// Throws [ArgumentError] for a weight that would make scores meaningless
  /// (negative, NaN, infinite) instead of letting it skew every list.
  void validate() {
    final named = {
      'like': like, 'listen': listen, 'skip': skip,
      'halfLifeDays': halfLifeDays, 'moreLikeThis': moreLikeThis,
      'dismissal': dismissal, 'genreBoost': genreBoost,
      'dismissedArtistPenalty': dismissedArtistPenalty, 'fatigue': fatigue,
      'knownArtistBonus': knownArtistBonus,
      'dislikedArtistFactor': dislikedArtistFactor, 'discovery': discovery,
      'sharpness': sharpness,
    };
    named.forEach((name, v) {
      if (!v.isFinite || v < 0) {
        throw ArgumentError.value(v, name, 'must be a finite number ≥ 0');
      }
    });
    if (halfLifeDays == 0) {
      throw ArgumentError.value(halfLifeDays, 'halfLifeDays', 'must be > 0');
    }
    if (sharpness == 0) {
      throw ArgumentError.value(sharpness, 'sharpness', 'must be > 0');
    }
    if (fatigueFreeShows < 0) {
      throw ArgumentError.value(fatigueFreeShows, 'fatigueFreeShows');
    }
  }
}

/// Per-artist affinity and per-genre share of the user's taste.
class TasteProfile {
  /// Normalized artist → affinity (can be negative).
  final Map<String, double> affinity;

  /// Normalized artist → display name, for reason labels.
  final Map<String, String> displayName;

  /// Lower-cased genre → share of positive affinity (sums to 1).
  final Map<String, double> genreShare;

  /// Artists played in the last 7 days, most recent first (normalized).
  final List<String> recentArtists;

  /// Artists with a liked track, most liked first (normalized).
  final List<String> likedArtists;

  const TasteProfile({
    required this.affinity,
    required this.displayName,
    required this.genreShare,
    required this.recentArtists,
    required this.likedArtists,
  });

  double affinityOf(String artist) => affinity[normalize(artist)] ?? 0;

  double get maxAffinity =>
      affinity.values.fold<double>(0, (m, v) => v > m ? v : m);

  static TasteProfile build(
    TasteSignals s, {
    required DateTime now,
    TasteWeights w = const TasteWeights(),
  }) {
    w.validate();
    final aff = <String, double>{};
    final names = <String, String>{};
    final genreOf = <String, String>{};
    void add(String artist, double v) {
      final k = normalize(artist);
      if (k.isEmpty) return;
      names.putIfAbsent(k, () => artist);
      aff[k] = (aff[k] ?? 0) + v;
    }

    s.genreByArtist.forEach((a, g) => genreOf[normalize(a)] = g.toLowerCase());

    final likeCount = <String, int>{};
    for (final l in s.likes) {
      add(l.artist, w.like);
      final k = normalize(l.artist);
      likeCount[k] = (likeCount[k] ?? 0) + 1;
      if (l.genre != null) genreOf.putIfAbsent(k, () => l.genre!.toLowerCase());
    }
    s.serverPlaysByArtist.forEach((a, n) {
      if (n > 0) add(a, math.log(1 + n) / math.ln2);
    });
    final recent = <String>[];
    final weekAgo = now.subtract(const Duration(days: 7));
    final sorted = [...s.history]..sort((a, b) => b.at.compareTo(a.at));
    for (final e in sorted) {
      final ageDays = now.difference(e.at).inMinutes / (60 * 24);
      final decay = math.pow(0.5, ageDays / w.halfLifeDays).toDouble();
      final skipped = w.useSkips && e.skipped;
      add(e.artist, decay * (skipped ? -w.skip : w.listen));
      final k = normalize(e.artist);
      if (e.genre != null) genreOf.putIfAbsent(k, () => e.genre!.toLowerCase());
      if (!skipped && e.at.isAfter(weekAgo) && !recent.contains(k)) {
        recent.add(k);
      }
    }
    s.moreLikeThis.forEach((a, n) => add(a, w.moreLikeThis * n));
    s.dismissalsByArtist.forEach((a, n) => add(a, -w.dismissal * n));
    for (final a in s.dismissedArtists) {
      aff[normalize(a)] = -1e6;
    }

    final genreTotals = <String, double>{};
    var total = 0.0;
    aff.forEach((k, v) {
      final g = genreOf[k];
      if (g == null || v <= 0) return;
      genreTotals[g] = (genreTotals[g] ?? 0) + v;
      total += v;
    });
    final share = {
      for (final e in genreTotals.entries) e.key: total == 0 ? 0.0 : e.value / total
    };
    final liked = likeCount.keys.toList()
      ..sort((a, b) => likeCount[b]!.compareTo(likeCount[a]!));

    return TasteProfile(
      affinity: aff,
      displayName: names,
      genreShare: share,
      recentArtists: recent.where((k) => (aff[k] ?? 0) > 0).toList(),
      likedArtists: liked.where((k) => (aff[k] ?? 0) > 0).toList(),
    );
  }
}

/// Why a seed was picked; shown on the card as the reason.
enum SeedReason { topArtist, recent, liked }

class TasteSeed {
  /// Display name of the artist.
  final String artist;
  final SeedReason reason;
  final double affinity;
  const TasteSeed(this.artist, this.reason, this.affinity);
}

/// Picks up to [count] seed artists: half drawn from top affinity (weighted
/// random, so refreshes vary), a quarter from the last week, a quarter from
/// likes. Artists with zero or negative affinity never seed.
List<TasteSeed> pickSeeds(
  TasteProfile p,
  math.Random rng, {
  int count = 8,
}) {
  final picked = <String, TasteSeed>{};
  void take(String k, SeedReason r) {
    if (picked.length >= count || picked.containsKey(k)) return;
    final a = p.affinity[k] ?? 0;
    if (a <= 0) return;
    picked[k] = TasteSeed(p.displayName[k] ?? k, r, a);
  }

  List<String> weightedDraw(List<String> pool, int n) {
    final remaining = [...pool];
    final out = <String>[];
    while (out.length < n && remaining.isNotEmpty) {
      final weights = [for (final k in remaining) math.max(0.0, p.affinity[k] ?? 0)];
      final sum = weights.fold<double>(0, (a, b) => a + b);
      if (sum <= 0) break;
      var r = rng.nextDouble() * sum;
      var i = 0;
      for (; i < remaining.length - 1; i++) {
        r -= weights[i];
        if (r <= 0) break;
      }
      out.add(remaining.removeAt(i));
    }
    return out;
  }

  final positive = p.affinity.keys.where((k) => p.affinity[k]! > 0).toList();
  final quarter = math.max(1, count ~/ 4);
  for (final k in weightedDraw(p.likedArtists, quarter)) {
    take(k, SeedReason.liked);
  }
  for (final k in weightedDraw(p.recentArtists.take(12).toList(), quarter)) {
    take(k, SeedReason.recent);
  }
  final rest = positive.where((k) => !picked.containsKey(k)).toList();
  for (final k in weightedDraw(rest, count - picked.length)) {
    take(k, SeedReason.topArtist);
  }
  return picked.values.toList();
}

/// A ranked recommendation with the seed that contributed most.
class ScoredTrack {
  final RecommendedTrack track;
  final double score;
  final TasteSeed because;
  const ScoredTrack(this.track, this.score, this.because);
}

/// Ranks the radio tracks of each seed and picks [limit] of them, at most
/// [perArtist] per artist. Owned, dismissed and dismissed-artist tracks are
/// dropped. Sampling is weighted by score so refreshes vary.
List<ScoredTrack> rankCandidates(
  Map<TasteSeed, List<RecommendedTrack>> radios,
  TasteProfile p,
  TasteSignals s,
  math.Random rng, {
  TasteWeights w = const TasteWeights(),
  int limit = 30,
  int perArtist = 2,
  double maxSeedShare = 0.3,
}) {
  final maxAff = p.maxAffinity;
  final norm = maxAff <= 0 ? 1.0 : maxAff;
  final dismissedArtists = {for (final a in s.dismissedArtists) normalize(a)};
  final dismissalsByArtist = {
    for (final e in s.dismissalsByArtist.entries) normalize(e.key): e.value
  };

  final byKey = <String, ({RecommendedTrack t, double base, TasteSeed best})>{};
  radios.forEach((seed, tracks) {
    final contrib = seed.affinity / norm;
    for (final t in tracks) {
      final key = keyFor(t.title, t.artist);
      final prev = byKey[key];
      if (prev == null) {
        byKey[key] = (t: t, base: contrib, best: seed);
      } else {
        byKey[key] = (
          t: prev.t,
          base: prev.base + contrib,
          best: contrib > prev.best.affinity / norm ? seed : prev.best,
        );
      }
    }
  });

  final scored = <ScoredTrack>[];
  byKey.forEach((key, c) {
    if (s.ownedTracks.contains(key) || s.dismissedTracks.contains(key)) return;
    final artist = normalize(c.t.artist);
    if (dismissedArtists.contains(artist)) return;
    var score = c.base;
    final g = c.t.genre?.toLowerCase();
    if (g != null) score *= 1 + w.genreBoost * (p.genreShare[g] ?? 0);
    score *= math.pow(w.dismissedArtistPenalty, dismissalsByArtist[artist] ?? 0);
    final shows = s.impressions[key] ?? 0;
    if (shows > w.fatigueFreeShows) {
      score *= math.pow(w.fatigue, shows - w.fatigueFreeShows);
    }
    final own = p.affinity[artist] ?? 0;
    if (own > 0) score += w.knownArtistBonus * own / norm;
    if (own < 0) score *= w.dislikedArtistFactor;
    if (!p.affinity.containsKey(artist)) score *= 1 + w.discovery;
    if (!score.isFinite) {
      // A bad weight or affinity, not a property of the track: fail loudly
      // instead of quietly dropping it.
      throw StateError('Recommendation score for "${c.t.title}" by '
          '${c.t.artist} is $score (seed ${c.best.artist}, '
          'affinity ${c.best.affinity})');
    }
    if (score > 0) scored.add(ScoredTrack(c.t, score, c.best));
  });

  // Weighted sampling without replacement (Efraimidis–Spirakis keys).
  final keyed = [
    for (final t in scored)
      (t, math.pow(rng.nextDouble(), 1 / math.pow(t.score, w.sharpness)))
  ]..sort((a, b) => b.$2.compareTo(a.$2));

  // No single seed may fill more than [maxSeedShare] of the list: one
  // strongly liked artist would otherwise crowd out everything else (seen
  // on a real library with a single liked song). Tracks over the cap are
  // used only if the list can't be filled otherwise.
  final seedCap = math.max(1, (limit * maxSeedShare).ceil());
  final perArtistCount = <String, int>{};
  final perSeedCount = <TasteSeed, int>{};
  final families = <String>{};
  final out = <ScoredTrack>[];
  final overflow = <ScoredTrack>[];
  for (final (t, _) in keyed) {
    if (out.length >= limit) break;
    if (!families.add(songFamily(t.track.title))) continue;
    final a = normalize(t.track.artist);
    final n = perArtistCount[a] ?? 0;
    if (n >= perArtist) continue;
    if ((perSeedCount[t.because] ?? 0) >= seedCap) {
      overflow.add(t);
      continue;
    }
    perArtistCount[a] = n + 1;
    perSeedCount[t.because] = (perSeedCount[t.because] ?? 0) + 1;
    out.add(t);
  }
  for (final t in overflow) {
    if (out.length >= limit) break;
    final a = normalize(t.track.artist);
    final n = perArtistCount[a] ?? 0;
    if (n >= perArtist) continue;
    perArtistCount[a] = n + 1;
    out.add(t);
  }
  return out;
}

final _versionWords = RegExp(
    r'\b(super|ultra|mega|extremely|very|slowed|slow|sped|speed|up|reverb|'
    r'reverbed|nightcore|hardtekk|hardstyle|jumpstyle|remix|edit|version|'
    r'phonk|bass ?boosted)\b');

/// The song behind a title, ignoring versions like "(Super Slowed)",
/// "- Sped Up" or "Hardtekk Remix", so the list doesn't carry the same song
/// twice in different edits or by different uploaders.
String songFamily(String title) {
  var s = title.toLowerCase().replaceAll(RegExp(r'[\(\[][^\)\]]*[\)\]]'), ' ');
  s = s.replaceAll(RegExp(r'\s+[-–—]\s+.*$'), ' ');
  s = s.replaceAll(_versionWords, ' ').replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ');
  s = s.trim();
  return s.isEmpty ? title.toLowerCase().trim() : s;
}

/// Why the taste model could not produce a list. Each has a message meant
/// for the user; the recommendations section shows it instead of an empty
/// or substitute list.
sealed class RecsFailure implements Exception {
  const RecsFailure();
  String get message;
  @override
  String toString() => message;
}

/// No artist has a positive score: nothing played, liked or kept yet.
class NoTasteYet extends RecsFailure {
  const NoTasteYet();
  @override
  String get message =>
      'Play or like a few songs — recommendations start from what you enjoy.';
}

/// Every seed's radio failed. [errors] maps seed artist → cause.
class AllRadiosFailed extends RecsFailure {
  final Map<String, Object> errors;
  const AllRadiosFailed(this.errors);
  @override
  String get message {
    final first = errors.values.first;
    return "Couldn't load recommendations from Deezer for any of "
        '${errors.length} artists: $first';
  }
}

/// Deezer answered for every seed but had no radio tracks for any of them.
class NoRadioTracks extends RecsFailure {
  final List<String> seeds;
  const NoRadioTracks(this.seeds);
  @override
  String get message => 'Deezer has no radio for ${seeds.join(', ')}. '
      'Play or like a few other artists and refresh.';
}

/// Radios came back, but every track was owned or hidden.
class NothingNew extends RecsFailure {
  final int candidates;
  const NothingNew(this.candidates);
  @override
  String get message => 'All $candidates suggestions were already in your '
      'library or hidden. Refresh for new ones.';
}

/// A finished list plus the seeds whose radio failed, so the UI can say
/// "2 of 8 artists couldn't be loaded" instead of hiding a partial result.
class RecommendationResult {
  final List<ScoredTrack> tracks;
  final List<TasteSeed> seeds;

  /// Seed artist → error, for radios that failed.
  final Map<String, Object> failedSeeds;

  const RecommendationResult(this.tracks, this.seeds, this.failedSeeds);
}

/// Runs the whole model: profile → seeds → radios → ranking. [radio] fetches
/// one artist's radio and throws on failure (it must not turn errors into an
/// empty list, or "Deezer is down" would look like "no music"). Throws a
/// [RecsFailure] when no list can be made; one failing seed only shows up in
/// [RecommendationResult.failedSeeds].
Future<RecommendationResult> recommend({
  required TasteSignals signals,
  required DateTime now,
  required Future<List<RecommendedTrack>> Function(TasteSeed seed) radio,
  required math.Random rng,
  TasteWeights weights = const TasteWeights(),
  int limit = 30,
}) async {
  final profile = TasteProfile.build(signals, now: now, w: weights);
  final seeds = pickSeeds(profile, rng);
  if (seeds.isEmpty) throw const NoTasteYet();

  final failed = <String, Object>{};
  final radios = <TasteSeed, List<RecommendedTrack>>{};
  await Future.wait(seeds.map((seed) async {
    try {
      radios[seed] = await radio(seed);
    } catch (e) {
      failed[seed.artist] = e;
    }
  }));
  if (failed.length == seeds.length) throw AllRadiosFailed(failed);
  final candidates = radios.values.fold<int>(0, (n, l) => n + l.length);
  if (candidates == 0) {
    throw NoRadioTracks([for (final s in radios.keys) s.artist]);
  }
  final tracks =
      rankCandidates(radios, profile, signals, rng, w: weights, limit: limit);
  if (tracks.isEmpty) throw NothingNew(candidates);
  return RecommendationResult(tracks, seeds, failed);
}

/// Short reason label for a recommendation card.
String reasonLabel(TasteSeed seed) => switch (seed.reason) {
      SeedReason.liked => 'You like ${seed.artist}',
      SeedReason.recent => 'You played ${seed.artist} this week',
      SeedReason.topArtist => 'Because you listen to ${seed.artist}',
    };
