import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart'
    show Color, HSLColor, ImageConfiguration, Size;
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:path/path.dart' as p;
import 'api/subsonic_client.dart';
import 'api/navidrome_client.dart' show CompanionClient;
import 'api/deezer_client.dart';
import 'api/lrclib_client.dart';
import 'models/recommended_track.dart';
import 'models/recommendations_state.dart';
import 'audio/audio_handler.dart';
import 'db/database.dart';
import 'models/app_preferences.dart';
import 'models/song.dart';
import 'models/album.dart';
import 'models/artist.dart';
import 'models/lyrics_result.dart';
import 'models/search_results.dart';
import 'utils/title_normalize.dart';

// --- Database ---
final databaseProvider = Provider<AppDatabase>((_) => AppDatabase());

// --- Connectivity ---
// True = device has at least one non-none network interface.
// This is real device connectivity (Wi-Fi / mobile), NOT server reachability.
final isOnlineProvider = StreamProvider<bool>((ref) async* {
  final conn = Connectivity();
  final initial = await conn.checkConnectivity();
  yield initial.any((r) => r != ConnectivityResult.none);
  yield* conn.onConnectivityChanged
      .map((results) => results.any((r) => r != ConnectivityResult.none));
});

// Resolves to a ServerReachability value.
// Re-runs automatically whenever isOnlineProvider or serverConfig changes.
final serverReachableProvider = FutureProvider<ServerReachability>((ref) async {
  final isOnline = ref.watch(isOnlineProvider).valueOrNull ?? true;
  if (!isOnline) return ServerReachability.offline;
  final client = ref.watch(subsonicClientProvider);
  if (client == null) return ServerReachability.unreachable;
  return client.pingDetailed();
});

// --- Server Config ---
final serverConfigProvider = FutureProvider<SubsonicConfig?>((ref) async {
  final db = ref.watch(databaseProvider);
  final config = await db.getActiveConfig();
  if (config == null) return null;
  return SubsonicConfig(
    serverUrl: config.serverUrl,
    username: config.username,
    password: config.password,
  );
});

// --- Subsonic Client ---
final subsonicClientProvider = Provider<SubsonicClient?>((ref) {
  final configAsync = ref.watch(serverConfigProvider);
  return configAsync.whenOrNull(
    data: (config) => config != null ? SubsonicClient(config) : null,
  );
});

// --- Companion Client ---
final companionClientProvider = Provider<CompanionClient?>((ref) {
  final prefs = ref.watch(preferencesNotifierProvider);
  if (!prefs.hasCompanion) return null;
  return CompanionClient(
    baseUrl: prefs.companionUrl,
    apiKey: prefs.companionApiKey,
  );
});

// Streams companion availability, re-checking every 30 s.
// Using StreamProvider so the UI reflects companion going offline mid-session.
final companionAvailableProvider = StreamProvider<bool>((ref) async* {
  final client = ref.watch(companionClientProvider);
  if (client == null) {
    yield false;
    return;
  }
  while (true) {
    try {
      yield await client.checkHealth();
    } catch (_) {
      yield false;
    }
    await Future.delayed(const Duration(seconds: 30));
  }
});

final canDeleteFromServerProvider = Provider<bool>((ref) =>
    ref.watch(companionAvailableProvider).valueOrNull ?? false);

/// Three-state readable status for the user's Deezer ARL cookie.
///
/// `notSet` — user never pasted an ARL. No banner, no red chip; the app is
///            just in "previews only" mode.
/// `valid`  — Deezer's gw-light endpoint returned a non-zero USER_ID.
/// `invalid`— ARL set but Deezer rejected it (expired, malformed, etc.)
///            → surface an actionable banner / red tile so the user knows
///            *before* they hit a mystery "download failed" on the server.
enum DeezerArlStatus { notSet, valid, invalid }

/// Validates the configured Deezer ARL by calling Deezer's gw-light endpoint
/// directly — no companion round-trip needed. Re-runs automatically whenever
/// `preferencesNotifierProvider` emits a new ARL via `ref.watch`.
final deezerArlStatusProvider = FutureProvider<DeezerArlStatus>((ref) async {
  final arl = ref.watch(
    preferencesNotifierProvider.select((p) => p.deezerArl),
  );
  if (arl.isEmpty) return DeezerArlStatus.notSet;
  final ok = await DeezerClient.validateArl(arl);
  return ok ? DeezerArlStatus.valid : DeezerArlStatus.invalid;
});

