import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/platform_dirs.dart';
import '../../core/models/song.dart';
import '../../core/providers.dart';
import '../utils/snack.dart';
import 'cover_art_image.dart';

class SongTile extends ConsumerWidget {
  final Song song;
  final VoidCallback? onTap;
  final bool showAlbum;
  final Widget? trailing;

  const SongTile({
    super.key,
    required this.song,
    this.onTap,
    this.showAlbum = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    // select: this tile only rebuilds when ITS OWN playing state flips
    final isPlaying = ref.watch(
      currentSongStreamProvider.select((s) => s.valueOrNull?.id == song.id),
    );
    // select: only rebuilds when this song's download status changes
    final isDownloaded = ref.watch(
          downloadedSongIdsProvider.select((ids) => ids.contains(song.id)),
        ) ||
        song.isDownloaded;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: CoverArtImage(coverArtId: song.coverArt, size: 48),
      title: Text(
        song.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
          color: isPlaying ? scheme.primary : null,
        ),
      ),
      subtitle: Text(
        showAlbum ? '${song.artist} · ${song.album}' : song.artist,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
      ),
      trailing: trailing ??
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (song.suffix != null)
                _QualityBadge(label: song.suffix!.toUpperCase()),
              if (isDownloaded)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(Icons.download_done_rounded,
                      size: 16, color: scheme.primary),
                ),
              _MoreButton(song: song, isDownloaded: isDownloaded),
            ],
          ),
      onTap: onTap,
    );
  }
}

class _QualityBadge extends StatelessWidget {
  final String label;
  const _QualityBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: scheme.onSecondaryContainer,
        ),
      ),
    );
  }
}

class _MoreButton extends ConsumerWidget {
  final Song song;
  final bool isDownloaded;
  const _MoreButton({required this.song, required this.isDownloaded});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: const Icon(Icons.more_vert_rounded, size: 20),
      onPressed: () => _showOptions(context, ref),
      visualDensity: VisualDensity.compact,
    );
  }

  void _showOptions(BuildContext context, WidgetRef ref) {
    final handler = ref.read(audioHandlerNotifierProvider);
    final canDelete = ref.read(canDeleteFromServerProvider);
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.queue_music_rounded),
              title: const Text('Play next'),
              onTap: () {
                handler?.playNext(song);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_rounded),
              title: const Text('Add to queue'),
              onTap: () {
                handler?.addToQueue(song);
                Navigator.pop(context);
              },
            ),
            if (isDownloaded)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded),
                title: const Text('Remove download'),
                onTap: () {
                  ref
                      .read(downloadNotifierProvider.notifier)
                      .removeDownload(song.id);
                  Navigator.pop(context);
                },
              ),
            if (!isDownloaded)
              ListTile(
                leading: const Icon(Icons.download_rounded),
                title: const Text('Download'),
                onTap: () {
                  _startDownload(context, ref);
                  Navigator.pop(context);
                },
              ),
            if (canDelete)
              ListTile(
                leading: Icon(Icons.delete_forever_rounded,
                    color: scheme.error),
                title: Text('Delete from server',
                    style: TextStyle(color: scheme.error)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmAndDelete(context, ref);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _confirmAndDelete(BuildContext context, WidgetRef ref) {
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

  Future<void> _startDownload(BuildContext context, WidgetRef ref) async {
    final dir = await getAppStorageDirectory();
    final prefs = ref.read(preferencesNotifierProvider);
    final path =
        '${dir.path}/melodize_downloads/${song.id}.${song.suffix ?? 'mp3'}';
    ref
        .read(downloadNotifierProvider.notifier)
        .download(song, path, quality: prefs.downloadQuality);
  }
}

