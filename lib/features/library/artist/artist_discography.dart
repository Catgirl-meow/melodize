import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_errors.dart';
import '../../../core/library/artist_profile.dart';
import '../../../core/models/song.dart';
import '../../../core/models/album.dart';
import '../../../core/providers.dart';
import '../../../shared/utils/song_actions.dart';
import '../../../shared/widgets/album_grid_tile.dart';
import '../../../shared/widgets/cover_art_image.dart';
import 'artist_sections.dart';

String releaseSubtitle(Album a) =>
    [releaseKindOf(a).label, if (a.year != null) '${a.year}'].join(' · ');

/// Filter chips by release type, a sort menu, and either an M3 multi-browse
/// carousel (phones, default) or a grid.
class DiscographySection extends ConsumerStatefulWidget {
  final List<Album> albums;

  /// Desktop: always a grid, chips beside the title.
  final bool wide;

  const DiscographySection(
      {super.key, required this.albums, this.wide = false});

  @override
  ConsumerState<DiscographySection> createState() =>
      _DiscographySectionState();
}

class _DiscographySectionState extends ConsumerState<DiscographySection> {
  var _filter = DiscographyFilter.all;
  var _sort = DiscographySort.newest;
  var _grid = false;

  @override
  Widget build(BuildContext context) {
    final albums = widget.albums;
    if (albums.isEmpty) return const SizedBox.shrink();
    final counts = discographyCounts(albums);
    final shown = discography(albums, filter: _filter, sort: _sort);
    // Two or fewer releases look odd in a carousel.
    final grid = widget.wide || _grid || shown.length <= 2;

    final sortMenu = MenuAnchor(
      builder: (context, controller, _) => TextButton.icon(
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
        icon: const Icon(Icons.swap_vert_rounded, size: 18),
        label: Text(_sort.label),
      ),
      menuChildren: [
        for (final s in DiscographySort.values)
          MenuItemButton(
            leadingIcon: Icon(
                s == _sort ? Icons.check_rounded : null,
                size: 18),
            onPressed: () => setState(() => _sort = s),
            child: Text(s.label),
          ),
      ],
    );

    final chips = [
      for (final f in DiscographyFilter.values)
        if (f == DiscographyFilter.all || (counts[f] ?? 0) > 0)
          FilterChip(
            label: Text('${f.label} ${counts[f]}'),
            selected: _filter == f,
            showCheckmark: true,
            onSelected: (_) => setState(() => _filter = f),
          ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ArtistSectionTitle(
          'Discography',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              sortMenu,
              if (!widget.wide && shown.length > 2)
                IconButton(
                  tooltip: _grid ? 'Show as carousel' : 'Show as grid',
                  onPressed: () => setState(() => _grid = !_grid),
                  icon: Icon(_grid
                      ? Icons.view_carousel_outlined
                      : Icons.grid_view_rounded),
                ),
            ],
          ),
        ),
        if (chips.length > 2)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                for (final c in chips) ...[c, const SizedBox(width: 8)],
              ],
            ),
          ),
        if (grid)
          _Grid(albums: shown, wide: widget.wide)
        else
          _Carousel(albums: shown),
      ],
    );
  }
}

class _Carousel extends StatelessWidget {
  final List<Album> albums;
  const _Carousel({required this.albums});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 220,
      child: CarouselView.weighted(
        flexWeights: const [5, 3, 1],
        itemSnapping: true,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        onTap: (i) => openAlbum(context, albums[i]),
        children: [
          for (final a in albums)
            LayoutBuilder(
              builder: (context, c) => Stack(
                fit: StackFit.expand,
                children: [
                  CoverArtImage(
                    coverArtId: a.coverArt,
                    size: c.maxHeight,
                    borderRadius: 0,
                  ),
                  // The label only fits on the large item.
                  if (c.maxWidth > 150)
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: scheme.surface,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(a.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700)),
                            Text(
                              '${releaseSubtitle(a)} · ${a.songCount} '
                              '${a.songCount == 1 ? 'song' : 'songs'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Grid extends ConsumerWidget {
  final List<Album> albums;
  final bool wide;
  const _Grid({required this.albums, required this.wide});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LayoutBuilder(builder: (context, c) {
        const gap = 12.0;
        final columns = wide
            ? (c.maxWidth / 180).floor().clamp(3, 8)
            : (c.maxWidth / 170).floor().clamp(2, 4);
        final tileWidth = (c.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final a in albums)
              SizedBox(
                width: tileWidth,
                height: AlbumGridTile.extent(context, tileWidth,
                    detailLines: 1),
                child: GestureDetector(
                  onLongPress: () => showAlbumSheet(context, ref, a),
                  child: AlbumGridTile(
                    coverArtId: a.coverArt,
                    title: a.name,
                    subtitle: releaseSubtitle(a),
                    onTap: () => openAlbum(context, a),
                    trailing: IconButton(
                      icon: const Icon(Icons.more_vert_rounded, size: 20),
                      tooltip: 'More for ${a.name}',
                      visualDensity: VisualDensity.compact,
                      style: IconButton.styleFrom(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => showAlbumSheet(context, ref, a),
                    ),
                  ),
                ),
              ),
          ],
        );
      }),
    );
  }
}

/// Album actions: Play, Shuffle, Play next, Add to queue, Download, Open.
void showAlbumSheet(BuildContext context, WidgetRef ref, Album album) {
  final scheme = Theme.of(context).colorScheme;
  final text = Theme.of(context).textTheme;

  Future<void> queueAll({required bool next}) async {
    final List<Song> songs;
    try {
      songs = await ref.read(albumSongsProvider(album.id).future);
    } catch (e) {
      AppErrors.report("Couldn't load ${album.name}", e);
      return;
    }
    final handler = ref.read(audioHandlerNotifierProvider);
    if (handler == null) return;
    // playNext inserts right after the current song, so go backwards to
    // keep the album order.
    for (final s in next ? songs.reversed : songs) {
      next ? await handler.playNext(s) : await handler.addToQueue(s);
    }
  }

  showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: Row(
              children: [
                CoverArtImage(
                    coverArtId: album.coverArt, size: 64, borderRadius: 16),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(album.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      Text(
                        '${releaseSubtitle(album)} · ${album.songCount} '
                        '${album.songCount == 1 ? 'song' : 'songs'}',
                        style: text.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 56)),
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      playAlbum(context, ref, album);
                    },
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Play'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 56)),
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      playAlbum(context, ref, album, shuffle: true);
                    },
                    icon: const Icon(Icons.shuffle_rounded),
                    label: const Text('Shuffle'),
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.queue_music_rounded),
            title: const Text('Play next'),
            onTap: () {
              Navigator.pop(sheetContext);
              queueAll(next: true);
            },
          ),
          ListTile(
            leading: const Icon(Icons.add_rounded),
            title: const Text('Add to queue'),
            onTap: () {
              Navigator.pop(sheetContext);
              queueAll(next: false);
            },
          ),
          ListTile(
            leading: const Icon(Icons.download_rounded),
            title: const Text('Download'),
            onTap: () {
              Navigator.pop(sheetContext);
              downloadAlbum(context, ref, album);
            },
          ),
          ListTile(
            leading: const Icon(Icons.album_outlined),
            title: const Text('Open album'),
            onTap: () {
              Navigator.pop(sheetContext);
              openAlbum(context, album);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
