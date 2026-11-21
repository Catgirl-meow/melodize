import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/errors/app_errors.dart';
import '../../core/models/playlist.dart';
import '../../core/models/song.dart';
import '../../core/audio/shuffle_mode.dart';
import '../../core/providers.dart';
import '../../shared/utils/formatting.dart';
import '../../shared/utils/snack.dart';
import '../../shared/utils/song_actions.dart';
import '../../shared/widgets/error_notice.dart';
import '../../shared/widgets/detail_header.dart';
import '../../shared/widgets/play_button_group.dart';
import '../../shared/widgets/playlist_cover.dart';
import '../../shared/widgets/song_selection.dart';
import '../../shared/widgets/song_tile.dart';
import '../playlists/playlist_dialogs.dart';
import '../playlists/playlist_edit_screen.dart';
import '../playlists/song_picker_screen.dart';

/// "32 songs · 2 h 4 min · updated today", plus who owns a locked playlist.
String playlistSubtitle(Playlist p, List<Song>? songs, String? user) {
  final parts = <String>[
    songCount(songs?.length ?? p.songCount),
    if (songs != null && songs.isNotEmpty) totalRuntime(songs),
    if (!p.isEditableBy(user))
      p.readonly && (p.owner == null || p.owner == user)
          ? 'smart playlist'
          : 'by ${p.owner}',
    if (updatedLabel(p.changedAt) case final u?) u,
  ];
  return parts.join(' · ');
}

Future<void> openPlaylistEditor(BuildContext context, WidgetRef ref,
    Playlist playlist, List<Song> songs) {
  return Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => PlaylistEditScreen(playlist: playlist, songs: songs),
  ));
}

/// Picks library songs and appends them to [playlist].
Future<void> pickAndAddSongs(BuildContext context, WidgetRef ref,
    Playlist playlist, List<Song> current) async {
  final picked = await Navigator.of(context, rootNavigator: true)
      .push<List<Song>>(MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => SongPickerScreen(
      playlistName: playlist.name,
      existingIds: {for (final s in current) s.id},
    ),
  ));
  if (picked == null || picked.isEmpty || !context.mounted) return;
  try {
    // Picked on purpose, so songs already in the playlist go in again.
    final r = await ref.read(playlistActionsProvider).addSongs(
        playlist.id, [for (final s in picked) s.id],
        allowDuplicates: true);
    if (context.mounted) {
      showStyledSnack(context, addResultMessage(playlist.name, r));
    }
  } catch (e) {
    if (context.mounted) {
      showStyledSnack(context, "Couldn't add songs: ${describeError(e)}",
          isError: true);
    }
  }
}

class PlaylistDetailScreen extends ConsumerStatefulWidget {
  final Playlist playlist;
  const PlaylistDetailScreen({super.key, required this.playlist});

