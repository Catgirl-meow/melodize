import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/album.dart';
import '../../core/models/song.dart';
import '../../core/providers.dart';
import 'snack.dart';

/// Queues a local-storage download for [song].
Future<void> startLocalDownload(WidgetRef ref, Song song) =>
    ref.read(downloadNotifierProvider.notifier).download(song);

/// Queues [songs] for download and tells the user how many were queued.
Future<void> downloadSongs(
    BuildContext context, WidgetRef ref, List<Song> songs) async {
  if (songs.isEmpty) return;
  final queued =
      await ref.read(downloadNotifierProvider.notifier).downloadBatch(songs);
  if (!context.mounted) return;
  if (queued == 0) {
    showStyledSnack(context, 'Already downloaded');
  } else if (queued < songs.length) {
    showStyledSnack(context,
        'Downloading $queued songs (${songs.length - queued} already saved)');
  } else {
    showStyledSnack(
        context, 'Downloading $queued song${queued == 1 ? '' : 's'}');
  }
}

/// Batch-downloads all songs in [album] to local storage.
Future<void> downloadAlbum(
    BuildContext context, WidgetRef ref, Album album) async {
  try {
    final songs = await ref.read(albumSongsProvider(album.id).future);
    if (!context.mounted) return;
    await downloadSongs(context, ref, songs);
  } catch (e) {
    if (context.mounted) {
      showStyledSnack(context, 'Failed to start download: $e', isError: true);
    }
  }
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
