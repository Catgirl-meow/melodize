import 'package:flutter/material.dart';

/// Styled floating snackbar used throughout the app.
/// Position is handled by MainShell's inner ScaffoldMessenger + MediaQuery.
void showStyledSnack(BuildContext context, String message,
    {bool isError = false}) {
  final scheme = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: TextStyle(
          color: isError ? scheme.onErrorContainer : Colors.white,
        ),
      ),
      behavior: SnackBarBehavior.floating,
      // Dark surface regardless of wallpaper-derived dynamic colors.
      backgroundColor:
          isError ? scheme.errorContainer : const Color(0xFF2C2C2E),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
