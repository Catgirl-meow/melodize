import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/shuffle_mode.dart';
import '../../core/db/database.dart' show PendingLike;
import '../../core/library/library_overview.dart';
import '../../core/models/song.dart';
import '../../core/providers.dart';
import '../../shared/utils/download_polling_mixin.dart';
import '../../shared/utils/formatting.dart';
import '../../shared/utils/song_actions.dart';
import '../../shared/widgets/cover_art_image.dart';
import '../../shared/widgets/error_notice.dart';
import '../../shared/widgets/play_button_group.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/song_selection.dart';
import '../../shared/widgets/song_tile.dart';
import '../playlists/playlist_dialogs.dart';

/// A song list opened from the Library overview (Liked songs, Recently
/// added): title, stats, Play / Shuffle / Save as playlist / Download, and
/// long-press multi-select.
class SongCollectionScreen extends ConsumerStatefulWidget {
  final String title;
  final IconData icon;
  final AsyncValue<List<Song>> Function(WidgetRef ref) watchSongs;
  final VoidCallback Function(WidgetRef ref) retry;
  final String errorTitle;
  final Widget empty;

  /// Extra content under the songs (Liked: "Waiting to be added").
  final List<Widget> Function(BuildContext context, WidgetRef ref)?
      extraSlivers;

  /// Shown when the songs are empty but [extraSlivers] has content.
  final bool Function(WidgetRef ref)? hasExtra;

  const SongCollectionScreen({
    super.key,
    required this.title,
    required this.icon,
    required this.watchSongs,
    required this.retry,
    required this.errorTitle,
    required this.empty,
    this.extraSlivers,
    this.hasExtra,
  });

  @override
  ConsumerState<SongCollectionScreen> createState() =>
      _SongCollectionScreenState();
}

class _SongCollectionScreenState extends ConsumerState<SongCollectionScreen> {
  final _selection = SongSelection();

