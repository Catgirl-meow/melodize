// Provider behaviour without a network: library views come from the
// on-device cache, server-only sections fail fast with a clear reason.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:melodize/core/api/subsonic_client.dart';
import 'package:melodize/core/db/database.dart';
import 'package:melodize/core/errors/app_errors.dart';
import 'package:melodize/core/models/recommendations_state.dart';
import 'package:melodize/core/providers.dart';

CachedSongsCompanion _row(String id, String title,
        {String albumId = 'al-1', int track = 1, bool downloaded = false}) =>
    CachedSongsCompanion(
      id: Value(id),
      title: Value(title),
      artist: const Value('Artist'),
      album: const Value('Album'),
      albumId: Value(albumId),
      artistId: const Value('ar-1'),
      track: Value(track),
      isDownloaded: Value(downloaded),
    );

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.upsertSongs([
      _row('1', 'Diamonds', track: 2),
      _row('2', 'Diamond Heart', track: 1, downloaded: true),
      _row('3', 'Something Else', albumId: 'al-2'),
    ]);
  });
  tearDown(() => db.close());

  // Port 9 (discard) on loopback: nothing listens, so requests are refused
  // at once — a stand-in for a server that can't be reached.
  final unreachable = SubsonicClient(const SubsonicConfig(
    serverUrl: 'http://127.0.0.1:9',
    username: 'u',
    password: 'p',
  ));

  Future<ProviderContainer> container({required bool online}) async {
    final c = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      isOnlineProvider.overrideWith((_) => Stream.value(online)),
      subsonicClientProvider.overrideWithValue(unreachable),
    ]);
    addTearDown(c.dispose);
    // Keep connectivity alive and resolved before the providers under test
    // read it.
    c.listen(isOnlineProvider, (_, __) {});
    await c.read(isOnlineProvider.future);
    return c;
  }

  test('offline search answers from the cache, downloaded first', () async {
    final c = await container(online: false);
    c.read(searchQueryProvider.notifier).state = 'diamond';
    final r = await c.read(searchResultsProvider.future);
    expect(r.fromCache, isTrue);
    expect(r.songs.map((s) => s.id), ['2', '1']);
  });

  test('a server that refuses connections falls back to the cache', () async {
    final c = await container(online: true);
    c.read(searchQueryProvider.notifier).state = 'something';
    final r = await c.read(searchResultsProvider.future);
    expect(r.fromCache, isTrue);
    expect(r.songs.single.id, '3');
  });

  test('offline Deezer search fails with "No internet connection"', () async {
    final c = await container(online: false);
    c.read(searchQueryProvider.notifier).state = 'diamond';
    c.listen(deezerSearchProvider, (_, __) {});
    await expectLater(c.read(deezerSearchProvider.future),
        throwsA(isA<DeviceOfflineException>()));
  });

  test('offline album and album list come from the cache', () async {
    final c = await container(online: false);
    final songs = await c.read(albumSongsProvider('al-1').future);
    expect(songs.map((s) => s.id), ['2', '1']);
    final albums = await c.read(allAlbumsProvider.future);
    expect(albums.map((a) => a.id).toSet(), {'al-1', 'al-2'});
    final artists = await c.read(allArtistsProvider.future);
    expect(artists.single.albumCount, 2);
  });

  test('offline server-only sections fail fast', () async {
    final c = await container(online: false);
    await expectLater(c.read(randomSongsProvider.future),
        throwsA(isA<DeviceOfflineException>()));
    await expectLater(c.read(playlistsProvider.future),
        throwsA(isA<DeviceOfflineException>()));
    final recs = await c.read(recommendationsProvider.future);
    expect(recs, isA<RecsError>());
  });
}
