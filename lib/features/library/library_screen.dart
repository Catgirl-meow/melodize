import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_errors.dart';
import '../../core/library/library_overview.dart';
import '../../core/models/album.dart';
import '../../core/models/artist.dart';
import '../../core/models/playlist.dart';
import '../../core/providers.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/utils/formatting.dart';
import '../../shared/widgets/offline_banner.dart';
import '../../shared/widgets/playlist_cover.dart';
import '../../shared/widgets/song_drag.dart';
import '../../shared/widgets/song_selection.dart';
import '../playlists/playlist_dialogs.dart';
import '../settings/downloaded_songs_screen.dart';
import 'album_detail_screen.dart';
import 'artist_detail_screen.dart';
import 'library_views.dart';
import 'playlist_detail_screen.dart';
import 'song_collection_screen.dart';
import '../../shared/theme/motion.dart';

/// Window width from which Library shows its sidebar layout.
const kLibraryWideBreakpoint = 900.0;

/// Library: one screen for everything the user owns. Phones get filter
/// chips (All, Playlists, Albums, Artists, Songs); wide windows get a
/// sidebar with the playlists always visible. See docs/design.md.
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) => c.maxWidth >= kLibraryWideBreakpoint
          ? const _WideLibrary()
          : const _PhoneLibrary(),
    );
  }
}

void _push(BuildContext context, Widget page) =>
    Navigator.of(context, rootNavigator: true)
        .push(MaterialPageRoute(builder: (_) => page));

// ---------------------------------------------------------------------------
// Phone

class _PhoneLibrary extends ConsumerStatefulWidget {
  const _PhoneLibrary();

  @override
  ConsumerState<_PhoneLibrary> createState() => _PhoneLibraryState();
}

