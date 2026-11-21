import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/subsonic_client.dart' show ServerReachability;
import '../../core/models/album.dart';
import '../../core/models/playlist.dart';
import '../../core/models/recommendations_state.dart';
import '../../core/models/song.dart';
import '../../core/providers.dart';
import '../../shared/theme/app_theme.dart';
import '../../core/errors/app_errors.dart' show describeError;
import '../../shared/widgets/cover_art_image.dart';
import '../../shared/widgets/offline_banner.dart';
import '../../shared/widgets/error_notice.dart';
import '../../shared/widgets/playlist_cover.dart';
import '../library/album_detail_screen.dart';
import '../library/playlist_detail_screen.dart';
import '../settings/downloaded_songs_screen.dart';
import '../settings/settings_screen.dart';
import '../../shared/theme/motion.dart';


// Stagger delays per section (cascading entrance).
const _kStagger0 = Duration.zero;
const _kStagger1 = Duration(milliseconds: 60);
const _kStagger2 = Duration(milliseconds: 120);
const _kStagger3 = Duration(milliseconds: 180);
const _kStagger4 = Duration(milliseconds: 240);

IconData _reachabilityIcon(ServerReachability r) {
  switch (r) {
    case ServerReachability.offline:
      return Icons.signal_wifi_off_rounded;
    case ServerReachability.unauthorized:
    case ServerReachability.forbidden:
      return Icons.lock_outline_rounded;
    case ServerReachability.tlsError:
      return Icons.gpp_bad_outlined;
    case ServerReachability.serverError:
      return Icons.error_outline_rounded;
    case ServerReachability.unreachable:
    case ServerReachability.reachable:
      return Icons.cloud_off_rounded;
  }
}

String _reachabilityMessage(ServerReachability r) {
  switch (r) {
    case ServerReachability.offline:
      return 'No internet connection';
    case ServerReachability.unauthorized:
      return 'Login rejected — update password in Settings';
    case ServerReachability.forbidden:
      return 'Access forbidden — check server permissions';
    case ServerReachability.tlsError:
      return 'Server TLS error — certificate issue';
    case ServerReachability.serverError:
      return 'Server error — tap to retry';
    case ServerReachability.unreachable:
      return 'Server not reachable — tap to retry';
    case ServerReachability.reachable:
      return '';
  }
}

const _kCardImageSize = 130.0;
// CarouselView applies its `padding` to every item, not just the first, so
// each item carries the 16 px left inset as well as the card's own 4 px on
// either side. The extent has to include both, or the cover comes out
// 114 px wide and 130 px tall and the art is cropped at the sides.
const _kCarouselItemInset = 16.0;
const _kCardExtent = _kCardImageSize + 8 + _kCarouselItemInset;

