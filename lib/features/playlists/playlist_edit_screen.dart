import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_errors.dart';
import '../../core/models/playlist.dart';
import '../../core/models/song.dart';
import '../../core/playlists/playlist_edits.dart';
import '../../core/providers.dart';
import '../../shared/utils/snack.dart';
import '../../shared/widgets/cover_art_image.dart';
import 'song_picker_screen.dart';

/// Rename, describe, remove and reorder in one place. Nothing reaches the
/// server until Done, which sends the fewest requests that produce the
/// edited playlist ([PlaylistActions.saveEdits]).
class PlaylistEditScreen extends ConsumerStatefulWidget {
  final Playlist playlist;
  final List<Song> songs;

  const PlaylistEditScreen(
      {super.key, required this.playlist, required this.songs});

  @override
  ConsumerState<PlaylistEditScreen> createState() =>
      _PlaylistEditScreenState();
}

class _Entry {
  final Song song;
  final int key; // stable across reorders, unique even for duplicates
  const _Entry(this.song, this.key);
}

class _PlaylistEditScreenState extends ConsumerState<PlaylistEditScreen> {
  late final _name = TextEditingController(text: widget.playlist.name);
  late final _comment =
      TextEditingController(text: widget.playlist.comment ?? '');
  final _formKey = GlobalKey<FormState>();
  late List<_Entry> _entries = [
    for (var i = 0; i < widget.songs.length; i++) _Entry(widget.songs[i], i)
  ];
  late var _nextKey = widget.songs.length;
  var _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _comment.dispose();
    super.dispose();
  }

  List<String> get _originalIds => [for (final s in widget.songs) s.id];
  List<String> get _editedIds => [for (final e in _entries) e.song.id];

  bool get _dirty =>
      _name.text.trim() != widget.playlist.name ||
      _comment.text.trim() != (widget.playlist.comment ?? '') ||
      planSongChange(_originalIds, _editedIds) is! NoSongChange;

  void _remove(int index) {
    final removed = _entries[index];
    setState(() => _entries = [..._entries]..removeAt(index));
    showStyledSnack(context, 'Removed "${removed.song.title}"',
        actionLabel: 'Undo', onAction: () {
      if (!mounted) return;
      setState(() {
        final at = index.clamp(0, _entries.length);
        _entries = [..._entries]..insert(at, removed);
      });
    });
  }

  Future<void> _addSongs() async {
    final picked = await Navigator.of(context).push<List<Song>>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => SongPickerScreen(
          playlistName: _name.text.trim().isEmpty
              ? widget.playlist.name
              : _name.text.trim(),
          existingIds: _editedIds.toSet(),
        ),
      ),
    );
    if (picked == null || picked.isEmpty || !mounted) return;
    setState(() {
      _entries = [
        ..._entries,
        for (final s in picked) _Entry(s, _nextKey++),
      ];
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_dirty) {
      Navigator.pop(context);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(playlistActionsProvider).saveEdits(
            widget.playlist,
            name: _name.text,
            comment: _comment.text,
            originalSongIds: _originalIds,
            editedSongIds: _editedIds,
          );
      if (!mounted) return;
      Navigator.pop(context);
      showStyledSnack(context, 'Saved "${_name.text.trim()}"');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      // The server may hold part of the edit; the playlist page reloads it.
      showStyledSnack(context, "Couldn't save: ${describeError(e)}",
          isError: true);
    }
  }

  Future<bool> _confirmDiscard() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('Your edits to this playlist will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return PopScope(
      canPop: !_dirty && !_saving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _saving) return;
        if (await _confirmDiscard() && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.maybePop(context),
          ),
          title: const Text('Edit playlist'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton(
                key: const Key('playlist-edit-done'),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: scheme.onPrimary))
                    : const Text('Done'),
              ),
            ),
          ],
        ),
        body: Form(
          key: _formKey,
          onChanged: () => setState(() {}),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Column(
                    children: [
                      TextFormField(
                        key: const Key('playlist-edit-name'),
                        controller: _name,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Name',
                          border: OutlineInputBorder(),
                        ),
                        validator: validatePlaylistName,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        key: const Key('playlist-edit-description'),
                        controller: _comment,
                        minLines: 1,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: ListTile(
                  key: const Key('playlist-edit-add-songs'),
                  contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.add_rounded,
                        color: scheme.onPrimaryContainer),
                  ),
                  title: Text('Add songs',
                      style: TextStyle(
                          color: scheme.primary, fontWeight: FontWeight.w600)),
                  onTap: _saving ? null : _addSongs,
                ),
              ),
              if (_entries.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text('No songs in this playlist',
                        textAlign: TextAlign.center,
                        style: text.bodyMedium
                            ?.copyWith(color: scheme.onSurfaceVariant)),
                  ),
                ),
              SliverReorderableList(
                itemCount: _entries.length,
                // newIndex is already the final position (item removed).
                onReorderItem: (oldIndex, newIndex) => setState(() {
                  final list = [..._entries];
                  list.insert(newIndex, list.removeAt(oldIndex));
                  _entries = list;
                }),
                proxyDecorator: (child, _, animation) => AnimatedBuilder(
                  animation: animation,
                  builder: (_, child) => Material(
                    elevation: 6 * animation.value,
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    child: child,
                  ),
                  child: child,
                ),
                itemBuilder: (context, i) {
                  final e = _entries[i];
                  return ReorderableDelayedDragStartListener(
                    key: ValueKey(e.key),
                    index: i,
                    child: ListTile(
                      contentPadding: const EdgeInsets.only(left: 4, right: 4),
                      leading: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Remove',
                            icon: Icon(Icons.remove_circle_outline_rounded,
                                color: scheme.error),
                            onPressed: _saving ? null : () => _remove(i),
                          ),
                          CoverArtImage(
                              coverArtId: e.song.coverArt,
                              localPath: e.song.localPath,
                              songId: e.song.id,
                              size: 44),
                        ],
                      ),
                      title: Text(e.song.title,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(e.song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: scheme.onSurfaceVariant)),
                      trailing: ReorderableDragStartListener(
                        index: i,
                        child: const Padding(
                          padding: EdgeInsets.all(12),
                          child: Icon(Icons.drag_handle_rounded),
                        ),
                      ),
                    ),
                  );
                },
              ),
              SliverPadding(
                padding: EdgeInsets.only(
                    bottom: MediaQuery.paddingOf(context).bottom + 24),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
