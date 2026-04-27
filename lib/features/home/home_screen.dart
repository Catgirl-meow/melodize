import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/subsonic_client.dart' show ServerReachability;
import '../../core/models/album.dart';
import '../../core/models/recommendations_state.dart';
import '../../core/models/song.dart';
import '../../core/providers.dart';
import '../../shared/utils/download_polling_mixin.dart';
import '../../shared/utils/snack.dart';
import '../../shared/widgets/cover_art_image.dart';
import '../../shared/widgets/offline_banner.dart';
import '../library/album_detail_screen.dart';
import '../library/playlist_detail_screen.dart';
import '../settings/settings_screen.dart';

// M3 Expressive motion tokens.
const _kEmphasizedDecelerate = Cubic(0.05, 0.7, 0.1, 1.0);
const _kEmphasizedDuration = Duration(milliseconds: 400);

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

// Carousel geometry matching pre-v1.9.0 proportions — image is explicit
// 130×130 in a column with text below; carousel height = 176 to fit.
const _kCardExtent = 138.0;     // CarouselView itemExtent (image 130 + 2×4 padding)
const _kCardImageSize = 130.0;  // explicit square — CoverArtImage(size: 130) → 130×130
const _kCarouselHeight = 176.0; // image 130 + gap 8 + title 16 + artist 14 + slack 8

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    // Clear any active "More like this" seed override — otherwise the override
    // persists through pull-to-refresh and re-triggers the same single-seed
    // run (which errors out if that artist can't be resolved on Deezer).
    ref.read(recommendationsSeedOverrideProvider.notifier).state = null;
    ref.invalidate(newestAlbumsProvider);
    ref.invalidate(randomSongsProvider);
    ref.invalidate(recentlyPlayedProvider);
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
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Offline banner — before the app bar so it shows at the absolute
            // top edge; AnimatedSize makes it zero-height when online.
            const SliverToBoxAdapter(child: OfflineBanner()),

            // M3E collapsing greeting — medium app bar collapses on scroll.
            // Pass only fontWeight; size/letterSpacing come from the framework's
            // variant-aware ScrollUnderFlexibleSpace so expanded → collapsed
            // interpolates correctly without clipping.
            SliverAppBar.medium(
              automaticallyImplyLeading: false,
              scrolledUnderElevation: 0,
              title: Text(
                _greeting(username),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),

            // Deezer ARL expiry banner
            if (arlStatus == DeezerArlStatus.invalid)
              const SliverToBoxAdapter(child: _DeezerExpiredBanner()),

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

            // Playlists
            playlistsAsync.when(
              skipLoadingOnRefresh: true,
              loading: () =>
                  const SliverToBoxAdapter(child: SizedBox.shrink()),
              error: (_, __) =>
                  const SliverToBoxAdapter(child: SizedBox.shrink()),
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
                        height: _kCarouselHeight,
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
              error: (_, __) =>
                  const SliverToBoxAdapter(child: SizedBox.shrink()),
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
                        height: _kCarouselHeight,
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
                              _AlbumCard(album: album),
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
              error: (_, __) => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.wifi_off_rounded,
                            size: 48, color: scheme.onSurfaceVariant),
                        const SizedBox(height: 8),
                        Text('Could not connect to server',
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                ),
              ),
              data: (songs) => SliverToBoxAdapter(
                child: _fadeIn(
                  delay: _kStagger2,
                  child: _Section(
                    title: 'Discover',
                    child: SizedBox(
                      height: _kCarouselHeight,
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

            // Recommended for You
            _buildRecsSection(context, ref, recsAsync),

            // Recently played
            recentAsync.when(
              skipLoadingOnRefresh: true,
              loading: () =>
                  const SliverToBoxAdapter(child: SizedBox.shrink()),
              error: (_, __) =>
                  const SliverToBoxAdapter(child: SizedBox.shrink()),
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
                        height: _kCarouselHeight,
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

  // Taps are handled at the carousel level (onItemTap) rather than inside
  // individual card widgets. This avoids tap-interception conflicts between
  // CarouselView's own gesture layer and nested InkWells.
  static Widget _buildCarousel({
    required BuildContext context,
    required List<Widget> children,
    void Function(int)? onItemTap,
  }) {
    // Scope a no-scrollbar ScrollConfiguration around the carousel: the base
    // ScrollBehavior adds a RawScrollbar on desktop for ALL axes, which on a
    // horizontal snap-carousel renders as a misaligned line through the cards.
    // Vertical scrollbars elsewhere in the app are unaffected.
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: CarouselView(
        itemExtent: _kCardExtent,
        itemSnapping: true,
        shrinkExtent: 40,
        padding: const EdgeInsets.only(left: 16),
        backgroundColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(),
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        onTap: onItemTap,
        children: children,
      ),
    );
  }

  // Fade + upward slide on first build — M3E "emphasized decelerate" entrance.
  // [delay] staggers sections so they cascade in rather than all at once.
  static Widget _fadeIn({required Widget child, Duration delay = Duration.zero}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: _kEmphasizedDuration + delay,
      curve: Interval(
        delay.inMilliseconds / (_kEmphasizedDuration + delay).inMilliseconds,
        1.0,
        curve: _kEmphasizedDecelerate,
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
      ref.read(recommendationsSeedOverrideProvider.notifier).state = null;
      ref.invalidate(recommendationsProvider);
    }

    return recsAsync.when(
      skipLoadingOnRefresh: true,
      loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
      error: (_, __) => SliverToBoxAdapter(
        child: _Section(
          title: 'Recommended for You',
          trailing: IconButton.filledTonal(
            tooltip: 'Retry',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: refresh,
          ),
          child: _RecsInlineError(
            message: 'Recommendations failed to load.',
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
          case RecsReady(songs: final songs):
            return SliverToBoxAdapter(
              child: _fadeIn(
                delay: _kStagger3,
                child: _Section(
                  title: 'Recommended for You',
                  trailing: IconButton.filledTonal(
                    tooltip: 'Refresh recommendations',
                    icon: const Icon(Icons.refresh_rounded),
                    onPressed: refresh,
                  ),
                  child: SizedBox(
                    height: _kCarouselHeight,
                    child: _buildCarousel(
                      context: context,
                      onItemTap: (i) => ref
                          .read(audioHandlerNotifierProvider)
                          ?.loadQueue(songs, startIndex: i),
                      children: [
                        for (final s in songs) _RecommendationCard(song: s),
                      ],
                    ),
                  ),
                ),
              ),
            );
        }
      },
    );
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
          padding: const EdgeInsets.fromLTRB(16, 24, 8, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
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
// Card widgets — intentionally no InkWell / tap handler of their own.
// CarouselView.onTap handles all taps at the carousel level to avoid
// gesture conflicts with the carousel's own scroll/snap recogniser.
// Layout mirrors pre-v1.9.0: explicit square image + title/artist below.
// ---------------------------------------------------------------------------

class _SongCard extends ConsumerWidget {
  final Song song;
  const _SongCard({required this.song});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: CoverArtImage(
              coverArtId: song.coverArt,
              size: _kCardImageSize,
              borderRadius: 12,
            ),
          ),
          const SizedBox(height: 8),
          Text(song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          Text(song.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _AlbumCard extends ConsumerWidget {
  final Album album;
  const _AlbumCard({required this.album});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: CoverArtImage(
              coverArtId: album.coverArt,
              size: _kCardImageSize,
              borderRadius: 12,
            ),
          ),
          const SizedBox(height: 8),
          Text(album.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          Text(album.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _PlaylistCard extends ConsumerWidget {
  final dynamic playlist;
  const _PlaylistCard({required this.playlist});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: CoverArtImage(
              coverArtId: playlist.coverArt as String?,
              size: _kCardImageSize,
              borderRadius: 12,
            ),
          ),
          const SizedBox(height: 6),
          Text(playlist.name as String,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          Text('${playlist.songCount} songs',
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

// Recommendation card — only handles the 3-dot context menu.
// Play is triggered via CarouselView.onTap at the carousel level.
class _RecommendationCard extends ConsumerStatefulWidget {
  final Song song;
  const _RecommendationCard({required this.song});

  @override
  ConsumerState<_RecommendationCard> createState() =>
      _RecommendationCardState();
}

class _RecommendationCardState extends ConsumerState<_RecommendationCard>
    with DownloadPollingMixin {
  Future<void> _addToLibrary() async {
    final companion = ref.read(companionClientProvider);
    if (companion == null) {
      showStyledSnack(context,
          'Companion not configured — set it up in Settings',
          isError: true);
      return;
    }
    final prefs = ref.read(preferencesNotifierProvider);
    if (!prefs.hasDeezerArl) {
      showStyledSnack(context,
          'Add Deezer ARL in Settings — required for server downloads',
          isError: true);
      return;
    }
    final arlStatus = ref.read(deezerArlStatusProvider).valueOrNull;
    if (arlStatus == DeezerArlStatus.invalid) {
      showStyledSnack(context,
          'Deezer session expired — update ARL in Settings',
          isError: true);
      return;
    }
    final deezerTrackId = widget.song.id.substring('deezer:'.length);
    final url = 'https://www.deezer.com/track/$deezerTrackId';
    showStyledSnack(context, 'Sending to server (FLAC)…');
    try {
      final jobId =
          await companion.startDownload(url, deezerArl: prefs.deezerArl);
      if (!mounted) return;
      startDownloadPolling(companion, jobId);
    } catch (e) {
      if (!mounted) return;
      showStyledSnack(context, 'Could not start download: $e', isError: true);
    }
  }

  void _moreLikeThis() {
    ref.read(recommendationsSeedOverrideProvider.notifier).state = (
      artist: widget.song.artist,
      title: widget.song.title,
      genre: null,
    );
    ref.invalidate(recommendationsProvider);
  }

  void _openMenu() {
    final canDownload = ref.read(canDeleteFromServerProvider);
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Song header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: widget.song.externalCoverUrl != null
                        ? CachedNetworkImage(
                            imageUrl: widget.song.externalCoverUrl!,
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                          )
                        : Consumer(
                            builder: (_, ref, __) => CoverArtImage(
                              coverArtId: widget.song.coverArt,
                              size: 44,
                              borderRadius: 6,
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(ctx).textTheme.titleSmall),
                        Text(widget.song.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                )),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: scheme.outlineVariant),
            const SizedBox(height: 4),
            if (canDownload)
              ListTile(
                leading: const Icon(Icons.library_add_rounded),
                title: const Text('Add to library'),
                subtitle: const Text('Download to Navidrome server'),
                onTap: () {
                  Navigator.pop(ctx);
                  _addToLibrary();
                },
              ),
            ListTile(
              leading: const Icon(Icons.auto_awesome_rounded),
              title: const Text('More like this'),
              subtitle: const Text('Rebuild recommendations from this track'),
              onTap: () {
                Navigator.pop(ctx);
                _moreLikeThis();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isPreview = widget.song.externalStreamUrl != null;

    Widget cover;
    if (widget.song.externalCoverUrl != null) {
      cover = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: widget.song.externalCoverUrl!,
          width: _kCardImageSize,
          height: _kCardImageSize,
          fit: BoxFit.cover,
          placeholder: (_, __) => _coverPlaceholder(scheme),
          errorWidget: (_, __, ___) => _coverPlaceholder(scheme),
        ),
      );
    } else {
      cover = CoverArtImage(
        coverArtId: widget.song.coverArt,
        size: _kCardImageSize,
        borderRadius: 12,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Stack(
              fit: StackFit.expand,
              children: [
              cover,
              if (isPreview)
                Positioned(
                  bottom: 6,
                  left: 6,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: scheme.inverseSurface,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'PREVIEW',
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: scheme.onInverseSurface),
                      ),
                    ),
                  ),
                ),
              // 3-dot button — has its own Material so its InkWell wins
              // the gesture arena when tapped, preventing CarouselView.onTap
              // from firing a play action for a menu tap.
              Positioned(
                top: 2,
                right: 2,
                child: Material(
                  color: Colors.black38,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _openMenu,
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.more_vert_rounded,
                          size: 18, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
            ),
          ),
          const SizedBox(height: 8),
          Text(widget.song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          Text(widget.song.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _coverPlaceholder(ColorScheme scheme) => ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: _kCardImageSize,
          height: _kCardImageSize,
          color: scheme.surfaceContainerHigh,
          child: Icon(Icons.music_note_rounded,
              size: 52, color: scheme.onSurfaceVariant),
        ),
      );
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
                  style: TextStyle(
                      fontSize: 13, color: scheme.onErrorContainer)),
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
                          style: TextStyle(
                              fontSize: 12,
                              color: scheme.onErrorContainer)),
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
                    TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
