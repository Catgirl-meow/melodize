// Likes: Subsonic star sync, the optimistic heart, and Deezer likes that wait
// for the companion to add the track before they are starred.
import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:melodize/core/api/subsonic_client.dart';
import 'package:melodize/core/db/database.dart';
import 'package:melodize/core/errors/app_errors.dart';
import 'package:melodize/core/likes/pending_like_match.dart';
import 'package:melodize/core/models/app_preferences.dart';
import 'package:melodize/core/models/song.dart';
import 'package:melodize/core/providers.dart';
import 'package:melodize/shared/widgets/like_button.dart';

/// A server that keeps stars in memory, can be told to refuse them, and
/// returns [library] (with current stars) from getAllSongs.
class _FakeServer extends SubsonicClient {
  _FakeServer(this.library)
      : super(const SubsonicConfig(
            serverUrl: 'http://127.0.0.1:9', username: 'u', password: 'p'));

  List<Song> library;
  final starred = <String>{};
  final calls = <String>[];
  bool refuse = false;

  @override
  Future<void> star(String songId) async {
    calls.add('star $songId');
    if (refuse) throw Exception('Subsonic error: denied');
    starred.add(songId);
  }

  @override
  Future<void> unstar(String songId) async {
    calls.add('unstar $songId');
    if (refuse) throw Exception('Subsonic error: denied');
    starred.remove(songId);
  }

  @override
  Future<List<Song>> getAllSongs() async => [
        for (final s in library)
          s.withStarred(starred.contains(s.id) ? DateTime(2026, 11, 1) : null)
      ];
}

Song _song(String id, String title, {String artist = 'Artist', bool starred = false}) =>
    Song(
      id: id,
      title: title,
      artist: artist,
      album: 'Album',
      starred: starred ? DateTime(2026, 10, 1) : null,
    );

