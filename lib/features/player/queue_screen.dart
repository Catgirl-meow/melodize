import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/audio/playback_core.dart';
import '../../core/models/song.dart';
import '../../core/providers.dart';
import '../../shared/widgets/cover_art_image.dart';

class QueueScreen extends ConsumerStatefulWidget {
  const QueueScreen({super.key});

  @override
  ConsumerState<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends ConsumerState<QueueScreen> {
  bool _playedExpanded = false;

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(queueSnapshotStreamProvider).valueOrNull;
    final songs = snapshot?.songs ?? const [];
    final currentIndex = snapshot?.currentIndex ?? 0;
    final mode = snapshot?.mode ?? PlaybackMode.normal;
    final transitions = snapshot?.upcomingTransitions ?? const [];
    final handler = ref.read(audioHandlerNotifierProvider);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final nowPlaying =
        (currentIndex >= 0 && currentIndex < songs.length)
            ? songs[currentIndex]
            : null;
    final upNext = currentIndex + 1 < songs.length
        ? songs.sublist(currentIndex + 1)
        : <Song>[];
    final played = currentIndex > 0
        ? songs.sublist(0, currentIndex)
        : <Song>[];

    // Map target song index → transition that leads into it.
    final transitionMap = <int, PlannedTransition>{};
    for (int i = 0; i < transitions.length; i++) {
      final targetIdx = currentIndex + i + 1;
      if (targetIdx < songs.length) {
        transitionMap[targetIdx] = transitions[i];
      }
    }

    final baseIndex = currentIndex + 1;

    return Material(
      color: scheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.82,
        child: Column(
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 16),
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header row
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 16),
              child: Row(
                children: [
                  Text(
                    'Queue',
                    style: textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 12),
                  _ModeChip(mode: mode, scheme: scheme),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: songs.isEmpty
                  ? Center(
                      child: Text(
                        'Queue is empty',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    )
                  : CustomScrollView(
                      slivers: [
                        // ── Now Playing ──
                        if (nowPlaying != null)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                  16, 0, 16, 16),
                              child: _NowPlayingCard(
                                song: nowPlaying,
                                scheme: scheme,
                                textTheme: textTheme,
                                nextTransition: mode == PlaybackMode.smartShuffle
                                    ? transitionMap[currentIndex + 1]
                                    : null,
                              ),
                            ),
                          ),

                        // ── Up Next ──
                        SliverToBoxAdapter(
                          child: _SectionHeader(
                            title: 'Up Next',
                            count: upNext.length,
                            scheme: scheme,
                            trailing: mode == PlaybackMode.normal &&
                                    upNext.length > 1
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.swipe_left_rounded,
                                        size: 14,
                                        color: scheme.onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Swipe to remove',
                                        style: textTheme.labelSmall?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  )
                                : mode != PlaybackMode.normal
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.auto_awesome,
                                            size: 14,
                                            color: scheme.primary,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Auto-ordered',
                                            style: textTheme.labelSmall
                                                ?.copyWith(
                                              color: scheme.primary,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      )
                                    : null,
                          ),
                        ),
                        if (upNext.isNotEmpty)
                          mode == PlaybackMode.normal
                              ?                              SliverPadding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  sliver: SliverList(
                                    delegate: SliverChildBuilderDelegate(
                                      (context, index) {
                                        final song = upNext[index];
                                        return RepaintBoundary(
                                          child: Dismissible(
                                            key: ValueKey(
                                                'upnext_${baseIndex + index}'),
                                            direction: DismissDirection.endToStart,
                                            onDismissed: (_) => handler
                                                ?.removeFromQueue(baseIndex + index),
                                            background: Container(
                                              alignment: Alignment.centerRight,
                                              padding: const EdgeInsets.only(right: 20),
                                              color: scheme.error,
                                              child: Icon(Icons.delete_rounded,
                                                  color: scheme.onError),
                                            ),
                                            child: _UpNextItem(
                                              song: song,
                                              queueIndex: baseIndex + index,
                                              number: index + 1,
                                              scheme: scheme,
                                              textTheme: textTheme,
                                              mode: PlaybackMode.normal,
                                              transition:
                                                  transitionMap[baseIndex + index],
                                              onTap: () => handler
                                                  ?.skipToIndex(baseIndex + index),
                                              onRemove: () => handler
                                                  ?.removeFromQueue(baseIndex + index),
                                            ),
                                          ),
                                        );
                                      },
                                      childCount: upNext.length,
                                    ),
                                  ),
                                )
                              : SliverPadding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 16),
                                  sliver: SliverList(
                                    delegate: SliverChildBuilderDelegate(
                                      (context, i) => RepaintBoundary(
                                        child: _UpNextItem(
                                          song: upNext[i],
                                          queueIndex: currentIndex + 1 + i,
                                          number: i + 1,
                                          scheme: scheme,
                                          textTheme: textTheme,
                                          mode: mode,
                                          transition: transitionMap[
                                              currentIndex + 1 + i],
                                          onTap: () =>
                                              handler?.skipToIndex(
                                                  currentIndex + 1 + i),
                                          onRemove: () =>
                                              handler?.removeFromQueue(
                                                  currentIndex + 1 + i),
                                        ),
                                      ),
                                      childCount: upNext.length,
                                    ),
                                  ),
                                )
                        else
                          const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              child: Text('Nothing up next'),
                            ),
                          ),

                        // ── Played ──
                        SliverToBoxAdapter(
                          child: _SectionHeader(
                            title: 'Played',
                            count: played.length,
                            scheme: scheme,
                            onTap: played.isNotEmpty
                                ? () => setState(
                                    () => _playedExpanded = !_playedExpanded)
                                : null,
                            expanded: _playedExpanded,
                          ),
                        ),
                        if (played.isNotEmpty && _playedExpanded)
                          SliverPadding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, i) => RepaintBoundary(
                                  child: _PlayedItem(
                                    song: played[i],
                                    onTap: () => handler?.skipToIndex(i),
                                    onRemove: () =>
                                        handler?.removeFromQueue(i),
                                    scheme: scheme,
                                    textTheme: textTheme,
                                  ),
                                ),
                                childCount: played.length,
                              ),
                            ),
                          ),

                        const SliverPadding(
                            padding: EdgeInsets.only(bottom: 24)),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

}

