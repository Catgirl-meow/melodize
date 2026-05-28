import 'dart:math';
import '../models/song.dart';
import 'bpm_estimator.dart';

// Expando caches normalized artist names outside Song to keep the class immutable.
final _normArtistExpando = Expando<String>('normArtist');
String _normArtist(Song s) => _normArtistExpando[s] ??= s.artist.trim().toLowerCase();

// DJ-aware smart shuffle with BPM/key/energy scoring and energy-curve planning.
//
// Tiers:
//   1 — real BPM, Camelot keys, energy (companion connected)
//   2 — real BPM from Deezer, no keys, genre-BPM energy
//   3 — genre-estimated BPM only, genre compatibility, arc

// In-memory cache for BPM, key, energy, and trailing silence.
class BpmCache {
  final Map<String, int> bpm; // songId → BPM
  final Map<String, String> key; // songId → Camelot key
  final Map<String, bool> isEstimated; // songId → whether BPM is estimated
  final Map<String, double> tailSilence; // songId → seconds of trailing silence
  final Map<String, double> energy; // songId → RMS energy (0.0–1.0)
  final Map<String, double> spectralCentroid; // songId → spectral centroid (brightness proxy)
  // Precomputed derived data for fast DJ scoring (no repeated regex/string ops).
  final Map<String, DjGroup> genreCache; // songId → DJ group
  final Map<String, ({int number, bool minor})?> parsedKeyCache; // songId → parsed Camelot key

  const BpmCache({
    this.bpm = const {},
    this.key = const {},
    this.isEstimated = const {},
    this.tailSilence = const {},
    this.energy = const {},
    this.spectralCentroid = const {},
    this.genreCache = const {},
    this.parsedKeyCache = const {},
  });

  int? bpmFor(Song song) => bpm[song.id];
  String? keyFor(Song song) => key[song.id];
  bool isEstimatedFor(Song song) => isEstimated[song.id] ?? false;
  double? tailSilenceFor(Song song) => tailSilence[song.id];
  double? energyFor(Song song) => energy[song.id];
  double? spectralCentroidFor(Song song) => spectralCentroid[song.id];

  DjGroup djGroupFor(Song song) => genreCache[song.id] ?? _classifyGenre(song.genre);

  ({int number, bool minor})? parsedKeyFor(Song song) => parsedKeyCache[song.id];

  /// Harmonic key distance between two songs (0 = same key, 99 = missing data).
  /// Falls back to parsing raw [key] strings if pre-computed [parsedKeyCache]
  /// is empty — useful for const test caches that only supply [key].
  int keyDistance(Song a, Song b) {
    final keyA = parsedKeyCache[a.id] ?? _parseRawKey(key[a.id]);
    final keyB = parsedKeyCache[b.id] ?? _parseRawKey(key[b.id]);
    return _camelotDistanceParsed(keyA, keyB);
  }
}  // Build a BPM cache. Falls back to genre-average estimates for songs
  // without real data and marks them so the algorithm uses wider tolerances.