  @override
  ConsumerState<PlaylistDetailScreen> createState() =>
      _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends ConsumerState<PlaylistDetailScreen> {
  final _selection = SongSelection();

  @override
  void initState() {
    super.initState();
    _selection.addListener(_onSelection);
  }

  void _onSelection() => setState(() {});

  @override
  void dispose() {
    _selection.removeListener(_onSelection);
    _selection.dispose();
    super.dispose();
  }

  Future<void> _removeAt(Playlist playlist, List<Song> songs, int index) async {
    final song = songs[index];
    final before = [for (final s in songs) s.id];
    final actions = ref.read(playlistActionsProvider);
    try {
      await actions.removeAt(playlist.id, index);
      if (!mounted) return;
      showStyledSnack(context, 'Removed "${song.title}"',
          actionLabel: 'Undo', onAction: () async {
        try {
          await actions.replaceSongs(playlist.id, before);
        } catch (e) {
          AppErrors.report("Couldn't put the song back", e);
        }
      });
    } catch (e) {
      if (mounted) {
        showStyledSnack(context, "Couldn't remove: ${describeError(e)}",
            isError: true);
      }
    }
  }

  Future<void> _removeSelected(Playlist playlist, List<Song> songs) async {
    final picked = _selection.pick(songs).map((s) => s.id).toSet();
    final before = [for (final s in songs) s.id];
    final after = [for (final id in before) if (!picked.contains(id)) id];
    _selection.clear();
    final actions = ref.read(playlistActionsProvider);
    try {
      await actions.saveEdits(playlist,
          name: playlist.name,
          comment: playlist.comment ?? '',
          originalSongIds: before,
          editedSongIds: after);
      if (!mounted) return;
      showStyledSnack(context, 'Removed ${songCount(before.length - after.length)}',
          actionLabel: 'Undo', onAction: () async {
        try {
          await actions.replaceSongs(playlist.id, before);
        } catch (e) {
          AppErrors.report("Couldn't put the songs back", e);
        }
      });
    } catch (e) {
      if (mounted) {
        showStyledSnack(context, "Couldn't remove: ${describeError(e)}",
            isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final user = ref.watch(currentUsernameProvider);
    // The list entry, so a rename shows here as soon as the list reloads.
    final playlist = ref.watch(playlistsProvider.select((a) {
          for (final p in a.valueOrNull ?? const <Playlist>[]) {
            if (p.id == widget.playlist.id) return p;
          }
          return null;
        })) ??
        widget.playlist;
    final editable = playlist.isEditableBy(user);
    final online = ref.watch(isOnlineProvider).valueOrNull ?? true;
    final canEdit = editable && online;
    final songsAsync = ref.watch(playlistSongsProvider(playlist.id));
    final songs = songsAsync.valueOrNull;
    final selecting = _selection.active;

    Future<void> play({bool shuffle = false}) async {
      final list = songs;
      if (list == null || list.isEmpty) return;
      final h = ref.read(audioHandlerNotifierProvider);
      if (h == null) return;
      if (shuffle) await h.applyShuffleMode(ShuffleMode.shuffle);
      await h.loadQueue(list);
    }

    final header = DetailHeader(
      title: playlist.name,
      subtitle: playlistSubtitle(playlist, songs, user),
      // Same app-built cover as the home card, not Navidrome's image.
      cover: PlaylistCover(
        playlist: playlist,
        size: double.infinity,
        borderRadius: 0,
        placeholderIcon: false,
      ),
      expandedHeight: 280,
      actions: [
        if (canEdit)
          IconButton(
            key: const Key('playlist-edit'),
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_rounded),
            onPressed: songs == null
                ? null
                : () => openPlaylistEditor(context, ref, playlist, songs),
          ),
        IconButton(
          key: const Key('playlist-more'),
          tooltip: 'More',
          icon: const Icon(Icons.more_vert_rounded),
          onPressed: () => showPlaylistMenu(
            context,
            ref,
            playlist,
            onEdit: songs == null || !online
                ? null
                : () => openPlaylistEditor(context, ref, playlist, songs),
            onDeleted: () {
              if (context.mounted) Navigator.of(context).maybePop();
            },
          ),
        ),
      ],
    );

    return PopScope(
      canPop: !selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _selection.clear();
      },
      child: Scaffold(
        body: Stack(
          children: [
            CustomScrollView(
              slivers: [
                header,
                if (playlist.comment != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                      child: Text(
                        playlist.comment!,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: PlayButtonGroup(
                      onPlay: songs == null || songs.isEmpty ? null : play,
                      actions: [
                        GroupAction(
                          icon: Icons.shuffle_rounded,
                          tooltip: 'Shuffle',
                          onTap: songs == null || songs.isEmpty
                              ? null
                              : () => play(shuffle: true),
                        ),
                        if (editable)
                          GroupAction(
                            key: const Key('playlist-add-songs'),
                            icon: Icons.playlist_add_rounded,
                            tooltip: 'Add songs',
                            background: scheme.tertiaryContainer,
                            foreground: scheme.onTertiaryContainer,
                            onTap: songs == null || !online
                                ? null
                                : () => pickAndAddSongs(
                                    context, ref, playlist, songs),
                          ),
                        GroupAction(
                          icon: Icons.download_rounded,
                          tooltip: 'Download all',
                          background: scheme.surfaceContainerHigh,
                          foreground: scheme.onSurfaceVariant,
                          onTap: songs == null || songs.isEmpty
                              ? null
                              : () => downloadSongs(context, ref, songs),
                        ),
                      ],
                    ),
                  ),
                ),
                songsAsync.when(
                  skipLoadingOnReload: true,
                  loading: () => const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => SliverToBoxAdapter(
                    child: ErrorNotice(
                      title: "Couldn't load this playlist",
                      error: e,
                      onRetry: () =>
                          ref.invalidate(playlistSongsProvider(playlist.id)),
                    ),
                  ),
                  data: (songs) => songs.isEmpty
                      ? SliverToBoxAdapter(
                          child: _EmptyPlaylist(
                            onAdd: canEdit
                                ? () => pickAndAddSongs(
                                    context, ref, playlist, songs)
                                : null,
                          ),
                        )
                      : SliverList.builder(
                          itemCount: songs.length,
                          itemBuilder: (_, i) => SongTile(
                            song: songs[i],
                            showAlbum: true,
                            selected: selecting
                                ? _selection.contains(songs[i].id)
                                : null,
                            onLongPress: () => _selection.toggle(songs[i].id),
                            onTap: selecting
                                ? () => _selection.toggle(songs[i].id)
                                : () => ref
                                    .read(audioHandlerNotifierProvider)
                                    ?.loadQueue(songs, startIndex: i),
                            menuActions: [
                              if (canEdit)
                                SongMenuAction(
                                  icon: Icons.playlist_remove_rounded,
                                  label: 'Remove from this playlist',
                                  onTap: () => _removeAt(playlist, songs, i),
                                ),
                            ],
                          ),
                        ),
                ),
                SliverPadding(
                  padding: EdgeInsets.only(
                      bottom: MediaQuery.paddingOf(context).bottom + 16),
                ),
              ],
            ),
            if (selecting && songs != null)
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: SongSelectionAppBar(
                  selection: _selection,
                  songs: songs,
                  extraMenu: [
                    if (canEdit)
                      PopupMenuItem(
                        value: () => _removeSelected(playlist, songs),
                        child: const ListTile(
                          leading: Icon(Icons.playlist_remove_rounded),
                          title: Text('Remove from playlist'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyPlaylist extends StatelessWidget {
  final VoidCallback? onAdd;
  const _EmptyPlaylist({this.onAdd});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 16),
      child: Column(
        children: [
          Icon(Icons.queue_music_rounded,
              size: 48, color: scheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text('This playlist is empty', style: text.titleMedium),
          if (onAdd != null) ...[
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add songs'),
            ),
          ],
        ],
      ),
    );
  }
}
