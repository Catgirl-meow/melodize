import 'dart:async';
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

        // Connectivity banner — topmost layer, appears on all screens
        const _ConnectivityBanner(),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Connectivity banner
//
// • Device offline  → orange bar "No internet connection" slides in from top
// • Back online     → green bar "Back online" for 2 s, then slides out
// Manages its own timer state so the outer shell never rebuilds for it.

class _ConnectivityBanner extends ConsumerStatefulWidget {
  const _ConnectivityBanner();

  @override
  ConsumerState<_ConnectivityBanner> createState() =>
      _ConnectivityBannerState();
}

class _ConnectivityBannerState extends ConsumerState<_ConnectivityBanner> {
  // null  = hidden
  // true  = showing "No internet connection"
  // false = showing "Back online" (briefly)
  bool? _bannerState; // null=hidden, true=offline, false=reconnected
  Timer? _hideTimer;

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<bool>>(isOnlineProvider, (prev, next) {
      final wasOnline = prev?.valueOrNull ?? true;
      final isNowOnline = next.valueOrNull ?? true;

      if (!isNowOnline && wasOnline) {
        // Just went offline
        _hideTimer?.cancel();
        setState(() => _bannerState = true);
      } else if (isNowOnline && wasOnline == false) {
        // Just came back online — show "Back online" briefly
        _hideTimer?.cancel();
        setState(() => _bannerState = false);
        _hideTimer = Timer(const Duration(seconds: 2), () {
          if (mounted) setState(() => _bannerState = null);
        });
      }
    });

    final visible = _bannerState != null;
    final statusBarH = MediaQuery.of(context).padding.top;

    return Positioned(
      top: statusBarH,
      left: 0,
      right: 0,
      child: AnimatedSlide(
        offset: visible ? Offset.zero : const Offset(0, -1),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _bannerState == null
              ? const SizedBox.shrink()
              : _BannerContent(isOffline: _bannerState!),
        ),
      ),
    );
  }
}

class _BannerContent extends StatelessWidget {
  final bool isOffline;
  const _BannerContent({required this.isOffline});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey(isOffline),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 16),
      color: isOffline ? const Color(0xFFBF360C) : const Color(0xFF2E7D32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isOffline ? Icons.wifi_off_rounded : Icons.wifi_rounded,
            size: 14,
            color: Colors.white,
          ),
          const SizedBox(width: 6),
          Text(
            isOffline ? 'No internet connection' : 'Back online',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
