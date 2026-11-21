import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/motion.dart';

/// M3 Expressive "wavy" progress bar.
///
/// The played part is a sine line that drifts while [playing] is true; it
/// eases flat when playback pauses, while the user drags, and always under
/// the platform's reduce-motion setting. The unplayed part is a straight
/// line in [trackColor], separated from the handle by a small gap.
///
/// With [onChanged] null it is a read-only indicator (the mini player).
/// It only ticks while the wave is moving, and respects [TickerMode], so a
/// hidden Now Playing screen costs nothing.
class WavySlider extends StatefulWidget {
  const WavySlider({
    super.key,
    required this.value,
    required this.playing,
    required this.color,
    required this.trackColor,
    this.onChangeStart,
    this.onChanged,
    this.onChangeEnd,
    this.height = 28,
    this.thickness = 4,
    this.amplitude = 3,
    this.wavelength = 40,
    this.showHandle = true,
    this.semanticLabel,
    this.semanticValue,
  });

  /// Progress, 0 to 1.
  final double value;
  final bool playing;
  final Color color;
  final Color trackColor;
  final ValueChanged<double>? onChangeStart;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;
  final double height;
  final double thickness;
  final double amplitude;
  final double wavelength;
  final bool showHandle;
  final String? semanticLabel;

  /// Spoken value, such as "1:23 of 3:36".
  final String? semanticValue;

  @override
  State<WavySlider> createState() => _WavySliderState();
}

