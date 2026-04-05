import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/song.dart';
import '../../core/providers.dart';
import '../../shared/widgets/cover_art_image.dart';

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
    // Accent color is already being computed via currentAccentColorProvider;
    // watching it here triggers the dominantColorProvider pre-warm as well.
    final accentColor = ref.watch(currentAccentColorProvider);

    return floatingNav
        ? _FloatingMiniPlayer(song: song, onOpen: onOpen, accentColor: accentColor)
        : _ClassicMiniPlayer(song: song, onOpen: onOpen, accentColor: accentColor);
  }
}

// ---------------------------------------------------------------------------
// Classic mini player — full-width bar, rounded top only. Used with old nav.

class _ClassicMiniPlayer extends StatelessWidget {
  final Song song;
  final VoidCallback onOpen;
  final Color? accentColor;
  const _ClassicMiniPlayer({required this.song, required this.onOpen, this.accentColor});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final bg = accentColor != null
        ? Color.lerp(accentColor!, scheme.surfaceContainerHigh, 0.55)!
        : Color.lerp(scheme.surfaceContainerHigh, scheme.primaryContainer, 0.28)!;

    return GestureDetector(
      onTap: onOpen,
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
                RepaintBoundary(child: _MiniPlayerProgress()),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        CoverArtImage(
                            coverArtId: song.coverArt,
                            externalUrl: song.externalCoverUrl,
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

// ---------------------------------------------------------------------------
// Floating mini player — glass card with all-rounded corners, inset to match
// the floating dock.

class _FloatingMiniPlayer extends StatelessWidget {
  final Song song;
  final VoidCallback onOpen;
  final Color? accentColor;
  const _FloatingMiniPlayer({required this.song, required this.onOpen, this.accentColor});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const radius = 16.0;
    const cardRadius = BorderRadius.all(Radius.circular(radius));

    final bgColor = accentColor != null
        ? (scheme.brightness == Brightness.dark
            ? Color.lerp(accentColor!, const Color(0xFF1C1C1E), 0.58)!.withValues(alpha: 0.93)
            : Color.lerp(accentColor!, Colors.white, 0.65)!.withValues(alpha: 0.94))
        : (scheme.brightness == Brightness.dark
            ? const Color(0xFF2C2C2E).withValues(alpha: 0.93)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.94));

    return Padding(
      // Side inset matches the dock. Bottom gap sits 6 px above the dock top.
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
      child: GestureDetector(
        onTap: onOpen,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: cardRadius,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.42),
                blurRadius: 24,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: cardRadius,
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
                          CoverArtImage(
                              coverArtId: song.coverArt,
                              externalUrl: song.externalCoverUrl,
                              size: 40,
                              borderRadius: 10),
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
                          RepaintBoundary(child: _MiniPlayerControls()),
                        ],
                      ),
                    ),
                    // Progress bar — clipped to card corner radius at bottom
                    Positioned(
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
    );
  }
}

// ---------------------------------------------------------------------------

// Rebuilds every ~200 ms — only repaints its own 2 px slice.
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
          icon: Icon(isPlaying
              ? Icons.pause_rounded
              : Icons.play_arrow_rounded),
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