class _PhoneLibraryState extends ConsumerState<_PhoneLibrary>
    implements LibraryNavigator {
  final _selection = SongSelection();
  final _searchController = TextEditingController();
  late LibraryView _view = libraryViewFromName(
      ref.read(preferencesNotifierProvider).libraryView);
  // Views are built the first time they're shown, then kept (scroll
  // position, loaded data) while switching chips.
  late final _visited = <LibraryView>{_view};
  var _searching = false;

  @override
  void initState() {
    super.initState();
    _selection.addListener(_changed);
    _searchController.addListener(_changed);
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    _selection.removeListener(_changed);
    _selection.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String get _query => _searching ? _searchController.text : '';

  @override
  void showView(LibraryView view) {
    if (view == _view) return;
    _selection.clear();
    setState(() {
      _view = view;
      _visited.add(view);
    });
    final prefs = ref.read(preferencesNotifierProvider);
    ref
        .read(preferencesNotifierProvider.notifier)
        .update(prefs.copyWith(libraryView: view.name));
  }

  @override
  void openPlaylist(Playlist playlist) =>
      _push(context, PlaylistDetailScreen(playlist: playlist));
  @override
  void openLiked() => _push(context, const LikedSongsScreen());
  @override
  void openDownloaded() => _push(context, const DownloadedSongsScreen());
  @override
  void openRecentlyAdded() => _push(context, const RecentlyAddedScreen());
  @override
  void openAlbum(Album album) => _push(context, AlbumDetailScreen(album: album));
  @override
  void openArtist(Artist artist) =>
      _push(context, ArtistDetailScreen(artist: artist));

  Widget _viewFor(LibraryView v) => switch (v) {
        LibraryView.all => LibraryOverview(query: _query, nav: this),
        LibraryView.playlists => LibraryPlaylistsView(query: _query, nav: this),
        LibraryView.albums => LibraryAlbumsView(query: _query, nav: this),
        LibraryView.artists => LibraryArtistsView(query: _query, nav: this),
        LibraryView.songs =>
          LibrarySongsView(query: _query, selection: _selection),
      };

  @override
  Widget build(BuildContext context) {
    final selecting = _selection.active;
    final allSongs = ref.watch(allSongsProvider).valueOrNull ?? const [];

    final PreferredSizeWidget appBar = selecting
        ? SongSelectionAppBar(selection: _selection, songs: allSongs)
            as PreferredSizeWidget
        : AppBar(
            title: Text('Library', style: AppTheme.pageTitleStyle(context)),
            titleSpacing: 16,
            toolbarHeight: AppTheme.pageTitleBarHeight,
            automaticallyImplyLeading: false,
            scrolledUnderElevation: 0,
            actions: [
              IconButton(
                key: const Key('library-search'),
                tooltip: _searching ? 'Close search' : 'Search your library',
                icon: Icon(
                    _searching ? Icons.search_off_rounded : Icons.search_rounded),
                onPressed: () => setState(() {
                  _searching = !_searching;
                  if (!_searching) _searchController.clear();
                }),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton.filledTonal(
                  key: const Key('library-new-playlist'),
                  tooltip: 'New playlist',
                  icon: const Icon(Icons.add_rounded),
                  onPressed: () => createPlaylistFlow(context, ref),
                ),
              ),
            ],
          );

    return PopScope(
      canPop: !selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _selection.clear();
      },
      child: Scaffold(
        appBar: appBar,
        floatingActionButton: _view == LibraryView.playlists && !selecting
            ? FloatingActionButton.extended(
                heroTag: 'library-new-playlist-fab',
                onPressed: () => createPlaylistFlow(context, ref),
                icon: const Icon(Icons.add_rounded),
                label: const Text('New playlist'),
              )
            : null,
        body: Column(
          children: [
            const OfflineBanner(),
            if (_searching)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: SearchBar(
                  key: const Key('library-search-field'),
                  controller: _searchController,
                  autoFocus: true,
                  hintText: 'Search in ${libraryViewLabel(_view) == 'All' ? 'your library' : libraryViewLabel(_view).toLowerCase()}',
                  leading: const Icon(Icons.search_rounded),
                  elevation: const WidgetStatePropertyAll(0),
                  trailing: [
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        tooltip: 'Clear',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: _searchController.clear,
                      ),
                  ],
                ),
              ),
            _Chips(current: _view, onSelected: showView),
            Expanded(
              child: IndexedStack(
                index: _view.index,
                children: [
                  for (final v in LibraryView.values)
                    _visited.contains(v)
                        ? RepaintBoundary(child: _viewFor(v))
                        : const SizedBox.shrink(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chips extends StatelessWidget {
  final LibraryView current;
  final ValueChanged<LibraryView> onSelected;
  const _Chips({required this.current, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        children: [
          for (final v in LibraryView.values) ...[
            ChoiceChip(
              key: Key('library-chip-${v.name}'),
              label: Text(libraryViewLabel(v)),
              selected: v == current,
              showCheckmark: true,
              onSelected: (_) => onSelected(v),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Wide (desktop)

/// What the right pane shows.
sealed class _Pane {
  const _Pane();
}

class _ViewPane extends _Pane {
  final LibraryView view;
  const _ViewPane(this.view);
  @override
  bool operator ==(Object other) => other is _ViewPane && other.view == view;
  @override
  int get hashCode => view.hashCode;
}

class _LikedPane extends _Pane {
  const _LikedPane();
}

class _DownloadedPane extends _Pane {
  const _DownloadedPane();
}

class _RecentPane extends _Pane {
  const _RecentPane();
}

class _PlaylistPane extends _Pane {
  final Playlist playlist;
  const _PlaylistPane(this.playlist);
}

class _WideLibrary extends ConsumerStatefulWidget {
  const _WideLibrary();

  @override
  ConsumerState<_WideLibrary> createState() => _WideLibraryState();
}

class _WideLibraryState extends ConsumerState<_WideLibrary>
    implements LibraryNavigator {
  final _selection = SongSelection();
  final _searchController = TextEditingController();
  late _Pane _pane = _ViewPane(
      libraryViewFromName(ref.read(preferencesNotifierProvider).libraryView));

  @override
  void initState() {
    super.initState();
    _selection.addListener(_changed);
    _searchController.addListener(_changed);
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    _selection.removeListener(_changed);
    _selection.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _show(_Pane pane) {
    _selection.clear();
    setState(() => _pane = pane);
  }

  @override
  void showView(LibraryView view) {
    _show(_ViewPane(view));
    final prefs = ref.read(preferencesNotifierProvider);
    ref
        .read(preferencesNotifierProvider.notifier)
        .update(prefs.copyWith(libraryView: view.name));
  }

  @override
  void openPlaylist(Playlist playlist) => _show(_PlaylistPane(playlist));
  @override
  void openLiked() => _show(const _LikedPane());
  @override
  void openDownloaded() => _show(const _DownloadedPane());
  @override
  void openRecentlyAdded() => _show(const _RecentPane());
  @override
  void openAlbum(Album album) => _push(context, AlbumDetailScreen(album: album));
  @override
  void openArtist(Artist artist) =>
      _push(context, ArtistDetailScreen(artist: artist));

  Widget _content() {
    final query = _searchController.text;
    switch (_pane) {
      case _ViewPane(:final view):
        final list = switch (view) {
          LibraryView.all => LibraryOverview(query: query, nav: this),
          LibraryView.playlists =>
            LibraryPlaylistsView(query: query, nav: this),
          LibraryView.albums => LibraryAlbumsView(query: query, nav: this),
          LibraryView.artists => LibraryArtistsView(query: query, nav: this),
          LibraryView.songs =>
            LibrarySongsView(query: query, selection: _selection),
        };
        final allSongs = ref.watch(allSongsProvider).valueOrNull ?? const [];
        return Scaffold(
          key: ValueKey(view),
          appBar: _selection.active
              ? SongSelectionAppBar(selection: _selection, songs: allSongs)
                  as PreferredSizeWidget
              : AppBar(
                  automaticallyImplyLeading: false,
                  toolbarHeight: AppTheme.pageTitleBarHeight,
                  titleSpacing: 24,
                  scrolledUnderElevation: 0,
                  title: Text(
                      view == LibraryView.all
                          ? 'Library'
                          : libraryViewLabel(view),
                      style: AppTheme.pageTitleStyle(context)),
                ),
          body: list,
        );
      case _LikedPane():
        return const LikedSongsScreen(key: ValueKey('liked'));
      case _DownloadedPane():
        return const DownloadedSongsScreen(key: ValueKey('downloaded'));
      case _RecentPane():
        return const RecentlyAddedScreen(key: ValueKey('recent'));
      case _PlaylistPane(:final playlist):
        return PlaylistDetailScreen(
            key: ValueKey('playlist-${playlist.id}'), playlist: playlist);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // A playlist deleted from its page (or elsewhere) leaves the pane.
    ref.listen<AsyncValue<List<Playlist>>>(playlistsProvider, (_, next) {
      final pane = _pane;
      final list = next.valueOrNull;
      if (pane is _PlaylistPane &&
          list != null &&
          !list.any((p) => p.id == pane.playlist.id)) {
        _show(const _ViewPane(LibraryView.all));
      }
    });

    return Scaffold(
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 288,
                  child: Material(
                    color: scheme.surfaceContainerLow,
                    child: _Sidebar(
                      pane: _pane,
                      searchController: _searchController,
                      onPane: (p) => p is _ViewPane ? showView(p.view) : _show(p),
                    ),
                  ),
                ),
                Expanded(
                  child: SongDragScope(
                    child: AnimatedSwitcher(
                      duration: Motion.short.duration,
                      child: _content(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends ConsumerWidget {
  final _Pane pane;
  final TextEditingController searchController;
  final ValueChanged<_Pane> onPane;
  const _Sidebar(
      {required this.pane,
      required this.searchController,
      required this.onPane});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final liked = ref.watch(likedSongsProvider).valueOrNull?.length;
    final downloaded = ref.watch(downloadedSongIdsProvider).length;
    final albums = ref.watch(allAlbumsProvider).valueOrNull?.length;
    final artists = ref.watch(allArtistsProvider).valueOrNull?.length;
    final songs = ref.watch(allSongsProvider).valueOrNull?.length;
    final playlistsAsync = ref.watch(playlistsProvider);
    final sortName =
        ref.watch(preferencesNotifierProvider.select((p) => p.libraryPlaylistSort));
    final sort = PlaylistSort.values.firstWhere((s) => s.name == sortName,
        orElse: () => PlaylistSort.updated);

    Widget nav(_Pane target, IconData icon, String label, int? count) {
      final key = Key('library-nav-${switch (target) {
        _ViewPane(:final view) => view.name,
        _LikedPane() => 'liked',
        _DownloadedPane() => 'downloaded',
        _RecentPane() => 'recent',
        _PlaylistPane() => 'playlist',
      }}');
      final selected = target.runtimeType == pane.runtimeType &&
          (target is! _ViewPane || target == pane);
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
        child: Material(
          color: selected ? scheme.secondaryContainer : Colors.transparent,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: key,
            onTap: () => onPane(target),
            child: SizedBox(
              height: 44,
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  Icon(icon,
                      size: 20,
                      color: selected
                          ? scheme.onSecondaryContainer
                          : scheme.onSurfaceVariant),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(label,
                        style: text.labelLarge?.copyWith(
                            color: selected
                                ? scheme.onSecondaryContainer
                                : scheme.onSurface)),
                  ),
                  if (count != null)
                    Text('$count',
                        style: text.labelMedium
                            ?.copyWith(color: scheme.onSurfaceVariant)),
                  const SizedBox(width: 16),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text('Library', style: AppTheme.pageTitleStyle(context)),
                ),
                IconButton.filledTonal(
                  key: const Key('library-new-playlist'),
                  tooltip: 'New playlist',
                  icon: const Icon(Icons.add_rounded),
                  onPressed: () async {
                    final p = await createPlaylistFlow(context, ref);
                    if (p != null) onPane(_PlaylistPane(p));
                  },
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: SearchBar(
              key: const Key('library-search-field'),
              controller: searchController,
              hintText: 'Search your library',
              leading: const Icon(Icons.search_rounded),
              elevation: const WidgetStatePropertyAll(0),
              constraints: const BoxConstraints(minHeight: 44),
              onTap: () {
                // Searching a collection page isn't supported; jump to the
                // overview, which searches everything.
                if (pane is! _ViewPane) {
                  onPane(const _ViewPane(LibraryView.all));
                }
              },
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Column(
            children: [
              nav(const _ViewPane(LibraryView.all), Icons.dashboard_rounded,
                  'Overview', null),
              nav(const _LikedPane(), Icons.favorite_rounded, 'Liked songs',
                  liked),
              nav(const _DownloadedPane(), Icons.download_done_rounded,
                  'Downloaded', downloaded),
              nav(const _RecentPane(), Icons.history_rounded,
                  'Recently added', null),
              nav(const _ViewPane(LibraryView.albums), Icons.album_rounded,
                  'Albums', albums),
              nav(const _ViewPane(LibraryView.artists), Icons.person_rounded,
                  'Artists', artists),
              nav(const _ViewPane(LibraryView.songs), Icons.music_note_rounded,
                  'Songs', songs),
            ],
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 16, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    key: const Key('library-nav-playlists'),
                    onTap: () => onPane(const _ViewPane(LibraryView.playlists)),
                    child: Text('Playlists',
                        style: text.labelLarge?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
                PopupMenuButton<PlaylistSort>(
                  tooltip: 'Sort playlists',
                  icon: Icon(Icons.sort_rounded,
                      size: 20, color: scheme.onSurfaceVariant),
                  initialValue: sort,
                  onSelected: (s) {
                    final prefs = ref.read(preferencesNotifierProvider);
                    ref
                        .read(preferencesNotifierProvider.notifier)
                        .update(prefs.copyWith(libraryPlaylistSort: s.name));
                  },
                  itemBuilder: (_) => [
                    for (final s in PlaylistSort.values)
                      PopupMenuItem(value: s, child: Text(playlistSortLabel(s))),
                  ],
                ),
              ],
            ),
          ),
        ),
        ...playlistsAsync.when(
          skipLoadingOnReload: true,
          loading: () => const [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          ],
          error: (e, _) => [
            SliverToBoxAdapter(
              child: ListTile(
                leading: Icon(Icons.error_outline_rounded, color: scheme.error),
                title: const Text("Couldn't load playlists"),
                subtitle: Text(describeError(e)),
                onTap: () => ref.invalidate(playlistsProvider),
              ),
            ),
          ],
          data: (all) {
            final list = sortPlaylists(all, sort);
            if (list.isEmpty) {
              return [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(28, 4, 16, 8),
                    child: Text('No playlists yet',
                        style: text.bodyMedium
                            ?.copyWith(color: scheme.onSurfaceVariant)),
                  ),
                ),
              ];
            }
            return [
              SliverList.builder(
                itemCount: list.length,
                itemBuilder: (_, i) => _SidebarPlaylist(
                  playlist: list[i],
                  selected:
                      pane is _PlaylistPane &&
                          (pane as _PlaylistPane).playlist.id == list[i].id,
                  onTap: () => onPane(_PlaylistPane(list[i])),
                ),
              ),
            ];
          },
        ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
      ],
    );
  }
}

/// A playlist in the sidebar. Songs dragged from the content pane can be
/// dropped on it to add them.
class _SidebarPlaylist extends ConsumerWidget {
  final Playlist playlist;
  final bool selected;
  final VoidCallback onTap;
  const _SidebarPlaylist(
      {required this.playlist, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final user = ref.watch(currentUsernameProvider);
    final editable = playlist.isEditableBy(user);

    return DragTarget<SongDragData>(
      onWillAcceptWithDetails: (_) => editable,
      onAcceptWithDetails: (d) =>
          addSongsToPlaylistFlow(context, ref, playlist, d.data.songs),
      builder: (context, candidates, _) {
        final hovering = candidates.isNotEmpty;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
          child: Material(
            color: selected
                ? scheme.surfaceContainerHighest
                : hovering
                    ? scheme.primaryContainer
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: ValueKey('sidebar-playlist-${playlist.id}'),
              onTap: onTap,
              onSecondaryTap: () => showPlaylistMenu(context, ref, playlist),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Row(
                  children: [
                    PlaylistCover(playlist: playlist, size: 40),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(playlist.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w500)),
                          Text(
                            hovering
                                ? 'Drop to add'
                                : !editable
                                    ? (playlist.readonly
                                        ? 'Smart playlist'
                                        : 'By ${playlist.owner}')
                                    : songCount(playlist.songCount),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    if (!editable)
                      Icon(Icons.lock_outline_rounded,
                          size: 16, color: scheme.onSurfaceVariant),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
