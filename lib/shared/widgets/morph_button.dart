import 'package:flutter/material.dart';

import '../theme/motion.dart';

/// A filled button whose shape springs between states (M3 Expressive).
///
/// [radius] and [width] animate with [Motion.spring] whenever they change,
/// so the caller describes the shape for its state (the play button is a
/// circle when paused and a wider rounded square while playing). While the
/// button is held its corners tighten to [pressedRadius] and it shrinks a
/// little, then springs back.
class MorphButton extends StatefulWidget {
  const MorphButton({
    super.key,
    required this.width,
    required this.height,
    required this.radius,
    required this.color,
    required this.child,
    required this.onPressed,
    this.pressedRadius,
    this.tooltip,
  });

  final double width;
  final double height;
  final double radius;
  final double? pressedRadius;
  final Color color;
  final Widget child;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  State<MorphButton> createState() => _MorphButtonState();
}

class _MorphButtonState extends State<MorphButton> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final targetRadius = _pressed
        ? (widget.pressedRadius ?? widget.radius * 0.6)
        : widget.radius;
    Widget button = TweenAnimationBuilder<double>(
      tween: Tween(end: widget.width),
      duration: Motion.spring.duration,
      curve: Motion.spring.curve,
      builder: (context, w, child) => TweenAnimationBuilder<double>(
        tween: Tween(end: targetRadius),
        duration: Motion.spring.duration,
        curve: Motion.spring.curve,
        builder: (context, r, child) {
          // The spring overshoots; keep the corners valid.
          final radius =
              BorderRadius.circular(r.clamp(0.0, widget.height / 2).toDouble());
          return SizedBox(
            width: w,
            height: widget.height,
            child: Material(
              color: widget.color,
              borderRadius: radius,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                borderRadius: radius,
                onTap: widget.onPressed,
                onTapDown: (_) => _setPressed(true),
                onTapUp: (_) => _setPressed(false),
                onTapCancel: () => _setPressed(false),
                child: Center(child: child),
              ),
            ),
          );
        },
        child: child,
      ),
      child: widget.child,
    );
    button = AnimatedScale(
      scale: _pressed ? 0.92 : 1,
      duration: Motion.spring.duration,
      curve: Motion.spring.curve,
      child: button,
    );
    if (widget.tooltip != null) {
      button = Tooltip(message: widget.tooltip!, child: button);
    }
    return button;
  }
}