BpmCache buildBpmCache(
  List<Song> songs, {
  Map<String, int>? knownBpm,
  Map<String, String>? knownKeys,
  Map<String, double>? knownEnergy,
  Map<String, double>? knownSpectralCentroid,
  Map<String, double>? knownTailSilence,
}) {
  final bpm = <String, int>{};
  final key = <String, String>{};
  final isEstimated = <String, bool>{};
  final energy = <String, double>{};
  final spectralCentroid = <String, double>{};
  final tailSilence = <String, double>{};
  final genreCache = <String, DjGroup>{};
  final parsedKeyCache = <String, ({int number, bool minor})?>{};

  for (final song in songs) {
    final real = knownBpm?[song.id];
    if (real != null && real > 0) {
      bpm[song.id] = real.clamp(40, 200);
      isEstimated[song.id] = false;
    } else if (song.bpm != null && song.bpm! > 0) {
      bpm[song.id] = song.bpm!.clamp(40, 200);
      isEstimated[song.id] = false;
    } else {
      final estimated = estimateBpm(song.genre);
      if (estimated != null) {
        bpm[song.id] = estimated;
        isEstimated[song.id] = true;
      }
    }

    final k = knownKeys?[song.id];
    if (k != null && k.isNotEmpty) key[song.id] = k;

    final e = knownEnergy?[song.id];
    if (e != null && e > 0) energy[song.id] = e;

    final sc = knownSpectralCentroid?[song.id];
    if (sc != null && sc > 0) spectralCentroid[song.id] = sc;

    final ts = knownTailSilence?[song.id];
    if (ts != null && ts > 0) tailSilence[song.id] = ts;

    // Precompute genre classification and parsed Camelot key once per song.
    genreCache[song.id] = _classifyGenre(song.genre);
    final keyVal = knownKeys?[song.id];
    if (keyVal != null && keyVal.isNotEmpty) {
      final match = RegExp(r'^(\d+)([AB])$').firstMatch(keyVal.trim().toUpperCase());
      if (match != null) {
        parsedKeyCache[song.id] = (
          number: int.parse(match[1]!),
          minor: match[2]! == 'A',
        );
      } else {
        parsedKeyCache[song.id] = null;
      }
    }
  }

  return BpmCache(
    bpm: bpm,
    key: key,
    isEstimated: isEstimated,
    energy: energy,
    spectralCentroid: spectralCentroid,
    tailSilence: tailSilence,
    genreCache: genreCache,
    parsedKeyCache: parsedKeyCache,
  );
}

// Cached RegExp so it's compiled once, not per call.
final _camelotKeyRegex = RegExp(r'^(\d+)([AB])$');

({int number, bool minor})? _parseRawKey(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final match = _camelotKeyRegex.firstMatch(raw.trim().toUpperCase());
  if (match == null) return null;
  return (number: int.parse(match[1]!), minor: match[2]! == 'A');
}

// Camelot wheel key compatibility. Adjacent positions are harmonically
// compatible. Distance 0 = same key, 1 = adjacent, 2 = two steps, etc.

int _camelotDistanceParsed(
  ({int number, bool minor})? a,
  ({int number, bool minor})? b,
) {
  if (a == null || b == null) return 99;
  if (a.number == b.number && a.minor == b.minor) return 0;
  // Same number, different mode → relative major/minor, compatible
  if (a.number == b.number) return 0;
  final diff = (a.number - b.number).abs();
  if (diff == 1 && a.minor == b.minor) return 1;
  if (diff == 1) return 2;
  final wheelDist = (a.number - b.number).abs() % 12;
  final wrapped = wheelDist > 6 ? 12 - wheelDist : wheelDist;
  if (wrapped == 1) return 1;
  if (wrapped <= 2) return 2;
  return wrapped * 2;
}

// DJ genre families. Ordered by typical set energy.

enum DjGroup { chill, organic, rock, pop, electronic, hipHop, heavy }

// Memoized genre classification. Called frequently during planning; capped
// at 500 entries to prevent unbounded growth.
final _genreClassificationCache = <String, DjGroup>{};
const _kMaxGenreCacheSize = 500;

