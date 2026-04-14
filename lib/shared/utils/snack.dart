import 'package:flutter/material.dart';

/// Inherited widget that tells [showStyledSnack] how many pixels to reserve
/// at the bottom so snackbars appear above the mini player and dock.
/// Set once by MainShell; defaults to 0 outside the shell.
class SnackBarClearance extends InheritedWidget {
  final double bottom;

  const SnackBarClearance({
    super.key,
    required this.bottom,
    required super.child,
  });

  static double of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<SnackBarClearance>()
            ?.bottom ??
        0.0;
  }

  @override
  bool updateShouldNotify(SnackBarClearance old) => old.bottom != bottom;
}

/// Styled floating snackbar used throughout the app.
/// Automatically stays above the mini player / dock using [SnackBarClearance].
void showStyledSnack(BuildContext context, String message,
    {bool isError = false}) {
  final scheme = Theme.of(context).colorScheme;
  final clearance = SnackBarClearance.of(context);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: TextStyle(color: isError ? scheme.onErrorContainer : scheme.onSurface),
      ),
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.fromLTRB(16, 0, 16, clearance + 8),
      backgroundColor:
          isError ? scheme.errorContainer : scheme.surfaceContainerHigh,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
