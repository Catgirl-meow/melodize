import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/artist.dart';
import '../../../core/models/song.dart';
import '../../../core/providers.dart';
import '../../../shared/utils/snack.dart';
import '../../../shared/utils/song_actions.dart';
import '../../../shared/widgets/error_notice.dart';
import '../../../shared/widgets/song_tile.dart';
import '../../playlists/add_to_playlist_sheet.dart';

enum ArtistSongsOrder { mostPlayed, byAlbum, title, newest, downloaded }

extension on ArtistSongsOrder {
  String get label => switch (this) {
        ArtistSongsOrder.mostPlayed => 'Most played',
        ArtistSongsOrder.byAlbum => 'By album',
        ArtistSongsOrder.title => 'A–Z',
        ArtistSongsOrder.newest => 'Newest',
        ArtistSongsOrder.downloaded => 'Downloaded',
      };
}

/// [songs] searched by [query] (title or album) and put in [order].
/// [plays] holds local play counts for songs the server reports none for;
/// [downloaded] the ids saved on this device.
List<Song> arrangeArtistSongs(
  List<Song> songs, {
  String query = '',
  ArtistSongsOrder order = ArtistSongsOrder.byAlbum,
  Map<String, int> plays = const {},
  Set<String> downloaded = const {},
}) {
  final q = query.trim().toLowerCase();
  var list = [
    for (final s in songs)
      if (q.isEmpty ||
          s.title.toLowerCase().contains(q) ||
          s.album.toLowerCase().contains(q))
        s,
  ];
  int playsOf(Song s) => s.playCount ?? plays[s.id] ?? 0;
  switch (order) {
    case ArtistSongsOrder.byAlbum:
      break; // The server's order: album by album, track by track.
    case ArtistSongsOrder.mostPlayed:
      list = [...list]..sort((a, b) => playsOf(b).compareTo(playsOf(a)));
    case ArtistSongsOrder.title:
      list = [...list]..sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    case ArtistSongsOrder.newest:
      list = [...list]..sort((a, b) {
          final y = (b.year ?? 0).compareTo(a.year ?? 0);
          if (y != 0) return y;
          final bc = b.created, ac = a.created;
          if (ac == null || bc == null) return 0;
          return bc.compareTo(ac);
        });
    case ArtistSongsOrder.downloaded:
      list = [
        for (final s in list)
          if (s.isDownloaded || downloaded.contains(s.id)) s,
      ];
  }
  return list;
}

/// Every song by an artist: search, sort, multi-select and shuffle.
class ArtistSongsScreen extends ConsumerStatefulWidget {
  final Artist artist;
  const ArtistSongsScreen({super.key, required this.artist});

  @override
  ConsumerState<ArtistSongsScreen> createState() => _ArtistSongsScreenState();
}

class _ArtistSongsScreenState extends ConsumerState<ArtistSongsScreen> {
  var _query = '';
  var _order = ArtistSongsOrder.byAlbum;
  final _selected = <String>{};

  bool get _selecting => _selected.isNotEmpty;

  void _toggle(Song s) => setState(() {
        if (!_selected.remove(s.id)) _selected.add(s.id);
      });