Future<void> deleteSongFromServer(WidgetRef ref, Song song) async {
  final companion = ref.read(companionClientProvider);
  if (companion == null) throw Exception('Companion not configured');

  // 0. Mark as pending-delete so it's filtered from the song list immediately,
  //    even if the server re-returns it before the rescan completes.
  ref.read(_pendingDeleteIdsProvider.notifier).update((s) => {...s, song.id});

  // 1. Delete file on server
  await companion.deleteSong(song.id);

  // 2. Trigger Navidrome library rescan (non-fatal if it fails)
  ref.read(subsonicClientProvider)?.startScan();

  // 3. Clean up local download file if present
  final db = ref.read(databaseProvider);
  final row = await db.getSongById(song.id);
  if (row?.localPath != null) {
    final file = File(row!.localPath!);
    if (await file.exists()) await file.delete();
  }

  // 4. Remove all local DB traces
  await db.deleteSongCompletely(song.id);

  // 5. Remove from active playback queue
  ref.read(audioHandlerNotifierProvider)?.removeSongById(song.id);

  // 6. Refresh downloads list (song file was deleted in step 3).
  // allSongsProvider is NOT invalidated here — _pendingDeleteIdsProvider
  // already triggers its rebuild at step 0, avoiding a double-reload that
  // would flash a loading spinner and reset the scroll position.
  ref.invalidate(downloadedSongsProvider);
}

// --- Audio Handler ---
class AudioHandlerNotifier extends StateNotifier<MelodizeAudioHandler?> {
  AudioHandlerNotifier() : super(null);
  void setHandler(MelodizeAudioHandler handler) => state = handler;
}

final audioHandlerNotifierProvider =
    StateNotifierProvider<AudioHandlerNotifier, MelodizeAudioHandler?>(
  (ref) => AudioHandlerNotifier(),
);

// --- Playback streams ---
final currentSongStreamProvider = StreamProvider<Song?>((ref) {
  final handler = ref.watch(audioHandlerNotifierProvider);
  if (handler == null) return Stream.value(null);
  return handler.currentSongStream;
});

final playerStateStreamProvider = StreamProvider<PlayerState>((ref) {
  final handler = ref.watch(audioHandlerNotifierProvider);
  if (handler == null) return const Stream.empty();
  return handler.player.playerStateStream;
});

final positionStreamProvider = StreamProvider<Duration>((ref) {
  final handler = ref.watch(audioHandlerNotifierProvider);
  if (handler == null) return Stream.value(Duration.zero);
  return handler.player.positionStream;
});

final durationStreamProvider = StreamProvider<Duration?>((ref) {
  final handler = ref.watch(audioHandlerNotifierProvider);
  if (handler == null) return Stream.value(null);
  return handler.player.durationStream;
});

final sequenceStateStreamProvider = StreamProvider<SequenceState?>((ref) {
  final handler = ref.watch(audioHandlerNotifierProvider);
  if (handler == null) return Stream.value(null);
  return handler.player.sequenceStateStream;
});

final shuffleModeStreamProvider = StreamProvider<bool>((ref) {
  final handler = ref.watch(audioHandlerNotifierProvider);
  if (handler == null) return Stream.value(false);
  return handler.shuffleStream;
});

final loopModeStreamProvider = StreamProvider<LoopMode>((ref) {
  final handler = ref.watch(audioHandlerNotifierProvider);
  if (handler == null) return Stream.value(LoopMode.off);
  return handler.player.loopModeStream;
});

// --- Cover art URL ---
final coverArtUrlProvider = Provider.family<String?, String>((ref, coverArtId) {
  if (coverArtId.isEmpty) return null;
  final client = ref.watch(subsonicClientProvider);
  return client?.coverArtUrl(coverArtId);
});

// IDs of songs deleted server-side that haven't been confirmed gone by the
// next server sync yet. Prevents ghost entries reappearing in the list.
final _pendingDeleteIdsProvider = StateProvider<Set<String>>((ref) => {});