// Card titles get two lines (long album and playlist names were cut to a
// few characters on one line) and a one-line subtitle. The carousel's
// height follows the text scale, so large system fonts don't clip the
// subtitle. Card text uses an explicit line height to keep this exact.
double _carouselHeight(BuildContext context) {
  final scaler = MediaQuery.textScalerOf(context);
  const line = AppTheme.cardLineHeight;
  return _kCardImageSize +
      8 +
      scaler.scale(AppTheme.cardTitleStyle(context).fontSize!) * line * 2 +
      scaler.scale(AppTheme.cardSubtitleStyle(context).fontSize!) * line +
      2;
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(newestAlbumsProvider);
    ref.invalidate(randomSongsProvider);
    ref.invalidate(recentlyPlayedProvider);
    ref.invalidate(playlistsProvider);
    ref.invalidate(allSongsProvider);
    ref.invalidate(serverReachableProvider);
    ref.invalidate(recommendationsProvider);
    await Future.delayed(const Duration(milliseconds: 600));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final randomAsync = ref.watch(randomSongsProvider);
    final recentAsync = ref.watch(recentlyPlayedProvider);
    final newestAsync = ref.watch(newestAlbumsProvider);
    final playlistsAsync = ref.watch(playlistsProvider);
    final recsAsync = ref.watch(recommendationsProvider);
    final username = ref.watch(serverConfigProvider).valueOrNull?.username;
    final isOnline = ref.watch(isOnlineProvider).valueOrNull ?? true;
    final reachability = ref.watch(serverReachableProvider).valueOrNull ??
        ServerReachability.reachable;
    final arlStatus = ref.watch(deezerArlStatusProvider).valueOrNull;
    final downloaded =
        ref.watch(downloadedSongsProvider).valueOrNull ?? const <Song>[];
    final scheme = Theme.of(context).colorScheme;
    // When the device is offline or the server unreachable, the banners at
    // the top already explain why sections are missing; otherwise a failed
    // section shows its own error instead of silently disappearing.
    final serverDown =
        !isOnline || reachability != ServerReachability.reachable;
    Widget sectionError(String title, Object error, ProviderOrFamily p) =>
        SliverToBoxAdapter(
          child: serverDown
              ? const SizedBox.shrink()
              : ErrorNotice(
                  title: title,
                  error: error,
                  compact: true,
                  onRetry: () => ref.invalidate(p),
                ),
        );

    return SafeArea(
      top: false,
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Offline banner + inline greeting (replaces SliverAppBar.medium
            // to avoid the large empty band above the bottom-aligned title on
            // phones). The banner sits inside the safe area, below the status
            // bar, like on the Search and Library tabs.
            SliverToBoxAdapter(
              child: SafeArea(
                top: true,
                bottom: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const OfflineBanner(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Text(
                        _greeting(username),
                        style: AppTheme.pageTitleStyle(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Deezer ARL status banner — only show when we *confirmed*
            // the ARL is rejected (not when we simply can't reach Deezer).
            // "Can't reach Deezer" is left out while the device is offline:
            // the offline banner already says why.
            if (arlStatus == DeezerArlStatus.invalid)
              const SliverToBoxAdapter(child: _DeezerExpiredBanner())
            else if (arlStatus == DeezerArlStatus.unreachable && isOnline)
              const SliverToBoxAdapter(child: _DeezerUnreachableBanner()),

            // Server status — specific message per failure mode.
            if (isOnline && reachability != ServerReachability.reachable)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: ActionChip(
                      avatar: Icon(_reachabilityIcon(reachability),
                          size: 16, color: scheme.onSurfaceVariant),
                      label: Text(_reachabilityMessage(reachability)),
                      onPressed: () => _refresh(ref),
                    ),
                  ),
                ),
              ),

            // Without the server, lead with what can still play: the
            // downloaded songs.
            if (serverDown && downloaded.isNotEmpty)
              SliverToBoxAdapter(
                child: _fadeIn(
                  delay: _kStagger0,
                  child: _Section(
                    title: 'Downloaded',
                    trailing: TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DownloadedSongsScreen(),
                        ),
                      ),
                      child: const Text('See all'),
                    ),
                    child: SizedBox(
                      height: _carouselHeight(context),
                      child: _buildCarousel(
                        context: context,
                        onItemTap: (i) => _playSongs(ref, downloaded, i),
                        children: [
                          for (final s in downloaded) _SongCard(song: s),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // Playlists
            playlistsAsync.when(
              skipLoadingOnRefresh: true,
              loading: () =>
                  const SliverToBoxAdapter(child: SizedBox.shrink()),
              error: (e, _) =>
                  sectionError("Couldn't load playlists", e, playlistsProvider),
              data: (playlists) {
                if (playlists.isEmpty) {
                  return const SliverToBoxAdapter(child: SizedBox.shrink());
                }
                return SliverToBoxAdapter(
                  child: _fadeIn(
                    delay: _kStagger0,
                    child: _Section(
                      title: 'Playlists',
                      child: SizedBox(
                        height: _carouselHeight(context),
                        child: _buildCarousel(
                          context: context,
                          onItemTap: (i) => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PlaylistDetailScreen(
                                  playlist: playlists[i]),
                            ),
                          ),
                          children: [
                            for (final p in playlists) _PlaylistCard(playlist: p),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            // Newly added albums
            newestAsync.when(
              skipLoadingOnRefresh: true,
              skipError: true,
              loading: () =>
                  const SliverToBoxAdapter(child: SizedBox.shrink()),
              error: (e, _) => sectionError(
                  "Couldn't load recently added albums", e, newestAlbumsProvider),
              data: (albums) {
                if (albums.isEmpty) {
                  return const SliverToBoxAdapter(child: SizedBox.shrink());
                }
                return SliverToBoxAdapter(
                  child: _fadeIn(
                    delay: _kStagger1,
                    child: _Section(
                      title: 'Recently Added',
                      child: SizedBox(
                        height: _carouselHeight(context),
                        child: _buildCarousel(
                          context: context,
                          onItemTap: (i) => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AlbumDetailScreen(album: albums[i]),
                            ),
                          ),
                          children: [
                            for (final album in albums)
                              _AlbumCard(
                                album: album,
                                onTap: () => Navigator.of(context, rootNavigator: true).push(
                                  MaterialPageRoute(
                                    builder: (_) => AlbumDetailScreen(album: album),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            // Discover — random songs
            randomAsync.when(
              skipLoadingOnRefresh: true,
              skipError: true,
              loading: () => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (e, _) => sectionError(
                  "Couldn't load songs from the server", e, randomSongsProvider),
              data: (songs) => SliverToBoxAdapter(
                child: _fadeIn(
                  delay: _kStagger2,
                  child: _Section(
                    title: 'Discover',
                    child: SizedBox(
                      height: _carouselHeight(context),
                      child: _buildCarousel(
                        context: context,
                        onItemTap: (i) => _playSongs(ref, songs, i),
                        children: [
                          for (final s in songs) _SongCard(song: s),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Recommended for You. Deezer needs the internet, so the section
            // waits offline instead of showing a failure under the banner.
            if (isOnline) _buildRecsSection(context, ref, recsAsync),

            // Recently played
            recentAsync.when(
              skipLoadingOnRefresh: true,
              loading: () =>
                  const SliverToBoxAdapter(child: SizedBox.shrink()),
              // Local history: a failure here is a database problem, never
              // a connectivity one, so it is always shown.
              error: (e, _) => SliverToBoxAdapter(
                child: ErrorNotice(
                  title: "Couldn't read play history",
                  error: e,
                  compact: true,
                  onRetry: () => ref.invalidate(recentlyPlayedProvider),
                ),
              ),
              data: (songs) {
                if (songs.isEmpty) {
                  return const SliverToBoxAdapter(child: SizedBox.shrink());
                }
                return SliverToBoxAdapter(
                  child: _fadeIn(
                    delay: _kStagger4,
                    child: _Section(
                      title: 'Recently Played',
                      child: SizedBox(
                        height: _carouselHeight(context),
                        child: _buildCarousel(
                          context: context,
                          onItemTap: (i) => _playSongs(ref, songs, i),
                          children: [
                            for (final s in songs) _SongCard(song: s),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            SliverPadding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.paddingOf(context).bottom + 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _playSongs(WidgetRef ref, List<Song> songs, int index) {
    ref.read(audioHandlerNotifierProvider)?.loadQueue(songs, startIndex: index);
  }

  // CarouselView.onTap avoids gesture conflicts with nested InkWells.
  static Widget _buildCarousel({
    required BuildContext context,
    required List<Widget> children,
    void Function(int)? onItemTap,
  }) {
    // Hide horizontal scrollbar on desktop — RawScrollbar looks broken on snap carousels.
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: CarouselView(
        itemExtent: _kCardExtent,
        itemSnapping: true,
        shrinkExtent: 40,
        padding: const EdgeInsets.only(left: _kCarouselItemInset),
        backgroundColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(),
        // No splash: CarouselView would lay its InkWell over the whole
        // card, above the ⋮ button, so tapping ⋮ played the song instead of
        // opening the menu. Without it, taps go through a GestureDetector
        // that loses to the button's own InkWell.
        enableSplash: false,
        onTap: onItemTap,
        children: children,
      ),
    );
  }

  // M3E emphasized-decelerate entrance with staggered delay per section.
  static Widget _fadeIn({required Widget child, Duration delay = Duration.zero}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Motion.enter.duration + delay,
      curve: Interval(
        delay.inMilliseconds / (Motion.enter.duration + delay).inMilliseconds,
        1.0,
        curve: Motion.enter.curve,
      ),
      builder: (_, value, ch) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - value)),
          child: ch,
        ),
      ),
      child: child,
    );
  }

  Widget _buildRecsSection(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<RecommendationsState> recsAsync,
  ) {
    void refresh() {
      ref.invalidate(recommendationsProvider);
    }

    return recsAsync.when(
      skipLoadingOnRefresh: true,
      loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
      error: (e, __) => SliverToBoxAdapter(
        child: _Section(
          title: 'Recommended for You',
          trailing: IconButton.filledTonal(
            tooltip: 'Retry',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: refresh,
          ),
          child: _RecsInlineError(
            message: "Recommendations failed to load: ${describeError(e)}",
            onRetry: refresh,
          ),
        ),
      ),
      data: (state) {
        switch (state) {
          case RecsLoading():
            return const SliverToBoxAdapter(child: SizedBox.shrink());
          case RecsEmptyNoHistory():
            return const SliverToBoxAdapter(
              child: _Section(
                title: 'Recommended for You',
                child: _RecsEmptyHint(),
              ),
            );
          case RecsError(reason: final reason):
            return SliverToBoxAdapter(
              child: _Section(
                title: 'Recommended for You',
                trailing: IconButton.filledTonal(
                  tooltip: 'Retry',
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: refresh,
                ),
                child: _RecsInlineError(message: reason, onRetry: refresh),
              ),
            );
          case RecsReady(
              songs: final all,
              failedSeeds: final failedSeeds,
            ):
            // "Not interested" takes the card out at once (and Undo brings
            // it back) without rebuilding the list.
            final dismissedAsync = ref.watch(dismissedRecsProvider);
            if (dismissedAsync.hasError) {
              return SliverToBoxAdapter(
                child: _Section(
                  title: 'Recommended for You',
                  child: _RecsInlineError(
                    message: "Couldn't read your hidden recommendations: "
                        '${describeError(dismissedAsync.error!)}',
                    onRetry: () => ref.invalidate(dismissedRecsProvider),
                  ),
                ),
              );
            }
            final dismissed = dismissedAsync.valueOrNull ?? const [];
            final songs = [
              for (final s in all)
                if (!isDismissed(s, dismissed)) s
            ];
            if (songs.isEmpty) {
              return SliverToBoxAdapter(
                child: _Section(
                  title: 'Recommended for You',
                  trailing: IconButton.filledTonal(
                    tooltip: 'Refresh recommendations',
                    icon: const Icon(Icons.refresh_rounded),
                    onPressed: refresh,
                  ),
                  child: const _RecsNote(
                      'You hid everything in this list. Refresh for new '
                      'suggestions.'),
                ),
              );
            }
            return SliverToBoxAdapter(
              child: _fadeIn(
                delay: _kStagger3,
                child: _Section(
                  title: 'Recommended for You',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Starts the whole list, for listening to it as a
                      // radio; tapping a card starts from that card.
                      FilledButton.tonalIcon(
                        onPressed: () => ref
                            .read(audioHandlerNotifierProvider)
                            ?.loadQueue(songs, startIndex: 0),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Play'),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        tooltip: 'Refresh recommendations',
                        icon: const Icon(Icons.refresh_rounded),
                        onPressed: refresh,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: _carouselHeight(context),
                        child: _buildCarousel(
                          context: context,
                          onItemTap: (i) => ref
                              .read(audioHandlerNotifierProvider)
                              ?.loadQueue(songs, startIndex: i),
                          children: [
                            // Same card as every other row: why it was
                            // picked, like and "Not interested" live in
                            // the player.
                            for (final s in songs)
                              _SongCard(key: ValueKey(s.id), song: s),
                          ],
                        ),
                      ),
                      if (failedSeeds.isNotEmpty)
                        _RecsNote(_failedSeedsNote(failedSeeds)),
                    ],
                  ),
                ),
              ),
            );
        }
      },
    );
  }

  static String _failedSeedsNote(List<String> seeds) {
    final names = seeds.length <= 3
        ? seeds.join(', ')
        : '${seeds.take(3).join(', ')} and ${seeds.length - 3} more';
    return "Couldn't load suggestions based on $names from Deezer, so this "
        'list is shorter. Refresh to try again.';
  }

  String _greeting(String? username) {
    final h = DateTime.now().hour;
    final String base;
    if (h >= 5 && h < 12) {
      base = 'Good morning';
    } else if (h < 17) {
      base = 'Good afternoon';
    } else if (h < 21) {
      base = 'Good evening';
    } else {
      base = 'Good night';
    }
    final isEmail = username != null && username.contains('@');
    return (username != null && !isEmail) ? '$base, $username' : base;
  }
}

// ---------------------------------------------------------------------------

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;

  const _Section({required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          // 16 on both sides: the trailing refresh button is a filled tonal
          // circle, so its visible edge has to line up with the content.
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppTheme.emphasized(context).titleLarge,
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
        child,
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Cards have no own tap handler — CarouselView.onTap handles gestures.
// ---------------------------------------------------------------------------

class _SongCard extends ConsumerWidget {
  final Song song;
  const _SongCard({super.key, required this.song});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fixed height, not AspectRatio(1): CarouselView squeezes the
          // item at the edge, and a square cover would shrink with it and
          // lift that card's title above its neighbours'.
          SizedBox(
            height: _kCardImageSize,
            width: double.infinity,
            child: CoverArtImage(
              coverArtId: song.coverArt,
              // A Deezer recommendation has only a cover URL.
              externalUrl: song.externalCoverUrl,
              // Lets a downloaded song show its saved cover offline.
              songId: song.id,
              size: _kCardImageSize,
              borderRadius: 12,
            ),
          ),
          const SizedBox(height: 8),
          Text(song.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.cardTitleStyle(context)),
          Text(song.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.cardSubtitleStyle(context)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _AlbumCard extends ConsumerWidget {
  final Album album;
  final VoidCallback? onTap;
  const _AlbumCard({required this.album, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget child = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fixed height, not AspectRatio(1): CarouselView squeezes the
          // item at the edge, and a square cover would shrink with it and
          // lift that card's title above its neighbours'.
          SizedBox(
            height: _kCardImageSize,
            width: double.infinity,
            child: CoverArtImage(
              coverArtId: album.coverArt,
              size: _kCardImageSize,
              borderRadius: 12,
            ),
          ),
          const SizedBox(height: 8),
          Text(album.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.cardTitleStyle(context)),
          Text(album.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.cardSubtitleStyle(context)),
        ],
      ),
    );
    if (onTap != null) {
      child = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: child,
      );
    }
    return child;
  }
}

// ---------------------------------------------------------------------------

class _PlaylistCard extends ConsumerWidget {
  final Playlist playlist;
  const _PlaylistCard({required this.playlist});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fixed height, not AspectRatio(1): CarouselView squeezes the
          // item at the edge, and a square cover would shrink with it and
          // lift that card's title above its neighbours'.
          SizedBox(
            height: _kCardImageSize,
            width: double.infinity,
            child: PlaylistCover(
              playlist: playlist,
              size: _kCardImageSize,
              borderRadius: 12,
            ),
          ),
          const SizedBox(height: 8),
          Text(playlist.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.cardTitleStyle(context)),
          Text(
              '${playlist.songCount} '
              '${playlist.songCount == 1 ? 'song' : 'songs'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.cardSubtitleStyle(context)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

/// A quiet one-line note under the recommendations (not an error).
class _RecsNote extends StatelessWidget {
  final String text;
  const _RecsNote(this.text);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded,
              size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _RecsInlineError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _RecsInlineError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded,
                size: 18, color: scheme.onErrorContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onErrorContainer)),
            ),
            TextButton(
              style: TextButton.styleFrom(
                  foregroundColor: scheme.onErrorContainer),
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeezerExpiredBanner extends StatelessWidget {
  const _DeezerExpiredBanner();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Material(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.error_rounded, color: scheme.onErrorContainer),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Deezer session expired',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: scheme.onErrorContainer)),
                      Text(
                          'Paste a fresh ARL in Settings to re-enable server downloads.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onErrorContainer)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: scheme.onErrorContainer),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DeezerUnreachableBanner extends StatelessWidget {
  const _DeezerUnreachableBanner();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Material(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.wifi_off_rounded,
                  size: 20, color: scheme.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Can\'t reach Deezer to verify your session — server downloads may still work.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecsEmptyHint extends StatelessWidget {
  const _RecsEmptyHint();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(Icons.auto_awesome_rounded,
                size: 18, color: scheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Play a few songs — recommendations appear after some listening history.',
                style:
                    Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
