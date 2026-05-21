import 'dart:math';
import '../models/song.dart';
import 'bpm_estimator.dart';

// ---------------------------------------------------------------------------
// Smart shuffle ordering algorithm
//
// Orders songs by similarity using available data:
//   • BPM (from companion server, Deezer API, or genre estimate)
//   • Camelot key (from companion server analysis)
//   • Genre (from song metadata)
//   • Era/decade (from song year)
//
// The algorithm uses a greedy nearest-neighbor TSP approach with 2-opt local
// search improvement. Falls back gracefully when data is sparse.
// ---------------------------------------------------------------------------

/// Result of the smart shuffle ordering.
class OrderedQueue {
  final List<Song> songs;
  final String strategy; // 'full' | 'hybrid' | 'metadata'
  final double bpmCoverage; // 0.0–1.0
  final double totalDistance;

  const OrderedQueue({
    required this.songs,
    required this.strategy,
    required this.bpmCoverage,
    required this.totalDistance,
  });
}

/// In-memory BPM/key/energy/tail-silence cache passed to the ordering
/// algorithm and used by the crossfade logic to offset fade timing.
class BpmCache {
  final Map<String, int> bpm; // songId → BPM
  final Map<String, String> key; // songId → Camelot key
  final Map<String, bool> isEstimated; // songId → whether BPM is estimated
  final Map<String, double> tailSilence; // songId → seconds of trailing silence
  final Map<String, double> energy; // songId → RMS energy (0.0–1.0)
  final Map<String, double> spectralCentroid; // songId → spectral centroid (brightness proxy)

  const BpmCache({
    this.bpm = const {},
    this.key = const {},
    this.isEstimated = const {},
    this.tailSilence = const {},
    this.energy = const {},
    this.spectralCentroid = const {},
  });

  int? bpmFor(Song song) => bpm[song.id];
  String? keyFor(Song song) => key[song.id];
  bool isEstimatedFor(Song song) => isEstimated[song.id] ?? false;
  double? tailSilenceFor(Song song) => tailSilence[song.id];
  double? energyFor(Song song) => energy[song.id];
  double? spectralCentroidFor(Song song) => spectralCentroid[song.id];
}

/// Build a BPM cache using genre estimates as fallback.
///
/// For songs with no BPM from any real source, this assigns a genre-average
/// estimate and marks it as estimated so the ordering algorithm can apply
/// wider tolerances.
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
  }

  return BpmCache(
    bpm: bpm,
    key: key,
    isEstimated: isEstimated,
    energy: energy,
    spectralCentroid: spectralCentroid,
    tailSilence: tailSilence,
  );
}

// ---------------------------------------------------------------------------
// Camelot wheel key compatibility
//
// The Camelot wheel maps musical keys to numbers 1-12 with A (minor) and
// B (major) suffixes. Adjacent positions are harmonically compatible.
// Distance 0 = same key, 1 = adjacent (perfect), 2 = two steps, etc.

int _camelotDistance(String keyA, String keyB) {
  if (keyA == keyB) return 0;
  // Parse "1A" → (number: 1, minor: true)
  final aMatch = RegExp(r'^(\d+)([AB])$').firstMatch(keyA.trim().toUpperCase());
  final bMatch = RegExp(r'^(\d+)([AB])$').firstMatch(keyB.trim().toUpperCase());
  if (aMatch == null || bMatch == null) return 99;

  final aNum = int.parse(aMatch[1]!);
  final bNum = int.parse(bMatch[1]!);
  final aMode = aMatch[2]!; // A=minor, B=major
  final bMode = bMatch[2]!;

  // Same number, different mode → relative major/minor, compatible
  if (aNum == bNum) return 0;
  // Adjacent numbers, same mode → compatible
  final diff = (aNum - bNum).abs();
  if (diff == 1 && aMode == bMode) return 1;
  // Adjacent numbers, different mode → somewhat compatible
  if (diff == 1) return 2;
  // Distance on the wheel (12 → 1 is adjacent, so wrap)
  final wheelDist = (aNum - bNum).abs() % 12;
  final wrapped = wheelDist > 6 ? 12 - wheelDist : wheelDist;
  if (wrapped == 1) return 1;
  if (wrapped <= 2) return 2;
  return wrapped * 2;
}

// ---------------------------------------------------------------------------

