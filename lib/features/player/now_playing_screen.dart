import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../../core/models/song.dart';
import '../../core/providers.dart';
import '../../core/audio/shuffle_mode.dart';
import '../../shared/utils/download_polling_mixin.dart';
import '../../shared/utils/snack.dart';
import '../../shared/utils/song_actions.dart';
import '../../shared/widgets/cover_art_image.dart';
import 'queue_screen.dart';

// ---------------------------------------------------------------------------

class NowPlayingScreen extends ConsumerStatefulWidget {
  /// Drives the slide-up/down animation. 0.0 = off-screen, 1.0 = fully open.
  final AnimationController controller;
  final VoidCallback onClose;

  const NowPlayingScreen({
    super.key,
    required this.controller,
    required this.onClose,
  });

  @override
  ConsumerState<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends ConsumerState<NowPlayingScreen>
    with TickerProviderStateMixin {
  final _pageController = PageController();
  int _currentPage = 0;
  Timer? _sleepCountdown;
  // ValueNotifier isolates rebuilds to _BottomActions (sleep timer tick).
  final _sleepNotifier = ValueNotifier<Duration?>(null);
  // ValueNotifier isolates the drag-gesture disable to the wrapper only.
  final _sheetOpen = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _pageController.dispose();
    _sleepCountdown?.cancel();
    _sleepNotifier.dispose();
    _sheetOpen.dispose();
    super.dispose();
  }

