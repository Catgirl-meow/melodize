import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../shared/widgets/cover_art_image.dart';
import '../../shared/widgets/song_tile.dart';

class DownloadedSongsScreen extends ConsumerWidget {
  const DownloadedSongsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songsAsync = ref.watch(downloadedSongsProvider);
    final scheme = Theme.of(context).colorScheme;

    // Only rebuild the list structure when the SET of downloading IDs changes,
    // not on every progress tick.  Individual _ActiveDownloadTile widgets
    // watch their own slice of the state via select().
    final downloadingIds = ref.watch(downloadNotifierProvider.select((m) {
      final ids = m.entries
          .where((e) =>
              e.value.status == 'downloading' || e.value.status == 'queued')
          .map((e) => e.key)
          .toList()
        ..sort();
      return ids.join(',');
    }));
    final activeIds = downloadingIds.isNotEmpty
        ? downloadingIds.split(',')
        : <String>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Downloaded Songs'),
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: songsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (songs) {
          final empty = songs.isEmpty && activeIds.isEmpty;
          if (empty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.download_for_offline_outlined,
                      size: 64, color: scheme.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text('No downloaded songs',
                      style: TextStyle(
                          color: scheme.onSurfaceVariant, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('Tap the download icon on any song to save it offline.',
                      style: TextStyle(
                          color: scheme.onSurfaceVariant, fontSize: 13),
                      textAlign: TextAlign.center),
                ],
              ),
            );
          }

          return CustomScrollView(
            slivers: [
              // --- Active downloads section ---
              if (activeIds.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text(
                      'DOWNLOADING NOW',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: scheme.primary,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _ActiveDownloadTile(songId: activeIds[i]),
                    childCount: activeIds.length,
                  ),
                ),
                SliverToBoxAdapter(
                  child: Divider(
                    height: 16,
                    indent: 16,
                    endIndent: 16,
                    color: scheme.outlineVariant,
                  ),
                ),
              ],

              // --- Saved songs header ---
              if (songs.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        Text(
                          '${songs.length} song${songs.length == 1 ? '' : 's'}',
                          style: TextStyle(
                              color: scheme.onSurfaceVariant, fontSize: 13),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          icon: const Icon(Icons.delete_outline_rounded,
                              size: 18),
                          label: const Text('Delete all'),
                          style: TextButton.styleFrom(
                            foregroundColor: scheme.error,
                          ),
                          onPressed: () =>
                              _confirmDeleteAll(context, ref, songs),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => SongTile(
                      song: songs[i],
                      showAlbum: true,
                      onTap: () => ref
                          .read(audioHandlerNotifierProvider)
                          ?.loadQueue(songs, startIndex: i),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.download_done_rounded,
                              size: 16, color: scheme.primary),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded,
                                size: 20),
                            visualDensity: VisualDensity.compact,
                            onPressed: () =>
                                _deleteSong(context, ref, songs[i]),
                          ),
                        ],
                      ),
                    ),
                    childCount: songs.length,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteSong(
      BuildContext context, WidgetRef ref, dynamic song) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete download?'),
        content: Text('Remove "${song.title}" from device?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _removeDownload(ref, song);
  }

  Future<void> _confirmDeleteAll(
      BuildContext context, WidgetRef ref, List songs) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete all downloads?'),
        content:
            Text('Remove all ${songs.length} downloaded songs from device?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete all')),
        ],
      ),
    );
    if (confirmed != true) return;
    for (final song in songs) {
      await _removeDownload(ref, song);
    }
  }

  Future<void> _removeDownload(WidgetRef ref, dynamic song) async {
    await ref
        .read(downloadNotifierProvider.notifier)
        .removeDownload(song.id as String);
  }
}

// Each tile only rebuilds when its own download's progress/status changes,
// not when other songs' downloads update.
class _ActiveDownloadTile extends ConsumerWidget {
  final String songId;
  const _ActiveDownloadTile({required this.songId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(
      downloadNotifierProvider.select((m) => m[songId]),
    );
    if (item == null) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: CoverArtImage(coverArtId: item.song.coverArt, size: 48),
      title: Text(
        item.song.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.song.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          if (item.status != 'queued')
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: item.progress,
                minHeight: 3,
                backgroundColor: scheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(scheme.primary),
              ),
            ),
        ],
      ),
      trailing: Text(
        item.status == 'queued'
            ? 'Queued'
            : '${(item.progress * 100).round()}%',
        style: TextStyle(
          fontSize: 12,
          color: item.status == 'queued'
              ? scheme.onSurfaceVariant
              : scheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
