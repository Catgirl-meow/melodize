import 'package:flutter_test/flutter_test.dart';
import 'package:melodize/core/audio/playback_core.dart';
import 'package:melodize/core/models/song.dart';

Song song(String id, {String artist = 'Artist'}) => Song(
      id: id,
      title: 'Song $id',
      artist: artist,
      album: 'Album',
    );

void main() {
  group('PlaybackQueue.reorder — duplicate object references', () {
    test('reorder current duplicate to front', () {
      final a = song('dup');
      final queue = PlaybackQueue()
        ..load([a, song('b'), a], startIndex: 2);

      // current is the second a (index 2). Move it to index 0.
      queue.reorder(2, 0);
      expect(queue.currentIndex, 0);
      expect(queue.songs[0], same(a));
      expect(queue.currentSong, same(a));
    });

    test('reorder current duplicate to back', () {
      final a = song('dup');
      final queue = PlaybackQueue()
        ..load([a, song('b'), a], startIndex: 0);

      // current is the first a (index 0). Move it to index 2.
      queue.reorder(0, 2);
      expect(queue.currentIndex, 2);
      expect(queue.songs[2], same(a));
      expect(queue.currentSong, same(a));
    });

    test('reorder non-current duplicate does not move current', () {
      final a = song('dup');
      final queue = PlaybackQueue()
        ..load([a, song('b'), a], startIndex: 0);

      // current is the first a (index 0). Move the second a (index 2) to 1.
      queue.reorder(2, 1);
      expect(queue.currentIndex, 0);
      expect(queue.songs[0], same(a));
      expect(queue.songs[1], same(a));
    });

    test('reorder non-current when current is same object elsewhere', () {
      final a = song('dup');
      final queue = PlaybackQueue()
        ..load([a, song('b'), a, song('c')], startIndex: 2);

      // current is the second a (index 2). Move the first a (index 0) to 3.
      queue.reorder(0, 3);
      expect(queue.currentIndex, 1); // second a slid back one
      expect(queue.songs[1], same(a));
      expect(queue.currentSong, same(a));
    });

    test('all same object references: reorder any preserves current', () {
      final a = song('dup');
      final queue = PlaybackQueue()
        ..load([a, a, a, a], startIndex: 1);

      queue.reorder(3, 0);
      expect(queue.currentIndex, 2);
      expect(queue.songs[2], same(a));
    });

    test('reorder same object from before current to after current', () {
      final a = song('dup');
      final b = song('b');
      final queue = PlaybackQueue()
        ..load([a, b, a, song('c')], startIndex: 2);

      // current is second a (index 2). Move first a (index 0) to after current.
      queue.reorder(0, 3);
      expect(queue.currentIndex, 1); // slid back one
      expect(queue.songs[1], same(a));
      expect(queue.currentSong, same(a));
    });

    test('reorder same object from after current to before current', () {
      final a = song('dup');
      final b = song('b');
      final queue = PlaybackQueue()
        ..load([b, a, song('c'), a], startIndex: 1);

      // current is first a (index 1). Move second a (index 3) to before current.
      queue.reorder(3, 0);
      expect(queue.currentIndex, 2); // slid forward one
      expect(queue.songs[2], same(a));
      expect(queue.currentSong, same(a));
    });
  });

  group('PlaybackQueue.reorder — general edge cases', () {
    test('reorder with no-op (oldIndex == newIndex)', () {
      final queue = PlaybackQueue()
        ..load([song('a'), song('b'), song('c')], startIndex: 1);

      queue.reorder(1, 1);
      expect(queue.songs.map((s) => s.id), ['a', 'b', 'c']);
      expect(queue.currentIndex, 1);
    });

    test('reorder first to last', () {
      final queue = PlaybackQueue()
        ..load([song('a'), song('b'), song('c')], startIndex: 0);

      queue.reorder(0, 2);
      expect(queue.songs.map((s) => s.id), ['b', 'c', 'a']);
      expect(queue.currentIndex, 2);
    });

    test('reorder last to first', () {
      final queue = PlaybackQueue()
        ..load([song('a'), song('b'), song('c')], startIndex: 2);

      queue.reorder(2, 0);
      expect(queue.songs.map((s) => s.id), ['c', 'a', 'b']);
      expect(queue.currentIndex, 0);
    });

    test('reorder with negative newIndex clamps to 0', () {
      final queue = PlaybackQueue()
        ..load([song('a'), song('b'), song('c')], startIndex: 1);

      queue.reorder(2, -5);
      expect(queue.songs.map((s) => s.id), ['c', 'a', 'b']);
      expect(queue.currentIndex, 2); // current b slid forward one
    });

    test('reorder with out-of-range newIndex clamps to end', () {
      final queue = PlaybackQueue()
        ..load([song('a'), song('b'), song('c')], startIndex: 0);

      queue.reorder(0, 100);
      expect(queue.songs.map((s) => s.id), ['b', 'c', 'a']);
      expect(queue.currentIndex, 2);
    });

    test('reorder with out-of-range oldIndex is no-op', () {
      final queue = PlaybackQueue()
        ..load([song('a'), song('b'), song('c')], startIndex: 1);

      queue.reorder(100, 0);
      expect(queue.songs.map((s) => s.id), ['a', 'b', 'c']);
      expect(queue.currentIndex, 1);
    });

    test('reorder on single-song queue', () {
      final queue = PlaybackQueue()..load([song('a')], startIndex: 0);

      queue.reorder(0, 0);
      expect(queue.songs.map((s) => s.id), ['a']);
      expect(queue.currentIndex, 0);
    });

    test('reorder on empty queue is no-op', () {
      final queue = PlaybackQueue();
      queue.reorder(0, 0);
      expect(queue.songs, isEmpty);
      expect(queue.currentIndex, 0);
    });

    test('reorder item before current forward past current', () {
      final queue = PlaybackQueue()
        ..load([song('a'), song('b'), song('c'), song('d')], startIndex: 2);

      // Move a (index 0) to the gap after c (visual index 3).
      // Flutter adjusts: onReorder(0, 3) → decremented to newIndex 2.
      queue.reorder(0, 2);
      expect(queue.songs.map((s) => s.id), ['b', 'c', 'a', 'd']);
      expect(queue.currentIndex, 1); // c slid back one
    });

    test('reorder item after current backward past current', () {
      final queue = PlaybackQueue()
        ..load([song('a'), song('b'), song('c'), song('d')], startIndex: 1);

      // Move d (index 3) to before b (index 1)
      queue.reorder(3, 1);
      expect(queue.songs.map((s) => s.id), ['a', 'd', 'b', 'c']);
      expect(queue.currentIndex, 2); // b slid forward one
    });

    test('reorder removes before current and inserts also before current', () {
      final queue = PlaybackQueue()
        ..load([song('a'), song('b'), song('c'), song('d')], startIndex: 3);

      // Move a (0) to position 1 (before current)
      queue.reorder(0, 1);
      expect(queue.songs.map((s) => s.id), ['b', 'a', 'c', 'd']);
      expect(queue.currentIndex, 3); // current unaffected
    });

    test('reorder removes after current and inserts also after current', () {
      final queue = PlaybackQueue()
        ..load([song('a'), song('b'), song('c'), song('d')], startIndex: 0);

      // Move d (3) to position 2 (after current)
      queue.reorder(3, 2);
      expect(queue.songs.map((s) => s.id), ['a', 'b', 'd', 'c']);
      expect(queue.currentIndex, 0); // current unaffected
    });

    test('reorder two-song queue swaps both', () {
      final queue = PlaybackQueue()
        ..load([song('a'), song('b')], startIndex: 0);

      queue.reorder(0, 1);
      expect(queue.songs.map((s) => s.id), ['b', 'a']);
      expect(queue.currentIndex, 1);
    });
  });
}
