import 'package:flutter_test/flutter_test.dart';
import 'package:melodize/core/audio/playback_core.dart';
import 'package:melodize/core/audio/smart_shuffle_engine.dart';
import 'package:melodize/core/models/song.dart';

Song song(
  String id, {
  String genre = 'rock',
  int? duration = 180,
}) =>
    Song(
      id: id,
      title: 'Song $id',
      artist: 'Artist $id',
      album: 'Album',
      genre: genre,
      duration: duration,
    );

void main() {
  group('PlaybackPlanner smart shuffle regression', () {
    test('smart shuffle with currentIndex > 0 preserves all songs and no duplicates',
        () {
      final songs = [
        song('a', genre: 'ambient'),
        song('b', genre: 'folk'),
        song('c', genre: 'house'),
        song('d', genre: 'techno'),
        song('e', genre: 'rock'),
      ];
      const cache = BpmCache(
        bpm: {'a': 60, 'b': 90, 'c': 120, 'd': 140, 'e': 130},
        isEstimated: {'a': false, 'b': false, 'c': false, 'd': false, 'e': false},
      );

      final planned = PlaybackPlanner().plan(
        songs: songs,
        currentIndex: 2, // 'c' is current
        mode: PlaybackMode.smartShuffle,
        cache: cache,
        seed: 1,
      );

      // Length must be preserved.
      expect(planned.length, songs.length,
          reason: 'planned queue must have same length as input');

      // No duplicates, no missing songs.
      expect(planned.map((s) => s.id).toSet(), songs.map((s) => s.id).toSet(),
          reason: 'all original song IDs must be present exactly once');

      // Heard + current preserved at front.
      expect(planned.take(3).map((s) => s.id), ['a', 'b', 'c'],
          reason: 'heard songs and current must stay at the front');

      // Upcoming is a permutation of the original upcoming.
      expect(planned.skip(3).map((s) => s.id).toSet(), {'d', 'e'},
          reason: 'upcoming must contain only the original upcoming songs');
    });

    test('smart shuffle at index 0 preserves all songs', () {
      final songs = [
        song('a', genre: 'house'),
        song('b', genre: 'techno'),
        song('c', genre: 'rock'),
      ];
      const cache = BpmCache(
        bpm: {'a': 120, 'b': 130, 'c': 140},
        isEstimated: {'a': false, 'b': false, 'c': false},
      );

      final planned = PlaybackPlanner().plan(
        songs: songs,
        currentIndex: 0,
        mode: PlaybackMode.smartShuffle,
        cache: cache,
        seed: 1,
      );

      expect(planned.length, 3);
      expect(planned.first.id, 'a');
      expect(planned.map((s) => s.id).toSet(), {'a', 'b', 'c'});
    });

    test('smart shuffle at last index returns full list unchanged', () {
      final songs = [
        song('a', genre: 'ambient'),
        song('b', genre: 'folk'),
        song('c', genre: 'house'),
      ];
      const cache = BpmCache(
        bpm: {'a': 60, 'b': 90, 'c': 120},
        isEstimated: {'a': false, 'b': false, 'c': false},
      );

      final planned = PlaybackPlanner().plan(
        songs: songs,
        currentIndex: 2,
        mode: PlaybackMode.smartShuffle,
        cache: cache,
        seed: 1,
      );

      // When current is the last song, upcoming is empty (< 2), so plan()
      // returns the original list unchanged.
      expect(planned.map((s) => s.id), ['a', 'b', 'c']);
    });

    test('smart shuffle with 4+ upcoming songs has no duplicates or drops', () {
      final songs = List.generate(
        8,
        (i) => song('$i', genre: i % 2 == 0 ? 'house' : 'techno'),
      );
      final cache = buildBpmCache(
        songs,
        knownBpm: {
          for (var i = 0; i < 8; i++) '$i': 100 + i * 5,
        },
      );

      final planned = PlaybackPlanner().plan(
        songs: songs,
        currentIndex: 2,
        mode: PlaybackMode.smartShuffle,
        cache: cache,
        seed: 42,
      );

      expect(planned.length, 8,
          reason: 'planned queue must preserve all 8 songs');
      expect(planned.map((s) => s.id).toSet().length, 8,
          reason: 'no duplicates allowed');
      expect(planned.take(3).map((s) => s.id), ['0', '1', '2'],
          reason: 'heard+current preserved');
    });
  });
}
