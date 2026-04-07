import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../shared/widgets/cover_art_image.dart';

class QueueScreen extends ConsumerWidget {
  const QueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use a (length, currentIndex) record for the select — Dart records compare
    // by value, so this rebuilds only when the queue length or playing position
    // actually changes (not on every sequenceStateStream emission where List
    // identity would incorrectly appear as a change every time).
    final (queueLength, currentIndex) = ref.watch(
      sequenceStateStreamProvider.select((s) {
        final seq = s.valueOrNull;
        return (seq?.effectiveSequence.length ?? 0, seq?.currentIndex ?? 0);
      }),
    );
    // Non-reactive read — runs only after the select above triggers a rebuild.
    final queue = ref.read(sequenceStateStreamProvider).valueOrNull
            ?.effectiveSequence ??
        const [];
    final handler = ref.read(audioHandlerNotifierProvider);
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      // Clip.hardEdge avoids a GPU save layer (Clip.antiAlias forces one),
      // which makes the modal dismiss animation smooth.
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 8, 12),
            child: Row(
              children: [
                Text('Queue',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Text('$queueLength songs',
                    style: TextStyle(
                        color: scheme.onSurfaceVariant, fontSize: 13)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(context),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          Expanded(
            child: queue.isEmpty
                ? Center(
                    child: Text('Queue is empty',
                        style:
                            TextStyle(color: scheme.onSurfaceVariant)),
                  )
                : ReorderableListView.builder(
                    padding: EdgeInsets.zero,
                    // Limit pre-building of off-screen items
                    cacheExtent: 50,
                    proxyDecorator: (child, index, animation) => Material(
                      color: scheme.surfaceContainerHighest,
                      elevation: 4,
                      shadowColor: Colors.black38,
                      child: child,
                    ),
                    itemCount: queue.length,
                    onReorder: (oldIndex, newIndex) {
                      if (newIndex > oldIndex) newIndex--;
                      handler?.reorderQueue(oldIndex, newIndex);
                    },
                    itemBuilder: (_, i) {
                      final song = queue[i].tag;
                      final isCurrent = i == currentIndex;
                      return RepaintBoundary(
                        key: ValueKey(song?.id ?? i),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 2),
                          leading: CoverArtImage(
                            coverArtId: song?.coverArt,
                            externalUrl: song?.externalCoverUrl,
                            size: 44,
                          ),
                          title: Text(
                            song?.title ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: isCurrent
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isCurrent ? scheme.primary : null,
                            ),
                          ),
                          subtitle: Text(
                            song?.artist ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                fontSize: 12),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isCurrent)
                                _AnimatedEqualizer(color: scheme.primary),
                              IconButton(
                                icon: const Icon(Icons.close_rounded,
                                    size: 18),
                                onPressed: () =>
                                    handler?.removeFromQueue(i),
                                visualDensity: VisualDensity.compact,
                              ),
                              const Icon(Icons.drag_handle_rounded,
                                  size: 20),
                            ],
                          ),
                          onTap: () => handler?.skipToIndex(i),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _AnimatedEqualizer extends StatefulWidget {
  final Color color;
  const _AnimatedEqualizer({required this.color});

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
      AnimationController(vsync: this, duration: const Duration(milliseconds: 380))..repeat(reverse: true),
      AnimationController(vsync: this, duration: const Duration(milliseconds: 500))..repeat(reverse: true),
      AnimationController(vsync: this, duration: const Duration(milliseconds: 420))..repeat(reverse: true),
    ];
    // Stagger start phases so bars aren't in sync
    _controllers[1].value = 0.5;
    _controllers[2].value = 0.25;
    _anims = [
      Tween<double>(begin: 0.25, end: 1.0).animate(CurvedAnimation(parent: _controllers[0], curve: Curves.easeInOut)),
      Tween<double>(begin: 0.6, end: 1.0).animate(CurvedAnimation(parent: _controllers[1], curve: Curves.easeInOut)),
      Tween<double>(begin: 0.35, end: 0.85).animate(CurvedAnimation(parent: _controllers[2], curve: Curves.easeInOut)),
    ];
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
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
