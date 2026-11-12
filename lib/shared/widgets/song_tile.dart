import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/song.dart';
import '../../core/providers.dart';
import '../utils/snack.dart';
import '../utils/song_actions.dart';
import 'cover_art_image.dart';

class SongTile extends ConsumerWidget {
  final Song song;
  final VoidCallback? onTap;
  final bool showAlbum;
  final Widget? trailing;

  /// Replaces the cover thumbnail (album pages show the track number).
  final Widget? leading;

  const SongTile({
    super.key,
    required this.song,
    this.onTap,
    this.showAlbum = false,
    this.trailing,
    this.leading,
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
    // select: rebuilds only when this song enters/leaves the download queue.
    final downloadStatus = ref.watch(
      downloadNotifierProvider.select((m) => m[song.id]?.status),
    );

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: leading ??
          CoverArtImage(
              coverArtId: song.coverArt,
              localPath: song.localPath,
              songId: song.id,
              size: 48),
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
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: scheme.onSurfaceVariant),
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
                )
              else if (downloadStatus == 'queued' ||
                  downloadStatus == 'downloading')
                const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: SizedBox.square(
                    dimension: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else if (downloadStatus == 'error')
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(Icons.error_outline_rounded,
                      size: 16, color: scheme.error),
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
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
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Song header — gives the user visual confirmation of which song
            // the menu is operating on (matches recommendation-card pattern).
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  CoverArtImage(
                    coverArtId: song.coverArt,
                    localPath: song.localPath,
                    size: 44,
                    borderRadius: 8,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          song.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(
                          song.artist,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            const SizedBox(height: 4),
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
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    await ref
                        .read(downloadNotifierProvider.notifier)
                        .removeDownload(song.id);
                  } catch (e) {
                    if (context.mounted) {
                      showStyledSnack(
                          context, 'Could not delete the downloaded file: $e',
                          isError: true);
                    }
                  }
                },
              ),
            if (!isDownloaded &&
                (ref.read(downloadNotifierProvider.notifier)
                    .isDownloading(song.id)))
              ListTile(
                leading: const Icon(Icons.cancel_outlined),
                title: const Text('Cancel download'),
                onTap: () {
                  ref.read(downloadNotifierProvider.notifier).cancel(song.id);
                  Navigator.pop(context);
                },
              )
            else if (!isDownloaded)
              ListTile(
                leading: const Icon(Icons.download_rounded),
                title: const Text('Download'),
                onTap: () {
                  startLocalDownload(ref, song);
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
                  confirmAndDeleteSong(context, ref, song);
                },
              ),
          ],
        ),
      ),
    );
  }

}