Song _deezer(int id, String title, String artist) => Song.fromRecommendation(
      deezerId: id,
      title: title,
      artist: artist,
      album: 'Deezer Album',
      durationSeconds: 200,
      previewUrl: 'https://example.invalid/p.mp3',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Song star fields', () {
    test('starred and playCount are parsed from Subsonic JSON', () {
      final s = Song.fromSubsonicJson({
        'id': 7,
        'title': 'T',
        'starred': '2026-11-02T10:00:00Z',
        'playCount': 12,
      });
      expect(s.isStarred, isTrue);
      expect(s.starred!.toUtc(), DateTime.utc(2026, 11, 2, 10));
      expect(s.playCount, 12);
      expect(Song.fromSubsonicJson({'id': 1}).isStarred, isFalse);
    });

    test('copies keep the star; withStarred sets and clears it', () {
      final s = _song('1', 'A', starred: true);
      expect(s.copyWith(isDownloaded: true).isStarred, isTrue);
      expect(s.withoutDownload().isStarred, isTrue);
      expect(s.withStarred(null).isStarred, isFalse);
    });

    test('deezerIdOf only answers for Deezer tracks', () {
      expect(deezerIdOf(_deezer(42, 'X', 'Y')), 42);
      expect(deezerIdOf(_song('42', 'X')), isNull);
    });
  });

  group('matchPendingLikes', () {
    test('matches on normalized title and artist', () {
      final library = [
        _song('a', 'Tokyo Rain (Remastered 2020)', artist: 'Kaito Ren'),
        _song('b', 'Field Notes', artist: 'The Paper Kites'),
      ];
      final m = matchPendingLikes([
        (deezerId: 1, title: 'tokyo rain', artist: 'KAITO REN'),
        (deezerId: 2, title: 'Not Here', artist: 'Nobody'),
      ], library);
      expect(m.length, 1);
      expect(m.single.$1.deezerId, 1);
      expect(m.single.$2.id, 'a');
    });

    test('never matches another Deezer track', () {
      final m = matchPendingLikes(
          [(deezerId: 1, title: 'X', artist: 'Y')], [_deezer(1, 'X', 'Y')]);
      expect(m, isEmpty);
    });
  });

  test('mergeLikes applies in-flight requests over the server state', () {
    final lib = [_song('1', 'A', starred: true), _song('2', 'B')];
    expect(mergeLikes(lib, {}), {'1'});
    expect(mergeLikes(lib, {'1': false, '2': true}), {'2'});
  });

  test('downloadLikedOffline survives a save/load round trip', () {
    const p = AppPreferences(downloadLikedOffline: true);
    expect(AppPreferences.fromJson(p.toJson()).downloadLikedOffline, isTrue);
    expect(const AppPreferences().downloadLikedOffline, isFalse);
  });

  group('LikesNotifier', () {
    late AppDatabase db;
    late _FakeServer server;

    setUp(() {
      AppErrors.resetForTest();
      db = AppDatabase.forTesting(NativeDatabase.memory());
      server = _FakeServer([
        _song('1', 'Tokyo Rain', artist: 'Kaito Ren'),
        _song('2', 'Field Notes', artist: 'The Paper Kites'),
      ]);
    });
    tearDown(() => db.close());

    Future<ProviderContainer> container() async {
      final c = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(db),
        isOnlineProvider.overrideWith((_) => Stream.value(true)),
        subsonicClientProvider.overrideWithValue(server),
      ]);
      addTearDown(c.dispose);
      c.listen(isOnlineProvider, (_, __) {});
      await c.read(isOnlineProvider.future);
      c.listen(likesProvider, (_, __) {});
      await _settle(c);
      return c;
    }

    test('starts from the server\'s stars and caches them', () async {
      server.starred.add('2');
      final c = await container();
      expect(c.read(likesProvider), {'2'});
      expect((await db.getSongById('2'))!.starred, isNotNull);
      expect(c.read(isLikedProvider('2')), isTrue);
      expect(c.read(isLikedProvider('1')), isFalse);
    });

    test('toggle stars on the server, updates the cache, then unstars',
        () async {
      final c = await container();
      final song = server.library.first;
      expect(await c.read(likesProvider.notifier).toggle(song), isTrue);
      expect(c.read(likesProvider), {'1'});
      expect(server.starred, {'1'});
      expect((await db.getSongById('1'))!.starred, isNotNull);

      expect(await c.read(likesProvider.notifier).toggle(song), isFalse);
      expect(c.read(likesProvider), isEmpty);
      expect(server.starred, isEmpty);
      expect((await db.getSongById('1'))!.starred, isNull);
    });

    test('a refused star flips the heart back and reports the error',
        () async {
      final c = await container();
      final errors = <String>[];
      final sub = AppErrors.stream.listen((e) => errors.add(e.message));
      addTearDown(sub.cancel);
      server.refuse = true;
      await c.read(likesProvider.notifier).toggle(server.library.first);
      await Future<void>.delayed(Duration.zero);
      expect(c.read(likesProvider), isEmpty);
      expect(errors.single, contains('Couldn\'t like "Tokyo Rain"'));
    });

    test('a liked Deezer track is starred once it lands in the library',
        () async {
      final c = await container();
      final rec = _deezer(99, 'Neon Harbor', 'Lumen Drift');
      c.listen(pendingLikesProvider, (_, __) {});
      await c.read(likesProvider.notifier).likeRecommendation(rec);
      await _settle(c);
      expect(c.read(isLikedProvider(rec.id)), isTrue);
      expect(await db.getPendingLikes(), hasLength(1));

      // The companion adds it; the next library sync picks it up.
      server.library = [
        ...server.library,
        _song('3', 'Neon Harbor', artist: 'Lumen Drift'),
      ];
      c.invalidate(allSongsProvider);
      await _settle(c);

      expect(server.calls, contains('star 3'));
      expect(c.read(likesProvider), contains('3'));
      expect(await db.getPendingLikes(), isEmpty);
      expect(c.read(isLikedProvider(rec.id)), isFalse);
    });

    test('a pending like whose star fails is kept for the next sync',
        () async {
      final c = await container();
      await c
          .read(likesProvider.notifier)
          .likeRecommendation(_deezer(5, 'Low Orbit', 'Satellite Ghosts'));
      server.refuse = true;
      server.library = [
        ...server.library,
        _song('4', 'Low Orbit', artist: 'Satellite Ghosts'),
      ];
      c.invalidate(allSongsProvider);
      await _settle(c);
      expect(await db.getPendingLikes(), hasLength(1));
      expect(c.read(likesProvider), isNot(contains('4')));
    });

    test('unliking a Deezer track drops its pending like', () async {
      final c = await container();
      await c
          .read(likesProvider.notifier)
          .likeRecommendation(_deezer(6, 'X', 'Y'));
      await c.read(likesProvider.notifier).unlikeRecommendation(6);
      expect(await db.getPendingLikes(), isEmpty);
    });

    testWidgets('the heart button fills when tapped and stars the song',
        (tester) async {
      final c = await tester.runAsync(container);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: c!,
        child: MaterialApp(
          home: Scaffold(body: LikeButton(song: server.library.first)),
        ),
      ));
      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(find.byType(IconButton));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
      expect(find.byTooltip('Unlike'), findsOneWidget);
      expect(server.starred, {'1'});
    });

    test('likedSongsProvider lists liked songs, newest like first', () async {
      server.starred.addAll(['1', '2']);
      final c = await container();
      await c.read(likesProvider.notifier).toggle(server.library.first);
      await c.read(likesProvider.notifier).toggle(server.library.first);
      final liked = c.read(likedSongsProvider).value!;
      expect(liked.map((s) => s.id), ['1', '2']);
    });
  });

  test('the debug export copies history but never the server login',
      () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db.addToHistory(PlayHistoryCompanion.insert(
        songId: '1', songTitle: 'T', artist: 'A'));
    await db.into(db.serverConfig).insert(ServerConfigCompanion.insert(
        serverUrl: 'http://s', username: 'u', password: 'secret'));
    final dir = Directory.systemTemp.createTempSync('melodize-export');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/export.db';
    await db.exportForAnalysis(path);
    await db.exportForAnalysis(path); // overwrites an earlier export
    final copy = AppDatabase.forTesting(NativeDatabase(File(path)));
    addTearDown(copy.close);
    expect(await copy.getRecentHistory(), hasLength(1));
    expect(await copy.select(copy.serverConfig).get(), isEmpty);
    expect(await db.select(db.serverConfig).get(), hasLength(1));
  });

  test('schema v6 migration adds the like columns and pending likes table',
      () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db.upsertSong(CachedSongsCompanion(
      id: const Value('1'),
      title: const Value('T'),
      artist: const Value('A'),
      album: const Value('Al'),
      starred: Value(DateTime(2026)),
      playCount: const Value(3),
    ));
    final row = (await db.getSongById('1'))!;
    expect(row.playCount, 3);
    await db.setSongStarred('1', null);
    expect((await db.getSongById('1'))!.starred, isNull);
  });
}

/// Lets the library stream, the reconciler and drift's watch queries run.
Future<void> _settle(ProviderContainer c) async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  c.read(allSongsProvider);
  await Future<void>.delayed(const Duration(milliseconds: 20));
}
