import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/song.dart';
import '../../core/providers.dart';
import '../../shared/widgets/cover_art_image.dart';
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
// Classic mini player — full-width bar, rounded top only. Used with old nav.

const _kClassicPausedTopRadius = 28.0;
const _kClassicPlayingTopRadius = 8.0;
const _kClassicThumbPaused = 20.0;
const _kClassicThumbPlaying = 6.0;
const _kClassicShapeDuration = Duration(milliseconds: 400);
const _kClassicShapeCurve = Curves.easeInOutCubicEmphasized;

class _ClassicMiniPlayer extends ConsumerWidget {
  final Song song;
  final VoidCallback onOpen;
  const _ClassicMiniPlayer({required this.song, required this.onOpen});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final isPlaying = ref.watch(
      playerStateStreamProvider.select((s) => s.valueOrNull?.playing ?? false),
    );

    final bg = Color.alphaBlend(
      scheme.primary.withValues(alpha: 0.10),
      scheme.surfaceContainerHigh,
    );

    final topRadius =
        isPlaying ? _kClassicPlayingTopRadius : _kClassicPausedTopRadius;
    final thumbRadius =
        isPlaying ? _kClassicThumbPlaying : _kClassicThumbPaused;

    return GestureDetector(
      onTap: onOpen,
      child: AnimatedContainer(
        duration: _kClassicShapeDuration,
        curve: _kClassicShapeCurve,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(topRadius)),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: 0.32),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
          border: Border.all(
            color: Color.alphaBlend(
              scheme.primary.withValues(alpha: 0.42),
              scheme.outline,
            ),
          ),
        ),
        child: Container(
          height: 72,
          color: bg,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const RepaintBoundary(child: _MiniPlayerProgress()),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(end: thumbRadius),
                        duration: _kClassicShapeDuration,
                        curve: _kClassicShapeCurve,
                        builder: (_, r, __) => CoverArtImage(
                          coverArtId: song.coverArt,
                          externalUrl: song.externalCoverUrl,
                          localPath: song.localPath,
                          size: 44,
                          borderRadius: r,
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
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: scheme.onSurface)),
                            Text(song.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: scheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                      const RepaintBoundary(child: _MiniPlayerControls()),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

// Rebuilds every ~200 ms — only repaints its own 2 px slice.
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
    final progress = (duration != null && duration.inMilliseconds > 0)
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;
    return LinearProgressIndicator(
      value: progress.toDouble(),
      minHeight: 3,
      backgroundColor: scheme.outlineVariant.withValues(alpha: 0.55),
      valueColor: AlwaysStoppedAnimation(fg),
    );
  }
}

// Only rebuilds on play/pause state changes.
class _MiniPlayerControls extends ConsumerWidget {
  const _MiniPlayerControls();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPlaying = ref.watch(
      playerStateStreamProvider.select((s) => s.valueOrNull?.playing ?? false),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.skip_previous_rounded),
          iconSize: 24,
          onPressed: () =>
              ref.read(audioHandlerNotifierProvider)?.skipToPrevious(),
        ),
        IconButton(
          icon:
              Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
          iconSize: 28,
          onPressed: () {
            final h = ref.read(audioHandlerNotifierProvider);
            isPlaying ? h?.pause() : h?.play();
          },
        ),
        IconButton(
          icon: const Icon(Icons.skip_next_rounded),
          iconSize: 24,
          onPressed: () => ref.read(audioHandlerNotifierProvider)?.skipToNext(),
        ),
      ],
    );
  }
}
