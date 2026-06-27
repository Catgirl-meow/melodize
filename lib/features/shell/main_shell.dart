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

const _kDockRadius = 16.0;     // dock corners — matches mini player playing state
// Pill is 38 px tall (dock 52 − 2×7 vertical padding). Radius = height/2 so it
// renders as a true stadium, not a smaller rounded rectangle. Decoupled from
// the dock radius on purpose — same radius on nested shapes reads as "mini
// dock inside dock" instead of a distinct selection indicator.
const _kPillRadius = 19.0;

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

  // Snack with a try/catch fallback for the one rare case the deferred
  // post-frame callback still fires against a ScaffoldMessenger whose
  // scaffold list is empty (e.g. during shell rebuild). Losing the snack
  // is fine; crashing the UI is not.
  void _safeSnack(String msg,
      {bool isError = false, double? bottomOffset}) {
    try {
      showStyledSnack(context, msg,
          isError: isError, bottomOffset: bottomOffset);
    } catch (_) {}
  }

  Widget _buildFloatingDock(ColorScheme scheme, Color? accentColor) {
    final dockBg = AppTheme.dockBackground(accentColor, scheme);

    // Outer horizontal padding creates spacing from screen edges. The internal
    // nav items provide their own pill indicator padding.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _kDockHorizontal),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: dockBg,
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
    // Counteract the Scaffold body shrink when the keyboard opens so the
    // mini player doesn't fly up.  When keyboardInset >= dockBodyPad the
    // mini player sits at the body bottom (right above the keyboard).
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final miniPlayerBottom =
        (dockBodyPad - keyboardInset).clamp(0.0, dockBodyPad);

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
    //
    // Listener runs with MainShell's own context, which is above the
    // Scaffold. If a DownloadNotifier state change fires synchronously
    // during a navigation transition, the Scaffold child hasn't
    // registered with the root ScaffoldMessenger yet and
    // showSnackBar asserts `_scaffolds.isNotEmpty`. Defer to after the
    // current frame and swallow the assertion defensively — dropping a
    // snack is strictly better than crashing the UI thread.
    ref.listen<Map<String, DownloadItem>>(downloadNotifierProvider,
        (prev, next) {
      if (prev == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        for (final entry in next.entries) {
          final prevItem = prev[entry.key];
          if (prevItem?.status != 'done' && entry.value.status == 'done') {
            _safeSnack('"${entry.value.song.title}" downloaded',
                bottomOffset: snackBottom + 12);
          }
          // Surface on state transition into 'error' AND on errorMessage
          // change while already in 'error' (handles same-song re-failure
          // after the user retries — the second failure was previously
          // silent because status didn't change).
          final wasError = prevItem?.status == 'error';
          final isError = entry.value.status == 'error';
          final errMsgChanged = wasError &&
              prevItem?.errorMessage != entry.value.errorMessage;
          if (isError && (!wasError || errMsgChanged)) {
            final errMsg = entry.value.errorMessage;
            final msg = errMsg != null
                ? 'Download failed: $errMsg'
                : '"${entry.value.song.title}" failed to download';
            _safeSnack(msg, isError: true, bottomOffset: snackBottom + 12);
          }
        }
      });
    });

    // Navigation bar background subtly adapts to accent color when available.
    final navBg = accentColor != null
        ? Color.lerp(accentColor, scheme.surface, 0.88)!
        : scheme.surface;

    // Navigation indicator pill uses accent when available.
    final navIndicator = accentColor?.withValues(alpha: 0.30);

    final scaffold = Scaffold(
      // extendBodyBehindAppBar: body fills behind the status bar so the
      // Scaffold background covers the camera cutout area with the same tint
      // as the rest of the app — no visible black/tinted discontinuity around
      // the camera cutout or Island.
      // extendBody only in floating-dock mode so the classic-mode mini player
      // at bottom:0 sits correctly above the NavigationBar.
      extendBodyBehindAppBar: true,
      extendBody: floatingNav,
      backgroundColor: scheme.surface,
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
          // No shell-level MediaQuery bottom padding — content scrolls behind
          // the overlays so the 20px overlay margins reveal list items rather
          // than a painted background dead zone.
          MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: MediaQuery.of(context).padding.copyWith(
                bottom: MediaQuery.of(context).padding.bottom,
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

          // Mini player — sits above the dock (floating mode) or NavigationBar
          // (classic mode).  Uses viewInsets-adjusted positioning so the
          // keyboard can't push it around when the Scaffold body resizes.
          Positioned(
            left: 0,
            right: 0,
            bottom: miniPlayerBottom,
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

    return ScaffoldMessenger(
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
      )); // Stack / ScaffoldMessenger
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
    // Guard against light accents — white text on a light pill is invisible.
    final isLightAccent = accentColor != null &&
        ThemeData.estimateBrightnessForColor(accentColor!) == Brightness.light;
    final activeColor = accentColor != null && !isLightAccent
        ? Colors.white
        : scheme.onSecondaryContainer;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        // vertical 7 → pill is 38 tall; horizontal 10 gives the pill breathing
        // room inside its cell so it reads as an indicator, not a filled cell.
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: pillColor,
            borderRadius: BorderRadius.circular(_kPillRadius),
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
