import 'dart:collection';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'api/subsonic_client.dart';
import 'api/navidrome_client.dart' show CompanionClient;
import 'api/lrclib_client.dart';
import 'audio/audio_handler.dart';
import 'db/database.dart';
import 'models/app_preferences.dart';
import 'models/song.dart';
import 'models/album.dart';
import 'models/artist.dart';
import 'models/lyrics_result.dart';
import 'models/search_results.dart';

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

// True = Navidrome/Subsonic server responded to ping while device is online.
// Re-runs automatically whenever isOnlineProvider or serverConfig changes.
final serverReachableProvider = FutureProvider<bool>((ref) async {
  final isOnline = ref.watch(isOnlineProvider).valueOrNull ?? true;
  if (!isOnline) return false;
  final client = ref.watch(subsonicClientProvider);
  if (client == null) return false;
  try {
    return await client.ping();
  } catch (_) {
    return false;
  }
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

// True when the companion is configured and responds to /health.
final companionAvailableProvider = FutureProvider<bool>((ref) async {
  final client = ref.watch(companionClientProvider);
  if (client == null) return false;
  return client.checkHealth();
});

final canDeleteFromServerProvider = Provider<bool>((ref) =>
    ref.watch(companionAvailableProvider).valueOrNull ?? false);

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

  // 6. Refresh song list UI
  ref.invalidate(allSongsProvider);
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
  return handler.player.shuffleModeEnabledStream;
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

  // Always emit cached songs immediately
  final cached = await db.getAllCachedSongs();
  yield _filter(cached.map(_rowToSong).toList());

  if (client != null) {
    try {
      final fresh = await client.getAllSongs();
      await db.upsertSongs(fresh.map(_songToCompanion).toList());
      final filtered = _filter(fresh);
      // If the server no longer returns deleted songs, clear them from the set
      if (deletedIds.isNotEmpty) {
        final stillPresent = deletedIds.intersection(fresh.map((s) => s.id).toSet());
        if (stillPresent.length < deletedIds.length) {
          ref.read(_pendingDeleteIdsProvider.notifier).update(
              (s) => s.intersection(fresh.map((e) => e.id).toSet()));
        }
      }
      yield filtered;
    } catch (_) {
      // Offline or server error — keep showing cached data, no rethrow
    }
  }
});

final randomSongsProvider = FutureProvider<List<Song>>((ref) async {
  final client = ref.watch(subsonicClientProvider);
  if (client == null) return [];
  try {
    return await client.getRandomSongs(count: 20);
  } catch (_) {
    return [];
  }
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
  try {
    return await client.getNewestAlbums(size: 20);
  } catch (_) {
    return [];
  }
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

// --- Downloads ---
class DownloadItem {
  final Song song;
  final double progress; // 0.0 – 1.0
  // status: 'queued' | 'downloading' | 'done' | 'error'
  final String status;
  const DownloadItem({
    required this.song,
    required this.progress,
    required this.status,
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
    } catch (_) {
      if (!mounted) return;
      final updated = Map<String, DownloadItem>.from(state);
      updated[song.id] =
          DownloadItem(song: song, progress: 0, status: 'error');
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
      if (row?.localPath != null) {
        final file = File(row!.localPath!);
        if (await file.exists()) await file.delete();
      }
      await _db.unmarkDownloaded(songId);
      await _db.deleteDownload(songId);
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
    );
