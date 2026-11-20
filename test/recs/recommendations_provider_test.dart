// recommendationsProvider end to end on an in-memory database with a fake
// Deezer: the taste model's inputs come from the right tables, and every
// failure becomes a clear state instead of an empty or substitute list.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:melodize/core/api/deezer_client.dart';
import 'package:melodize/core/api/subsonic_client.dart';
import 'package:melodize/core/audio/audio_handler.dart' show ListenEnd;
import 'package:melodize/core/db/database.dart';
import 'package:melodize/core/models/app_preferences.dart';
import 'package:melodize/core/models/recommendations_state.dart';
import 'package:melodize/core/models/recommended_track.dart';
import 'package:melodize/core/models/song.dart';
import 'package:melodize/core/providers.dart';
import 'package:melodize/core/recs/taste_model.dart';
import 'package:melodize/core/utils/title_normalize.dart';

/// Every artist's radio is ten songs by "<artist> fan 0..9"; artists in
/// [failing] throw, artists in [unknown] aren't on Deezer.
class FakeDeezer extends DeezerClient {
  final Set<String> failing;
  final Set<String> unknown;
  final searched = <String>[];
  FakeDeezer({this.failing = const {}, this.unknown = const {}});

  final _ids = <int, String>{};

  @override
  Future<int?> searchBestArtist({
    required String artistName,
    String? trackTitle,
    String? genreHint,
  }) async {
    searched.add(artistName);
    if (failing.contains(artistName)) throw Exception('HTTP 503');
    if (unknown.contains(artistName)) return null;
    final id = artistName.hashCode.abs();
    _ids[id] = artistName;
    return id;
  }

