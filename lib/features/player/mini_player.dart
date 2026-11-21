import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/song.dart';
import '../../core/providers.dart';
import '../../shared/widgets/cover_art_image.dart';
import 'package:just_audio/just_audio.dart' show ProcessingState;
import '../../core/utils/haptics.dart';
import '../../shared/theme/motion.dart';
import '../../shared/widgets/morph_button.dart';
import '../../shared/widgets/wavy_slider.dart';
import 'widgets/floating_mini_player.dart';

// Top-level widget — only rebuilds when the current song identity changes.
class MiniPlayer extends ConsumerWidget {
  final VoidCallback onOpen;
  const MiniPlayer({super.key, required this.onOpen});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final song = ref.watch(
      currentSongStreamProvider.select((s) => s.valueOrNull),
    );
    if (song == null) return const SizedBox.shrink();

    final floatingNav = ref.watch(
      preferencesNotifierProvider.select((p) => p.floatingNavBar),
    );
    return floatingNav
        ? FloatingMiniPlayer(song: song, onOpen: onOpen)
        : _ClassicMiniPlayer(song: song, onOpen: onOpen);
  }
}

// ---------------------------------------------------------------------------
// Classic mini player: a full-width bar on top of the navigation bar.
//
// One tonal surface a step above the navigation bar (no outline, no shadow),
// with the floating player's shape language: top corners 24 paused / 16
// playing, thumbnail nearly round paused / 10 playing. Progress is a thin
// wave inset from the edges. Swipe sideways to skip, up to open.

const _kClassicPausedTopRadius = 24.0;
const _kClassicPlayingTopRadius = 16.0;
const _kClassicThumbSize = 44.0;
const _kClassicThumbPaused = 21.0;
const _kClassicThumbPlaying = 10.0;
// How far a horizontal swipe must travel (or how fast) to skip.
const _kSwipeDistance = 56.0;
const _kSwipeVelocity = 400.0;

class _ClassicMiniPlayer extends ConsumerStatefulWidget {
  final Song song;
  final VoidCallback onOpen;
  const _ClassicMiniPlayer({required this.song, required this.onOpen});

  @override
  ConsumerState<_ClassicMiniPlayer> createState() => _ClassicMiniPlayerState();
}

class _ClassicMiniPlayerState extends ConsumerState<_ClassicMiniPlayer> {
  double _dx = 0;

  void _onDragEnd(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    final h = ref.read(audioHandlerNotifierProvider);
    if (_dx <= -_kSwipeDistance || v <= -_kSwipeVelocity) {
      Haptics.tick(ref);
      h?.skipToNext();
    } else if (_dx >= _kSwipeDistance || v >= _kSwipeVelocity) {
      Haptics.tick(ref);
      h?.skipToPrevious();
    }
    setState(() => _dx = 0);
  }

