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
const _kDockBottom = 8.0;    // gap between dock and safe area
const _kDockHorizontal = 20.0;
const _kDockRadius = 26.0;

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

  Widget _buildFloatingDock(ColorScheme scheme) {
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
                // Use a noticeably elevated surface so the pill stands out
                color: scheme.brightness == Brightness.dark
                    ? const Color(0xFF2C2C2E).withValues(alpha: 0.93)
                    : scheme.surfaceContainerHighest.withValues(alpha: 0.94),
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

    // Safe area bottom (home indicator / Android nav bar height).
    // viewPadding is never modified by Scaffold or any widget — it always
    // reflects the physical device inset.
    final safeBottom = MediaQuery.of(context).viewPadding.bottom;

    // Total vertical space the floating dock occupies (dock + gap + safe area).
    // Used to push the mini player up and pad the scroll content.
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

    final scaffold = Scaffold(
      // No bottomNavigationBar when floating — the body fills the full screen
      // so content renders behind the dock, enabling the blur effect.
      // The classic bar uses explicit height for a tighter look.
      bottomNavigationBar: floatingNav
          ? null
          : NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (i) =>
                  setState(() => _selectedIndex = i),
              backgroundColor: scheme.surface,
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
          // Main content — scroll padding keeps last items above the dock/player
          AnimatedPadding(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(
              bottom: hasSong ? 72.0 : 0.0,
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

          // Mini player — sits directly above the floating dock
          Positioned(
            left: 0,
            right: 0,
            bottom: dockBodyPad,
            child: AnimatedBuilder(
              animation: _playerAnim,
              builder: (_, child) => IgnorePointer(
                ignoring: _playerAnim.value > 0.1,
                child: Opacity(
                  opacity: (1 - _playerAnim.value * 5).clamp(0.0, 1.0),
                  child: child,
                ),
              ),
              child: MiniPlayer(onOpen: _openPlayer),
            ),
          ),
        ],
      ),
    );

    return Stack(
      children: [
        scaffold,

        // Floating dock — rendered above the scaffold so content is visible
        // behind it (enabling the BackdropFilter blur). Fades when the full
        // player opens.
        if (floatingNav)
          Positioned(
            bottom: safeBottom + _kDockBottom,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _playerAnim,
              builder: (_, child) => IgnorePointer(
                ignoring: _playerAnim.value > 0.1,
                child: Opacity(
                  opacity: (1 - _playerAnim.value * 5).clamp(0.0, 1.0),
                  child: child,
                ),
              ),
              child: _buildFloatingDock(scheme),
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
  final VoidCallback onTap;

  const _FloatingNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.scheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: selected ? scheme.secondaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.max,
            children: [
              Icon(
                selected ? selectedIcon : icon,
                size: 22,
                color: selected
                    ? scheme.onSecondaryContainer
                    : scheme.onSurfaceVariant,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.normal,
                  color: selected
                      ? scheme.onSecondaryContainer
                      : scheme.onSurfaceVariant,
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
