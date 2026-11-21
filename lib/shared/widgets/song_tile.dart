import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'like_button.dart';
import '../../core/models/song.dart';
import '../../core/providers.dart';
import '../utils/snack.dart';
import '../utils/song_actions.dart';
import 'cover_art_image.dart';
import 'song_drag.dart';
import '../../features/playlists/add_to_playlist_sheet.dart';
import '../theme/app_theme.dart';
import '../theme/motion.dart';

/// An extra entry in a song's ⋮ sheet, e.g. "Remove from this playlist".
class SongMenuAction {
  final IconData icon;
  final String label;
  final bool destructive;
  final VoidCallback onTap;
  const SongMenuAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });
}

class SongTile extends ConsumerWidget {
  final Song song;
  final VoidCallback? onTap;
  final bool showAlbum;
  final Widget? trailing;

  /// Replaces the cover thumbnail (album pages show the track number).
  final Widget? leading;

  /// Replaces the artist (· album) line, e.g. "Glasshouse · 38 plays".
  final String? subtitle;

  /// Long-press, usually to start selecting several songs.
  final VoidCallback? onLongPress;

  /// Non-null while the list is in selection mode: the cover becomes a
  /// check mark and the ⋮ button is hidden.
  final bool? selected;

  /// Extra entries at the end of the ⋮ sheet.
  final List<SongMenuAction> menuActions;

  const SongTile({
    super.key,
    required this.song,
    this.onTap,
    this.showAlbum = false,
    this.trailing,
    this.leading,
    this.subtitle,
    this.onLongPress,
    this.selected,
    this.menuActions = const [],
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

    final selecting = selected != null;
    final cover = leading ??
        CoverArtImage(
            coverArtId: song.coverArt,
            localPath: song.localPath,
            songId: song.id,
            size: 48);
    final tile = ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      selected: selected ?? false,
      selectedTileColor: scheme.secondaryContainer.withValues(alpha: 0.6),
      selectedColor: scheme.onSurface,
      shape: selecting
          ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
          : null,
      onLongPress: onLongPress,
      leading: !selecting
          ? cover
          : AnimatedSwitcher(
              duration: Motion.short.duration,
              child: selected!
                  ? Container(
                      key: const ValueKey('checked'),
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.check_rounded, color: scheme.onPrimary),
                    )
                  : KeyedSubtree(key: const ValueKey('cover'), child: cover),
            ),
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
        subtitle ??
            (showAlbum ? '${song.artist} · ${song.album}' : song.artist),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: scheme.onSurfaceVariant),
      ),
      trailing: selecting
          ? null
          : trailing ??
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
                  _MoreButton(
                      song: song,
                      isDownloaded: isDownloaded,
                      extra: menuActions),
                ],
              ),
      onTap: onTap,
    );
    // Desktop Library: drag a song onto a playlist in the sidebar.
    if (selecting || song.isExternal || !SongDragScope.enabled(context)) {
      return tile;
    }
    return Draggable<SongDragData>(
      data: SongDragData([song]),
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: SongDragFeedback(songs: [song]),
      childWhenDragging: Opacity(opacity: 0.5, child: tile),
      child: tile,
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
        style: AppTheme.emphasized(context)
            .labelSmall
            ?.copyWith(color: scheme.onSecondaryContainer),
      ),
    );
  }
}

class _MoreButton extends ConsumerWidget {
  final Song song;
  final bool isDownloaded;
  final List<SongMenuAction> extra;
  const _MoreButton(
      {required this.song, required this.isDownloaded, this.extra = const []});

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
            if (!song.isExternal)
              ListTile(
                leading: const Icon(Icons.playlist_add_rounded),
                title: const Text('Add to playlist'),
                onTap: () {
                  Navigator.pop(context);
                  showAddToPlaylistSheet(context, ref, [song]);
                },
              ),
            if (!song.isExternal)
              Consumer(builder: (_, ref, __) {
                final liked = ref.watch(isLikedProvider(song.id));
                return ListTile(
                  leading: Icon(liked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded),
                  title: Text(liked ? 'Unlike' : 'Like'),
                  onTap: () {
                    Navigator.pop(context);
                    toggleLibraryLike(ref, song);
                  },
                );
              }),
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
                (ref
                    .read(downloadNotifierProvider.notifier)
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
                leading:
                    Icon(Icons.delete_forever_rounded, color: scheme.error),
                title: Text('Delete from server',
                    style: TextStyle(color: scheme.error)),
                onTap: () {
                  Navigator.pop(context);
                  confirmAndDeleteSong(context, ref, song);
                },
              ),
            for (final a in extra)
              ListTile(
                leading:
                    Icon(a.icon, color: a.destructive ? scheme.error : null),
                title: Text(a.label,
                    style:
                        a.destructive ? TextStyle(color: scheme.error) : null),
                onTap: () {
                  Navigator.pop(context);
                  a.onTap();
                },
              ),
          ],
        ),
      ),
    );
  }
}