DjGroup _classifyGenre(String? genre) {
  final g = (genre ?? '').toLowerCase().trim();
  if (g.isEmpty)    return DjGroup.rock; // default neutral
  final cached = _genreClassificationCache[g];
  if (cached != null) return cached;
  // Prevent unbounded growth from unusual genre strings.
  if (_genreClassificationCache.length >= _kMaxGenreCacheSize) {
    _genreClassificationCache.clear();
  }

  // Chill / ambient / downtempo / classical / acoustic / new age
  if (g.contains('ambient') ||
      g.contains('chill') ||
      g.contains('downtempo') ||
      g.contains('classical') ||
      g.contains('orchestral') ||
      g.contains('acoustic') ||
      g.contains('lofi') ||
      g.contains('new age') ||
      g.contains('lo-fi') ||
      g.contains('soundtrack')) {
    return DjGroup.chill;
  }

  // Organic: jazz, soul, funk, blues, r&b, bossa, reggae, gospel, folk
  if (g.contains('jazz') ||
      g.contains('soul') ||
      g.contains('funk') ||
      g.contains('blues') ||
      g.contains('bossa') ||
      g.contains('reggae') ||
      g.contains('gospel') ||
      g.contains('folk') ||
      g.contains('country') ||
      g.contains('bluegrass') ||
      g.contains('singer') ||
      g.contains('world')) {
    return DjGroup.organic;
  }

  // Heavy: metal, hard rock, punk, industrial, death, black, grind
  if (g.contains('metal') ||
      g.contains('hard rock') ||
      g.contains('punk') ||
      g.contains('death') ||
      g.contains('black') ||
      g.contains('grind') ||
      g.contains('industrial') ||
      g.contains('thrash') ||
      g.contains('doom') ||
      g.contains('scream')) {
    return DjGroup.heavy;
  }

  // Electronic / dance
  if (g.contains('electronic') ||
      g.contains('dance') ||
      g.contains('house') ||
      g.contains('techno') ||
      g.contains('trance') ||
      g.contains('dubstep') ||
      g.contains('drum') ||
      g.contains('dnb') ||
      g.contains('edm') ||
      g.contains('synth') ||
      g.contains('disco') ||
      g.contains('breakbeat') ||
      g.contains('garage')) {
    return DjGroup.electronic;
  }

  // Hip-hop / rap / trap
  if (g.contains('hip') ||
      g.contains('rap') ||
      g.contains('trap') ||
      g.contains('grime')) {
    return DjGroup.hipHop;
  }

  // Pop / dance-pop / k-pop / j-pop / r&b (modern)
  if (g.contains('pop') ||
      g.contains('k-pop') ||
      g.contains('j-pop') ||
      g.contains('r&b') ||
      g.contains('rnb')) {
    return DjGroup.pop;
  }

  // Rock / indie / alternative / prog / classic rock / latin / ska
     return DjGroup.rock;
}

/// Precomputed genre-transition score matrix (7×7 = 49 entries).
///
/// Derived from the original `_genreTransitionScore` logic:
///   same group          → 0.90
///   explicit natural    → 0.70
///   |index diff| ≤ 2     → 0.40
///   otherwise            → 0.15
///
/// Index by [a.index][b.index] for O(1) lookup.
const _genreScoreMatrix = <List<double>>[
  //                 chill organic rock  pop   electronic hipHop heavy
  /* chill */      [0.90, 0.70, 0.70, 0.15, 0.15,     0.15,  0.15],
  /* organic */    [0.70, 0.90, 0.70, 0.70, 0.15,     0.15,  0.15],
  /* rock */       [0.40, 0.70, 0.90, 0.70, 0.70,     0.15,  0.70],
  /* pop */        [0.15, 0.40, 0.70, 0.90, 0.70,     0.70,  0.15],
  /* electronic */ [0.15, 0.15, 0.70, 0.70, 0.90,     0.70,  0.70],
  /* hipHop */     [0.15, 0.15, 0.15, 0.70, 0.70,     0.90,  0.40],
  /* heavy */      [0.15, 0.15, 0.70, 0.15, 0.70,     0.40,  0.90],
];

/// O(1) genre transition score lookup.
double _genreTransitionScore(DjGroup a, DjGroup b) =>
    _genreScoreMatrix[a.index][b.index];

// ---------------------------------------------------------------------------
// DJ compatibility score: how well would a DJ mix song a → song b?  // 0.0–1.0 compatibility score for a → b. Higher = better mix.
  // Weights vary by tier: BPM, key, genre flow, energy.