// --- Songs ---
// Stale-while-revalidate: shows cached songs immediately, refreshes from server
final allSongsProvider = StreamProvider<List<Song>>((ref) async* {
  final db = ref.watch(databaseProvider);
  final client = ref.watch(subsonicClientProvider);
  final deletedIds = ref.watch(_pendingDeleteIdsProvider);

  List<Song> _filter(List<Song> songs) =>
      deletedIds.isEmpty ? songs : songs.where((s) => !deletedIds.contains(s.id)).toList();

  // Always emit cached songs immediately (with correct isDownloaded from DB)
  final cached = await db.getAllCachedSongs();
  yield _filter(cached.map(_rowToSong).toList());

  if (client != null) {
    try {
      final fresh = await client.getAllSongs();
      await db.upsertSongs(fresh.map(_songToCompanion).toList());

      // Prune songs that are no longer on the server (fixes stale cache and
      // downloaded-count > library-count).  Keep locally-downloaded songs so
      // the user can still play offline files that were removed from the server.
      final freshIds = fresh.map((s) => s.id).toSet();
      for (final row in cached) {
        if (!freshIds.contains(row.id) && !row.isDownloaded) {
          await db.deleteSongCompletely(row.id);
        }
      }

      // Re-read from DB so isDownloaded / localPath are preserved — avoids
      // downloadBatch seeing all songs as not-downloaded on app restart.
      final updated = await db.getAllCachedSongs();
      final updatedSongs = updated.map(_rowToSong).toList();

      // If the server no longer returns pending-delete songs, clear them from the set.
      if (deletedIds.isNotEmpty) {
        ref.read(_pendingDeleteIdsProvider.notifier).update(
            (s) => s.intersection(freshIds));
      }
      yield _filter(updatedSongs);
    } catch (_) {
      // Offline or server error — keep showing cached data, no rethrow
    }
  }
});

final randomSongsProvider = FutureProvider<List<Song>>((ref) async {
  final client = ref.watch(subsonicClientProvider);
  if (client == null) return [];
  return await client.getRandomSongs(count: 20);
});

final deezerClientProvider = Provider<DeezerClient>((_) => DeezerClient());

/// When set, [recommendationsProvider] uses this single seed instead of
/// pulling from play history. Wired to the "More like this" action on a
/// recommendation card's 3-dot menu.
///
/// The consumer is responsible for clearing this back to null after its
/// invalidate, so a subsequent refresh falls back to the history-based
/// flow rather than re-forcing the same seed forever.
typedef RecommendationSeed = ({String artist, String title, String? genre});

final recommendationsSeedOverrideProvider =
    StateProvider<RecommendationSeed?>((_) => null);

