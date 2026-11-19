import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math' show Random;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart'
    show
        Brightness,
        Color,
        FileImage,
        HSLColor,
        ImageConfiguration,
        ImageProvider,
        Size;
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:path/path.dart' as p;
import 'api/subsonic_client.dart';
import 'api/navidrome_client.dart' show CompanionClient;
import 'api/navidrome_native_client.dart';
import 'api/deezer_client.dart';
import 'api/lrclib_client.dart';
import 'api/lyrics_ovh_client.dart';
import 'models/recommended_track.dart';
import 'models/recommendations_state.dart';
import 'audio/shuffle_mode.dart';
import 'audio/audio_handler.dart';
import 'audio/playback_core.dart';
import 'audio/smart_shuffle_engine.dart';
import 'api/companion_audio_api.dart';
import 'db/database.dart';
import 'downloads/download_files.dart';
import 'utils/platform_dirs.dart';
import 'downloads/local_cover_cache.dart';
import 'errors/app_errors.dart';
import 'models/app_preferences.dart';
import 'models/song.dart';
import 'models/album.dart';
import 'models/playlist.dart';
import 'models/artist.dart';
import 'models/artist_info.dart';
import 'library/artist_profile.dart';
import 'models/lyrics_result.dart';
import 'models/search_results.dart';
import 'utils/title_normalize.dart';
import 'library/local_search.dart';
import 'likes/pending_like_match.dart';
import 'recs/taste_model.dart';

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

final canDeleteFromServerProvider = Provider<bool>(
    (ref) => ref.watch(companionAvailableProvider).valueOrNull ?? false);

/// Companion audio analysis API client — built from the server prefs.
final companionAudioApiProvider = Provider<CompanionAudioApi?>((ref) {
  final prefs = ref.watch(preferencesNotifierProvider);
  if (!prefs.hasCompanion) return null;
  return CompanionAudioApi(
    baseUrl: prefs.companionUrl,
    apiKey: prefs.companionApiKey,
  );
});

/// Fetches all analysis results from the companion server.
/// Returns a [BpmCache] that the smart shuffle engine uses for ordering.
final companionAnalysisProvider = FutureProvider<BpmCache?>((ref) async {
  final api = ref.watch(companionAudioApiProvider);
  final available = ref.watch(companionAvailableProvider).valueOrNull ?? false;
  if (api == null || !available) return null;

  final results = await api.getAllResults();
  if (results.isEmpty) return null;

  final bpm = <String, int>{};
  final key = <String, String>{};
  final isEstimated = <String, bool>{};
  final tailSilence = <String, double>{};
  final energy = <String, double>{};
  final spectralCentroid = <String, double>{};
  final phrasePositions = <String, List<double>>{};
  final firstBeatOffset = <String, double>{};
  final vocalSections = <String, List<VocalSection>>{};

  for (final r in results) {
    final songId = r['song_id'] as String?;
    final bpmVal = r['bpm'];
    final keyVal = r['key'] as String?;
    if (songId == null) continue;

    if (bpmVal is num && bpmVal > 0) {
      bpm[songId] = bpmVal.round();
      isEstimated[songId] = false;
    }
    if (keyVal != null && keyVal.isNotEmpty) {
      key[songId] = keyVal;
    }
    final tailVal = r['tail_silence'];
    if (tailVal is num && tailVal > 0) {
      tailSilence[songId] = tailVal.toDouble();
    }
    final energyVal = r['energy'];
    if (energyVal is num && energyVal > 0) {
      energy[songId] = energyVal.toDouble();
    }
    final centroidVal = r['spectral_centroid'];
    if (centroidVal is num && centroidVal > 0) {
      spectralCentroid[songId] = centroidVal.toDouble();
    }
    final pp = r['phrase_positions'];
    if (pp is List && pp.isNotEmpty) {
      phrasePositions[songId] =
          pp.whereType<num>().map((n) => n.toDouble()).toList();
    }
    final fbo = r['first_beat_offset'];
    if (fbo is num && fbo >= 0) {
      firstBeatOffset[songId] = fbo.toDouble();
    }
    final vs = r['vocal_sections'];
    if (vs is List && vs.isNotEmpty) {
      vocalSections[songId] = vs
          .whereType<Map>()
          .map((m) => VocalSection(
                start: (m['start'] as num?)?.toDouble() ?? 0.0,
                end: (m['end'] as num?)?.toDouble() ?? 0.0,
              ))
          .toList();
    }
  }

  return BpmCache(
    bpm: bpm,
    key: key,
    isEstimated: isEstimated,
    tailSilence: tailSilence,
    energy: energy,
    spectralCentroid: spectralCentroid,
    phrasePositions: phrasePositions,
    firstBeatOffset: firstBeatOffset,
    vocalSections: vocalSections,
  );
});

enum CompanionAnalysisPhase { unavailable, ready, queued, running, error }

class CompanionAnalysisStatus {
  final CompanionAnalysisPhase phase;
  final int totalSongs;
  final int cachedSongs;
  final int missingSongs;
  final String? message;

  const CompanionAnalysisStatus({
    required this.phase,
    this.totalSongs = 0,
    this.cachedSongs = 0,
    this.missingSongs = 0,
    this.message,
  });
}

final companionAnalysisSyncProvider =
    StreamProvider<CompanionAnalysisStatus>((ref) async* {
  final api = ref.watch(companionAudioApiProvider);
  final available = ref.watch(companionAvailableProvider).valueOrNull ?? false;
  if (api == null || !available) {
    yield const CompanionAnalysisStatus(
      phase: CompanionAnalysisPhase.unavailable,
      message: 'Companion offline',
    );
    return;
  }

  final songs = ref.watch(allSongsProvider).valueOrNull ?? const <Song>[];
  if (songs.isEmpty) {
    yield const CompanionAnalysisStatus(phase: CompanionAnalysisPhase.ready);
    return;
  }

  final results = await api.getAllResults();
  final cachedIds = <String>{
    for (final r in results)
      if (r['song_id'] != null) r['song_id'].toString(),
  };
  final missing = songs
      .where((s) => !s.id.startsWith('deezer:') && !cachedIds.contains(s.id))
      .map((s) => s.id)
      .toList();

  if (missing.isEmpty) {
    yield CompanionAnalysisStatus(
      phase: CompanionAnalysisPhase.ready,
      totalSongs: songs.length,
      cachedSongs: cachedIds.length,
    );
    return;
  }

  yield CompanionAnalysisStatus(
    phase: CompanionAnalysisPhase.queued,
    totalSongs: songs.length,
    cachedSongs: cachedIds.length,
    missingSongs: missing.length,
  );

  final job = await api.startAnalysis(songIds: missing);
  final jobId = job?['job_id']?.toString() ?? job?['jobId']?.toString();
  if (jobId == null || jobId.isEmpty) {
    yield CompanionAnalysisStatus(
      phase: CompanionAnalysisPhase.error,
      totalSongs: songs.length,
      cachedSongs: cachedIds.length,
      missingSongs: missing.length,
      message: 'Could not start analysis',
    );
    return;
  }

  for (var attempt = 0; attempt < 120; attempt++) {
    await Future.delayed(const Duration(seconds: 3));
    final status = await api.pollAnalysis(jobId);
    final raw = status?['status']?.toString().toLowerCase();
    final done = raw == 'done' || raw == 'complete' || raw == 'completed';
    final failed = raw == 'error' || raw == 'failed';

    if (done) {
      ref.invalidate(companionAnalysisProvider);
      yield CompanionAnalysisStatus(
        phase: CompanionAnalysisPhase.ready,
        totalSongs: songs.length,
        cachedSongs: songs.length,
      );
      return;
    }
    if (failed) {
      yield CompanionAnalysisStatus(
        phase: CompanionAnalysisPhase.error,
        totalSongs: songs.length,
        cachedSongs: cachedIds.length,
        missingSongs: missing.length,
        message: status?['error']?.toString() ?? 'Analysis failed',
      );
      return;
    }

    yield CompanionAnalysisStatus(
      phase: CompanionAnalysisPhase.running,
      totalSongs: songs.length,
      cachedSongs: cachedIds.length,
      missingSongs: missing.length,
      message: raw,
    );
  }

  yield CompanionAnalysisStatus(
    phase: CompanionAnalysisPhase.error,
    totalSongs: songs.length,
    cachedSongs: cachedIds.length,
    missingSongs: missing.length,
    message: 'Analysis timed out',
  );
});

