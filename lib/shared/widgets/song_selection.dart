import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/song.dart';
import '../../core/providers.dart';
import '../../features/playlists/add_to_playlist_sheet.dart';
import '../utils/snack.dart';
import '../utils/song_actions.dart';

/// The ids of the songs picked in a list, in the order they were picked.
/// Long-press a song to start; the list shows [SongSelectionAppBar] while
/// [active].
class SongSelection extends ChangeNotifier {
  final _ids = <String>{};

  bool get active => _ids.isNotEmpty;
  int get length => _ids.length;
  bool contains(String id) => _ids.contains(id);

  void toggle(String id) {
    if (!_ids.remove(id)) _ids.add(id);
    notifyListeners();
  }

  void addAll(Iterable<String> ids) {
    _ids.addAll(ids);
    notifyListeners();
  }

  void clear() {
    if (_ids.isEmpty) return;
    _ids.clear();
    notifyListeners();
  }

  /// The picked songs out of [from], in [from]'s order.
  List<Song> pick(List<Song> from) =>
      [for (final s in from) if (_ids.contains(s.id)) s];
}

/// Contextual app bar for a list in selection mode: count, Add to playlist,
/// Play next, Add to queue, and an overflow with Download and Select all.
class SongSelectionAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final SongSelection selection;

  /// Every song in the list, for Select all and to resolve the picked ids.
  final List<Song> songs;

  /// Extra actions for this list (e.g. "Remove from playlist").
  final List<PopupMenuEntry<VoidCallback>> extraMenu;

  const SongSelectionAppBar({
    super.key,
    required this.selection,
    required this.songs,
    this.extraMenu = const [],
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final picked = selection.pick(songs);
    final library = [for (final s in picked) if (!s.isExternal) s];
    final handler = ref.read(audioHandlerNotifierProvider);

    return AppBar(
      backgroundColor: scheme.secondaryContainer,
      foregroundColor: scheme.onSecondaryContainer,
      automaticallyImplyLeading: false,
      leading: IconButton(
        tooltip: 'Cancel selection',
        onPressed: selection.clear,
        icon: const Icon(Icons.close_rounded),
      ),
      title: Text('${selection.length} selected'),
      actions: [
        if (library.isNotEmpty)
          IconButton(
            tooltip: 'Add to playlist',
            icon: const Icon(Icons.playlist_add_rounded),
            onPressed: () async {
              await showAddToPlaylistSheet(context, ref, library);
              selection.clear();
            },
          ),
        IconButton(
          tooltip: 'Play next',
          icon: const Icon(Icons.queue_play_next_rounded),
          onPressed: () async {
            // playNext puts each song right after the current one, so feed
            // them last-first to keep the picked order.
            for (final s in picked.reversed) {
              await handler?.playNext(s);
            }
            if (context.mounted) {
              showStyledSnack(context, 'Playing ${_n(picked.length)} next');
            }
            selection.clear();
          },
        ),
        IconButton(
          tooltip: 'Add to queue',
          icon: const Icon(Icons.add_to_queue_rounded),
          onPressed: () async {
            for (final s in picked) {
              await handler?.addToQueue(s);
            }
            if (context.mounted) {
              showStyledSnack(
                  context, 'Added ${_n(picked.length)} to the queue');
            }
            selection.clear();
          },
        ),
        PopupMenuButton<VoidCallback>(
          tooltip: 'More',
          icon: const Icon(Icons.more_vert_rounded),
          onSelected: (action) => action(),
          itemBuilder: (_) => [
            if (library.isNotEmpty)
              PopupMenuItem(
                value: () async {
                  await downloadSongs(context, ref, library);
                  selection.clear();
                },
                child: const ListTile(
                  leading: Icon(Icons.download_rounded),
                  title: Text('Download'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            PopupMenuItem(
              value: () => selection.addAll(songs.map((s) => s.id)),
              child: const ListTile(
                leading: Icon(Icons.select_all_rounded),
                title: Text('Select all'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            ...extraMenu,
          ],
        ),
      ],
    );
  }
}

String _n(int n) => n == 1 ? '1 song' : '$n songs';
