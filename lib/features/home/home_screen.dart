import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/album.dart';
import '../../core/models/recommended_track.dart';
import '../../core/models/song.dart';
import '../../core/providers.dart';
import '../../shared/widgets/cover_art_image.dart';
import '../../shared/widgets/offline_banner.dart';
import '../library/album_detail_screen.dart';
import '../library/playlist_detail_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(newestAlbumsProvider);
    ref.invalidate(randomSongsProvider);
    ref.invalidate(recentlyPlayedProvider);
    ref.invalidate(allSongsProvider);
    ref.invalidate(serverReachableProvider);
    ref.invalidate(recommendationsProvider);
    // Give providers a moment to start fetching before we declare done
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

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
      onRefresh: () => _refresh(ref),
      child: CustomScrollView(
        // Always scrollable so pull-to-refresh works even with little content
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
        // Offline banner
        const SliverToBoxAdapter(child: OfflineBanner()),

        // Server unreachable chip (only when device is online but server is down)
        if (isOnline && !serverReachable)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  Icon(Icons.cloud_off_rounded,
                      size: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: 5),
                  Text(
                    'Server unreachable — pull to retry',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Header
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          sliver: SliverToBoxAdapter(
            child: Text(
              _greeting(username),
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        ),

        // Playlists
        playlistsAsync.when(
          skipLoadingOnRefresh: true,
          loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
          error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
          data: (playlists) {
            if (playlists.isEmpty) {
              return const SliverToBoxAdapter(child: SizedBox.shrink());
            }
            return SliverToBoxAdapter(
              child: _Section(
                title: 'Playlists',
                child: SizedBox(
                  height: 152,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: playlists.length,
                    itemBuilder: (_, i) => _PlaylistCard(
                      playlist: playlists[i],
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PlaylistDetailScreen(
                              playlist: playlists[i]),
                        ),
                      ),
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
          loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
          error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
          data: (albums) {
            if (albums.isEmpty) {
              return const SliverToBoxAdapter(child: SizedBox.shrink());
            }
            return SliverToBoxAdapter(
              child: _Section(
                title: 'Recently Added',
                child: SizedBox(
                  height: 176,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: albums.length,
                    itemBuilder: (_, i) => _AlbumCard(
                      album: albums[i],
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              AlbumDetailScreen(album: albums[i]),
                        ),
                      ),
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
          error: (e, _) => SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.wifi_off_rounded, size: 48),
                    const SizedBox(height: 8),
                    Text('$e',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ),
          ),
          data: (songs) => SliverToBoxAdapter(
            child: _Section(
              title: 'Discover',
              child: SizedBox(
                height: 176,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: songs.length,
                  itemBuilder: (_, i) => _SongCard(
                    song: songs[i],
                    onTap: () => _playSongs(ref, songs, i),
                  ),
                ),
              ),
            ),
          ),
        ),

        // Recommended for You — Deezer artist-radio, songs NOT in the library
        recsAsync.when(
          skipLoadingOnRefresh: true,
          loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
          error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
          data: (recs) {
            if (recs.isEmpty) {
              return const SliverToBoxAdapter(child: SizedBox.shrink());
            }
            return SliverToBoxAdapter(
              child: _Section(
                title: 'Recommended for You',
                child: SizedBox(
                  height: 176,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: recs.length,
                    itemBuilder: (_, i) => _RecommendationCard(rec: recs[i]),
                  ),
                ),
              ),
            );
          },
        ),

        // Recently played
        recentAsync.when(
          skipLoadingOnRefresh: true,
          loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
          error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
          data: (songs) {
            if (songs.isEmpty) {
              return const SliverToBoxAdapter(child: SizedBox.shrink());
            }
            return SliverToBoxAdapter(
              child: _Section(
                title: 'Recently Played',
                child: SizedBox(
                  height: 176,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: songs.length,
                    itemBuilder: (_, i) => _SongCard(
                      song: songs[i],
                      onTap: () => _playSongs(ref, songs, i),
                    ),
                  ),
                ),
              ),
            );
          },
        ),

        const SliverPadding(padding: EdgeInsets.only(bottom: 16)),
      ],
      ),
    ),
    );
  }

  void _playSongs(WidgetRef ref, List<Song> songs, int index) {
    ref.read(audioHandlerNotifierProvider)?.loadQueue(songs, startIndex: index);
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

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
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
      child: SizedBox(
        width: 130,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CoverArtImage(
                  coverArtId: song.coverArt, size: 130, borderRadius: 12),
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
      child: SizedBox(
        width: 130,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CoverArtImage(
                  coverArtId: album.coverArt, size: 130, borderRadius: 12),
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
      child: SizedBox(
        width: 110,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CoverArtImage(
                  coverArtId: playlist.coverArt as String?,
                  size: 110,
                  borderRadius: 12),
              const SizedBox(height: 6),
              Text(playlist.name as String,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600)),
              Text('${playlist.songCount} songs',
                  style: TextStyle(
                      fontSize: 11, color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _RecommendationCard extends ConsumerStatefulWidget {
  final RecommendedTrack rec;
  const _RecommendationCard({required this.rec});

  @override
  ConsumerState<_RecommendationCard> createState() =>
      _RecommendationCardState();
}

class _RecommendationCardState extends ConsumerState<_RecommendationCard> {
  bool _loading = false;

  Future<void> _play() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final song = Song.fromRecommendation(
        deezerId: widget.rec.deezerId,
        title: widget.rec.title,
        artist: widget.rec.artist,
        album: widget.rec.album,
        durationSeconds: widget.rec.durationSeconds,
        previewUrl: widget.rec.previewUrl,
        coverUrl: widget.rec.coverUrl,
      );
      ref.read(audioHandlerNotifierProvider)?.loadQueue([song]);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _addToLibrary() {
    final companion = ref.read(companionClientProvider);
    if (companion == null) return;
    final prefs = ref.read(preferencesNotifierProvider);
    final url = 'https://www.deezer.com/track/${widget.rec.deezerId}';
    companion
        .startDownload(
          url,
          deezerArl: prefs.hasDeezerArl ? prefs.deezerArl : null,
        )
        .catchError((_) {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(prefs.hasDeezerArl
            ? 'Downloading FLAC to server — appears in library after next Navidrome scan'
            : 'Queued — connect Deezer account in Settings for lossless quality'),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final canSave = ref.watch(canDeleteFromServerProvider);

    Widget cover;
    if (widget.rec.coverUrl != null) {
      cover = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: widget.rec.coverUrl!,
          width: 130,
          height: 130,
          fit: BoxFit.cover,
          placeholder: (_, __) => _coverPlaceholder(scheme),
          errorWidget: (_, __, ___) => _coverPlaceholder(scheme),
        ),
      );
    } else {
      cover = _coverPlaceholder(scheme);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: SizedBox(
        width: 130,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _play,
          onLongPress: canSave ? _addToLibrary : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  cover,
                  // "PREVIEW" badge
                  Positioned(
                    bottom: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'PREVIEW',
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                    ),
                  ),
                  if (_loading)
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          color: Colors.black45,
                          child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2)),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(widget.rec.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              Text(widget.rec.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12, color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _coverPlaceholder(ColorScheme scheme) => ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 130,
          height: 130,
          color: scheme.surfaceContainerHigh,
          child: Icon(Icons.music_note_rounded,
              size: 52, color: scheme.onSurfaceVariant),
        ),
      );
}