double _djScore(Song a, Song b, BpmCache cache, int tier, int totalSongs) {
  // Require BOTH songs to have real BPM for tight beatmatching tolerances.
  // If either uses estimated (genre-guessed) BPM, fall back to wide table.
  final hasRealBpm = (!cache.isEstimatedFor(a) && cache.bpmFor(a) != null) &&
      (!cache.isEstimatedFor(b) && cache.bpmFor(b) != null);
  final hasKeys = cache.keyFor(a) != null && cache.keyFor(b) != null;
  final hasEnergy = cache.energyFor(a) != null && cache.energyFor(b) != null;

  // --- Weights adjust based on available data ---
  final hasSpectral = cache.spectralCentroidFor(a) != null &&
      cache.spectralCentroidFor(b) != null;

  double wBpm;
  double wKey;
  double wGenre;
  double wEnergy;
  double wSpectral;

  switch (tier) {
    case 1: // Full DJ
      wBpm = 0.30;
      wKey = hasKeys ? 0.20 : 0.0;
      wGenre = 0.25;
      wEnergy = hasEnergy ? 0.15 : 0.0;
      wSpectral = hasSpectral ? 0.10 : 0.0;
      break;
    case 2: // Partial DJ (Deezer BPM, no companion)
      wBpm = 0.30;
      wKey = 0.0;
      wGenre = 0.35;
      wEnergy = hasEnergy ? 0.10 : 0.0;
      wSpectral = 0.0;
      break;
    default: // Tier 3: Simple DJ (offline)
      wBpm = 0.25;
      wKey = 0.0;
      wGenre = 0.30;
      wEnergy = 0.0;
      wSpectral = 0.0;
      break;
  }

  // Normalize so active weights always sum to 1.0.
  final totalWeight = wBpm + wKey + wGenre + wEnergy + wSpectral;
  if (totalWeight > 0.0) {
    wBpm /= totalWeight;
    wKey /= totalWeight;
    wGenre /= totalWeight;
    wEnergy /= totalWeight;
    wSpectral /= totalWeight;
  }

  double score = 0.0;

  // --- BPM match ---
  final bpmA = cache.bpmFor(a);
  final bpmB = cache.bpmFor(b);
  if (bpmA != null && bpmB != null) {
    final ratio = bpmA > bpmB ? bpmA / bpmB : bpmB / bpmA;

    // Half/double time bonus (e.g. 70 BPM → 140 BPM is a natural beatmatch)
    final halfOrDouble =
        (ratio >= 1.90 && ratio <= 2.10) || (ratio >= 0.48 && ratio <= 0.52);

    double bpmScore;
    if (hasRealBpm) {
      if (ratio <= 1.03) {
        bpmScore = 1.0;
      } else if (halfOrDouble) {
        bpmScore = 0.9;
      } else if (ratio <= 1.08) {
        bpmScore = 0.8;
      } else if (ratio <= 1.15) {
        bpmScore = 0.5;
      } else if (ratio <= 1.25) {
        bpmScore = 0.2;
      } else {
        bpmScore = 0.0;
      }
    } else {
      // Estimated BPM — wider tolerances
      if (ratio <= 1.10) {
        bpmScore = 0.8;
      } else if (halfOrDouble) {
        bpmScore = 0.7;
      } else if (ratio <= 1.20) {
        bpmScore = 0.5;
      } else if (ratio <= 1.35) {
        bpmScore = 0.2;
      } else {
        bpmScore = 0.0;
      }
    }
    score += bpmScore * wBpm;
  } else if (wBpm > 0) {
    // Missing BPM — neutral contribution
    score += 0.3 * wBpm;
  }

  // --- Key compatibility (uses pre-parsed keys, no regex per call) ---
  if (hasKeys && wKey > 0) {
    final kd = cache.keyDistance(a, b);
    double keyScore = switch (kd) {
      0 => 1.0,
      1 => 0.9,
      2 => 0.7,
      3 => 0.4,
      5 || 7 => 0.3, // perfect fourth/fifth
      _ => 0.0,
    };

    // Energy-boost bonus: +2 Camelot steps with increasing energy
    // is a classic DJ energy boost technique (e.g. 5A → 7A).
    if (kd == 2 && hasEnergy) {
      final eA = cache.energyFor(a)!;
      final eB = cache.energyFor(b)!;
      if (eB > eA + 0.05) {
        keyScore = 0.85; // better than normal distance=2
      }
    }

    score += keyScore * wKey;
  }

  // --- Genre transition (uses precomputed DJ group from cache) ---
  final gScore = _genreTransitionScore(
      cache.djGroupFor(a), cache.djGroupFor(b));
  score += gScore * wGenre;

  // --- Energy proximity ---
  if (hasEnergy && wEnergy > 0) {
    final eA = cache.energyFor(a)!;
    final eB = cache.energyFor(b)!;
    final eDiff = (eA - eB).abs();
    final eScore = eDiff <= 0.10
        ? 1.0
        : eDiff <= 0.20
            ? 0.7
            : eDiff <= 0.35
                ? 0.3
                : 0.0;
    score += eScore * wEnergy;
  }

  // --- Spectral centroid (brightness / timbre matching) ---
  if (hasSpectral && wSpectral > 0) {
    final scA = cache.spectralCentroidFor(a)!;
    final scB = cache.spectralCentroidFor(b)!;
    final maxSc = max(scA, scB);
    final scDiff = maxSc > 0 ? (scA - scB).abs() / maxSc : 0.0;
    final scScore = scDiff <= 0.10
        ? 1.0
        : scDiff <= 0.25
            ? 0.7
            : scDiff <= 0.45
                ? 0.3
                : 0.0;
    score += scScore * wSpectral;
  }

  // --- Artist penalty ---
  if (totalSongs > 5 && _normArtist(a) == _normArtist(b)) {
    score *= 0.1;
  }

  // Safety: corrupted companion data may produce NaN / Infinity.
  if (score.isNaN || score.isInfinite) return 0.0;
  return score.clamp(0.0, 1.0);
}

