// A made-up music world for scoring recommendations offline: artists in
// genres, a Deezer-like artist radio, and simulated listeners whose true
// taste is known, so we can measure how close the recommendations get.
import 'dart:math' as math;

import 'package:melodize/core/models/recommended_track.dart';
import 'package:melodize/core/recs/taste_model.dart';
import 'package:melodize/core/utils/title_normalize.dart';

const genres = [
  'Rock', 'Metal', 'Electronic', 'Hip-Hop', 'Jazz', 'Pop', 'Folk', 'Classical'
];

class SimArtist {
  final String name;
  final int genre;
  final double popularity; // 0..1
  const SimArtist(this.name, this.genre, this.popularity);
  String get genreName => genres[genre];
}

/// Genres sit on a ring; neighbours share fans (Rock–Metal, Electronic–Pop…).
int genreDistance(int a, int b) {
  final d = (a - b).abs() % genres.length;
  return math.min(d, genres.length - d);
}

class SimWorld {
  static const artistsPerGenre = 25;
  static const tracksPerArtist = 12;
  final List<SimArtist> artists;
  final Map<String, SimArtist> byName;

  SimWorld._(this.artists)
      : byName = {for (final a in artists) a.name: a};

  factory SimWorld() {
    final rng = math.Random(7);
    final list = <SimArtist>[];
    for (var g = 0; g < genres.length; g++) {
      for (var i = 0; i < artistsPerGenre; i++) {
        list.add(SimArtist('${genres[g]} Artist ${i + 1}', g,
            math.pow(rng.nextDouble(), 2).toDouble()));
      }
    }
    return SimWorld._(list);
  }

  int deezerId(SimArtist a, int track) =>
      artists.indexOf(a) * 100 + track + 1;

  RecommendedTrack track(SimArtist a, int i) => RecommendedTrack(
        deezerId: deezerId(a, i),
        title: '${a.name} Song ${i + 1}',
        artist: a.name,
        album: '${a.name} Album',
        durationSeconds: 200,
        genre: a.genreName,
      );

  /// Like Deezer's artist radio: some of the artist's own songs, mostly
  /// same-genre artists (popular ones more often), some from neighbouring
  /// genres and a little noise. Deterministic per (artist, call).
  List<RecommendedTrack> radio(String artistName, int call, {int limit = 20}) {
    final seed = artists.firstWhere((a) => a.name == artistName);
    final rng = math.Random(seed.name.hashCode ^ (call * 7919));
    final out = <int, RecommendedTrack>{};
    var guard = 0;
    while (out.length < limit && guard++ < 500) {
      final r = rng.nextDouble();
      SimArtist a;
      if (r < 0.2) {
        a = seed;
      } else if (r < 0.75) {
        a = _pick(rng, (x) => x.genre == seed.genre && x != seed);
      } else if (r < 0.92) {
        a = _pick(rng, (x) => genreDistance(x.genre, seed.genre) == 1);
      } else {
        a = _pick(rng, (_) => true);
      }
      final t = track(a, rng.nextInt(tracksPerArtist));
      out[t.deezerId] = t;
    }
    return out.values.toList();
  }

  SimArtist _pick(math.Random rng, bool Function(SimArtist) where) {
    final pool = artists.where(where).toList();
    final weights = [for (final a in pool) 0.2 + a.popularity];
    final sum = weights.reduce((a, b) => a + b);
    var r = rng.nextDouble() * sum;
    for (var i = 0; i < pool.length; i++) {
      r -= weights[i];
      if (r <= 0) return pool[i];
    }
    return pool.last;
  }
}

/// A listener with a hidden true taste per artist in [-1, 1].
class Persona {
  final String name;
  final String description;

  /// Genre index → base preference.
  final Map<int, double> genreTaste;

  /// Specific artists loved (+) or disliked (−) beyond their genre.
  final Map<String, double> artistTaste;

  /// Generates this persona's starting history and likes.
  final void Function(Persona, SimWorld, SimState, math.Random) seedHistory;

  Persona(this.name, this.description, this.genreTaste, this.seedHistory,
      {this.artistTaste = const {}});

  double pref(SimArtist a) {
    final g = genreTaste[a.genre] ?? -0.2;
    final own = artistTaste[a.name];
    // Per-artist noise so not every artist in a liked genre is a hit.
    final noise = ((a.name.hashCode % 1000) / 1000 - 0.5) * 0.4;
    return (own ?? g + noise).clamp(-1.0, 1.0);
  }
}

/// What the app knows about a listener at a point in time.
class SimState {
  final now = DateTime(2026, 11, 19, 12);
  final history = <ListenEvent>[];
  final likes = <LikedTrack>[];
  final owned = <String>{};
  final dismissedTracks = <String>{};
  final dismissedArtists = <String>{};
  final dismissalsByArtist = <String, int>{};
  final impressions = <String, int>{};
  final serverPlays = <String, int>{};

  void play(SimArtist a, String title, DateTime at, bool skipped) {
    history.add(ListenEvent(
        artist: a.name, title: title, genre: a.genreName, at: at, skipped: skipped));
    owned.add(keyFor(title, a.name));
    if (!skipped) serverPlays[a.name] = (serverPlays[a.name] ?? 0) + 1;
  }