  @override
  Widget build(BuildContext context) {
    final artist = widget.artist;
    final async = ref.watch(artistAllSongsProvider(artist.id));
    final history = ref.watch(playRecordsProvider).valueOrNull ?? const [];
    final downloaded = ref.watch(downloadedSongIdsProvider);
    final plays = <String, int>{};
    for (final h in history) {
      plays[h.songId] = (plays[h.songId] ?? 0) + 1;
    }
    final all = async.valueOrNull ?? const <Song>[];
    final songs = arrangeArtistSongs(all,
        query: _query, order: _order, plays: plays, downloaded: downloaded);
    final selectedSongs = [
      for (final s in all)
        if (_selected.contains(s.id)) s,
    ];
    final scheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(_selected.clear);
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: _selecting ? scheme.secondaryContainer : null,
          leading: _selecting
              ? IconButton(
                  tooltip: 'Cancel selection',
                  onPressed: () => setState(_selected.clear),
                  icon: const Icon(Icons.close_rounded),
                )
              : null,
          title: _selecting
              ? Text('${_selected.length} selected')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('All songs',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    Text(
                      '${artist.name}${all.isEmpty ? '' : ' · ${all.length} songs'}',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
          actions: _selecting
              ? [
                  IconButton(
                    tooltip: 'Add to playlist',
                    onPressed: () async {
                      await showAddToPlaylistSheet(
                          context, ref, selectedSongs);
                      if (mounted) setState(_selected.clear);
                    },
                    icon: const Icon(Icons.playlist_add_rounded),
                  ),
                  IconButton(
                    tooltip: 'Add to queue',
                    onPressed: () async {
                      final handler = ref.read(audioHandlerNotifierProvider);
                      for (final s in selectedSongs) {
                        await handler?.addToQueue(s);
                      }
                      if (!context.mounted) return;
                      showStyledSnack(context,
                          'Added ${selectedSongs.length} to the queue');
                      setState(_selected.clear);
                    },
                    icon: const Icon(Icons.add_to_queue_rounded),
                  ),
                  IconButton(
                    tooltip: 'Download',
                    onPressed: () async {
                      await downloadSongs(context, ref, selectedSongs);
                      if (mounted) setState(_selected.clear);
                    },
                    icon: const Icon(Icons.download_rounded),
                  ),
                  IconButton(
                    tooltip: 'Select all',
                    onPressed: () => setState(
                        () => _selected.addAll(songs.map((s) => s.id))),
                    icon: const Icon(Icons.select_all_rounded),
                  ),
                ]
              : null,
        ),
        floatingActionButton: songs.isEmpty || _selecting
            ? null
            : FloatingActionButton.extended(
                onPressed: () => ref
                    .read(audioHandlerNotifierProvider)
                    ?.loadQueue([...songs]..shuffle()),
                icon: const Icon(Icons.shuffle_rounded),
                label: Text('Shuffle ${songs.length}'),
              ),
        body: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: SearchBar(
                  hintText: 'Search ${artist.name}',
                  leading: const Icon(Icons.search_rounded),
                  elevation: const WidgetStatePropertyAll(0),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    for (final o in ArtistSongsOrder.values) ...[
                      ChoiceChip(
                        label: Text(o.label),
                        selected: _order == o,
                        onSelected: (_) => setState(() => _order = o),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
            ),
            ...async.when(
              loading: () => const [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
              ],
              error: (e, _) => [
                SliverToBoxAdapter(
                  child: ErrorNotice(
                    title: "Couldn't load ${artist.name}'s songs",
                    error: e,
                    onRetry: () =>
                        ref.invalidate(artistAllSongsProvider(artist.id)),
                  ),
                ),
              ],
              data: (_) => [
                if (songs.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Text(_query.isNotEmpty
                            ? 'No songs match "$_query"'
                            : _order == ArtistSongsOrder.downloaded
                                ? 'No downloaded songs by ${artist.name}'
                                : 'No songs'),
                      ),
                    ),
                  ),
                SliverList.builder(
                  itemCount: songs.length,
                  itemBuilder: (_, i) {
                    final s = songs[i];
                    final n = s.playCount ?? plays[s.id] ?? 0;
                    final subtitle = [
                      s.album,
                      if (n > 0) '$n ${n == 1 ? 'play' : 'plays'}',
                    ].join(' · ');
                    return GestureDetector(
                      onLongPress: () => _toggle(s),
                      child: SongTile(
                        song: s,
                        subtitle: subtitle,
                        leading: _selecting
                            ? SizedBox(
                                width: 48,
                                child: Checkbox(
                                  value: _selected.contains(s.id),
                                  onChanged: (_) => _toggle(s),
                                ),
                              )
                            : null,
                        onTap: _selecting
                            ? () => _toggle(s)
                            : () => ref
                                .read(audioHandlerNotifierProvider)
                                ?.loadQueue(songs, startIndex: i),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
          ],
        ),
      ),
    );
  }
}
