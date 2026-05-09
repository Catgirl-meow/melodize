import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../shared/widgets/cover_art_image.dart';
import '../../shared/widgets/deezer_track_tile.dart';
import '../../shared/widgets/offline_banner.dart';
import '../../shared/widgets/song_tile.dart';
import '../library/album_detail_screen.dart';
import '../library/artist_detail_screen.dart';

// M3 Expressive motion tokens (mirrors home_screen.dart).
const _kEmphasizedDecelerate = Cubic(0.05, 0.7, 0.1, 1.0);
const _kEmphasizedDuration = Duration(milliseconds: 400);

// Stagger delays for result sections (Songs → Artists → Albums → Deezer).
const _kStagger0 = Duration.zero;
const _kStagger1 = Duration(milliseconds: 60);
const _kStagger2 = Duration(milliseconds: 120);
const _kStagger3 = Duration(milliseconds: 180);

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    // Seed controller from provider state in case the widget tree rebuilt
    // while a query was active.
    final existing = ref.read(searchQueryProvider);
    if (existing.isNotEmpty) _controller.text = existing;
  }

  @override
  void dispose() {
    _controller.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      ref.read(searchQueryProvider.notifier).state = v;
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider);
    final resultsAsync = ref.watch(searchResultsProvider);
    final deezerAsync = ref.watch(deezerSearchProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const OfflineBanner(),
            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: SearchBar(
                controller: _controller,
                hintText: 'Songs, albums, artists…',
                leading: const Icon(Icons.search_rounded),
                trailing: [
                  if (query.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () => _controller.clear(),
                    ),
                ],
                onChanged: _onSearchChanged,
              ),
            ),
            // Results
            Expanded(
              child: query.isEmpty
                  ? _EmptySearch()
                  : resultsAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text('$e')),
                      data: (results) {
                        final hasLibrary = results.songs.isNotEmpty ||
                            results.artists.isNotEmpty ||
                            results.albums.isNotEmpty;
                        final deezerTracks =
                            deezerAsync.valueOrNull ?? const [];
                        final deezerLoading = deezerAsync.isLoading;

                        if (!hasLibrary && !deezerLoading && deezerTracks.isEmpty) {
                          return Center(
                            child: Text('No results for "$query"',
                                style: TextStyle(
                                    color: scheme.onSurfaceVariant)),
                          );
                        }

                        // Show spinner while waiting for first results
                        if (!hasLibrary && deezerLoading) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        return ListView(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding:
                              const EdgeInsets.only(bottom: 96),
                          children: [
                            if (results.songs.isNotEmpty)
                              _fadeIn(
                                delay: _kStagger0,
                                child: _Section(
                                  label: 'Songs',
                                  children: results.songs.map((s) =>
                                    RepaintBoundary(
                                      key: ValueKey('search-song-${s.id}'),
                                      child: SongTile(
                                        song: s,
                                        showAlbum: true,
                                        onTap: () async {
                                          final handler = ref.read(
                                              audioHandlerNotifierProvider);
                                          if (handler == null) return;
                                          FocusScope.of(context).unfocus();
                                          // If nothing playing, load fresh.
                                          final currentSong = ref
                                              .read(currentSongStreamProvider)
                                              .valueOrNull;
                                          if (currentSong == null) {
                                            await handler.loadQueue([s]);
                                          } else {
                                            await handler.playNext(s);
                                            await handler.skipToNext();
                                          }
                                        },
                                      ),
                                    ),
                                  ).toList(),
                                ),
                              ),
                            if (results.artists.isNotEmpty)
                              _fadeIn(
                                delay: _kStagger1,
                                child: _Section(
                                  label: 'Artists',
                                  children: results.artists.map((a) =>
                                    RepaintBoundary(
                                      key: ValueKey('search-artist-${a.id}'),
                                      child: ListTile(
                                        leading: CoverArtImage(
                                            coverArtId: a.coverArt,
                                            size: 48,
                                            borderRadius: 24),
                                        title: Text(a.name),
                                        subtitle: Text(
                                            '${a.albumCount} ${a.albumCount == 1 ? 'album' : 'albums'}',
                                            style: TextStyle(
                                                color: scheme.onSurfaceVariant)),
                                        trailing: const Icon(
                                            Icons.chevron_right_rounded),
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                ArtistDetailScreen(artist: a),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ).toList(),
                                ),
                              ),
                            if (results.albums.isNotEmpty)
                              _fadeIn(
                                delay: _kStagger2,
                                child: _Section(
                                  label: 'Albums',
                                  children: results.albums.map((a) =>
                                    RepaintBoundary(
                                      key: ValueKey('search-album-${a.id}'),
                                      child: ListTile(
                                        leading: CoverArtImage(
                                            coverArtId: a.coverArt,
                                            size: 48),
                                        title: Text(a.name),
                                        subtitle: Text(a.artist,
                                            style: TextStyle(
                                                color:
                                                    scheme.onSurfaceVariant)),
                                        trailing: const Icon(
                                            Icons.chevron_right_rounded),
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                AlbumDetailScreen(album: a),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ).toList(),
                                ),
                              ),
                            // From Deezer
                            if (deezerTracks.isNotEmpty)
                              _fadeIn(
                                delay: _kStagger3,
                                child: _Section(
                                  label: 'From Deezer',
                                  children: deezerTracks.map((t) =>
                                    RepaintBoundary(
                                      key: ValueKey(
                                          'search-deezer-${t.deezerId}'),
                                      child: DeezerTrackTile(track: t),
                                    ),
                                  ).toList(),
                                ),
                              ),
                            if (deezerTracks.isEmpty && deezerLoading)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Center(
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2)),
                              ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

/// Fade + upward slide entrance animation. Mirrors home_screen._fadeIn.
Widget _fadeIn({required Widget child, Duration delay = Duration.zero}) {
  return TweenAnimationBuilder<double>(
    tween: Tween(begin: 0.0, end: 1.0),
    duration: _kEmphasizedDuration + delay,
    curve: Interval(
      delay.inMilliseconds / (_kEmphasizedDuration + delay).inMilliseconds,
      1.0,
      curve: _kEmphasizedDecelerate,
    ),
    builder: (_, value, ch) => Opacity(
      opacity: value,
      child: Transform.translate(
        offset: Offset(0, 16 * (1 - value)),
        child: ch,
      ),
    ),
    child: child,
  );
}

/// A labeled section in the results list.
class _Section extends StatelessWidget {
  final String label;
  final List<Widget> children;
  const _Section({required this.label, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  )),
        ),
        ...children,
      ],
    );
  }
}

class _EmptySearch extends StatelessWidget {
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
                  color:
                      Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
        ),
      ),
    );
  }
}