  void _onVerticalDragStart(DragStartDetails _) {
    if (_currentPage != 0 || _sheetOpen.value) return;
    // Stop any in-progress open/close animation so drag takes over immediately.
    widget.controller.stop();
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (_currentPage != 0 || _sheetOpen.value) return;
    final screenH = MediaQuery.of(context).size.height;
    // Drag down (positive dy) decreases controller value toward 0 (off-screen).
    widget.controller.value -= details.delta.dy / screenH;
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (_currentPage != 0 || _sheetOpen.value) return;
    final vel = details.velocity.pixelsPerSecond.dy;
    if (widget.controller.value < 0.5 || vel > 600) {
      widget.onClose();
    } else {
      // Snap back to fully open.
      widget.controller.animateTo(
        1.0,
        curve: Curves.easeOutCubic,
        duration: const Duration(milliseconds: 300),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final songAsync = ref.watch(currentSongStreamProvider);
    final song = songAsync.valueOrNull;

    if (song == null) return const SizedBox.shrink();

    final coverUrl =
        ref.watch(coverArtUrlProvider(song.coverArt ?? '')) ??
        song.externalCoverUrl ??
        '';
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final bgBase = isDark ? Colors.black : Colors.white;

    final rawAccent =
        ref.watch(currentAccentColorProvider);
    final fg = foregroundAccentColor(rawAccent, scheme.brightness)
        ?? scheme.primary;
    final dominantColor = rawAccent ?? bgBase;

    final bgTop  = Color.lerp(dominantColor, bgBase, 0.52)!;
    final bgPeak = Color.lerp(dominantColor, bgBase, 0.10)!;
    final bgFade = Color.lerp(dominantColor, bgBase, 0.72)!;
    final bgGlow = dominantColor.withValues(alpha: isDark ? 0.42 : 0.15);

    // Rebuilds only the GestureDetector wrapper on sheet open/close.
    return ValueListenableBuilder<bool>(
      valueListenable: _sheetOpen,
      builder: (_, sheetOpen, child) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragStart: sheetOpen ? null : _onVerticalDragStart,
        onVerticalDragUpdate: sheetOpen ? null : _onVerticalDragUpdate,
        onVerticalDragEnd: sheetOpen ? null : _onVerticalDragEnd,
        child: child!,
      ),
      // Material(transparency) provides the Material ancestor Slider needs.
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        child: Material(
          type: MaterialType.transparency,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Base linear gradient
              AnimatedContainer(
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOut,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [bgTop, bgPeak, bgFade, bgBase],
                    stops: const [0.0, 0.32, 0.62, 1.0],
                  ),
                ),
              ),
              // Radial colour bloom — centred on the album-art zone
              AnimatedContainer(
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOut,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.28),
                    radius: 0.90,
                    colors: [bgGlow, Colors.transparent],
                  ),
                ),
              ),
              // Content
              SafeArea(
                child: Column(
                  children: [
                    _TopBar(
                      song: song,
                      onClose: widget.onClose,
                    ),
                    Expanded(
                      child: ScrollConfiguration(        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {
                            PointerDeviceKind.touch,
                            PointerDeviceKind.mouse,
                            PointerDeviceKind.trackpad,
                            PointerDeviceKind.stylus,
                          },
                        ),
                        child: PageView(
                          controller: _pageController,
                          onPageChanged: (p) =>
                              setState(() => _currentPage = p),
                          children: [
                            _PlayerPage(
                              fgAccent: fg,
                              song: song,
                              coverUrl: coverUrl,
                              sleepNotifier: _sleepNotifier,
                              onSleepTimer: () =>
                                  _showSleepTimerDialog(context),
                              onQueueOpen: () => _openQueue(context),
                              onLyricsOpen: () => _pageController.animateToPage(
                                1,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              ),
                            ),
                            _LyricsPage(song: song),
                          ],
                        ),
                      ),
                    ),
                    // Page indicator
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          2,
                          (i) => AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: _currentPage == i ? 20 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(3),
                              color: _currentPage == i
                                  ? scheme.onSurface
                                  : scheme.onSurface.withValues(alpha: 0.38),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openQueue(BuildContext context) {
    _sheetOpen.value = true;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: false, // _SlideDismiss owns the drag
      // Zero reverse duration — the sheet is already off-screen via Transform.
      sheetAnimationStyle: const AnimationStyle(reverseDuration: Duration.zero),
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      builder: (_) => const _SlideDismiss(
        child: RepaintBoundary(child: QueueScreen()),
      ),
    ).whenComplete(() {
      if (mounted) _sheetOpen.value = false;
    });
  }

  void _showSleepTimerDialog(BuildContext context) {
    final handler = ref.read(audioHandlerNotifierProvider);
    if (handler == null) return;

    _sheetOpen.value = true;
    showModalBottomSheet(
      context: context,
      barrierColor: Colors.transparent,
      backgroundColor: Colors.transparent,
      enableDrag: false,
      sheetAnimationStyle: const AnimationStyle(reverseDuration: Duration.zero),
      builder: (_) {
        final scheme = Theme.of(context).colorScheme;
        return _SlideDismiss(child: Material(
          color: scheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          clipBehavior: Clip.hardEdge,
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Sleep Timer',
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                if (handler.hasSleepTimer)
                  ListTile(
                    leading:
                        Icon(Icons.timer_off_rounded, color: scheme.error),
                    title: const Text('Cancel timer'),
                    onTap: () {
                      handler.cancelSleepTimer();
                      _sleepCountdown?.cancel();
                      Navigator.pop(context);
                      _sleepNotifier.value = null;
                    },
                  ),
                for (final minutes in [15, 30, 45, 60])
                  ListTile(
                    leading: const Icon(Icons.bedtime_rounded),
                    title: Text('$minutes minutes'),
                    onTap: () {
                      final dur = Duration(minutes: minutes);
                      handler.setSleepTimer(dur);
                      Navigator.pop(context);
                      _startSleepCountdown(dur);
                    },
                  ),
              ],
            ),
          ),
        ));
      },
    ).whenComplete(() {
      if (mounted) _sheetOpen.value = false;
    });
  }

  void _startSleepCountdown(Duration initial) {
    _sleepCountdown?.cancel();
    _sleepNotifier.value = initial;
    _sleepCountdown = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      final remaining = _sleepNotifier.value;
      if (remaining == null || remaining.inSeconds <= 0) {
        t.cancel();
        _sleepNotifier.value = null;
        return;
      }
      _sleepNotifier.value = Duration(seconds: remaining.inSeconds - 1);
    });
  }
}

// Drag-to-dismiss bottom-sheet wrapper. Replaces Flutter's built-in drag
// to avoid the velocity-mismatch stutter between pointer and physics.
class _SlideDismiss extends StatefulWidget {
  final Widget child;
  const _SlideDismiss({required this.child});

  @override
  State<_SlideDismiss> createState() => _SlideDismissState();
}

