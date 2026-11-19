import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/errors/app_errors.dart';
import '../../../core/library/artist_profile.dart';
import '../../../core/models/album.dart';
import '../../../core/models/artist.dart';
import '../../../core/models/song.dart';
import '../../../core/providers.dart';
import '../../../core/utils/title_normalize.dart';
import '../../../shared/utils/snack.dart';
import '../../../shared/widgets/cover_art_image.dart';
import '../../../shared/widgets/deezer_track_tile.dart';
import '../../../shared/widgets/error_notice.dart';
import '../../../shared/widgets/song_tile.dart';
import '../album_detail_screen.dart';
import '../artist_detail_screen.dart';
import 'artist_songs_screen.dart';

/// Section title on the artist page: titleLarge bold with an optional
/// trailing widget (caption, link or button).
class ArtistSectionTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  const ArtistSectionTitle(
    this.title, {
    super.key,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(16, 28, 8, 8),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

TextStyle? _captionStyle(BuildContext context) => Theme.of(context)
    .textTheme
    .bodySmall
    ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);

/// Whether [error] only means the device is offline, which hides the
/// online-only sections instead of showing an error card.
bool isOffline(Object? error) => error is DeviceOfflineException;

/// "1.2M", "34K", "980".
String compactCount(int n) {
  String trim(double v) =>
      v >= 10 ? v.toStringAsFixed(0) : v.toStringAsFixed(1).replaceAll('.0', '');
  if (n >= 1000000) return '${trim(n / 1000000)}M';
  if (n >= 1000) return '${trim(n / 1000)}K';
  return '$n';
}

// ---------------------------------------------------------------------------
// Your listening

class ListeningCard extends ConsumerWidget {
  final Artist artist;
  final bool compact;

  const ListeningCard({super.key, required this.artist, this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats =
        ref.watch(artistListeningStatsProvider(artist.name)).valueOrNull;
    if (stats == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    Widget stat(String value, String label) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: (compact ? text.headlineSmall : text.headlineMedium)
                      ?.copyWith(fontWeight: FontWeight.w800)),
              Text(label, style: _captionStyle(context)),
            ],
          ),
        );

    final top = stats.topSong;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your listening',
              style: text.titleSmall?.copyWith(
                  color: scheme.primary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(
            children: [
              stat('${stats.plays}', stats.plays == 1 ? 'play' : 'plays'),
              if (stats.monthRank != null)
                stat('#${stats.monthRank}',
                    compact ? 'this month' : 'artist this month'),
              stat('${stats.firstPlayed.year}', 'first played'),
            ],
          ),
          if (!compact) ...[
            const SizedBox(height: 16),
            Material(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => ref.read(audioHandlerNotifierProvider)?.loadQueue([
                  Song(
                    id: top.songId,
                    title: top.title,
                    artist: artist.name,
                    album: '',
                    coverArt: top.coverArt,
                  ),
                ]),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      CoverArtImage(
                          coverArtId: top.coverArt,
                          songId: top.songId,
                          size: 44,
                          borderRadius: 10),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Your most played',
                                style: _captionStyle(context)),
                            Text(
                              '${top.title} · ${top.plays} '
                              '${top.plays == 1 ? 'play' : 'plays'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.play_circle_rounded,
                          size: 36,
                          color: scheme.primary,
                          semanticLabel: 'Play ${top.title}'),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Popular

class PopularSection extends ConsumerWidget {
  final Artist artist;

  /// Show album, play count and duration columns (desktop).
  final bool wide;

  const PopularSection({super.key, required this.artist, this.wide = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topAsync = ref.watch(artistTopSongsProvider(artist.name));
    if (topAsync.isLoading) return const SizedBox.shrink();
    if (topAsync.hasError && !isOffline(topAsync.error)) {
      return ErrorNotice(
        title: "Couldn't load popular songs",
        error: topAsync.error,
        compact: true,
        onRetry: () => ref.invalidate(artistTopSongsProvider(artist.name)),
      );
    }

    List<Song> songs = (topAsync.valueOrNull ?? const []).take(5).toList();
    var source = PopularSource.lastFm;
    final history = ref.watch(playRecordsProvider).valueOrNull ?? const [];
    final counts = <String, int>{};
    for (final h in history) {
      counts[h.songId] = (counts[h.songId] ?? 0) + 1;
    }

    // No Last.fm data (or offline): rank by plays instead of hiding.
    if (songs.isEmpty) {
      final all = ref.watch(artistAllSongsProvider(artist.id)).valueOrNull;
      if (all == null) return const SizedBox.shrink();
      final ranked = popularFromPlays(all, history);
      songs = ranked.songs;
      source = ranked.source;
    }
    if (songs.isEmpty) return const SizedBox.shrink();

    final caption = switch (source) {
      PopularSource.lastFm => 'Last.fm',
      PopularSource.serverPlays => 'By plays',
      PopularSource.yourPlays => 'Your plays',
    };
    final playingId = ref.watch(
        currentSongStreamProvider.select((s) => s.valueOrNull?.id));
    final scheme = Theme.of(context).colorScheme;

    String plays(Song s) {
      final n = s.playCount ?? counts[s.id] ?? 0;
      return n == 0 ? '' : '$n ${n == 1 ? 'play' : 'plays'}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ArtistSectionTitle(
          'Popular',
          trailing: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(caption,
                style: _captionStyle(context)),
          ),
        ),
        for (var i = 0; i < songs.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Material(
              color: songs[i].id == playingId
                  ? scheme.primaryContainer
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: SongTile(
                song: songs[i],
                subtitle: [
                  if (songs[i].album.isNotEmpty) songs[i].album,
                  if (!wide && plays(songs[i]).isNotEmpty) plays(songs[i]),
                ].join(' · '),
                leading: SizedBox(
                  width: 84,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 28,
                        child: songs[i].id == playingId
                            ? Icon(Icons.equalizer_rounded,
                                color: scheme.primary, size: 20)
                            : Text(
                                '${i + 1}',
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: scheme.onSurfaceVariant),
                              ),
                      ),
                      const SizedBox(width: 8),
                      CoverArtImage(
                        coverArtId: songs[i].coverArt,
                        songId: songs[i].id,
                        size: 48,
                        borderRadius: 12,
                      ),
                    ],
                  ),
                ),
                trailing: wide
                    ? Text(
                        [
                          if (plays(songs[i]).isNotEmpty) plays(songs[i]),
                          songs[i].durationFormatted,
                        ].join('   '),
                        style: _captionStyle(context),
                      )
                    : null,
                onTap: () => ref
                    .read(audioHandlerNotifierProvider)
                    ?.loadQueue(songs, startIndex: i),
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Latest release

Future<void> playAlbum(BuildContext context, WidgetRef ref, Album album,
    {bool shuffle = false}) async {
  try {
    final songs = await ref.read(albumSongsProvider(album.id).future);
    if (songs.isEmpty) return;
    await ref
        .read(audioHandlerNotifierProvider)
        ?.loadQueue(shuffle ? ([...songs]..shuffle()) : songs);
  } catch (e) {
    if (context.mounted) {
      showStyledSnack(context, "Couldn't load ${album.name}: $e",
          isError: true);
    }
  }
}

void openAlbum(BuildContext context, Album album) => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AlbumDetailScreen(album: album)),
    );

class LatestReleaseCard extends ConsumerWidget {
  final Album album;
  final bool vertical;

  const LatestReleaseCard(
      {super.key, required this.album, this.vertical = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final kind = releaseKindOf(album);
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('NEW · ${album.year}',
            style: text.labelMedium?.copyWith(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6)),
        const SizedBox(height: 2),
        Text(album.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: text.titleLarge?.copyWith(
                color: scheme.onPrimaryContainer, fontWeight: FontWeight.w800)),
        Text(
          '${kind.label} · ${album.songCount} '
          '${album.songCount == 1 ? 'song' : 'songs'}',
          style: text.bodyMedium?.copyWith(
              color: scheme.onPrimaryContainer.withValues(alpha: 0.8)),
        ),
      ],
    );
    final play = IconButton.filled(
      tooltip: 'Play ${album.name}',
      iconSize: 28,
      style: IconButton.styleFrom(
        minimumSize: const Size(56, 56),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      onPressed: () => playAlbum(context, ref, album),
      icon: const Icon(Icons.play_arrow_rounded),
    );

    return Material(
      color: scheme.primaryContainer,
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openAlbum(context, album),
        child: Padding(
          padding: EdgeInsets.all(vertical ? 16 : 12),
          child: vertical
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AspectRatio(
                      aspectRatio: 1,
                      child: LayoutBuilder(
                        builder: (_, c) => CoverArtImage(
                            coverArtId: album.coverArt,
                            size: c.maxWidth,
                            borderRadius: 20),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(children: [Expanded(child: details), play]),
                  ],
                )
              : Row(
                  children: [
                    CoverArtImage(
                        coverArtId: album.coverArt,
                        size: 112,
                        borderRadius: 20),
                    const SizedBox(width: 16),
                    Expanded(child: details),
                    const SizedBox(width: 8),
                    play,
                  ],
                ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Not in your library (Deezer)

class MissingTracksSection extends ConsumerWidget {
  final Artist artist;
  const MissingTracksSection({super.key, required this.artist});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(deezerArtistTracksProvider(artist.name));
    if (async.isLoading || isOffline(async.error)) {
      return const SizedBox.shrink();
    }
    if (async.hasError) {
      return ErrorNotice(
        title: "Couldn't load this artist from Deezer",
        error: async.error,
        compact: true,
        onRetry: () => ref.invalidate(deezerArtistIdProvider(artist.name)),
      );
    }
    final tracks = async.valueOrNull ?? const [];
    if (tracks.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ArtistSectionTitle(
          'Not in your library',
          trailing: tracks.length > 3
              ? TextButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => DraggableScrollableSheet(
                      expand: false,
                      initialChildSize: 0.7,
                      builder: (_, controller) => ListView(
                        controller: controller,
                        children: [
                          ArtistSectionTitle('${artist.name} on Deezer',
                              padding:
                                  const EdgeInsets.fromLTRB(16, 0, 16, 8)),
                          for (final t in tracks) DeezerTrackTile(track: t),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                  child: Text('See all ${tracks.length}'),
                )
              : null,
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            children: [
              for (final t in tracks.take(3)) DeezerTrackTile(track: t),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Fans also like

/// One avatar in "Fans also like": an artist in the library (opens their
/// page) or one only on Deezer (opens their Deezer tracks).
class _Similar {
  final String name;
  final String? libraryId;
  final int albumCount;
  final String? coverArt;
  final String? imageUrl;

  const _Similar({
    required this.name,
    this.libraryId,
    this.albumCount = 0,
    this.coverArt,
    this.imageUrl,
  });
}

class SimilarArtistsSection extends ConsumerWidget {
  final Artist artist;
  const SimilarArtistsSection({super.key, required this.artist});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(artistInfoProvider(artist.id)).valueOrNull;
    final related =
        ref.watch(deezerRelatedArtistsProvider(artist.name)).valueOrNull;

    final items = <_Similar>[];
    final seen = <String>{normalize(artist.name)};
    void add(_Similar s) {
      if (seen.add(normalize(s.name))) items.add(s);
    }

    for (final s in info?.similar ?? const []) {
      if (s.inLibrary) {
        add(_Similar(
            name: s.name,
            libraryId: s.id,
            albumCount: s.albumCount,
            coverArt: s.coverArt,
            imageUrl: s.imageUrl));
      }
    }
    for (final d in related ?? const []) {
      add(_Similar(name: d.name, imageUrl: d.pictureUrl));
    }
    for (final s in info?.similar ?? const []) {
      if (!s.inLibrary) add(_Similar(name: s.name, imageUrl: s.imageUrl));
    }
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ArtistSectionTitle('Fans also like'),
        // A Row in a horizontal scroll view sizes to its tallest avatar, so
        // large text never overflows a fixed height.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, item) in items.take(14).indexed) ...[
                if (i > 0) const SizedBox(width: 16),
                _SimilarAvatar(item: item),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SimilarAvatar extends StatelessWidget {
  final _Similar item;
  const _SimilarAvatar({required this.item});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final owned = item.libraryId != null;
    const size = 84.0;

    Widget image;
    if (item.imageUrl != null) {
      image = CachedNetworkImage(
        imageUrl: item.imageUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => _initials(scheme),
      );
    } else if (item.coverArt != null) {
      image = CoverArtImage(
          coverArtId: item.coverArt, size: size, borderRadius: 0);
    } else {
      image = _initials(scheme);
    }

    return SizedBox(
      width: 88,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => owned
            ? Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ArtistDetailScreen(
                    artist: Artist(
                      id: item.libraryId!,
                      name: item.name,
                      albumCount: item.albumCount,
                      coverArt: item.coverArt,
                    ),
                  ),
                ),
              )
            : _showDeezerArtist(context, item.name),
        child: Column(
          children: [
            const SizedBox(height: 2),
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: owned
                        ? null
                        : Border.all(color: scheme.outline, width: 2),
                  ),
                  padding: owned ? null : const EdgeInsets.all(3),
                  child: ClipOval(child: image),
                ),
                if (owned)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: scheme.surface, width: 3),
                      ),
                      child: Icon(Icons.check_rounded,
                          size: 14, color: scheme.onPrimary),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(fontWeight: FontWeight.w600)),
            Text(owned ? 'In library' : 'Deezer',
                style: _captionStyle(context)),
          ],
        ),
      ),
    );
  }

  Widget _initials(ColorScheme scheme) => ColoredBox(
        color: scheme.secondaryContainer,
        child: Center(
          child: Text(
            item.name.isEmpty ? '?' : item.name.characters.first.toUpperCase(),
            style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: scheme.onSecondaryContainer),
          ),
        ),
      );
}

void _showDeezerArtist(BuildContext context, String name) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      builder: (_, controller) => Consumer(
        builder: (context, ref, _) {
          final async = ref.watch(deezerArtistTracksProvider(name));
          return ListView(
            controller: controller,
            children: [
              ArtistSectionTitle(name,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8)),
              ...async.when(
                loading: () => const [
                  Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ],
                error: (e, _) => [
                  ErrorNotice(
                    title: "Couldn't load $name from Deezer",
                    error: e,
                    compact: true,
                    onRetry: () =>
                        ref.invalidate(deezerArtistIdProvider(name)),
                  ),
                ],
                data: (tracks) => tracks.isEmpty
                    ? [
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                              child: Text(
                                  'Deezer has no tracks you don\'t already have')),
                        ),
                      ]
                    : [for (final t in tracks) DeezerTrackTile(track: t)],
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// About

class AboutSection extends ConsumerWidget {
  final Artist artist;
  const AboutSection({super.key, required this.artist});

  Future<void> _open(BuildContext context, String url) async {
    final ok = await launchUrl(Uri.parse(url),
        mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      showStyledSnack(context, "Couldn't open $url", isError: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final infoAsync = ref.watch(artistInfoProvider(artist.id));
    final fans =
        ref.watch(deezerArtistProvider(artist.name)).valueOrNull?.fans;
    if (infoAsync.isLoading || isOffline(infoAsync.error)) {
      return const SizedBox.shrink();
    }
    if (infoAsync.hasError) {
      return ErrorNotice(
        title: "Couldn't load artist details",
        error: infoAsync.error,
        compact: true,
        onRetry: () => ref.invalidate(artistInfoProvider(artist.id)),
      );
    }
    final info = infoAsync.value!;
    final bio = info.biography;
    final mbid = info.musicBrainzId;
    if (bio == null && info.lastFmUrl == null && mbid == null && fans == null) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ArtistSectionTitle('About'),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          decoration: BoxDecoration(
            color: scheme.surfaceContainer,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (bio != null) ...[
                Text(bio,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyLarge?.copyWith(height: 1.45)),
                TextButton(
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => DraggableScrollableSheet(
                      expand: false,
                      initialChildSize: 0.75,
                      builder: (_, controller) => ListView(
                        controller: controller,
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                        children: [
                          Text(artist.name,
                              style: text.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 16),
                          SelectableText(bio,
                              style: text.bodyLarge?.copyWith(height: 1.5)),
                        ],
                      ),
                    ),
                  ),
                  child: const Text('Read more'),
                ),
              ],
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (info.lastFmUrl != null)
                    ActionChip(
                      avatar: const Icon(Icons.open_in_new_rounded, size: 18),
                      label: const Text('Last.fm'),
                      onPressed: () => _open(context, info.lastFmUrl!),
                    ),
                  if (mbid != null)
                    ActionChip(
                      avatar: const Icon(Icons.open_in_new_rounded, size: 18),
                      label: const Text('MusicBrainz'),
                      onPressed: () => _open(
                          context, 'https://musicbrainz.org/artist/$mbid'),
                    ),
                  if (fans != null && fans > 0)
                    Chip(
                      avatar: const Icon(Icons.group_outlined, size: 18),
                      label: Text('${compactCount(fans)} fans on Deezer'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// All songs row

class AllSongsRow extends StatelessWidget {
  final Artist artist;
  final int songCount;
  const AllSongsRow({super.key, required this.artist, required this.songCount});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Material(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          minTileHeight: 72,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          leading: Icon(Icons.queue_music_rounded, color: scheme.primary),
          title: const Text('All songs',
              style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(songCount > 0
              ? '$songCount ${songCount == 1 ? 'song' : 'songs'} · search, sort, select'
              : 'Search, sort, select'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => ArtistSongsScreen(artist: artist)),
          ),
        ),
      ),
    );
  }
}
