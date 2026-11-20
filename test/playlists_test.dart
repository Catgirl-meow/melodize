import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:melodize/core/api/subsonic_client.dart';
import 'package:melodize/core/models/playlist.dart';
import 'package:melodize/core/playlists/playlist_cache.dart';
import 'package:melodize/core/playlists/playlist_edits.dart';

class _FakeAdapter implements HttpClientAdapter {
  final ResponseBody Function(RequestOptions) handler;
  _FakeAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(RequestOptions options,
          Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async =>
      handler(options);

  @override
  void close({bool force = false}) {}
}

ResponseBody _ok([Map<String, dynamic> extra = const {}]) =>
    ResponseBody.fromString(
        jsonEncode({
          'subsonic-response': {'status': 'ok', ...extra}
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        });

void main() {
  group('planSongChange', () {
    test('identical lists need no request', () {
      expect(planSongChange(['a', 'b'], ['a', 'b']), isA<NoSongChange>());
    });

    test('removals keep server indices, duplicates included', () {
      final c = planSongChange(['a', 'b', 'a', 'c'], ['a', 'c']);
      expect(c, isA<RemoveSongs>());
      expect((c as RemoveSongs).indices, [1, 2]);
    });

    test('appends only send the new ids', () {
      final c = planSongChange(['a'], ['a', 'b', 'c']);
      expect((c as AppendSongs).songIds, ['b', 'c']);
    });

    test('a reorder replaces the list', () {
      final c = planSongChange(['a', 'b', 'c'], ['c', 'a', 'b']);
      expect((c as ReplaceSongs).songIds, ['c', 'a', 'b']);
    });

    test('remove plus reorder replaces the list', () {
      final c = planSongChange(['a', 'b', 'c'], ['c', 'a']);
      expect((c as ReplaceSongs).songIds, ['c', 'a']);
    });

    test('emptying a playlist removes every index', () {
      final c = planSongChange(['a', 'b'], []);
      expect((c as RemoveSongs).indices, [0, 1]);
    });
  });

  group('reorderedList', () {
    test('uses ReorderableListView indices for downward moves', () {
      // Dragging "a" below "c": Flutter reports newIndex 3.
      expect(reorderedList(['a', 'b', 'c'], 0, 3), ['b', 'c', 'a']);
      expect(reorderedList(['a', 'b', 'c'], 0, 2), ['b', 'a', 'c']);
    });

    test('upward moves use the index as is', () {
      expect(reorderedList(['a', 'b', 'c'], 2, 0), ['c', 'a', 'b']);
    });
  });

  test('splitNewSongs de-duplicates and keeps order', () {
    final r = splitNewSongs(['x', 'y'], ['a', 'x', 'b', 'a', 'y']);
    expect(r.fresh, ['a', 'b']);
    expect(r.already, ['x', 'y']);
  });

  test('copyName skips names in use, ignoring case', () {
    expect(copyName('Gym', ['Gym']), 'Gym (copy)');
    expect(copyName('Gym', ['Gym', 'gym (COPY)']), 'Gym (copy 2)');
    expect(copyName('Gym', ['Gym (copy)', 'Gym (copy 2)']), 'Gym (copy 3)');
  });

  test('validatePlaylistName', () {
    expect(validatePlaylistName('  '), isNotNull);
    expect(validatePlaylistName(null), isNotNull);
    expect(validatePlaylistName(' Road trip '), isNull);
    expect(validatePlaylistName('x' * 201), isNotNull);
  });

  group('Playlist', () {
    test('reads owner, readonly and an empty comment as none', () {
      final p = Playlist.fromSubsonicJson({
        'id': 7,
        'name': 'Mix',
        'comment': ' ',
        'songCount': 3,
        'duration': 600,
        'owner': 'admin',
        'public': true,
        'readonly': true,
        'changed': '2026-11-20T10:00:00Z',
      });
      expect(p.id, '7');
      expect(p.comment, isNull);
      expect(p.owner, 'admin');
      expect(p.public, isTrue);
      expect(p.readonly, isTrue);
      expect(p.changedAt, DateTime.utc(2026, 11, 20, 10));
    });

    test('editable only by its owner and never when readonly', () {
      const mine = Playlist(
          id: '1', name: 'a', songCount: 0, duration: 0, changed: '',
          owner: 'test');
      expect(mine.isEditableBy('test'), isTrue);
      expect(mine.isEditableBy('other'), isFalse);
      const smart = Playlist(
          id: '2', name: 'b', songCount: 0, duration: 0, changed: '',
          owner: 'test', readonly: true);
      expect(smart.isEditableBy('test'), isFalse);
      const unknownOwner = Playlist(
          id: '3', name: 'c', songCount: 0, duration: 0, changed: '');
      expect(unknownOwner.isEditableBy('test'), isTrue);
    });

    test('toJson round-trips', () {
      const p = Playlist(
          id: '1', name: 'a', comment: 'c', songCount: 2, duration: 9,
          coverArt: 'pl-1', changed: 'x', owner: 'o', public: true);
      final back = Playlist.fromSubsonicJson(p.toJson());
      expect(back.toJson(), p.toJson());
    });
  });

  group('SubsonicClient playlist calls', () {
    late List<Uri> calls;
    late SubsonicClient client;
    Map<String, dynamic> next = const {};

    setUp(() {
      calls = [];
      next = const {};
      final dio = Dio(BaseOptions(baseUrl: 'http://nd.test'))
        ..httpClientAdapter = _FakeAdapter((o) {
          calls.add(o.uri);
          return _ok(next);
        });
      client = SubsonicClient(
        const SubsonicConfig(
            serverUrl: 'http://nd.test', username: 'u', password: 'p'),
        dio: dio,
      );
    });

    test('createPlaylist repeats songId and returns the new playlist',
        () async {
      next = {
        'playlist': {'id': 'p1', 'name': 'Road trip', 'songCount': 2}
      };
      final p = await client.createPlaylist('Road trip', songIds: ['a', 'b']);
      expect(p.id, 'p1');
      final uri = calls.single;
      expect(uri.path, '/rest/createPlaylist');
      expect(uri.queryParametersAll['songId'], ['a', 'b']);
      expect(uri.queryParameters['name'], 'Road trip');
    });

    test('updatePlaylist sends adds and removals as repeated params',
        () async {
      await client.updatePlaylist('p1',
          name: 'New', addSongIds: ['x', 'y'], removeIndices: [0, 3]);
      final uri = calls.single;
      expect(uri.path, '/rest/updatePlaylist');
      expect(uri.queryParameters['playlistId'], 'p1');
      expect(uri.queryParameters['name'], 'New');
      expect(uri.queryParametersAll['songIdToAdd'], ['x', 'y']);
      expect(uri.queryParametersAll['songIndexToRemove'], ['0', '3']);
      expect(uri.queryParameters.containsKey('comment'), isFalse);
    });

    test('replacePlaylistSongs overwrites through createPlaylist', () async {
      await client.replacePlaylistSongs('p1', ['c', 'a']);
      final uri = calls.single;
      expect(uri.path, '/rest/createPlaylist');
      expect(uri.queryParameters['playlistId'], 'p1');
      expect(uri.queryParametersAll['songId'], ['c', 'a']);
      expect(uri.queryParameters.containsKey('name'), isFalse);
    });

    test('deletePlaylist', () async {
      await client.deletePlaylist('p1');
      expect(calls.single.path, '/rest/deletePlaylist');
      expect(calls.single.queryParameters['id'], 'p1');
    });

    test('a failed status throws', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://nd.test'))
        ..httpClientAdapter = _FakeAdapter((_) => ResponseBody.fromString(
                jsonEncode({
                  'subsonic-response': {
                    'status': 'failed',
                    'error': {'code': 50, 'message': 'not owner'}
                  }
                }),
                200,
                headers: {
                  Headers.contentTypeHeader: [Headers.jsonContentType],
                }));
      final c = SubsonicClient(
          const SubsonicConfig(
              serverUrl: 'http://nd.test', username: 'u', password: 'p'),
          dio: dio);
      expect(c.deletePlaylist('p1'), throwsA(isA<Exception>()));
    });
  });

  group('PlaylistCache', () {
    late Directory dir;
    late PlaylistCache cache;
    setUp(() async {
      dir = await Directory.systemTemp.createTemp('pl-cache');
      cache = PlaylistCache(directory: () async => dir);
    });
    tearDown(() => dir.delete(recursive: true));

    const a = Playlist(
        id: '1', name: 'A', songCount: 2, duration: 1, changed: '');
    const b = Playlist(
        id: '2', name: 'B', songCount: 1, duration: 1, changed: '');

    test('empty cache answers null, not an empty list', () async {
      expect(await cache.playlists('acc'), isNull);
      expect(await cache.songIds('acc', '1'), isNull);
    });

    test('stores playlists and song order per account', () async {
      await cache.savePlaylists('acc', [a, b]);
      await cache.saveSongIds('acc', '1', ['s2', 's1']);
      expect((await cache.playlists('acc'))!.map((p) => p.name), ['A', 'B']);
      expect(await cache.songIds('acc', '1'), ['s2', 's1']);
      expect(await cache.playlists('other'), isNull);
    });

    test('drops songs of playlists that no longer exist', () async {
      await cache.savePlaylists('acc', [a, b]);
      await cache.saveSongIds('acc', '2', ['s']);
      await cache.savePlaylists('acc', [a]);
      expect(await cache.songIds('acc', '2'), isNull);
    });
  });
}