// ─────────────────────────────────────────────────────────────────────────────
//  Mode chip
// ─────────────────────────────────────────────────────────────────────────────

class _ModeChip extends StatelessWidget {
  final PlaybackMode mode;
  final ColorScheme scheme;

  const _ModeChip({required this.mode, required this.scheme});

  @override
  Widget build(BuildContext context) {
    final (icon, label, bg, fg) = switch (mode) {
      PlaybackMode.normal => (
          Icons.playlist_play,
          'Sequential',
          scheme.surfaceContainerHighest,
          scheme.onSurfaceVariant
        ),
      PlaybackMode.shuffle => (
          Icons.shuffle,
          'Shuffle',
          scheme.primaryContainer,
          scheme.onPrimaryContainer
        ),
      PlaybackMode.smartShuffle => (
          Icons.auto_awesome,
          'Smart',
          scheme.tertiaryContainer,
          scheme.onTertiaryContainer
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Section header
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final ColorScheme scheme;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool expanded;

  const _SectionHeader({
    required this.title,
    required this.count,
    required this.scheme,
    this.trailing,
    this.onTap,
    this.expanded = true,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$count',
                      style: textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (onTap != null) ...[
                    const SizedBox(width: 4),
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.expand_more,
                        size: 18,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Now Playing card
// ─────────────────────────────────────────────────────────────────────────────

class _NowPlayingCard extends ConsumerWidget {
  final Song song;
  final ColorScheme scheme;
  final TextTheme textTheme;
  final PlannedTransition? nextTransition;

  const _NowPlayingCard({
    required this.song,
    required this.scheme,
    required this.textTheme,
    this.nextTransition,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPlaying = ref.watch(
      playerStateStreamProvider.select((s) => s.valueOrNull?.playing ?? false),
    );
    final accent = ref.watch(currentAccentColorProvider);
    final fg = foregroundAccentColor(accent, scheme.brightness) ?? scheme.primary;

    return Card(
      elevation: 0,
      color: scheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                RepaintBoundary(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: CoverArtImage(
                      coverArtId: song.coverArt,
                      externalUrl: song.externalCoverUrl,
                      size: 64,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: fg,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      if (song.album.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          song.album,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant.withValues(
                                alpha: 0.7),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _AnimatedEqualizer(color: fg, isPlaying: isPlaying),
              ],
            ),
            if (nextTransition != null) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),
              _TransitionPill(transition: nextTransition!, scheme: scheme),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Up Next item
// ─────────────────────────────────────────────────────────────────────────────

class _UpNextItem extends StatelessWidget {
  final Song song;
  final int queueIndex;
  final int number;
  final ColorScheme scheme;
  final TextTheme textTheme;
  final PlaybackMode mode;
  final PlannedTransition? transition;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final bool dragHandle;

  const _UpNextItem({
    super.key,
    required this.song,
    required this.queueIndex,
    required this.number,
    required this.scheme,
    required this.textTheme,
    this.mode = PlaybackMode.normal,
    this.transition,
    required this.onTap,
    required this.onRemove,
    this.dragHandle = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 28,
                child: Text(
                  '$number',
                  textAlign: TextAlign.center,
                  style: textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
                  ),
                ),
              ),
              RepaintBoundary(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CoverArtImage(
                    coverArtId: song.coverArt,
                    externalUrl: song.externalCoverUrl,
                    size: 44,
                  ),
                ),
              ),
            ],
          ),
          title: Text(
            song.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
              color: scheme.onSurface,
            ),
          ),
          subtitle: Text(
            song.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: onRemove,
                visualDensity: VisualDensity.compact,
                color: scheme.onSurfaceVariant,
              ),
              if (dragHandle)
                ReorderableDragStartListener(
                  index: number - 1,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4, right: 8),
                    child: Icon(
                      Icons.drag_handle_rounded,
                      size: 20,
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                  ),
                ),
            ],
          ),
          onTap: onTap,
        ),
        // Transition hint between this song and the next — only in smart shuffle
        if (mode == PlaybackMode.smartShuffle && transition != null)
          Padding(
            padding: const EdgeInsets.only(left: 36, bottom: 4),
            child: _TransitionPill(transition: transition!, scheme: scheme),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Played item
// ─────────────────────────────────────────────────────────────────────────────

class _PlayedItem extends StatelessWidget {
  final Song song;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final ColorScheme scheme;
  final TextTheme textTheme;

  const _PlayedItem({
    required this.song,
    required this.onTap,
    required this.onRemove,
    required this.scheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.5,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        leading: RepaintBoundary(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: CoverArtImage(
              coverArtId: song.coverArt,
              externalUrl: song.externalCoverUrl,
              size: 36,
            ),
          ),
        ),
        title: Text(
          song.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w400,
            color: scheme.onSurface,
          ),
        ),
        subtitle: Text(
          song.artist,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.close_rounded, size: 16),
          onPressed: onRemove,
          visualDensity: VisualDensity.compact,
          color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
        ),
        onTap: onTap,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Transition pill
// ─────────────────────────────────────────────────────────────────────────────

class _TransitionPill extends StatelessWidget {
  final PlannedTransition transition;
  final ColorScheme scheme;

  const _TransitionPill({required this.transition, required this.scheme});

  @override
  Widget build(BuildContext context) {
    final (icon, label, color) = switch (transition.kind) {
      TransitionKind.gapless => (
          Icons.play_arrow_rounded,
          'Gapless',
          scheme.outline
        ),
      TransitionKind.volumeCrossfade => (
          Icons.blur_on_rounded,
          'Crossfade · ${transition.duration.inSeconds}s',
          scheme.primary
        ),
      TransitionKind.djBlend => (
          Icons.graphic_eq_rounded,
          'DJ Blend · ${transition.duration.inSeconds}s',
          scheme.tertiary
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withValues(alpha: 0.20),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Animated equalizer (unchanged)
// ─────────────────────────────────────────────────────────────────────────────

class _AnimatedEqualizer extends StatefulWidget {
  final Color color;
  final bool isPlaying;
  const _AnimatedEqualizer({required this.color, this.isPlaying = true});

  @override
  State<_AnimatedEqualizer> createState() => _AnimatedEqualizerState();
}

class _AnimatedEqualizerState extends State<_AnimatedEqualizer>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _anims;

  @override
  void initState() {
    super.initState();
    _controllers = [
      AnimationController(
          vsync: this, duration: const Duration(milliseconds: 380)),
      AnimationController(
          vsync: this, duration: const Duration(milliseconds: 500)),
      AnimationController(
          vsync: this, duration: const Duration(milliseconds: 420)),
    ];
    _controllers[1].value = 0.5;
    _controllers[2].value = 0.25;
    _anims = [
      Tween<double>(begin: 0.25, end: 1.0).animate(
          CurvedAnimation(parent: _controllers[0], curve: Curves.easeInOut)),
      Tween<double>(begin: 0.6, end: 1.0).animate(
          CurvedAnimation(parent: _controllers[1], curve: Curves.easeInOut)),
      Tween<double>(begin: 0.35, end: 0.85).animate(
          CurvedAnimation(parent: _controllers[2], curve: Curves.easeInOut)),
    ];
    _updateAnimationState();
  }

  @override
  void didUpdateWidget(_AnimatedEqualizer old) {
    super.didUpdateWidget(old);
    if (widget.isPlaying != old.isPlaying) {
      _updateAnimationState();
    }
  }

  void _updateAnimationState() {
    if (widget.isPlaying) {
      for (final c in _controllers) {
        c.repeat(reverse: true);
      }
    } else {
      for (final c in _controllers) {
        c.stop();
        c.value = 0.25; // freeze at flat paused state
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: AnimatedBuilder(
        animation: Listenable.merge(_controllers),
        builder: (_, __) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(3, (i) {
            return Container(
              width: 3,
              height: math.max(3, 18 * _anims[i].value),
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(1.5),
              ),
            );
          }),
        ),
      ),
    );
  }
}
