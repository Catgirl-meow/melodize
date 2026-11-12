import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/album.dart';
import '../../core/audio/shuffle_mode.dart';
import '../../core/providers.dart';
import '../../shared/utils/song_actions.dart';
import '../../shared/widgets/detail_actions.dart';
import '../../shared/widgets/detail_header.dart';
import '../../shared/widgets/song_tile.dart';

class AlbumDetailScreen extends ConsumerWidget {
  final Album album;
  const AlbumDetailScreen({super.key, required this.album});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songsAsync = ref.watch(albumSongsProvider(album.id));
    final songs = songsAsync.valueOrNull;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          DetailHeader(
            title: album.name,
            subtitle: album.year != null
                ? '${album.artist} · ${album.year}'
                : album.artist,
            coverArtId: album.coverArt,
          ),
          SliverToBoxAdapter(
            child: DetailActions(
              onPlay: songs == null || songs.isEmpty
                  ? null
                  : () {
                      ref.read(audioHandlerNotifierProvider)?.loadQueue(songs);
                      Navigator.pop(context);
                    },
              onShuffle: songs == null || songs.isEmpty
                  ? null
                  : () async {
                      final h = ref.read(audioHandlerNotifierProvider);
                      if (h == null) return;
                      await h.applyShuffleMode(ShuffleMode.shuffle);
                      await h.loadQueue(songs);
                      if (context.mounted) Navigator.pop(context);
                    },
              onDownload: () => downloadAlbum(context, ref, album),
              downloadTooltip: 'Download album',
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
                  leading: _TrackNumber(songs[i].track),
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

/// Track number in the cover slot: every row on an album page has the same
/// cover, so the number is the useful part.
class _TrackNumber extends StatelessWidget {
  final int? track;
  const _TrackNumber(this.track);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Center(
        child: Text(
          track?.toString() ?? '–',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
        ),
      ),
    );
  }
}