/// Discovers NEW tracks the user doesn't already have via Deezer artist
/// radios. Explicit [RecommendationsState] so Home can distinguish
/// loading / empty-history / error / ready — the previous version
/// silently returned `[]` for every failure mode.
///
/// Pipeline:
///   1. Build up to 6 seeds (override takes precedence; otherwise dedupe
///      recent history by artist, shuffle, take 6).
///   2. For each seed run [DeezerClient.searchBestArtist] (fuzzy match,
///      genre-biased) then [DeezerClient.artistRadio] — all seeds in
///      parallel via Future.wait.
///   3. If every seed returned empty, retry the whole fan-out once
///      (transient network hits tend to be correlated).
///   4. Merge + dedupe by Deezer ID.
///   5. Filter out anything whose normalized title+artist matches a
///      library track — recommendations are for music the user doesn't
///      own yet. Uses the local [allSongsProvider] snapshot, not a
///      per-candidate Subsonic search (the old impl did N searches per
///      refresh, which was both slow and brittle).
///   6. Cap at 2 tracks per artist (bucket-interleave), shuffle, take 30.
///   7. Warm the cover-art disk cache so the list doesn't pop in.
///
/// Intentionally NOT autoDispose: a fail-empty state used to stick
/// across navigation because rebuilding with the same seed reproduced
/// the same failure. Keeping the provider alive lets explicit
/// `ref.invalidate` from the refresh button be the only retry trigger.
final recommendationsProvider =
    FutureProvider<RecommendationsState>((ref) async {
  final db = ref.watch(databaseProvider);
  final client = ref.watch(subsonicClientProvider);
  final deezer = ref.watch(deezerClientProvider);
  final override = ref.watch(recommendationsSeedOverrideProvider);

  if (client == null) {
    return const RecsError(
        'Connect a server in Settings to get recommendations.');
  }

  // Library snapshot used for the already-owned cross-check. ref.read,
  // not watch — we don't want a rec rebuild every time the library
  // stream re-emits (stale-then-fresh).
  final library = ref.read(allSongsProvider).valueOrNull ?? const <Song>[];
  final libraryKeys = <String>{
    for (final s in library) keyFor(s.title, s.artist),
  };
  final genreBySongId = <String, String?>{
    for (final s in library) s.id: s.genre,
  };

  // Build history seeds (always — used both for normal mode and as fallback
  // when "More like this" override exhausts its candidates).
  final history = await db.getRecentHistory(limit: 30);
  final byArtist = <String, PlayHistoryData>{};
  for (final h in history) {
    byArtist.putIfAbsent(h.artist, () => h);
  }
  final distinctHistory = byArtist.values.toList()..shuffle();

  final seeds = <RecommendationSeed>[];
  if (override != null) {
    // Override artist goes first so it dominates the mix.
    seeds.add(override);
    // Add 3 history seeds from different artists as resilience backup:
    // if the override artist isn't on Deezer, or all their radio tracks
    // are already owned, history seeds fill the gap instead of erroring.
    final overrideNorm = normalize(override.artist);
    for (final h in distinctHistory) {
      if (seeds.length >= 4) break;
      if (normalize(h.artist) == overrideNorm) continue;
      seeds.add((
        artist: h.artist,
        title: h.songTitle,
        genre: genreBySongId[h.songId],
      ));
    }
    // If there's no history at all and the override also fails, return
    // a graceful empty rather than crashing.
    if (seeds.length == 1 && history.isEmpty) {
      return const RecsEmptyNoHistory();
    }
  } else {
    if (history.isEmpty) return const RecsEmptyNoHistory();
    // Dedupe by artist so 6 seeds cover 6 different artists; avoids the
    // "played the same track 6 times today = 6 identical seeds = 1 radio"
    // degenerate case.
    for (final h in distinctHistory.take(6)) {
      seeds.add((
        artist: h.artist,
        title: h.songTitle,
        genre: genreBySongId[h.songId],
      ));
    }
    if (seeds.isEmpty) return const RecsEmptyNoHistory();
  }

  // Fetch radio for each seed in parallel. Use a larger limit so the
  // library cross-check (below) has more candidates to work with —
  // users with large libraries need more raw tracks to find new ones.
  Future<List<RecommendedTrack>> fanOut(RecommendationSeed seed) async {
    final id = await deezer.searchBestArtist(
      artistName: seed.artist,
      trackTitle: seed.title,
      genreHint: seed.genre,
    );
    if (id == null) return const [];
    return deezer.artistRadio(id, limit: 20);
  }

  var results = await Future.wait(seeds.map(fanOut));
  if (results.every((r) => r.isEmpty)) {
    results = await Future.wait(seeds.map(fanOut));
  }
  final failedSeeds = results.where((r) => r.isEmpty).length;

  final byDeezerId = <int, RecommendedTrack>{};
  for (final list in results) {
    for (final t in list) {
      byDeezerId.putIfAbsent(t.deezerId, () => t);
    }
  }
  if (byDeezerId.isEmpty) {
    return const RecsError(
        "Couldn't fetch recommendations right now — check your connection and retry.");
  }

  final discoveries = byDeezerId.values
      .where((t) => !libraryKeys.contains(keyFor(t.title, t.artist)))
      .toList();

  // Artist diversity: at most 2 per artist, interleaved so same-artist
  // tracks aren't clustered at the top of the list.
  final buckets = <String, List<RecommendedTrack>>{};
  for (final t in discoveries) {
    buckets.putIfAbsent(normalize(t.artist), () => []).add(t);
  }
  final shuffledBuckets = buckets.values.map((b) {
    final list = b.toList()..shuffle();
    return list.take(2).toList();
  }).toList()
    ..shuffle();
  final capped = <RecommendedTrack>[];
  for (var round = 0; capped.length < 30; round++) {
    var anyLeft = false;
    for (final bucket in shuffledBuckets) {
      if (round < bucket.length) {
        capped.add(bucket[round]);
        anyLeft = true;
        if (capped.length >= 30) break;
      }
    }
    if (!anyLeft) break;
  }

  if (capped.isEmpty) {
    return const RecsError(
        'All recommendations matched tracks you already have — try refreshing.');
  }

  // Warm cover-art disk cache. CachedNetworkImageProvider writes through
  // to disk on resolve; fire-and-forget so a slow image host can't stall
  // the whole provider.
  for (final t in capped) {
    final url = t.coverUrl;
    if (url != null && url.isNotEmpty) {
      CachedNetworkImageProvider(url).resolve(const ImageConfiguration());
    }
  }

  final songs = [
    for (final t in capped)
      Song.fromRecommendation(
        deezerId: t.deezerId,
        title: t.title,
        artist: t.artist,
        album: t.album,
        durationSeconds: t.durationSeconds,
        previewUrl: t.previewUrl,
        coverUrl: t.coverUrl,
      ),
  ];

  return RecsReady(songs, failedSeeds: failedSeeds);
});