class _SlideDismissState extends State<_SlideDismiss>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  final _dy = ValueNotifier<double>(0.0);
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _dy.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  void _onUpdate(DragUpdateDetails d) {
    if (_dismissing) return;
    _ctrl.stop();
    final next = _dy.value + d.delta.dy;
    if (next < 0) return; // don't let user drag upward
    _dy.value = next;
  }

  void _onEnd(DragEndDetails d) {
    if (_dismissing) return;
    final screenH = MediaQuery.of(context).size.height;
    final vel = d.velocity.pixelsPerSecond.dy;
    if (_dy.value > screenH * 0.22 || vel > 500) {
      _animateOut(vel, screenH);
    } else {
      _snapBack();
    }
  }

  void _animateOut(double vel, double screenH) {
    _dismissing = true;
    final remaining = screenH - _dy.value;
    final ms = (remaining / math.max(vel, 600) * 1000).clamp(80.0, 280.0).round();
    final anim = Tween<double>(begin: _dy.value, end: screenH).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeIn),
    );
    _ctrl
      ..duration = Duration(milliseconds: ms)
      ..reset();
    late final VoidCallback listener;
    listener = () { _dy.value = anim.value; };
    _ctrl.addListener(listener);
    _ctrl.forward().whenComplete(() {
      _ctrl.removeListener(listener);
      if (mounted) Navigator.of(context).pop();
    });
  }

  void _snapBack() {
    final startDy = _dy.value;
    final anim = Tween<double>(begin: startDy, end: 0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    _ctrl
      ..duration = const Duration(milliseconds: 240)
      ..reset();
    late final VoidCallback listener;
    listener = () { _dy.value = anim.value; };
    _ctrl.addListener(listener);
    _ctrl.forward().whenComplete(() {
      _ctrl.removeListener(listener);
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragUpdate: _onUpdate,
      onVerticalDragEnd: _onEnd,
      child: ValueListenableBuilder<double>(
        valueListenable: _dy,
        builder: (_, dy, child) => Transform.translate(
          offset: Offset(0, dy),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _TopBar extends ConsumerStatefulWidget {
  final Song song;
  final VoidCallback onClose;
  const _TopBar({required this.song, required this.onClose});

  @override
  ConsumerState<_TopBar> createState() => _TopBarState();
}

class _TopBarState extends ConsumerState<_TopBar> with DownloadPollingMixin {
  Song get song => widget.song;

  @override
  double? get snackBottomOffset => _snackBottom();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 28),
            color: scheme.onSurface,
            onPressed: widget.onClose,
          ),
          const Spacer(),
          Text('Now Playing',
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: scheme.onSurface.withValues(alpha: 0.7))),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.more_vert_rounded),
            color: scheme.onSurface,
            onPressed: _showMoreOptions,
          ),
        ],
      ),
    );
  }

  // Preview tracks from recommendations are not in the Subsonic library.
  bool get _isPreview =>
      song.externalStreamUrl != null || song.id.startsWith('deezer:');

  void _showMoreOptions() {
    final downloadedIds = ref.read(downloadedSongIdsProvider);
    final isDownloaded = downloadedIds.contains(song.id) || song.isDownloaded;
    final canUseCompanion = ref.read(canDeleteFromServerProvider);
    final isPreview = _isPreview;
    final scheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Song header — confirms which track the menu acts on.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  CoverArtImage(
                    coverArtId: song.coverArt,
                    externalUrl: song.externalCoverUrl,
                    size: 44,
                    borderRadius: 8,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        Text(song.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12,
                                color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            const SizedBox(height: 4),
            ListTile(
              leading: const Icon(Icons.queue_music_rounded),
              title: const Text('Play next'),
              onTap: () {
                ref.read(audioHandlerNotifierProvider)?.playNext(song);
                Navigator.pop(sheetCtx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome_rounded),
              title: const Text('More like this'),
              subtitle:
                  const Text('Rebuild recommendations from this track'),
              onTap: () {
                Navigator.pop(sheetCtx);
                _moreLikeThis();
              },
            ),
            if (isPreview && canUseCompanion)
              ListTile(
                leading: const Icon(Icons.library_add_rounded),
                title: const Text('Add to library'),
                subtitle: const Text('Download to Navidrome server'),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _addToLibraryViaCompanion();
                },
              ),
            if (!isPreview && !isDownloaded)
              ListTile(
                leading: const Icon(Icons.download_rounded),
                title: const Text('Download'),
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  await startLocalDownload(ref, song);
                },
              ),
            if (!isPreview && isDownloaded)
              ListTile(
                leading: Icon(Icons.download_done_rounded,
                    color: scheme.primary),
                title: const Text('Downloaded'),
                enabled: false,
              ),
            if (!isPreview && canUseCompanion)
              ListTile(
                leading: Icon(Icons.delete_forever_rounded,
                    color: scheme.error),
                title: Text('Delete from server',
                    style: TextStyle(color: scheme.error)),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  confirmAndDeleteSong(context, ref, song);
                },
              ),
          ],
        ),
      ),
    );
  }

  // Compute snack offset above mini player + dock (player is outside shell MediaQuery).
  double _snackBottom() {
    final floatingNav = ref.read(
      preferencesNotifierProvider.select((p) => p.floatingNavBar),
    );
    final safeBottom = MediaQuery.of(context).viewPadding.bottom;
    const kDockHeight = 52.0;
    const kDockBottom = 8.0;
    final dockPad = floatingNav
        ? kDockHeight + kDockBottom + safeBottom
        : 62.0 + safeBottom;
    const miniPlayerHeight = 72.0;
    return dockPad + miniPlayerHeight + 12;
  }

  void _snack(String msg, {bool isError = false}) =>
      showStyledSnack(context, msg,
          isError: isError, bottomOffset: _snackBottom());

  void _moreLikeThis() {
    ref.read(recommendationsSeedOverrideProvider.notifier).state = (
      artist: song.artist,
      title: song.title,
      genre: song.genre,
    );
    ref.invalidate(recommendationsProvider);
    _snack('Refreshing recommendations from "${song.title}"');
  }

  Future<void> _addToLibraryViaCompanion() async {
    final companion = ref.read(companionClientProvider);
    if (companion == null) {
      _snack('Companion not configured — set it up in Settings',
          isError: true);
      return;
    }
    final prefs = ref.read(preferencesNotifierProvider);

    if (!song.id.startsWith('deezer:')) {
      _snack('No Deezer source for this track', isError: true);
      return;
    }
    final deezerTrackId = song.id.substring('deezer:'.length);
    final url = 'https://www.deezer.com/track/$deezerTrackId';

    if (!prefs.hasDeezerArl) {
      _snack('Add Deezer ARL in Settings — required for server downloads',
          isError: true);
      return;
    }
    final arlStatus = ref.read(deezerArlStatusProvider).valueOrNull;
    if (arlStatus == DeezerArlStatus.invalid) {
      _snack('Deezer session expired — update ARL in Settings',
          isError: true);
      return;
    }
    if (arlStatus == DeezerArlStatus.unreachable) {
      _snack('Can\'t verify Deezer session — download will attempt anyway');
    }

    _snack('Sending to server (FLAC)…');

    try {
      final jobId = await companion.startDownload(url, deezerArl: prefs.deezerArl);
      if (!mounted) return;
      startDownloadPolling(companion, jobId);
    } catch (e) {
      if (!mounted) return;
      _snack('Download could not start — check companion connection', isError: true);
    }
  }
}