  @override
  Widget build(BuildContext context) {
    final song = widget.song;
    final scheme = Theme.of(context).colorScheme;
    final isPlaying = ref.watch(
      playerStateStreamProvider.select((s) => s.valueOrNull?.playing ?? false),
    );

    return TweenAnimationBuilder<double>(
      tween: Tween(
          end:
              isPlaying ? _kClassicPlayingTopRadius : _kClassicPausedTopRadius),
      duration: Motion.spring.duration,
      curve: Motion.spring.curve,
      builder: (context, r, child) => Material(
        color: scheme.surfaceContainerHigh,
        clipBehavior: Clip.antiAlias,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(r.clamp(0.0, 36.0))),
        child: child,
      ),
      child: GestureDetector(
        onHorizontalDragUpdate: (d) =>
            setState(() => _dx = (_dx + d.delta.dx).clamp(-120.0, 120.0)),
        onHorizontalDragEnd: _onDragEnd,
        onHorizontalDragCancel: () => setState(() => _dx = 0),
        onVerticalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0) < -_kSwipeVelocity) widget.onOpen();
        },
        child: InkWell(
          onTap: widget.onOpen,
          child: SizedBox(
            height: 72,
            child: Stack(
              children: [
                const Positioned(
                  left: 18,
                  right: 18,
                  top: 5,
                  child: RepaintBoundary(child: _MiniPlayerProgress()),
                ),
                Positioned.fill(
                  top: 10,
                  child: AnimatedSlide(
                    // Follows the finger a little; snaps back on release.
                    offset: Offset(_dx / 600, 0),
                    duration: _dx == 0 ? Motion.glide.duration : Duration.zero,
                    curve: Motion.glide.curve,
                    child: AnimatedOpacity(
                      opacity: 1 - (_dx.abs() / 240),
                      duration:
                          _dx == 0 ? Motion.glide.duration : Duration.zero,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 12, right: 6),
                        child: Row(
                          children: [
                            TweenAnimationBuilder<double>(
                              tween: Tween<double>(
                                  end: isPlaying
                                      ? _kClassicThumbPlaying
                                      : _kClassicThumbPaused),
                              duration: Motion.spring.duration,
                              curve: Motion.spring.curve,
                              builder: (_, r, __) => CoverArtImage(
                                coverArtId: song.coverArt,
                                externalUrl: song.externalCoverUrl,
                                localPath: song.localPath,
                                size: _kClassicThumbSize,
                                borderRadius:
                                    r.clamp(0.0, _kClassicThumbSize / 2),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(song.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: scheme.onSurface)),
                                  Text(song.artist,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                              color: scheme.onSurfaceVariant)),
                                ],
                              ),
                            ),
                            const RepaintBoundary(child: _MiniPlayerControls()),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

// Rebuilds every ~200 ms; only repaints its own thin slice.
class _MiniPlayerProgress extends ConsumerWidget {
  const _MiniPlayerProgress();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final accent = ref.watch(currentAccentColorProvider);
    final fg =
        foregroundAccentColor(accent, scheme.brightness) ?? scheme.primary;
    final position =
        ref.watch(positionStreamProvider).valueOrNull ?? Duration.zero;
    final duration = ref.watch(durationStreamProvider).valueOrNull;
    final playerState = ref.watch(playerStateStreamProvider).valueOrNull;
    final moving = (playerState?.playing ?? false) &&
        playerState?.processingState == ProcessingState.ready;
    final progress = (duration != null && duration.inMilliseconds > 0)
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;
    return WavySlider(
      value: progress.toDouble(),
      playing: moving,
      color: fg,
      trackColor: scheme.outlineVariant,
      height: 8,
      thickness: 3,
      amplitude: 2,
      wavelength: 26,
      showHandle: false,
      semanticLabel: 'Playback progress',
    );
  }
}

// Only rebuilds on play/pause state changes.
class _MiniPlayerControls extends ConsumerWidget {
  const _MiniPlayerControls();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final isPlaying = ref.watch(
      playerStateStreamProvider.select((s) => s.valueOrNull?.playing ?? false),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.skip_previous_rounded),
          iconSize: 24,
          tooltip: 'Previous',
          onPressed: () {
            Haptics.tick(ref);
            ref.read(audioHandlerNotifierProvider)?.skipToPrevious();
          },
        ),
        // The main action: a tonal button that morphs with the play state.
        MorphButton(
          width: 44,
          height: 44,
          radius: isPlaying ? 14 : 22,
          pressedRadius: 10,
          color: scheme.primaryContainer,
          tooltip: isPlaying ? 'Pause' : 'Play',
          onPressed: () {
            Haptics.tap(ref);
            final h = ref.read(audioHandlerNotifierProvider);
            isPlaying ? h?.pause() : h?.play();
          },
          child: Icon(
            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            color: scheme.onPrimaryContainer,
            size: 26,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.skip_next_rounded),
          iconSize: 24,
          tooltip: 'Next',
          onPressed: () {
            Haptics.tick(ref);
            ref.read(audioHandlerNotifierProvider)?.skipToNext();
          },
        ),
      ],
    );
  }
}
