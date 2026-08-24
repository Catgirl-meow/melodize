import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/album.dart';
import '../../core/models/artist.dart';
import '../../core/models/recommended_track.dart';
import '../../core/models/search_results.dart';
import '../../core/models/song.dart';
import '../../core/providers.dart';
import '../../shared/widgets/cover_art_image.dart';
import '../../shared/widgets/deezer_track_tile.dart';
import '../../shared/widgets/offline_banner.dart';
import '../../shared/widgets/song_tile.dart';
import '../library/album_detail_screen.dart';
import '../library/artist_detail_screen.dart';

const _kEmphasizedDecelerate = Cubic(0.05, 0.7, 0.1, 1.0);
const _kEmphasizedDuration = Duration(milliseconds: 400);

// Search filters are local UI state: the query remains shared so the tab keeps
// its query when IndexedStack switches screens.
enum _SearchFilter { all, library, songs, albums, artists, deezer }

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounceTimer;
  _SearchFilter _filter = _SearchFilter.all;

  @override
  void initState() {
    super.initState();
    final existing = ref.read(searchQueryProvider);
    if (existing.isNotEmpty) _controller.text = existing;
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _publishQuery({bool saveFocus = false}) {
    _debounceTimer?.cancel();
    final query = _controller.text.trim();
    ref.read(searchQueryProvider.notifier).state = query;
    if (saveFocus) _focusNode.requestFocus();
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    final query = value.trim();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      ref.read(searchQueryProvider.notifier).state = query;
    });
  }

  void _clearSearch() {
    _debounceTimer?.cancel();
    _controller.clear();
    ref.read(searchQueryProvider.notifier).state = '';
    _focusNode.requestFocus();
  }

  void _retry() {
    ref.invalidate(searchResultsProvider);
    ref.invalidate(deezerSearchProvider);
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider);
    final resultsAsync = ref.watch(searchResultsProvider);
    final deezerAsync = ref.watch(deezerSearchProvider);
    final scheme = Theme.of(context).colorScheme;
    final isWide = MediaQuery.sizeOf(context).width >= 700;

    return Scaffold(
      body: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          children: [
            const OfflineBanner(),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: SearchBar(
                  controller: _controller,
                  focusNode: _focusNode,
                  hintText: 'Songs, albums, artists…',
                  leading: const Icon(Icons.search_rounded),
                  trailing: [
                    if (_controller.text.isNotEmpty || query.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        tooltip: 'Clear search',
                        onPressed: _clearSearch,
                      ),
                  ],
                  onChanged: _onSearchChanged,
                  onSubmitted: (_) {
                    _publishQuery();
                    _focusNode.unfocus();
                  },
                ),
              ),
            ),
            if (query.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: _FilterBar(
                  filter: _filter,
                  isWide: isWide,
                  onChanged: (filter) => setState(() => _filter = filter),
                ),
              ),
            Expanded(
              child: query.isEmpty
                  ? const _EmptySearch()
                  : _SearchResults(
                      query: query,
                      filter: _filter,
                      resultsAsync: resultsAsync,
                      deezerAsync: deezerAsync,
                      onRetry: _retry,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final _SearchFilter filter;
  final bool isWide;
  final ValueChanged<_SearchFilter> onChanged;

  const _FilterBar({
    required this.filter,
    required this.isWide,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final labels = <_SearchFilter, String>{
      _SearchFilter.all: 'All',
      _SearchFilter.library: 'Library',
      _SearchFilter.songs: 'Songs',
      _SearchFilter.albums: 'Albums',
      _SearchFilter.artists: 'Artists',
      _SearchFilter.deezer: 'Deezer',
    };
    final segments = <ButtonSegment<_SearchFilter>>[
      for (final entry in labels.entries)
        ButtonSegment<_SearchFilter>(
          value: entry.key,
          label: Text(entry.value),
          icon: Icon(_filterIcon(entry.key)),
        ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SegmentedButton<_SearchFilter>(
          segments: segments,
          selected: {filter},
          onSelectionChanged: (selection) => onChanged(selection.first),
          showSelectedIcon: false,
          style: SegmentedButton.styleFrom(
            visualDensity:
                isWide ? VisualDensity.standard : VisualDensity.compact,
          ),
        ),
      ),
    );
  }
}

IconData _filterIcon(_SearchFilter filter) {
  switch (filter) {
    case _SearchFilter.all:
      return Icons.apps_rounded;
    case _SearchFilter.library:
      return Icons.library_music_rounded;
    case _SearchFilter.songs:
      return Icons.music_note_rounded;
    case _SearchFilter.albums:
      return Icons.album_rounded;
    case _SearchFilter.artists:
      return Icons.person_rounded;
    case _SearchFilter.deezer:
      return Icons.public_rounded;
  }
}

class _SearchResults extends StatelessWidget {
  final String query;
  final _SearchFilter filter;
  final AsyncValue<SearchResults> resultsAsync;
  final AsyncValue<List<RecommendedTrack>> deezerAsync;
  final VoidCallback onRetry;

  const _SearchResults({
    required this.query,
    required this.filter,
    required this.resultsAsync,
    required this.deezerAsync,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return resultsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => _SearchError(query: query, onRetry: onRetry),
      data: (results) {
        final showLibrary = filter != _SearchFilter.deezer;
        final showDeezer =
            filter == _SearchFilter.all || filter == _SearchFilter.deezer;
        final showSongs = showLibrary &&
            (filter == _SearchFilter.all ||
                filter == _SearchFilter.library ||
                filter == _SearchFilter.songs);
        final showArtists = showLibrary &&
            (filter == _SearchFilter.all ||
                filter == _SearchFilter.library ||
                filter == _SearchFilter.artists);
        final showAlbums = showLibrary &&
            (filter == _SearchFilter.all ||
                filter == _SearchFilter.library ||
                filter == _SearchFilter.albums);
        final deezerTracks =
            deezerAsync.valueOrNull ?? const <RecommendedTrack>[];
        final hasVisibleLibrary = (showSongs && results.songs.isNotEmpty) ||
            (showArtists && results.artists.isNotEmpty) ||
            (showAlbums && results.albums.isNotEmpty);
        final deezerLoading = deezerAsync.isLoading;
        final deezerError = deezerAsync.hasError;
        final hasVisibleResult =
            hasVisibleLibrary || (showDeezer && deezerTracks.isNotEmpty);

        if (!hasVisibleResult &&
            (filter == _SearchFilter.deezer || !hasVisibleLibrary) &&
            deezerLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!hasVisibleResult &&
            !deezerLoading &&
            (!showDeezer || !deezerError)) {
          return _NoResults(query: query);
        }
        if (!hasVisibleResult && showDeezer && deezerError) {
          return _SearchError(query: query, onRetry: onRetry);
        }

        final sections = <Widget>[];
        if (showSongs && results.songs.isNotEmpty) {
          sections.add(_AnimatedSection(
            label: 'Songs · ${results.songs.length}',
            child: _SongResults(songs: results.songs),
          ));
        }
        if (showArtists && results.artists.isNotEmpty) {
          sections.add(_AnimatedSection(
            label: 'Artists · ${results.artists.length}',
            child: _ArtistResults(artists: results.artists),
          ));
        }
        if (showAlbums && results.albums.isNotEmpty) {
          sections.add(_AnimatedSection(
            label: 'Albums · ${results.albums.length}',
            child: _AlbumResults(albums: results.albums),
          ));
        }
        if (showDeezer && deezerTracks.isNotEmpty) {
          sections.add(_AnimatedSection(
            label: 'From Deezer · ${deezerTracks.length}',
            child: _DeezerResults(tracks: deezerTracks),
          ));
        }
        if (showDeezer && deezerLoading) {
          sections.add(const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ));
        }
        if (showDeezer && deezerError && hasVisibleLibrary) {
          sections.add(const _PartialError(
            message:
                'Deezer results are unavailable. Library results are still shown.',
          ));
        }

        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.only(bottom: 24),
              children: sections,
            ),
          ),
        );
      },
    );
  }
}

