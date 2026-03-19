import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/song.dart';
import '../../core/providers.dart';
import '../../shared/widgets/cover_art_image.dart';
import 'now_playing_screen.dart';

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

    // Pre-warm dominant color while mini player is visible so it's already
    // computed by the time the user opens the full player.
    final coverUrl = ref.watch(coverArtUrlProvider(song.coverArt ?? '')) ?? '';
    // Always watch unconditionally — dominantColorProvider returns null for
    // empty URLs instantly, and conditional watches are a Riverpod antipattern.
    ref.watch(dominantColorProvider(coverUrl));

    return _MiniPlayerShell(song: song, onOpen: onOpen);
  }
}

// Shell: stable background + layout. Only rebuilds when song identity changes.
class _MiniPlayerShell extends StatelessWidget {
  final Song song;
  final VoidCallback onOpen;
  const _MiniPlayerShell({required this.song, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Blend primary colour into the surface so the mini player is always
    // visually distinct from the flat navigation bar underneath it.
    final bg = Color.lerp(
      scheme.surfaceContainerHigh,
      scheme.primaryContainer,
      0.28,
    )!;

    return GestureDetector(
      onTap: onOpen,
      // DecoratedBox outside the clip so the shadow is not cut off.
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.50),
              blurRadius: 22,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          child: Container(
            height: 72,
            color: bg,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Progress bar — rebuilds every ~200ms independently
                RepaintBoundary(child: _MiniPlayerProgress(trackColor: bg)),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        CoverArtImage(
                            coverArtId: song.coverArt,
                            size: 44,
                            borderRadius: 6),
                        const SizedBox(width: 12),
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
                                      fontSize: 14)),
                              Text(song.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: scheme.onSurfaceVariant)),
                            ],
                          ),
                        ),
                        // Controls only rebuild on play/pause state change
                        RepaintBoundary(child: _MiniPlayerControls()),
                      ],
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

// Rebuilds every ~200ms — only repaints its own 2px slice.
class _MiniPlayerProgress extends ConsumerWidget {
  final Color trackColor;
  const _MiniPlayerProgress({required this.trackColor});

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
          iconSize: 26,
          onPressed: () =>
              ref.read(audioHandlerNotifierProvider)?.skipToPrevious(),
        ),
        IconButton(
          icon: Icon(isPlaying
              ? Icons.pause_rounded
              : Icons.play_arrow_rounded),
          iconSize: 30,
          onPressed: () {
            final h = ref.read(audioHandlerNotifierProvider);
            isPlaying ? h?.pause() : h?.play();
          },
        ),
        IconButton(
          icon: const Icon(Icons.skip_next_rounded),
          iconSize: 26,
          onPressed: () =>
              ref.read(audioHandlerNotifierProvider)?.skipToNext(),
        ),
      ],
    );
  }
}