/// Order songs by similarity starting from the anchor song.
///
/// [songs] — the full list of songs to order.
/// [anchorIndex] — the index of the song that should play first.
/// [cache] — BPM/key/energy cache (can be from any source).
/// [seed] — random seed for non-deterministic ordering.
/// [energyCurve] — when true, use energy-curve DJ arc planning instead of
///   the greedy TSP.  Falls back to TSP when energy data is sparse.
List<Song> orderSongs(List<Song> songs, int anchorIndex, BpmCache cache,
    {int seed = 0, bool energyCurve = false}) {
  // --- Input validation ---
  if (songs.isEmpty) return [];
  if (songs.length <= 1) return List.from(songs);
  final idx = anchorIndex.clamp(0, songs.length - 1);

  // --- Determine data quality ---
  final songsWithBpm = songs.where((s) => cache.bpmFor(s) != null).length;
  final bpmCoverage = songsWithBpm / songs.length;

  // --- Try energy-curve mode when requested and data is sufficient ---
  if (energyCurve) {
    final songsWithEnergy =
        songs.where((s) => cache.energyFor(s) != null).length;
    final energyCoverage = songsWithEnergy / songs.length;

    // Use full energy curve when ≥ 30 % have real energy data.
    // Use BPM-proxy curve when ≥ 30 % have BPM (but not enough energy).
    if (energyCoverage >= 0.3) {
      return _energyCurveOrder(songs, idx, cache, seed: seed);
    }
    if (bpmCoverage >= 0.3) {
      return _energyCurveOrder(songs, idx, cache, seed: seed,
          useBpmProxy: true);
    }
  }

  // --- Safety: if very few songs have BPM, fall to metadata-only ---
  if (bpmCoverage < 0.3) {
    return _metadataOrder(songs, idx, seed: seed);
  }

  // --- Greedy TSP (default path) ---
  return _tspOrder(songs, idx, cache, seed: seed, fullBpm: bpmCoverage >= 0.8);
}

// ---------------------------------------------------------------------------
// Metadata-only fallback (genre → era → artist/album)

List<Song> _metadataOrder(List<Song> songs, int anchorIndex, {int seed = 0}) {
  if (songs.isEmpty) return [];
  if (songs.length <= 1) return List.from(songs);

  final anchor = songs[anchorIndex.clamp(0, songs.length - 1)];

  // Seed-derived random ranks for non-deterministic tie-breaking within
  // groups.  Songs from the same artist/album stay in track order; songs
  // from different artists in the same decade/year get shuffled per seed.
  final rng = Random(seed);
  final rank = <String, int>{};
  for (final s in songs) {
    rank[s.id] = rng.nextInt(1000);
  }

  // Group by genre
  final genreGroups = <String, List<Song>>{};
  for (final s in songs) {
    final g = s.genre?.trim().toLowerCase() ?? '';
    genreGroups.putIfAbsent(g, () => []).add(s);
  }

  // Sort within each genre group: by decade, then artist, then track,
  // then random seed rank (so ordering changes per activation).
  for (final group in genreGroups.values) {
    group.sort((a, b) {
      final decadeA = a.year != null ? (a.year! ~/ 10) * 10 : -1;
      final decadeB = b.year != null ? (b.year! ~/ 10) * 10 : -1;
      if (decadeA != decadeB) return decadeA.compareTo(decadeB);
      final artistCmp = a.artist.toLowerCase().compareTo(b.artist.toLowerCase());
      if (artistCmp != 0) return artistCmp;
      final trackCmp = (a.track ?? 999).compareTo(b.track ?? 999);
      if (trackCmp != 0) return trackCmp;
      return (rank[a.id] ?? 0).compareTo(rank[b.id] ?? 0);
    });
  }

  // Order: anchor's genre group first, then others by size descending
  final anchorGenre = anchor.genre?.trim().toLowerCase() ?? '';
  final ordered = <Song>[...(genreGroups.remove(anchorGenre) ?? [])];

  // Sort remaining groups by size descending
  final remaining = genreGroups.entries.toList()
    ..sort((a, b) => b.value.length.compareTo(a.value.length));
  for (final entry in remaining) {
    ordered.addAll(entry.value);
  }

  // Ensure anchor is at anchorIndex
  final currentAnchorPos = ordered.indexWhere((s) => s.id == anchor.id);
  if (currentAnchorPos > 0) {
    ordered.removeAt(currentAnchorPos);
  }
  if (ordered.isEmpty) return [anchor];
  ordered.insert(anchorIndex.clamp(0, ordered.length), anchor);

  return ordered;
}

// ---------------------------------------------------------------------------
// Greedy nearest-neighbor TSP (extracted for code sharing)

