import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

// M3 Expressive emphasized-decelerate curve (entrance motion spec).
const _kEmphasizedDecelerate = Cubic(0.05, 0.7, 0.1, 1.0);
const _kEmphasizedDuration = Duration(milliseconds: 350);

// Uniform horizontal-carousel geometry — all rows use the same card width,
// image size, and row height so the page feels visually consistent.
const _kCardExtent = 160.0;     // CarouselView itemExtent
const _kCardImageSize = 152.0;  // image width (160 – 2×4 px side padding)
const _kCarouselHeight = 200.0; // SizedBox height wrapping each CarouselView

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
    final serverReachable =
        ref.watch(serverReachableProvider).valueOrNull ?? true;
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

            // Collapsing large app bar (M3E recommended pattern for home
            // screens). The greeting is the expanded title; it collapses to
            // a smaller toolbar-height version on scroll.
            SliverAppBar.large(
              pinned: true,
              floating: false,
              automaticallyImplyLeading: false,
              scrolledUnderElevation: 0,
              surfaceTintColor: scheme.surfaceContainer,
              title: Text(_greeting(username)),
            ),

            // Deezer ARL expiry banner — appears only when ARL is set but
            // Deezer's own /getUserData returned USER_ID=0.
            if (arlStatus == DeezerArlStatus.invalid)
              const SliverToBoxAdapter(child: _DeezerExpiredBanner()),

            // Server unreachable — AssistChip gives the status a proper M3
            // interactive component with a built-in retry affordance.
            if (isOnline && !serverReachable)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: ActionChip(
                      avatar: Icon(Icons.cloud_off_rounded,
                          size: 16, color: scheme.onSurfaceVariant),
                      label: const Text('Server unreachable — tap to retry'),
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
                    child: _Section(
                      title: 'Playlists',
                      child: SizedBox(
                        height: _kCarouselHeight,
                        child: _buildCarousel(children: [
                          for (final p in playlists)
                            _PlaylistCard(
                              playlist: p,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      PlaylistDetailScreen(playlist: p),
                                ),
                              ),
                            ),
                        ]),
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
                    child: _Section(
                      title: 'Recently Added',
                      child: SizedBox(
                        height: _kCarouselHeight,
                        child: _buildCarousel(children: [
                          for (final album in albums)
                            _AlbumCard(
                              album: album,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      AlbumDetailScreen(album: album),
                                ),
                              ),
                            ),
                        ]),
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
                            size: 48,
                            color: scheme.onSurfaceVariant),
                        const SizedBox(height: 8),
                        Text(
                          'Could not connect to server',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              data: (songs) => SliverToBoxAdapter(
                child: _fadeIn(
                  child: _Section(
                    title: 'Discover',
                    child: SizedBox(
                      height: _kCarouselHeight,
                      child: _buildCarousel(children: [
                        for (int i = 0; i < songs.length; i++)
                          _SongCard(
                            song: songs[i],
                            onTap: () => _playSongs(ref, songs, i),
                          ),
                      ]),
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
                    child: _Section(
                      title: 'Recently Played',
                      child: SizedBox(
                        height: _kCarouselHeight,
                        child: _buildCarousel(children: [
                          for (int i = 0; i < songs.length; i++)
                            _SongCard(
                              song: songs[i],
                              onTap: () => _playSongs(ref, songs, i),
                            ),
                        ]),
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

  // Shared CarouselView factory — all home-screen horizontal rows use the same
  // snap / shrink / padding / transparency configuration.
  static Widget _buildCarousel({required List<Widget> children}) {
    return CarouselView(
      itemExtent: _kCardExtent,
      itemSnapping: true,
      shrinkExtent: 40,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      backgroundColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(),
      overlayColor: WidgetStateProperty.all(Colors.transparent),
      children: children,
    );
  }

  // Fade + upward slide on first build — M3E "emphasized decelerate" entrance.
  // Plays once when a section's AsyncValue first transitions to .data.
  static Widget _fadeIn({required Widget child}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: _kEmphasizedDuration,
      curve: _kEmphasizedDecelerate,
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
      // Clear any active "More like this" override so the refresh falls
      // back to history-based seeds instead of re-running the same single
      // seed the user clicked earlier.
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
                child: _Section(
                  title: 'Recommended for You',
                  trailing: IconButton.filledTonal(
                    tooltip: 'Refresh recommendations',
                    icon: const Icon(Icons.refresh_rounded),
                    onPressed: refresh,
                  ),
                  child: SizedBox(
                    height: _kCarouselHeight,
                    child: _buildCarousel(children: [
                      for (int i = 0; i < songs.length; i++)
                        _RecommendationCard(
                          song: songs[i],
                          queue: songs,
                          index: i,
                        ),
                    ]),
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
                        letterSpacing: -0.1,
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

class _SongCard extends ConsumerWidget {
  final Song song;
  final VoidCallback onTap;
  const _SongCard({required this.song, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CoverArtImage(
                coverArtId: song.coverArt,
                size: _kCardImageSize,
                borderRadius: 12),
            const SizedBox(height: 8),
            Text(song.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
            Text(song.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12, color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _AlbumCard extends ConsumerWidget {
  final Album album;
  final VoidCallback onTap;
  const _AlbumCard({required this.album, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CoverArtImage(
                coverArtId: album.coverArt,
                size: _kCardImageSize,
                borderRadius: 12),
            const SizedBox(height: 8),
            Text(album.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
            Text(album.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12, color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _PlaylistCard extends ConsumerWidget {
  final dynamic playlist;
  final VoidCallback onTap;
  const _PlaylistCard({required this.playlist, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CoverArtImage(
                coverArtId: playlist.coverArt as String?,
                size: _kCardImageSize,
                borderRadius: 12),
            const SizedBox(height: 6),
            Text(playlist.name as String,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600)),
            Text('${playlist.songCount} songs',
                style: TextStyle(
                    fontSize: 11, color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _RecommendationCard extends ConsumerStatefulWidget {
  final Song song;
  // Full recommendations list so tapping this card starts sequential
  // playback of the whole row; shuffle / loop in the player then operate
  // over every recommendation, not the single tapped track.
  final List<Song> queue;
  final int index;
  const _RecommendationCard({
    required this.song,
    required this.queue,
    required this.index,
  });

  @override
  ConsumerState<_RecommendationCard> createState() =>
      _RecommendationCardState();
}

class _RecommendationCardState extends ConsumerState<_RecommendationCard>
    with DownloadPollingMixin {
  void _play() {
    ref
        .read(audioHandlerNotifierProvider)
        ?.loadQueue(widget.queue, startIndex: widget.index);
  }

  Future<void> _addToLibrary() async {
    debugPrint('[rec] _addToLibrary for ${widget.song.id} "${widget.song.title}"');
    final companion = ref.read(companionClientProvider);
    if (companion == null) {
      showStyledSnack(context,
          'Companion not configured — set it up in Settings',
          isError: true);
      return;
    }
    final prefs = ref.read(preferencesNotifierProvider);
    // Deemix fails hard without a valid ARL — preflight here so the user
    // gets an actionable message instead of a "Download failed: Aborted!"
    // snack five seconds later from the server-side polling path.
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
      // Deezer-sourced song — no library genre to bias the search with.
      genre: null,
    );
    ref.invalidate(recommendationsProvider);
  }

  void _openMenu() {
    final canDownload = ref.read(canDeleteFromServerProvider);
    debugPrint('[rec] _openMenu canDownload=$canDownload song=${widget.song.id}');
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
                        Text(
                          widget.song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(ctx).textTheme.titleSmall,
                        ),
                        Text(
                          widget.song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, indent: 16, endIndent: 16,
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

    // Two separate tap zones (cover + text block) instead of one outer
    // InkWell wrapping the 3-dot button. Nested InkWells inside a Stack
    // were swallowing the 3-dot tap and routing it to _play, so the
    // menu never opened and companion downloads never fired.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _play,
                child: cover,
              ),
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
          const SizedBox(height: 8),
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: _play,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                Text(widget.song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
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
              size: 60, color: scheme.onSurfaceVariant),
        ),
      );
}

// ---------------------------------------------------------------------------

// Inline error row rendered inside the "Recommended for You" section.
// Uses errorContainer so all error states in the app share the same visual
// language (consistent with _DeezerExpiredBanner above).
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
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded,
                size: 18, color: scheme.onErrorContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                    fontSize: 13, color: scheme.onErrorContainer),
              ),
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

// Surfaces Deezer ARL expiry as an actionable top-of-home banner. Tapping
// routes to Settings so the user can paste a fresh ARL without hunting
// through the nav.
class _DeezerExpiredBanner extends StatelessWidget {
  const _DeezerExpiredBanner();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Material(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
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
                      Text(
                        'Deezer session expired',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: scheme.onErrorContainer,
                        ),
                      ),
                      Text(
                        'Paste a fresh ARL in Settings to re-enable server downloads.',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onErrorContainer,
                        ),
                      ),
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

// Shown when the user has no play history yet — can't build seeds.
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
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(Icons.auto_awesome_rounded,
                size: 18, color: scheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Play a few songs — recommendations appear after some listening history.',
                style: TextStyle(
                    fontSize: 13, color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
