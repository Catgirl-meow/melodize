import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../shared/widgets/cover_art_image.dart';

class QueueScreen extends ConsumerWidget {
  const QueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use select so QueueScreen only rebuilds when the sequence or current
    // index changes — not on every stream emission (loop mode, shuffle, etc.)
    final queue = ref.watch(
      sequenceStateStreamProvider
          .select((s) => s.valueOrNull?.effectiveSequence ?? const []),
    );
    final currentIndex = ref.watch(
      sequenceStateStreamProvider
          .select((s) => s.valueOrNull?.currentIndex ?? 0),
    );
    final handler = ref.read(audioHandlerNotifierProvider);
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      clipBehavior: Clip.antiAlias,
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
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                Text('Queue',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Text('${queue.length} songs',
                    style: TextStyle(
                        color: scheme.onSurfaceVariant, fontSize: 13)),
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
                    cacheExtent: 200,
                    proxyDecorator: (child, index, animation) => child,
                    itemCount: queue.length,
                    onReorder: (oldIndex, newIndex) {
                      if (newIndex > oldIndex) newIndex--;
                      handler?.reorderQueue(oldIndex, newIndex);
                    },
                    itemBuilder: (_, i) {
                      final song = queue[i].tag;
                      final isCurrent = i == currentIndex;
                      return RepaintBoundary(
                        key: ValueKey(queue[i].sequence.hashCode + i),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 2),
                          leading: CoverArtImage(
                            coverArtId: song?.coverArt,
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
                                Icon(Icons.equalizer_rounded,
                                    size: 20, color: scheme.primary),
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