class _SongResults extends StatelessWidget {
  final List<Song> songs;
  const _SongResults({required this.songs});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: songs
          .map((song) => RepaintBoundary(
                key: ValueKey('search-song-${song.id}'),
                child: SongTile(
                  song: song,
                  showAlbum: true,
                  onTap: () async {
                    final handler =
                        ProviderScope.containerOf(context, listen: false)
                            .read(audioHandlerNotifierProvider);
                    if (handler == null) return;
                    FocusScope.of(context).unfocus();
                    final current =
                        ProviderScope.containerOf(context, listen: false)
                            .read(currentSongStreamProvider)
                            .valueOrNull;
                    if (current == null) {
                      await handler.loadQueue([song]);
                    } else {
                      await handler.playNext(song);
                      await handler.skipToNext();
                    }
                  },
                ),
              ))
          .toList(),
    );
  }
}

class _ArtistResults extends StatelessWidget {
  final List<Artist> artists;
  const _ArtistResults({required this.artists});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: artists
          .map((artist) => RepaintBoundary(
                key: ValueKey('search-artist-${artist.id}'),
                child: ListTile(
                  leading: CoverArtImage(
                      coverArtId: artist.coverArt, size: 48, borderRadius: 24),
                  title: Text(artist.name),
                  subtitle: Text(
                    '${artist.albumCount} ${artist.albumCount == 1 ? 'album' : 'albums'}',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => ArtistDetailScreen(artist: artist)),
                  ),
                ),
              ))
          .toList(),
    );
  }
}

