import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/library/artist_profile.dart';
import '../../core/models/album.dart';
import '../../core/models/artist.dart';
import '../../core/providers.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/error_notice.dart';
import 'artist/artist_actions.dart';
import 'artist/artist_discography.dart';
import 'artist/artist_portrait.dart';
import 'artist/artist_sections.dart';

/// Width from which the page splits into an identity pane and content.
const double kArtistWideBreakpoint = 900;

/// The artist profile: portrait hero, actions, your listening, popular
/// songs, latest release, discography, Deezer tracks you don't own, similar
/// artists and the biography. See docs/design.md › Artist page.
class ArtistDetailScreen extends ConsumerWidget {
  final Artist artist;
  const ArtistDetailScreen({super.key, required this.artist});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(artistInfoProvider(artist.id)).valueOrNull;
    final deezer = ref.watch(deezerArtistProvider(artist.name)).valueOrNull;
    final imageUrl = info?.imageUrl ?? deezer?.pictureUrl;
    final coverUrl = ref.watch(coverArtUrlProvider(artist.coverArt ?? ''));
    final seedUrl = imageUrl ?? coverUrl ?? '';
    final seed = seedUrl.isEmpty
        ? null
        : ref.watch(dominantColorProvider(seedUrl)).valueOrNull;
    final base = Theme.of(context);
    final theme =
        seed == null ? base : AppTheme.seeded(seed, base.brightness);

    return AnimatedTheme(
      data: theme,
      child: Builder(
        builder: (context) => Scaffold(
          body: LayoutBuilder(
            builder: (context, c) => c.maxWidth >= kArtistWideBreakpoint
                ? _WideLayout(artist: artist, imageUrl: imageUrl)
                : _PhoneLayout(artist: artist, imageUrl: imageUrl),
          ),
        ),
      ),
    );
  }
}

/// Albums, totals and the latest release, shared by both layouts.
class _ArtistData {
  final AsyncValue<List<Album>> albumsAsync;
  final List<Album> albums;
  final ArtistTotals totals;
  final Album? latest;

  _ArtistData(this.albumsAsync)
      : albums = albumsAsync.valueOrNull ?? const [],
        totals = artistTotals(albumsAsync.valueOrNull ?? const []),
        latest = latestRelease(albumsAsync.valueOrNull ?? const []);

  String get statsLine {
    if (albums.isEmpty) return '';
    final t = totals;
    return [
      '${t.releases} ${t.releases == 1 ? 'release' : 'releases'}',
      '${t.songs} ${t.songs == 1 ? 'song' : 'songs'}',
      if (t.duration > Duration.zero) formatRuntime(t.duration),
    ].join(' · ');
  }
}

Widget _albumsState(WidgetRef ref, Artist artist, _ArtistData d) {
  return d.albumsAsync.when(
    loading: () => const Padding(
      padding: EdgeInsets.all(32),
      child: Center(child: CircularProgressIndicator()),
    ),
    error: (e, _) => ErrorNotice(
      title: "Couldn't load albums",
      error: e,
      onRetry: () => ref.invalidate(artistAlbumsProvider(artist.id)),
    ),
    data: (albums) => albums.isEmpty
        ? const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('No albums')),
          )
        : const SizedBox.shrink(),
  );
}

// ---------------------------------------------------------------------------
// Phone

class _PhoneLayout extends ConsumerWidget {
  final Artist artist;
  final String? imageUrl;
  const _PhoneLayout({required this.artist, required this.imageUrl});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = _ArtistData(ref.watch(artistAlbumsProvider(artist.id)));
    return CustomScrollView(
      slivers: [
        _ArtistHero(
          artist: artist,
          imageUrl: imageUrl,
          genres: d.totals.genres,
          statsLine: d.statsLine,
        ),
        SliverList.list(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: ArtistActions(artist: artist),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
              child: ListeningCard(artist: artist),
            ),
            PopularSection(artist: artist),
            if (d.latest != null) ...[
              const ArtistSectionTitle('Latest release'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: LatestReleaseCard(album: d.latest!),
              ),
            ],
            DiscographySection(albums: d.albums),
            _albumsState(ref, artist, d),
            MissingTracksSection(artist: artist),
            SimilarArtistsSection(artist: artist),
            AboutSection(artist: artist),
            AllSongsRow(artist: artist, songCount: d.totals.songs),
            const SizedBox(height: 120),
          ],
        ),
      ],
    );
  }
}

