import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/album.dart';
import '../../core/models/artist.dart';
import '../../core/providers.dart';
import '../../core/utils/platform_dirs.dart';
import '../../shared/utils/snack.dart';
import '../../shared/utils/song_actions.dart';
import '../../shared/widgets/album_grid_tile.dart';
import '../../shared/widgets/detail_actions.dart';
import '../../shared/widgets/detail_header.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/deezer_track_tile.dart';
import '../../shared/widgets/song_tile.dart';
import 'album_detail_screen.dart';

class ArtistDetailScreen extends ConsumerWidget {
  final Artist artist;
  const ArtistDetailScreen({super.key, required this.artist});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albumsAsync = ref.watch(artistAlbumsProvider(artist.id));
    final topSongsAsync = ref.watch(artistTopSongsProvider(artist.name));
    final allSongsAsync = ref.watch(artistAllSongsProvider(artist.id));
    final deezerAsync = ref.watch(deezerArtistTracksProvider(artist.name));

    final allSongs = allSongsAsync.valueOrNull;
    final topSongs = (topSongsAsync.valueOrNull ?? const []).take(5).toList();
    final albums = albumsAsync.valueOrNull ?? const [];
    final deezerTracks = deezerAsync.valueOrNull ?? const [];

    Future<void> downloadAll() async {
      final songs = allSongsAsync.valueOrNull;
      if (songs == null || songs.isEmpty) return;
      final dir = await getAppStorageDirectory();
      final prefs = ref.read(preferencesNotifierProvider);
      ref.read(downloadNotifierProvider.notifier).downloadBatch(
        songs,
        '${dir.path}/melodize_downloads',
        prefs.downloadQuality,
      );
      if (context.mounted) {
        showStyledSnack(context, 'Downloading ${songs.length} songs…');
      }
    }

    void playAll({bool shuffle = false}) {
      if (allSongs == null || allSongs.isEmpty) return;
      final handler = ref.read(audioHandlerNotifierProvider);
      final queue = shuffle ? ([...allSongs]..shuffle()) : allSongs;
      handler?.loadQueue(queue);
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── Collapsing artist header ─────────────────────────────────────
          DetailHeader(
            title: artist.name,
            subtitle: _statsLabel(artist.albumCount, allSongs?.length),
            coverArtId: artist.coverArt,
            stretch: true,
          ),

          // ── Action row ───────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: DetailActions(
              onPlay: allSongs != null && allSongs.isNotEmpty
                  ? () => playAll()
                  : null,
              onShuffle: allSongs != null && allSongs.isNotEmpty
                  ? () => playAll(shuffle: true)
                  : null,
              onDownload: allSongs != null && allSongs.isNotEmpty
                  ? downloadAll
                  : null,
              downloadBusy: allSongsAsync.isLoading,
            ),
          ),

          // ── Top Songs ────────────────────────────────────────────────────
          if (topSongsAsync.isLoading)
            const SliverToBoxAdapter(child: SizedBox.shrink()),
          if (!topSongsAsync.isLoading && topSongs.isNotEmpty) ...[
            const SliverToBoxAdapter(child: SectionHeader('Top songs')),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => SongTile(
                  song: topSongs[i],
                  onTap: () => ref
                      .read(audioHandlerNotifierProvider)
                      ?.loadQueue(topSongs, startIndex: i),
                ),
                childCount: topSongs.length,
              ),
            ),
          ],

          // ── On Deezer ────────────────────────────────────────────────────
          // Shows tracks the user doesn't own yet — preview or save to server.
          // Hidden while loading or when all tracks are already in the library.
          if (deezerAsync.isLoading)
            const SliverToBoxAdapter(child: SizedBox.shrink()),
          if (!deezerAsync.isLoading && deezerTracks.isNotEmpty)
            SliverMainAxisGroup(
              slivers: [
                SliverToBoxAdapter(
                  child: SectionHeader(
                    'On Deezer',
                    count: '${deezerTracks.length}',
                    icon: Icons.headphones_rounded,
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => DeezerTrackTile(track: deezerTracks[i]),
                    childCount: deezerTracks.length,
                  ),
                ),
              ],
            ),

          // ── Albums ───────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: SectionHeader(
              'Albums',
              count: albums.isNotEmpty ? '${albums.length}' : null,
            ),
          ),
          albumsAsync.when(
            loading: () => const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (e, _) => SliverToBoxAdapter(
              child: Center(child: Text('$e')),
            ),
            data: (albums) => albums.isEmpty
                ? const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('No albums')),
                    ),
                  )
                : SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    // Square covers plus room for a two-line album name,
                    // sized from the text scale (see _AlbumCard).
                    sliver: SliverLayoutBuilder(
                      builder: (context, constraints) {
                        final tileWidth = (constraints.crossAxisExtent - 8) / 2;
                        return SliverGrid(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisExtent: AlbumGridTile.extent(
                                context, tileWidth,
                                detailLines: 1),
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (_, i) => RepaintBoundary(
                              child: _AlbumCard(album: albums[i]),
                            ),
                            childCount: albums.length,
                          ),
                        );
                      },
                    ),
                  ),
          ),

          // ── All Songs ────────────────────────────────────────────────────
          allSongsAsync.when(
            loading: () => const SliverToBoxAdapter(
              child: SectionHeader('Songs', count: '…'),
            ),
            error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
            data: (songs) => songs.isEmpty
                ? const SliverToBoxAdapter(child: SizedBox.shrink())
                : SliverMainAxisGroup(
                    slivers: [
                      SliverToBoxAdapter(
                        child: SectionHeader(
                          'Songs',
                          count: '${songs.length}',
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
                          ),
                          childCount: songs.length,
                        ),
                      ),
                    ],
                  ),
          ),

          const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
        ],
      ),
    );
  }

  static String _statsLabel(int albumCount, int? songCount) {
    final parts = [
      '$albumCount ${albumCount == 1 ? 'album' : 'albums'}',
      if (songCount != null) '$songCount ${songCount == 1 ? 'song' : 'songs'}',
    ];
    return parts.join(' · ');
  }
}

// ---------------------------------------------------------------------------

class _AlbumCard extends ConsumerWidget {
  final Album album;
  const _AlbumCard({required this.album});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AlbumGridTile(
      coverArtId: album.coverArt,
      title: album.name,
      subtitle: album.year != null ? '${album.year}' : null,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AlbumDetailScreen(album: album)),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.download_rounded, size: 20),
        tooltip: 'Download album',
        visualDensity: VisualDensity.compact,
        style: IconButton.styleFrom(
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: () => downloadAlbum(context, ref, album),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