/// Four-state readable status for the user's Deezer ARL cookie.
///
/// `notSet`      — user never pasted an ARL. No banner, no red chip; the app
///                 is just in "previews only" mode.
/// `valid`       — Deezer's gw-light endpoint returned a non-zero USER_ID.
/// `invalid`     — ARL set but Deezer rejected it (expired, malformed, etc.)
///                 → surface an actionable banner / red tile so the user knows
///                 *before* they hit a mystery "download failed" on the server.
/// `unreachable` — Network error (timeout, DNS, TLS) reaching Deezer.
///                 Don't blame the ARL — show a non-alarming info banner
///                 instead of a red "session expired" alert.
enum DeezerArlStatus { notSet, valid, invalid, unreachable }

/// Validates the configured Deezer ARL by calling Deezer's gw-light endpoint
/// directly — no companion round-trip needed. Re-runs automatically whenever
/// `preferencesNotifierProvider` emits a new ARL via `ref.watch`.
final deezerArlStatusProvider = FutureProvider<DeezerArlStatus>((ref) async {
  final arl = ref.watch(
    preferencesNotifierProvider.select((p) => p.deezerArl),
  );
  if (arl.isEmpty) return DeezerArlStatus.notSet;
  // Watching connectivity re-checks the ARL when the connection returns.
  if (_deviceOffline(ref)) return DeezerArlStatus.unreachable;
  try {
    final ok = await DeezerClient.validateArl(arl);
    return ok ? DeezerArlStatus.valid : DeezerArlStatus.invalid;
  } on DioException {
    return DeezerArlStatus.unreachable;
  } catch (_) {
    return DeezerArlStatus.unreachable;
  }
});

/// Rich Deezer account status — checks ARL validity AND subscription tier.
/// Used in the Deezer settings screen to warn about expired plans.
final deezerAccountStatusProvider =
    FutureProvider<DeezerAccountStatus>((ref) async {
  final arl = ref.watch(
    preferencesNotifierProvider.select((p) => p.deezerArl),
  );
  if (arl.isEmpty) return const DeezerAccountStatus();
  // Errors propagate: "couldn't check" must not look like "no subscription".
  return DeezerClient.checkAccountStatus(arl);
});

Future<void> deleteSongFromServer(WidgetRef ref, Song song) async {
  final companion = ref.read(companionClientProvider);
  if (companion == null) throw Exception('Companion not configured');

  // 0. Mark as pending-delete so it's filtered from the song list immediately,
  //    even if the server re-returns it before the rescan completes.
  ref.read(_pendingDeleteIdsProvider.notifier).update((s) => {...s, song.id});

  // 1. Delete file on server
  await companion.deleteSong(song.id);

  // 2. Trigger a Navidrome rescan (non-fatal if it fails), then purge the
  //    song from Navidrome's "missing files" list once the scan flags it,
  //    otherwise it lingers there forever. Runs in the background.
  final subsonic = ref.read(subsonicClientProvider);
  final config = ref.read(serverConfigProvider).valueOrNull;
  if (subsonic != null) {
    unawaited(subsonic.startScan().then((_) {
      if (config == null) return null;
      return purgeDeletedSongs(
        subsonic: subsonic,
        native: NavidromeNativeClient(config),
        songIds: [song.id],
      );
    }));
  }

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

final queueSnapshotStreamProvider =
    StreamProvider<PlaybackQueueSnapshot>((ref) {
  final handler = ref.watch(audioHandlerNotifierProvider);
  if (handler == null) return Stream.value(PlaybackQueueSnapshot.empty());
  return (() async* {
    yield handler.queueSnapshot;
    yield* handler.queueSnapshotStream;
  })();
});

final shuffleModeStreamProvider = StreamProvider<ShuffleMode>((ref) {
  final handler = ref.watch(audioHandlerNotifierProvider);
  if (handler == null) return Stream.value(ShuffleMode.off);
  return handler.shuffleModeStream;
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

  List<Song> filter(List<Song> songs) => deletedIds.isEmpty
      ? songs
      : songs.where((s) => !deletedIds.contains(s.id)).toList();

  // Always emit cached songs immediately (with correct isDownloaded from DB)
  final cached = await db.getAllCachedSongs();
  yield filter(cached.map(_rowToSong).toList());

  // Offline the cached library is the whole answer; the refresh runs when
  // the connection returns (watching connectivity re-runs this provider).
  if (client != null && !_deviceOffline(ref)) {
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
      // Only write when the set actually shrinks: this provider watches it,
      // and a new-but-equal Set would rebuild it and refetch the whole
      // library in a loop for as long as the server still returns the song.
      if (deletedIds.isNotEmpty) {
        final stillPending = deletedIds.intersection(freshIds);
        if (stillPending.length != deletedIds.length) {
          ref.read(_pendingDeleteIdsProvider.notifier).state = stillPending;
        }
      }
      yield filter(updatedSongs);
      ref.read(librarySyncErrorProvider.notifier).state = null;
    } catch (e) {
      // Keep showing the cached library (that is what makes the app usable
      // offline), but record the failure so the Library screen says the
      // list is stale instead of passing it off as current.
      debugPrint('Library refresh failed: $e');
      ref.read(librarySyncErrorProvider.notifier).state = e;
    }
  }
});

/// Why the last library refresh from the server failed, or null when it
/// succeeded. The library still shows the cached songs; the UI uses this to
/// say that they may be out of date.
final librarySyncErrorProvider = StateProvider<Object?>((_) => null);

// --- Likes ---
// A like is a Subsonic star, so it syncs with Navidrome's web UI and other
// clients. Deezer recommendations can't be starred until they're in the
// library: liking one stores a pending like and asks the companion to add
// it; the next library sync that contains it stars it and drops the row.

/// Liked Deezer tracks that are not in the server library yet.
final pendingLikesProvider = StreamProvider<List<PendingLike>>(
    (ref) => ref.watch(databaseProvider).watchPendingLikes());

/// Ids of liked library songs. Kept alive by MainShell so pending likes are
/// reconciled on every library sync, whichever screen is open.
final likesProvider = StateNotifierProvider<LikesNotifier, Set<String>>(
    (ref) => LikesNotifier(ref));

/// Whether [songId] (a library id or `deezer:<id>`) is liked.
final isLikedProvider = Provider.family<bool, String>((ref, songId) {
  if (songId.startsWith('deezer:')) {
    final id = int.tryParse(songId.substring('deezer:'.length));
    final pending = ref.watch(pendingLikesProvider).valueOrNull ?? const [];
    return pending.any((p) => p.deezerId == id);
  }
  return ref.watch(likesProvider.select((ids) => ids.contains(songId)));
});

/// Liked library songs, newest like first.
final likedSongsProvider = Provider<AsyncValue<List<Song>>>((ref) {
  final ids = ref.watch(likesProvider);
  final likes = ref.read(likesProvider.notifier);
  return ref.watch(allSongsProvider).whenData((songs) {
    final liked = [
      for (final s in songs)
        if (ids.contains(s.id)) s.withStarred(likes.likedAt(s) ?? s.starred)
    ]..sort((a, b) {
        final at = a.starred, bt = b.starred;
        if (at == null || bt == null) return at == null ? 1 : -1;
        return bt.compareTo(at);
      });
    return liked;
  });
});

class LikesNotifier extends StateNotifier<Set<String>> {
  final Ref _ref;
  // Like (true) / unlike (false) requests still waiting for the server.
  final _inFlight = <String, bool>{};
  // Likes made in this session; the library list still carries the old
  // server timestamp until its next sync.
  final _likedAt = <String, DateTime>{};
  bool _reconciling = false;

  /// When [song] was liked in this session, if it was.
  DateTime? likedAt(Song song) => _likedAt[song.id];

  LikesNotifier(this._ref) : super(const {}) {
    _ref.listen<AsyncValue<List<Song>>>(allSongsProvider, (_, next) {
      final songs = next.valueOrNull;
      if (songs == null) return;
      state = mergeLikes(songs, _inFlight);
      _reconcilePending(songs);
    }, fireImmediately: true);
  }

  /// Likes or unlikes a library song. The heart flips at once and flips back
  /// if the server refuses; that failure is reported as an error snackbar.
  /// Returns the new state.
  Future<bool> toggle(Song song) async {
    if (song.isExternal) {
      throw ArgumentError.value(
          song.id, 'song', 'is a Deezer track; use likeRecommendation');
    }
    final like = !state.contains(song.id);
    await _setLiked(song, like);
    return like;
  }