class _PlayerPage extends StatelessWidget {
  final Color fgAccent;
  final Song song;
  final String coverUrl;
  final ValueNotifier<Duration?> sleepNotifier;
  final VoidCallback onSleepTimer;
  final VoidCallback onQueueOpen;
  final VoidCallback onLyricsOpen;

  const _PlayerPage({
    required this.fgAccent,
    required this.song,
    required this.coverUrl,
    required this.sleepNotifier,
    required this.onSleepTimer,
    required this.onQueueOpen,
    required this.onLyricsOpen,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final artSize = math.min(size.width * 0.8, size.height * 0.40);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const Spacer(flex: 1),
          RepaintBoundary(
            child: _AlbumArt(coverUrl: coverUrl, artSize: artSize),
          ),
          const Spacer(flex: 2),
          _SongInfoRow(song: song, fgAccent: fgAccent),
          const SizedBox(height: 16),
          const RepaintBoundary(child: _SeekSlider()),
          if (Platform.isLinux) ...[
            const SizedBox(height: 8),
            const RepaintBoundary(child: _VolumeSlider()),
          ],
          const SizedBox(height: 4),
          const RepaintBoundary(child: _PlayControls()),
          const SizedBox(height: 12),
          RepaintBoundary(
            child: _BottomActions(
              fg: fgAccent,
              sleepNotifier: sleepNotifier,
              onSleepTimer: onSleepTimer,
              onQueueOpen: onQueueOpen,
              onLyricsOpen: onLyricsOpen,
            ),
          ),
          const Spacer(flex: 1),
        ],
      ),
    );
  }
}

