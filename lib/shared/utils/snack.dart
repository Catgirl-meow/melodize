import 'package:flutter/material.dart';

/// Gap between a snackbar and whatever it sits on (mini player, dock, or the
/// bottom of the screen).
const kSnackGap = 8.0;

/// Side inset shared with the floating dock and mini player, so a snackbar
/// lines up with them instead of being slightly wider.
const _kSnackSideInset = 16.0;

/// How far above a Scaffold's own snackbar position the app's overlays reach
/// (MainShell's dock + mini player). Scaffold already keeps floating snackbars
/// above the system navigation inset, so this excludes that inset.
class SnackInset extends InheritedWidget {
  final double bottom;
  const SnackInset({super.key, required this.bottom, required super.child});

  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SnackInset>()?.bottom ?? 0;

  @override
  bool updateShouldNotify(SnackInset oldWidget) => oldWidget.bottom != bottom;
}

/// Styled floating snackbar used throughout the app.
///
/// [bottomOffset] — explicit bottom margin in logical pixels. When omitted,
/// falls back to [SnackInset] + [kSnackGap]: just above the mini player
/// inside MainShell, just above the system navigation bar elsewhere.
///
/// [messenger] — show on this messenger instead of the nearest one above
/// [context] (MainShell's own listeners sit above the shell's messenger).
void showStyledSnack(BuildContext context, String message,
    {bool isError = false,
    double? bottomOffset,
    ScaffoldMessengerState? messenger}) {
  final scheme = Theme.of(context).colorScheme;
  final bottom = bottomOffset ?? SnackInset.of(context) + kSnackGap;
  (messenger ?? ScaffoldMessenger.of(context))
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(
            color: isError ? scheme.onErrorContainer : Colors.white,
          ),
        ),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(
            _kSnackSideInset, 0, _kSnackSideInset, bottom),
        // Dark surface regardless of wallpaper-derived dynamic colors.
        backgroundColor:
            isError ? scheme.errorContainer : const Color(0xFF2C2C2E),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
}