// ---------------------------------------------------------------------------
// Energy tier assignment

const _kEnergyTiers = 5;

// Energy tier 0–4 (0 = lowest, 4 = highest).
int _assignEnergyTier(Song song, BpmCache cache) {
  // 1. Real energy data (companion)
  final energy = cache.energyFor(song);
  if (energy != null) {
    return (energy * _kEnergyTiers).clamp(0, _kEnergyTiers - 1).floor();
  }

  // 2. Real BPM → normalise to 0–1 → tier
  final bpm = cache.bpmFor(song);
  if (bpm != null && !cache.isEstimatedFor(song)) {
    return ((bpm.clamp(40, 220) - 40) / 180 * _kEnergyTiers)
        .clamp(0, _kEnergyTiers - 1)
        .floor();
  }

  // 3. Estimated BPM → normalise → tier (wider buckets)
  if (bpm != null) {
    return ((bpm.clamp(40, 220) - 40) / 180 * _kEnergyTiers)
        .clamp(0, _kEnergyTiers - 1)
        .floor();
  }

  // 4. Genre-default energy as fallback
  return switch (_classifyGenre(song.genre)) {
    DjGroup.chill => 0,
    DjGroup.organic => 1,
    DjGroup.rock => 2,
    DjGroup.pop => 2,
    DjGroup.electronic => 3,
    DjGroup.hipHop => 3,
    DjGroup.heavy => 4,
  };
}