class _AlbumArt extends ConsumerWidget {
  final String coverUrl;
  final double artSize;
  const _AlbumArt({required this.coverUrl, required this.artSize});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final isPlaying = ref.watch(
      playerStateStreamProvider.select((s) => s.valueOrNull?.playing ?? false),
    );
    final w = isPlaying ? artSize : artSize * 0.85;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: w,
      height: w,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.5)
                : Colors.black.withValues(alpha: 0.12),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: coverUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: coverUrl,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _placeholder(scheme),
              )
            : _placeholder(scheme),
      ),
    );
  }

  Widget _placeholder(ColorScheme scheme) {
    return Container(
      color: scheme.surfaceContainerHighest,
      child: Icon(Icons.music_note_rounded,
          size: 80, color: scheme.onSurface.withValues(alpha: 0.38)),
    );
  }
}

// ---------------------------------------------------------------------------

class _SongInfoRow extends StatelessWidget {
  final Song song;
  final Color fgAccent;
  const _SongInfoRow({required this.song, required this.fgAccent});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                song.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Text(
                song.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.7),
                    ),
              ),
            ],
          ),
        ),
          if (song.suffix != null)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: fgAccent.withValues(alpha: 0.12),
              border: Border.all(color: fgAccent.withValues(alpha: 0.4)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              song.suffix!.toUpperCase(),
              style: TextStyle(
                  color: fgAccent,
                  fontSize: 10,
                  fontWeight: FontWeight.bold),
            ),
          ),
      ],
    );
  }
}

class _SeekSlider extends ConsumerStatefulWidget {
  const _SeekSlider();

  @override
  ConsumerState<_SeekSlider> createState() => _SeekSliderState();
}

class _SeekSliderState extends ConsumerState<_SeekSlider> {
  bool _isDragging = false;
  double _sliderValue = 0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = ref.watch(currentAccentColorProvider);
    final fg = foregroundAccentColor(accent, scheme.brightness)
        ?? scheme.primary;
    final position = ref.watch(
      positionStreamProvider.select((s) => s.valueOrNull ?? Duration.zero),
    );
    final duration = ref.watch(
      durationStreamProvider.select((s) => s.valueOrNull),
    );

