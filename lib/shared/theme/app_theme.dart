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

  /// Title of a top-level tab (Home greeting, Library, Settings).
  static TextStyle? pageTitleStyle(BuildContext context) => Theme.of(context)
      .textTheme
      .headlineMedium
      ?.copyWith(fontWeight: FontWeight.bold);

  /// Toolbar height for the top-level tabs' title bars.
  static const double pageTitleBarHeight = 64;

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

  /// A complete M3 scheme for [brightness].
  ///
  /// Android's wallpaper scheme (dynamic_color) only fills the original M3
  /// roles; the surface-container tones are left at `surface`, so cards,
  /// grouped settings tiles and cover placeholders vanished into the page.
  /// Keep the system colors and fill just those tones from a scheme seeded
  /// with the same primary (tonal spot, the variant Android itself uses).
  static ColorScheme schemeFor(Brightness brightness, ColorScheme? dynamic) {
    if (dynamic == null) {
      return ColorScheme.fromSeed(
        seedColor: const Color(0xFF6750A4),
        brightness: brightness,
        dynamicSchemeVariant: DynamicSchemeVariant.expressive,
      );
    }
    final full = ColorScheme.fromSeed(
      seedColor: dynamic.primary,
      brightness: brightness,
    );
    return dynamic.copyWith(
      surface: full.surface,
      surfaceDim: full.surfaceDim,
      surfaceBright: full.surfaceBright,
      surfaceContainerLowest: full.surfaceContainerLowest,
      surfaceContainerLow: full.surfaceContainerLow,
      surfaceContainer: full.surfaceContainer,
      surfaceContainerHigh: full.surfaceContainerHigh,
      surfaceContainerHighest: full.surfaceContainerHighest,
      onSurface: full.onSurface,
      onSurfaceVariant: full.onSurfaceVariant,
      outlineVariant: full.outlineVariant,
    ).harmonized();
  }

  static ThemeData dark(ColorScheme? dynamicScheme) =>
      _build(schemeFor(Brightness.dark, dynamicScheme));

  static ThemeData light(ColorScheme? dynamicScheme) =>
      _build(schemeFor(Brightness.light, dynamicScheme));

  static ThemeData _build(ColorScheme scheme) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: scheme.brightness,
      fontFamily: 'Roboto',
    );
    final text = base.textTheme;
    return base.copyWith(
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: scheme.secondaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) =>
            text.labelMedium?.copyWith(
              color: states.contains(WidgetState.selected)
                  ? scheme.onSurface
                  : scheme.onSurfaceVariant,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w500,
            )),
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
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        modalBackgroundColor: scheme.surfaceContainerLow,
        showDragHandle: true,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        space: 1,
        thickness: 1,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
        contentTextStyle:
            text.bodyMedium?.copyWith(color: scheme.onInverseSurface),
        actionTextColor: scheme.inversePrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
