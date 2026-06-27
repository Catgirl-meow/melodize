import 'dart:math';

// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:melodize/core/audio/playback_core.dart';
import 'package:melodize/core/audio/smart_shuffle_engine.dart';
import 'package:melodize/core/models/song.dart';

Song _song(int i, {String? artist, String? genre, int? bpm}) => Song(
      id: 's${i.toString().padLeft(6, '0')}',
      title: 'Song $i',
      artist: artist ?? 'Artist ${i % 200}',
      album: 'Album ${i % 50}',
      duration: 180 + (i % 120),
      genre: genre ?? _pickGenre(i),
      bpm: bpm,
    );

String _pickGenre(int i) {
  final genres = [
    'Rock', 'Pop', 'Electronic', 'Hip-Hop', 'Jazz', 'Metal', 'Classical',
    'Indie', 'Alternative', 'House', 'Techno', 'Blues', 'Folk', 'Ambient',
  ];
  return genres[i % genres.length];
}

/// Build a cache with realistic data for [count] songs.
BpmCache _buildRealCache(int count) {
  final bpm = <String, int>{};
  final key = <String, String>{};
  final energy = <String, double>{};
  final spectral = <String, double>{};
  final tailSilence = <String, double>{};
  final isEstimated = <String, bool>{};

  final rng = Random(42);
  for (int i = 0; i < count; i++) {
    final id = 's${i.toString().padLeft(6, '0')}';
    bpm[id] = 80 + rng.nextInt(80); // 80–160 BPM
    key[id] = '${rng.nextInt(12) + 1}${rng.nextBool() ? 'A' : 'B'}';
    energy[id] = rng.nextDouble();
    spectral[id] = 2000 + rng.nextInt(6000).toDouble();
    tailSilence[id] = rng.nextDouble() * 4;
    isEstimated[id] = false;
  }
  return buildBpmCache(
    const [],
    knownBpm: bpm,
    knownKeys: key,
    knownEnergy: energy,
    knownSpectralCentroid: spectral,
    knownTailSilence: tailSilence,
  );
}

