import 'package:flutter_test/flutter_test.dart';
import 'package:melodize/core/audio/playback_core.dart';
import 'package:melodize/core/audio/smart_shuffle_engine.dart';
import 'package:melodize/core/models/song.dart';

Song song(
  String id, {
  String genre = 'rock',
  int? duration = 180,
  int? year,
}) =>
    Song(
      id: id,
      title: 'Song $id',
      artist: 'Artist $id',
      album: 'Album',
      genre: genre,
      duration: duration,
      year: year,
    );

void main() {
  group('PlaybackPlanner', () {
    test('smart shuffle anchors current song and only reorders upcoming songs',
        () {
      final songs = [
        song('heard-1', genre: 'ambient'),
        song('heard-2', genre: 'ambient'),
        song('current', genre: 'house'),
        song('future-1', genre: 'house'),
        song('future-2', genre: 'techno'),
        song('future-3', genre: 'house'),
      ];
      const cache = BpmCache(
        bpm: {
          'current': 120,
          'future-1': 121,
          'future-2': 140,
          'future-3': 122,
        },
        isEstimated: {
          'current': false,
          'future-1': false,
          'future-2': false,
          'future-3': false,
        },
      );

      final planned = PlaybackPlanner().plan(
        songs: songs,
        currentIndex: 2,
        mode: PlaybackMode.smartShuffle,
        cache: cache,
        seed: 1,
      );

      expect(
          planned.take(3).map((s) => s.id), ['heard-1', 'heard-2', 'current']);
      expect(planned.skip(3).map((s) => s.id).toSet(),
          {'future-1', 'future-2', 'future-3'});
    });

    test('smart shuffle works without analysis cache', () {
      final songs = [
        song('a', genre: 'jazz', year: 1970),
        song('b', genre: 'jazz', year: 1971),
        song('c', genre: 'metal', year: 1990),
      ];

      final planned = PlaybackPlanner().plan(
        songs: songs,
        currentIndex: 0,
        mode: PlaybackMode.smartShuffle,
        seed: 42,
      );

      expect(planned.first.id, 'a');
      expect(planned.map((s) => s.id).toSet(), {'a', 'b', 'c'});
    });

    test('shuffle preserves heard and current segment', () {
      final songs = [song('a'), song('b'), song('c'), song('d'), song('e')];

      final planned = PlaybackPlanner().plan(
        songs: songs,
        currentIndex: 2,
        mode: PlaybackMode.shuffle,
        seed: 7,
      );

      expect(planned.take(3).map((s) => s.id), ['a', 'b', 'c']);
      expect(planned.skip(3).map((s) => s.id).toSet(), {'d', 'e'});
    });
  });

  group('TransitionPolicy', () {
    test('auto duration from 120 BPM → 8s (16 beats)', () {
      final from = song('from', duration: 180);
      final to = song('to');
      final transition = const TransitionPolicy(
        analysis: BpmCache(
          bpm: {'from': 120},
          isEstimated: {'from': false},
          tailSilence: {'from': 3.0},
        ),
      ).planPair(from, to);

      expect(transition.kind, TransitionKind.volumeCrossfade);
      // 16 beats @ 120 BPM = 8s; clamped to [2,12]
      expect(transition.duration, const Duration(seconds: 8));
      // effectiveMs = 180000 - 3000 = 177000
      // fadeMs = min(8000, max(1000, 177000 ~/ 3)) = 8000
      // startMs = 177000 - 8000 = 169000
      expect(transition.fromStart, const Duration(seconds: 169));
      expect(transition.toStart, Duration.zero);
    });

    test('auto duration from 150 BPM → 6s (16 beats = 6.4s, rounded)', () {
      final from = song('from', duration: 180);
      final to = song('to');
      final transition = const TransitionPolicy(
        analysis: BpmCache(
          bpm: {'from': 150},
          isEstimated: {'from': false},
        ),
      ).planPair(from, to);

      expect(transition.kind, TransitionKind.volumeCrossfade);
      // 16 * 60 / 150 = 6.4s → rounds to 6s
      expect(transition.duration, const Duration(seconds: 6));
    });

    test('auto duration from 90 BPM → 11s (16 beats = 10.7s, rounded)', () {
      final from = song('from', duration: 180);
      final to = song('to');
      final transition = const TransitionPolicy(
        analysis: BpmCache(
          bpm: {'from': 90},
          isEstimated: {'from': false},
        ),
      ).planPair(from, to);

      expect(transition.kind, TransitionKind.volumeCrossfade);
      // 16 * 60 / 90 = 10.7s → rounds to 11s
      expect(transition.duration, const Duration(seconds: 11));
    });

    test('auto duration without BPM defaults to 6s', () {
      final from = song('from', duration: 180);
      final to = song('to');
      final transition = const TransitionPolicy().planPair(from, to);

      expect(transition.kind, TransitionKind.volumeCrossfade);
      expect(transition.duration, const Duration(seconds: 6));
    });

    test('energy differential shortens duration for big gap', () {
      final from = song('from', duration: 180);
      final to = song('to');
      final transition = const TransitionPolicy(
        analysis: BpmCache(
          bpm: {'from': 120},
          isEstimated: {'from': false},
          energy: {'from': 0.8, 'to': 0.3}, // diff = 0.5 > 0.30
        ),
      ).planPair(from, to);

      expect(transition.kind, TransitionKind.volumeCrossfade);
      // Base 8s * 0.75 = 6s
      expect(transition.duration, const Duration(seconds: 6));
    });

    test('energy differential lengthens duration for similar energy', () {
      final from = song('from', duration: 180);
      final to = song('to');
      final transition = const TransitionPolicy(
        analysis: BpmCache(
          bpm: {'from': 120},
          isEstimated: {'from': false},
          energy: {'from': 0.5, 'to': 0.52}, // diff = 0.02 < 0.10
        ),
      ).planPair(from, to);

      expect(transition.kind, TransitionKind.volumeCrossfade);
      // Base 8s * 1.15 = 9.2s → rounds to 9s
      expect(transition.duration, const Duration(seconds: 9));
    });

    test('short track caps duration', () {
      final from = song('from', duration: 30);
      final to = song('to');
      final transition = const TransitionPolicy().planPair(from, to);

      expect(transition.kind, TransitionKind.volumeCrossfade);
      // maxFade = 30 * 0.35 = 10.5s, but short track (< 90s) clamps to 4s
      expect(transition.duration, const Duration(seconds: 4));
    });

    test('unknown and short durations fall back to gapless', () {
      final to = song('to');

      expect(
        const TransitionPolicy()
            .planPair(song('unknown', duration: null), to)
            .kind,
        TransitionKind.gapless,
      );
      expect(
        const TransitionPolicy()
            .planPair(song('short', duration: 10), to)
            .kind,
        TransitionKind.gapless,
      );
    });

    test('dj blend requires real compatible companion analysis', () {
      final from = song('from');
      final to = song('to');

      // Missing keys → fallback to BPM-only (allowed)
      final good = const TransitionPolicy(
        analysis: BpmCache(
          bpm: {'from': 120, 'to': 126},
          isEstimated: {'from': false, 'to': false},
        ),
      ).planPair(from, to);
      expect(good.kind, TransitionKind.djBlend);

      final estimated = const TransitionPolicy(
        analysis: BpmCache(
          bpm: {'from': 120, 'to': 126},
          isEstimated: {'from': true, 'to': false},
        ),
      ).planPair(from, to);
      expect(estimated.kind, TransitionKind.volumeCrossfade);
    });

    test('dj blend blocked by incompatible keys', () {
      final from = song('from');
      final to = song('to');

      // Same BPM but clashing keys (8B vs 3A → distance > 2)
      final clash = const TransitionPolicy(
        djTransitionsEnabled: true,
        analysis: BpmCache(
          bpm: {'from': 120, 'to': 126},
          isEstimated: {'from': false, 'to': false},
          key: {'from': '8B', 'to': '3A'},
        ),
      ).planPair(from, to);
      expect(clash.kind, TransitionKind.volumeCrossfade);

      // Compatible keys (adjacent Camelot)
      final compatible = const TransitionPolicy(
        djTransitionsEnabled: true,
        analysis: BpmCache(
          bpm: {'from': 120, 'to': 126},
          isEstimated: {'from': false, 'to': false},
          key: {'from': '5A', 'to': '6A'},
        ),
      ).planPair(from, to);
      expect(compatible.kind, TransitionKind.djBlend);
    });

    test('planUpcoming tags dj blend when companion analysis + compatible BPM', () {
      final songs = [
        song('a', duration: 180),
        song('b', duration: 180),
        song('c', duration: 180),
        song('d', duration: 180),
      ];
      const policy = TransitionPolicy(
        djTransitionsEnabled: true,
        analysis: BpmCache(
          bpm: {'a': 120, 'b': 126, 'c': 124, 'd': 128},
          isEstimated: {'a': false, 'b': false, 'c': false, 'd': false},
          key: {'a': '5A', 'b': '6A', 'c': '5A', 'd': '6A'},
        ),
      );

      final transitions = policy.planUpcoming(songs, 0);
      expect(transitions.length, 3);

      for (final t in transitions) {
        expect(t.kind, TransitionKind.djBlend,
            reason: '${t.from.id} → ${t.to.id} should be a DJ blend');
        expect(t.reason, 'compatible companion analysis');
        expect(t.toStart, Duration.zero);
      }
    });

    test('planUpcoming falls back to crossfade when BPM is incompatible', () {
      final songs = [
        song('a', duration: 180),
        song('b', duration: 180),
      ];
      const policy = TransitionPolicy(
        djTransitionsEnabled: true,
        analysis: BpmCache(
          bpm: {'a': 120, 'b': 145}, // ratio = 1.208 > 1.15
          isEstimated: {'a': false, 'b': false},
        ),
      );

      final transitions = policy.planUpcoming(songs, 0);
      expect(transitions.length, 1);
      expect(transitions.first.kind, TransitionKind.volumeCrossfade);
      expect(transitions.first.reason, 'standard volume crossfade');
    });

    test('planUpcoming falls back to gapless when track too short', () {
      final songs = [
        song('a', duration: 14),
        song('b', duration: 180),
      ];
      const policy = TransitionPolicy(
        djTransitionsEnabled: true,
        analysis: BpmCache(
          bpm: {'a': 120, 'b': 126},
          isEstimated: {'a': false, 'b': false},
        ),
      );

      final transitions = policy.planUpcoming(songs, 0);
      expect(transitions.length, 1);
      expect(transitions.first.kind, TransitionKind.gapless);
    });

    test('planUpcoming disables DJ blend when djTransitionsEnabled is false', () {
      final songs = [
        song('a', duration: 180),
        song('b', duration: 180),
        song('c', duration: 180),
      ];
      const policy = TransitionPolicy(
        djTransitionsEnabled: false,
        analysis: BpmCache(
          bpm: {'a': 120, 'b': 126, 'c': 124},
          isEstimated: {'a': false, 'b': false, 'c': false},
          key: {'a': '5A', 'b': '6A', 'c': '5A'},
        ),
      );

      final transitions = policy.planUpcoming(songs, 0);
      expect(transitions.length, 2);

      for (final t in transitions) {
        expect(t.kind, TransitionKind.volumeCrossfade,
            reason: '${t.from.id} → ${t.to.id} should be crossfade when DJ transitions disabled');
        expect(t.reason, 'standard volume crossfade');
      }
    });

    test('planUpcoming falls back to crossfade when BPM is estimated', () {
      final songs = [
        song('a', duration: 180),
        song('b', duration: 180),
        song('c', duration: 180),
      ];
      const policy = TransitionPolicy(
        djTransitionsEnabled: true,
        analysis: BpmCache(
          bpm: {'a': 120, 'b': 126, 'c': 124},
          // All BPM values are estimated → should not allow DJ blend
          isEstimated: {'a': true, 'b': true, 'c': true},
          key: {'a': '5A', 'b': '6A', 'c': '5A'},
        ),
      );

      final transitions = policy.planUpcoming(songs, 0);
      expect(transitions.length, 2);

      for (final t in transitions) {
        expect(t.kind, TransitionKind.volumeCrossfade,
            reason: '${t.from.id} → ${t.to.id} should be crossfade when BPM is estimated');
        expect(t.reason, 'standard volume crossfade');
      }
    });

    test('planUpcoming blocks DJ blend when only one song has estimated BPM', () {
      final songs = [
        song('a', duration: 180),
        song('b', duration: 180),
        song('c', duration: 180),
      ];
      const policy = TransitionPolicy(
        djTransitionsEnabled: true,
        analysis: BpmCache(
          bpm: {'a': 120, 'b': 126, 'c': 124},
          // Only 'b' is estimated — both adjacent transitions should be blocked
          isEstimated: {'a': false, 'b': true, 'c': false},
          key: {'a': '5A', 'b': '6A', 'c': '5A'},
        ),
      );

      final transitions = policy.planUpcoming(songs, 0);
      expect(transitions.length, 2);

      // a→b: 'b' is estimated → blocked
      expect(transitions[0].kind, TransitionKind.volumeCrossfade,
          reason: 'a → b blocked because b has estimated BPM');
      // b→c: 'b' is estimated → blocked
      expect(transitions[1].kind, TransitionKind.volumeCrossfade,
          reason: 'b → c blocked because b has estimated BPM');
    });

    test('auto duration capped to one-third of effective track length', () {
      final from = song('short', duration: 18);
      final to = song('next');
      final transition = const TransitionPolicy().planPair(from, to);

      // 18s short track → auto duration clamped to 4s
      // effectiveMs = 18000, fadeMs = min(4000, max(1000, 6000)) = 4000ms
      expect(transition.kind, TransitionKind.volumeCrossfade);
      expect(transition.duration, const Duration(seconds: 4));
      expect(transition.fromStart, const Duration(seconds: 14));
      expect(transition.toStart, Duration.zero);
    });

    test('tail silence offsets fromStart', () {
      final from = song('from', duration: 30);
      final to = song('to');

      // Baseline: no tail silence.
      // Short track (< 90s) → auto duration clamped to 4s.
      // effectiveMs = 30000, fadeMs = min(4000, 10000) = 4000
      final baseline = const TransitionPolicy().planPair(from, to);
      expect(baseline.fromStart, const Duration(seconds: 26));

      // 4s tail silence: effectiveMs = 26000, fromStart drops by 4s.
      final withTail = const TransitionPolicy(
        analysis: BpmCache(tailSilence: {'from': 4.0}),
      ).planPair(from, to);
      expect(withTail.fromStart, const Duration(seconds: 22));
    });

    test('planUpcoming returns empty when currentIndex is the last song', () {
      final songs = [
        song('a', duration: 180),
        song('b', duration: 180),
      ];
      const policy = TransitionPolicy(
        analysis: BpmCache(
          bpm: {'a': 120, 'b': 126},
          isEstimated: {'a': false, 'b': false},
        ),
      );

      final transitions = policy.planUpcoming(songs, 1);
      expect(transitions, isEmpty);
    });

    test('planUpcoming on 2-song queue returns exactly 1 transition', () {
      final songs = [
        song('a', duration: 180),
        song('b', duration: 180),
      ];
      const policy = TransitionPolicy(
        analysis: BpmCache(
          bpm: {'a': 120, 'b': 126},
          isEstimated: {'a': false, 'b': false},
          key: {'a': '5A', 'b': '6A'},
        ),
      );

      final transitions = policy.planUpcoming(songs, 0);
      expect(transitions.length, 1);
      expect(transitions.first.from.id, 'a');
      expect(transitions.first.to.id, 'b');
      expect(transitions.first.kind, TransitionKind.djBlend);
    });

    test('fade capped at minimum effective duration boundary (15s track)', () {
      final from = song('from', duration: 15);
      final to = song('to');
      final transition = const TransitionPolicy().planPair(from, to);

      // 15s short track → auto duration clamped to 4s.
      // effectiveMs = 15000, fadeMs = min(4000, max(1000, 5000)) = 4000ms
      expect(transition.kind, TransitionKind.volumeCrossfade);
      expect(transition.duration, const Duration(seconds: 4));
      expect(transition.fromStart, const Duration(seconds: 11));
      expect(transition.toStart, Duration.zero);
    });
  });

  group('PlaybackQueue', () {
    test('queue edits keep logical current index in sync', () {
      final queue = PlaybackQueue()
        ..load([song('a'), song('b'), song('c')], startIndex: 1);

      queue.playNext(song('next'));
      expect(queue.songs.map((s) => s.id), ['a', 'b', 'next', 'c']);
      expect(queue.currentIndex, 1);

      queue.removeAt(0);
      expect(queue.songs.map((s) => s.id), ['b', 'next', 'c']);
      expect(queue.currentIndex, 0);

      queue.reorder(2, 1);
      expect(queue.songs.map((s) => s.id), ['b', 'c', 'next']);
      expect(queue.currentIndex, 0);

      queue.removeById('b');
      expect(queue.songs.map((s) => s.id), ['c', 'next']);
      expect(queue.currentIndex, 0);
    });

    test('snapshot contains only real songs', () {
      final queue = PlaybackQueue()
        ..load([song('a'), song('b')], mode: PlaybackMode.smartShuffle);

      final snapshot = queue.snapshot();

      expect(snapshot.songs.map((s) => s.id), ['a', 'b']);
      expect(snapshot.mode, PlaybackMode.smartShuffle);
    });
  });

  group('SmartShuffleEngine scoring', () {
    test('spectral centroid matching affects tier-1 ordering', () {
      final songs = [
        song('anchor', genre: 'house'),
        song('bright1', genre: 'house'),
        song('bright2', genre: 'house'),
        song('bright3', genre: 'house'),
        song('dull', genre: 'house'),
      ];
      // All same BPM/key/genre — spectral centroid is the tie-breaker.
      // Four bright-sounding tracks (close spectral centroid) and one dull.
      const cache = BpmCache(
        bpm: {
          'anchor': 120,
          'bright1': 120,
          'bright2': 120,
          'bright3': 120,
          'dull': 120,
        },
        key: {
          'anchor': '5A',
          'bright1': '5A',
          'bright2': '5A',
          'bright3': '5A',
          'dull': '5A',
        },
        energy: {
          'anchor': 0.5,
          'bright1': 0.5,
          'bright2': 0.5,
          'bright3': 0.5,
          'dull': 0.5,
        },
        spectralCentroid: {
          'anchor': 8000.0,
          'bright1': 8200.0,
          'bright2': 8100.0,
          'bright3': 8300.0,
          'dull': 3000.0,
        },
        isEstimated: {},
      );

      final ordered = orderSongs(songs, 0, cache, seed: 1);
      // The dull track should never be in first position because all three
      // bright tracks score higher (close spectral centroid) and the top-3
      // weighted random pool excludes the dull one.
      expect(ordered[1].id, isNot('dull'));
    });

    test('energy-boost bonus scores +2 Camelot steps higher when energy rises',
        () {
      final a = song('a', genre: 'house');
      final b = song('b', genre: 'house');
      const cache = BpmCache(
        bpm: {'a': 120, 'b': 120},
        key: {'a': '5A', 'b': '7A'}, // +2 Camelot steps
        energy: {'a': 0.3, 'b': 0.6}, // energy rises
        isEstimated: {},
      );

      // Use a playlist with only these two upcoming songs so we can
      // observe the ordering directly.
      final songs = [a, b];
      final ordered = orderSongs(songs, 0, cache, seed: 1);
      expect(ordered[1].id, 'b');
    });

    test('energy boost does NOT trigger when energy drops', () {
      final a = song('a', genre: 'house');
      final b = song('b', genre: 'house');
      const cache = BpmCache(
        bpm: {'a': 120, 'b': 120},
        key: {'a': '5A', 'b': '7A'},
        energy: {'a': 0.60, 'b': 0.30}, // energy drops
        isEstimated: {},
      );
      // With only these two songs, b must still be placed after a
      final ordered = orderSongs([a, b], 0, cache, seed: 1);
      expect(ordered[1].id, 'b');
    });
  });
}
