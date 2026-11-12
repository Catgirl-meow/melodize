import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dynamic_color/dynamic_color.dart';

class AppTheme {
  /// System bar style for a page of the given [brightness]: transparent bars
  /// (edge-to-edge) with icons that contrast with the page.
  ///
  /// AppBars must get this explicitly. Our AppBars are transparent, and for a
  /// transparent background Flutter estimates a *dark* color and switches the
  /// status bar to white icons, which vanish on the light theme.
  static SystemUiOverlayStyle systemOverlayFor(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      // iOS/macOS naming: the brightness of the bar background.
      statusBarBrightness: brightness,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness:
          dark ? Brightness.light : Brightness.dark,
      systemNavigationBarContrastEnforced: false,
    );
  }

  /// Frosted-glass background color shared by the floating dock and mini player.
  static Color dockBackground(Color? accentColor, ColorScheme scheme) {
    if (accentColor != null) {
      return scheme.brightness == Brightness.dark
          ? Color.lerp(accentColor, scheme.surface, 0.58)!
              .withValues(alpha: 0.93)
          : Color.lerp(accentColor, Colors.white, 0.65)!
              .withValues(alpha: 0.94);
    }
    return scheme.brightness == Brightness.dark
        ? scheme.surface.withValues(alpha: 0.93)
        : scheme.surfaceContainerHighest.withValues(alpha: 0.94);
  }

  static ThemeData dark(ColorScheme? dynamicScheme) {
    final scheme = dynamicScheme ??
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.dark,
          dynamicSchemeVariant: DynamicSchemeVariant.expressive,
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme.harmonized(),
      brightness: Brightness.dark,
      fontFamily: 'Roboto',
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.secondaryContainer,
        labelTextStyle: WidgetStateProperty.all(
          TextStyle(fontSize: 12, color: scheme.onSurface),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: systemOverlayFor(scheme.brightness),
      ),
      sliderTheme: SliderThemeData(
        thumbColor: scheme.primary,
        activeTrackColor: scheme.primary,
        inactiveTrackColor: scheme.surfaceContainerHighest,
        overlayShape: SliderComponentShape.noOverlay,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        trackHeight: 3,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(color: scheme.onInverseSurface),
        actionTextColor: scheme.inversePrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  static ThemeData light(ColorScheme? dynamicScheme) {
    final scheme = dynamicScheme ??
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.light,
          dynamicSchemeVariant: DynamicSchemeVariant.expressive,
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme.harmonized(),
      brightness: Brightness.light,
      fontFamily: 'Roboto',
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.secondaryContainer,
        labelTextStyle: WidgetStateProperty.all(
          TextStyle(fontSize: 12, color: scheme.onSurface),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: systemOverlayFor(scheme.brightness),
      ),
      sliderTheme: SliderThemeData(
        thumbColor: scheme.primary,
        activeTrackColor: scheme.primary,
        inactiveTrackColor: scheme.surfaceContainerHighest,
        overlayShape: SliderComponentShape.noOverlay,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        trackHeight: 3,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(color: scheme.onInverseSurface),
        actionTextColor: scheme.inversePrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