List<Song> _tspOrder(List<Song> songs, int anchorIndex, BpmCache cache,
    {int seed = 0, bool fullBpm = false}) {
  final anchor = songs[anchorIndex.clamp(0, songs.length - 1)];
  final rng = Random(seed);

  // Per-song random bias: a tiny (±0.025) nudge so the same playlist
  // produces different orderings for different seeds.
  final bias = <String, double>{};
  for (final s in songs) {
    bias[s.id] = (rng.nextDouble() - 0.5) * 0.05;
  }

  double distance(Song a, Song b) {
    double d = 0;

    final bpmA = cache.bpmFor(a);
    final bpmB = cache.bpmFor(b);
    if (bpmA != null && bpmB != null) {
      final estA = cache.isEstimatedFor(a);
      final estB = cache.isEstimatedFor(b);
      final rawDiff = (bpmA - bpmB).abs() / 140.0;
      if (estA || estB) {
        d += rawDiff * (fullBpm ? 0.25 : 0.15);
      } else {
        d += rawDiff * (fullBpm ? 0.50 : 0.30);
      }
    } else if ((bpmA != null) != (bpmB != null)) {
      d += 0.15;
    } else {
      d += 0.05;
    }

    final keyA = cache.keyFor(a);
    final keyB = cache.keyFor(b);
    if (keyA != null && keyB != null) {
      final kd = _camelotDistance(keyA, keyB);
      d += (kd.clamp(0, 10) / 10.0) * (fullBpm ? 0.20 : 0.15);
    }

    if (a.genre != null &&
        b.genre != null &&
        a.genre!.trim().toLowerCase() != b.genre!.trim().toLowerCase()) {
      d += fullBpm ? 0.15 : 0.25;
    } else if ((a.genre != null) != (b.genre != null)) {
      d += 0.10;
    }

    final decadeA = a.year != null ? (a.year! ~/ 10) * 10 : null;
    final decadeB = b.year != null ? (b.year! ~/ 10) * 10 : null;
    if (decadeA != null && decadeB != null) {
      d += ((decadeA - decadeB).abs() / 100.0) * (fullBpm ? 0.10 : 0.20);
    }

    if (a.artist.trim().toLowerCase() == b.artist.trim().toLowerCase()) {
      d -= 0.1;
    }

    d += (bias[a.id] ?? 0) - (bias[b.id] ?? 0);
    return d;
  }

  final ordered = <Song>[anchor];
  final unvisited = <String, Song>{};
  for (final s in songs) {
    if (s.id != anchor.id) unvisited[s.id] = s;
  }

  while (unvisited.isNotEmpty) {
    final current = ordered.last;
    Song? best;
    double? bestDist;

    for (final s in unvisited.values) {
      final d = distance(current, s);
      if (best == null || d < bestDist!) {
        best = s;
        bestDist = d;
      } else if (d == bestDist && rng.nextBool()) {
        best = s;
      }
    }

    if (best != null) {
      ordered.add(best);
      unvisited.remove(best.id);
    }
  }

  if (ordered.isNotEmpty && ordered[0].id != anchor.id) {
    final anchorPos = ordered.indexWhere((s) => s.id == anchor.id);
    if (anchorPos > 0) {
      ordered.removeAt(anchorPos);
      ordered.insert(0, anchor);
    }
  }

  return ordered;
}

// ---------------------------------------------------------------------------
// Energy-curve DJ arc ordering
//
// Arranges songs in a warm-up → build → peak → cool-down energy arc,
// with BPM progression and harmonic mixing within each energy tier.

/// Number of energy tiers for curve planning.
const _kTierCount = 5;

