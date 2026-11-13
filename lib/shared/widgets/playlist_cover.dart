import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_errors.dart';
import '../../core/models/playlist.dart';
import '../../core/models/song.dart';
import '../../core/providers.dart';
import 'cover_art_image.dart';

/// Cover for a playlist, built in the app from its songs' album art so that
/// every playlist follows the same rules.
///
/// Navidrome's own playlist image (`getCoverArt?id=pl-…`) comes in three
/// unrelated looks: a 2x2 mosaic when the playlist spans two or more albums
/// (with two or three albums it repeats covers to fill the grid), a single
/// album cover for one album, and Navidrome's blue vinyl placeholder when the
/// albums have no art. On the home carousel these sat next to each other
/// and next to the app's own placeholder for playlists without a `coverArt`
/// field, so no two playlists looked alike.
///
/// Here: four or more albums with art give a 2x2 mosaic of four different
/// covers, one to three give the first album's cover, none gives the app's
/// playlist placeholder.
class PlaylistCover extends ConsumerWidget {
  final Playlist playlist;

  /// Edge length. `double.infinity` fills the parent (page headers).
  final double size;
  final double borderRadius;

  /// Draw the playlist icon on the placeholder. Off for page headers,
  /// where the name text sits on top of the cover area.
  final bool placeholderIcon;

  const PlaylistCover({
    super.key,
    required this.playlist,
    required this.size,
    this.borderRadius = 8,
    this.placeholderIcon = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final songs = ref.watch(playlistSongsProvider(playlist.id));

    final Widget child = songs.when(
      skipLoadingOnRefresh: true,
      // Plain tile while the songs load, so a playlist doesn't flash the
      // placeholder icon before its covers arrive.
      loading: () => _tile(scheme, icon: false),
      // A failed load is shown as one, not as the "no artwork" placeholder.
      // The playlist page shows the full error with a retry.
      error: (e, _) => Tooltip(
        message: describeError(e),
        child: Container(
          width: size,
          height: size,
          color: scheme.errorContainer,
          child: Icon(
            Icons.broken_image_outlined,
            size: size.isFinite ? size * 0.4 : 72,
            color: scheme.onErrorContainer,
          ),
        ),
      ),
      data: (songs) {
        final covers = playlistCoverIds(songs);
        if (covers.isEmpty) return _tile(scheme, icon: placeholderIcon);
        if (covers.length < 4) return _cover(covers.first, size);
        // Infinite size: each quarter fills its cell of the parent's box.
        final half = size.isFinite ? size / 2 : double.infinity;
        return SizedBox(
          width: size,
          height: size,
          child: Column(
            children: [
              for (final row in const [0, 2])
                Expanded(
                  child: Row(
                    children: [
                      for (final i in [row, row + 1])
                        Expanded(child: _cover(covers[i], half)),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: child,
    );
  }

  Widget _cover(String id, double edge) => CoverArtImage(
        coverArtId: id,
        size: edge,
        borderRadius: 0,
        placeholderIcon: false,
      );

  Widget _tile(ColorScheme scheme, {required bool icon}) => Container(
        width: size,
        height: size,
        color: scheme.surfaceContainerHigh,
        child: !icon
            ? null
            : Icon(
                Icons.queue_music_rounded,
                size: size.isFinite ? size * 0.4 : 72,
                color: scheme.onSurfaceVariant,
              ),
      );
}

/// Up to four cover-art ids for a playlist mosaic: one per album, in
/// playlist order, skipping songs whose album has no art.
List<String> playlistCoverIds(List<Song> songs) {
  final seenAlbums = <String>{};
  final seenCovers = <String>{};
  final ids = <String>[];
  for (final s in songs) {
    final cover = s.coverArt;
    if (cover == null || cover.isEmpty) continue;
    // Navidrome gives each song its own cover id (mf-…), so dedupe by album.
    final album = s.albumId ?? cover;
    if (!seenAlbums.add(album) || !seenCovers.add(cover)) continue;
    ids.add(cover);
    if (ids.length == 4) break;
  }
  return ids;
}
