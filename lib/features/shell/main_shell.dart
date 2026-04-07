import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
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
  }

  @override
  void dispose() {
    _playerAnim.dispose();
    super.dispose();
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
    final dockBg = accentColor != null
        ? (scheme.brightness == Brightness.dark
            ? Color.lerp(accentColor, const Color(0xFF1C1C1E), 0.58)!
                .withValues(alpha: 0.93)
            : Color.lerp(accentColor, Colors.white, 0.65)!
                .withValues(alpha: 0.94))
        : (scheme.brightness == Brightness.dark
            ? const Color(0xFF2C2C2E).withValues(alpha: 0.93)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.94));

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

    // Classic dock accent color
    final navBg = accentColor != null
        ? Color.lerp(accentColor, scheme.surface, 0.88)!
        : scheme.surface;
    final navIndicator = accentColor != null
        ? accentColor.withValues(alpha: 0.30)
        : null; // use theme default

    final scaffold = Scaffold(
      // extendBody + extendBodyBehindAppBar: body fills the entire screen
      // including behind the status bar and system nav bar.  The body's first
      // child (ColoredBox) provides the surface fill so the MaterialApp's
      // black root never bleeds through, even on AMOLED.
      extendBody: true,
      extendBodyBehindAppBar: true,
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
          // Surface fill — replaces scaffold backgroundColor so the body can
          // be transparent (needed for edgeToEdge status bar) without the
          // MaterialApp black root bleeding through on AMOLED.
          ColoredBox(color: scheme.surface, child: const SizedBox.expand()),

          // Main content — bottom padding accounts for both the floating dock
          // (when active) AND the mini player so the last item is always
          // reachable.  Classic dock mode only needs mini-player clearance.
          Padding(
            padding: EdgeInsets.only(
              bottom: (floatingNav ? dockBodyPad : 0.0) +
                  (hasSong ? 72.0 : 0.0),
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

    return Stack(
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
            child: RepaintBoundary(
              child: NowPlayingScreen(
                controller: _playerAnim,
                onClose: _closePlayer,
              ),
            ),
          ),
      ],
    );
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? selectedIcon : icon,
                size: 22,
                color: selected ? activeColor : scheme.onSurfaceVariant,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  color: selected ? activeColor : scheme.onSurfaceVariant,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