// Deezer catalog search — powers the "From Deezer" section in the search tab.
final deezerSearchProvider =
    FutureProvider.autoDispose<List<RecommendedTrack>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.trim().length < 2) return [];
  return ref.watch(deezerClientProvider).search(query);
});

// Deezer top tracks for a specific artist — used on the artist detail page to
// surface songs the user doesn't own yet. Resolves the artist name → Deezer ID
// first (searchBestArtist), then fetches real top tracks (not the radio mix).
// Tracks already in the library are filtered out so this section is discovery-
// only; library tracks are already visible in Albums / Songs.
final deezerArtistTracksProvider =
    FutureProvider.autoDispose.family<List<RecommendedTrack>, String>(
        (ref, artistName) async {
  if (artistName.trim().isEmpty) return [];
  final deezer = ref.watch(deezerClientProvider);

  final artistId = await deezer.searchBestArtist(artistName: artistName);
  if (artistId == null) return [];

  final tracks = await deezer.artistTopTracks(artistId, limit: 15);
  if (tracks.isEmpty) return [];

  // Cross-check against the cached library to skip tracks the user already owns.
  final library = ref.read(allSongsProvider).valueOrNull ?? const <Song>[];
  final owned = <String>{
    for (final s in library) keyFor(s.title, s.artist),
  };

  return tracks.where((t) => !owned.contains(keyFor(t.title, t.artist))).toList();
});

final downloadedSongsProvider = FutureProvider<List<Song>>((ref) async {
  final db = ref.watch(databaseProvider);
  final rows = await db.getDownloadedSongs();
  return rows.map(_rowToSong).toList();
});

final recentlyPlayedProvider = FutureProvider<List<Song>>((ref) async {
  final db = ref.watch(databaseProvider);
  final history = await db.getRecentHistory(limit: 20);
  return history
      .map((h) => Song(
            id: h.songId,
            title: h.songTitle,
            artist: h.artist,
            album: '',
            coverArt: h.coverArt,
          ))
      .toList();
});

// --- Albums ---
final newestAlbumsProvider = FutureProvider<List<Album>>((ref) async {
  final client = ref.watch(subsonicClientProvider);
  if (client == null) return [];
  return await client.getNewestAlbums(size: 20);
});

final allAlbumsProvider = FutureProvider<List<Album>>((ref) async {
  final client = ref.watch(subsonicClientProvider);
  if (client == null) return [];
  try {
    final all = <Album>[];
    int offset = 0;
    const size = 500;
    while (true) {
      final page = await client.getAlbums(size: size, offset: offset);
      all.addAll(page);
      if (page.length < size) break;
      offset += size;
    }
    return all;
  } catch (_) {
    return [];
  }
});

final albumSongsProvider =
    FutureProvider.family<List<Song>, String>((ref, albumId) async {
  final client = ref.watch(subsonicClientProvider);
  if (client == null) return [];
  try {
    return await client.getAlbumSongs(albumId);
  } catch (_) {
    return [];
  }
});

// --- Artists ---
final allArtistsProvider = FutureProvider<List<Artist>>((ref) async {
  final client = ref.watch(subsonicClientProvider);
  if (client == null) return [];
  try {
    return await client.getArtists();
  } catch (_) {
    return [];
  }
});

final artistAlbumsProvider =
    FutureProvider.family<List<Album>, String>((ref, artistId) async {
  final client = ref.watch(subsonicClientProvider);
  if (client == null) return [];
  try {
    return await client.getArtistAlbums(artistId);
  } catch (_) {
    return [];
  }
});

// Top songs for an artist by name (Navidrome/Last.fm backed — may return [] on servers
// without Last.fm integration; callers should handle empty gracefully).
final artistTopSongsProvider =
    FutureProvider.family<List<Song>, String>((ref, artistName) async {
  final client = ref.watch(subsonicClientProvider);
  if (client == null) return [];
  return client.getTopSongs(artistName);
});

