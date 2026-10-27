import 'package:just_audio/just_audio.dart';

/// A just_audio [ShuffleOrder] that plays exactly the order it is given.
///
/// The audio handler keeps shuffle and DJ order as a virtual order over a
/// stable physical playlist. Without help, the platform player auto-advances
/// to physical index + 1 and the handler only corrects it with a seek after
/// that song has started, so a third song plays for a moment between the two
/// planned ones. Handing the virtual order to the player as its shuffle order
/// makes the natural advance land on the planned song (and lets ExoPlayer
/// buffer that song ahead of time).
///
/// [shuffle] is a no-op: the order is computed by the handler and installed
/// with [assign]. [insert] and [removeRange] only keep [indices] a valid
/// permutation until the handler assigns the updated virtual order.
class FixedShuffleOrder extends ShuffleOrder {
  @override
  final List<int> indices = <int>[];

  /// Replaces [indices] with [order], completed to a full permutation of
  /// `0..length-1`: indices out of range or repeated are dropped and missing
  /// ones are appended in physical order. Returns whether [indices] changed.
  bool assign(List<int> order, int length) {
    final next = complete(order, length);
    if (_listEquals(next, indices)) return false;
    indices
      ..clear()
      ..addAll(next);
    return true;
  }

  static List<int> complete(List<int> order, int length) {
    final seen = List<bool>.filled(length, false);
    final result = <int>[];
    for (final index in order) {
      if (index < 0 || index >= length || seen[index]) continue;
      seen[index] = true;
      result.add(index);
    }
    for (int i = 0; i < length; i++) {
      if (!seen[i]) result.add(i);
    }
    return result;
  }

  @override
  void shuffle({int? initialIndex}) {}

  @override
  void insert(int index, int count) {
    for (int i = 0; i < indices.length; i++) {
      if (indices[i] >= index) indices[i] += count;
    }
    indices.addAll(List<int>.generate(count, (i) => index + i));
  }

  @override
  void removeRange(int start, int end) {
    final count = end - start;
    indices.removeWhere((i) => i >= start && i < end);
    for (int i = 0; i < indices.length; i++) {
      if (indices[i] >= end) indices[i] -= count;
    }
  }

  @override
  void clear() => indices.clear();

  static bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