// Order songs by DJ compatibility starting from the anchor song.
// [tier] controls which scoring components are active.
List<Song> orderSongs(List<Song> songs, int anchorIndex, BpmCache cache,
    {int seed = 0, int djTier = 3}) {
  // Input validation
  if (songs.isEmpty) return [];
  if (songs.length <= 1) return List.from(songs);
  final idx = anchorIndex.clamp(0, songs.length - 1);

  // Detect data quality and auto-select tier if not explicitly set
  final tier = _detectDjTier(songs, cache, djTier);

  final anchor = songs[idx];
  final upcoming = songs.sublist(idx + 1);
  if (upcoming.isEmpty) return List.from(songs);

  // Safety: if literally zero usable data, fall back to random shuffle
  final hasAnyBpm = songs.any((s) => cache.bpmFor(s) != null);
  if (!hasAnyBpm && songs.length > 1) {
    return _randomWithArtistSep(songs, idx, seed);
  }

  // Build the DJ path through upcoming songs
  final orderedUpcoming =
      _buildAndPolishDjArc(anchor, upcoming, cache, tier, songs.length, seed);

  return [...songs.sublist(0, idx + 1), ...orderedUpcoming];
}  // Auto-select tier based on available data quality.
  int _detectDjTier(List<Song> songs, BpmCache cache, int requestedTier) {
  if (requestedTier < 3) return requestedTier; // caller explicitly chose

  final total = songs.length;
  if (total == 0) return 3;

  final realBpmCount =
      songs.where((s) => cache.bpmFor(s) != null && !cache.isEstimatedFor(s)).length;
  final realKeyCount =
      songs.where((s) => cache.keyFor(s) != null).length;
  final realEnergyCount =
      songs.where((s) => cache.energyFor(s) != null).length;

  final bpmFraction = realBpmCount / total;
  final energyFraction = realEnergyCount / total;

  // Tier 1: ≥ 30 % have real BPM or real energy (companion connected)
  if (bpmFraction >= 0.3 || energyFraction >= 0.3) return 1;

  // Tier 2: ≥ 10 % have real BPM (Deezer data in playlist)
  if (bpmFraction >= 0.1 && realKeyCount == 0) return 2;
  if (bpmFraction >= 0.1) return 2;

  // Tier 3: offline / simple
  return 3;
}

// DJ path builder: energy-constrained nearest neighbor.

/// Build a DJ arc — pure energy-curve ordering without post-processing.
///
/// Returns the upcoming songs ordered by energy-tier sequence (warm-up →
/// peak → cool-down) using greedy nearest-neighbour selection. No adjacent
/// swap or artist-interleave passes are applied, so the result is the raw
/// arc shape and is fully deterministic for a given [seed].
///
/// This is public so tests can assert the pure arc before perturbations.
List<Song> buildDjArc(
  Song anchor,
  List<Song> upcoming,
  BpmCache cache,
  int tier,
  int totalSongs,
  int seed,
) {
  if (upcoming.isEmpty) return const [];

  final rng = Random(seed);

  // Assign energy tiers to all upcoming songs.
  final tierBuckets = List.generate(_kEnergyTiers, (_) => <Song>[]);
  for (final s in upcoming) {
    final t = _assignEnergyTier(s, cache);
    tierBuckets[t].add(s);
  }

  // Determine the arc tier sequence starting from anchor's tier.
  final anchorTier = _assignEnergyTier(anchor, cache);
  final arcSequence = _buildArcSequence(anchorTier);

  // Build the path greedily, cycling through the arc sequence until all
  // upcoming songs are placed. Distribute songs evenly across tiers so the
  // energy curve is perceptible across the entire set (not just first 5 songs).
  final result = <Song>[];
  // Use object identity (Set<Song>) instead of Set<String> so duplicate
  // song IDs in the queue don't cause an infinite loop or data loss.
  final visited = <Song>{};
  Song current = anchor;
  var songCount = upcoming.length;
  final songsPerTierStep = max(1, songCount ~/ arcSequence.length);

  while (songCount > 0) {
    for (final targetTier in arcSequence) {
      if (songCount <= 0) break;

      var placedThisStep = 0;
      while (placedThisStep < songsPerTierStep && songCount > 0) {
        // Collect candidates in the target tier (±1 if exhausted).
        List<Song> candidates = const [];
        for (int spread = 0; spread <= 2; spread++) {
          candidates = _candidatesInTier(
              tierBuckets, targetTier, spread, visited);
          if (candidates.isNotEmpty) break;
        }

        if (candidates.isEmpty) break;

        // Pick best-scoring candidate from current song. For large playlists,
        // avoid O(n log n) sorts on thousands of candidates by using reservoir
        // sampling to pick a random subset, then sorting only that subset.
        final maxCandidates = totalSongs > 500
            ? min(50, candidates.length)
            : candidates.length;
        if (maxCandidates < candidates.length) {
          // Reservoir sample: O(n) with one RNG call per extra element.
          final sample = candidates.sublist(0, maxCandidates);
          for (int i = maxCandidates; i < candidates.length; i++) {
            final j = rng.nextInt(i + 1);
            if (j < maxCandidates) {
              sample[j] = candidates[i];
            }
          }
          candidates = sample;

          final currBpm = cache.bpmFor(current);
          if (currBpm != null) {
            candidates.sort((a, b) {
              final da = (cache.bpmFor(a) ?? currBpm) - currBpm;
              final db = (cache.bpmFor(b) ?? currBpm) - currBpm;
              return da.abs().compareTo(db.abs());
            });
          } else {
            final currGroup = cache.djGroupFor(current);
            final groupOrder = DjGroup.values.toList();
            candidates.sort((a, b) {
              final da = (groupOrder.indexOf(cache.djGroupFor(a)) -
                      groupOrder.indexOf(currGroup))
                  .abs();
              final db = (groupOrder.indexOf(cache.djGroupFor(b)) -
                      groupOrder.indexOf(currGroup))
                  .abs();
              return da.compareTo(db);
            });
          }
        }

        // Score all candidates, then pick randomly from the top 3 weighted
        // by score.  This keeps DJ quality high while varying the order
        // across sessions — without it the same anchor produces the same arc.
        final scored = <({Song song, double score})>[];
        for (int i = 0; i < maxCandidates; i++) {
          final c = candidates[i];
          final s = _djScore(current, c, cache, tier, totalSongs);
          scored.add((song: c, score: s));
        }
        scored.sort((a, b) => b.score.compareTo(a.score));

        // If the best candidate is mediocre, search deeper for a better match.
        var topN = scored.take(3).toList();
        if (topN.isNotEmpty && topN.first.score < 0.5 && scored.length > 3) {
          topN = scored.take(5).toList();
        }
        if (topN.isEmpty) break;

        Song best;
        if (topN.length == 1) {
          best = topN.first.song;
        } else {
          final totalWeight = topN.fold<double>(0, (sum, e) => sum + e.score);
          // Safety: if every candidate scored 0.0, just pick the first one.
          if (totalWeight <= 0.0 || totalWeight.isNaN) {
            best = topN.first.song;
          } else {
            var roll = rng.nextDouble() * totalWeight;
            best = topN.first.song; // fallback
            for (final e in topN) {
              roll -= e.score;
              if (roll <= 0) {
                best = e.song;
                break;
              }
            }
          }
        }

        result.add(best);
        visited.add(best);
        // Remove best from its actual bucket (may differ from targetTier due to spread).
        for (final bucket in tierBuckets) {
          if (bucket.remove(best)) break;
        }
        current = best;
        placedThisStep++;
        songCount--;
      }
    }
  }

  return result;
}

