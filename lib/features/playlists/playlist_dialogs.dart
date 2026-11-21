import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_errors.dart';
import '../../core/models/playlist.dart';
import '../../core/models/song.dart';
import '../../core/playlists/playlist_edits.dart';
import '../../core/providers.dart';
import '../../shared/utils/snack.dart';

/// Asks for a playlist name. Returns the trimmed name, or null on Cancel.
Future<String?> showPlaylistNameDialog(
  BuildContext context, {
  required String title,
  String initial = '',
  String confirmLabel = 'Create',
}) {
  return showDialog<String>(
    context: context,
    useRootNavigator: true,
    builder: (_) => _NameDialog(
        title: title, initial: initial, confirmLabel: confirmLabel),
  );
}

class _NameDialog extends StatefulWidget {
  final String title;
  final String initial;
  final String confirmLabel;
  const _NameDialog(
      {required this.title, required this.initial, required this.confirmLabel});

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _controller = TextEditingController(text: widget.initial)
    ..selection =
        TextSelection(baseOffset: 0, extentOffset: widget.initial.length);
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, _controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: TextFormField(
          key: const Key('playlist-name-field'),
          controller: _controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Name',
            border: OutlineInputBorder(),
          ),
          validator: validatePlaylistName,
          onFieldSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }
}

/// Asks for a name and creates a playlist holding [songs]. Shows the result
/// as a snackbar on [context]; returns the playlist, or null when cancelled
/// or failed.
Future<Playlist?> createPlaylistFlow(BuildContext context, WidgetRef ref,
    {List<Song> songs = const []}) async {
  final name = await showPlaylistNameDialog(context, title: 'New playlist');
  if (name == null || !context.mounted) return null;
  try {
    final playlist = await ref
        .read(playlistActionsProvider)
        .create(name, songIds: [for (final s in songs) s.id]);
    if (context.mounted) {
      showStyledSnack(
          context,
          songs.isEmpty
              ? 'Created "${playlist.name}"'
              : 'Added ${_songs(songs.length)} to "${playlist.name}"');
    }
    return playlist;
  } catch (e) {
    if (context.mounted) {
      showStyledSnack(context, "Couldn't create the playlist: ${describeError(e)}",
          isError: true);
    }
    return null;
  }
}

Future<void> renamePlaylistFlow(
    BuildContext context, WidgetRef ref, Playlist playlist) async {
  final name = await showPlaylistNameDialog(context,
      title: 'Rename playlist', initial: playlist.name, confirmLabel: 'Rename');
  if (name == null || name == playlist.name || !context.mounted) return;
  try {
    await ref.read(playlistActionsProvider).updateDetails(playlist, name: name);
    if (context.mounted) showStyledSnack(context, 'Renamed to "$name"');
  } catch (e) {
    if (context.mounted) {
      showStyledSnack(context, "Couldn't rename: ${describeError(e)}",
          isError: true);
    }
  }
}

Future<void> duplicatePlaylistFlow(
    BuildContext context, WidgetRef ref, Playlist playlist) async {
  try {
    final copy = await ref.read(playlistActionsProvider).duplicate(playlist);
    if (context.mounted) showStyledSnack(context, 'Created "${copy.name}"');
  } catch (e) {
    if (context.mounted) {
      showStyledSnack(context, "Couldn't duplicate: ${describeError(e)}",
          isError: true);
    }
  }
}

/// Confirms, then deletes. Returns true when the playlist was deleted.
Future<bool> deletePlaylistFlow(
    BuildContext context, WidgetRef ref, Playlist playlist) async {
  final scheme = Theme.of(context).colorScheme;
  final ok = await showDialog<bool>(
    context: context,
    useRootNavigator: true,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.delete_outline_rounded),
      title: Text('Delete "${playlist.name}"?'),
      content: const Text(
          'The playlist is removed from your server. The songs stay in your '
          'library.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: scheme.error,
            foregroundColor: scheme.onError,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return false;
  try {
    await ref.read(playlistActionsProvider).delete(playlist);
    if (context.mounted) showStyledSnack(context, 'Deleted "${playlist.name}"');
    return true;
  } catch (e) {
    if (context.mounted) {
      showStyledSnack(context, "Couldn't delete: ${describeError(e)}",
          isError: true);
    }
    return false;
  }
}

/// Adds [songs] to [playlist] and reports how it went.
Future<void> addSongsToPlaylistFlow(BuildContext context, WidgetRef ref,
    Playlist playlist, List<Song> songs) async {
  try {
    final r = await ref
        .read(playlistActionsProvider)
        .addSongs(playlist.id, [for (final s in songs) s.id]);
    if (!context.mounted) return;
    showStyledSnack(context, addResultMessage(playlist.name, r));
  } catch (e) {
    if (context.mounted) {
      showStyledSnack(
          context, "Couldn't add to \"${playlist.name}\": ${describeError(e)}",
          isError: true);
    }
  }
}

String addResultMessage(String playlistName, PlaylistAddResult r) {
  if (r.added == 0) {
    return r.skipped == 1
        ? 'Already in "$playlistName"'
        : 'All ${r.skipped} songs are already in "$playlistName"';
  }
  final base = 'Added ${_songs(r.added)} to "$playlistName"';
  if (r.skipped == 0) return base;
  return '$base · ${r.skipped} already there';
}

String _songs(int n) => n == 1 ? '1 song' : '$n songs';

/// The ⋮ actions of a playlist, shared by the Library list and the playlist
/// page. [onDeleted] runs after a successful delete (the page pops itself).
Future<void> showPlaylistMenu(
  BuildContext context,
  WidgetRef ref,
  Playlist playlist, {
  VoidCallback? onEdit,
  VoidCallback? onDeleted,
}) {
  final editable =
      playlist.isEditableBy(ref.read(currentUsernameProvider));
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    builder: (sheetContext) {
      void run(Future<void> Function() action) {
        Navigator.pop(sheetContext);
        action();
      }

      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(playlist.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  if (!editable)
                    Icon(Icons.lock_outline_rounded,
                        size: 18,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                ],
              ),
            ),
            if (editable && onEdit != null)
              ListTile(
                leading: const Icon(Icons.edit_rounded),
                title: const Text('Edit'),
                onTap: () => run(() async => onEdit()),
              ),
            if (editable)
              ListTile(
                leading: const Icon(Icons.drive_file_rename_outline_rounded),
                title: const Text('Rename'),
                onTap: () =>
                    run(() => renamePlaylistFlow(context, ref, playlist)),
              ),
            ListTile(
              leading: const Icon(Icons.copy_all_rounded),
              title: const Text('Duplicate'),
              subtitle: editable
                  ? null
                  : const Text('Make your own copy you can edit'),
              onTap: () =>
                  run(() => duplicatePlaylistFlow(context, ref, playlist)),
            ),
            if (editable)
              ListTile(
                leading: Icon(Icons.delete_outline_rounded,
                    color: Theme.of(context).colorScheme.error),
                title: Text('Delete',
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
                onTap: () => run(() async {
                  if (await deletePlaylistFlow(context, ref, playlist)) {
                    onDeleted?.call();
                  }
                }),
              ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}
