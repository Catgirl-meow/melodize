import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/album.dart';
import '../../core/models/song.dart';
import '../../core/providers.dart';
import '../../shared/widgets/cover_art_image.dart';
import '../../shared/widgets/song_tile.dart';
import 'album_detail_screen.dart';
import 'playlist_detail_screen.dart';

// ---------------------------------------------------------------------------
// Song sorting

enum _SongSort { name, artist, recentlyAdded, downloaded }

String _songSortLabel(_SongSort s) => switch (s) {
      _SongSort.name => 'Name',
      _SongSort.artist => 'Artist',
      _SongSort.recentlyAdded => 'Recently added',
      _SongSort.downloaded => 'Downloaded',
    };

IconData _songSortIcon(_SongSort s) => switch (s) {
      _SongSort.name => Icons.sort_by_alpha_rounded,
      _SongSort.artist => Icons.person_rounded,
      _SongSort.recentlyAdded => Icons.schedule_rounded,
      _SongSort.downloaded => Icons.download_done_rounded,
    };

List<Song> _applySongSort(
    List<Song> songs, _SongSort sort, bool ascending, Set<String> downloadedIds) {
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
        return b.created!.compareTo(a.created!);
      });
    case _SongSort.downloaded:
      list.sort((a, b) {
        final aDown = a.isDownloaded || downloadedIds.contains(a.id);
        final bDown = b.isDownloaded || downloadedIds.contains(b.id);
        if (aDown == bDown) {
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        }
        return aDown ? -1 : 1;
      });
  }
  if (!ascending) return list.reversed.toList();
  return list;
}

// ---------------------------------------------------------------------------
// Album sorting

enum _AlbumSort { name, artist, year, songCount }

String _albumSortLabel(_AlbumSort s) => switch (s) {
      _AlbumSort.name => 'Name',
      _AlbumSort.artist => 'Artist',
      _AlbumSort.year => 'Year',
      _AlbumSort.songCount => 'Song count',
    };

IconData _albumSortIcon(_AlbumSort s) => switch (s) {
      _AlbumSort.name => Icons.sort_by_alpha_rounded,
      _AlbumSort.artist => Icons.person_rounded,
      _AlbumSort.year => Icons.calendar_today_rounded,
      _AlbumSort.songCount => Icons.music_note_rounded,
    };

List<Album> _applyAlbumSort(List<Album> albums, _AlbumSort sort, bool ascending) {
  final list = List<Album>.from(albums);
  switch (sort) {
    case _AlbumSort.name:
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    case _AlbumSort.artist:
      list.sort((a, b) {
        final c = a.artist.toLowerCase().compareTo(b.artist.toLowerCase());
        return c != 0 ? c : a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    case _AlbumSort.year:
      list.sort((a, b) {
        if (a.year == null && b.year == null) return 0;
        if (a.year == null) return 1;
        if (b.year == null) return -1;
        return b.year!.compareTo(a.year!); // newest first by default
      });
    case _AlbumSort.songCount:
      list.sort((a, b) => b.songCount.compareTo(a.songCount));
  }
  if (!ascending) return list.reversed.toList();
  return list;
}

// ---------------------------------------------------------------------------

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return DefaultTabController(
      length: 4,
      child: NestedScrollView(
        headerSliverBuilder: (context, __) => [
          SliverAppBar(
            pinned: true,
            backgroundColor: scheme.surface,
            surfaceTintColor: Colors.transparent,
            title: const Text('Library'),
            bottom: TabBar(
              splashBorderRadius: BorderRadius.circular(50),
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(50),
                color: scheme.secondaryContainer,
              ),
              labelColor: scheme.onSecondaryContainer,
              unselectedLabelColor: scheme.onSurfaceVariant,
              dividerColor: Colors.transparent,
              tabs: const [
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
  bool _ascending = true;

  void _showSortSheet(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: StatefulBuilder(
          builder: (ctx, setSheetState) => Column(
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
                    _songSortIcon(option),
                    color: _sort == option ? scheme.primary : null,
                  ),
                  title: Text(_songSortLabel(option)),
                  trailing: _sort == option
                      ? Icon(
                          _ascending
                              ? Icons.arrow_upward_rounded
                              : Icons.arrow_downward_rounded,
                          color: scheme.primary,
                          size: 20,
                        )
                      : null,
                  onTap: () {
                    setSheetState(() {
                      if (_sort == option) {
                        _ascending = !_ascending;
                      } else {
                        _sort = option;
                        _ascending = true;
                      }
                    });
                    setState(() {});
                    Navigator.pop(context);
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

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
        final songs = _applySongSort(rawSongs, _sort, _ascending, downloadedIds);
        return CustomScrollView(
          slivers: [
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
                      icon: Icon(
                        _ascending
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        size: 16,
                      ),
                      label: Text(_songSortLabel(_sort)),
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

class _AlbumsTab extends ConsumerStatefulWidget {
  const _AlbumsTab();

  @override
  ConsumerState<_AlbumsTab> createState() => _AlbumsTabState();
}

class _AlbumsTabState extends ConsumerState<_AlbumsTab> {
  _AlbumSort _sort = _AlbumSort.name;
  bool _ascending = true;

  void _showSortSheet(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: StatefulBuilder(
          builder: (ctx, setSheetState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text('Sort albums',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              for (final option in _AlbumSort.values)
                ListTile(
                  leading: Icon(
                    _albumSortIcon(option),
                    color: _sort == option ? scheme.primary : null,
                  ),
                  title: Text(_albumSortLabel(option)),
                  trailing: _sort == option
                      ? Icon(
                          _ascending
                              ? Icons.arrow_upward_rounded
                              : Icons.arrow_downward_rounded,
                          color: scheme.primary,
                          size: 20,
                        )
                      : null,
                  onTap: () {
                    setSheetState(() {
                      if (_sort == option) {
                        _ascending = !_ascending;
                      } else {
                        _sort = option;
                        _ascending = true;
                      }
                    });
                    setState(() {});
                    Navigator.pop(context);
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final albumsAsync = ref.watch(allAlbumsProvider);
    final scheme = Theme.of(context).colorScheme;

    return albumsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (rawAlbums) {
        if (rawAlbums.isEmpty) return const Center(child: Text('No albums'));
        final albums = _applyAlbumSort(rawAlbums, _sort, _ascending);
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
                child: Row(
                  children: [
                    Text(
                      '${albums.length} albums',
                      style: TextStyle(
                          color: scheme.onSurfaceVariant, fontSize: 13),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => _showSortSheet(context),
                      icon: Icon(
                        _ascending
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        size: 16,
                      ),
                      label: Text(_albumSortLabel(_sort)),
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
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (_, i) {
                    final album = albums[i];
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
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13)),
                                Text(
                                  album.year != null
                                      ? '${album.artist} · ${album.year}'
                                      : album.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: scheme.onSurfaceVariant),
                                ),
                                Text(
                                  '${album.songCount} ${album.songCount == 1 ? 'song' : 'songs'}',
                                  maxLines: 1,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: scheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],
                      ),
                    );
                  },
                  childCount: albums.length,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.70,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
              ),
            ),
          ],
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