  Future<void> _setLiked(Song song, bool like) async {
    final client = _ref.read(subsonicClientProvider);
    if (client == null) {
      AppErrors.report('Connect a server to like songs');
      return;
    }
    _inFlight[song.id] = like;
    if (like) {
      _likedAt[song.id] = DateTime.now();
    } else {
      _likedAt.remove(song.id);
    }
    state = like ? {...state, song.id} : ({...state}..remove(song.id));
    try {
      if (like) {
        await client.star(song.id);
      } else {
        await client.unstar(song.id);
      }
      await _ref
          .read(databaseProvider)
          .setSongStarred(song.id, like ? DateTime.now() : null);
      if (like && _ref.read(preferencesNotifierProvider).downloadLikedOffline) {
        await _ref.read(downloadNotifierProvider.notifier).download(song);
      }
    } catch (e) {
      if (mounted) {
        state = like ? ({...state}..remove(song.id)) : {...state, song.id};
      }
      AppErrors.report(
          like ? "Couldn't like \"${song.title}\"" : "Couldn't unlike \"${song.title}\"",
          e);
    } finally {
      _inFlight.remove(song.id);
    }
  }

  /// Saves a like on a Deezer track. The caller then asks the companion to
  /// add it to the server library; the like is applied when it arrives.
  Future<void> likeRecommendation(Song song) async {
    final deezerId = deezerIdOf(song);
    if (deezerId == null) {
      throw ArgumentError.value(song.id, 'song', 'is not a Deezer track');
    }
    await _ref.read(databaseProvider).addPendingLike(PendingLikesCompanion.insert(
          deezerId: Value(deezerId),
          title: song.title,
          artist: song.artist,
          album: song.album,
          duration: Value(song.duration),
          coverUrl: Value(song.externalCoverUrl),
          previewUrl: Value(song.externalStreamUrl),
        ));
  }

  Future<void> unlikeRecommendation(int deezerId) =>
      _ref.read(databaseProvider).removePendingLike(deezerId);

  /// Stars every pending like that has arrived in [library].
  Future<void> _reconcilePending(List<Song> library) async {
    if (_reconciling) return;
    _reconciling = true;
    try {
      final db = _ref.read(databaseProvider);
      final pending = await db.getPendingLikes();
      if (pending.isEmpty) return;
      final matches = matchPendingLikes(
        [
          for (final p in pending)
            (deezerId: p.deezerId, title: p.title, artist: p.artist)
        ],
        library,
      );
      for (final (like, song) in matches) {
        if (!mounted) return;
        if (!state.contains(song.id)) await _setLiked(song, true);
        // Only drop the pending row once the star stuck; a failed star was
        // reported and is retried on the next sync.
        if (state.contains(song.id)) await db.removePendingLike(like.deezerId);
      }
    } catch (e) {
      AppErrors.report("Couldn't apply likes to newly added songs", e);
    } finally {
      _reconciling = false;
    }
  }
}

/// Whether the device has no network at all. Watching it makes a provider
/// re-run when the connection comes back, so a section that failed offline
/// fills itself in without a manual refresh.
///
/// Selects the plain bool so the startup "loading → online" step doesn't
/// count as a change and fire every server request twice.
bool _deviceOffline(Ref ref) =>
    !ref.watch(isOnlineProvider.select((v) => v.valueOrNull ?? true));

/// The on-device library cache, for views that work offline.
Future<List<Song>> _cachedSongs(Ref ref) async {
  final rows = await ref.read(databaseProvider).getAllCachedSongs();
  return rows.map(_rowToSong).toList();
}

final randomSongsProvider = FutureProvider<List<Song>>((ref) async {
  final client = ref.watch(subsonicClientProvider);
  if (client == null) return [];
  if (_deviceOffline(ref)) throw const DeviceOfflineException();
  return await client.getRandomSongs(count: 20);
});

final deezerClientProvider = Provider<DeezerClient>((_) => DeezerClient());

/// When set, [recommendationsProvider] builds the next list around this
/// artist ("More like this" on a recommendation card or in the player).
///
/// The consumer clears it back to null before a plain refresh, so the next
/// refresh goes back to the user's whole taste.
typedef RecommendationSeed = ({String artist, String title, String? genre});

final recommendationsSeedOverrideProvider =
    StateProvider<RecommendationSeed?>((_) => null);

/// "Not interested" choices, newest first. Home hides matching cards at once
/// (and shows them again on Undo) without rebuilding the list.
final dismissedRecsProvider = StreamProvider<List<DismissedRec>>(
    (ref) => ref.watch(databaseProvider).watchDismissedRecs());

/// Key of a "Not interested: this song" row.
String dismissedTrackKey(String title, String artist) =>
    'track:${keyFor(title, artist)}';

/// Key of a "Not interested: this artist" row.
String dismissedArtistKey(String artist) => 'artist:${normalize(artist)}';

/// Whether [song] is hidden by any of [dismissed].
bool isDismissed(Song song, Iterable<DismissedRec> dismissed) {
  final track = dismissedTrackKey(song.title, song.artist);
  final artist = dismissedArtistKey(song.artist);
  return dismissed.any((d) => d.key == track || d.key == artist);
}

/// Collects everything the taste model reads from the local database:
/// play history (with skips), likes, server play counts, "Not interested",
/// "More like this" taps and how often each card was shown.
Future<TasteSignals> loadTasteSignals(AppDatabase db) async {
  final library = await db.getAllCachedSongs();
  final genreByArtist = <String, String>{};
  final plays = <String, int>{};
  final likes = <LikedTrack>[];
  final owned = <String>{};
  for (final s in library) {
    owned.add(keyFor(s.title, s.artist));
    final g = s.genre;
    if (g != null && g.isNotEmpty) genreByArtist.putIfAbsent(s.artist, () => g);
    final n = s.playCount ?? 0;
    if (n > 0) plays[s.artist] = (plays[s.artist] ?? 0) + n;
    if (s.starred != null) {
      likes.add(LikedTrack(artist: s.artist, title: s.title, genre: s.genre));
    }
  }
  for (final p in await db.getPendingLikes()) {
    likes.add(LikedTrack(artist: p.artist, title: p.title));
  }
  final history = [
    for (final h in await db.getRecentHistory(limit: 5000))
      ListenEvent(
        artist: h.artist,
        title: h.songTitle,
        at: h.playedAt,
        genre: genreByArtist[h.artist],
        skipped: h.skipped,
      ),
  ];
  final dismissedTracks = <String>{};
  final dismissedArtists = <String>{};
  final dismissalsByArtist = <String, int>{};
  for (final d in await db.getDismissedRecs()) {
    if (d.kind == 'artist') {
      dismissedArtists.add(d.artist);
    } else {
      dismissedTracks.add(keyFor(d.title ?? '', d.artist));
      dismissalsByArtist[d.artist] = (dismissalsByArtist[d.artist] ?? 0) + 1;
    }
  }
  return TasteSignals(
    history: history,
    likes: likes,
    serverPlaysByArtist: plays,
    genreByArtist: genreByArtist,
    dismissedTracks: dismissedTracks,
    dismissedArtists: dismissedArtists,
    dismissalsByArtist: dismissalsByArtist,
    moreLikeThis: await db.getMoreLikeThis(),
    impressions: await db.getImpressions(),
    ownedTracks: owned,
  );
}