class _WavySliderState extends State<WavySlider> with TickerProviderStateMixin {
  // Phase runs continuously while the wave moves; one cycle per wavelength.
  late final AnimationController _phase = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  );
  // 1 = full wave, 0 = flat.
  late final AnimationController _amp = AnimationController(
    vsync: this,
    duration: Motion.standard.duration,
    value: 0,
  );
  bool _dragging = false;
  bool _reduced = false;
  // Last value reported during a drag; the parent may not have rebuilt
  // with it yet when the drag ends.
  double? _dragValue;

  bool get _interactive => widget.onChanged != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = Motion.reduced(context);
    _sync();
  }

  @override
  void didUpdateWidget(WavySlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playing != widget.playing) _sync();
  }

  void _sync() {
    final wavy = widget.playing && !_dragging && !_reduced;
    if (wavy) {
      if (!_phase.isAnimating) _phase.repeat();
      _amp.animateTo(1, curve: Motion.standard.curve);
    } else {
      _amp.animateTo(0, curve: Motion.standard.curve).whenCompleteOrCancel(() {
        if (mounted && _amp.value == 0) _phase.stop();
      });
    }
  }

  @override
  void dispose() {
    _phase.dispose();
    _amp.dispose();
    super.dispose();
  }

  double _valueAt(Offset local, double width) {
    final pad = _WavePainter.sidePad(widget.thickness, widget.showHandle);
    return ((local.dx - pad) / (width - 2 * pad)).clamp(0.0, 1.0);
  }

  void _setDragging(bool v) {
    if (_dragging == v) return;
    setState(() => _dragging = v);
    _sync();
  }

  @override
  Widget build(BuildContext context) {
    final painter = CustomPaint(
      size: Size(double.infinity, widget.height),
      painter: _WavePainter(
        value: widget.value,
        phase: _phase,
        amp: _amp,
        color: widget.color,
        trackColor: widget.trackColor,
        thickness: widget.thickness,
        amplitude: widget.amplitude,
        wavelength: widget.wavelength,
        showHandle: widget.showHandle,
        dragging: _dragging,
      ),
    );
    if (!_interactive) {
      return Semantics(
        label: widget.semanticLabel,
        value: widget.semanticValue,
        child: SizedBox(height: widget.height, child: painter),
      );
    }
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      return Semantics(
        slider: true,
        label: widget.semanticLabel,
        value: widget.semanticValue,
        onIncrease: () => _nudge(0.05),
        onDecrease: () => _nudge(-0.05),
        child: Focus(
          onKeyEvent: (_, e) {
            if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
              return KeyEventResult.ignored;
            }
            if (e.logicalKey == LogicalKeyboardKey.arrowRight) {
              _nudge(0.02);
              return KeyEventResult.handled;
            }
            if (e.logicalKey == LogicalKeyboardKey.arrowLeft) {
              _nudge(-0.02);
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: (d) {
                _setDragging(true);
                final v = _dragValue = _valueAt(d.localPosition, w);
                widget.onChangeStart?.call(v);
                widget.onChanged?.call(v);
              },
              onHorizontalDragUpdate: (d) => widget.onChanged
                  ?.call(_dragValue = _valueAt(d.localPosition, w)),
              onHorizontalDragEnd: (_) {
                _setDragging(false);
                widget.onChangeEnd?.call(_dragValue ?? widget.value);
                _dragValue = null;
              },
              onHorizontalDragCancel: () {
                _setDragging(false);
                // Ends the drag where it was, so the caller never stays
                // stuck in its dragging state.
                widget.onChangeEnd?.call(_dragValue ?? widget.value);
                _dragValue = null;
              },
              onTapUp: (d) {
                final v = _valueAt(d.localPosition, w);
                widget.onChangeStart?.call(v);
                widget.onChanged?.call(v);
                widget.onChangeEnd?.call(v);
              },
              // Taller than the line itself so it is easy to grab.
              child:
                  SizedBox(height: math.max(widget.height, 40), child: painter),
            ),
          ),
        ),
      );
    });
  }

  void _nudge(double delta) {
    final v = (widget.value + delta).clamp(0.0, 1.0);
    widget.onChangeStart?.call(v);
    widget.onChanged?.call(v);
    widget.onChangeEnd?.call(v);
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter({
    required this.value,
    required this.phase,
    required this.amp,
    required this.color,
    required this.trackColor,
    required this.thickness,
    required this.amplitude,
    required this.wavelength,
    required this.showHandle,
    required this.dragging,
  }) : super(repaint: Listenable.merge([phase, amp]));

  final double value;
  final Animation<double> phase;
  final Animation<double> amp;
  final Color color;
  final Color trackColor;
  final double thickness;
  final double amplitude;
  final double wavelength;
  final bool showHandle;
  final bool dragging;

  static double sidePad(double thickness, bool handle) =>
      thickness / 2 + (handle ? 2 : 0);

  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.height / 2;
    final pad = sidePad(thickness, showHandle);
    final x = pad + (size.width - 2 * pad) * value.clamp(0.0, 1.0);
    final gap = showHandle ? 6.0 : 3.0;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round;

    // Unplayed track.
    final trackStart = x + gap + thickness / 2;
    if (trackStart < size.width - pad) {
      canvas.drawLine(Offset(trackStart, mid), Offset(size.width - pad, mid),
          line..color = trackColor);
    }

    // Played wave.
    final end = x - gap - thickness / 2;
    if (end > pad) {
      final a = amplitude * amp.value;
      final shift = phase.value * 2 * math.pi;
      final path = Path()
        ..moveTo(
            pad, mid + a * math.sin(pad / wavelength * 2 * math.pi - shift));
      for (double px = pad + 1; px <= end; px += 1) {
        path.lineTo(
            px, mid + a * math.sin(px / wavelength * 2 * math.pi - shift));
      }
      canvas.drawPath(path, line..color = color);
    }

    if (showHandle) {
      final h = dragging ? 26.0 : 22.0;
      final w = dragging ? 5.0 : 4.0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(x, mid), width: w, height: h),
          Radius.circular(w / 2),
        ),
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) =>
      old.value != value ||
      old.color != color ||
      old.trackColor != trackColor ||
      old.dragging != dragging ||
      old.showHandle != showHandle ||
      old.thickness != thickness ||
      old.amplitude != amplitude ||
      old.wavelength != wavelength;
}
