import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/album.dart';
import '../../core/providers.dart';
import '../../shared/utils/song_actions.dart';
import '../../shared/widgets/cover_art_image.dart';
import '../../shared/widgets/song_tile.dart';

class AlbumDetailScreen extends ConsumerWidget {
  final Album album;
  const AlbumDetailScreen({super.key, required this.album});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songsAsync = ref.watch(albumSongsProvider(album.id));
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  CoverArtImage(
                    coverArtId: album.coverArt,
                    size: double.infinity,
                    borderRadius: 0,
                    fit: BoxFit.cover,
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          scheme.surface.withOpacity(0.9),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              titlePadding: const EdgeInsets.fromLTRB(16, 0, 16, 64),
              title: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(album.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 20)),
                  Text(album.artist,
                      style: TextStyle(
                          fontSize: 14, color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
          ),
          // Play all + Download album buttons
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: songsAsync.whenOrNull(
                data: (songs) => Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: Text('Play all · ${songs.length} songs'),
                        onPressed: () {
                          ref
                              .read(audioHandlerNotifierProvider)
                              ?.loadQueue(songs);
                          Navigator.pop(context);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.outlined(
                      icon: const Icon(Icons.download_rounded),
                      tooltip: 'Download album',
                      onPressed: () => downloadAlbum(context, ref, album),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Songs
          songsAsync.when(
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => SliverFillRemaining(
              child: Center(child: Text('$e')),
            ),
            data: (songs) => SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => SongTile(
                  song: songs[i],
                  onTap: () {
                    ref
                        .read(audioHandlerNotifierProvider)
                        ?.loadQueue(songs, startIndex: i);
                  },
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (songs[i].track != null)
                        SizedBox(
                          width: 28,
                          child: Text(
                            '${songs[i].track}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                                fontSize: 13),
                          ),
                        ),
                    ],
                  ),
                ),
                childCount: songs.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