/// Discovers NEW tracks for Home with the taste model
/// (`lib/core/recs/taste_model.dart`): seed artists come from likes, recent
/// and long-term listening; their Deezer artist radios are ranked by how
/// well each track fits the user's taste, minus anything owned or hidden.
///
/// Failures are explicit: no taste yet → [RecsEmptyNoHistory]; Deezer down,
/// no radio, or nothing new → [RecsError] with the reason. A partial list
/// lists the seed artists whose radio failed in [RecsReady.failedSeeds].
///
/// Intentionally NOT autoDispose: the refresh button's `ref.invalidate` is
/// the only retry trigger, so navigating doesn't reshuffle the list.
final recommendationsProvider =
    FutureProvider<RecommendationsState>((ref) async {
  final db = ref.watch(databaseProvider);
  final client = ref.watch(subsonicClientProvider);
  final deezer = ref.watch(deezerClientProvider);
  final override = ref.watch(recommendationsSeedOverrideProvider);
  // read, not watch: moving the slider applies on the next refresh instead
  // of reshuffling the list under the user's finger.
  final discovery = ref.read(preferencesNotifierProvider).recDiscovery;

  if (client == null) {
    return const RecsError(
        'Connect a server in Settings to get recommendations.');
  }
  // Recommendations come from Deezer. Offline, say so at once instead of
  // retrying every seed into DNS failures; watching connectivity reloads
  // them when the connection comes back.
  if (_deviceOffline(ref)) {
    return const RecsError('Recommendations need an internet connection.');
  }

  final signals = await loadTasteSignals(db);
  final titleOf = <String, String>{
    for (final e in signals.history.reversed) normalize(e.artist): e.title,
    for (final l in signals.likes) normalize(l.artist): l.title,
    if (override != null) normalize(override.artist): override.title,
  };
  final genreOf = <String, String>{
    for (final e in signals.genreByArtist.entries) normalize(e.key): e.value,
    if (override?.genre != null) normalize(override!.artist): override.genre!,
  };

  // Throws on failure: the model tells "Deezer is down" apart from "no
  // radio" only if errors reach it.
  Future<List<RecommendedTrack>> radio(TasteSeed seed) async {
    final key = normalize(seed.artist);
    final id = await deezer.searchBestArtist(
      artistName: seed.artist,
      trackTitle: titleOf[key],
      genreHint: genreOf[key],
    );
    if (id == null) throw NoDeezerRadio(seed.artist);
    final tracks = await deezer.artistRadio(id, limit: 20);
    if (tracks.isEmpty) throw NoDeezerRadio(seed.artist);
    return tracks;
  }

  final RecommendationResult result;
  try {
    result = await recommend(
      signals: signals,
      now: DateTime.now(),
      radio: radio,
      rng: Random(),
      weights: TasteWeights(discovery: discovery),
      focusArtist: override?.artist,
    );
  } on NoTasteYet {
    return const RecsEmptyNoHistory();
  } on AllRadiosFailed catch (e) {
    final reached = e.errors.values.whereType<NoDeezerRadio>();
    final network =
        e.errors.values.where((err) => err is! NoDeezerRadio).toList();
    if (network.isEmpty) {
      return RecsError(NoRadioTracks([for (final r in reached) r.artist])
          .message);
    }
    return RecsError('Could not reach Deezer for ${network.length} of '
        '${e.errors.length} artists: ${describeError(network.first)}');
  } on FocusRadioFailed catch (e) {
    return RecsError("Couldn't load songs like ${e.artist} from Deezer: "
        '${describeError(e.error)}');
  } on RecsFailure catch (e) {
    return RecsError(e.message);
  }

  final tracks = result.tracks;
  // Warm cover-art disk cache. CachedNetworkImageProvider writes through
  // to disk on resolve; fire-and-forget so a slow image host can't stall
  // the whole provider.
  for (final t in tracks) {
    final url = t.track.coverUrl;
    if (url != null && url.isNotEmpty) {
      CachedNetworkImageProvider(url).resolve(const ImageConfiguration());
    }
  }
  // Shown once more; fatigue lowers a card the user keeps ignoring. Playing
  // it clears the count (see the history listener in main.dart).
  try {
    await db.countImpressions(
        [for (final t in tracks) keyFor(t.track.title, t.track.artist)]);
  } catch (e) {
    AppErrors.report("Couldn't save which recommendations were shown", e);
  }

  final songs = <Song>[];
  final reasons = <String, TasteSeed>{};
  for (final s in tracks) {
    final t = s.track;
    final song = Song.fromRecommendation(
      deezerId: t.deezerId,
      title: t.title,
      artist: t.artist,
      album: t.album,
      durationSeconds: t.durationSeconds,
      previewUrl: t.previewUrl,
      coverUrl: t.coverUrl,
      bpm: t.bpm,
      genre: t.genre,
    );
    songs.add(song);
    reasons[song.id] = s.because;
  }
  return RecsReady(songs,
      reasons: reasons, failedSeeds: result.failedSeeds.keys.toList());
});

// Deezer catalog search — powers the "From Deezer" section in the search tab.
// Not autoDispose: search tab lives in IndexedStack and never unmounts.
final deezerSearchProvider =
    FutureProvider<List<RecommendedTrack>>((ref) async {
  final query = ref.watch(searchQueryProvider).trim();
  if (query.length < 2) return [];
  // Offline: fail at once with a clear reason instead of a DNS error after
  // a timeout. The search screen hides Deezer results while offline.
  if (_deviceOffline(ref)) throw const DeviceOfflineException();
  // Let errors reach the UI so a Deezer/network failure is not presented as
  // "no results". This request is also tied to the current query state.
  return ref.watch(deezerClientProvider).search(query);
});

/// Deezer's id for an artist name, or null when Deezer has no match.
/// Shared by the artist page's Deezer sections so the name is resolved once.
final deezerArtistIdProvider =
    FutureProvider.autoDispose.family<int?, String>((ref, artistName) async {
  if (artistName.trim().isEmpty) return null;
  if (_deviceOffline(ref)) throw const DeviceOfflineException();
  return ref
      .watch(deezerClientProvider)
      .searchBestArtist(artistName: artistName);
});

// Deezer top tracks for a specific artist — used on the artist detail page to
// surface songs the user doesn't own yet. Resolves the artist name → Deezer ID
// first (searchBestArtist), then fetches real top tracks (not the radio mix).
// Tracks already in the library are filtered out so this section is discovery-
// only; library tracks are already visible in Albums / Songs.
final deezerArtistTracksProvider = FutureProvider.autoDispose
    .family<List<RecommendedTrack>, String>((ref, artistName) async {
  final artistId = await ref.watch(deezerArtistIdProvider(artistName).future);
  if (artistId == null) return [];
  final deezer = ref.watch(deezerClientProvider);

  final tracks = await deezer.artistTopTracks(artistId, limit: 15);
  if (tracks.isEmpty) return [];

  // Cross-check against the cached library to skip tracks the user already owns.
  final library = ref.read(allSongsProvider).valueOrNull ?? const <Song>[];
  final owned = <String>{
    for (final s in library) keyFor(s.title, s.artist),
  };

  return tracks
      .where((t) => !owned.contains(keyFor(t.title, t.artist)))
      .toList();
});

/// The Deezer artist (picture, fan count), or null when Deezer has no match.
final deezerArtistProvider = FutureProvider.autoDispose
    .family<DeezerArtist?, String>((ref, artistName) async {
  final id = await ref.watch(deezerArtistIdProvider(artistName).future);
  if (id == null) return null;
  return ref.watch(deezerClientProvider).artist(id);
});

/// Deezer's related artists for an artist name.
final deezerRelatedArtistsProvider = FutureProvider.autoDispose
    .family<List<DeezerArtist>, String>((ref, artistName) async {
  final id = await ref.watch(deezerArtistIdProvider(artistName).future);
  if (id == null) return const [];
  return ref.watch(deezerClientProvider).relatedArtists(id);
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
  if (_deviceOffline(ref)) throw const DeviceOfflineException();
  return await client.getNewestAlbums(size: 20);
});

final allAlbumsProvider = FutureProvider<List<Album>>((ref) async {
  final client = ref.watch(subsonicClientProvider);
  if (client == null) return [];
  // Offline: the albums of the cached library (the offline banner says why
  // the list may be incomplete).
  if (_deviceOffline(ref)) return albumsFromSongs(await _cachedSongs(ref));
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
});

final albumSongsProvider =
    FutureProvider.family<List<Song>, String>((ref, albumId) async {
  final client = ref.watch(subsonicClientProvider);
  if (client == null) return [];
  if (_deviceOffline(ref)) {
    return cachedAlbumSongs(await _cachedSongs(ref), albumId);
  }
  return await client.getAlbumSongs(albumId);
});

// --- Artists ---
final allArtistsProvider = FutureProvider<List<Artist>>((ref) async {
  final client = ref.watch(subsonicClientProvider);
  if (client == null) return [];
  if (_deviceOffline(ref)) return artistsFromSongs(await _cachedSongs(ref));
  return await client.getArtists();
});

final artistAlbumsProvider =
    FutureProvider.family<List<Album>, String>((ref, artistId) async {
  final client = ref.watch(subsonicClientProvider);
  if (client == null) return [];
  if (_deviceOffline(ref)) {
    return albumsFromSongs(
        cachedArtistSongs(await _cachedSongs(ref), artistId));
  }
  return await client.getArtistAlbums(artistId);
});

// Top songs for an artist by name (Navidrome/Last.fm backed). Servers without
// Last.fm answer with an empty list; a failed request is an error.
final artistTopSongsProvider =
    FutureProvider.family<List<Song>, String>((ref, artistName) async {
  final client = ref.watch(subsonicClientProvider);
  if (client == null) return [];
  if (_deviceOffline(ref)) throw const DeviceOfflineException();
  return client.getTopSongs(artistName);
});

