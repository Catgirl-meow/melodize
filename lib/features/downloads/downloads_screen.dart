import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../shared/widgets/cover_art_image.dart';
import '../../shared/widgets/song_tile.dart';

class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Select returns a comma-joined string of active IDs — stable for equality
    // checks so this screen only rebuilds when downloads are added/removed,
    // not on every progress tick. Individual _ActiveTile widgets watch their
    // own slice for progress updates.
    final activeIdsStr = ref.watch(
      downloadNotifierProvider.select((m) {
        final ids = m.entries
            .where((e) =>
                e.value.status == 'downloading' ||
                e.value.status == 'queued')
            .map((e) => e.key)
            .toList()
          ..sort();
        return ids.join(',');
      }),
    );
    final activeIds =
        activeIdsStr.isEmpty ? const <String>[] : activeIdsStr.split(',');
    final downloadedAsync = ref.watch(downloadedSongsProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverAppBar(
            pinned: true,
            title: Text('Downloads'),
          ),

          // Active downloads
          if (activeIds.isNotEmpty) ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              sliver: SliverToBoxAdapter(
                child: Text('Downloading',
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(color: scheme.primary)),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => _ActiveTile(songId: activeIds[i]),
                childCount: activeIds.length,
              ),
            ),
          ],

          // Downloaded songs
          downloadedAsync.when(
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) =>
                SliverFillRemaining(child: Center(child: Text('$e'))),
            data: (songs) {
              if (songs.isEmpty && activeIds.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.download_rounded,
                            size: 64, color: scheme.onSurfaceVariant),
                        const SizedBox(height: 12),
                        Text('No downloaded songs',
                            style: TextStyle(
                                color: scheme.onSurfaceVariant)),
                        const SizedBox(height: 4),
                        Text(
                          'Tap ··· on any song to download it',
                          style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                );
              }
              if (songs.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) {
                    if (i == 0) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                        child: Text('Downloaded',
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(color: scheme.primary)),
                      );
                    }
                    final idx = i - 1;
                    return SongTile(
                      song: songs[idx],
                      onTap: () => ref
                          .read(audioHandlerNotifierProvider)
                          ?.loadQueue(songs, startIndex: idx),
                    );
                  },
                  childCount: songs.length + 1, // +1 for the header
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Rebuilds only when this song's own download progress/status changes.
class _ActiveTile extends ConsumerWidget {
  final String songId;
  const _ActiveTile({required this.songId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(
      downloadNotifierProvider.select((m) => m[songId]),
    );
    if (item == null) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: CoverArtImage(coverArtId: item.song.coverArt, size: 48),
      title: Text(item.song.title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.song.artist,
              style: TextStyle(
                  color: scheme.onSurfaceVariant, fontSize: 12)),
          if (item.status != 'queued') ...[
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: item.progress,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ],
      ),
      trailing: Text(
        item.status == 'queued'
            ? 'Queued'
            : '${(item.progress * 100).toInt()}%',
        style: TextStyle(color: scheme.onSurfaceVariant),
      ),
    );
  }
}