  TasteSignals signals() => TasteSignals(
        history: List.of(history),
        likes: List.of(likes),
        serverPlaysByArtist: Map.of(serverPlays),
        dismissedTracks: Set.of(dismissedTracks),
        dismissedArtists: Set.of(dismissedArtists),
        dismissalsByArtist: Map.of(dismissalsByArtist),
        impressions: Map.of(impressions),
        ownedTracks: Set.of(owned),
      );
}

double skipChance(double pref) => 1 / (1 + math.exp(4 * pref + 0.5));

/// Plays [n] songs spread over [days] days ending [endDaysAgo] days ago,
/// choosing artists by [weight].
void listen(
  Persona p,
  SimWorld w,
  SimState s,
  math.Random rng, {
  required int n,
  required double Function(SimArtist) weight,
  int days = 90,
  int endDaysAgo = 0,
}) {
  final pool = w.artists.where((a) => weight(a) > 0).toList();
  final weights = [for (final a in pool) weight(a)];
  final sum = weights.reduce((a, b) => a + b);
  for (var i = 0; i < n; i++) {
    var r = rng.nextDouble() * sum;
    var k = 0;
    for (; k < pool.length - 1; k++) {
      r -= weights[k];
      if (r <= 0) break;
    }
    final a = pool[k];
    final title = '${a.name} Song ${rng.nextInt(SimWorld.tracksPerArtist ~/ 2) + 1}';
    final at = s.now.subtract(Duration(
        minutes: ((endDaysAgo + rng.nextDouble() * days) * 24 * 60).round()));
    s.play(a, title, at, rng.nextDouble() < skipChance(p.pref(a)));
  }
}

/// Likes the persona's most-played well-loved songs.
void likeFavourites(Persona p, SimWorld w, SimState s, {int max = 15}) {
  final counts = <String, int>{};
  final artistOf = <String, SimArtist>{};
  for (final e in s.history.where((e) => !e.skipped)) {
    counts[e.title] = (counts[e.title] ?? 0) + 1;
    artistOf[e.title] = w.byName[e.artist]!;
  }
  final top = counts.keys.where((t) => p.pref(artistOf[t]!) > 0.5).toList()
    ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
  for (final t in top.take(max)) {
    final a = artistOf[t]!;
    s.likes.add(LikedTrack(artist: a.name, title: t, genre: a.genreName));
  }
}

List<Persona> personas() => [
      Persona(
        'Focused fan',
        'Loves rock and metal, three favourite bands on heavy rotation, '
            'dislikes electronic and hip-hop.',
        {0: 0.8, 1: 0.7, 2: -0.7, 3: -0.8, 5: -0.2, 6: 0.1},
        (p, w, s, rng) {
          final fav = ['Rock Artist 3', 'Metal Artist 5', 'Rock Artist 11'];
          listen(p, w, s, rng, n: 300, weight: (a) {
            if (fav.contains(a.name)) return 8;
            return (a.genre == 0 || a.genre == 1) ? 0.4 : 0;
          });
          likeFavourites(p, w, s);
        },
        artistTaste: {
          'Rock Artist 3': 1,
          'Metal Artist 5': 1,
          'Rock Artist 11': 0.95,
        },
      ),
      Persona(
        'Eclectic',
        'Mildly likes five genres, no strong dislikes.',
        {0: 0.4, 2: 0.45, 4: 0.5, 5: 0.4, 6: 0.45, 1: 0, 3: 0, 7: 0},
        (p, w, s, rng) {
          listen(p, w, s, rng,
              n: 250, weight: (a) => p.pref(a) > 0.2 ? 1 + a.popularity : 0.05);
          likeFavourites(p, w, s, max: 8);
        },
      ),
      Persona(
        'Skipper',
        'Loves jazz and folk, but half of what plays is a shared pop/hip-hop '
            'playlist that gets skipped.',
        {4: 0.8, 6: 0.7, 5: -0.6, 3: -0.7, 7: 0.3},
        (p, w, s, rng) {
          listen(p, w, s, rng,
              n: 150, weight: (a) => (a.genre == 4 || a.genre == 6) ? 1 : 0);
          listen(p, w, s, rng,
              n: 150, weight: (a) => (a.genre == 5 || a.genre == 3) ? 1 : 0);
          likeFavourites(p, w, s, max: 10);
        },
      ),
      Persona(
        'New listener',
        'Only a dozen plays, but liked eight electronic songs.',
        {2: 0.8, 5: 0.4, 0: -0.3, 1: -0.6},
        (p, w, s, rng) {
          listen(p, w, s, rng,
              n: 12, days: 5, weight: (a) => a.genre == 2 || a.genre == 5 ? 1 : 0);
          final rngLikes = math.Random(3);
          final electronic = w.artists.where((a) => a.genre == 2).toList();
          for (var i = 0; i < 8; i++) {
            final a = electronic[rngLikes.nextInt(electronic.length)];
            s.likes.add(LikedTrack(
                artist: a.name, title: '${a.name} Song 1', genre: a.genreName));
            s.owned.add(keyFor('${a.name} Song 1', a.name));
          }
        },
      ),
      Persona(
        'Changing taste',
        'Played lots of classical until two months ago, now into hip-hop.',
        {3: 0.8, 7: -0.1, 2: 0.2},
        (p, w, s, rng) {
          listen(p, w, s, rng,
              n: 250, days: 120, endDaysAgo: 60, weight: (a) => a.genre == 7 ? 1 : 0);
          listen(p, w, s, rng,
              n: 60, days: 40, weight: (a) => a.genre == 3 ? 1 : 0);
          likeFavourites(p, w, s, max: 6);
        },
      ),
    ];
