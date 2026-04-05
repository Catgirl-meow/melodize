import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/album.dart';
import '../../core/models/song.dart';
import '../../core/providers.dart';
import '../../shared/widgets/cover_art_image.dart';
import '../../shared/widgets/offline_banner.dart';
import '../../shared/widgets/song_tile.dart';
import 'album_detail_screen.dart';

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
        return b.year!.compareTo(a.year!);
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
    // Plain Scaffold + AppBar is much lighter than NestedScrollView +
    // SliverAppBar when the app bar is always pinned anyway.
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Library'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Songs'),
              Tab(text: 'Albums'),
              Tab(text: 'Artists'),
            ],
          ),
        ),
        body: const Column(
          children: [
            OfflineBanner(),
            Expanded(
              child: TabBarView(
                children: [
                  RepaintBoundary(child: _SongsTab()),
                  RepaintBoundary(child: _AlbumsTab()),
                  RepaintBoundary(child: _ArtistsTab()),
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

class _SongsTab extends ConsumerStatefulWidget {
  const _SongsTab();

  @override
  ConsumerState<_SongsTab> createState() => _SongsTabState();
}

class _SongsTabState extends ConsumerState<_SongsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  void _showSortSheet(BuildContext context, _SongSort currentSort, bool currentAscending) {
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: StatefulBuilder(
          builder: (ctx, setSheetState) {
            var sheetSort = currentSort;
            var sheetAscending = currentAscending;
            return Column(
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
                      color: sheetSort == option ? scheme.primary : null,
                    ),
                    title: Text(_songSortLabel(option)),
                    trailing: sheetSort == option
                        ? Icon(
                            sheetAscending
                                ? Icons.arrow_upward_rounded
                                : Icons.arrow_downward_rounded,
                            color: scheme.primary,
                            size: 20,
                          )
                        : null,
                    onTap: () {
                      if (sheetSort == option) {
                        sheetAscending = !sheetAscending;
                      } else {
                        sheetSort = option;
                        sheetAscending = true;
                      }
                      ref.read(preferencesNotifierProvider.notifier).update(
                        ref.read(preferencesNotifierProvider).copyWith(
                          librarySongSort: sheetSort.name,
                          librarySongAscending: sheetAscending,
                        ),
                      );
                      Navigator.pop(context);
                    },
                  ),
                const SizedBox(height: 8),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by AutomaticKeepAliveClientMixin

    final (sortName, ascending) = ref.watch(
      preferencesNotifierProvider.select(
        (p) => (p.librarySongSort, p.librarySongAscending),
      ),
    );
    final sort = _SongSort.values.firstWhere(
      (s) => s.name == sortName,
      orElse: () => _SongSort.name,
    );

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
        final songs = _applySongSort(rawSongs, sort, ascending, downloadedIds);
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
                      onPressed: () => _showSortSheet(context, sort, ascending),
                      icon: Icon(
                        ascending
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        size: 16,
                      ),
                      label: Text(_songSortLabel(sort)),
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
                (_, i) => RepaintBoundary(
                  child: SongTile(
                    song: songs[i],
                    showAlbum: true,
                    onTap: () => ref
                        .read(audioHandlerNotifierProvider)
                        ?.loadQueue(songs, startIndex: i),
                  ),
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

class _AlbumsTabState extends ConsumerState<_AlbumsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  void _showSortSheet(BuildContext context, _AlbumSort currentSort, bool currentAscending) {
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: StatefulBuilder(
          builder: (ctx, setSheetState) {
            var sheetSort = currentSort;
            var sheetAscending = currentAscending;
            return Column(
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
                      color: sheetSort == option ? scheme.primary : null,
                    ),
                    title: Text(_albumSortLabel(option)),
                    trailing: sheetSort == option
                        ? Icon(
                            sheetAscending
                                ? Icons.arrow_upward_rounded
                                : Icons.arrow_downward_rounded,
                            color: scheme.primary,
                            size: 20,
                          )
                        : null,
                    onTap: () {
                      if (sheetSort == option) {
                        sheetAscending = !sheetAscending;
                      } else {
                        sheetSort = option;
                        sheetAscending = true;
                      }
                      ref.read(preferencesNotifierProvider.notifier).update(
                        ref.read(preferencesNotifierProvider).copyWith(
                          libraryAlbumSort: sheetSort.name,
                          libraryAlbumAscending: sheetAscending,
                        ),
                      );
                      Navigator.pop(context);
                    },
                  ),
                const SizedBox(height: 8),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final (sortName, ascending) = ref.watch(
      preferencesNotifierProvider.select(
        (p) => (p.libraryAlbumSort, p.libraryAlbumAscending),
      ),
    );
    final sort = _AlbumSort.values.firstWhere(
      (s) => s.name == sortName,
      orElse: () => _AlbumSort.name,
    );

    final albumsAsync = ref.watch(allAlbumsProvider);
    final scheme = Theme.of(context).colorScheme;

    return albumsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (rawAlbums) {
        if (rawAlbums.isEmpty) return const Center(child: Text('No albums'));
        final albums = _applyAlbumSort(rawAlbums, sort, ascending);
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
                      onPressed: () => _showSortSheet(context, sort, ascending),
                      icon: Icon(
                        ascending
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        size: 16,
                      ),
                      label: Text(_albumSortLabel(sort)),
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
                    return RepaintBoundary(
                      child: InkWell(
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
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
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
// Artist sorting

enum _ArtistSort { name, albumCount }

String _artistSortLabel(_ArtistSort s) => switch (s) {
      _ArtistSort.name => 'Name',
      _ArtistSort.albumCount => 'Album count',
    };

IconData _artistSortIcon(_ArtistSort s) => switch (s) {
      _ArtistSort.name => Icons.sort_by_alpha_rounded,
      _ArtistSort.albumCount => Icons.album_rounded,
    };

// ---------------------------------------------------------------------------

class _ArtistsTab extends ConsumerStatefulWidget {
  const _ArtistsTab();

  @override
  ConsumerState<_ArtistsTab> createState() => _ArtistsTabState();
}

class _ArtistsTabState extends ConsumerState<_ArtistsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  void _showSortSheet(BuildContext context, _ArtistSort currentSort, bool currentAscending) {
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: StatefulBuilder(
          builder: (ctx, setSheetState) {
            var sheetSort = currentSort;
            var sheetAscending = currentAscending;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text('Sort artists',
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                for (final option in _ArtistSort.values)
                  ListTile(
                    leading: Icon(
                      _artistSortIcon(option),
                      color: sheetSort == option ? scheme.primary : null,
                    ),
                    title: Text(_artistSortLabel(option)),
                    trailing: sheetSort == option
                        ? Icon(
                            sheetAscending
                                ? Icons.arrow_upward_rounded
                                : Icons.arrow_downward_rounded,
                            color: scheme.primary,
                            size: 20,
                          )
                        : null,
                    onTap: () {
                      if (sheetSort == option) {
                        sheetAscending = !sheetAscending;
                      } else {
                        sheetSort = option;
                        sheetAscending = true;
                      }
                      ref.read(preferencesNotifierProvider.notifier).update(
                        ref.read(preferencesNotifierProvider).copyWith(
                          libraryArtistSort: sheetSort.name,
                          libraryArtistAscending: sheetAscending,
                        ),
                      );
                      Navigator.pop(context);
                    },
                  ),
                const SizedBox(height: 8),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final (sortName, ascending) = ref.watch(
      preferencesNotifierProvider.select(
        (p) => (p.libraryArtistSort, p.libraryArtistAscending),
      ),
    );
    final sort = _ArtistSort.values.firstWhere(
      (s) => s.name == sortName,
      orElse: () => _ArtistSort.name,
    );

    final artistsAsync = ref.watch(allArtistsProvider);
    return artistsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (rawArtists) {
        if (rawArtists.isEmpty) return const Center(child: Text('No artists'));
        final artists = rawArtists.toList();
        switch (sort) {
          case _ArtistSort.name:
            artists.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
          case _ArtistSort.albumCount:
            artists.sort((a, b) => b.albumCount.compareTo(a.albumCount));
        }
        if (!ascending) artists.setRange(0, artists.length, artists.reversed.toList());
        final scheme = Theme.of(context).colorScheme;
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
                child: Row(
                  children: [
                    Text(
                      '${artists.length} artists',
                      style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => _showSortSheet(context, sort, ascending),
                      icon: Icon(
                        ascending
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        size: 16,
                      ),
                      label: Text(_artistSortLabel(sort)),
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
                (_, i) {
                  final artist = artists[i];
                  return RepaintBoundary(
                    child: ListTile(
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
                    ),
                  );
                },
                childCount: artists.length,
              ),
            ),
          ],
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
            return RepaintBoundary(
              child: InkWell(
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
              ),
            );
          },
        ),
      ),
    );
  }
}
