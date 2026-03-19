import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/song.dart';
import '../../core/providers.dart';
import '../../shared/widgets/cover_art_image.dart';
import '../../shared/widgets/song_tile.dart';
import 'album_detail_screen.dart';
import 'playlist_detail_screen.dart';

// ---------------------------------------------------------------------------

enum _SongSort { name, artist, recentlyAdded, downloaded }

String _sortLabel(_SongSort s) => switch (s) {
      _SongSort.name => 'Name',
      _SongSort.artist => 'Artist',
      _SongSort.recentlyAdded => 'Recently added',
      _SongSort.downloaded => 'Downloaded',
    };

List<Song> _applySongSort(
    List<Song> songs, _SongSort sort, Set<String> downloadedIds) {
  final list = List<Song>.from(songs);
  switch (sort) {
    case _SongSort.name:
      list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    case _SongSort.artist:
      list.sort((a, b) {
        final c = a.artist.toLowerCase().compareTo(b.artist.toLowerCase());
        return c != 0 ? c : a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });
    case _SongSort.recentlyAdded:
      list.sort((a, b) {
        if (a.created == null && b.created == null) return 0;
        if (a.created == null) return 1;
        if (b.created == null) return -1;
        return b.created!.compareTo(a.created!); // newest first
      });
    case _SongSort.downloaded:
      list.sort((a, b) {
        // Use live downloadedIds to account for auto-downloaded songs
        final aDown = a.isDownloaded || downloadedIds.contains(a.id);
        final bDown = b.isDownloaded || downloadedIds.contains(b.id);
        if (aDown == bDown) {
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        }
        return aDown ? -1 : 1;
      });
  }
  return list;
}

// ---------------------------------------------------------------------------

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 4,
      child: NestedScrollView(
        headerSliverBuilder: (context, __) => [
          SliverAppBar(
            pinned: true,
            backgroundColor: Theme.of(context).colorScheme.surface,
            surfaceTintColor: Colors.transparent,
            title: const Text('Library'),
            bottom: const TabBar(
              tabs: [
                Tab(text: 'Songs'),
                Tab(text: 'Albums'),
                Tab(text: 'Artists'),
                Tab(text: 'Playlists'),
              ],
            ),
          ),
        ],
        body: const TabBarView(
          children: [
            _SongsTab(),
            _AlbumsTab(),
            _ArtistsTab(),
            _PlaylistsTab(),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _SongsTab extends ConsumerStatefulWidget {
  const _SongsTab();

  @override
  ConsumerState<_SongsTab> createState() => _SongsTabState();
}

class _SongsTabState extends ConsumerState<_SongsTab> {
  _SongSort _sort = _SongSort.name;

  void _showSortSheet(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Sort songs',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            for (final option in _SongSort.values)
              ListTile(
                leading: Icon(
                  _sortIcon(option),
                  color: _sort == option ? scheme.primary : null,
                ),
                title: Text(_sortLabel(option)),
                trailing: _sort == option
                    ? Icon(Icons.check_rounded, color: scheme.primary)
                    : null,
                onTap: () {
                  setState(() => _sort = option);
                  Navigator.pop(context);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  IconData _sortIcon(_SongSort s) => switch (s) {
        _SongSort.name => Icons.sort_by_alpha_rounded,
        _SongSort.artist => Icons.person_rounded,
        _SongSort.recentlyAdded => Icons.schedule_rounded,
        _SongSort.downloaded => Icons.download_done_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final songsAsync = ref.watch(allSongsProvider);
    final scheme = Theme.of(context).colorScheme;

    return songsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (rawSongs) {
        if (rawSongs.isEmpty) {
          return const Center(child: Text('No songs found'));
        }
        final downloadedIds = ref.watch(downloadedSongIdsProvider);
        final songs = _applySongSort(rawSongs, _sort, downloadedIds);
        return CustomScrollView(
          slivers: [
            // Sort bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
                child: Row(
                  children: [
                    Text(
                      '${songs.length} songs',
                      style: TextStyle(
                          color: scheme.onSurfaceVariant, fontSize: 13),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => _showSortSheet(context),
                      icon: const Icon(Icons.sort_rounded, size: 18),
                      label: Text(_sortLabel(_sort)),
                      style: TextButton.styleFrom(
                        foregroundColor: scheme.primary,
                        textStyle: const TextStyle(fontSize: 13),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Song list
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
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------

class _AlbumsTab extends ConsumerWidget {
  const _AlbumsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albumsAsync = ref.watch(allAlbumsProvider);
    return albumsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (albums) {
        if (albums.isEmpty) return const Center(child: Text('No albums'));
        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.78,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: albums.length,
          itemBuilder: (_, i) {
            final album = albums[i];
            final scheme = Theme.of(context).colorScheme;
            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AlbumDetailScreen(album: album),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: CoverArtImage(
                      coverArtId: album.coverArt,
                      size: double.infinity,
                      borderRadius: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(album.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13)),
                        Text(
                          album.year != null
                              ? '${album.artist} · ${album.year}'
                              : album.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12, color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------

class _ArtistsTab extends ConsumerWidget {
  const _ArtistsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artistsAsync = ref.watch(allArtistsProvider);
    return artistsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (artists) {
        if (artists.isEmpty) return const Center(child: Text('No artists'));
        return ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: artists.length,
          itemBuilder: (_, i) {
            final artist = artists[i];
            final scheme = Theme.of(context).colorScheme;
            return ListTile(
              leading: CoverArtImage(
                coverArtId: artist.coverArt,
                size: 48,
                borderRadius: 24,
              ),
              title: Text(artist.name),
              subtitle: Text(
                '${artist.albumCount} ${artist.albumCount == 1 ? 'album' : 'albums'}',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => _ArtistDetailScreen(
                      artistId: artist.id, artistName: artist.name),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ArtistDetailScreen extends ConsumerWidget {
  final String artistId;
  final String artistName;
  const _ArtistDetailScreen(
      {required this.artistId, required this.artistName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albumsAsync = ref.watch(artistAlbumsProvider(artistId));
    return Scaffold(
      appBar: AppBar(title: Text(artistName)),
      body: albumsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (albums) => GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.78,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: albums.length,
          itemBuilder: (_, i) {
            final album = albums[i];
            final scheme = Theme.of(context).colorScheme;
            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AlbumDetailScreen(album: album),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: CoverArtImage(
                      coverArtId: album.coverArt,
                      size: double.infinity,
                      borderRadius: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(album.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13)),
                        if (album.year != null)
                          Text('${album.year}',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _PlaylistsTab extends ConsumerWidget {
  const _PlaylistsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlistsAsync = ref.watch(playlistsProvider);
    return playlistsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (playlists) {
        if (playlists.isEmpty) {
          return const Center(child: Text('No playlists'));
        }
        return ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: playlists.length,
          itemBuilder: (_, i) {
            final p = playlists[i];
            final scheme = Theme.of(context).colorScheme;
            return ListTile(
              leading: CoverArtImage(coverArtId: p.coverArt, size: 56),
              title: Text(p.name),
              subtitle: Text('${p.songCount} songs',
                  style: TextStyle(color: scheme.onSurfaceVariant)),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PlaylistDetailScreen(playlist: p),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