    final progress = (duration != null && duration.inMilliseconds > 0)
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            thumbShape:
                const RoundSliderThumbShape(enabledThumbRadius: 6),
            trackHeight: 3,
            activeTrackColor: fg,
            inactiveTrackColor: scheme.surfaceContainerHighest,
            thumbColor: fg,
            overlayShape: SliderComponentShape.noOverlay,
          ),
          child: Slider(
            value: _isDragging ? _sliderValue : progress.toDouble(),
            onChangeStart: (v) =>
                setState(() { _isDragging = true; _sliderValue = v; }),
            onChanged: (v) => setState(() => _sliderValue = v),
            onChangeEnd: (v) {
              setState(() => _isDragging = false);
              final handler = ref.read(audioHandlerNotifierProvider);
              final dur = ref.read(durationStreamProvider).valueOrNull;
              if (handler != null && dur != null) {
                handler.seek(Duration(
                    milliseconds: (v * dur.inMilliseconds).round()));
              }
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_fmt(position),
                  style: TextStyle(
                      color: scheme.onSurfaceVariant, fontSize: 12)),
              Text(_fmt(duration ?? Duration.zero),
                  style: TextStyle(
                      color: scheme.onSurfaceVariant, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

class _PlayControls extends ConsumerWidget {
  const _PlayControls();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final accent = ref.watch(currentAccentColorProvider);
    final fg = foregroundAccentColor(accent, scheme.brightness)
        ?? scheme.primary;
    final isPlaying = ref.watch(
      playerStateStreamProvider.select((s) => s.valueOrNull?.playing ?? false),
    );
    final shuffleMode = ref.watch(
      shuffleModeStreamProvider.select((s) => s.valueOrNull ?? ShuffleMode.off),
    );
    final loopMode = ref.watch(
      loopModeStreamProvider.select((s) => s.valueOrNull ?? LoopMode.off),
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          icon: Icon(
            shuffleMode == ShuffleMode.smartShuffle
                ? Icons.auto_awesome_rounded
                : Icons.shuffle_rounded,
            color: shuffleMode != ShuffleMode.off
                ? fg
                : scheme.onSurface.withValues(alpha: 0.38),
          ),
          iconSize: 26,
          onPressed: () async {
            final h = ref.read(audioHandlerNotifierProvider);
            if (h == null) return;
            await h.toggleShuffle();
            // Persist the new mode.
            final prefsNotifier = ref.read(preferencesNotifierProvider.notifier);
            final current = ref.read(preferencesNotifierProvider);
            await prefsNotifier.update(current.copyWith(
              shuffleMode: h.currentShuffleMode.name,
            ));
          },
        ),
        IconButton(
          icon: Icon(Icons.skip_previous_rounded, color: scheme.onSurface),
          iconSize: 40,
          onPressed: () =>
              ref.read(audioHandlerNotifierProvider)?.skipToPrevious(),
        ),
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            color: fg,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: scheme.onPrimary,
            ),
            iconSize: 38,
            onPressed: () {
              final h = ref.read(audioHandlerNotifierProvider);
              isPlaying ? h?.pause() : h?.play();
            },
          ),
        ),
        IconButton(
          icon: Icon(Icons.skip_next_rounded, color: scheme.onSurface),
          iconSize: 40,
          onPressed: () =>
              ref.read(audioHandlerNotifierProvider)?.skipToNext(),
        ),
        IconButton(
          icon: Icon(
            loopMode == LoopMode.one
                ? Icons.repeat_one_rounded
                : Icons.repeat_rounded,
            color: loopMode != LoopMode.off ? fg : scheme.onSurface.withValues(alpha: 0.38),
          ),
          iconSize: 26,
          onPressed: () =>
              ref.read(audioHandlerNotifierProvider)?.cycleLoopMode(),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _BottomActions extends StatelessWidget {
  final Color fg;
  final ValueNotifier<Duration?> sleepNotifier;
  final VoidCallback onSleepTimer;
  final VoidCallback onQueueOpen;
  final VoidCallback onLyricsOpen;

  const _BottomActions({
    required this.fg,
    required this.sleepNotifier,
    required this.onSleepTimer,
    required this.onQueueOpen,
    required this.onLyricsOpen,
  });

  @override
  Widget build(BuildContext context) {
    // Absorb drag events so button taps win over the swipe-to-close recogniser.
    return GestureDetector(
      onVerticalDragStart: (_) {},
      onVerticalDragUpdate: (_) {},
      onVerticalDragEnd: (_) {},
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ActionButton(
            icon: Icons.queue_music_rounded,
            label: 'Queue',
            fg: fg,
            onTap: onQueueOpen,
          ),
          _ActionButton(
            icon: Icons.lyrics_outlined,
            label: 'Lyrics',
            fg: fg,
            onTap: onLyricsOpen,
          ),
          // Only this button rebuilds every second — the rest of the row is stable
          ValueListenableBuilder<Duration?>(
            valueListenable: sleepNotifier,
            builder: (_, remaining, __) => _ActionButton(
              icon: Icons.bedtime_rounded,
              label: remaining != null ? _fmtSleep(remaining) : 'Sleep',
              active: remaining != null,
              fg: fg,
              onTap: onSleepTimer,
            ),
          ),
        ],
      ),
    );
  }

  String _fmtSleep(Duration d) {
    if (d.inHours > 0) return '${d.inHours}h${d.inMinutes % 60}m';
    return '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final Color fg;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.fg,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final activeColor = fg;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24,
                color: active ? activeColor : scheme.onSurface.withValues(alpha: 0.6)),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: active ? activeColor : scheme.onSurface.withValues(alpha: 0.6))),
          ],
        ),
      ),
    );
  }
}

class _VolumeSlider extends ConsumerStatefulWidget {
  const _VolumeSlider();

  @override
  ConsumerState<_VolumeSlider> createState() => _VolumeSliderState();
}

class _VolumeSliderState extends ConsumerState<_VolumeSlider> {
  double _volume = 1.0;
  StreamSubscription<double>? _sub;