// All songs by an artist — fetches each album's tracks in parallel.
final artistAllSongsProvider =
    FutureProvider.family<List<Song>, String>((ref, artistId) async {
  final client = ref.watch(subsonicClientProvider);
  if (client == null) return [];
  try {
    final albums = await client.getArtistAlbums(artistId);
    final perAlbum =
        await Future.wait(albums.map((a) => client.getAlbumSongs(a.id)));
    return perAlbum.expand((songs) => songs).toList();
  } catch (_) {
    return [];
  }
});

// --- Playlists ---
final playlistsProvider = FutureProvider((ref) async {
  final client = ref.watch(subsonicClientProvider);
  if (client == null) return [];
  try {
    return await client.getPlaylists();
  } catch (_) {
    return [];
  }
});

final playlistSongsProvider =
    FutureProvider.family<List<Song>, String>((ref, playlistId) async {
  final client = ref.watch(subsonicClientProvider);
  if (client == null) return [];
  try {
    return await client.getPlaylistSongs(playlistId);
  } catch (_) {
    return [];
  }
});

// --- Search ---
final searchQueryProvider = StateProvider<String>((_) => '');

final searchResultsProvider = FutureProvider<SearchResults>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.isEmpty) {
    return const SearchResults(songs: [], albums: [], artists: []);
  }
  final client = ref.watch(subsonicClientProvider);
  if (client == null) {
    return const SearchResults(songs: [], albums: [], artists: []);
  }
  try {
    return await client.search(query);
  } catch (_) {
    return const SearchResults(songs: [], albums: [], artists: []);
  }
});

// --- Lyrics ---
typedef LyricsQuery = ({
  String songId,
  String artist,
  String title,
  String album,
  int duration,
});

final lyricsProvider =
    FutureProvider.family<LyricsResult?, LyricsQuery>((ref, q) async {
  final db = ref.read(databaseProvider);

  // Check cache first
  final cached = await db.getCachedLyrics(q.songId);
  if (cached != null) {
    return LyricsResult(
      plain: cached.plainLyrics,
      synced: cached.syncedLyrics,
    );
  }

  // Fetch from LRClib
  try {
    final result = await LrcLibClient().getLyrics(
      artist: q.artist,
      title: q.title,
      album: q.album,
      duration: q.duration,
    );
    if (result != null) {
      await db.cacheLyrics(q.songId, result.plain, result.synced);
    }
    return result;
  } catch (_) {
    return null;
  }
});

// --- Preferences ---
class PreferencesNotifier extends StateNotifier<AppPreferences> {
  PreferencesNotifier() : super(const AppPreferences()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await AppPreferences.load();
    if (mounted) state = prefs;
  }

  Future<void> update(AppPreferences prefs) async {
    state = prefs;
    await prefs.save();
  }
}

final preferencesNotifierProvider =
    StateNotifierProvider<PreferencesNotifier, AppPreferences>(
  (_) => PreferencesNotifier(),
);

/// Maps the saved theme preference string to a [ThemeMode].
final themeModeProvider = Provider<ThemeMode>((ref) {
  final mode = ref.watch(
    preferencesNotifierProvider.select((p) => p.themeMode),
  );
  switch (mode) {
    case 'light':
      return ThemeMode.light;
    case 'system':
      return ThemeMode.system;
    case 'dark':
    default:
      return ThemeMode.dark;
  }
});

// --- Downloads ---
class DownloadItem {
  final Song song;
  final double progress; // 0.0 – 1.0
  // status: 'queued' | 'downloading' | 'done' | 'error'
  final String status;
  final String? errorMessage;
  const DownloadItem({
    required this.song,
    required this.progress,
    required this.status,
    this.errorMessage,
  });
}

class _DownloadTask {
  final Song song;
  final String savePath;
  final String quality;
  final bool force;
  const _DownloadTask({
    required this.song,
    required this.savePath,
    required this.quality,
    required this.force,
  });
}

class DownloadNotifier extends StateNotifier<Map<String, DownloadItem>> {
  final SubsonicClient? _client;
  final AppDatabase _db;
  final Ref _ref;

  // At most 2 simultaneous HTTP downloads to keep the device responsive.
  static const _maxConcurrent = 2;
  int _activeCount = 0;
  final _queue = Queue<_DownloadTask>();

  DownloadNotifier(this._client, this._db, this._ref) : super({});

