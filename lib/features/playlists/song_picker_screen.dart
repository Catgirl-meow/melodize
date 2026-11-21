import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/song.dart';
import '../../core/providers.dart';
import '../../core/utils/title_normalize.dart';
import '../../shared/utils/formatting.dart';
import '../../shared/widgets/cover_art_image.dart';
import '../../shared/widgets/error_notice.dart';

/// Pick songs from the library to add to a playlist. Pops with the picked
/// songs in the order they were ticked, or null.
class SongPickerScreen extends ConsumerStatefulWidget {
  final String playlistName;

  /// Songs already in the playlist, marked so they aren't added twice by
  /// accident (they can still be picked).
  final Set<String> existingIds;

  const SongPickerScreen({
    super.key,
    required this.playlistName,
    this.existingIds = const {},
  });

  @override
  ConsumerState<SongPickerScreen> createState() => _SongPickerScreenState();
}

class _SongPickerScreenState extends ConsumerState<SongPickerScreen> {
  final _picked = <String, Song>{};
  var _query = '';

  List<Song> _filter(List<Song> songs) {
    final terms = foldForSearch(_query)
        .split(' ')
        .where((t) => t.isNotEmpty)
        .toList();
    final list = terms.isEmpty
        ? List<Song>.of(songs)
        : [
            for (final s in songs)
              if (terms.every(
                  foldForSearch('${s.title} ${s.artist} ${s.album}').contains))
                s
          ];
    list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return list;
  }

  void _toggle(Song s) => setState(() {
        if (_picked.remove(s.id) == null) _picked[s.id] = s;
      });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final async = ref.watch(allSongsProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add songs'),
            Text(widget.playlistName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant)),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              key: const Key('song-picker-add'),
              onPressed: _picked.isEmpty
                  ? null
                  : () => Navigator.pop(context, _picked.values.toList()),
              child: Text(
                  _picked.isEmpty ? 'Add' : 'Add ${_picked.length}'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SearchBar(
              key: const Key('song-picker-search'),
              autoFocus: false,
              hintText: 'Search your library',
              leading: const Icon(Icons.search_rounded),
              elevation: const WidgetStatePropertyAll(0),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: async.when(
              skipLoadingOnReload: true,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorNotice(
                title: "Couldn't load your library",
                error: e,
                onRetry: () => ref.invalidate(allSongsProvider),
              ),
              data: (all) {
                final songs = _filter(all);
                if (songs.isEmpty) {
                  return Center(
                    child: Text(_query.trim().isEmpty
                        ? 'Your library is empty'
                        : 'No songs match "${_query.trim()}"'),
                  );
                }
                return ListView.builder(
                  padding: EdgeInsets.only(
                      bottom: MediaQuery.paddingOf(context).bottom + 16),
                  itemCount: songs.length,
                  itemBuilder: (_, i) {
                    final s = songs[i];
                    final picked = _picked.containsKey(s.id);
                    final inPlaylist = widget.existingIds.contains(s.id);
                    return ListTile(
                      leading: CoverArtImage(
                          coverArtId: s.coverArt,
                          localPath: s.localPath,
                          songId: s.id,
                          size: 48),
                      title: Text(s.title,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        inPlaylist
                            ? '${s.artist} · already in playlist'
                            : '${s.artist} · ${s.album}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                      trailing: Checkbox(
                          value: picked, onChanged: (_) => _toggle(s)),
                      onTap: () => _toggle(s),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: _picked.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(
                  '${songCount(_picked.length)} picked · '
                  '${totalRuntime(_picked.values)}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
            ),
    );
  }
}