void main() {
  group('Stress: regular shuffle', () {
    late List<Song> songs10k;

    setUpAll(() {
      songs10k = List.generate(10000, (i) => _song(i));
    });

    test('shuffle 10,000 songs from index 0', () {
      final sw = Stopwatch()..start();
      final planned = PlaybackPlanner().plan(
        songs: songs10k,
        currentIndex: 0,
        mode: PlaybackMode.shuffle,
        seed: 42,
      );
      sw.stop();
      expect(planned.length, 10000);
      expect(planned.first.id, songs10k.first.id);
      // Shuffle must be deterministic with same seed.
      final p2 = PlaybackPlanner().plan(
        songs: songs10k,
        currentIndex: 0,
        mode: PlaybackMode.shuffle,
        seed: 42,
      );
      expect(planned.map((s) => s.id), p2.map((s) => s.id));
      print('[shuffle 10k] ${sw.elapsedMilliseconds}ms');
      expect(sw.elapsedMilliseconds, lessThan(500),
          reason: 'shuffle should be fast');
    });

    test('shuffle 10,000 songs from middle index', () {
      final sw = Stopwatch()..start();
      final planned = PlaybackPlanner().plan(
        songs: songs10k,
        currentIndex: 5000,
        mode: PlaybackMode.shuffle,
        seed: 42,
      );
      sw.stop();
      expect(planned.length, 10000);
      expect(planned[5000].id, songs10k[5000].id);
      print('[shuffle 10k mid] ${sw.elapsedMilliseconds}ms');
      expect(sw.elapsedMilliseconds, lessThan(500),
          reason: 'shuffle from middle should be fast');
    });
  });

  group('Stress: smart shuffle — no analysis data', () {
    late List<Song> songs10k;

    setUpAll(() {
      songs10k = List.generate(10000, (i) => _song(i));
    });

    test('smart shuffle 10,000 songs — falls back to random', () {
      final sw = Stopwatch()..start();
      final planned = PlaybackPlanner().plan(
        songs: songs10k,
        currentIndex: 0,
        mode: PlaybackMode.smartShuffle,
        seed: 42,
      );
      sw.stop();
      expect(planned.length, 10000);
      print('[smart 10k no-data] ${sw.elapsedMilliseconds}ms');
      // With no data, it should still be reasonably fast (random shuffle).
      expect(sw.elapsedMilliseconds, lessThan(3000),
          reason: 'no-data smart shuffle should stay fast');
    });
  });

  group('Stress: smart shuffle — full companion data', () {
    late List<Song> songs10k;
    late BpmCache cache10k;

    setUpAll(() {
      songs10k = List.generate(10000, (i) => _song(i));
      cache10k = _buildRealCache(10000);
    });

    test('smart shuffle 10,000 songs with full data', () {
      final sw = Stopwatch()..start();
      final planned = PlaybackPlanner().plan(
        songs: songs10k,
        currentIndex: 0,
        mode: PlaybackMode.smartShuffle,
        cache: cache10k,
        seed: 42,
      );
      sw.stop();
      expect(planned.length, 10000);
      print('[smart 10k full] ${sw.elapsedMilliseconds}ms');
      // Should complete in a few seconds even with full DJ scoring.
      expect(sw.elapsedMilliseconds, lessThan(1000),
          reason: 'full-data smart shuffle should complete in < 1s');
    });

    test('smart shuffle 10,000 songs from middle index', () {
      final sw = Stopwatch()..start();
      final planned = PlaybackPlanner().plan(
        songs: songs10k,
        currentIndex: 5000,
        mode: PlaybackMode.smartShuffle,
        cache: cache10k,
        seed: 42,
      );
      sw.stop();
      expect(planned.length, 10000);
      print('[smart 10k mid] ${sw.elapsedMilliseconds}ms');
      expect(sw.elapsedMilliseconds, lessThan(1000),
          reason: 'mid-index smart shuffle should complete in < 1s');
    });
  });

  group('Stress: buildBpmCache performance', () {
    test('build cache for 10,000 songs with keys', () {
      final songs = List.generate(10000, (i) => _song(i));
      final bpm = <String, int>{};
      final keys = <String, String>{};
      final rng = Random(42);
      for (int i = 0; i < 10000; i++) {
        final id = 's${i.toString().padLeft(6, '0')}';
        bpm[id] = 80 + rng.nextInt(80);
        keys[id] = '${rng.nextInt(12) + 1}${rng.nextBool() ? 'A' : 'B'}';
      }
      final sw = Stopwatch()..start();
      final cache = buildBpmCache(
        songs,
        knownBpm: bpm,
        knownKeys: keys,
      );
      sw.stop();
      expect(cache.bpm.length, 10000);
      print('[buildBpmCache 10k] ${sw.elapsedMilliseconds}ms');
      expect(sw.elapsedMilliseconds, lessThan(1000),
          reason: 'cache build should be < 1s');
    });
  });

  group('Stress: artist separation with huge queue', () {
    test('1000-song queue with only 5 artists (extreme clustering)', () {
      final songs = List.generate(
        1000,
        (i) => _song(i, artist: 'Artist ${i % 5}'),
      );
      final sw = Stopwatch()..start();
      final planned = PlaybackPlanner().plan(
        songs: songs,
        currentIndex: 0,
        mode: PlaybackMode.smartShuffle,
        seed: 42,
      );
      sw.stop();
      expect(planned.length, 1000);
      expect(sw.elapsedMilliseconds, lessThan(2000),
          reason: 'artist separation 1k×5 should be < 2s');
      print('[artist-sep 1k×5] ${sw.elapsedMilliseconds}ms');
    });

    test('10000-song queue with only 50 artists', () {
      final songs = List.generate(
        10000,
        (i) => _song(i, artist: 'Artist ${i % 50}'),
      );
      final sw = Stopwatch()..start();
      final planned = PlaybackPlanner().plan(
        songs: songs,
        currentIndex: 0,
        mode: PlaybackMode.smartShuffle,
        seed: 42,
      );
      sw.stop();
      expect(planned.length, 10000);
      expect(sw.elapsedMilliseconds, lessThan(3000),
          reason: 'artist separation 10k×50 should be < 3s');
      print('[artist-sep 10k×50] ${sw.elapsedMilliseconds}ms');
    });
  });

  group('Stress: memory-sanity on large queue', () {
    test('20,000 songs normal mode (no shuffle work)', () {
      final songs = List.generate(20000, (i) => _song(i));
      final sw = Stopwatch()..start();
      final planned = PlaybackPlanner().plan(
        songs: songs,
        currentIndex: 0,
        mode: PlaybackMode.normal,
        seed: 42,
      );
      sw.stop();
      expect(planned.length, 20000);
      print('[normal 20k] ${sw.elapsedMilliseconds}ms');
      expect(sw.elapsedMilliseconds, lessThan(100),
          reason: 'normal mode should be near-instant');
    });

    test('shuffle 20,000 songs', () {
      final songs = List.generate(20000, (i) => _song(i));
      final sw = Stopwatch()..start();
      final planned = PlaybackPlanner().plan(
        songs: songs,
        currentIndex: 0,
        mode: PlaybackMode.shuffle,
        seed: 42,
      );
      sw.stop();
      expect(planned.length, 20000);
      print('[shuffle 20k] ${sw.elapsedMilliseconds}ms');
      expect(sw.elapsedMilliseconds, lessThan(2000),
          reason: '20k shuffle should be < 2s');
    });
  });

  group('Stress: all-same-genre corner case', () {
    test('5000 songs all same genre', () {
      final songs = List.generate(
        5000,
        (i) => _song(i, genre: 'Rock'),
      );
      final sw = Stopwatch()..start();
      final planned = PlaybackPlanner().plan(
        songs: songs,
        currentIndex: 0,
        mode: PlaybackMode.smartShuffle,
        seed: 42,
      );
      sw.stop();
      expect(planned.length, 5000);
      expect(sw.elapsedMilliseconds, lessThan(2000),
          reason: 'same-genre 5k should be < 2s');
      print('[same-genre 5k] ${sw.elapsedMilliseconds}ms');
    });
  });

  group('Stress: duplicate-heavy queue', () {
    test('5000 songs with 50% duplicate IDs', () {
      final songs = <Song>[];
      for (int i = 0; i < 5000; i++) {
        songs.add(_song(i % 2500)); // ids wrap every 2500
      }
      final sw = Stopwatch()..start();
      final planned = PlaybackPlanner().plan(
        songs: songs,
        currentIndex: 0,
        mode: PlaybackMode.smartShuffle,
        seed: 42,
      );
      sw.stop();
      expect(planned.length, 5000);
      expect(sw.elapsedMilliseconds, lessThan(2000),
          reason: 'duplicate-id 5k should be < 2s');
      print('[dup-ids 5k] ${sw.elapsedMilliseconds}ms');
    });
  });

  group('Stress: transition planning on large queues', () {
    test('planUpcoming on 2000 songs with full analysis — under 50ms', () {
      final songs = List.generate(2000, (i) => _song(i));
      final cache = _buildRealCache(2000);
      final policy = TransitionPolicy(
        djTransitionsEnabled: true,
        analysis: cache,
      );

      final sw = Stopwatch()..start();
      final transitions = policy.planUpcoming(songs, 0);
      sw.stop();

      expect(transitions.length, 3,
          reason: 'should plan 3 transitions ahead from index 0');
      expect(sw.elapsedMilliseconds, lessThan(50),
          reason: 'planUpcoming is O(1); 3 pairs should be < 50ms');
      print('[planUpcoming 2k] ${sw.elapsedMilliseconds}ms');

      // All should be DJ blends because the cache has compatible real data.
      for (final t in transitions) {
        expect(t.kind, isNot(TransitionKind.gapless),
            reason: 'all tracks have valid duration and analysis');
      }
    });

    test('planUpcoming on 5000 songs near end boundary', () {
      final songs = List.generate(5000, (i) => _song(i));
      final cache = _buildRealCache(5000);
      final policy = TransitionPolicy(
        djTransitionsEnabled: true,
        analysis: cache,
      );

      final transitions = policy.planUpcoming(songs, 4998);
      expect(transitions.length, 1,
          reason: 'only 1 upcoming pair when 2 songs remain');
    });

    test('planUpcoming on 10000 songs at mid-index', () {
      final songs = List.generate(10000, (i) => _song(i));
      final cache = _buildRealCache(10000);
      final policy = TransitionPolicy(
        djTransitionsEnabled: true,
        analysis: cache,
      );

      final sw = Stopwatch()..start();
      final transitions = policy.planUpcoming(songs, 5000);
      sw.stop();

      expect(transitions.length, 3);
      expect(sw.elapsedMilliseconds, lessThan(50),
          reason: 'mid-index planUpcoming should still be < 50ms');
      print('[planUpcoming 10k mid] ${sw.elapsedMilliseconds}ms');
    });
  });

  group('Stress: energy-arc with 5,000+ songs and mixed real/estimated BPM', () {
    test('5000 songs: energy arc shape preserved with 30% real BPM', () {
      final rng = Random(42);
      final songs = <Song>[];
      final bpm = <String, int>{};
      final key = <String, String>{};
      final energy = <String, double>{};
      final isEstimated = <String, bool>{};
      final genres = ['ambient', 'folk', 'rock', 'house', 'metal'];

      for (int i = 0; i < 5000; i++) {
        final id = 's${i.toString().padLeft(6, '0')}';
        // Distribute songs across 5 energy tiers.
        final tier = i % 5;
        energy[id] = (tier * 0.2 + 0.05 + rng.nextDouble() * 0.14)
            .clamp(0.0, 1.0);
        // BPM roughly aligned with tier but with variety.
        bpm[id] = 60 + (tier * 35) + rng.nextInt(20);
        key[id] = '${rng.nextInt(12) + 1}${rng.nextBool() ? 'A' : 'B'}';
        // 30% real BPM, 70% estimated.
        isEstimated[id] = rng.nextDouble() > 0.3;

        songs.add(Song(
          id: id,
          title: 'Song $i',
          artist: 'Artist $i',
          album: 'Album ${i % 200}',
          genre: genres[tier],
          duration: 180 + (i % 120),
        ));
      }

      final cache = BpmCache(
        bpm: bpm,
        key: key,
        energy: energy,
        isEstimated: isEstimated,
      );

      final sw = Stopwatch()..start();
      final planned = PlaybackPlanner().plan(
        songs: songs,
        currentIndex: 0,
        mode: PlaybackMode.smartShuffle,
        cache: cache,
        seed: 42,
      );
      sw.stop();

      expect(planned.length, 5000);
      print('[energy-arc 5k mixed] ${sw.elapsedMilliseconds}ms');
      expect(sw.elapsedMilliseconds, lessThan(5000),
          reason: '5k energy-arc smart shuffle should be < 5s');

      // Verify the energy-arc shape is visible at a block level after the
      // full pipeline (_adjacentSwap / _interleaveArtists perturb individual
      // songs but preserve coarse block trends).
      final remaining = planned.skip(1).toList();

      // Split remaining ~4999 songs into 5 blocks; ascending arc means later
      // blocks should have higher average tier than earlier blocks.
      final blockSize = remaining.length ~/ 5;
      final blockAvgs = <double>[];
      for (int b = 0; b < 5; b++) {
        final block = remaining.skip(b * blockSize).take(blockSize).toList();
        final avg = block
                .map((s) => _energyTierForTest(s, cache))
                .reduce((a, b) => a + b) /
            block.length;
        blockAvgs.add(avg);
      }

      // Ascending trend: each later block should be >= previous (allowing
      // small noise from post-processing).
      int ascents = 0;
      for (int i = 0; i < blockAvgs.length - 1; i++) {
        if (blockAvgs[i + 1] >= blockAvgs[i] - 0.5) ascents++;
      }
      expect(ascents, greaterThanOrEqualTo(3),
          reason: 'coarse energy arc should ascend across most blocks');

      // Peak should be in the last block (or close to it).
      final maxBlock = blockAvgs
          .reduce((a, b) => a > b ? a : b);
      expect(blockAvgs.last, greaterThanOrEqualTo(maxBlock - 0.5),
          reason: 'peak energy should be near the end of the arc');

      // It should span at least 3 distinct tiers somewhere in the queue.
      final allTiers = remaining
          .map((s) => _energyTierForTest(s, cache))
          .toList();
      expect(allTiers.toSet().length, greaterThanOrEqualTo(3),
          reason: 'arc should span at least 3 tiers overall');
    });

    test('10000 songs: energy arc with 50% real BPM', () {
      final rng = Random(123);
      final songs = <Song>[];
      final bpm = <String, int>{};
      final key = <String, String>{};
      final energy = <String, double>{};
      final isEstimated = <String, bool>{};
      final genres = ['ambient', 'folk', 'rock', 'house', 'metal'];

      for (int i = 0; i < 10000; i++) {
        final id = 's${i.toString().padLeft(6, '0')}';
        final tier = i % 5;
        energy[id] = (tier * 0.2 + 0.05 + rng.nextDouble() * 0.14)
            .clamp(0.0, 1.0);
        bpm[id] = 60 + (tier * 35) + rng.nextInt(20);
        key[id] = '${rng.nextInt(12) + 1}${rng.nextBool() ? 'A' : 'B'}';
        isEstimated[id] = rng.nextDouble() > 0.5;

        songs.add(Song(
          id: id,
          title: 'Song $i',
          artist: 'Artist $i',
          album: 'Album ${i % 200}',
          genre: genres[tier],
          duration: 180 + (i % 120),
        ));
      }

      final cache = BpmCache(
        bpm: bpm,
        key: key,
        energy: energy,
        isEstimated: isEstimated,
      );

      final sw = Stopwatch()..start();
      final planned = PlaybackPlanner().plan(
        songs: songs,
        currentIndex: 2500,
        mode: PlaybackMode.smartShuffle,
        cache: cache,
        seed: 42,
      );
      sw.stop();

      expect(planned.length, 10000);
      print('[energy-arc 10k mixed mid] ${sw.elapsedMilliseconds}ms');
      expect(sw.elapsedMilliseconds, lessThan(5000),
          reason: '10k mid-index energy-arc should be < 5s');

      // Anchor at mid-index; verify the arc continues at a block level.
      final afterAnchor = planned.skip(2501).toList();

      // Split the ~7499 remaining songs into 5 blocks.
      final blockSize = afterAnchor.length ~/ 5;
      final blockAvgs = <double>[];
      for (int b = 0; b < 5; b++) {
        final block =
            afterAnchor.skip(b * blockSize).take(blockSize).toList();
        final avg = block
                .map((s) => _energyTierForTest(s, cache))
                .reduce((a, b) => a + b) /
            block.length;
        blockAvgs.add(avg);
      }

      // With anchor at tier 0 in the middle of the queue, the arc should
      // continue ascending for a while then descend.
      int ascents = 0;
      for (int i = 0; i < blockAvgs.length - 1; i++) {
        if (blockAvgs[i + 1] >= blockAvgs[i] - 0.5) ascents++;
      }
      expect(ascents, greaterThanOrEqualTo(2),
          reason: 'arc should continue ascending for several blocks');

      // The queue should still span at least 3 tiers overall.
      final allTiers = planned
          .map((s) => _energyTierForTest(s, cache))
          .toList();
      expect(allTiers.toSet().length, greaterThanOrEqualTo(3),
          reason: 'arc should span at least 3 tiers overall');
    });
  });
}

/// Minimal mirror of _assignEnergyTier for stress-test verification.
int _energyTierForTest(Song song, BpmCache cache) {
  final energy = cache.energyFor(song);
  if (energy != null) {
    return (energy * 5).clamp(0, 4).floor();
  }
  final bpm = cache.bpmFor(song);
  if (bpm != null) {
    return ((bpm.clamp(40, 220) - 40) / 180 * 5).clamp(0, 4).floor();
  }
  return 2;
}
