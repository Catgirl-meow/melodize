import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import '../utils/platform_dirs.dart';

part 'database.g.dart';

// --- Tables ---

class CachedSongs extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get artist => text()();
  TextColumn get album => text()();
  TextColumn get albumId => text().nullable()();
  TextColumn get artistId => text().nullable()();
  IntColumn get duration => integer().nullable()();
  IntColumn get year => integer().nullable()();
  TextColumn get genre => text().nullable()();
  IntColumn get track => integer().nullable()();
  TextColumn get coverArt => text().nullable()();
  TextColumn get suffix => text().nullable()();
  TextColumn get contentType => text().nullable()();
  IntColumn get bitRate => integer().nullable()();
  IntColumn get size => integer().nullable()();
  BoolColumn get isDownloaded => boolean().withDefault(const Constant(false))();
  TextColumn get localPath => text().nullable()();
  DateTimeColumn get created => dateTime().nullable()();
  // When the song was starred ("liked") on the server; null = not liked.
  DateTimeColumn get starred => dateTime().nullable()();
  IntColumn get playCount => integer().nullable()();
  DateTimeColumn get cachedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class PlayHistory extends Table {
  IntColumn get historyId => integer().autoIncrement()();
  TextColumn get songId => text()();
  TextColumn get songTitle => text()();
  TextColumn get artist => text()();
  TextColumn get coverArt => text().nullable()();
  DateTimeColumn get playedAt => dateTime().withDefault(currentDateAndTime)();
  // How long the song played before it ended or was left, and whether that
  // counts as a skip (< 30 s of a song longer than a minute). Null/false for
  // rows from before schema v7 and while the song is still playing.
  IntColumn get listenedMs => integer().nullable()();
  BoolColumn get skipped => boolean().withDefault(const Constant(false))();
}

