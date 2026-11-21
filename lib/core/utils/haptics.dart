import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'platform_info.dart';

/// Haptic feedback for the user's own touches, gated by the
/// "Haptic feedback" setting. Desktop has no vibration motor, so every call
/// is a no-op there. Android's system-wide touch-feedback setting still
/// applies on top.
///
/// | Call     | Feel   | Used for                                          |
/// |----------|--------|---------------------------------------------------|
/// | [tap]    | light  | play / pause, dropping a queue item, removing one |
/// | [tick]   | click  | next / previous, swipe-to-skip, seek grab and     |
/// |          |        | release, shuffle / repeat, switches               |
/// | [lift]   | medium | picking up a queue item                           |
///
/// Nothing vibrates on its own (downloads, errors, song changes).
abstract final class Haptics {
  static bool _enabled(WidgetRef ref) =>
      isMobilePlatform && ref.read(preferencesNotifierProvider).hapticFeedback;

  static void tap(WidgetRef ref) {
    if (_enabled(ref)) HapticFeedback.lightImpact();
  }

  static void tick(WidgetRef ref) {
    if (_enabled(ref)) HapticFeedback.selectionClick();
  }

  static void lift(WidgetRef ref) {
    if (_enabled(ref)) HapticFeedback.mediumImpact();
  }
}
