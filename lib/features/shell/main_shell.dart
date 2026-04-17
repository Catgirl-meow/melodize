import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/utils/snack.dart';
import '../home/home_screen.dart';
import '../library/library_screen.dart';
import '../search/search_screen.dart';
import '../settings/settings_screen.dart';
import '../player/mini_player.dart';
import '../player/now_playing_screen.dart';

// Floating dock geometry
const _kDockHeight = 52.0;
const _kDockBottom = 8.0;      // gap between dock bottom and safe area edge
const _kDockHorizontal = 20.0;
const _kDockRadius = 16.0;     // shared by dock corners AND selection pill

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late final AnimationController _playerAnim;

  static const _icons = [
    Icons.home_outlined,
    Icons.library_music_outlined,
    Icons.search_rounded,
    Icons.settings_outlined,
  ];
  static const _selectedIcons = [
    Icons.home_rounded,
    Icons.library_music_rounded,
    Icons.search_rounded,
    Icons.settings_rounded,
  ];
  static const _labels = ['Home', 'Library', 'Search', 'Settings'];

  @override
  void initState() {
    super.initState();
    _playerAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    HardwareKeyboard.instance.addHandler(_handleNavKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleNavKey);
    _playerAnim.dispose();
    super.dispose();
  }

  bool _handleNavKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    // Only intercept when no text field is focused.
    final focus = FocusManager.instance.primaryFocus;
    if (focus?.context?.widget is EditableText) return false;

    switch (event.logicalKey) {
      case LogicalKeyboardKey.digit1:
        setState(() => _selectedIndex = 0);
        return true;
      case LogicalKeyboardKey.digit2:
        setState(() => _selectedIndex = 1);
        return true;
      case LogicalKeyboardKey.digit3:
        setState(() => _selectedIndex = 2);
        return true;
      case LogicalKeyboardKey.digit4:
        setState(() => _selectedIndex = 3);
        return true;
      case LogicalKeyboardKey.escape:
        if (_playerAnim.value > 0.01) {
          _closePlayer();
          return true;
        }
        return false;
    }
    return false;
  }

  void _openPlayer() => _playerAnim.animateTo(
        1.0,
        curve: Curves.easeOutCubic,
        duration: const Duration(milliseconds: 450),
      );

  void _closePlayer() => _playerAnim.animateTo(
        0.0,
        curve: Curves.easeOutCubic,
        duration: const Duration(milliseconds: 350),
      );

  void _invalidateServerProviders() {
    ref.invalidate(allSongsProvider);
    ref.invalidate(newestAlbumsProvider);
    ref.invalidate(randomSongsProvider);
    ref.invalidate(allAlbumsProvider);
    ref.invalidate(allArtistsProvider);
    ref.invalidate(serverReachableProvider);
  }

  Widget _buildFloatingDock(ColorScheme scheme, Color? accentColor) {
    final dockBg = AppTheme.dockBackground(accentColor, scheme);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _kDockHorizontal),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_kDockRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 28,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_kDockRadius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Container(
              height: _kDockHeight,
              decoration: BoxDecoration(
                color: dockBg,
                borderRadius: BorderRadius.circular(_kDockRadius),
              ),
              child: Row(
                children: [
                  for (int i = 0; i < _labels.length; i++)
                    Expanded(
                      child: _FloatingNavItem(
                        icon: _icons[i],
                        selectedIcon: _selectedIcons[i],
                        label: _labels[i],
                        selected: i == _selectedIndex,
                        scheme: scheme,
                        accentColor: accentColor,
                        onTap: () => setState(() => _selectedIndex = i),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasSong = ref.watch(
      currentSongStreamProvider.select((s) => s.valueOrNull != null),
    );
    final screenH = MediaQuery.of(context).size.height;
    final floatingNav = ref.watch(
      preferencesNotifierProvider.select((p) => p.floatingNavBar),
    );
    // Accent color from album art — null until PaletteGenerator resolves.
    final accentColor = hasSong ? ref.watch(currentAccentColorProvider) : null;

    final safeBottom = MediaQuery.of(context).viewPadding.bottom;
    final dockBodyPad =
        floatingNav ? _kDockHeight + _kDockBottom + safeBottom : 0.0;

    // Full clearance needed to position a snackbar above the dock + mini player.
    // Used for ref.listen callbacks whose BuildContext sits outside the inner
    // MediaQuery override, so they can't rely on padding.bottom auto-resolution.
    final snackBottom = (hasSong ? 72.0 : 0.0) +
        (floatingNav
            ? _kDockHeight + _kDockBottom + safeBottom
            : 62.0 + safeBottom);

    // Collapse player when the queue runs out.
    ref.listen(currentSongStreamProvider, (prev, next) {
      if (prev?.valueOrNull != null && next.valueOrNull == null) {
        _playerAnim.value = 0;
      }
    });

    ref.listen<AsyncValue<bool>>(isOnlineProvider, (prev, next) {
      final wasOnline = prev?.valueOrNull ?? true;
      final isNowOnline = next.valueOrNull ?? true;
      if (!wasOnline && isNowOnline) _invalidateServerProviders();
    });

    // Surface local download completion and errors as snackbars.
    ref.listen<Map<String, DownloadItem>>(downloadNotifierProvider,
        (prev, next) {
      if (prev == null) return;
      for (final entry in next.entries) {
        final prevItem = prev[entry.key];
        if (prevItem?.status != 'done' && entry.value.status == 'done') {
          showStyledSnack(
            context,
            '"${entry.value.song.title}" downloaded',
            bottomOffset: snackBottom + 12,
          );
        }
        if (prevItem?.status != 'error' && entry.value.status == 'error') {
          final errMsg = entry.value.errorMessage;
          final msg = errMsg != null
              ? 'Download failed: $errMsg'
              : '"${entry.value.song.title}" failed to download';
          showStyledSnack(context, msg,
              isError: true, bottomOffset: snackBottom + 12);
        }
      }
    });

    // Classic dock accent color
    final navBg = accentColor != null
        ? Color.lerp(accentColor, scheme.surface, 0.88)!
        : scheme.surface;
    final navIndicator = accentColor != null
        ? accentColor.withValues(alpha: 0.30)
        : null; // use theme default

    final scaffold = Scaffold(
      // extendBodyBehindAppBar: body fills behind the status bar so the
      // ColoredBox(scheme.surface) covers that area with the same tint as the
      // rest of the app — no visible black/tinted discontinuity around the
      // camera cutout or Island.
      // backgroundColor: transparent because the body's ColoredBox covers the
      // entire screen; the scaffold background is never visible.
      // extendBody only in floating-dock mode so the classic-mode mini player
      // at bottom:0 sits correctly above the NavigationBar.
      extendBodyBehindAppBar: true,
      extendBody: floatingNav,
      backgroundColor: Colors.transparent,
      bottomNavigationBar: floatingNav
          ? null
          : NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (i) =>
                  setState(() => _selectedIndex = i),
              backgroundColor: navBg,
              indicatorColor: navIndicator,
              elevation: 0,
              height: 62,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.library_music_outlined),
                  selectedIcon: Icon(Icons.library_music_rounded),
                  label: 'Library',
                ),
                NavigationDestination(
                  icon: Icon(Icons.search_rounded),
                  selectedIcon: Icon(Icons.search_rounded),
                  label: 'Search',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings_rounded),
                  label: 'Settings',
                ),
              ],
            ),
      body: Stack(
        children: [
          // Surface fill — covers the full body including the status bar /
          // camera cutout region so no window-background colour bleeds through.
          // NowPlayingScreen's full-bleed gradient paints on top of this when
          // the player is open.
          ColoredBox(color: scheme.surface, child: const SizedBox.expand()),


          // Content fills the full body with no shell-level bottom padding so
          // the dock and mini player overlay actual content (giving the
          // frosted-glass effect).  MediaQuery injection tells child scroll
          // views how much bottom clearance to reserve via SafeArea / ListView
          // default padding so the last item is always scrollable above the dock.
          MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: MediaQuery.of(context).padding.copyWith(
                bottom: (floatingNav ? dockBodyPad : 0.0) +
                    (hasSong ? 72.0 : 0.0),
              ),
            ),
            child: IndexedStack(
              index: _selectedIndex,
              children: const [
                RepaintBoundary(child: HomeScreen()),
                RepaintBoundary(child: LibraryScreen()),
                RepaintBoundary(child: SearchScreen()),
                RepaintBoundary(child: SettingsScreen()),
              ],
            ),
          ),

          // Mini player — sits directly above the floating dock.
          // Removed from the layer tree once invisible so its BackdropFilter
          // doesn't add GPU compositing cost while the full player is open.
          Positioned(
            left: 0,
            right: 0,
            bottom: dockBodyPad,
            child: AnimatedBuilder(
              animation: _playerAnim,
              builder: (_, child) {
                final opacity = (1 - _playerAnim.value * 5).clamp(0.0, 1.0);
                if (opacity == 0.0) return const SizedBox.shrink();
                return IgnorePointer(
                  ignoring: _playerAnim.value > 0.1,
                  child: Opacity(opacity: opacity, child: child!),
                );
              },
              child: MiniPlayer(onOpen: _openPlayer),
            ),
          ),
        ],
      ),
    );

    return MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(padding: MediaQuery.of(context).padding.copyWith(bottom: snackBottom)),
      child: ScaffoldMessenger(
      child: Stack(
      children: [
        scaffold,

        // Floating dock — removed from the layer tree once invisible so the
        // BackdropFilter doesn't force GPU compositing during player modals.
        if (floatingNav)
          Positioned(
            bottom: safeBottom + _kDockBottom,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _playerAnim,
              builder: (_, child) {
                final opacity = (1 - _playerAnim.value * 5).clamp(0.0, 1.0);
                if (opacity == 0.0) return const SizedBox.shrink();
                return IgnorePointer(
                  ignoring: _playerAnim.value > 0.1,
                  child: Opacity(opacity: opacity, child: child!),
                );
              },
              child: _buildFloatingDock(scheme, accentColor),
            ),
          ),

        // Black underlay fades in as the player opens to prevent the scaffold
        // content from showing through before the player gradient covers it.
        if (hasSong)
          AnimatedBuilder(
            animation: _playerAnim,
            builder: (_, __) => IgnorePointer(
              ignoring: true,
              child: Opacity(
                opacity: _playerAnim.value.clamp(0.0, 1.0),
                child: const ColoredBox(
                    color: Colors.black, child: SizedBox.expand()),
              ),
            ),
          ),

        // Full player
        if (hasSong)
          AnimatedBuilder(
            animation: _playerAnim,
            builder: (_, child) {
              final t = _playerAnim.value;
              return IgnorePointer(
                ignoring: t < 0.01,
                child: Transform.translate(
                  offset: Offset(0, screenH * (1 - t)),
                  child: child,
                ),
              );
            },
            // Reset padding to raw system insets so the player's SafeArea only
            // respects the notch/home-indicator, not the inflated snack clearance.
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(
                padding: MediaQuery.of(context).viewPadding,
              ),
              child: RepaintBoundary(
                child: NowPlayingScreen(
                  controller: _playerAnim,
                  onClose: _closePlayer,
                ),
              ),
            ),
          ),
      ],
      ))); // Stack / ScaffoldMessenger / MediaQuery
  }
}

// ---------------------------------------------------------------------------

class _FloatingNavItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final ColorScheme scheme;
  final Color? accentColor;
  final VoidCallback onTap;

  const _FloatingNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.scheme,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Selection pill colour: accent when available, else system secondary container.
    final pillColor = selected
        ? (accentColor != null
            ? accentColor!.withValues(alpha: 0.42)
            : scheme.secondaryContainer)
        : Colors.transparent;

    // Icon/label colour on the pill: white on accent (always dark dock bg),
    // else the standard onSecondaryContainer token.
    final activeColor = accentColor != null
        ? Colors.white
        : scheme.onSecondaryContainer;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        // vertical: 7 — pill is shorter than dock height, making it pill-like;
        // same _kDockRadius is used for both dock and pill corners.
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: pillColor,
            borderRadius: BorderRadius.circular(_kDockRadius),
          ),
          child: Center(
            child: Icon(
              selected ? selectedIcon : icon,
              size: 26,
              color: selected ? activeColor : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
