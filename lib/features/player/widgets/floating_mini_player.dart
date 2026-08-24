import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/song.dart';
import '../../../core/providers.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/cover_art_image.dart';

// The mini player uses the same Android-first tonal surface as the dock.
// Its shape remains a compact rounded rectangle in both playback states so the
// two bottom surfaces read as one Material 3 group rather than morphing cards.
const _kCardRadius = 20.0;
const _kThumbRadius = 12.0;

const _kShapeDuration = Duration(milliseconds: 400);
const _kShapeCurve = Curves.easeInOutCubicEmphasized;

class FloatingMiniPlayer extends ConsumerWidget {
  final Song song;
  final VoidCallback onOpen;
  const FloatingMiniPlayer({
    super.key,
    required this.song,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final isPlaying = ref.watch(
      playerStateStreamProvider.select((s) => s.valueOrNull?.playing ?? false),
    );

    final bgColor = scheme.surfaceContainerHigh;
    final cardRadius = BorderRadius.circular(_kCardRadius);

    return Padding(
      // Side inset matches the dock. Bottom gap separates the two tonal
      // surfaces without producing a large shadow halo.
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Material(
        color: bgColor,
        elevation: 1,
        shadowColor: scheme.shadow.withValues(alpha: 0.22),
        shape: RoundedRectangleBorder(
          borderRadius: cardRadius,
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
        borderRadius: cardRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          // RepaintBoundary isolates shape-morph repaints from the surrounding
          // dock so the animation doesn't dirty the dock's compositing layer.
          child: RepaintBoundary(
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
                          tween: Tween<double>(end: _kThumbRadius),
                          duration: _kShapeDuration,
                          curve: _kShapeCurve,
                          builder: (_, r, __) => CoverArtImage(
                            coverArtId: song.coverArt,
                            externalUrl: song.externalCoverUrl,
                            localPath: song.localPath,
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
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
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
      minHeight: 2,
      backgroundColor: Colors.transparent,
      valueColor: AlwaysStoppedAnimation(fg),
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
