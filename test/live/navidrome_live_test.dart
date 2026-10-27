// Live tests against a real Navidrome. Skipped unless these are set:
//
//   MELODIZE_TEST_SERVER=http://localhost:4534
//   MELODIZE_TEST_USER=test
//   MELODIZE_TEST_PASSWORD=...
//
// Point them at a throwaway server with the generated test library
// (scripts/test-navidrome.sh), never at a production server.
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:melodize/core/api/subsonic_client.dart';

void main() {
  final env = Platform.environment;
  final server = env['MELODIZE_TEST_SERVER'];
  final user = env['MELODIZE_TEST_USER'];
  final password = env['MELODIZE_TEST_PASSWORD'];
  final skip = (server == null || user == null || password == null)
      ? 'set MELODIZE_TEST_SERVER/USER/PASSWORD to run live tests'
      : null;

  late SubsonicClient client;
  setUpAll(() {
    if (skip != null) return;
    client = SubsonicClient(SubsonicConfig(
        serverUrl: '$server/', username: user!, password: password!));
  });

  group('live Navidrome', skip: skip, () {
    test('ping succeeds and wrong credentials are rejected', () async {
      expect(await client.pingDetailed(), ServerReachability.reachable);
      final bad = SubsonicClient(SubsonicConfig(
          serverUrl: server!, username: user!, password: 'wrong-$password'));
      expect(await bad.ping(), isFalse);
    });

    test('getAllSongs pages through the whole library', () async {
      final songs = await client.getAllSongs();
      // 29 generated tracks; delete-flow testing may have removed a few.
      expect(songs.length, greaterThanOrEqualTo(20));
      expect(songs.map((s) => s.id).toSet().length, songs.length,
          reason: 'no duplicates across pages');
    });

    test('unicode, untagged and very long metadata survive parsing', () async {
      final songs = await client.getAllSongs();
      final titles = songs.map((s) => s.title).toSet();
      expect(titles, contains('Песня №1'));
      expect(titles, contains('曲 1'));
      expect(titles.any((t) => t.length > 100), isTrue);
      // A file with no tags: Navidrome falls back to the file name.
      expect(titles, contains('no tags'));
      for (final s in songs) {
        expect(s.id, isNotEmpty);
        expect(s.duration, isNotNull, reason: s.title);
      }
    });

    test('search finds Cyrillic and special-character titles', () async {
      final ru = await client.search('Песня');
      expect(ru.songs.length, 3);
      final amp = await client.search('Compilation');
      expect(amp.albums.single.name, contains('<Specials>'));
    });

    test('albums, artists and album tracks are consistent', () async {
      final albums = await client.getAlbums(size: 500);
      expect(albums, isNotEmpty);
      final artists = await client.getArtists();
      expect(artists.map((a) => a.name), contains('Группа Кино'));
      final electro = albums.firstWhere((a) => a.name == 'Electro Album');
      final tracks = await client.getAlbumSongs(electro.id);
      expect(tracks.map((t) => t.track), [1, 2, 3, 4, 5, 6]);
    });

    test('stream and cover URLs are fetchable', () async {
      final songs = await client.getAllSongs();
      // The 96 kHz/24-bit file: its bitrate is well above 128 kbps, so
      // Navidrome has to transcode it for the 128 quality setting.
      final flac = songs.firstWhere((s) => s.title == '96kHz 24bit');
      expect(flac.bitRate, greaterThan(128));
      final dio = Dio();
      final resp = await dio.get<List<int>>(client.streamUrl(flac.id),
          options: Options(responseType: ResponseType.bytes));
      expect(resp.statusCode, 200);
      expect(String.fromCharCodes(resp.data!.take(4)), 'fLaC',
          reason: 'lossless streams the original file');

      final mp3 = await dio.get<List<int>>(
          client.streamUrl(flac.id, quality: '128'),
          options: Options(responseType: ResponseType.bytes));
      expect(mp3.statusCode, 200);
      expect(mp3.data!.length, lessThan(resp.data!.length),
          reason: 'transcoded stream is smaller than the FLAC');
    });

    test('downloadSong writes the original file', () async {
      final songs = await client.getAllSongs();
      final s = songs.firstWhere((s) => s.title == 'One Second');
      final dir = await Directory.systemTemp.createTemp('melodize_live');
      try {
        final path = '${dir.path}/${s.id}.${s.suffix}';
        var lastReceived = 0;
        await client.downloadSong(s, path,
            onProgress: (received, _) => lastReceived = received);
        final f = File(path);
        expect(await f.length(), s.size);
        expect(lastReceived, s.size);
      } finally {
        await dir.delete(recursive: true);
      }
    });

    test('unknown ids fail cleanly', () async {
      expect(() => client.getAlbumSongs('does-not-exist'), throwsException);
      expect(await client.getSimilarSongs('does-not-exist'), isEmpty);
    });
  });
}
