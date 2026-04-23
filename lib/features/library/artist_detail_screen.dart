import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/album.dart';
import '../../core/models/artist.dart';
import '../../core/providers.dart';
import '../../core/utils/platform_dirs.dart';
import '../../shared/utils/snack.dart';
import '../../shared/utils/song_actions.dart';
import '../../shared/widgets/cover_art_image.dart';
import '../../shared/widgets/song_tile.dart';
import 'album_detail_screen.dart';

class ArtistDetailScreen extends ConsumerWidget {
  final Artist artist;
  const ArtistDetailScreen({super.key, required this.artist});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final albumsAsync = ref.watch(artistAlbumsProvider(artist.id));
    final topSongsAsync = ref.watch(artistTopSongsProvider(artist.name));
    final allSongsAsync = ref.watch(artistAllSongsProvider(artist.id));

    final allSongs = allSongsAsync.valueOrNull;
    final topSongs = (topSongsAsync.valueOrNull ?? const []).take(5).toList();
    final albums = albumsAsync.valueOrNull ?? const [];

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
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            stretch: true,
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [
                StretchMode.zoomBackground,
                StretchMode.blurBackground,
              ],
              background: Stack(
                fit: StackFit.expand,
                children: [
                  CoverArtImage(
                    coverArtId: artist.coverArt,
                    size: double.infinity,
                    borderRadius: 0,
                    fit: BoxFit.cover,
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          scheme.surface.withValues(alpha: 0.92),
                        ],
                        stops: const [0.4, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
              titlePadding: const EdgeInsets.fromLTRB(16, 0, 16, 56),
              title: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    artist.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 22),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _statsLabel(artist.albumCount, allSongs?.length),
                    style:
                        TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),

          // ── Action row ───────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Play all'),
                    onPressed: allSongs != null && allSongs.isNotEmpty
                        ? () => playAll()
                        : null,
                  ),
                  FilledButton.tonal(
                    onPressed: allSongs != null && allSongs.isNotEmpty
                        ? () => playAll(shuffle: true)
                        : null,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shuffle_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('Shuffle'),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    icon: allSongsAsync.isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child:
                                CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.download_rounded, size: 18),
                    label: const Text('Download all'),
                    onPressed: allSongs != null && allSongs.isNotEmpty
                        ? downloadAll
                        : null,
                  ),
                ],
              ),
            ),
          ),

          // ── Top Songs ────────────────────────────────────────────────────
          if (topSongsAsync.isLoading)
            const SliverToBoxAdapter(child: SizedBox.shrink()),
          if (!topSongsAsync.isLoading && topSongs.isNotEmpty) ...[
            SliverToBoxAdapter(child: _SectionHeader('Top songs')),
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

          // ── Albums ───────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _SectionHeader(
              'Albums',
              trailing: albums.isNotEmpty ? '${albums.length}' : null,
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
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.70,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => RepaintBoundary(
                          child: _AlbumCard(album: albums[i]),
                        ),
                        childCount: albums.length,
                      ),
                    ),
                  ),
          ),

          // ── All Songs ────────────────────────────────────────────────────
          allSongsAsync.when(
            loading: () => SliverToBoxAdapter(
              child: _SectionHeader('Songs', trailing: '…'),
            ),
            error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
            data: (songs) => songs.isEmpty
                ? const SliverToBoxAdapter(child: SizedBox.shrink())
                : SliverMainAxisGroup(
                    slivers: [
                      SliverToBoxAdapter(
                        child: _SectionHeader(
                          'Songs',
                          trailing: '${songs.length}',
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
    final scheme = Theme.of(context).colorScheme;
    return Card.filled(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AlbumDetailScreen(album: album)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: CoverArtImage(
                coverArtId: album.coverArt,
                size: double.infinity,
                borderRadius: 0,
                fit: BoxFit.cover,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 4, 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          album.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        if (album.year != null)
                          Text(
                            '${album.year}',
                            style: TextStyle(
                                fontSize: 12,
                                color: scheme.onSurfaceVariant),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.download_rounded, size: 20),
                    tooltip: 'Download album',
                    style: IconButton.styleFrom(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => downloadAlbum(context, ref, album),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? trailing;
  const _SectionHeader(this.title, {this.trailing});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            Text(
              trailing!,
              style: TextStyle(
                  fontSize: 13, color: scheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}
