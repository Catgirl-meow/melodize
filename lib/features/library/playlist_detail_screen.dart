import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/playlist.dart';
import '../../core/audio/shuffle_mode.dart';
import '../../core/providers.dart';
import '../../shared/widgets/detail_header.dart';
import '../../shared/widgets/song_tile.dart';

class PlaylistDetailScreen extends ConsumerWidget {
  final Playlist playlist;
  const PlaylistDetailScreen({super.key, required this.playlist});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songsAsync = ref.watch(playlistSongsProvider(playlist.id));

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          DetailHeader(
            title: playlist.name,
            subtitle: '${playlist.songCount} '
                '${playlist.songCount == 1 ? 'song' : 'songs'}',
            coverArtId: playlist.coverArt,
            expandedHeight: 260,
          ),
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
                        label: const Text('Play all'),
                        onPressed: () {
                          ref
                              .read(audioHandlerNotifierProvider)
                              ?.loadQueue(songs);
                          Navigator.pop(context);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonalIcon(
                      icon: const Icon(Icons.shuffle_rounded),
                      label: const Text('Shuffle'),
                      onPressed: () async {
                        final h =
                            ref.read(audioHandlerNotifierProvider);
                        if (h == null) return;
                        await h.applyShuffleMode(ShuffleMode.shuffle);
                        await h.loadQueue(songs);
                        if (context.mounted) Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          songsAsync.when(
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) =>
                SliverFillRemaining(child: Center(child: Text('$e'))),
            data: (songs) => SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => SongTile(
                  song: songs[i],
                  showAlbum: true,
                  onTap: () => ref
                      .read(audioHandlerNotifierProvider)
                      ?.loadQueue(songs, startIndex: i),
                ),
                childCount: songs.length,
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.paddingOf(context).bottom + 16),
          ),
        ],
      ),
    );
  }
}