/// Collapsing hero: blurred portrait backdrop, cookie-shaped portrait, name,
/// genre chips and totals. Collapsed, it becomes a bar with a small portrait,
/// the name, Shuffle and Play.
class _ArtistHero extends ConsumerWidget {
  final Artist artist;
  final String? imageUrl;
  final List<String> genres;
  final String statsLine;

  const _ArtistHero({
    required this.artist,
    required this.imageUrl,
    required this.genres,
    required this.statsLine,
  });

  static const _portrait = 200.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final mq = MediaQuery.of(context);
    final top = mq.padding.top;
    final nameStyle = text.displaySmall?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: -0.5,
      color: scheme.onSurface,
    );

    // Size the hero to its content: the name may wrap to two lines and the
    // text scale grows everything.
    final nameHeight = (TextPainter(
      text: TextSpan(text: artist.name, style: nameStyle),
      maxLines: 2,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      textScaler: mq.textScaler,
    )..layout(maxWidth: mq.size.width - 48))
        .height;
    final statsHeight = mq.textScaler.scale(20);
    final chipsHeight = genres.isEmpty ? 0.0 : 44.0;
    final expanded = top +
        kToolbarHeight +
        _portrait +
        16 +
        nameHeight +
        chipsHeight +
        (statsLine.isEmpty ? 0 : statsHeight + 10) +
        24;
    final collapsed = top + kToolbarHeight;

    return SliverAppBar(
      pinned: true,
      stretch: true,
      automaticallyImplyLeading: false,
      expandedHeight: expanded,
      collapsedHeight: kToolbarHeight,
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      flexibleSpace: LayoutBuilder(
        builder: (context, c) {
          final t = ((expanded - c.maxHeight) / (expanded - collapsed))
              .clamp(0.0, 1.0);
          final barVisible = t > 0.85;
          return Stack(
            fit: StackFit.expand,
            children: [
              // Backdrop: the portrait, blurred and faded into the page.
              Opacity(
                opacity: (1 - t) * 0.6,
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                  child: ArtistImage(
                    imageUrl: imageUrl,
                    coverArtId: artist.coverArt,
                    size: double.infinity,
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: (c.maxHeight * 0.42).clamp(0, double.infinity),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.vertical(
                        top: Radius.circular(48 * (1 - t))),
                  ),
                ),
              ),
              // Expanded content, anchored to the bottom so it scrolls away.
              Positioned(
                left: 24,
                right: 24,
                bottom: 24,
                child: Opacity(
                  opacity: (1 - t * 1.6).clamp(0.0, 1.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ArtistPortrait(
                        imageUrl: imageUrl,
                        coverArtId: artist.coverArt,
                        size: _portrait,
                        name: artist.name,
                      ),
                      const SizedBox(height: 16),
                      Text(artist.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: nameStyle),
                      if (genres.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Wrap(
                            spacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              for (final g in genres)
                                Chip(
                                  label: Text(g),
                                  visualDensity: VisualDensity.compact,
                                  side: BorderSide.none,
                                  backgroundColor: scheme.secondaryContainer,
                                  labelStyle: TextStyle(
                                      color: scheme.onSecondaryContainer),
                                ),
                            ],
                          ),
                        ),
                      if (statsLine.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(statsLine,
                              style: text.bodyMedium
                                  ?.copyWith(color: scheme.onSurfaceVariant)),
                        ),
                    ],
                  ),
                ),
              ),
              // Toolbar row: back always; portrait, name and play once collapsed.
              Positioned(
                left: 0,
                right: 0,
                top: top,
                height: kToolbarHeight,
                child: Row(
                  children: [
                    const SizedBox(width: 4),
                    IconButton.filledTonal(
                      tooltip: 'Back',
                      style: IconButton.styleFrom(
                        backgroundColor: barVisible
                            ? Colors.transparent
                            : scheme.surface.withValues(alpha: 0.7),
                      ),
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    Expanded(
                      child: AnimatedOpacity(
                        opacity: barVisible ? 1 : 0,
                        duration: const Duration(milliseconds: 150),
                        child: IgnorePointer(
                          ignoring: !barVisible,
                          child: Row(
                            children: [
                              const SizedBox(width: 4),
                              ArtistPortrait(
                                imageUrl: imageUrl,
                                coverArtId: artist.coverArt,
                                size: 36,
                                name: artist.name,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(artist.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: text.titleLarge?.copyWith(
                                        fontWeight: FontWeight.w700)),
                              ),
                              IconButton.filledTonal(
                                tooltip: 'Shuffle',
                                onPressed: () => playArtist(
                                    context, ref, artist,
                                    shuffle: true),
                                icon: const Icon(Icons.shuffle_rounded),
                              ),
                              IconButton.filled(
                                tooltip: 'Play',
                                onPressed: () =>
                                    playArtist(context, ref, artist),
                                icon: const Icon(Icons.play_arrow_rounded),
                              ),
                              const SizedBox(width: 8),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Desktop / wide

class _WideLayout extends ConsumerWidget {
  final Artist artist;
  final String? imageUrl;
  const _WideLayout({required this.artist, required this.imageUrl});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = _ArtistData(ref.watch(artistAlbumsProvider(artist.id)));
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final pane = SizedBox(
      width: 380,
      child: SafeArea(
        right: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton.filledTonal(
                tooltip: 'Back',
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: ArtistPortrait(
                imageUrl: imageUrl,
                coverArtId: artist.coverArt,
                size: 220,
                name: artist.name,
              ),
            ),
            const SizedBox(height: 16),
            Text(artist.name,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: text.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800, letterSpacing: -0.5)),
            if (d.totals.genres.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Wrap(
                  spacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final g in d.totals.genres)
                      Chip(
                        label: Text(g),
                        visualDensity: VisualDensity.compact,
                        side: BorderSide.none,
                        backgroundColor: scheme.secondaryContainer,
                        labelStyle:
                            TextStyle(color: scheme.onSecondaryContainer),
                      ),
                  ],
                ),
              ),
            if (d.statsLine.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(d.statsLine,
                    textAlign: TextAlign.center,
                    style: text.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant)),
              ),
            const SizedBox(height: 20),
            ArtistActions(artist: artist, height: 56),
            const SizedBox(height: 20),
            ListeningCard(artist: artist, compact: true),
          ],
        ),
      ),
    );

    final content = SafeArea(
      left: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(8, 0, 24, 120),
        children: [
          LayoutBuilder(builder: (context, c) {
            final popular = PopularSection(artist: artist, wide: true);
            if (d.latest == null) return popular;
            final latest = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const ArtistSectionTitle('Latest release'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: LatestReleaseCard(album: d.latest!, vertical: true),
                ),
              ],
            );
            if (c.maxWidth < 760) return Column(children: [popular, latest]);
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: popular),
                SizedBox(width: (c.maxWidth * 0.32).clamp(240, 340), child: latest),
              ],
            );
          }),
          DiscographySection(albums: d.albums, wide: true),
          _albumsState(ref, artist, d),
          MissingTracksSection(artist: artist),
          SimilarArtistsSection(artist: artist),
          AboutSection(artist: artist),
          AllSongsRow(artist: artist, songCount: d.totals.songs),
        ],
      ),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [pane, Expanded(child: content)],
    );
  }
}