  @override
  Future<List<RecommendedTrack>> artistRadio(int artistId,
      {int limit = 10}) async {
    final a = _ids[artistId]!;
    return [
      for (var i = 0; i < 10; i++)
        RecommendedTrack(
          deezerId: artistId * 100 + i,
          title: 'Song $i',
          artist: '$a fan ${i ~/ 2}',
          album: 'Album',
          durationSeconds: 200,
        ),
    ];
  }
}

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  final client = SubsonicClient(const SubsonicConfig(
      serverUrl: 'http://127.0.0.1:9', username: 'u', password: 'p'));

  Future<ProviderContainer> container(FakeDeezer deezer) async {
    final c = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      isOnlineProvider.overrideWith((_) => Stream.value(true)),
      subsonicClientProvider.overrideWithValue(client),
      deezerClientProvider.overrideWithValue(deezer),
      preferencesNotifierProvider.overrideWith(
          (_) => PreferencesNotifier.inMemory(const AppPreferences())),
    ]);
    addTearDown(c.dispose);
    c.listen(isOnlineProvider, (_, __) {});
    await c.read(isOnlineProvider.future);
    return c;
  }

  Future<void> play(String artist, String title, {bool skipped = false}) =>
      db.addToHistory(PlayHistoryCompanion.insert(
        songId: '$artist-$title',
        songTitle: title,
        artist: artist,
        skipped: Value(skipped),
      ));

  test('no plays or likes: the "play something first" state', () async {
    final c = await container(FakeDeezer());
    expect(await c.read(recommendationsProvider.future),
        isA<RecsEmptyNoHistory>());
  });

  test('a list with a reason per card, counted as shown', () async {
    await play('Kaito Ren', 'Tokyo Rain');
    await play('Orbit Theory', 'Small Hours');
    final c = await container(FakeDeezer());
    final r = await c.read(recommendationsProvider.future) as RecsReady;
    expect(r.songs, isNotEmpty);
    expect(r.failedSeeds, isEmpty);
    for (final s in r.songs) {
      expect(r.reasons[s.id]?.artist, anyOf('Kaito Ren', 'Orbit Theory'));
    }
    final shown = await db.getImpressions();
    expect(shown.length, r.songs.length);
    expect(shown.values.toSet(), {1});
  });

  test('liked songs alone are enough to start', () async {
    await db.upsertSongs([
      CachedSongsCompanion.insert(
          id: 's1', title: 'Neon', artist: 'Lumen Drift', album: 'X',
          starred: Value(DateTime(2026, 11, 1))),
    ]);
    final c = await container(FakeDeezer());
    final r = await c.read(recommendationsProvider.future) as RecsReady;
    expect(r.reasons.values.map((s) => s.reason).toSet(), {SeedReason.liked});
  });

  test('hidden artists and songs never come back', () async {
    await play('Kaito Ren', 'Tokyo Rain');
    await db.addDismissedRec(DismissedRecsCompanion.insert(
        key: dismissedArtistKey('Kaito Ren fan 0'),
        kind: 'artist',
        artist: 'Kaito Ren fan 0'));
    await db.addDismissedRec(DismissedRecsCompanion.insert(
        key: dismissedTrackKey('Song 2', 'Kaito Ren fan 1'),
        kind: 'track',
        artist: 'Kaito Ren fan 1',
        title: const Value('Song 2')));
    final c = await container(FakeDeezer());
    final r = await c.read(recommendationsProvider.future) as RecsReady;
    expect(r.songs.map((s) => s.artist), isNot(contains('Kaito Ren fan 0')));
    expect(
        r.songs.map((s) => keyFor(s.title, s.artist)),
        isNot(contains(keyFor('Song 2', 'Kaito Ren fan 1'))));
  });

  test('Deezer down for every artist: an error naming the cause', () async {
    await play('Kaito Ren', 'Tokyo Rain');
    final c = await container(FakeDeezer(failing: {'Kaito Ren'}));
    final r = await c.read(recommendationsProvider.future);
    expect(r, isA<RecsError>());
    expect((r as RecsError).reason, contains('HTTP 503'));
  });

  test('one artist failing: the list says which', () async {
    await play('Kaito Ren', 'Tokyo Rain');
    await play('Orbit Theory', 'Small Hours');
    final c = await container(FakeDeezer(failing: {'Orbit Theory'}));
    final r = await c.read(recommendationsProvider.future) as RecsReady;
    expect(r.failedSeeds, ['Orbit Theory']);
    expect(r.songs, isNotEmpty);
  });

  test('artists Deezer doesn\'t know: an error, not an empty list', () async {
    await play('Nobody Knows', 'Track');
    final c = await container(FakeDeezer(unknown: {'Nobody Knows'}));
    final r = await c.read(recommendationsProvider.future);
    expect((r as RecsError).reason, contains('Nobody Knows'));
  });

  test('an artist Deezer doesn\'t know is replaced, not reported as a '
      'failure', () async {
    // Retrying can't fix an artist Deezer doesn't have, so it must not put
    // "couldn't load" under every list; the next artist takes its place.
    await play('Kaito Ren', 'Tokyo Rain');
    await play('Nobody Knows', 'Track');
    final c = await container(FakeDeezer(unknown: {'Nobody Knows'}));
    final r = await c.read(recommendationsProvider.future) as RecsReady;
    expect(r.failedSeeds, isEmpty);
    expect(r.songs, isNotEmpty);
  });

  test('a Navidrome credit "A • B" seeds A and B, not the joined name',
      () async {
    // The bug behind the permanent "couldn't load suggestions" note: the
    // joined display artist was searched on Deezer and never found.
    await play('qaraqshy • !Nxght • KIXIA', 'Track');
    final deezer = FakeDeezer(unknown: {'qaraqshy • !Nxght • KIXIA'});
    final c = await container(deezer);
    final r = await c.read(recommendationsProvider.future) as RecsReady;
    expect(r.failedSeeds, isEmpty);
    expect(deezer.searched, isNot(contains('qaraqshy • !Nxght • KIXIA')));
    expect(deezer.searched, containsAll(['qaraqshy', '!Nxght', 'KIXIA']));
  });

  test('"A, B" is tried whole first, then each part', () async {
    await play('MC KAIQUE SP, merunes', 'Track');
    final deezer = FakeDeezer(unknown: {'MC KAIQUE SP, merunes'});
    final c = await container(deezer);
    final r = await c.read(recommendationsProvider.future) as RecsReady;
    expect(r.failedSeeds, isEmpty);
    expect(deezer.searched.take(2), ['MC KAIQUE SP, merunes', 'MC KAIQUE SP']);
  });

  test('"Earth, Wind & Fire" stays one artist when Deezer knows it',
      () async {
    await play('Earth, Wind & Fire', 'September');
    final deezer = FakeDeezer();
    final c = await container(deezer);
    await c.read(recommendationsProvider.future);
    expect(deezer.searched, ['Earth, Wind & Fire']);
  });

  group('taste signals from the database', () {
    test('skips, likes, pending likes, play counts and hides', () async {
      await db.upsertSongs([
        CachedSongsCompanion.insert(
            id: 's1', title: 'Neon', artist: 'Lumen Drift', album: 'X',
            genre: const Value('Phonk'), playCount: const Value(7),
            starred: Value(DateTime(2026, 11, 1))),
      ]);
      await db.addPendingLike(PendingLikesCompanion.insert(
          deezerId: const Value(9), title: 'Rec', artist: 'Glass Parade', album: 'Y'));
      await play('Lumen Drift', 'Neon', skipped: true);
      await db.addDismissedRec(DismissedRecsCompanion.insert(
          key: dismissedTrackKey('Bad', 'Meh'),
          kind: 'track',
          artist: 'Meh',
          title: const Value('Bad')));
      final s = await loadTasteSignals(db);
      expect(s.likes.map((l) => l.artist), ['Lumen Drift', 'Glass Parade']);
      expect(s.serverPlaysByArtist, {'Lumen Drift': 7});
      expect(s.genreByArtist, {'Lumen Drift': 'Phonk'});
      expect(s.history.single.skipped, isTrue);
      expect(s.history.single.genre, 'Phonk');
      expect(s.dismissedTracks, {keyFor('Bad', 'Meh')});
      expect(s.dismissalsByArtist, {'Meh': 1});
      expect(s.ownedTracks, {keyFor('Neon', 'Lumen Drift')});
    });
  });

  group('database', () {
    test('a finished listen is saved on the latest open play', () async {
      await play('A', 'T');
      await db.finishLatestPlay('A-T', listenedMs: 12000, skipped: true);
      await play('A', 'T');
      await db.finishLatestPlay('A-T', listenedMs: 200000, skipped: false);
      final rows = await db.getRecentHistory();
      expect(rows.map((r) => (r.listenedMs, r.skipped)).toSet(),
          {(12000, true), (200000, false)});
    });

    test('impressions count up and clear when played', () async {
      await db.countImpressions(['a|b', 'c|d']);
      await db.countImpressions(['a|b']);
      expect(await db.getImpressions(), {'a|b': 2, 'c|d': 1});
      await db.clearImpression('a|b');
      expect(await db.getImpressions(), {'c|d': 1});
    });

    test('reset forgets feedback but keeps history', () async {
      await play('A', 'T', skipped: true);
      await db.addMoreLikeThis('A');
      await db.countImpressions(['x']);
      await db.addDismissedRec(DismissedRecsCompanion.insert(
          key: 'artist:a', kind: 'artist', artist: 'A'));
      await db.resetRecommendationFeedback();
      expect(await db.getMoreLikeThis(), isEmpty);
      expect(await db.getImpressions(), isEmpty);
      expect(await db.getDismissedRecs(), isEmpty);
      final h = await db.getRecentHistory();
      expect(h.single.skipped, isFalse);
    });

    test('isDismissed matches a song or its whole artist', () async {
      await db.addDismissedRec(DismissedRecsCompanion.insert(
          key: dismissedArtistKey('Glass Parade'),
          kind: 'artist',
          artist: 'Glass Parade'));
      final rows = await db.getDismissedRecs();
      Song song(String artist, String title) => Song.fromRecommendation(
          deezerId: 1, title: title, artist: artist, album: '',
          durationSeconds: 1);
      expect(isDismissed(song('glass parade', 'X'), rows), isTrue);
      expect(isDismissed(song('Lumen Drift', 'X'), rows), isFalse);
    });
  });

  group('ListenEnd.isSkip', () {
    final s = Song.fromRecommendation(
        deezerId: 1, title: 'T', artist: 'A', album: '', durationSeconds: 200);
    test('left within 30 s of a full song', () {
      expect(ListenEnd(s, const Duration(seconds: 10),
              const Duration(minutes: 3)).isSkip, isTrue);
      expect(ListenEnd(s, const Duration(seconds: 45),
              const Duration(minutes: 3)).isSkip, isFalse);
    });
    test('a 30 s preview is never a skip', () {
      expect(ListenEnd(s, const Duration(seconds: 10),
              const Duration(seconds: 30)).isSkip, isFalse);
      expect(ListenEnd(s, const Duration(seconds: 10), null).isSkip, isFalse);
    });
  });
}