  @override
  void initState() {
    super.initState();
    _selection.addListener(_changed);
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    _selection.removeListener(_changed);
    _selection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final async = widget.watchSongs(ref);
    final songs = async.valueOrNull ?? const <Song>[];
    final selecting = _selection.active;
    final handler = ref.read(audioHandlerNotifierProvider);

    Future<void> play({bool shuffle = false}) async {
      if (songs.isEmpty || handler == null) return;
      if (shuffle) await handler.applyShuffleMode(ShuffleMode.shuffle);
      await handler.loadQueue(songs);
    }

    final appBar = selecting
        ? SliverToBoxAdapter(
            child: SongSelectionAppBar(selection: _selection, songs: songs))
        : SliverAppBar.medium(
            title: Text(widget.title),
            pinned: true,
          );

    return PopScope(
      canPop: !selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _selection.clear();
      },
      child: Scaffold(
        body: async.when(
          skipLoadingOnReload: true,
          loading: () => CustomScrollView(slivers: [
            appBar,
            const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator())),
          ]),
          error: (e, _) => CustomScrollView(slivers: [
            appBar,
            SliverToBoxAdapter(
              child: ErrorNotice(
                  title: widget.errorTitle,
                  error: e,
                  onRetry: widget.retry(ref)),
            ),
          ]),
          data: (songs) {
            final extra = widget.extraSlivers?.call(context, ref) ?? const [];
            final hasExtra = widget.hasExtra?.call(ref) ?? false;
            return CustomScrollView(
              slivers: [
                appBar,
                if (songs.isEmpty && !hasExtra)
                  SliverFillRemaining(
                      hasScrollBody: false, child: widget.empty),
                if (songs.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                      child: Row(
                        children: [
                          Icon(widget.icon, size: 18, color: scheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            '${songCount(songs.length)} · ${totalRuntime(songs)}',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: PlayButtonGroup(
                        onPlay: play,
                        actions: [
                          GroupAction(
                            icon: Icons.shuffle_rounded,
                            tooltip: 'Shuffle',
                            onTap: () => play(shuffle: true),
                          ),
                          GroupAction(
                            icon: Icons.playlist_add_rounded,
                            tooltip: 'Save as playlist',
                            background: scheme.tertiaryContainer,
                            foreground: scheme.onTertiaryContainer,
                            onTap: () async {
                              await createPlaylistFlow(context, ref,
                                  songs: [
                                    for (final s in songs)
                                      if (!s.isExternal) s
                                  ]);
                            },
                          ),
                          GroupAction(
                            icon: Icons.download_rounded,
                            tooltip: 'Download all',
                            background: scheme.surfaceContainerHigh,
                            foreground: scheme.onSurfaceVariant,
                            onTap: () => downloadSongs(context, ref, songs),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                SliverList.builder(
                  itemCount: songs.length,
                  itemBuilder: (_, i) => RepaintBoundary(
                    child: SongTile(
                      song: songs[i],
                      showAlbum: true,
                      selected:
                          selecting ? _selection.contains(songs[i].id) : null,
                      onLongPress: () => _selection.toggle(songs[i].id),
                      onTap: selecting
                          ? () => _selection.toggle(songs[i].id)
                          : () => handler?.loadQueue(songs, startIndex: i),
                    ),
                  ),
                ),
                ...extra,
                SliverPadding(
                  padding: EdgeInsets.only(
                      bottom: MediaQuery.paddingOf(context).bottom + 16),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Liked songs

class LikedSongsScreen extends StatelessWidget {
  const LikedSongsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SongCollectionScreen(
      title: 'Liked songs',
      icon: Icons.favorite_rounded,
      watchSongs: (ref) => ref.watch(likedSongsProvider),
      retry: (ref) => () => ref.invalidate(allSongsProvider),
      errorTitle: "Couldn't load liked songs",
      empty: const _Empty(
        icon: Icons.favorite_border_rounded,
        title: 'No liked songs yet',
        body: "Tap the heart on Now Playing or in a song's menu. Likes sync "
            'with your Navidrome server.',
      ),
      hasExtra: (ref) {
        final pending = ref.watch(pendingLikesProvider);
        return pending.hasError || (pending.valueOrNull?.isNotEmpty ?? false);
      },
      extraSlivers: (context, ref) {
        final pendingAsync = ref.watch(pendingLikesProvider);
        final pending = pendingAsync.valueOrNull ?? const <PendingLike>[];
        return [
          if (pendingAsync.hasError)
            SliverToBoxAdapter(
              child: ErrorNotice(
                title: "Couldn't read liked recommendations",
                error: pendingAsync.error!,
                compact: true,
                onRetry: () => ref.invalidate(pendingLikesProvider),
              ),
            ),
          if (pending.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: SectionHeader('Waiting to be added',
                  count: '${pending.length}'),
            ),
            SliverList.builder(
              itemCount: pending.length,
              itemBuilder: (_, i) => PendingLikeTile(like: pending[i]),
            ),
          ],
        ];
      },
    );
  }
}

/// A liked Deezer track that isn't in the library yet (the companion add is
/// still running, failed, or there is no companion). Tap to preview; Add
/// retries the server download.
class PendingLikeTile extends ConsumerStatefulWidget {
  final PendingLike like;
  const PendingLikeTile({super.key, required this.like});

  @override
  ConsumerState<PendingLikeTile> createState() => _PendingLikeTileState();
}

class _PendingLikeTileState extends ConsumerState<PendingLikeTile>
    with DownloadPollingMixin {
  @override
  Widget build(BuildContext context) {
    final like = widget.like;
    final scheme = Theme.of(context).colorScheme;
    final canAdd = ref.watch(companionClientProvider) != null;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: CoverArtImage(
          coverArtId: null, externalUrl: like.coverUrl, size: 48),
      title: Text(like.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('${like.artist} · preview',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: scheme.onSurfaceVariant)),
      onTap: like.previewUrl == null
          ? null
          : () => ref.read(audioHandlerNotifierProvider)?.loadQueue([
                Song.fromRecommendation(
                  deezerId: like.deezerId,
                  title: like.title,
                  artist: like.artist,
                  album: like.album,
                  durationSeconds: like.duration ?? 0,
                  previewUrl: like.previewUrl,
                  coverUrl: like.coverUrl,
                ),
              ]),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (canAdd)
            TextButton(
              onPressed: () => addDeezerTrackToServer(like.deezerId),
              child: const Text('Add'),
            ),
          IconButton(
            tooltip: 'Unlike',
            icon: Icon(Icons.favorite_rounded, color: scheme.primary),
            onPressed: () => ref
                .read(likesProvider.notifier)
                .unlikeRecommendation(like.deezerId),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Recently added

class RecentlyAddedScreen extends StatelessWidget {
  const RecentlyAddedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SongCollectionScreen(
      title: 'Recently added',
      icon: Icons.history_rounded,
      watchSongs: (ref) =>
          ref.watch(allSongsProvider).whenData(recentlyAddedSongs),
      retry: (ref) => () => ref.invalidate(allSongsProvider),
      errorTitle: "Couldn't load your library",
      empty: const _Empty(
        icon: Icons.history_rounded,
        title: 'Nothing here yet',
        body: 'Songs show up here once your server reports when they were '
            'added.',
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _Empty({required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: scheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(title, style: text.titleMedium),
            const SizedBox(height: 4),
            Text(body,
                textAlign: TextAlign.center,
                style:
                    text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