/// Wraps [buildDjArc] and applies the polishing passes
/// (_adjacentSwap + _interleaveArtists).
List<Song> _buildAndPolishDjArc(
  Song anchor,
  List<Song> upcoming,
  BpmCache cache,
  int tier,
  int totalSongs,
  int seed,
) {
  final result = buildDjArc(anchor, upcoming, cache, tier, totalSongs, seed);
  final rng = Random(seed);
  result
    .._adjacentSwap(cache, tier, totalSongs, rng)
    .._interleaveArtists();
  return result;
}  // Warm-up → peak → cool-down arc sequence.
  List<int> _buildArcSequence(int anchorTier) {
  final seq = <int>[];
  // Up: anchor → 4
  for (int t = anchorTier; t < _kEnergyTiers; t++) {
    seq.add(t);
  }
  // Down: 3 → 0
  for (int t = _kEnergyTiers - 1; t >= 0; t--) {
    if (!seq.contains(t)) seq.add(t);
  }
  return seq;
}  // Unvisited songs from target tier, widening by [spread].
  List<Song> _candidatesInTier(
  List<List<Song>> buckets,
  int targetTier,
  int spread,
  Set<Song> visited,
) {
  final result = <Song>[];
  for (int t = targetTier - spread;
      t <= targetTier + spread;
      t++) {
    if (t < 0 || t >= _kEnergyTiers) continue;
    for (final s in buckets[t]) {
      if (!visited.contains(s)) result.add(s);
    }
  }
  return result;
}

