import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../home/home_screen.dart';
import '../library/library_screen.dart';
import '../search/search_screen.dart';
import '../settings/settings_screen.dart';
import '../player/mini_player.dart';
import '../player/now_playing_screen.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late final AnimationController _playerAnim;

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

  void _openPlayer() {
    _playerAnim.animateTo(
      1.0,
      curve: Curves.easeOutCubic,
      duration: const Duration(milliseconds: 450),
    );
  }

  void _closePlayer() {
    _playerAnim.animateTo(
      0.0,
      curve: Curves.easeOutCubic,
      duration: const Duration(milliseconds: 350),
    );
  }

  void _invalidateServerProviders() {
    ref.invalidate(allSongsProvider);
    ref.invalidate(newestAlbumsProvider);
    ref.invalidate(randomSongsProvider);
    ref.invalidate(allAlbumsProvider);
    ref.invalidate(allArtistsProvider);
    ref.invalidate(serverReachableProvider);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasSong = ref.watch(currentSongStreamProvider).valueOrNull != null;
    final screenH = MediaQuery.of(context).size.height;

    // Collapse player when the queue runs out
    ref.listen(currentSongStreamProvider, (prev, next) {
      if (prev?.valueOrNull != null && next.valueOrNull == null) {
        _playerAnim.value = 0;
      }
    });

    // Auto-invalidate all server providers when device comes back online
    ref.listen<AsyncValue<bool>>(isOnlineProvider, (prev, next) {
      final wasOnline = prev?.valueOrNull ?? true;
      final isNowOnline = next.valueOrNull ?? true;
      if (!wasOnline && isNowOnline) {
        _invalidateServerProviders();
      }
    });

    final scaffold = Scaffold(
      body: Stack(
        children: [
          // Main content — pad bottom only when mini player is visible
          AnimatedPadding(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(bottom: hasSong ? 72 : 0),
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

          // Mini player — fades out in first 20 % of the open animation
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        backgroundColor: scheme.surface,
        elevation: 0,
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
    );

    // Always use outer Stack so the connectivity banner overlays everything
    // (including the full player) regardless of hasSong state.
    return Stack(
      children: [
        scaffold,

        // Full player — only when a song is active
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
