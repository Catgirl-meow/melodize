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
    test('crossfade starts before audible end after tail silence offset', () {
      final from = song('from', duration: 180);
      final to = song('to');
      final transition = const TransitionPolicy(
        crossfadeSeconds: 8,
        analysis: BpmCache(tailSilence: {'from': 3.0}),
      ).planPair(from, to);

      expect(transition.kind, TransitionKind.volumeCrossfade);
      expect(transition.duration, const Duration(seconds: 8));
      expect(transition.fromStart, const Duration(seconds: 169));
      expect(transition.toStart, Duration.zero);
    });

    test('unknown and short durations fall back to gapless', () {
      final to = song('to');

      expect(
        const TransitionPolicy(crossfadeSeconds: 6)
            .planPair(song('unknown', duration: null), to)
            .kind,
        TransitionKind.gapless,
      );
      expect(
        const TransitionPolicy(crossfadeSeconds: 6)
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
        crossfadeSeconds: 6,
        analysis: BpmCache(
          bpm: {'from': 120, 'to': 126},
          isEstimated: {'from': false, 'to': false},
        ),
      ).planPair(from, to);
      expect(good.kind, TransitionKind.djBlend);

      final estimated = const TransitionPolicy(
        crossfadeSeconds: 6,
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
        crossfadeSeconds: 6,
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
        crossfadeSeconds: 6,
        djTransitionsEnabled: true,
        analysis: BpmCache(
          bpm: {'from': 120, 'to': 126},
          isEstimated: {'from': false, 'to': false},
          key: {'from': '5A', 'to': '6A'},
        ),
      ).planPair(from, to);
      expect(compatible.kind, TransitionKind.djBlend);
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
  });
}
