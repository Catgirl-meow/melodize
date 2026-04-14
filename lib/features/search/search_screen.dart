import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/recommended_track.dart';
import '../../core/models/song.dart';
import '../../core/providers.dart';
import '../../shared/utils/download_polling_mixin.dart';
import '../../shared/utils/snack.dart';
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
    final deezerAsync = ref.watch(deezerSearchProvider);
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
                          children: [
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
                            // From Deezer
                            if (deezerTracks.isNotEmpty) ...[
                              _SectionLabel('From Deezer'),
                              ...deezerTracks.map(
                                  (t) => _DeezerTrackTile(track: t)),
                            ],
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

class _DeezerTrackTile extends ConsumerStatefulWidget {
  final RecommendedTrack track;
  const _DeezerTrackTile({required this.track});

  @override
  ConsumerState<_DeezerTrackTile> createState() => _DeezerTrackTileState();
}

class _DeezerTrackTileState extends ConsumerState<_DeezerTrackTile>
    with DownloadPollingMixin {

  void _playPreview() {
    final song = Song.fromRecommendation(
      deezerId: widget.track.deezerId,
      title: widget.track.title,
      artist: widget.track.artist,
      album: widget.track.album,
      durationSeconds: widget.track.durationSeconds,
      previewUrl: widget.track.previewUrl,
      coverUrl: widget.track.coverUrl,
    );
    ref.read(audioHandlerNotifierProvider)?.loadQueue([song]);
  }

  Future<void> _saveToServer() async {
    final companion = ref.read(companionClientProvider);
    if (companion == null) return;
    final prefs = ref.read(preferencesNotifierProvider);
    final url = 'https://www.deezer.com/track/${widget.track.deezerId}';
    try {
      final jobId = await companion.startDownload(
        url,
        deezerArl: prefs.hasDeezerArl ? prefs.deezerArl : null,
      );
      if (!mounted) return;
      showStyledSnack(
        context,
        prefs.hasDeezerArl
            ? 'Downloading FLAC to Navidrome server…'
            : 'Downloading to Navidrome server (add Deezer ARL in Settings for lossless)',
      );
      startDownloadPolling(companion, jobId);
    } catch (e) {
      if (!mounted) return;
      showStyledSnack(context, 'Could not start download: $e', isError: true);
    }
  }


  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final canSave = ref.watch(canDeleteFromServerProvider);

    Widget leading;
    if (widget.track.coverUrl != null) {
      leading = ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: CachedNetworkImage(
          imageUrl: widget.track.coverUrl!,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          placeholder: (_, __) => _placeholder(scheme),
          errorWidget: (_, __, ___) => _placeholder(scheme),
        ),
      );
    } else {
      leading = _placeholder(scheme);
    }

    return ListTile(
      leading: leading,
      title: Text(widget.track.title,
          maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        widget.track.artist,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: scheme.onSurfaceVariant),
      ),
      onTap: _playPreview,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.play_circle_outline_rounded),
            tooltip: 'Play 30s preview',
            onPressed: _playPreview,
          ),
          if (canSave)
            IconButton(
              icon: const Icon(Icons.download_for_offline_rounded),
              tooltip: 'Save to Navidrome server',
              onPressed: () { _saveToServer(); },
            ),
        ],
      ),
    );
  }

  Widget _placeholder(ColorScheme scheme) => ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 48,
          height: 48,
          color: scheme.surfaceContainerHigh,
          child: Icon(Icons.music_note_rounded,
              size: 20, color: scheme.onSurfaceVariant),
        ),
      );
}

// ---------------------------------------------------------------------------

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
