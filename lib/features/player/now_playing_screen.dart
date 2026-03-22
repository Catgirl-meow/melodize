import 'dart:async';
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:palette_generator/palette_generator.dart';
import '../../core/utils/platform_dirs.dart';
import '../../core/models/song.dart';
import '../../core/providers.dart';
import 'queue_screen.dart';

// ---------------------------------------------------------------------------
// Dominant color provider — cached per URL, reused across nav

final dominantColorProvider =
    FutureProvider.family<Color?, String>((ref, url) async {
  if (url.isEmpty) return null;
  try {
    final palette = await PaletteGenerator.fromImageProvider(
      CachedNetworkImageProvider(url),
      size: const Size(112, 112), // downsample before extraction — much faster
      maximumColorCount: 8,
    );
    return palette.dominantColor?.color;
  } catch (_) {
    return null;
  }
});

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
  // ValueNotifier so only _BottomActions rebuilds each tick — not the whole screen
  final _sleepNotifier = ValueNotifier<Duration?>(null);

  @override
  void dispose() {
    _pageController.dispose();
    _sleepCountdown?.cancel();
    _sleepNotifier.dispose();
    super.dispose();
  }

  void _onVerticalDragStart(DragStartDetails _) {
    if (_currentPage != 0) return;
    // Stop any in-progress open/close animation so drag takes over immediately.
    widget.controller.stop();
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (_currentPage != 0) return;
    final screenH = MediaQuery.of(context).size.height;
    // Drag down (positive dy) decreases controller value toward 0 (off-screen).
    widget.controller.value -= details.delta.dy / screenH;
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (_currentPage != 0) return;
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
    final dominantColor =
        ref.watch(dominantColorProvider(coverUrl)).valueOrNull ??
            const Color(0xFF1A1A2E);

    // Gradient: top slightly dark (prevents stripe on bright art), peak is very
    // vibrant around the album art zone, fades to black below.
    final bgTop  = Color.lerp(dominantColor, Colors.black, 0.52)!;
    final bgPeak = Color.lerp(dominantColor, Colors.black, 0.10)!;
    final bgFade = Color.lerp(dominantColor, Colors.black, 0.72)!;
    final bgGlow = dominantColor.withValues(alpha: 0.42);

    // Material(transparency) provides the Material ancestor Slider needs.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: _onVerticalDragStart,
      onVerticalDragUpdate: _onVerticalDragUpdate,
      onVerticalDragEnd: _onVerticalDragEnd,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
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
                    colors: [bgTop, bgPeak, bgFade, Colors.black],
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
                      child: ScrollConfiguration(
                        // Allow mouse/trackpad to swipe between player and lyrics
                        behavior: ScrollConfiguration.of(context).copyWith(
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
                            _LyricsPage(
                              song: song,
                              onBack: () => _pageController.animateToPage(
                                0,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              ),
                            ),
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
                                  ? Colors.white
                                  : Colors.white38,
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      builder: (_) => const RepaintBoundary(child: QueueScreen()),
    );
  }

  void _showSleepTimerDialog(BuildContext context) {
    final handler = ref.read(audioHandlerNotifierProvider);
    if (handler == null) return;

    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
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
                    const Icon(Icons.timer_off_rounded, color: Colors.red),
                title: const Text('Cancel timer'),
                onTap: () {
                  handler.cancelSleepTimer();
                  _sleepCountdown?.cancel();
                  _sleepNotifier.value = null;
                  Navigator.pop(context);
                },
              ),
            for (final minutes in [15, 30, 45, 60])
              ListTile(
                leading: const Icon(Icons.bedtime_rounded),
                title: Text('$minutes minutes'),
                onTap: () {
                  final dur = Duration(minutes: minutes);
                  handler.setSleepTimer(dur);
                  _startSleepCountdown(dur);
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
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

// ---------------------------------------------------------------------------

class _TopBar extends ConsumerWidget {
  final Song song;
  final VoidCallback onClose;
  const _TopBar({required this.song, required this.onClose});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 28),
            color: Colors.white,
            onPressed: onClose,
          ),
          const Spacer(),
          Text('Now Playing',
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: Colors.white70)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.more_vert_rounded),
            color: Colors.white,
            onPressed: () => _showMoreOptions(context, ref),
          ),
        ],
      ),
    );
  }

  void _showMoreOptions(BuildContext context, WidgetRef ref) {
    final downloadedIds = ref.read(downloadedSongIdsProvider);
    final isDownloaded = downloadedIds.contains(song.id) || song.isDownloaded;
    final canDelete = ref.read(canDeleteFromServerProvider);
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.queue_music_rounded),
              title: const Text('Play next'),
              onTap: () {
                ref.read(audioHandlerNotifierProvider)?.playNext(song);
                Navigator.pop(context);
              },
            ),
            if (!isDownloaded)
              ListTile(
                leading: const Icon(Icons.download_rounded),
                title: const Text('Download'),
                onTap: () async {
                  Navigator.pop(context);
                  final dir = await getAppStorageDirectory();
                  final prefs = ref.read(preferencesNotifierProvider);
                  final path =
                      '${dir.path}/melodize_downloads/${song.id}.${song.suffix ?? 'mp3'}';
                  ref
                      .read(downloadNotifierProvider.notifier)
                      .download(song, path, quality: prefs.downloadQuality);
                },
              ),
            if (isDownloaded)
              ListTile(
                leading: Icon(Icons.download_done_rounded,
                    color: scheme.primary),
                title: const Text('Downloaded'),
                enabled: false,
              ),
            if (canDelete)
              ListTile(
                leading: Icon(Icons.delete_forever_rounded,
                    color: scheme.error),
                title: Text('Delete from server',
                    style: TextStyle(color: scheme.error)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmAndDelete(context, ref);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _confirmAndDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete from server?'),
        content: Text(
          '"${song.title}" will be permanently deleted from the server. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await deleteSongFromServer(ref, song);
                if (context.mounted) {
                  _styledSnack(context, '"${song.title}" deleted');
                }
              } catch (e) {
                if (context.mounted) {
                  _styledSnack(context, 'Failed to delete: $e', isError: true);
                }
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Player page — layout only, stream-watching delegated to sub-widgets

class _PlayerPage extends StatelessWidget {
  final Song song;
  final String coverUrl;
  final ValueNotifier<Duration?> sleepNotifier;
  final VoidCallback onSleepTimer;
  final VoidCallback onQueueOpen;
  final VoidCallback onLyricsOpen;

  const _PlayerPage({
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
    // Cap by height so the Column never overflows on wide/short desktop windows.
    // On mobile screenWidth * 0.8 always wins (tall narrow screens).
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
          _SongInfoRow(song: song),
          const SizedBox(height: 16),
          RepaintBoundary(child: _SeekSlider()),
          const SizedBox(height: 4),
          RepaintBoundary(child: _PlayControls()),
          const SizedBox(height: 12),
          _BottomActions(
            sleepNotifier: sleepNotifier,
            onSleepTimer: onSleepTimer,
            onQueueOpen: onQueueOpen,
            onLyricsOpen: onLyricsOpen,
          ),
          const Spacer(flex: 1),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Album art — only rebuilds when isPlaying changes

class _AlbumArt extends ConsumerWidget {
  final String coverUrl;
  final double artSize;
  const _AlbumArt({required this.coverUrl, required this.artSize});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPlaying =
        ref.watch(playerStateStreamProvider).valueOrNull?.playing ?? false;
    final w = isPlaying ? artSize : artSize * 0.85;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: w,
      height: w,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
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
                errorWidget: (_, __, ___) => _placeholder(),
              )
            : _placeholder(),
      ),
    );
  }

  Widget _placeholder() => Container(
        color: Colors.white10,
        child:
            const Icon(Icons.music_note_rounded, size: 80, color: Colors.white24),
      );
}

// ---------------------------------------------------------------------------

class _SongInfoRow extends StatelessWidget {
  final Song song;
  const _SongInfoRow({required this.song});

  @override
  Widget build(BuildContext context) {
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
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                song.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(color: Colors.white70, fontSize: 15),
              ),
            ],
          ),
        ),
        if (song.suffix != null)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white30),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              song.suffix!.toUpperCase(),
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.bold),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Seek slider — has its own drag state, rebuilds every ~200ms independently

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
    final position =
        ref.watch(positionStreamProvider).valueOrNull ?? Duration.zero;
    final duration = ref.watch(durationStreamProvider).valueOrNull;

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
            activeTrackColor: Colors.white,
            inactiveTrackColor: Colors.white24,
            thumbColor: Colors.white,
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
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 12)),
              Text(_fmt(duration ?? Duration.zero),
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 12)),
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

