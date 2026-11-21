import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/shuffle_mode.dart';
import '../../core/library/artist_profile.dart' show formatRuntime;
import '../../core/library/library_overview.dart';
import '../../core/library/local_search.dart'
    show albumsFromSongs, artistsFromSongs;
import '../../core/models/album.dart';
import '../../core/models/app_preferences.dart';
import '../../core/models/artist.dart';
import '../../core/models/playlist.dart';
import '../../core/models/song.dart';
import '../../core/providers.dart';
import '../../core/utils/title_normalize.dart';
import '../../shared/utils/formatting.dart';
import '../../shared/widgets/album_grid_tile.dart';
import '../../shared/widgets/cover_art_image.dart';
import '../../shared/widgets/error_notice.dart';
import '../../shared/widgets/playlist_cover.dart';
import '../../shared/widgets/song_selection.dart';
import '../../shared/widgets/song_tile.dart';
import '../playlists/playlist_dialogs.dart';
import 'artist/artist_portrait.dart' show CookieShape;

/// The chips at the top of Library.
enum LibraryView { all, playlists, albums, artists, songs }

String libraryViewLabel(LibraryView v) => switch (v) {
      LibraryView.all => 'All',
      LibraryView.playlists => 'Playlists',
      LibraryView.albums => 'Albums',
      LibraryView.artists => 'Artists',
      LibraryView.songs => 'Songs',
    };

LibraryView libraryViewFromName(String name) => LibraryView.values
    .firstWhere((v) => v.name == name, orElse: () => LibraryView.all);

/// Where Library's items open. Phones push pages; the desktop layout shows
/// collections and playlists in its right pane.
abstract class LibraryNavigator {
  void openPlaylist(Playlist playlist);
  void openLiked();
  void openDownloaded();
  void openRecentlyAdded();
  void openAlbum(Album album);
  void openArtist(Artist artist);
  void showView(LibraryView view);
}

bool _matches(String query, String haystack) {
  final terms =
      foldForSearch(query).split(' ').where((t) => t.isNotEmpty).toList();
  if (terms.isEmpty) return true;
  final folded = foldForSearch(haystack);
  return terms.every(folded.contains);
}

/// Clears the shell's mini player + bar at the end of a list.
Widget _endPadding(BuildContext context) => SliverPadding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + 16),
    );

Widget _noMatches(String query) => SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text('Nothing matches "${query.trim()}"'),
        ),
      ),
    );

// ---------------------------------------------------------------------------
// Sorting

