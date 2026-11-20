import 'package:flutter/material.dart';

/// A square button in a [PlayButtonGroup].
class GroupAction {
  final IconData icon;
  final String tooltip;
  final Future<void> Function()? onTap;

  /// Defaults to secondary container colours.
  final Color? background;
  final Color? foreground;
  final Key? key;

  const GroupAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.background,
    this.foreground,
    this.key,
  });
}

/// M3 Expressive button group used on playlist and collection pages, like
/// the artist page: a wide Play pill and square tonal buttons (corner radius
/// about 31 % of the height). Shows a spinner on the button that is running.
class PlayButtonGroup extends StatefulWidget {
  final Future<void> Function()? onPlay;
  final List<GroupAction> actions;
  final double height;

  const PlayButtonGroup({
    super.key,
    required this.onPlay,
    this.actions = const [],
    this.height = 56,
  });

  @override
  State<PlayButtonGroup> createState() => _PlayButtonGroupState();
}

class _PlayButtonGroupState extends State<PlayButtonGroup> {
  int? _busy; // -1 = Play, else index into actions

  Future<void> _run(int key, Future<void> Function() action) async {
    if (_busy != null) return;
    setState(() => _busy = key);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final h = widget.height;
    final onPlay = widget.onPlay;

    Widget spinner(Color color) => SizedBox.square(
        dimension: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: color));

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: h,
            child: FilledButton.icon(
              key: const Key('group-play'),
              onPressed: onPlay == null || _busy != null
                  ? null
                  : () => _run(-1, onPlay),
              style: FilledButton.styleFrom(
                shape: const StadiumBorder(),
                textStyle: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              icon: _busy == -1
                  ? spinner(scheme.onPrimary)
                  : const Icon(Icons.play_arrow_rounded, size: 28),
              label: const Text('Play'),
            ),
          ),
        ),
        for (var i = 0; i < widget.actions.length; i++) ...[
          const SizedBox(width: 8),
          _square(i, widget.actions[i], scheme, spinner),
        ],
      ],
    );
  }

  Widget _square(int i, GroupAction a, ColorScheme scheme,
      Widget Function(Color) spinner) {
    final h = widget.height;
    final bg = a.background ?? scheme.secondaryContainer;
    final fg = a.foreground ?? scheme.onSecondaryContainer;
    final onTap = a.onTap;
    return Tooltip(
      message: a.tooltip,
      child: SizedBox.square(
        dimension: h,
        child: FilledButton(
          key: a.key,
          onPressed:
              onTap == null || _busy != null ? null : () => _run(i, onTap),
          style: FilledButton.styleFrom(
            backgroundColor: bg,
            foregroundColor: fg,
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(h * 0.31)),
          ),
          child: _busy == i
              ? spinner(fg)
              : Icon(a.icon, semanticLabel: a.tooltip),
        ),
      ),
    );
  }
}