// ---------------------------------------------------------------------------
// Play controls — rebuilds only on playerState / shuffle / loop changes

class _PlayControls extends ConsumerWidget {
  const _PlayControls();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPlaying = ref.watch(
      playerStateStreamProvider.select((s) => s.valueOrNull?.playing ?? false),
    );
    final isShuffled = ref.watch(
      shuffleModeStreamProvider.select((s) => s.valueOrNull ?? false),
    );
    final loopMode = ref.watch(
      loopModeStreamProvider.select((s) => s.valueOrNull ?? LoopMode.off),
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          icon: Icon(
            Icons.shuffle_rounded,
            color: isShuffled ? Colors.white : Colors.white38,
          ),
          iconSize: 26,
          onPressed: () =>
              ref.read(audioHandlerNotifierProvider)?.toggleShuffle(),
        ),
        IconButton(
          icon: const Icon(Icons.skip_previous_rounded, color: Colors.white),
          iconSize: 40,
          onPressed: () =>
              ref.read(audioHandlerNotifierProvider)?.skipToPrevious(),
        ),
        Container(
          width: 68,
          height: 68,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.black,
            ),
            iconSize: 38,
            onPressed: () {
              final h = ref.read(audioHandlerNotifierProvider);
              isPlaying ? h?.pause() : h?.play();
            },
          ),
        ),
        IconButton(
          icon: const Icon(Icons.skip_next_rounded, color: Colors.white),
          iconSize: 40,
          onPressed: () =>
              ref.read(audioHandlerNotifierProvider)?.skipToNext(),
        ),
        IconButton(
          icon: Icon(
            loopMode == LoopMode.one
                ? Icons.repeat_one_rounded
                : Icons.repeat_rounded,
            color: loopMode != LoopMode.off ? Colors.white : Colors.white38,
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
  final ValueNotifier<Duration?> sleepNotifier;
  final VoidCallback onSleepTimer;
  final VoidCallback onQueueOpen;
  final VoidCallback onLyricsOpen;

  const _BottomActions({
    required this.sleepNotifier,
    required this.onSleepTimer,
    required this.onQueueOpen,
    required this.onLyricsOpen,
  });

  @override
  Widget build(BuildContext context) {
    // The outer NowPlayingScreen has a vertical-drag handler for swipe-to-close.
    // Absorbing drag events here ensures button taps always win the gesture
    // arena and don't occasionally get stolen by the drag recognizer.
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
            onTap: onQueueOpen,
          ),
          _ActionButton(
            icon: Icons.lyrics_outlined,
            label: 'Lyrics',
            onTap: onLyricsOpen,
          ),
          // Only this button rebuilds every second — the rest of the row is stable
          ValueListenableBuilder<Duration?>(
            valueListenable: sleepNotifier,
            builder: (_, remaining, __) => _ActionButton(
              icon: Icons.bedtime_rounded,
              label: remaining != null ? _fmtSleep(remaining) : 'Sleep',
              active: remaining != null,
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

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: active ? Colors.white : Colors.white60),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: active ? Colors.white : Colors.white60)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Lyrics page

class _LyricsPage extends ConsumerStatefulWidget {
  final Song song;
  final VoidCallback onBack;
  const _LyricsPage({required this.song, required this.onBack});

  @override
  ConsumerState<_LyricsPage> createState() => _LyricsPageState();
}

class _LyricsPageState extends ConsumerState<_LyricsPage> {
  final _scrollCtrl = ScrollController();
  int _currentLine = 0;

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = (
      songId: widget.song.id,
      artist: widget.song.artist,
      title: widget.song.title,
      album: widget.song.album,
      duration: widget.song.duration ?? 0,
    );
    final lyricsAsync = ref.watch(lyricsProvider(query));
    final position =
        ref.watch(positionStreamProvider).valueOrNull ?? Duration.zero;

    return Stack(
      children: [
        lyricsAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: Colors.white)),
      error: (_, __) => const Center(
          child: Text('Could not load lyrics',
              style: TextStyle(color: Colors.white70))),
      data: (result) {
        if (result == null) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lyrics_outlined, size: 48, color: Colors.white38),
                SizedBox(height: 12),
                Text('No lyrics found',
                    style: TextStyle(color: Colors.white60, fontSize: 16)),
              ],
            ),
          );
        }

        if (result.hasSynced) {
          final lines = result.syncedLines;
          // Binary search for current lyric line — O(log n) vs O(n)
          int lo = 0, hi = lines.length - 1, current = 0;
          while (lo <= hi) {
            final mid = (lo + hi) >> 1;
            if (lines[mid].timestamp <= position) {
              current = mid;
              lo = mid + 1;
            } else {
              hi = mid - 1;
            }
          }
          if (current != _currentLine) {
            _currentLine = current;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_scrollCtrl.hasClients) {
                const itemH = 48.0;
                final target = (current * itemH -
                        MediaQuery.of(context).size.height * 0.35)
                    .clamp(0.0, _scrollCtrl.position.maxScrollExtent);
                _scrollCtrl.animateTo(
                  target,
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeOutCubic,
                );
              }
            });
          }

          return ListView.builder(
            controller: _scrollCtrl,
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
            itemCount: lines.length,
            itemBuilder: (_, i) => _LyricLine(
              key: ValueKey(i),
              text: lines[i].text,
              isActive: i == current,
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Text(
            result.plain ?? '',
            style: const TextStyle(
                color: Colors.white70, fontSize: 15, height: 1.6),
          ),
        );
      },
        ),
        // Back button — visible on desktop where swipe is unavailable
        Positioned(
          top: 8,
          left: 8,
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white70, size: 20),
            tooltip: 'Back to player',
            onPressed: widget.onBack,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Animated lyric line — smoothly transitions between active and inactive state.

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
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final t = _anim.value;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            widget.text,
            style: TextStyle(
              fontSize: 18.0,
              fontWeight: t > 0.5 ? FontWeight.w700 : FontWeight.w400,
              color: Color.lerp(
                Colors.white.withValues(alpha: 0.28),
                Colors.white,
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

void _styledSnack(BuildContext context, String message, {bool isError = false}) {
  final scheme = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      backgroundColor:
          isError ? scheme.errorContainer : scheme.inverseSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