/// Biography, image and similar artists from the server (Last.fm backed).
/// Online only; the page hides the sections that need it while offline.
final artistInfoProvider = FutureProvider.autoDispose
    .family<ArtistInfo, String>((ref, artistId) async {
  final client = ref.watch(subsonicClientProvider);
  if (client == null) return ArtistInfo.empty;
  if (_deviceOffline(ref)) throw const DeviceOfflineException();
  return client.getArtistInfo2(artistId);
});

/// The whole local play history as [PlayRecord]s, newest first. autoDispose
/// so reopening an artist page picks up plays made since.
final playRecordsProvider =
    FutureProvider.autoDispose<List<PlayRecord>>((ref) async {
  final rows = await ref.watch(databaseProvider).getAllHistory();
  return [
    for (final h in rows)
      (
        songId: h.songId,
        title: h.songTitle,
        artist: h.artist,
        coverArt: h.coverArt,
        playedAt: h.playedAt,
      ),
  ];
});

/// The "Your listening" card for an artist name; null below 3 plays.
final artistListeningStatsProvider = FutureProvider.autoDispose
    .family<ArtistListeningStats?, String>((ref, artistName) async {
  final history = await ref.watch(playRecordsProvider.future);
  return listeningStats(artistName, history);
});

// All songs by an artist — fetches each album's tracks in parallel.
final artistAllSongsProvider =
    FutureProvider.family<List<Song>, String>((ref, artistId) async {
  final client = ref.watch(subsonicClientProvider);
  if (client == null) return [];
  if (_deviceOffline(ref)) {
    return cachedArtistSongs(await _cachedSongs(ref), artistId);
  }
  final albums = await client.getArtistAlbums(artistId);
  final perAlbum =
      await Future.wait(albums.map((a) => client.getAlbumSongs(a.id)));
  return perAlbum.expand((songs) => songs).toList();
});

// --- Playlists ---
final playlistsProvider = FutureProvider<List<Playlist>>((ref) async {
  final client = ref.watch(subsonicClientProvider);
  if (client == null) return const [];
  if (_deviceOffline(ref)) throw const DeviceOfflineException();
  return await client.getPlaylists();
});

final playlistSongsProvider =
    FutureProvider.family<List<Song>, String>((ref, playlistId) async {
  final client = ref.watch(subsonicClientProvider);
  if (client == null) return [];
  if (_deviceOffline(ref)) throw const DeviceOfflineException();
  return await client.getPlaylistSongs(playlistId);
});

// --- Search ---
/// App-wide failures for the main shell to show. autoDispose on purpose:
/// while no shell is listening (setup screen), [AppErrors] buffers instead
/// of delivering into a provider nobody watches.
final appErrorStreamProvider =
    StreamProvider.autoDispose<AppError>((_) => AppErrors.stream);

final searchQueryProvider = StateProvider<String>((_) => '');

