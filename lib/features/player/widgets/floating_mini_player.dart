import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/song.dart';
import '../../../core/providers.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/cover_art_image.dart';

// Playing shape: slightly asymmetric, wider leading corner for visual motion.
// Paused shape: uniform 16 px — same as the dock corners.
const _kPausedRadius = 16.0;
const _kPlayingTL = 22.0;
const _kPlayingBL = 22.0;
const _kPlayingTR = 18.0;
const _kPlayingBR = 18.0;
const _kThumbPaused = 12.0;
const _kThumbPlaying = 18.0;

const _kShapeDuration = Duration(milliseconds: 400);
const _kShapeCurve = Curves.easeInOutCubicEmphasized;

class FloatingMiniPlayer extends ConsumerWidget {
  final Song song;
  final VoidCallback onOpen;
  final Color? accentColor;

  const FloatingMiniPlayer({
    super.key,
    required this.song,
    required this.onOpen,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final isPlaying = ref.watch(
      playerStateStreamProvider.select((s) => s.valueOrNull?.playing ?? false),
    );

    final cardRadius = isPlaying
        ? const BorderRadius.only(
            topLeft: Radius.circular(_kPlayingTL),
            bottomLeft: Radius.circular(_kPlayingBL),
            topRight: Radius.circular(_kPlayingTR),
            bottomRight: Radius.circular(_kPlayingBR),
          )
        : BorderRadius.circular(_kPausedRadius);

    final thumbRadius = isPlaying ? _kThumbPlaying : _kThumbPaused;
    final bgColor = AppTheme.dockBackground(accentColor, scheme);

    return Padding(
      // Side inset matches the dock. Bottom gap sits 6 px above the dock top.
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
      child: GestureDetector(
        onTap: onOpen,
        child: DecoratedBox(
          // Shadow shape is fixed — 24 px blur makes corner asymmetry invisible.
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_kPausedRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.42),
                blurRadius: 24,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          // RepaintBoundary isolates shape-morph repaints from the surrounding
          // dock so the animation doesn't dirty the dock's compositing layer.
          child: RepaintBoundary(
            child: AnimatedContainer(
              duration: _kShapeDuration,
              curve: _kShapeCurve,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(borderRadius: cardRadius),
              // Blur+tint layer is intentionally left structurally unchanged.
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                child: Container(
                  height: 62,
                  color: bgColor,
                  child: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Row(
                          children: [
                            TweenAnimationBuilder<double>(
                              tween: Tween<double>(end: thumbRadius),
                              duration: _kShapeDuration,
                              curve: _kShapeCurve,
                              builder: (_, r, child) => CoverArtImage(
                                coverArtId: song.coverArt,
                                externalUrl: song.externalCoverUrl,
                                size: 40,
                                borderRadius: r,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(song.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13)),
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
                      // Progress bar — painted at card bottom, clipped to card radius.
                      const Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: RepaintBoundary(child: _MiniPlayerProgress()),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private helpers — mirrors of the same widgets in mini_player.dart, kept here
// to avoid a circular import between mini_player.dart ↔ this file.

class _MiniPlayerProgress extends ConsumerWidget {
  const _MiniPlayerProgress();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final position =
        ref.watch(positionStreamProvider).valueOrNull ?? Duration.zero;
    final duration = ref.watch(durationStreamProvider).valueOrNull;
    final progress = (duration != null && duration.inMilliseconds > 0)
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;
    return LinearProgressIndicator(
      value: progress.toDouble(),
      minHeight: 2,
      backgroundColor: Colors.transparent,
      valueColor:
          AlwaysStoppedAnimation(Theme.of(context).colorScheme.primary),
    );
  }
}

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
          icon: Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
          iconSize: 28,
          onPressed: () {
            final h = ref.read(audioHandlerNotifierProvider);
            isPlaying ? h?.pause() : h?.play();
          },
        ),
        IconButton(
          icon: const Icon(Icons.skip_next_rounded),
          iconSize: 24,
          onPressed: () =>
              ref.read(audioHandlerNotifierProvider)?.skipToNext(),
        ),
      ],
    );
  }
}