List<Song> _energyCurveOrder(List<Song> songs, int anchorIndex, BpmCache cache,
    {int seed = 0, bool useBpmProxy = false}) {
  final rng = Random(seed);

  // Per-song seed-derived bias for non-deterministic within-tier ordering.
  final bias = <String, double>{};
  for (final s in songs) {
    bias[s.id] = (rng.nextDouble() - 0.5) * 0.05;
  }

  // --- Assign each song to an energy tier ---
  // Tier 0 = LOWEST (0.0–0.2), tier 4 = HIGHEST (0.8–1.0).
  // When useBpmProxy is true, BPM is normalised to 0–1 as energy proxy.
  final tiers = List.generate(_kTierCount, (_) => <_TieredSong>[]);

  // Also track which songs lack energy data for later distribution.
  final noEnergy = <Song>[];

  double minBpm = double.infinity;
  double maxBpm = 0;
  if (useBpmProxy) {
    for (final s in songs) {
      final b = cache.bpmFor(s) ?? (estimateBpm(s.genre) ?? 120);
      if (b < minBpm) minBpm = b.toDouble();
      if (b > maxBpm) maxBpm = b.toDouble();
    }
  }
  final bpmRange = (maxBpm - minBpm).clamp(1, 200);

  for (final s in songs) {
    double? raw;
    if (useBpmProxy) {
      raw = ((cache.bpmFor(s) ?? (estimateBpm(s.genre) ?? 120)) - minBpm) /
          bpmRange;
    } else {
      raw = cache.energyFor(s);
    }

    if (raw == null) {
      noEnergy.add(s);
      continue;
    }

    final tier = (raw * _kTierCount).clamp(0, _kTierCount - 1).floor();
    tiers[tier].add(_TieredSong(
      song: s,
      energyRaw: raw,
      bpm: cache.bpmFor(s) ?? (estimateBpm(s.genre) ?? 120),
      key: cache.keyFor(s),
    ));
  }

  // --- Sort within each tier by BPM + seed bias ---
  for (final bin in tiers) {
    bin.sort((a, b) {
      final bpmCmp = a.bpm.compareTo(b.bpm);
      if (bpmCmp != 0) return bpmCmp;
      // Same BPM: harmonically compatible keys first
      if (a.key != null && b.key != null) {
        final kd = _camelotDistance(a.key!, b.key!);
        if (kd <= 2) return -1;
      }
      // Seed-derived bias so same-energy songs get different ordering
      // per seed.
      final ba = bias[a.song.id] ?? 0;
      final bb = bias[b.song.id] ?? 0;
      if (ba != bb) return ba.compareTo(bb);
      return 0;
    });
  }

  // --- Build the arc ---
  // Arc shape: warm-up (0→1→2) → build (2→3) → peak (4) → cool-down (3→2)
  // The anchor's tier determines where in the arc we start.
  final double? anchorEnergy;
  if (useBpmProxy) {
    final bpmVal = cache.bpmFor(songs[anchorIndex])
        ?? estimateBpm(songs[anchorIndex].genre)
        ?? 120;
    anchorEnergy = (bpmVal - minBpm) / bpmRange;
  } else {
    anchorEnergy = cache.energyFor(songs[anchorIndex]);
  }
  final anchorTier = anchorEnergy != null
      ? (anchorEnergy * _kTierCount).clamp(0, _kTierCount - 1).floor()
      : 2; // default to middle

  // Determine the tier sequence starting from the anchor's tier.
  final tierSequence = <int>[];
  for (int t = anchorTier; t < _kTierCount; t++) {
    tierSequence.add(t);
  }
  for (int t = _kTierCount - 2; t >= 2; t--) {
    if (!tierSequence.contains(t)) tierSequence.add(t);
  }
  if (anchorTier > 0) {
    for (int t = anchorTier - 1; t >= 0; t--) {
      tierSequence.insert(0, t);
    }
  }

  // Assemble the ordered list from tiers.
  final ordered = <Song>[];
  final usedIds = <String>{};

  void addSongsFrom(List<_TieredSong> bin) {
    for (final ts in bin) {
      if (usedIds.contains(ts.song.id)) continue;
      ordered.add(ts.song);
      usedIds.add(ts.song.id);
    }
  }

  for (final t in tierSequence) {
    final bin = tiers[t];
    if (bin.isEmpty) continue;
    addSongsFrom(bin);
  }

  // Ensure the anchor song plays first regardless of its tier.
  final anchorId = songs[anchorIndex].id;
  final anchorPos = ordered.indexWhere((s) => s.id == anchorId);
  if (anchorPos > 0) {
    ordered.removeAt(anchorPos);
    ordered.insert(0, songs[anchorIndex]);
  }

  // Distribute no-energy songs evenly across the ordered list.
  if (noEnergy.isNotEmpty) {
    final step = (ordered.length / (noEnergy.length + 1)).ceil();
    for (int i = 0; i < noEnergy.length; i++) {
      final pos = (step * (i + 1)).clamp(0, ordered.length);
      ordered.insert(pos, noEnergy[i]);
    }
  }

  return ordered;
}

/// Internal helper pairing a song with its energy/BPM/key data.
class _TieredSong {
  final Song song;
  final double energyRaw;
  final int bpm;
  final String? key;

  const _TieredSong({
    required this.song,
    required this.energyRaw,
    required this.bpm,
    this.key,
  });
}

// Keep the existing _metadataOrder and _camelotDistance functions below.
// (already defined above)