// Adjacent-swap local search. Memoizes edge scores to avoid re-scoring
// the same pair within a pass.

extension _AdjacentSwap on List<Song> {
  void _adjacentSwap(
      BpmCache cache, int tier, int totalSongs, Random rng) {
    if (length < 3) return;
    const maxPasses = 3;
    for (int pass = 0; pass < maxPasses; pass++) {
      bool improved = false;
      // Precompute all edge scores for this pass.
      final edgeScores = List<double>.filled(length - 1, 0.0);
      for (int e = 0; e < length - 1; e++) {
        edgeScores[e] = _djScore(this[e], this[e + 1], cache, tier, totalSongs);
      }
      for (int i = 0; i < length - 1; i++) {
        final scoreBefore = _edgeSum(i, edgeScores);
        // Try swapping i and i+1
        final tmp = this[i];
        this[i] = this[i + 1];
        this[i + 1] = tmp;
        // Recompute only the three edges that changed.
        final scoreAfter = _edgeSumAfterSwap(i, edgeScores, cache, tier, totalSongs);
        if (scoreAfter > scoreBefore + 0.01) {
          improved = true;
          // Commit: update the memoized edge scores for the next iteration.
          _refreshEdges(i, edgeScores, cache, tier, totalSongs);
        } else {
          // Undo swap
          final tmp2 = this[i];
          this[i] = this[i + 1];
          this[i + 1] = tmp2;
        }
      }
      if (!improved) break;
    }
  }

  double _edgeSum(int i, List<double> edgeScores) {
    double total = 0;
    if (i > 0) total += edgeScores[i - 1];
    total += edgeScores[i];
    if (i < length - 2) total += edgeScores[i + 1];
    return total;
  }

  double _edgeSumAfterSwap(
    int i,
    List<double> edgeScores,
    BpmCache cache,
    int tier,
    int totalSongs,
  ) {
    double total = 0;
    if (i > 0) {
      total += _djScore(this[i - 1], this[i], cache, tier, totalSongs);
    }
    total += _djScore(this[i], this[i + 1], cache, tier, totalSongs);
    if (i < length - 2) {
      total += _djScore(this[i + 1], this[i + 2], cache, tier, totalSongs);
    }
    return total;
  }

  void _refreshEdges(
    int i,
    List<double> edgeScores,
    BpmCache cache,
    int tier,
    int totalSongs,
  ) {
    if (i > 0) {
      edgeScores[i - 1] = _djScore(this[i - 1], this[i], cache, tier, totalSongs);
    }
    edgeScores[i] = _djScore(this[i], this[i + 1], cache, tier, totalSongs);
    if (i < length - 2) {
      edgeScores[i + 1] = _djScore(this[i + 1], this[i + 2], cache, tier, totalSongs);
    }
  }
}

// Break up same-artist clusters.

extension _Interleave on List<Song> {
  void _interleaveArtists() {
    if (length < 3) return;
    // Precompute normalized artist names once.
    final norm = List<String>.generate(length, (i) => _normArtist(this[i]));
    for (int i = 1; i < length - 1; i++) {
      if (norm[i] == norm[i - 1] && norm[i] == norm[i + 1]) {
        // Triple same-artist cluster — swap middle with a later song
        for (int j = i + 2; j < length; j++) {
          if (norm[j] != norm[i] &&
              (i == 1 || norm[j] != norm[i - 1])) {
            final tmp = this[i];
            this[i] = this[j];
            this[j] = tmp;
            final tmpN = norm[i];
            norm[i] = norm[j];
            norm[j] = tmpN;
            break;
          }
        }
      }
    }
  }
}

// Fallback: random shuffle with artist separation.

List<Song> _randomWithArtistSep(List<Song> songs, int anchorIndex, int seed) {
  final anchor = songs[anchorIndex.clamp(0, songs.length - 1)];
  // Use object identity so duplicate song instances are preserved.
  final rest = songs.where((s) => s != anchor).toList();
  rest.shuffle(Random(seed));
  final result = [anchor, ...rest];
  result._interleaveArtists();
  return result;
}
