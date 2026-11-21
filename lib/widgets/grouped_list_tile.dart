import 'dart:async';

import 'package:flutter/material.dart';

import '../shared/theme/motion.dart';

/// A single tile clipped to [borderRadius] with a [surfaceContainerHigh]
/// background. Use directly or let [GroupedSection] create these automatically.
///
/// While a tappable tile is held, every corner rounds to at least
/// [pressedRadius] (the M3 Expressive pressed shape for list items) and
/// springs back on release. A press starts after a short hold without
/// movement, so scrolling across the list doesn't morph tiles.
class GroupedListTile extends StatefulWidget {
  const GroupedListTile({
    super.key,
    required this.child,
    required this.borderRadius,
    this.backgroundColor,
    this.pressedRadius = 20,
  });

  final Widget child;
  final BorderRadius borderRadius;

  /// Defaults to [ColorScheme.surfaceContainerHigh].
  final Color? backgroundColor;
  final double pressedRadius;

  @override
  State<GroupedListTile> createState() => _GroupedListTileState();
}

class _GroupedListTileState extends State<GroupedListTile> {
  static const _holdDelay = Duration(milliseconds: 90);
  static const _moveSlop = 8.0;

  bool _pressed = false;
  Timer? _hold;
  Offset? _down;

  /// List tiles without a tap or toggle handler are read-only rows (server
  /// URL, username) and must not look pressable.
  bool get _interactive {
    final c = widget.child;
    if (c is ListTile) return c.onTap != null || c.onLongPress != null;
    if (c is SwitchListTile) return c.onChanged != null;
    if (c is CheckboxListTile) return c.onChanged != null;
    return true;
  }

  void _start(PointerDownEvent e) {
    _down = e.position;
    _hold?.cancel();
    _hold = Timer(_holdDelay, () {
      if (mounted) setState(() => _pressed = true);
    });
  }

  void _move(PointerMoveEvent e) {
    if (_down != null && (e.position - _down!).distance > _moveSlop) _end();
  }

  void _end([PointerEvent? _]) {
    _hold?.cancel();
    _down = null;
    if (_pressed && mounted) setState(() => _pressed = false);
  }

  @override
  void dispose() {
    _hold?.cancel();
    super.dispose();
  }

  BorderRadius get _target {
    if (!_pressed) return widget.borderRadius;
    final p = Radius.circular(widget.pressedRadius);
    Radius at(Radius r) => r.x >= widget.pressedRadius ? r : p;
    final b = widget.borderRadius;
    return BorderRadius.only(
      topLeft: at(b.topLeft),
      topRight: at(b.topRight),
      bottomLeft: at(b.bottomLeft),
      bottomRight: at(b.bottomRight),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.backgroundColor ??
        Theme.of(context).colorScheme.surfaceContainerHigh;
    if (!_interactive) {
      return Material(
        color: color,
        borderRadius: widget.borderRadius,
        clipBehavior: Clip.antiAlias,
        child: widget.child,
      );
    }
    return Listener(
      onPointerDown: _start,
      onPointerMove: _move,
      onPointerUp: _end,
      onPointerCancel: _end,
      child: TweenAnimationBuilder<BorderRadius?>(
        tween: BorderRadiusTween(end: _target),
        duration: _pressed ? Motion.short.duration : Motion.spring.duration,
        curve: _pressed ? Motion.short.curve : Motion.spring.curve,
        builder: (context, r, child) => Material(
          color: color,
          borderRadius: _clamp(r ?? widget.borderRadius),
          clipBehavior: Clip.antiAlias,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }

  // The spring overshoots; never let a corner go negative.
  static BorderRadius _clamp(BorderRadius r) {
    Radius c(Radius x) => Radius.circular(x.x < 0 ? 0 : x.x);
    return BorderRadius.only(
      topLeft: c(r.topLeft),
      topRight: c(r.topRight),
      bottomLeft: c(r.bottomLeft),
      bottomRight: c(r.bottomRight),
    );
  }
}

/// Wraps [children] in an Android-15-style grouped card with position-aware
/// corner radii:
///
/// | position   | top corners | bottom corners |
/// |------------|-------------|----------------|
/// | only-child | 24 px       | 24 px          |
/// | first      | 24 px       | 4 px           |
/// | middle     | 4 px        | 4 px           |
/// | last       | 4 px        | 24 px          |
///
/// A 2 px gap separates adjacent tiles. The whole group is inset 16 px
/// horizontally so it sits inside the screen margins like a card.
class GroupedSection extends StatelessWidget {
  const GroupedSection({super.key, required this.children});

  final List<Widget> children;

  static const double _outer = 24;
  static const double _inner = 4;

  static BorderRadius _radiusFor(int index, int total) {
    if (total == 1) return BorderRadius.circular(_outer);
    if (index == 0) {
      return const BorderRadius.only(
        topLeft: Radius.circular(_outer),
        topRight: Radius.circular(_outer),
        bottomLeft: Radius.circular(_inner),
        bottomRight: Radius.circular(_inner),
      );
    }
    if (index == total - 1) {
      return const BorderRadius.only(
        topLeft: Radius.circular(_inner),
        topRight: Radius.circular(_inner),
        bottomLeft: Radius.circular(_outer),
        bottomRight: Radius.circular(_outer),
      );
    }
    return BorderRadius.circular(_inner);
  }

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    final color = Theme.of(context).colorScheme.surfaceContainerHigh;
    final rows = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      if (i > 0) rows.add(const SizedBox(height: 2));
      rows.add(GroupedListTile(
        borderRadius: _radiusFor(i, children.length),
        backgroundColor: color,
        child: children[i],
      ));
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: rows,
      ),
    );
  }
}