final searchResultsProvider = FutureProvider<SearchResults>((ref) async {
  final query = ref.watch(searchQueryProvider).trim();
  if (query.isEmpty) return SearchResults.empty();

  final client = ref.watch(subsonicClientProvider);
  if (client == null) return SearchResults.empty();

  Future<SearchResults> fromCache() async {
    final rows = await ref.read(databaseProvider).getAllCachedSongs();
    return searchCachedLibrary(rows.map(_rowToSong).toList(), query);
  }

  // Offline: search the library cache instead of waiting for the request
  // to time out. The screen labels these results as coming from the cache.
  if (_deviceOffline(ref)) return fromCache();

  // Riverpod scopes this request to the current query, so a newer query
  // cannot be replaced by an older response.
  try {
    return await client.search(query);
  } catch (e) {
    // A connection failure (flaky mobile data, VPN, server host down) falls
    // back to the cache, labelled as such. Anything else, like rejected
    // credentials or a server error, stays an error the screen shows.
    if (isConnectionError(e)) return fromCache();
    rethrow;
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

/// Caches [result] for offline use. Never lets a plain-only result clobber a
/// cached row that already has synced lyrics, and swallows DB errors so a
/// cache failure can never fail lyrics display or a download.
Future<void> _persistLyrics(
  AppDatabase db,
  String songId,
  LyricsResult result,
) async {
  try {
    if (result.synced == null) {
      final existing = await db.getCachedLyrics(songId);
      if (existing?.syncedLyrics != null) return; // keep the better row
    }
    await db.cacheLyrics(songId, result.plain, result.synced);
  } catch (_) {
    // Cache write failures are non-fatal.
  }
}

/// Fetches lyrics with an LRCLIB → lyrics.ovh fallback. Shared by
/// [lyricsProvider] and the download pre-cache so both paths follow the same
/// cache/fallback rules. Throws when every provider failed for transport or
/// server reasons (as opposed to "no lyrics for this track").
///
/// Rules:
///  * an existing usable cache row wins immediately (offline availability);
///  * an unusable legacy cache row is overwritten on success, healing it;
///  * after the [cancelToken] fires, remaining network work is skipped;
///  * a plain-only ovh result is returned for display but NOT cached when
///    LRCLIB failed transiently (as opposed to a definitive 404): caching it
///    would permanently shadow a later synced fetch (rows have no TTL);
///  * when [networkAllowed] is false (device offline) only the cache is
///    consulted, so opening lyrics never blocks on network timeouts.
Future<LyricsResult?> _fetchLyrics({
  required AppDatabase db,
  required LyricsQuery q,
  CancelToken? cancelToken,
  bool networkAllowed = true,
}) async {
  // Cache first: lyrics are available offline and cache hits avoid the
  // network entirely.
  try {
    final cached = await db.getCachedLyrics(q.songId);
    if (cached != null) {
      final cachedResult = LyricsResult(
        plain: cached.plainLyrics,
        synced: cached.syncedLyrics,
      );
      if (cachedResult.isUsable) return cachedResult;
    }
  } catch (_) {
    // Treat DB errors as a cache miss.
  }

  if (!networkAllowed || (cancelToken?.isCancelled ?? false)) return null;

  // LRCLIB first: it can return synced lyrics.
  LyricsResult? result;
  var lrcDefinitiveMiss = false;
  var fromOvh = false;
  // Transport/server failures (not "no lyrics for this track"). When
  // nothing was found and a provider failed, the answer is unknown, and the
  // UI must say so rather than claim there are no lyrics.
  Object? providerError;
  try {
    final lrc = await LrcLibClient().getLyrics(
      artist: q.artist,
      title: q.title,
      album: q.album,
      duration: q.duration,
      cancelToken: cancelToken,
    );
    if (lrc == null) {
      // HTTP 404 — LRCLIB definitively has no record for this track.
      lrcDefinitiveMiss = true;
    } else if (lrc.isUsable) {
      result = lrc;
    }
  } on DioException catch (e) {
    if (e.type == DioExceptionType.cancel) return null;
    // Other transport failures fall through to the plain-lyrics fallback.
    providerError = e;
  } catch (e) {
    providerError = e;
  }

  if (result == null) {
    try {
      final plain = await LyricsOvhClient().getLyrics(
        artist: q.artist,
        title: q.title,
        cancelToken: cancelToken,
      );
      if (plain != null && plain.trim().isNotEmpty) {
        result = LyricsResult(plain: plain.trim());
        fromOvh = true;
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) return null;
      providerError = e;
    } catch (e) {
      providerError = e;
    }
  }

  if (result == null || !result.isUsable) {
    if (providerError != null) throw providerError;
    return null;
  }

  if (fromOvh && !lrcDefinitiveMiss) return result; // display only
  await _persistLyrics(db, q.songId, result);
  return result;
}

final lyricsProvider = FutureProvider.autoDispose
    .family<LyricsResult?, LyricsQuery>((ref, q) async {
  final db = ref.read(databaseProvider);

  // Cancel in-flight provider work when the lyrics page/song is abandoned.
  final cancel = CancelToken();
  ref.onDispose(cancel.cancel);

  // Skip the network entirely when the device is offline: the cache is the
  // only possible source anyway, and the fallback timeouts would otherwise
  // stall lyrics for tens of seconds.
  final online = ref.read(isOnlineProvider).valueOrNull ?? true;
  return _fetchLyrics(
    db: db,
    q: q,
    cancelToken: cancel,
    networkAllowed: online,
  );
});

// --- Preferences ---
class PreferencesNotifier extends StateNotifier<AppPreferences> {
  PreferencesNotifier() : super(const AppPreferences()) {
    _load();
  }

  /// Fixed preferences that are never loaded from or saved to disk (tests).
  PreferencesNotifier.inMemory(super.prefs) : _inMemory = true;

  bool _inMemory = false;

  Future<void> _load() async {
    final prefs = await AppPreferences.load();
    if (mounted) state = prefs;
  }

  Future<void> update(AppPreferences prefs) async {
    state = prefs;
    if (_inMemory) return;
    try {
      await prefs.save();
    } catch (e) {
      // The change is live for this session but will be lost on restart.
      AppErrors.report("Couldn't save settings", e);
    }
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
//
// A download is complete only when the audio AND its cover art are on disk;
// lyrics are fetched too but are optional (most tracks have none). The queue
// is persisted in the DownloadQueue table so it survives restarts, and
// failures stay visible (with their reason and a Retry action) until the user
// retries or dismisses them.
class DownloadItem {
  final Song song;
  final double progress; // 0.0 – 1.0
  // status: 'queued' | 'downloading' | 'done' | 'error'
  final String status;
  final String? errorMessage;
  final String quality;
  const DownloadItem({
    required this.song,
    required this.progress,
    required this.status,
    this.errorMessage,
    this.quality = 'lossless',
  });

  bool get isActive => status == 'queued' || status == 'downloading';
}

/// A one-shot message for the shell's snackbar. [id] makes repeated identical
/// messages distinct so the listener still fires.
class DownloadNotice {
  final int id;
  final String message;
  final bool isError;
  const DownloadNotice(this.id, this.message, {this.isError = false});
}

final downloadNoticeProvider = StateProvider<DownloadNotice?>((_) => null);

class _DownloadTask {
  final Song song;
  final String quality;
  final bool force;
  const _DownloadTask({
    required this.song,
    required this.quality,
    required this.force,
  });
}

class DownloadNotifier extends StateNotifier<Map<String, DownloadItem>> {
  final AppDatabase _db;
  final Ref _ref;

  // At most 2 simultaneous HTTP downloads to keep the device responsive.
  static const _maxConcurrent = 2;
  final _queue = Queue<_DownloadTask>();
  final _active = <String, CancelToken>{};
  bool _online = true;

  // A "session" runs from the first enqueue until the queue drains. Batch
  // downloads report one summary at the end instead of one snackbar per song.
  int _sessionTotal = 0;
  int _sessionDone = 0;
  int _sessionFailed = 0;
  bool _sessionErrorShown = false;
  int _noticeSeq = 0;
  // Set while the notifier is torn down: its cancels are not user cancels,
  // so queue rows are kept for the next start to resume.
  bool _disposing = false;

  DownloadNotifier(this._db, this._ref) : super({}) {
    _online = _ref.read(isOnlineProvider).valueOrNull ?? true;
    Future.microtask(_restore);
  }

  @override
  void dispose() {
    _disposing = true;
    for (final token in _active.values) {
      token.cancel('disposed');
    }
    _queue.clear();
    super.dispose();
  }

  String get _defaultQuality =>
      _ref.read(preferencesNotifierProvider).downloadQuality;

  void _notice(String message, {bool isError = false}) {
    if (!mounted) return;
    _ref.read(downloadNoticeProvider.notifier).state =
        DownloadNotice(++_noticeSeq, message, isError: isError);
  }

  void _put(Song song, String status,
      {double progress = 0, String? error, String? quality}) {
    if (!mounted) return;
    state = {
      ...state,
      song.id: DownloadItem(
        song: song,
        progress: progress,
        status: status,
        errorMessage: error,
        quality: quality ?? state[song.id]?.quality ?? _defaultQuality,
      ),
    };
  }

  /// Called by the provider when connectivity changes. Queued downloads wait
  /// while offline instead of each failing with a connection error.
  void setOnline(bool online) {
    _online = online;
    if (online) _pump();
  }

  bool get isOnline => _online;

  // --- Enqueueing -----------------------------------------------------------

  /// Queue a single download (song menu, auto-download on play, re-download
  /// after a quality change with [force]).
  Future<int> download(Song song, {String? quality, bool force = false}) =>
      _enqueueAll([song], quality ?? _defaultQuality, force: force);

  /// Queue many songs with ONE state update (album / artist / whole library).
  /// Songs already downloaded or in flight are skipped. Returns how many were
  /// actually queued.
  Future<int> downloadBatch(List<Song> songs, {String? quality}) =>
      _enqueueAll(songs, quality ?? _defaultQuality, force: false);

  /// Download [songs] again even though they are on device (download quality
  /// changed). The old files stay playable until each replacement finishes.
  Future<int> redownload(List<Song> songs, {required String quality}) =>
      _enqueueAll(songs, quality, force: true);

  Future<int> _enqueueAll(
    List<Song> songs,
    String quality, {
    required bool force,
  }) async {
    if (songs.isEmpty) return 0;
    final downloaded = _ref.read(downloadedSongIdsProvider);
    final accepted = <Song>[];
    var rejectedPreview = false;
    for (final song in songs) {
      if (song.externalStreamUrl != null || song.id.startsWith('deezer:')) {
        rejectedPreview = true;
        continue;
      }
      final current = state[song.id];
      if (current != null && current.isActive) continue;
      if (!force && (song.isDownloaded || downloaded.contains(song.id))) {
        continue;
      }
      accepted.add(song);
    }
    if (rejectedPreview && songs.length == 1) {
      _notice('Previews are not in your library and can’t be downloaded',
          isError: true);
    }
    if (accepted.isEmpty) return 0;

    state = {
      ...state,
      for (final song in accepted)
        song.id: DownloadItem(
            song: song, progress: 0, status: 'queued', quality: quality),
    };
    _sessionTotal += accepted.length;

    // Persist metadata + queue rows first: the song row is what the finished
    // download attaches to, and the queue row lets a restart resume.
    try {
      await _db.upsertSongs(accepted.map(_songToCompanion).toList());
      await _db.upsertDownloads([
        for (final song in accepted)
          DownloadQueueCompanion.insert(
            songId: song.id,
            songTitle: song.title,
            artist: song.artist,
            savePath: '',
            status: const Value('queued'),
            quality: Value(quality),
            errorMessage: const Value(null),
          ),
      ]);
    } catch (e) {
      // Without the rows the downloads would finish but never register.
      for (final song in accepted) {
        _put(song, 'error',
            error: 'Could not save to the local database: $e',
            quality: quality);
      }
      _sessionFailed += accepted.length;
      _notice('Downloads could not be queued: $e', isError: true);
      _maybeFinishSession();
      return 0;
    }
    for (final song in accepted) {
      // A cancel may have landed while the rows were being written.
      if (state[song.id]?.status != 'queued') continue;
      _queue.add(_DownloadTask(song: song, quality: quality, force: force));
    }
    _pump();
    return accepted.length;
  }

  void _pump() {
    if (!mounted || !_online) return;
    while (_active.length < _maxConcurrent && _queue.isNotEmpty) {
      final task = _queue.removeFirst();
      final token = CancelToken();
      _active[task.song.id] = token;
      _run(task, token).whenComplete(() {
        _active.remove(task.song.id);
        _pump();
        _maybeFinishSession();
      });
    }
  }

  void _maybeFinishSession() {
    if (!mounted || _active.isNotEmpty || _queue.isNotEmpty) return;
    if (_sessionTotal > 1 && _sessionDone + _sessionFailed > 0) {
      final finished = _sessionDone + _sessionFailed;
      if (_sessionFailed == 0) {
        _notice('Downloaded $_sessionDone songs');
      } else {
        _notice(
          'Downloaded $_sessionDone of $finished songs — $_sessionFailed '
          'failed. Retry them in Downloaded songs.',
          isError: true,
        );
      }
    }
    _sessionTotal = 0;
    _sessionDone = 0;
    _sessionFailed = 0;
    _sessionErrorShown = false;
  }

  // --- The download itself --------------------------------------------------

  Future<void> _run(_DownloadTask task, CancelToken token) async {
    final song = task.song;
    _put(song, 'downloading', quality: task.quality);
    String? coverWritten;
    try {
      final client = _ref.read(subsonicClientProvider);
      if (client == null) {
        throw const DownloadContentException('No server is configured');
      }
      await _db.updateDownloadStatus(song.id, 'downloading');

      final root = await getAppStorageDirectory();
      final dir = downloadsDirPath(root.path);
      await Directory(dir).create(recursive: true);
      final base = downloadBasePath(dir, song.id);

      // 1. Cover art first: it is small, so a broken cover fails fast instead
      //    of after a 50 MB FLAC. A download without its cover is incomplete.
      final coverArtId = song.coverArt;
      if (coverArtId != null && coverArtId.isNotEmpty) {
        final coverPath = '$base.cover.jpg';
        if (task.force || !File(coverPath).existsSync()) {
          try {
            await client.downloadCoverArt(coverArtId, coverPath,
                cancelToken: token);
          } on DioException catch (e) {
            if (e.type == DioExceptionType.cancel) rethrow;
            throw DownloadContentException(
                'Cover art failed: ${friendlyDownloadError(e)}');
          }
          evictLocalCoverCache(coverPath);
          coverWritten = coverPath;
        }
      }

      // 2. Audio, written to a .part file and renamed when complete.
      var lastReported = 0.0;
      final audioPath = await client.downloadSong(
        song,
        base,
        quality: task.quality,
        cancelToken: token,
        onProgress: (recv, total) {
          if (total <= 0) return;
          final progress = recv / total;
          // Throttle to 1 % steps: per-chunk updates rebuild every listener.
          if (progress - lastReported < 0.01 && progress < 1) return;
          lastReported = progress;
          _put(song, 'downloading', progress: progress);
        },
      );

      // 3. Register as soon as the file is in place, before anything that
      //    can be cancelled: a cancel or app exit from here on must not leave
      //    a complete file that is neither downloaded nor resumable. The previous file (e.g. a FLAC replaced by a lower
      //    quality MP3) is removed only after the new one is in place.
      final previous = (await _db.getSongById(song.id))?.localPath;
      await _db.upsertSong(_songToCompanion(song));
      await _db.markDownloaded(song.id, audioPath);
      await _db.updateDownloadStatus(song.id, 'done');
      if (previous != null && previous != audioPath) {
        final old = File(previous);
        if (await old.exists()) await old.delete();
      }

      // 4. Lyrics for offline viewing. Optional: most tracks have none, and
      //    Bounded so a slow provider can't hold a download slot; a cancel
      //    here just stops the lookup. A provider outage must not undo a
      //    finished download: the lyrics screen reports it when opened.
      try {
        await _fetchLyrics(
          db: _db,
          q: (
            songId: song.id,
            artist: song.artist,
            title: song.title,
            album: song.album,
            duration: song.duration ?? 0,
          ),
          cancelToken: token,
        ).timeout(const Duration(seconds: 20), onTimeout: () => null);
      } catch (e) {
        debugPrint('[Downloads] lyrics for ${song.id} not cached: $e');
      }

      _sessionDone++;
      if (!mounted) return;
      final next = Map<String, DownloadItem>.from(state)..remove(song.id);
      state = next;
      _ref.invalidate(downloadedSongsProvider);
      if (_sessionTotal == 1) _notice('“${song.title}” downloaded');
    } catch (e) {
      final cancelled = e is DioException && e.type == DioExceptionType.cancel;
      if (cancelled) {
        // An app shutdown keeps the row ('downloading') so it resumes.
        if (!_disposing) {
          await _db.deleteDownloads([song.id]).catchError((_) {});
          // A user cancel drops the cover this attempt fetched, unless the
          // song was already downloaded (a forced re-download keeps its art).
          final cover = coverWritten;
          if (cover != null &&
              !_ref.read(downloadedSongIdsProvider).contains(song.id)) {
            await File(cover).delete().catchError((_) => File(cover));
            evictLocalCoverCache(cover);
          }
        }
        if (!mounted) return;
        state = Map<String, DownloadItem>.from(state)..remove(song.id);
        return;
      }
      final reason = friendlyDownloadError(e);
      debugPrint('[Downloads] ${song.id} failed: $e');
      await _db
          .updateDownloadStatus(song.id, 'error', errorMessage: reason)
          .catchError((_) {});
      _sessionFailed++;
      _put(song, 'error', error: reason);
      if (!_sessionErrorShown) {
        _sessionErrorShown = true;
        _notice('“${song.title}” couldn’t be downloaded: $reason',
            isError: true);
      }
    }
  }

  // --- User actions -----------------------------------------------------------

  bool isDownloading(String songId) => state[songId]?.isActive ?? false;

  /// Cancel a queued or running download.
  Future<void> cancel(String songId) async {
    final token = _active[songId];
    if (token != null) {
      token.cancel('user');
      return; // _run cleans up state and the queue row.
    }
    _queue.removeWhere((t) => t.song.id == songId);
    if (state[songId]?.status == 'queued') {
      _sessionTotal = (_sessionTotal - 1).clamp(0, 1 << 30);
      state = Map<String, DownloadItem>.from(state)..remove(songId);
      await _db.deleteDownloads([songId]);
      _maybeFinishSession();
    }
  }

  Future<void> cancelAll() async {
    final queued = _queue.map((t) => t.song.id).toList();
    _queue.clear();
    _sessionTotal = (_sessionTotal - queued.length).clamp(0, 1 << 30);
    for (final token in _active.values) {
      token.cancel('user');
    }
    if (queued.isNotEmpty) {
      state = Map<String, DownloadItem>.from(state)
        ..removeWhere((id, _) => queued.contains(id));
      await _db.deleteDownloads(queued);
    }
    _maybeFinishSession();
  }

  Future<void> retry(String songId) async {
    final item = state[songId];
    if (item == null || item.status != 'error') return;
    await _enqueueAll([item.song], item.quality, force: false);
  }

  Future<void> retryAllFailed() async {
    final failed = state.values.where((d) => d.status == 'error').toList();
    final byQuality = <String, List<Song>>{};
    for (final d in failed) {
      byQuality.putIfAbsent(d.quality, () => []).add(d.song);
    }
    for (final entry in byQuality.entries) {
      await _enqueueAll(entry.value, entry.key, force: false);
    }
  }

  /// Forget failed downloads without retrying them.
  Future<void> clearFailed() => _forgetFailed(state.entries
      .where((e) => e.value.status == 'error')
      .map((e) => e.key)
      .toList());

  Future<void> clearFailedOne(String songId) =>
      _forgetFailed(state[songId]?.status == 'error' ? [songId] : const []);

  Future<void> _forgetFailed(List<String> ids) async {
    if (ids.isEmpty) return;
    state = Map<String, DownloadItem>.from(state)
      ..removeWhere((id, _) => ids.contains(id));
    await _db.deleteDownloads(ids);
  }

  Future<void> removeDownload(String songId) => removeDownloads([songId]);

  /// Delete downloaded files and their covers. Throws if a file can't be
  /// deleted, after un-marking it so the app never plays a half-removed song.
  Future<void> removeDownloads(List<String> songIds) async {
    for (final id in songIds) {
      await cancel(id);
    }
    Object? firstError;
    for (final id in songIds) {
      try {
        final row = await _db.getSongById(id);
        await _db.unmarkDownloaded(id);
        final path = row?.localPath;
        if (path != null) {
          for (final f in [File(path), File(coverPathForAudio(path))]) {
            if (await f.exists()) await f.delete();
          }
          evictLocalCoverCache(coverPathForAudio(path));
        }
      } catch (e) {
        firstError ??= e;
      }
    }
    await _db.deleteDownloads(songIds);
    if (mounted) {
      state = Map<String, DownloadItem>.from(state)
        ..removeWhere((id, _) => songIds.contains(id));
    }
    _ref.invalidate(downloadedSongsProvider);
    if (firstError != null) throw firstError;
  }

  // --- Startup: integrity check, resume, cover backfill ---------------------

  Future<void> _restore() async {
    try {
      await _ref.read(serverConfigProvider.future);
      final root = await getAppStorageDirectory();
      final dir = Directory(downloadsDirPath(root.path));
      final downloaded = await _db.getDownloadedSongs();
      final unfinished = await _db.getUnfinishedDownloads();

      // 1. Downloads whose file vanished (cleared storage, manual delete):
      //    un-mark them and say so instead of failing at play time.
      final missing = <CachedSong>[];
      for (final row in downloaded) {
        final path = row.localPath;
        if (path == null || !File(path).existsSync()) missing.add(row);
      }
      for (final row in missing) {
        await _db.unmarkDownloaded(row.id);
      }
      if (missing.isNotEmpty) {
        _ref.invalidate(downloadedSongsProvider);
        final n = missing.length;
        _notice(
          n == 1
              ? '“${missing.first.title}” was missing from storage and was '
                  'removed from Downloads'
              : '$n downloaded songs were missing from storage and were '
                  'removed from Downloads',
          isError: true,
        );
      }

      // 2. Leftovers from crashes: .part files and covers no download owns.
      if (dir.existsSync()) {
        final keep = <String>{};
        for (final row in downloaded) {
          final path = row.localPath;
          if (path == null) continue;
          keep.add(p.normalize(path));
          keep.add(p.normalize(coverPathForAudio(path)));
        }
        final pendingBases = {
          for (final q in unfinished) downloadBasePath(dir.path, q.songId),
        };
        // Anything the user queued while this check was starting.
        final liveBases = {
          for (final id in state.keys) downloadBasePath(dir.path, id),
        };
        await for (final entity in dir.list()) {
          if (entity is! File) continue;
          final path = p.normalize(entity.path);
          if (keep.contains(path)) continue;
          if (liveBases.any((b) => path.startsWith('$b.'))) continue;
          // Only .part files and orphaned covers are removed. An unreferenced
          // audio file is left alone: deleting the user's music on a path
          // mismatch would be far worse than a few stray megabytes.
          final isPart = path.endsWith('.part');
          final isOrphanCover = path.endsWith('.cover.jpg') &&
              !pendingBases.contains(path.substring(0, path.length - 10));
          if (isPart || isOrphanCover) {
            await entity.delete().catchError((_) => entity);
          }
        }
      }

      // 3. Resume the queue saved before the app closed.
      if (unfinished.isNotEmpty) {
        final failed = <String, DownloadItem>{};
        final resume = <String, List<Song>>{};
        final gone = <String>[];
        for (final q in unfinished) {
          final row = await _db.getSongById(q.songId);
          if (row == null) {
            gone.add(q.songId);
            continue;
          }
          final song = _rowToSong(row);
          final quality = q.quality ?? _defaultQuality;
          if (q.status == 'error') {
            failed[song.id] = DownloadItem(
              song: song,
              progress: 0,
              status: 'error',
              errorMessage: q.errorMessage ?? 'Download failed',
              quality: quality,
            );
          } else if (!row.isDownloaded) {
            resume.putIfAbsent(quality, () => []).add(song);
          } else {
            gone.add(q.songId);
          }
        }
        if (gone.isNotEmpty) await _db.deleteDownloads(gone);
        if (mounted && failed.isNotEmpty) state = {...state, ...failed};
        for (final entry in resume.entries) {
          await _enqueueAll(entry.value, entry.key, force: false);
        }
      }

      // 4. Downloads made before covers were part of the pipeline (or whose
      //    cover failed back then): fetch the missing covers now.
      await _backfillCovers(
          downloaded.where((r) => !missing.contains(r)).toList());
    } catch (e, st) {
      debugPrint('[Downloads] restore failed: $e\n$st');
      _notice('Could not check downloads: $e', isError: true);
    }
  }

  Future<void> _backfillCovers(List<CachedSong> rows) async {
    final client = _ref.read(subsonicClientProvider);
    if (client == null || !_online) return;
    final todo = rows.where((r) {
      final art = r.coverArt;
      return art != null &&
          art.isNotEmpty &&
          r.localPath != null &&
          !File(coverPathForAudio(r.localPath!)).existsSync();
    }).toList();
    if (todo.isEmpty) return;
    var failures = 0;
    String? firstReason;
    for (final row in todo) {
      if (!mounted) return;
      final cover = coverPathForAudio(row.localPath!);
      try {
        await client.downloadCoverArt(row.coverArt!, cover);
        evictLocalCoverCache(cover);
      } catch (e) {
        failures++;
        firstReason ??= friendlyDownloadError(e);
      }
    }
    if (failures > 0) {
      _notice(
        'Couldn’t save cover art for $failures downloaded '
        'song${failures == 1 ? '' : 's'}: $firstReason',
        isError: true,
      );
    }
    _ref.invalidate(downloadedSongsProvider);
  }
}

final downloadNotifierProvider =
    StateNotifierProvider<DownloadNotifier, Map<String, DownloadItem>>((ref) {
  // Deliberately watches nothing: rebuilding on a config refresh would orphan
  // in-flight downloads. The client is read when each download starts.
  final notifier = DownloadNotifier(ref.read(databaseProvider), ref);
  ref.listen<AsyncValue<bool>>(isOnlineProvider, (_, next) {
    final online = next.valueOrNull;
    if (online != null) notifier.setOnline(online);
  });
  return notifier;
});

/// Song id → local audio path for every finished download. Feeds the audio
/// handler (play from disk even when a song comes from a server view) and
/// [CoverArtImage] (show the saved cover offline).
final downloadedPathsProvider = Provider<Map<String, String>>((ref) {
  final songs = ref.watch(downloadedSongsProvider).valueOrNull ?? const [];
  return {
    for (final s in songs)
      if (s.localPath != null) s.id: s.localPath!,
  };
});

// Set of downloaded song IDs — only updates when a download *completes* (not on progress ticks).
// DownloadNotifier invalidates downloadedSongsProvider on completion, which cascades here.
final downloadedSongIdsProvider = Provider<Set<String>>((ref) {
  return ref.watch(downloadedPathsProvider).keys.toSet();
});

/// Bytes used by downloaded audio + covers, for the Downloaded songs header.
final downloadsStorageBytesProvider = FutureProvider<int>((ref) async {
  final paths = ref.watch(downloadedPathsProvider).values;
  var total = 0;
  for (final path in paths) {
    for (final f in [File(path), File(coverPathForAudio(path))]) {
      try {
        total += await f.length();
      } on FileSystemException {
        // Missing cover (song without art) or a file the startup check is
        // about to report; neither contributes to the total.
      }
    }
  }
  return total;
});

// --- Album art dominant color (cached per URL) ---
// Shared by now_playing_screen, mini_player, and main_shell.
final dominantColorProvider =
    FutureProvider.family<Color?, String>((ref, url) async {
  if (url.isEmpty) return null;
  try {
    // file:// keys come from a downloaded song's saved cover, so the accent
    // works offline too.
    final ImageProvider<Object> image;
    if (url.startsWith('file://')) {
      image = FileImage(File(Uri.parse(url).toFilePath()));
    } else {
      image = CachedNetworkImageProvider(url);
    }
    final palette = await PaletteGenerator.fromImageProvider(
      image,
      size: const Size(112, 112), // downsample before extraction — much faster
      maximumColorCount: 8,
    );
    // Prefer intentionally-saturated swatches over the dominant (most-pixels)
    // color, which is often the album cover's background — off-white, black, or
    // a washed-out neutral that makes a poor accent.
    final raw = palette.vibrantColor?.color ??
        palette.darkVibrantColor?.color ??
        palette.mutedColor?.color ??
        palette.dominantColor?.color;
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

/// Derives a foreground accent from the album-art color for interactive
/// elements (buttons, sliders, active icons). Same hue as the cover-art
/// accent but shifted to contrast against the player background (which
/// lerps the same accent toward black/white). Dark theme pushes lightness
/// up for visibility; light theme pulls it down.
/// Returns null when [accent] is null — caller falls back to scheme.primary.
Color? foregroundAccentColor(Color? accent, Brightness brightness) {
  if (accent == null) return null;
  final hsl = HSLColor.fromColor(accent);
  if (brightness == Brightness.dark) {
    return hsl
        .withLightness((hsl.lightness + 0.18).clamp(0.45, 0.80))
        .withSaturation((hsl.saturation + 0.05).clamp(0.0, 1.0))
        .toColor();
  } else {
    return hsl
        .withLightness((hsl.lightness - 0.12).clamp(0.18, 0.48))
        .toColor();
  }
}

// Module-level cache for the last non-null accent. Using a plain variable
// instead of a StateProvider avoids the Riverpod assertion that prohibits
// modifying another provider's state during a provider's build phase.
Color? _cachedLastAccent;

// Accent color derived from the current song's album art.
// Returns the last good accent during loading to avoid light-blue blinking.
final currentAccentColorProvider = Provider<Color?>((ref) {
  final song = ref.watch(currentSongStreamProvider).valueOrNull;
  if (song == null) return null;
  final localCover = song.localPath == null
      ? null
      : coverPathForAudio(song.localPath!);
  final coverUrl = localCover != null && localCoverExists(localCover)
      ? Uri.file(localCover).toString()
      : ref.watch(coverArtUrlProvider(song.coverArt ?? '')) ??
          song.externalCoverUrl ??
          '';
  if (coverUrl.isEmpty) return null;
  final color = ref.watch(dominantColorProvider(coverUrl)).valueOrNull;
  if (color != null) {
    _cachedLastAccent = color;
    return color;
  }
  return _cachedLastAccent;
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
      starred: row.starred,
      playCount: row.playCount,
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
      starred: Value(s.starred),
      playCount: Value(s.playCount),
    );
