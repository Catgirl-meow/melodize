import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../shared/widgets/cover_art_image.dart';
import '../../shared/widgets/song_tile.dart';
import '../library/album_detail_screen.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider);
    final resultsAsync = ref.watch(searchResultsProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
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
                      onPressed: () {
                        _controller.clear();
                        ref.read(searchQueryProvider.notifier).state = '';
                      },
                    ),
                ],
                onChanged: (v) =>
                    ref.read(searchQueryProvider.notifier).state = v,
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
                        if (results.isEmpty) {
                          return Center(
                            child: Text('No results for "$query"',
                                style: TextStyle(
                                    color: scheme.onSurfaceVariant)),
                          );
                        }
                        return ListView(
                          children: [
                            if (results.artists.isNotEmpty) ...[
                              _SectionLabel('Artists'),
                              ...results.artists.map((a) => ListTile(
                                    leading: CoverArtImage(
                                        coverArtId: a.coverArt,
                                        size: 44,
                                        borderRadius: 22),
                                    title: Text(a.name),
                                    subtitle: Text(
                                        '${a.albumCount} albums',
                                        style: TextStyle(
                                            color:
                                                scheme.onSurfaceVariant)),
                                  )),
                            ],
                            if (results.albums.isNotEmpty) ...[
                              _SectionLabel('Albums'),
                              ...results.albums.map((a) => ListTile(
                                    leading: CoverArtImage(
                                        coverArtId: a.coverArt,
                                        size: 48),
                                    title: Text(a.name),
                                    subtitle: Text(a.artist,
                                        style: TextStyle(
                                            color:
                                                scheme.onSurfaceVariant)),
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            AlbumDetailScreen(album: a),
                                      ),
                                    ),
                                  )),
                            ],
                            if (results.songs.isNotEmpty) ...[
                              _SectionLabel('Songs'),
                              ...results.songs.map((s) => SongTile(
                                    song: s,
                                    showAlbum: true,
                                    onTap: () => ref
                                        .read(audioHandlerNotifierProvider)
                                        ?.loadQueue(results.songs,
                                            startIndex:
                                                results.songs.indexOf(s)),
                                  )),
                            ],
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

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(text,
          style: Theme.of(context)
              .textTheme
              .labelLarge
              ?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold)),
    );
  }
}

class _EmptySearch extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
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
    );
  }
}