  // Enqueue a single download (e.g. when user taps ⋯ > Download, or on-play).
  Future<void> download(
    Song song,
    String savePath, {
    String quality = 'lossless',
    bool force = false,
  }) async {
    if (_client == null) return;
    final current = state[song.id]?.status;
    if (!force && (current == 'downloading' || current == 'queued')) return;

    state = {
      ...state,
      song.id: DownloadItem(song: song, progress: 0, status: 'queued'),
    };
    _enqueue(_DownloadTask(
        song: song, savePath: savePath, quality: quality, force: force));
  }

  // Bulk-enqueue an entire list in ONE state update to avoid flooding Riverpod
  // with thousands of individual rebuilds when "Download all" is enabled.
  Future<void> downloadBatch(
    List<Song> songs,
    String baseDir,
    String quality,
  ) async {
    if (_client == null || songs.isEmpty) return;

    final Map<String, DownloadItem> additions = {};
    for (final song in songs) {
      if (song.isDownloaded) continue;
      final s = state[song.id]?.status;
      if (s == 'downloading' || s == 'queued' || s == 'done') continue;
      final savePath =
          '$baseDir/${song.id}.${song.suffix ?? 'mp3'}';
      additions[song.id] =
          DownloadItem(song: song, progress: 0, status: 'queued');
      _queue.add(_DownloadTask(
          song: song, savePath: savePath, quality: quality, force: false));
    }
    if (additions.isEmpty) return;

    // Single state write for the entire batch.
    state = {...state, ...additions};
    _tryStartQueued();
  }

  void _enqueue(_DownloadTask task) {
    if (_activeCount < _maxConcurrent) {
      _runDownload(task);
    } else {
      _queue.add(task);
    }
  }

  void _tryStartQueued() {
    while (_activeCount < _maxConcurrent && _queue.isNotEmpty) {
      _runDownload(_queue.removeFirst());
    }
  }

  void _runDownload(_DownloadTask task) {
    _activeCount++;
    _doDownload(task).then((_) {
      _activeCount--;
      if (_queue.isNotEmpty && mounted) {
        _runDownload(_queue.removeFirst());
      }
    });
  }

  Future<void> _doDownload(_DownloadTask task) async {
    final song = task.song;
    final savePath = task.savePath;
    final quality = task.quality;

    if (!mounted) return;
    state = {
      ...state,
      song.id: DownloadItem(song: song, progress: 0, status: 'downloading'),
    };
    try {
      await Directory(p.dirname(savePath)).create(recursive: true);
      await _client!.downloadSong(
        song,
        savePath,
        quality: quality,
        onProgress: (recv, total) {
          if (!mounted) return;
          if (total > 0) {
            state = {
              ...state,
              song.id: DownloadItem(
                song: song,
                progress: recv / total,
                status: 'downloading',
              ),
            };
          }
        },
      );
      if (!mounted) return;
      await _db.markDownloaded(song.id, savePath);
      // Pre-cache lyrics so they're available offline. Fire-and-forget:
      // a lyrics failure must not fail the download.
      unawaited(LrcLibClient().getLyrics(
        artist: song.artist,
        title: song.title,
        album: song.album,
        duration: song.duration ?? 0,
      ).then((result) {
        if (result != null) {
          _db.cacheLyrics(song.id, result.plain, result.synced);
        }
      }).catchError((_) {}));
      await _db.upsertDownload(DownloadQueueCompanion.insert(
        songId: song.id,
        songTitle: song.title,
        artist: song.artist,
        savePath: savePath,
        status: const Value('done'),
        progress: const Value(100),
      ));
      if (!mounted) return;
      final updated = Map<String, DownloadItem>.from(state);
      updated[song.id] = DownloadItem(song: song, progress: 1, status: 'done');
      state = updated;
      _ref.invalidate(downloadedSongsProvider);
    } catch (e) {
      if (!mounted) return;
      final updated = Map<String, DownloadItem>.from(state);
      updated[song.id] = DownloadItem(
          song: song,
          progress: 0,
          status: 'error',
          errorMessage: e.toString());
      state = updated;
    }
  }

  bool isDownloading(String songId) {
    final s = state[songId]?.status;
    return s == 'downloading' || s == 'queued';
  }

