import 'package:flutter/material.dart';

/// A single tile clipped to [borderRadius] with a [surfaceContainerHigh]
/// background. Use directly or let [GroupedSection] create these automatically.
class GroupedListTile extends StatelessWidget {
  const GroupedListTile({
    super.key,
    required this.child,
    required this.borderRadius,
    this.backgroundColor,
  });

  final Widget child;
  final BorderRadius borderRadius;

  /// Defaults to [ColorScheme.surfaceContainerHigh].
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor ??
          Theme.of(context).colorScheme.surfaceContainerHigh,
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: child,
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
