import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:melodize/core/audio/fixed_shuffle_order.dart';

bool isPermutation(List<int> order, int length) {
  if (order.length != length) return false;
  final sorted = List.of(order)..sort();
  for (int i = 0; i < length; i++) {
    if (sorted[i] != i) return false;
  }
  return true;
}

AudioSource source(int i) => AudioSource.uri(Uri.parse('https://example.test/$i'));

void main() {
  group('FixedShuffleOrder', () {
    test('assign installs the virtual order exactly', () {
      final order = FixedShuffleOrder()..insert(0, 5);
      expect(order.indices, [0, 1, 2, 3, 4]);
      expect(order.assign([3, 0, 4, 1, 2], 5), isTrue);
      expect(order.indices, [3, 0, 4, 1, 2]);
    });

    test('assign reports no change for the same order', () {
      final order = FixedShuffleOrder()..assign([2, 0, 1], 3);
      expect(order.assign([2, 0, 1], 3), isFalse);
    });

    test('assign completes a partial order to a full permutation', () {
      final order = FixedShuffleOrder();
      // Planner dropped index 1 and produced an out-of-range and a repeat.
      order.assign([4, 9, 2, 4, 0], 5);
      expect(order.indices, [4, 2, 0, 1, 3]);
      expect(isPermutation(order.indices, 5), isTrue);
    });

    test('shuffle keeps the assigned order', () {
      final order = FixedShuffleOrder()..assign([2, 0, 1], 3);
      order.shuffle(initialIndex: 0);
      expect(order.indices, [2, 0, 1]);
    });

    test('the platform next after the current song is the planned one', () {
      // Physical queue 0..5, virtual (shuffled) order below. Whatever the
      // current song, the item after it in the player's order must be the
      // virtual next, never physical index + 1.
      const virtual = [2, 5, 0, 4, 1, 3];
      final order = FixedShuffleOrder()..assign(virtual, 6);
      for (int vp = 0; vp < virtual.length - 1; vp++) {
        final pos = order.indices.indexOf(virtual[vp]);
        expect(order.indices[pos + 1], virtual[vp + 1]);
      }
    });

    test('playlist edits keep a valid permutation', () {
      final order = FixedShuffleOrder();
      final playlist = ConcatenatingAudioSource(
        children: List.generate(5, source),
        shuffleOrder: order,
      );
      order.assign([3, 1, 4, 0, 2], 5);

      playlist.insert(2, source(10));
      expect(isPermutation(order.indices, 6), isTrue);
      // Existing songs keep their relative order, shifted past the insert.
      expect(order.indices.take(5), [4, 1, 5, 0, 3]);

      playlist.add(source(11));
      expect(isPermutation(order.indices, 7), isTrue);

      playlist.removeAt(1);
      expect(isPermutation(order.indices, 6), isTrue);

      playlist.move(0, 4);
      expect(isPermutation(order.indices, 6), isTrue);

      playlist.clear();
      expect(order.indices, isEmpty);
    });
  });
}