class ServerConfig extends Table {
  IntColumn get configId => integer().autoIncrement()();
  TextColumn get serverUrl => text()();
  TextColumn get username => text()();
  TextColumn get password => text()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

class DownloadQueue extends Table {
  TextColumn get songId => text()();
  TextColumn get songTitle => text()();
  TextColumn get artist => text()();
  TextColumn get savePath => text()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  IntColumn get progress => integer().withDefault(const Constant(0))();
  // Requested quality ('lossless' or a max bitrate), so a queue restored
  // after a restart downloads what the user originally asked for.
  TextColumn get quality => text().nullable()();
  // Last failure reason, shown next to the Retry button after a restart.
  TextColumn get errorMessage => text().nullable()();
  DateTimeColumn get addedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {songId};
}

class LyricsCache extends Table {
  TextColumn get songId => text()();
  TextColumn get plainLyrics => text().nullable()();
  TextColumn get syncedLyrics => text().nullable()();
  DateTimeColumn get cachedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {songId};
}

/// Deezer recommendations the user liked that aren't in the server library
/// yet. Liking one asks the companion to add it; once a song with the same
/// title and artist shows up in the library it is starred there and the row
/// is removed. Rows stay (and show under Library → Liked) while the add is
/// pending or failed, so a like is never lost.
class PendingLikes extends Table {
  IntColumn get deezerId => integer()();
  TextColumn get title => text()();
  TextColumn get artist => text()();
  TextColumn get album => text()();
  IntColumn get duration => integer().nullable()();
  TextColumn get coverUrl => text().nullable()();
  TextColumn get previewUrl => text().nullable()();
  DateTimeColumn get likedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {deezerId};
}

/// "Not interested" on recommendations. [key] is `track:<keyFor>` for one
/// song or `artist:<normalized artist>` for a whole artist.
class DismissedRecs extends Table {
  TextColumn get key => text()();
  TextColumn get kind => text()(); // 'track' | 'artist'
  TextColumn get artist => text()();
  TextColumn get title => text().nullable()();
  TextColumn get coverUrl => text().nullable()();
  DateTimeColumn get dismissedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {key};
}

/// How often a recommended track ([keyFor] key) was shown on Home without
/// being played. Played tracks are removed.
class RecImpressions extends Table {
  TextColumn get trackKey => text()();
  IntColumn get shown => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {trackKey};
}

/// "More like this" taps per artist (as written).
class MoreLikeThisTaps extends Table {
  TextColumn get artist => text()();
  IntColumn get taps => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {artist};
}

// --- Database ---

@DriftDatabase(tables: [
  CachedSongs,
  PlayHistory,
  ServerConfig,
  DownloadQueue,
  LyricsCache,
  PendingLikes,
  DismissedRecs,
  RecImpressions,
  MoreLikeThisTaps,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase._internal() : super(_openConnection());
  static final AppDatabase _instance = AppDatabase._internal();
  factory AppDatabase() => _instance;

  /// A separate database on [executor], e.g. `NativeDatabase.memory()`.
  /// Tests only; the app uses the singleton.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(lyricsCache);
          }
          if (from < 3) {
            await m.addColumn(cachedSongs, cachedSongs.created);
          }
          if (from < 4) {
            // Drop orphaned queue_entries table (never written to).
            await customStatement('DROP TABLE IF EXISTS queue_entries');
          }
          if (from < 5) {
            // Persisted download queue: resume after restart, keep failures.
            await m.addColumn(downloadQueue, downloadQueue.quality);
            await m.addColumn(downloadQueue, downloadQueue.errorMessage);
          }
          if (from < 6) {
            // Likes: server star + play count cache, pending Deezer likes.
            await m.addColumn(cachedSongs, cachedSongs.starred);
            await m.addColumn(cachedSongs, cachedSongs.playCount);
            await m.createTable(pendingLikes);
          }
          if (from < 7) {
            // Taste model: listen length/skips, Not interested, impressions.
            await m.addColumn(playHistory, playHistory.listenedMs);
            await m.addColumn(playHistory, playHistory.skipped);
            await m.createTable(dismissedRecs);
            await m.createTable(recImpressions);
            await m.createTable(moreLikeThisTaps);
          }
        },
      );

  // --- Songs ---
  Future<List<CachedSong>> getAllCachedSongs() =>
      (select(cachedSongs)..orderBy([(t) => OrderingTerm.asc(t.title)])).get();

  Future<List<CachedSong>> getDownloadedSongs() =>
      (select(cachedSongs)
            ..where((t) => t.isDownloaded.equals(true))
            ..orderBy([(t) => OrderingTerm.asc(t.title)]))
          .get();

  Future<void> upsertSong(CachedSongsCompanion song) =>
      into(cachedSongs).insertOnConflictUpdate(song);

  Future<void> upsertSongs(List<CachedSongsCompanion> songs) =>
      batch((b) => b.insertAllOnConflictUpdate(cachedSongs, songs));

  Future<CachedSong?> getSongById(String id) =>
      (select(cachedSongs)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Flags [id] as downloaded at [localPath]. Throws if the song row does not
  /// exist: a silent no-op here used to leave a file on disk that never
  /// showed up in Downloads. Callers upsert the song's metadata first.
  Future<void> markDownloaded(String id, String localPath) async {
    final rows = await (update(cachedSongs)..where((t) => t.id.equals(id)))
        .write(
      CachedSongsCompanion(
        isDownloaded: const Value(true),
        localPath: Value(localPath),
      ),
    );
    if (rows == 0) {
      throw StateError('Song $id is missing from the local library cache');
    }
  }

  Future<void> unmarkDownloaded(String id) =>
      (update(cachedSongs)..where((t) => t.id.equals(id))).write(
        const CachedSongsCompanion(
          isDownloaded: Value(false),
          localPath: Value(null),
        ),
      );

  /// Sets or clears the cached star on [id] without touching anything else.
  Future<void> setSongStarred(String id, DateTime? when) =>
      (update(cachedSongs)..where((t) => t.id.equals(id)))
          .write(CachedSongsCompanion(starred: Value(when)));

  // --- Pending likes ---
  Stream<List<PendingLike>> watchPendingLikes() => (select(pendingLikes)
        ..orderBy([(t) => OrderingTerm.desc(t.likedAt)]))
      .watch();

  Future<List<PendingLike>> getPendingLikes() => select(pendingLikes).get();

  Future<void> addPendingLike(PendingLikesCompanion like) =>
      into(pendingLikes).insertOnConflictUpdate(like);

  Future<void> removePendingLike(int deezerId) =>
      (delete(pendingLikes)..where((t) => t.deezerId.equals(deezerId))).go();

  // --- Recommendation feedback ---
  /// Records how long the latest play of [songId] lasted. Only touches a
  /// row from the last 12 hours still missing its length, so a late report
  /// can't overwrite an older play.
  Future<void> finishLatestPlay(String songId,
      {required int listenedMs, required bool skipped}) async {
    final row = await (select(playHistory)
          ..where((t) =>
              t.songId.equals(songId) &
              t.listenedMs.isNull() &
              t.playedAt.isBiggerThanValue(
                  DateTime.now().subtract(const Duration(hours: 12))))
          ..orderBy([(t) => OrderingTerm.desc(t.playedAt)])
          ..limit(1))
        .getSingleOrNull();
    if (row == null) return;
    await (update(playHistory)
          ..where((t) => t.historyId.equals(row.historyId)))
        .write(PlayHistoryCompanion(
            listenedMs: Value(listenedMs), skipped: Value(skipped)));
  }

  Stream<List<DismissedRec>> watchDismissedRecs() => (select(dismissedRecs)
        ..orderBy([(t) => OrderingTerm.desc(t.dismissedAt)]))
      .watch();

  Future<List<DismissedRec>> getDismissedRecs() => select(dismissedRecs).get();

  Future<void> addDismissedRec(DismissedRecsCompanion rec) =>
      into(dismissedRecs).insertOnConflictUpdate(rec);

  Future<void> removeDismissedRec(String key) =>
      (delete(dismissedRecs)..where((t) => t.key.equals(key))).go();

  Future<Map<String, int>> getImpressions() async => {
        for (final r in await select(recImpressions).get()) r.trackKey: r.shown
      };

  /// Adds one showing to each of [trackKeys].
  Future<void> countImpressions(Iterable<String> trackKeys) =>
      transaction(() async {
        for (final k in trackKeys) {
          await customStatement(
              'INSERT INTO rec_impressions (track_key, shown) VALUES (?, 1) '
              'ON CONFLICT(track_key) DO UPDATE SET shown = shown + 1',
              [k]);
        }
      });

  Future<void> clearImpression(String trackKey) =>
      (delete(recImpressions)..where((t) => t.trackKey.equals(trackKey))).go();

  Future<Map<String, int>> getMoreLikeThis() async => {
        for (final r in await select(moreLikeThisTaps).get()) r.artist: r.taps
      };

  Future<void> addMoreLikeThis(String artist) => customStatement(
      'INSERT INTO more_like_this_taps (artist, taps) VALUES (?, 1) '
      'ON CONFLICT(artist) DO UPDATE SET taps = taps + 1',
      [artist]);

  /// Forgets hides, impressions and "more like this" (Settings → Reset).
  /// Play history and likes stay.
  /// Settings → Recommendations → Reset: forgets hidden items, "More like
  /// this" taps, card impressions and skip flags. Play history itself and
  /// likes (stars on the server) stay.
  Future<void> resetRecommendationFeedback() => transaction(() async {
        await delete(dismissedRecs).go();
        await delete(recImpressions).go();
        await delete(moreLikeThisTaps).go();
        await update(playHistory).write(const PlayHistoryCompanion(
            skipped: Value(false), listenedMs: Value(null)));
      });

  // --- Debug export ---
  /// Writes a consistent copy of the database to [path] for offline
  /// analysis (Settings → Debug), with the server login removed: the copy
  /// holds play history, the library cache and likes, never credentials.
  Future<void> exportForAnalysis(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
    final quoted = path.replaceAll("'", "''");
    await customStatement("VACUUM INTO '$quoted'");
    await customStatement("ATTACH DATABASE '$quoted' AS export_copy");
    try {
      await customStatement('DELETE FROM export_copy.server_config');
    } finally {
      await customStatement('DETACH DATABASE export_copy');
    }
  }

  // --- History ---
  Future<List<PlayHistoryData>> getRecentHistory({int limit = 30}) =>
      (select(playHistory)
            ..orderBy([(t) => OrderingTerm.desc(t.playedAt)])
            ..limit(limit))
          .get();

  Future<void> addToHistory(PlayHistoryCompanion entry) =>
      into(playHistory).insert(entry);

  // --- Config ---
  Future<ServerConfigData?> getActiveConfig() =>
      (select(serverConfig)..where((t) => t.isActive.equals(true)))
          .getSingleOrNull();

  Future<void> saveConfig(ServerConfigCompanion config) =>
      into(serverConfig).insertOnConflictUpdate(config);

  // --- Downloads ---
  Future<List<DownloadQueueData>> getAllDownloads() =>
      (select(downloadQueue)
            ..orderBy([(t) => OrderingTerm.desc(t.addedAt)]))
          .get();

  Future<void> upsertDownload(DownloadQueueCompanion entry) =>
      into(downloadQueue).insertOnConflictUpdate(entry);

  /// Queue rows that still need work after a restart: queued, interrupted
  /// mid-download, or failed (shown with a Retry button).
  Future<List<DownloadQueueData>> getUnfinishedDownloads() =>
      (select(downloadQueue)
            ..where((t) => t.status.isIn(['queued', 'downloading', 'error']))
            ..orderBy([(t) => OrderingTerm.asc(t.addedAt)]))
          .get();

  Future<void> upsertDownloads(List<DownloadQueueCompanion> entries) =>
      batch((b) => b.insertAllOnConflictUpdate(downloadQueue, entries));

  Future<void> updateDownloadStatus(
    String songId,
    String status, {
    String? errorMessage,
  }) =>
      (update(downloadQueue)..where((t) => t.songId.equals(songId))).write(
        DownloadQueueCompanion(
          status: Value(status),
          progress: Value(status == 'done' ? 100 : 0),
          errorMessage: Value(errorMessage),
        ),
      );

  Future<void> deleteDownloads(Iterable<String> songIds) =>
      (delete(downloadQueue)..where((t) => t.songId.isIn(songIds))).go();

  Future<void> deleteDownload(String songId) =>
      (delete(downloadQueue)..where((t) => t.songId.equals(songId))).go();

  // --- Single song removal (server-side delete) ---
  Future<void> deleteSongCompletely(String songId) => transaction(() async {
        await (delete(cachedSongs)..where((t) => t.id.equals(songId))).go();
        await (delete(downloadQueue)..where((t) => t.songId.equals(songId)))
            .go();
        await (delete(lyricsCache)..where((t) => t.songId.equals(songId)))
            .go();
      });

  // --- Server change / full reset ---
  // Play history is intentionally preserved: it stores artist+title strings
  // (not server-specific IDs) so Deezer recommendations keep working after
  // switching servers.
  Future<void> clearAllData() => transaction(() async {
        await delete(cachedSongs).go();
        await delete(serverConfig).go();
        await delete(downloadQueue).go();
        await delete(lyricsCache).go();
      });

  // --- Lyrics ---
  Future<LyricsCacheData?> getCachedLyrics(String songId) =>
      (select(lyricsCache)..where((t) => t.songId.equals(songId)))
          .getSingleOrNull();

  Future<void> cacheLyrics(
          String songId, String? plain, String? synced) =>
      into(lyricsCache).insertOnConflictUpdate(LyricsCacheCompanion(
        songId: Value(songId),
        plainLyrics: Value(plain),
        syncedLyrics: Value(synced),
      ));
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getAppStorageDirectory();
    final file = File(p.join(dbFolder.path, 'melodize.db'));
    return NativeDatabase(
      file,
      setup: (db) {
        db.execute('PRAGMA journal_mode=WAL');
        db.execute('PRAGMA busy_timeout=5000');
      },
    );
  });
}