/// Bottom sheet listing sort options; tapping the current one flips the
/// direction.
void showSortSheet<T>(
  BuildContext context, {
  required String title,
  required List<T> values,
  required String Function(T) label,
  required IconData Function(T) icon,
  required T current,
  required bool ascending,
  required void Function(T sort, bool ascending) onSelected,
  bool showDirection = true,
}) {
  final scheme = Theme.of(context).colorScheme;
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          for (final option in values)
            ListTile(
              leading: Icon(icon(option),
                  color: option == current ? scheme.primary : null),
              title: Text(label(option)),
              trailing: option == current && showDirection
                  ? Icon(
                      ascending
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                      color: scheme.primary,
                      size: 20)
                  : option == current
                      ? Icon(Icons.check_rounded, color: scheme.primary)
                      : null,
              onTap: () {
                Navigator.pop(sheetContext);
                onSelected(
                    option, option == current ? !ascending : true);
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

/// "13 albums ...... ↑ Name  ▦" row at the top of each list.
class LibrarySortBar extends StatelessWidget {
  final String count;
  final String label;
  final bool? ascending;
  final VoidCallback onSort;

  /// Grid/list toggle; hidden when null.
  final bool? grid;
  final VoidCallback? onToggleGrid;

  const LibrarySortBar({
    super.key,
    required this.count,
    required this.label,
    required this.onSort,
    this.ascending,
    this.grid,
    this.onToggleGrid,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 4, 4),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: onSort,
            icon: Icon(
              ascending == null
                  ? Icons.sort_rounded
                  : ascending!
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
              size: 18,
            ),
            label: Text(label),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
          const Spacer(),
          Text(count,
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
          if (grid != null)
            IconButton(
              tooltip: grid! ? 'Show as list' : 'Show as grid',
              onPressed: onToggleGrid,
              icon: Icon(grid!
                  ? Icons.view_list_rounded
                  : Icons.grid_view_rounded),
            )
          else
            const SizedBox(width: 12),
        ],
      ),
    );
  }
}

void _updatePrefs(
    WidgetRef ref, AppPreferences Function(AppPreferences p) change) {
  final notifier = ref.read(preferencesNotifierProvider.notifier);
  notifier.update(change(ref.read(preferencesNotifierProvider)));
}

// ---------------------------------------------------------------------------
// Songs

enum SongSort { name, artist, recentlyAdded, downloaded }

String songSortLabel(SongSort s) => switch (s) {
      SongSort.name => 'Name',
      SongSort.artist => 'Artist',
      SongSort.recentlyAdded => 'Recently added',
      SongSort.downloaded => 'Downloaded',
    };

IconData _songSortIcon(SongSort s) => switch (s) {
      SongSort.name => Icons.sort_by_alpha_rounded,
      SongSort.artist => Icons.person_rounded,
      SongSort.recentlyAdded => Icons.schedule_rounded,
      SongSort.downloaded => Icons.download_done_rounded,
    };

List<Song> applySongSort(
    List<Song> songs, SongSort sort, bool ascending, Set<String> downloadedIds) {
  final list = List<Song>.from(songs);
  switch (sort) {
    case SongSort.name:
      list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    case SongSort.artist:
      list.sort((a, b) {
        final c = a.artist.toLowerCase().compareTo(b.artist.toLowerCase());
        return c != 0 ? c : a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });
    case SongSort.recentlyAdded:
      list.sort((a, b) {
        if (a.created == null && b.created == null) return 0;
        if (a.created == null) return 1;
        if (b.created == null) return -1;
        return b.created!.compareTo(a.created!);
      });
    case SongSort.downloaded:
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

class LibrarySongsView extends ConsumerWidget {
  final String query;
  final SongSelection selection;
  const LibrarySongsView(
      {super.key, required this.query, required this.selection});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (sortName, ascending) = ref.watch(preferencesNotifierProvider
        .select((p) => (p.librarySongSort, p.librarySongAscending)));
    final sort = SongSort.values
        .firstWhere((s) => s.name == sortName, orElse: () => SongSort.name);
    final songsAsync = ref.watch(allSongsProvider);

    return ListenableBuilder(
      listenable: selection,
      builder: (context, _) => songsAsync.when(
        // Keep the list (and its scroll position) during reloads.
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorNotice(
          title: "Couldn't load songs",
          error: e,
          onRetry: () => ref.invalidate(allSongsProvider),
        ),
        data: (rawSongs) {
          // The list is the local cache; when the server refresh failed, say
          // so rather than presenting a stale (or empty) list as the library.
          final syncError = ref.watch(librarySyncErrorProvider);
          final online = ref.watch(isOnlineProvider).valueOrNull ?? true;
          final staleNotice = syncError != null && online
              ? ErrorNotice(
                  title: rawSongs.isEmpty
                      ? "Couldn't load your library from the server"
                      : "Couldn't refresh from the server — showing saved songs",
                  error: syncError,
                  compact: rawSongs.isNotEmpty,
                  onRetry: () => ref.invalidate(allSongsProvider),
                )
              : null;
          if (rawSongs.isEmpty) {
            return staleNotice ?? const Center(child: Text('No songs found'));
          }
          final downloadedIds = ref.watch(downloadedSongIdsProvider);
          final filtered = [
            for (final s in rawSongs)
              if (_matches(query, '${s.title} ${s.artist} ${s.album}')) s
          ];
          final songs = applySongSort(filtered, sort, ascending, downloadedIds);
          final selecting = selection.active;
          return CustomScrollView(
            key: const PageStorageKey('library-songs'),
            slivers: [
              if (staleNotice != null) SliverToBoxAdapter(child: staleNotice),
              SliverToBoxAdapter(
                child: LibrarySortBar(
                  count: songCount(songs.length),
                  label: songSortLabel(sort),
                  ascending: ascending,
                  onSort: () => showSortSheet<SongSort>(
                    context,
                    title: 'Sort songs',
                    values: SongSort.values,
                    label: songSortLabel,
                    icon: _songSortIcon,
                    current: sort,
                    ascending: ascending,
                    onSelected: (s, asc) => _updatePrefs(
                        ref,
                        (p) => p.copyWith(
                            librarySongSort: s.name,
                            librarySongAscending: asc)),
                  ),
                ),
              ),
              if (songs.isEmpty) _noMatches(query),
              SliverList.builder(
                itemCount: songs.length,
                itemBuilder: (_, i) => RepaintBoundary(
                  child: SongTile(
                    song: songs[i],
                    showAlbum: true,
                    selected:
                        selecting ? selection.contains(songs[i].id) : null,
                    onLongPress: () => selection.toggle(songs[i].id),
                    onTap: selecting
                        ? () => selection.toggle(songs[i].id)
                        : () => ref
                            .read(audioHandlerNotifierProvider)
                            ?.loadQueue(songs, startIndex: i),
                  ),
                ),
              ),
              _endPadding(context),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Albums

enum AlbumSort { name, artist, year, songCount }

String _albumSortLabel(AlbumSort s) => switch (s) {
      AlbumSort.name => 'Name',
      AlbumSort.artist => 'Artist',
      AlbumSort.year => 'Year',
      AlbumSort.songCount => 'Song count',
    };

IconData _albumSortIcon(AlbumSort s) => switch (s) {
      AlbumSort.name => Icons.sort_by_alpha_rounded,
      AlbumSort.artist => Icons.person_rounded,
      AlbumSort.year => Icons.calendar_today_rounded,
      AlbumSort.songCount => Icons.music_note_rounded,
    };

List<Album> applyAlbumSort(List<Album> albums, AlbumSort sort, bool ascending) {
  final list = List<Album>.from(albums);
  switch (sort) {
    case AlbumSort.name:
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    case AlbumSort.artist:
      list.sort((a, b) {
        final c = a.artist.toLowerCase().compareTo(b.artist.toLowerCase());
        return c != 0 ? c : a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    case AlbumSort.year:
      list.sort((a, b) {
        if (a.year == null && b.year == null) return 0;
        if (a.year == null) return 1;
        if (b.year == null) return -1;
        return b.year!.compareTo(a.year!);
      });
    case AlbumSort.songCount:
      list.sort((a, b) => b.songCount.compareTo(a.songCount));
  }
  if (!ascending) return list.reversed.toList();
  return list;
}

/// Grid column count for a content [width]: two on phones, more on wide
/// windows so covers don't grow huge.
int gridColumns(double width) => (width / 200).floor().clamp(2, 8);

class LibraryAlbumsView extends ConsumerWidget {
  final String query;
  final LibraryNavigator nav;
  const LibraryAlbumsView({super.key, required this.query, required this.nav});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (sortName, ascending, grid) = ref.watch(preferencesNotifierProvider
        .select((p) =>
            (p.libraryAlbumSort, p.libraryAlbumAscending, p.libraryAlbumsGrid)));
    final sort = AlbumSort.values
        .firstWhere((s) => s.name == sortName, orElse: () => AlbumSort.name);
    final albumsAsync = ref.watch(allAlbumsProvider);
    final scheme = Theme.of(context).colorScheme;

    return albumsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorNotice(
        title: "Couldn't load albums",
        error: e,
        onRetry: () => ref.invalidate(allAlbumsProvider),
      ),
      data: (rawAlbums) {
        if (rawAlbums.isEmpty) return const Center(child: Text('No albums'));
        final albums = applyAlbumSort([
          for (final a in rawAlbums)
            if (_matches(query, '${a.name} ${a.artist}')) a
        ], sort, ascending);
        return CustomScrollView(
          key: const PageStorageKey('library-albums'),
          slivers: [
            SliverToBoxAdapter(
              child: LibrarySortBar(
                count: '${albums.length} ${albums.length == 1 ? 'album' : 'albums'}',
                label: _albumSortLabel(sort),
                ascending: ascending,
                grid: grid,
                onToggleGrid: () => _updatePrefs(
                    ref, (p) => p.copyWith(libraryAlbumsGrid: !grid)),
                onSort: () => showSortSheet<AlbumSort>(
                  context,
                  title: 'Sort albums',
                  values: AlbumSort.values,
                  label: _albumSortLabel,
                  icon: _albumSortIcon,
                  current: sort,
                  ascending: ascending,
                  onSelected: (s, asc) => _updatePrefs(
                      ref,
                      (p) => p.copyWith(
                          libraryAlbumSort: s.name,
                          libraryAlbumAscending: asc)),
                ),
              ),
            ),
            if (albums.isEmpty) _noMatches(query),
            if (grid)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                // Square covers plus room for a two-line album name, sized
                // from the text scale so large fonts don't overflow.
                sliver: SliverLayoutBuilder(builder: (context, constraints) {
                  final cols = gridColumns(constraints.crossAxisExtent);
                  final tileWidth =
                      (constraints.crossAxisExtent - 8 * (cols - 1)) / cols;
                  return SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) {
                        final album = albums[i];
                        return RepaintBoundary(
                          child: AlbumGridTile(
                            coverArtId: album.coverArt,
                            title: album.name,
                            subtitle: album.year != null
                                ? '${album.artist} · ${album.year}'
                                : album.artist,
                            caption: songCount(album.songCount),
                            onTap: () => nav.openAlbum(album),
                          ),
                        );
                      },
                      childCount: albums.length,
                    ),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      mainAxisExtent: AlbumGridTile.extent(context, tileWidth),
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                  );
                }),
              )
            else
              SliverList.builder(
                itemCount: albums.length,
                itemBuilder: (_, i) {
                  final album = albums[i];
                  return ListTile(
                    leading: CoverArtImage(
                        coverArtId: album.coverArt, size: 56, borderRadius: 8),
                    title: Text(album.name,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      [
                        album.artist,
                        if (album.year != null) '${album.year}',
                        songCount(album.songCount),
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                    onTap: () => nav.openAlbum(album),
                  );
                },
              ),
            _endPadding(context),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Artists

enum ArtistSort { name, albumCount }

String _artistSortLabel(ArtistSort s) => switch (s) {
      ArtistSort.name => 'Name',
      ArtistSort.albumCount => 'Album count',
    };

IconData _artistSortIcon(ArtistSort s) => switch (s) {
      ArtistSort.name => Icons.sort_by_alpha_rounded,
      ArtistSort.albumCount => Icons.album_rounded,
    };

class LibraryArtistsView extends ConsumerWidget {
  final String query;
  final LibraryNavigator nav;
  const LibraryArtistsView({super.key, required this.query, required this.nav});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (sortName, ascending) = ref.watch(preferencesNotifierProvider
        .select((p) => (p.libraryArtistSort, p.libraryArtistAscending)));
    final sort = ArtistSort.values
        .firstWhere((s) => s.name == sortName, orElse: () => ArtistSort.name);
    final artistsAsync = ref.watch(allArtistsProvider);
    final scheme = Theme.of(context).colorScheme;

    return artistsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorNotice(
        title: "Couldn't load artists",
        error: e,
        onRetry: () => ref.invalidate(allArtistsProvider),
      ),
      data: (rawArtists) {
        if (rawArtists.isEmpty) return const Center(child: Text('No artists'));
        final artists = [
          for (final a in rawArtists)
            if (_matches(query, a.name)) a
        ];
        switch (sort) {
          case ArtistSort.name:
            artists.sort(
                (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
          case ArtistSort.albumCount:
            artists.sort((a, b) => b.albumCount.compareTo(a.albumCount));
        }
        final shown = ascending ? artists : artists.reversed.toList();
        return CustomScrollView(
          key: const PageStorageKey('library-artists'),
          slivers: [
            SliverToBoxAdapter(
              child: LibrarySortBar(
                count:
                    '${shown.length} ${shown.length == 1 ? 'artist' : 'artists'}',
                label: _artistSortLabel(sort),
                ascending: ascending,
                onSort: () => showSortSheet<ArtistSort>(
                  context,
                  title: 'Sort artists',
                  values: ArtistSort.values,
                  label: _artistSortLabel,
                  icon: _artistSortIcon,
                  current: sort,
                  ascending: ascending,
                  onSelected: (s, asc) => _updatePrefs(
                      ref,
                      (p) => p.copyWith(
                          libraryArtistSort: s.name,
                          libraryArtistAscending: asc)),
                ),
              ),
            ),
            if (shown.isEmpty) _noMatches(query),
            SliverList.builder(
              itemCount: shown.length,
              itemBuilder: (_, i) {
                final artist = shown[i];
                return RepaintBoundary(
                  child: ListTile(
                    leading: CoverArtImage(
                        coverArtId: artist.coverArt,
                        size: 48,
                        borderRadius: 24),
                    title: Text(artist.name),
                    subtitle: Text(
                      '${artist.albumCount} ${artist.albumCount == 1 ? 'album' : 'albums'}',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                    onTap: () => nav.openArtist(artist),
                  ),
                );
              },
            ),
            _endPadding(context),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Playlists

IconData _playlistSortIcon(PlaylistSort s) => switch (s) {
      PlaylistSort.updated => Icons.schedule_rounded,
      PlaylistSort.name => Icons.sort_by_alpha_rounded,
      PlaylistSort.songCount => Icons.music_note_rounded,
    };

/// "32 songs · 2 h 4 min · updated today" for a list row.
String playlistRowSubtitle(Playlist p, String? user) => [
      songCount(p.songCount),
      if (p.duration > 0) formatRuntime(Duration(seconds: p.duration)),
      if (!p.isEditableBy(user))
        p.readonly && (p.owner == null || p.owner == user)
            ? 'smart playlist'
            : 'by ${p.owner}',
      if (updatedLabel(p.changedAt) case final u?) u,
    ].join(' · ');

class LibraryPlaylistsView extends ConsumerWidget {
  final String query;
  final LibraryNavigator nav;
  const LibraryPlaylistsView(
      {super.key, required this.query, required this.nav});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (sortName, grid) = ref.watch(preferencesNotifierProvider
        .select((p) => (p.libraryPlaylistSort, p.libraryPlaylistsGrid)));
    final sort = PlaylistSort.values.firstWhere((s) => s.name == sortName,
        orElse: () => PlaylistSort.updated);
    final user = ref.watch(currentUsernameProvider);
    final async = ref.watch(playlistsProvider);
    final scheme = Theme.of(context).colorScheme;

    return async.when(
      skipLoadingOnReload: true,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorNotice(
        title: "Couldn't load playlists",
        error: e,
        onRetry: () => ref.invalidate(playlistsProvider),
      ),
      data: (all) {
        if (all.isEmpty) {
          return _NoPlaylists(onCreate: () => _create(context, ref));
        }
        final playlists = sortPlaylists(
            [for (final p in all) if (_matches(query, p.name)) p], sort);
        return CustomScrollView(
          key: const PageStorageKey('library-playlists'),
          slivers: [
            SliverToBoxAdapter(
              child: LibrarySortBar(
                count:
                    '${playlists.length} ${playlists.length == 1 ? 'playlist' : 'playlists'}',
                label: playlistSortLabel(sort),
                grid: grid,
                onToggleGrid: () => _updatePrefs(
                    ref, (p) => p.copyWith(libraryPlaylistsGrid: !grid)),
                onSort: () => showSortSheet<PlaylistSort>(
                  context,
                  title: 'Sort playlists',
                  values: PlaylistSort.values,
                  label: playlistSortLabel,
                  icon: _playlistSortIcon,
                  current: sort,
                  ascending: true,
                  showDirection: false,
                  onSelected: (s, _) => _updatePrefs(
                      ref, (p) => p.copyWith(libraryPlaylistSort: s.name)),
                ),
              ),
            ),
            if (playlists.isEmpty) _noMatches(query),
            if (grid)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                sliver: SliverLayoutBuilder(builder: (context, constraints) {
                  final cols = gridColumns(constraints.crossAxisExtent);
                  final tileWidth =
                      (constraints.crossAxisExtent - 8 * (cols - 1)) / cols;
                  return SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => _PlaylistGridTile(
                          playlist: playlists[i],
                          size: tileWidth,
                          user: user,
                          onTap: () => nav.openPlaylist(playlists[i])),
                      childCount: playlists.length,
                    ),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      mainAxisExtent: AlbumGridTile.extent(context, tileWidth,
                          detailLines: 1),
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                  );
                }),
              )
            else
              SliverList.builder(
                itemCount: playlists.length,
                itemBuilder: (_, i) {
                  final p = playlists[i];
                  final locked = !p.isEditableBy(user);
                  return ListTile(
                    key: ValueKey('playlist-row-${p.id}'),
                    leading: PlaylistCover(
                        playlist: p, size: 56, borderRadius: 10),
                    title: Row(
                      children: [
                        Flexible(
                          child: Text(p.name,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        if (locked) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.lock_outline_rounded,
                              size: 16, color: scheme.onSurfaceVariant),
                        ],
                      ],
                    ),
                    subtitle: Text(playlistRowSubtitle(p, user),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: scheme.onSurfaceVariant)),
                    trailing: IconButton(
                      tooltip: 'More',
                      icon: const Icon(Icons.more_vert_rounded),
                      onPressed: () => showPlaylistMenu(context, ref, p),
                    ),
                    onTap: () => nav.openPlaylist(p),
                  );
                },
              ),
            _endPadding(context),
          ],
        );
      },
    );
  }
}

Future<void> _create(BuildContext context, WidgetRef ref) =>
    createPlaylistFlow(context, ref);

class _PlaylistGridTile extends StatelessWidget {
  final Playlist playlist;
  final double size;
  final String? user;
  final VoidCallback onTap;
  const _PlaylistGridTile(
      {required this.playlist,
      required this.size,
      required this.user,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PlaylistCover(playlist: playlist, size: size, borderRadius: 12),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(playlist.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600, height: 1.3)),
                Text(songCount(playlist.songCount),
                    maxLines: 1,
                    style: text.bodySmall?.copyWith(
                        height: 1.3, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoPlaylists extends StatelessWidget {
  final VoidCallback onCreate;
  const _NoPlaylists({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.queue_music_rounded,
                size: 48, color: scheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text('No playlists yet', style: text.titleMedium),
            const SizedBox(height: 4),
            Text('Playlists you make here are saved on your Navidrome server.',
                textAlign: TextAlign.center,
                style:
                    text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded),
              label: const Text('New playlist'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Overview

const _kShelfCover = 128.0;

class LibraryOverview extends ConsumerWidget {
  final String query;
  final LibraryNavigator nav;
  const LibraryOverview({super.key, required this.query, required this.nav});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (query.trim().isNotEmpty) {
      return _OverviewSearch(query: query, nav: nav);
    }
    final songsAsync = ref.watch(allSongsProvider);
    final songs = songsAsync.valueOrNull ?? const <Song>[];
    final likedCount = ref.watch(likedSongsProvider).valueOrNull?.length;
    final downloaded = ref.watch(downloadedSongIdsProvider).length;
    final playlistsAsync = ref.watch(playlistsProvider);
    final artistsAsync = ref.watch(allArtistsProvider);
    final history = ref.watch(playRecordsProvider).valueOrNull ?? const [];
    final recentAlbums = recentlyAddedAlbums(songs, limit: 12);
    final recentSongs = recentlyAddedSongs(songs, limit: 100);
    final scheme = Theme.of(context).colorScheme;

    return CustomScrollView(
      key: const PageStorageKey('library-overview'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          sliver: SliverLayoutBuilder(builder: (context, c) {
            final cols = c.crossAxisExtent >= 700 ? 4 : 2;
            final tiles = [
              _PinnedTile(
                key: const Key('pinned-liked'),
                icon: Icons.favorite_rounded,
                label: 'Liked songs',
                caption: likedCount == null ? null : songCount(likedCount),
                shape: const CookieShape(),
                bg: scheme.primaryContainer,
                fg: scheme.onPrimaryContainer,
                onTap: nav.openLiked,
              ),
              _PinnedTile(
                key: const Key('pinned-downloaded'),
                icon: Icons.download_done_rounded,
                label: 'Downloaded',
                caption: songCount(downloaded),
                shape: const StadiumBorder(),
                bg: scheme.tertiaryContainer,
                fg: scheme.onTertiaryContainer,
                onTap: nav.openDownloaded,
              ),
              _PinnedTile(
                key: const Key('pinned-recent'),
                icon: Icons.history_rounded,
                label: 'Recently added',
                caption: recentSongs.isEmpty ? null : songCount(recentSongs.length),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                bg: scheme.secondaryContainer,
                fg: scheme.onSecondaryContainer,
                onTap: nav.openRecentlyAdded,
              ),
              _PinnedTile(
                key: const Key('pinned-shuffle'),
                icon: Icons.shuffle_rounded,
                label: 'Shuffle all',
                caption: songs.isEmpty ? null : songCount(songs.length),
                shape: const CircleBorder(),
                bg: scheme.surfaceContainerHighest,
                fg: scheme.onSurface,
                onTap: songs.isEmpty
                    ? null
                    : () async {
                        final h = ref.read(audioHandlerNotifierProvider);
                        if (h == null) return;
                        await h.applyShuffleMode(ShuffleMode.shuffle);
                        await h.loadQueue(songs);
                      },
              ),
            ];
            return SliverGrid(
              delegate: SliverChildListDelegate(tiles),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                mainAxisExtent: 64 * MediaQuery.textScalerOf(context).scale(1),
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
            );
          }),
        ),

        // Playlists
        _ShelfHeader(
            title: 'Playlists',
            onSeeAll: () => nav.showView(LibraryView.playlists)),
        SliverToBoxAdapter(
          child: playlistsAsync.when(
            skipLoadingOnReload: true,
            loading: () => const SizedBox(
                height: _kShelfCover + 48,
                child: Center(child: CircularProgressIndicator())),
            error: (e, _) => ErrorNotice(
              title: "Couldn't load playlists",
              error: e,
              compact: true,
              onRetry: () => ref.invalidate(playlistsProvider),
            ),
            data: (all) {
              final list = sortPlaylists(all, PlaylistSort.updated)
                  .take(12)
                  .toList();
              return _Shelf(
                children: [
                  _NewPlaylistCard(onTap: () => _create(context, ref)),
                  for (final p in list)
                    _ShelfCard(
                      cover: PlaylistCover(
                          playlist: p, size: _kShelfCover, borderRadius: 12),
                      title: p.name,
                      subtitle: songCount(p.songCount),
                      onTap: () => nav.openPlaylist(p),
                    ),
                ],
              );
            },
          ),
        ),

        // Recently added albums
        if (recentAlbums.isNotEmpty) ...[
          _ShelfHeader(
              title: 'Recently added',
              onSeeAll: nav.openRecentlyAdded),
          SliverToBoxAdapter(
            child: _Shelf(children: [
              for (final a in recentAlbums)
                _ShelfCard(
                  cover: CoverArtImage(
                      coverArtId: a.coverArt,
                      size: _kShelfCover,
                      borderRadius: 12),
                  title: a.name,
                  subtitle: a.artist,
                  onTap: () => nav.openAlbum(a),
                ),
            ]),
          ),
        ],

        // Artists
        ...artistsAsync.when(
          skipLoadingOnReload: true,
          loading: () => const <Widget>[],
          error: (e, _) => [
            SliverToBoxAdapter(
              child: ErrorNotice(
                title: "Couldn't load artists",
                error: e,
                compact: true,
                onRetry: () => ref.invalidate(allArtistsProvider),
              ),
            ),
          ],
          data: (artists) {
            if (artists.isEmpty) return const <Widget>[];
            final top =
                artistsByPlays(artists, history.map((h) => h.artist), limit: 15);
            return [
              _ShelfHeader(
                  title: 'Artists',
                  onSeeAll: () => nav.showView(LibraryView.artists)),
              SliverToBoxAdapter(
                child: _Shelf(
                  height: 112,
                  children: [
                    for (final a in top)
                      _ArtistCircle(artist: a, onTap: () => nav.openArtist(a)),
                  ],
                ),
              ),
            ];
          },
        ),
        _endPadding(context),
      ],
    );
  }
}

class _PinnedTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? caption;
  final ShapeBorder shape;
  final Color bg;
  final Color fg;
  final VoidCallback? onTap;

  const _PinnedTile({
    super.key,
    required this.icon,
    required this.label,
    required this.caption,
    required this.shape,
    required this.bg,
    required this.fg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              Material(
                color: bg,
                shape: shape,
                child: SizedBox.square(
                  dimension: 40,
                  child: Icon(icon, size: 22, color: fg),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    if (caption != null)
                      Text(caption!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShelfHeader extends StatelessWidget {
  final String title;
  final VoidCallback onSeeAll;
  const _ShelfHeader({required this.title, required this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 4, 4),
        child: Row(
          children: [
            Expanded(
              child: Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ),
            TextButton(
              onPressed: onSeeAll,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('See all'),
                  Icon(Icons.chevron_right_rounded, size: 18),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Shelf extends StatelessWidget {
  final List<Widget> children;
  final double? height;
  const _Shelf({required this.children, this.height});

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return SizedBox(
      height: height ?? _kShelfCover + 8 + 44 * scale,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: children.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => children[i],
      ),
    );
  }
}

class _ShelfCard extends StatelessWidget {
  final Widget cover;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ShelfCard(
      {required this.cover,
      required this.title,
      required this.subtitle,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return SizedBox(
      width: _kShelfCover,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox.square(dimension: _kShelfCover, child: cover),
            const SizedBox(height: 8),
            Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            Text(subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _NewPlaylistCard extends StatelessWidget {
  final VoidCallback onTap;
  const _NewPlaylistCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: _kShelfCover,
      child: Align(
        alignment: Alignment.topCenter,
        child: SizedBox.square(
          dimension: _kShelfCover,
          child: Material(
            color: scheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: scheme.outlineVariant, width: 1.5),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: const Key('overview-new-playlist'),
              onTap: onTap,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_rounded, size: 32, color: scheme.primary),
                  const SizedBox(height: 4),
                  Text('New playlist',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: scheme.primary, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ArtistCircle extends StatelessWidget {
  final Artist artist;
  final VoidCallback onTap;
  const _ArtistCircle({required this.artist, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      child: InkWell(
        borderRadius: BorderRadius.circular(40),
        onTap: onTap,
        child: Column(
          children: [
            CoverArtImage(
                coverArtId: artist.coverArt, size: 80, borderRadius: 40),
            const SizedBox(height: 6),
            Text(artist.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

/// Search from the All chip: matching playlists, albums, artists and songs
/// from the library (works offline, the library is cached).
class _OverviewSearch extends ConsumerWidget {
  final String query;
  final LibraryNavigator nav;
  const _OverviewSearch({required this.query, required this.nav});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final songs = ref.watch(allSongsProvider).valueOrNull ?? const <Song>[];
    final playlists =
        ref.watch(playlistsProvider).valueOrNull ?? const <Playlist>[];
    final user = ref.watch(currentUsernameProvider);
    final pl = [for (final p in playlists) if (_matches(query, p.name)) p];
    final albums = [
      for (final a in albumsFromSongs(songs))
        if (_matches(query, '${a.name} ${a.artist}')) a
    ].take(10).toList();
    final artists = [
      for (final a in artistsFromSongs(songs))
        if (_matches(query, a.name)) a
    ].take(10).toList();
    final matchedSongs = [
      for (final s in songs)
        if (_matches(query, '${s.title} ${s.artist} ${s.album}')) s
    ].take(50).toList();
    final nothing =
        pl.isEmpty && albums.isEmpty && artists.isEmpty && matchedSongs.isEmpty;

    Widget header(String t) => SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(t,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
          ),
        );

    return CustomScrollView(
      slivers: [
        if (nothing) _noMatches(query),
        if (pl.isNotEmpty) ...[
          header('Playlists'),
          SliverList.builder(
            itemCount: pl.length,
            itemBuilder: (_, i) => ListTile(
              leading: PlaylistCover(playlist: pl[i], size: 48),
              title: Text(pl[i].name),
              subtitle: Text(playlistRowSubtitle(pl[i], user),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: scheme.onSurfaceVariant)),
              onTap: () => nav.openPlaylist(pl[i]),
            ),
          ),
        ],
        if (artists.isNotEmpty) ...[
          header('Artists'),
          SliverList.builder(
            itemCount: artists.length,
            itemBuilder: (_, i) => ListTile(
              leading: CoverArtImage(
                  coverArtId: artists[i].coverArt, size: 48, borderRadius: 24),
              title: Text(artists[i].name),
              onTap: () => nav.openArtist(artists[i]),
            ),
          ),
        ],
        if (albums.isNotEmpty) ...[
          header('Albums'),
          SliverList.builder(
            itemCount: albums.length,
            itemBuilder: (_, i) => ListTile(
              leading: CoverArtImage(coverArtId: albums[i].coverArt, size: 48),
              title: Text(albums[i].name),
              subtitle: Text(albums[i].artist,
                  style: TextStyle(color: scheme.onSurfaceVariant)),
              onTap: () => nav.openAlbum(albums[i]),
            ),
          ),
        ],
        if (matchedSongs.isNotEmpty) ...[
          header('Songs'),
          SliverList.builder(
            itemCount: matchedSongs.length,
            itemBuilder: (_, i) => SongTile(
              song: matchedSongs[i],
              showAlbum: true,
              onTap: () => ref
                  .read(audioHandlerNotifierProvider)
                  ?.loadQueue(matchedSongs, startIndex: i),
            ),
          ),
        ],
        _endPadding(context),
      ],
    );
  }
}
