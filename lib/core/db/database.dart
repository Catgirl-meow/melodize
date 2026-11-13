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

// --- Database ---

@DriftDatabase(tables: [
  CachedSongs,
  PlayHistory,
  ServerConfig,
  DownloadQueue,
  LyricsCache,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase._internal() : super(_openConnection());
  static final AppDatabase _instance = AppDatabase._internal();
  factory AppDatabase() => _instance;

  @override
  int get schemaVersion => 5;

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