class _AlbumResults extends StatelessWidget {
  final List<Album> albums;
  const _AlbumResults({required this.albums});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: albums
          .map((album) => RepaintBoundary(
                key: ValueKey('search-album-${album.id}'),
                child: ListTile(
                  leading: CoverArtImage(coverArtId: album.coverArt, size: 48),
                  title: Text(album.name),
                  subtitle: Text(album.artist,
                      style: TextStyle(color: scheme.onSurfaceVariant)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => AlbumDetailScreen(album: album)),
                  ),
                ),
              ))
          .toList(),
    );
  }
}

class _DeezerResults extends StatelessWidget {
  final List<RecommendedTrack> tracks;
  const _DeezerResults({required this.tracks});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: tracks
          .map((track) => RepaintBoundary(
                key: ValueKey('search-deezer-${track.deezerId}'),
                child: DeezerTrackTile(track: track),
              ))
          .toList(),
    );
  }
}

class _AnimatedSection extends StatelessWidget {
  final String label;
  final Widget child;
  const _AnimatedSection({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final section = _Section(label: label, child: child);
    if (disableAnimations) return section;
    return TweenAnimationBuilder<double>(
      key: ValueKey(label),
      tween: Tween(begin: 0, end: 1),
      duration: _kEmphasizedDuration,
      curve: _kEmphasizedDecelerate,
      builder: (_, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - value)),
          child: child,
        ),
      ),
      child: section,
    );
  }
}

class _Section extends StatelessWidget {
  final String label;
  final Widget child;
  const _Section({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: scheme.onSurface,
                  )),
        ),
        child,
      ],
    );
  }
}

class _NoResults extends StatelessWidget {
  final String query;
  const _NoResults({required this.query});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('No results for "$query"',
          style:
              TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
    );
  }
}

class _PartialError extends StatelessWidget {
  final String message;
  const _PartialError({required this.message});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Text(message, style: TextStyle(color: scheme.onSurfaceVariant)),
    );
  }
}

class _SearchError extends StatelessWidget {
  final String query;
  final VoidCallback onRetry;
  const _SearchError({required this.query, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded,
                size: 48, color: scheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text('Could not search for "$query"',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Check your connection and try again.',
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySearch extends StatelessWidget {
  const _EmptySearch();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_rounded,
                size: 64,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text('Search your library',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
