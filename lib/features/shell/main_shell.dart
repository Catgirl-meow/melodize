import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../shared/utils/snack.dart';
import '../home/home_screen.dart';
import '../library/library_screen.dart';
import '../search/search_screen.dart';
import '../settings/settings_screen.dart';
import '../player/mini_player.dart';
import '../player/now_playing_screen.dart';

// Android-first Material 3 navigation geometry, shared by Android and Linux.
// Shared Android-first navigation geometry on every platform.
const _kDockHeight = 56.0;
const _kDockBottom = 12.0;
const _kDockHorizontal = 16.0;
const _kDockRadius = 24.0;
const _kPillRadius = 16.0;
const _kPillPadding = EdgeInsets.symmetric(horizontal: 8, vertical: 5);
const _kPillSlideDuration = Duration(milliseconds: 320);
// Starts moving on the tap and glides into place, without the near-jump of
// emphasized decelerate over a short distance.
const _kPillCurve = Curves.easeOutCubic;
// Mini player footprint, including its own bottom gap
// (floating: 56 card + 8 gap, classic: 72 bar).
const _kFloatingMiniPlayerHeight = 64.0;
const _kClassicMiniPlayerHeight = 72.0;

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell>
    with SingleTickerProviderStateMixin {
  // The selected tab lives in a notifier, not in this State: a setState here
  // rebuilt the whole shell on every tab switch, including the (hidden) Now
  // Playing screen and mini player, which made the first frames of the
  // switch drop. Only the dock / NavigationBar and the IndexedStack listen.
  final _tab = ValueNotifier<int>(0);
  late final AnimationController _playerAnim;
  // The shell's own messenger. MainShell's context sits *above* it, so
  // ScaffoldMessenger.of(context) would find the app's root messenger, which
  // has no Scaffold while the shell is showing, and every snack was dropped.
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();

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
    _tab.dispose();
    super.dispose();
  }

  bool _handleNavKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    // Only intercept when no text field is focused.
    final focus = FocusManager.instance.primaryFocus;
    if (focus?.context?.widget is EditableText) return false;

    switch (event.logicalKey) {
      case LogicalKeyboardKey.digit1:
        _tab.value = 0;
        return true;
      case LogicalKeyboardKey.digit2:
        _tab.value = 1;
        return true;
      case LogicalKeyboardKey.digit3:
        _tab.value = 2;
        return true;
      case LogicalKeyboardKey.digit4:
        _tab.value = 3;
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

  /// Map raw local-download error strings to user-friendly messages.
  String _friendlyLocalDownloadError(String err) {
    final lower = err.toLowerCase();
    if (lower.contains('timeout') || lower.contains('timed out')) {
      return 'Download timed out — check your connection and try again';
    }
    if (lower.contains('connection refused') ||
        lower.contains('connection error') ||
        lower.contains('socket')) {
      return 'Cannot reach server — check your connection';
    }
    if (lower.contains('401') || lower.contains('unauthorized')) {
      return 'Server rejected the request — check credentials in Settings';
    }
    if (lower.contains('404') || lower.contains('not found')) {
      return 'Song not found on server — it may have been removed';
    }
    if (lower.contains('403') || lower.contains('forbidden')) {
      return 'Access denied — check server permissions';
    }
    if (lower.contains('disk') ||
        lower.contains('space') ||
        lower.contains('storage')) {
      return 'Not enough storage space on device';
    }
    return 'Download failed — $err';
  }

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
  void _safeSnack(String msg, {bool isError = false, double? bottomOffset}) {
    final messenger = _messengerKey.currentState;
    if (messenger == null) return;
    try {
      showStyledSnack(context, msg,
          isError: isError, bottomOffset: bottomOffset, messenger: messenger);
    } catch (_) {}
  }

  Widget _buildFloatingDock(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _kDockHorizontal),
      child: Material(
        color: scheme.surfaceContainerHighest,
        elevation: 2,
        shadowColor: scheme.shadow.withValues(alpha: 0.36),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_kDockRadius),
          side: BorderSide(
            color: scheme.outline.withValues(alpha: 0.42),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: _kDockHeight,
          // One selection pill that slides to the selected tab. Each tab used
          // to fade its own pill in and out, so on every switch two
          // half-faded pills were on screen at once, and the fade went from
          // Colors.transparent (transparent *black*), which darkened both
          // pills mid-animation: the trail. The slow easeInOut start made the
          // tap feel late on top of that.
          child: ValueListenableBuilder<int>(
            valueListenable: _tab,
            builder: (_, selectedIndex, __) => Stack(
              children: [
                Positioned.fill(
                  child: AnimatedAlign(
                    alignment: Alignment(
                      -1 + 2 * selectedIndex / (_labels.length - 1),
                      0,
                    ),
                    duration: _kPillSlideDuration,
                    curve: _kPillCurve,
                    child: FractionallySizedBox(
                      widthFactor: 1 / _labels.length,
                      heightFactor: 1,
                      child: Padding(
                        padding: _kPillPadding,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: scheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(_kPillRadius),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (int i = 0; i < _labels.length; i++)
                      Expanded(
                        child: _FloatingNavItem(
                          icon: _icons[i],
                          selectedIcon: _selectedIcons[i],
                          label: _labels[i],
                          selected: i == selectedIndex,
                          scheme: scheme,
                          onTap: () => _tab.value = i,
                        ),
                      ),
                  ],
                ),
              ],
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

    final safeBottom = MediaQuery.of(context).viewPadding.bottom;
    final dockBodyPad =
        floatingNav ? _kDockHeight + _kDockBottom + safeBottom : 0.0;
    // Counteract the Scaffold body shrink when the keyboard opens so the
    // mini player doesn't fly up.  When keyboardInset >= dockBodyPad the
    // mini player sits at the body bottom (right above the keyboard).
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final miniPlayerBottom =
        (dockBodyPad - keyboardInset).clamp(0.0, dockBodyPad);

    // Height of the shell's overlays (dock + mini player) above the bottom of
    // the Scaffold body. Pages get it as MediaQuery padding.bottom so their
    // last list item can scroll clear of the overlays, and snackbars sit just
    // above the mini player instead of underneath it. In classic mode the
    // NavigationBar is a real bottomNavigationBar, so the body already ends
    // above it and only the mini player overlaps.
    final miniPlayerHeight = !hasSong
        ? 0.0
        : floatingNav
            ? _kFloatingMiniPlayerHeight
            : _kClassicMiniPlayerHeight;
    final overlayClearance =
        (floatingNav ? miniPlayerBottom : 0.0) + miniPlayerHeight;

    // Same height measured from where the Scaffold puts floating snackbars,
    // which is already above the system navigation inset in floating mode
    // and above the NavigationBar in classic mode.
    final snackBottom = floatingNav
        ? (overlayClearance - safeBottom).clamp(0.0, double.infinity)
        : overlayClearance;

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
                bottomOffset: snackBottom + kSnackGap);
          }
          // Surface on state transition into 'error' AND on errorMessage
          // change while already in 'error' (handles same-song re-failure
          // after the user retries — the second failure was previously
          // silent because status didn't change).
          final wasError = prevItem?.status == 'error';
          final isError = entry.value.status == 'error';
          final errMsgChanged =
              wasError && prevItem?.errorMessage != entry.value.errorMessage;
          if (isError && (!wasError || errMsgChanged)) {
            final errMsg = entry.value.errorMessage;
            final msg = errMsg != null
                ? _friendlyLocalDownloadError(errMsg)
                : '"${entry.value.song.title}" failed to download — try again';
            _safeSnack(msg,
                isError: true, bottomOffset: snackBottom + kSnackGap);
          }
        }
      });
    });

    // Navigation chrome uses stable Material 3 tonal colors, independent of
    // the currently playing album art.
    final navBg = scheme.surfaceContainer;

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
          : ValueListenableBuilder<int>(
              valueListenable: _tab,
              builder: (_, selectedIndex, __) => NavigationBar(
                selectedIndex: selectedIndex,
                onDestinationSelected: (i) => _tab.value = i,
                backgroundColor: navBg,
                indicatorColor: scheme.secondaryContainer,
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
            ),
      body: Stack(
        children: [
          // Content scrolls *behind* the overlays (no painted dead zone), but
          // pages see the overlay height as padding.bottom so the end of
          // every list can still scroll into view above the mini player.
          //
          // The view insets are removed because this Scaffold already shrank
          // the body for the keyboard; the pages' own Scaffolds would
          // otherwise shrink a second time, squashing Search results into a
          // sliver when the keyboard is open.
          MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: MediaQuery.of(context).padding.copyWith(
                    bottom: overlayClearance,
                  ),
              viewInsets: MediaQuery.of(context).viewInsets.copyWith(
                    bottom: 0,
                  ),
            ),
            child: SnackInset(
              bottom: snackBottom,
              child: ValueListenableBuilder<int>(
                valueListenable: _tab,
                builder: (_, selectedIndex, child) => IndexedStack(
                  index: selectedIndex,
                  children: const [
                    RepaintBoundary(child: HomeScreen()),
                    RepaintBoundary(child: LibraryScreen()),
                    RepaintBoundary(child: SearchScreen()),
                    RepaintBoundary(child: SettingsScreen()),
                  ],
                ),
              ),
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
        key: _messengerKey,
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
              child: _buildFloatingDock(scheme),
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
              // Own messenger + transparent Scaffold: snacks raised from the
              // player show on the player. Through the shell's messenger they
              // landed on the shell Scaffold *behind* the player and popped
              // up over the list only after the player was closed.
              child: RepaintBoundary(
                child: ScaffoldMessenger(
                  child: Scaffold(
                    backgroundColor: Colors.transparent,
                    resizeToAvoidBottomInset: false,
                    body: NowPlayingScreen(
                      controller: _playerAnim,
                      onClose: _closePlayer,
                    ),
                  ),
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
    // The pill itself is drawn once by the dock and slides between tabs;
    // the item only swaps its icon and tints it.
    final color =
        selected ? scheme.onSecondaryContainer : scheme.onSurfaceVariant;

    // Icon-only dock: the tooltip names the tab on hover (desktop) and long
    // press (Android).
    return Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkWell(
          onTap: onTap,
          splashFactory: NoSplash.splashFactory,
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          borderRadius: BorderRadius.circular(_kPillRadius),
          child: Padding(
            padding: _kPillPadding,
            child: Center(
              child: TweenAnimationBuilder<Color?>(
                tween: ColorTween(end: color),
                duration: _kPillSlideDuration,
                curve: _kPillCurve,
                builder: (_, c, __) => Icon(
                  selected ? selectedIcon : icon,
                  size: 26,
                  color: c,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