  @override
  void initState() {
    super.initState();
    final handler = ref.read(audioHandlerNotifierProvider);
    if (handler != null) {
      _volume = handler.player.volume;
      _sub = handler.player.volumeStream.listen((v) {
        if (mounted && v != _volume) setState(() => _volume = v);
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = ref.watch(currentAccentColorProvider);
    final fg = foregroundAccentColor(accent, scheme.brightness)
        ?? scheme.primary;
    final handler = ref.read(audioHandlerNotifierProvider);
    return Row(
      children: [
        IconButton(
          icon: Icon(
            _volume == 0
                ? Icons.volume_off_rounded
                : _volume < 0.5
                    ? Icons.volume_down_rounded
                    : Icons.volume_up_rounded,
            color: scheme.onSurfaceVariant,
            size: 18,
          ),
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          onPressed: () =>
              handler?.player.setVolume(_volume > 0 ? 0.0 : 1.0),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              trackHeight: 2,
              activeTrackColor: fg,
              inactiveTrackColor: scheme.surfaceContainerHighest,
              thumbColor: fg,
              overlayShape: SliderComponentShape.noOverlay,
            ),
            child: Slider(
              value: _volume,
              onChanged: (v) {
                setState(() => _volume = v);
                handler?.player.setVolume(v);
              },
            ),
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}

class _LyricsPage extends ConsumerStatefulWidget {
  final Song song;
  const _LyricsPage({required this.song});

  @override
  ConsumerState<_LyricsPage> createState() => _LyricsPageState();
}

class _LyricsPageState extends ConsumerState<_LyricsPage> {
  final _scrollCtrl = ScrollController();
  int _currentLine = 0;
  List<dynamic> _syncedLines = [];

  void _onPosition(Duration position) {
    if (_syncedLines.isEmpty) return;
    int lo = 0, hi = _syncedLines.length - 1, current = 0;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (_syncedLines[mid].timestamp <= position) {
        current = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    if (current == _currentLine) return;
    setState(() => _currentLine = current);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollCtrl.hasClients) return;
      const itemH = 48.0;
      final target = (current * itemH -
              MediaQuery.of(context).size.height * 0.35)
          .clamp(0.0, _scrollCtrl.position.maxScrollExtent);
      _scrollCtrl.animateTo(
        target,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = ref.watch(currentAccentColorProvider);
    final fg = foregroundAccentColor(accent, scheme.brightness)
        ?? scheme.primary;
    final query = (
      songId: widget.song.id,
      artist: widget.song.artist,
      title: widget.song.title,
      album: widget.song.album,
      duration: widget.song.duration ?? 0,
    );
    final lyricsAsync = ref.watch(lyricsProvider(query));

    // Listen, don't watch — position updates 10×/sec; only rebuild on line change.
    ref.listen(positionStreamProvider,
        (_, next) => _onPosition(next.valueOrNull ?? Duration.zero));

    return lyricsAsync.when(
      loading: () =>
          Center(child: CircularProgressIndicator(color: fg)),
      error: (_, __) => Center(
          child: Text('Could not load lyrics',
              style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.7)))),
      data: (result) {
        if (result == null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lyrics_outlined, size: 48,
                    color: scheme.onSurface.withValues(alpha: 0.38)),
                const SizedBox(height: 12),
                Text('No lyrics found',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.6))),
              ],
            ),
          );
        }

        if (result.hasSynced) {
          final lines = result.syncedLines;
          _syncedLines = lines;

          return ListView.builder(
            controller: _scrollCtrl,
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
            itemCount: lines.length,
            itemBuilder: (_, i) => _LyricLine(
              key: ValueKey(i),
              text: lines[i].text,
              isActive: i == _currentLine,
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Text(
            result.plain ?? '',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant, height: 1.6),
          ),
        );
      },
    );
  }
}

class _LyricLine extends StatefulWidget {
  final String text;
  final bool isActive;

  const _LyricLine({required this.text, required this.isActive, super.key});

  @override
  State<_LyricLine> createState() => _LyricLineState();
}

class _LyricLineState extends State<_LyricLine>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      value: widget.isActive ? 1.0 : 0.0,
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  }

  @override
  void didUpdateWidget(_LyricLine old) {
    super.didUpdateWidget(old);
    if (widget.isActive != old.isActive) {
      widget.isActive ? _ctrl.forward() : _ctrl.reverse();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final t = _anim.value;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            widget.text,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: t > 0.5 ? FontWeight.w700 : FontWeight.w400,
              color: Color.lerp(
                scheme.onSurface.withValues(alpha: 0.28),
                scheme.onSurface,
                t,
              ),
              height: 1.4,
            ),
          ),
        );
      },
    );
  }
}