  Future<void> removeDownload(String songId) async {
    // Cancel if queued.
    _queue.removeWhere((t) => t.song.id == songId);
    try {
      final row = await _db.getSongById(songId);
      // Update DB before deleting the file so that if file deletion fails,
      // the app won't attempt to play a track that no longer exists on disk.
      await _db.unmarkDownloaded(songId);
      await _db.deleteDownload(songId);
      if (row?.localPath != null) {
        final file = File(row!.localPath!);
        if (await file.exists()) await file.delete();
      }
    } catch (_) {}
    final updated = Map<String, DownloadItem>.from(state);
    updated.remove(songId);
    state = updated;
    _ref.invalidate(downloadedSongsProvider);
  }
}

final downloadNotifierProvider =
    StateNotifierProvider<DownloadNotifier, Map<String, DownloadItem>>((ref) {
  final client = ref.watch(subsonicClientProvider);
  final db = ref.watch(databaseProvider);
  return DownloadNotifier(client, db, ref);
});

// Set of downloaded song IDs — only updates when a download *completes* (not on progress ticks).
// DownloadNotifier invalidates downloadedSongsProvider on completion, which cascades here.
final downloadedSongIdsProvider = Provider<Set<String>>((ref) {
  final songs = ref.watch(downloadedSongsProvider).valueOrNull ?? [];
  return songs.map((s) => s.id).toSet();
});

// --- Album art dominant color (cached per URL) ---
// Shared by now_playing_screen, mini_player, and main_shell.
final dominantColorProvider =
    FutureProvider.family<Color?, String>((ref, url) async {
  if (url.isEmpty) return null;
  try {
    final palette = await PaletteGenerator.fromImageProvider(
      CachedNetworkImageProvider(url),
      size: const Size(112, 112), // downsample before extraction — much faster
      maximumColorCount: 8,
    );
    // Prefer intentionally-saturated swatches over the dominant (most-pixels)
    // color, which is often the album cover's background — off-white, black, or
    // a washed-out neutral that makes a poor accent.
    final raw = palette.vibrantColor?.color
        ?? palette.darkVibrantColor?.color
        ?? palette.mutedColor?.color
        ?? palette.dominantColor?.color;
    if (raw == null) return null;
    return _processAccentColor(raw);
  } catch (_) {
    return null;
  }
});

/// Clamps a raw palette color into a range that works as a UI accent:
/// - Saturation ≥ 0.20 so it reads as a colour, not a gray.
/// - Lightness ∈ [0.28, 0.62] so it is neither too dark to tint surfaces
///   nor too light to support white text (dock pill, player bg, mini player).
Color _processAccentColor(Color raw) {
  final hsl = HSLColor.fromColor(raw);
  return hsl
      .withSaturation(hsl.saturation.clamp(0.20, 1.0))
      .withLightness(hsl.lightness.clamp(0.28, 0.62))
      .toColor();
}

// Accent color derived from the current song's album art.
// Returns null until the color resolves, then updates all watchers.
final currentAccentColorProvider = Provider<Color?>((ref) {
  final song = ref.watch(currentSongStreamProvider).valueOrNull;
  if (song == null) return null;
  final coverUrl = ref.watch(coverArtUrlProvider(song.coverArt ?? ''))
      ?? song.externalCoverUrl
      ?? '';
  if (coverUrl.isEmpty) return null;
  return ref.watch(dominantColorProvider(coverUrl)).valueOrNull;
});

// --- Helpers ---

Song _rowToSong(CachedSong row) => Song(
      id: row.id,
      title: row.title,
      artist: row.artist,
      album: row.album,
      albumId: row.albumId,
      artistId: row.artistId,
      duration: row.duration,
      year: row.year,
      genre: row.genre,
      track: row.track,
      coverArt: row.coverArt,
      suffix: row.suffix,
      contentType: row.contentType,
      bitRate: row.bitRate,
      size: row.size,
      isDownloaded: row.isDownloaded,
      localPath: row.localPath,
      created: row.created,
    );

// Intentionally omits isDownloaded and localPath so server syncs
// never overwrite download state managed by DownloadNotifier.
CachedSongsCompanion _songToCompanion(Song s) => CachedSongsCompanion(
      id: Value(s.id),
      title: Value(s.title),
      artist: Value(s.artist),
      album: Value(s.album),
      albumId: Value(s.albumId),
      artistId: Value(s.artistId),
      duration: Value(s.duration),
      year: Value(s.year),
      genre: Value(s.genre),
      track: Value(s.track),
      coverArt: Value(s.coverArt),
      suffix: Value(s.suffix),
      contentType: Value(s.contentType),
      bitRate: Value(s.bitRate),
      size: Value(s.size),
      created: Value(s.created),
    );
