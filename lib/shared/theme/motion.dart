import 'package:flutter/widgets.dart';

/// One named animation: how long it runs and how it eases.
@immutable
class MotionSpec {
  const MotionSpec(this.duration, this.curve);

  final Duration duration;
  final Curve curve;
}

/// Melodize's motion tokens (Material 3 Expressive).
///
/// Every UI animation picks one of these instead of its own duration and
/// curve, so the app moves consistently:
///
/// | Token          | Use for                                                   |
/// |----------------|-----------------------------------------------------------|
/// | [spring]       | shapes that answer a touch: play button, mini player      |
/// |                | corners, pressed tiles, the like heart                    |
/// | [emphasized]   | large shape or layout changes that stay on screen         |
/// | [enter]        | things arriving: Now Playing opening, Home sections,      |
/// |                | banners and sheets                                        |
/// | [exit]         | things leaving: Now Playing closing, dismissals           |
/// | [glide]        | settling after a gesture or sliding a selection:          |
/// |                | snap-backs, the dock pill, lyric auto-scroll              |
/// | [standard]     | small state changes: sizes, colors, page indicator        |
/// | [short]        | fades, icon swaps, rotations                              |
///
/// Timers, debounces and the queue's equalizer bars are not motion and keep
/// their own values.
abstract final class Motion {
  /// Slight overshoot, like a soft spring. Expressive "spatial" motion.
  static const MotionSpec spring =
      MotionSpec(Duration(milliseconds: 500), Cubic(0.34, 1.56, 0.64, 1.0));

  static const MotionSpec emphasized =
      MotionSpec(Duration(milliseconds: 500), Curves.easeInOutCubicEmphasized);

  static const MotionSpec enter =
      MotionSpec(Duration(milliseconds: 400), Cubic(0.05, 0.7, 0.1, 1.0));

  static const MotionSpec exit =
      MotionSpec(Duration(milliseconds: 200), Cubic(0.3, 0.0, 0.8, 0.15));

  static const MotionSpec glide =
      MotionSpec(Duration(milliseconds: 300), Cubic(0.0, 0.0, 0.0, 1.0));

  static const MotionSpec standard =
      MotionSpec(Duration(milliseconds: 300), Cubic(0.2, 0.0, 0.0, 1.0));

  static const MotionSpec short =
      MotionSpec(Duration(milliseconds: 150), Cubic(0.2, 0.0, 0.0, 1.0));

  /// True when the platform asks for reduced motion. Ambient animation (the
  /// wavy progress line) stops; one-off transitions still run.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}
