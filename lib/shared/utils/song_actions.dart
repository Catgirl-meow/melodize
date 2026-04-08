import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/song.dart';
import '../../core/providers.dart';
import '../../core/utils/platform_dirs.dart';
import 'snack.dart';

/// Queues a local-storage download for [song].
Future<void> startLocalDownload(WidgetRef ref, Song song) async {
  final dir = await getAppStorageDirectory();
  final prefs = ref.read(preferencesNotifierProvider);
  final path =
      '${dir.path}/melodize_downloads/${song.id}.${song.suffix ?? 'mp3'}';
  ref
      .read(downloadNotifierProvider.notifier)
      .download(song, path, quality: prefs.downloadQuality);
}

/// Shows the "Delete from server?" confirmation dialog.
void confirmAndDeleteSong(BuildContext context, WidgetRef ref, Song song) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Delete from server?'),
      content: Text(
        '"${song.title}" will be permanently deleted from the server. '
        'This cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () async {
            Navigator.pop(context);
            try {
              await deleteSongFromServer(ref, song);
              if (context.mounted) {
                showStyledSnack(context, '"${song.title}" deleted');
              }
            } catch (e) {
              if (context.mounted) {
                showStyledSnack(context, 'Failed to delete: $e', isError: true);
              }
            }
          },
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
}
