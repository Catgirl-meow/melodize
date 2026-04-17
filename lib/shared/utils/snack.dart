import 'package:flutter/material.dart';

/// Styled floating snackbar used throughout the app.
///
/// [bottomOffset] — explicit bottom margin in logical pixels. When omitted,
/// falls back to [MediaQuery.padding.bottom] + 12, which resolves to the
/// content-clearance value injected by MainShell for screens rendered inside
/// the shell (dock + mini-player height). Callers outside that MediaQuery
/// scope (e.g. MainShell's own ref.listen callbacks) must supply the value
/// explicitly so the snackbar clears the dock and mini player.
void showStyledSnack(BuildContext context, String message,
    {bool isError = false, double? bottomOffset}) {
  final scheme = Theme.of(context).colorScheme;
  final bottom = bottomOffset ?? MediaQuery.of(context).padding.bottom + 12;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: TextStyle(
          color: isError ? scheme.onErrorContainer : Colors.white,
        ),
      ),
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.fromLTRB(12, 0, 12, bottom),
      // Dark surface regardless of wallpaper-derived dynamic colors.
      backgroundColor:
          isError ? scheme.errorContainer : const Color(0xFF2C2C2E),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
