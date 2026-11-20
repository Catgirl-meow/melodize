import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_errors.dart';
import '../../core/models/playlist.dart';
import '../../core/models/song.dart';
import '../../core/providers.dart';
import '../../shared/utils/snack.dart';
import '../../shared/widgets/cover_art_image.dart';
import '../../shared/widgets/error_notice.dart';
import '../../shared/widgets/playlist_cover.dart';
import 'playlist_dialogs.dart';

/// "Add to playlist" for one or more songs.
///
/// Playlists that already hold the song(s) start ticked. For a single song,
/// unticking removes it from that playlist; for several, ticks only add.
/// Locked playlists (smart, someone else's) aren't listed. Results are shown
/// on [context] after the sheet closes.
Future<void> showAddToPlaylistSheet(
    BuildContext context, WidgetRef ref, List<Song> songs) async {
  final library = [
    for (final s in songs)
      if (!s.isExternal) s
  ];
  if (library.isEmpty) return;
  if (!(ref.read(isOnlineProvider).valueOrNull ?? true)) {
    showStyledSnack(context, "You're offline. Playlists can be changed when "
        "you're back online.", isError: true);
    return;
  }
  final result = await showModalBottomSheet<_SheetResult>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _AddToPlaylistSheet(songs: library),
  );
  if (result == null || !context.mounted) return;
  if (result.createNew) {
    await createPlaylistFlow(context, ref, songs: library);
    return;
  }
  await _apply(context, ref, library, result);
}

class _SheetResult {
  final bool createNew;
  final List<Playlist> add;
  final List<Playlist> remove;
  const _SheetResult({this.createNew = false, this.add = const [], this.remove = const []});
}

Future<void> _apply(BuildContext context, WidgetRef ref, List<Song> songs,
    _SheetResult r) async {
  final actions = ref.read(playlistActionsProvider);
  final ids = [for (final s in songs) s.id];
  final done = <String>[];
  try {
    for (final p in r.add) {
      final res = await actions.addSongs(p.id, ids);
      if (r.add.length == 1 && r.remove.isEmpty) {
        if (context.mounted) showStyledSnack(context, addResultMessage(p.name, res));
        return;
      }
      done.add('added to "${p.name}"');
    }
    for (final p in r.remove) {
      await actions.removeSong(p.id, ids.single);
      done.add('removed from "${p.name}"');
    }
    if (!context.mounted || done.isEmpty) return;
    final msg = done.join(', ');
    showStyledSnack(context, msg[0].toUpperCase() + msg.substring(1));
  } catch (e) {
    if (!context.mounted) return;
    showStyledSnack(
        context,
        done.isEmpty
            ? "Couldn't update the playlist: ${describeError(e)}"
            : "Only partly saved (${done.join(', ')}): ${describeError(e)}",
        isError: true);
  }
}

class _AddToPlaylistSheet extends ConsumerStatefulWidget {
  final List<Song> songs;
  const _AddToPlaylistSheet({required this.songs});

  @override
  ConsumerState<_AddToPlaylistSheet> createState() => _SheetState();
}

class _SheetState extends ConsumerState<_AddToPlaylistSheet> {
  /// Playlists the user ticked or unticked, with their new state.
  final _changed = <String, bool>{};
  var _query = '';

  bool get _single => widget.songs.length == 1;

  /// true = holds every song, false = holds none, null = some (or loading).
  bool? _membership(Playlist p) {
    final songs = ref.watch(playlistSongsProvider(p.id)).valueOrNull;
    if (songs == null) return false;
    final have = songs.map((s) => s.id).toSet();
    final n = widget.songs.where((s) => have.contains(s.id)).length;
    if (n == 0) return false;
    if (n == widget.songs.length) return true;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final user = ref.watch(currentUsernameProvider);
    final async = ref.watch(playlistsProvider);
    final first = widget.songs.first;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.8;

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          CoverArtImage(
              coverArtId: first.coverArt,
              localPath: first.localPath,
              songId: first.id,
              size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Add to playlist',
                    style: text.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                Text(
                  _single
                      ? '${first.title} · ${first.artist}'
                      : '${widget.songs.length} songs',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final body = async.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => ErrorNotice(
        title: "Couldn't load playlists",
        error: e,
        compact: true,
        onRetry: () => ref.invalidate(playlistsProvider),
      ),
      data: (all) {
        final editable = [
          for (final p in all)
            if (p.isEditableBy(user)) p
        ]..sort((a, b) => b.changed.compareTo(a.changed));
        final q = _query.trim().toLowerCase();
        final shown = q.isEmpty
            ? editable
            : [
                for (final p in editable)
                  if (p.name.toLowerCase().contains(q)) p
              ];
        return ListView(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          children: [
            if (editable.length > 6)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: SearchBar(
                  hintText: 'Find a playlist',
                  leading: const Icon(Icons.search_rounded),
                  elevation: const WidgetStatePropertyAll(0),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
            ListTile(
              key: const Key('add-to-new-playlist'),
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.add_rounded,
                    color: scheme.onPrimaryContainer),
              ),
              title: Text('New playlist',
                  style: TextStyle(
                      color: scheme.primary, fontWeight: FontWeight.w600)),
              onTap: () =>
                  Navigator.pop(context, const _SheetResult(createNew: true)),
            ),
            for (final p in shown) _tile(p),
            if (editable.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Text('You have no playlists yet.',
                    style: text.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant)),
              ),
          ],
        );
      },
    );

    final playlists = async.valueOrNull ?? const <Playlist>[];
    final byId = {for (final p in playlists) p.id: p};
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            header,
            Flexible(child: body),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _changed.isEmpty
                        ? null
                        : () => Navigator.pop(
                              context,
                              _SheetResult(
                                add: [
                                  for (final e in _changed.entries)
                                    if (e.value && byId[e.key] != null)
                                      byId[e.key]!
                                ],
                                remove: [
                                  for (final e in _changed.entries)
                                    if (!e.value && byId[e.key] != null)
                                      byId[e.key]!
                                ],
                              ),
                            ),
                    child: const Text('Save'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(Playlist p) {
    final scheme = Theme.of(context).colorScheme;
    final loading = ref.watch(playlistSongsProvider(p.id)).isLoading;
    final initial = _membership(p);
    final value = _changed[p.id] ?? initial;
    // With several songs a full playlist can't be unticked (ticks only add).
    final locked = !_single && initial == true;
    final subtitle = initial == true
        ? (_single ? 'Already added' : 'All already added')
        : initial == null
            ? 'Some already added'
            : '${p.songCount} ${p.songCount == 1 ? 'song' : 'songs'}';
    void toggle() {
      setState(() {
        final next = !(value ?? false);
        if (next == initial || (initial == null && !next)) {
          _changed.remove(p.id);
        } else {
          _changed[p.id] = next;
        }
      });
    }

    return ListTile(
      leading: PlaylistCover(playlist: p, size: 44),
      title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle,
          style: TextStyle(color: scheme.onSurfaceVariant)),
      enabled: !locked && !loading,
      trailing: loading
          ? const SizedBox.square(
              dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : Checkbox(
              value: value,
              tristate: value == null,
              onChanged: locked ? null : (_) => toggle(),
            ),
      onTap: toggle,
    );
  }
}
