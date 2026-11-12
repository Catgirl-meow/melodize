import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:melodize/core/api/subsonic_client.dart';
import 'package:melodize/core/downloads/download_files.dart';
import 'package:melodize/core/models/song.dart';

void main() {
  group('layout helpers', () {
    test('cover sits next to the audio file', () {
      expect(coverPathForAudio('/d/abc.flac'), '/d/abc.cover.jpg');
      expect(coverPathForAudio('/d/a.b.mp3'), '/d/a.b.cover.jpg');
    });

    test('base path sanitises ids', () {
      expect(downloadBasePath('/d', 'abc/../x'), '/d/abc_.._x');
      expect(downloadBasePath('/d', 'Zx9_-.'), '/d/Zx9_-.');
    });

    test('extension follows the real content type', () {
      expect(
          audioExtensionFor(contentType: 'audio/mpeg', fallbackSuffix: 'flac'),
          'mp3');
      expect(audioExtensionFor(contentType: 'audio/flac; charset=binary'),
          'flac');
      expect(audioExtensionFor(contentType: 'application/octet-stream',
              fallbackSuffix: 'FLAC'),
          'flac');
      expect(audioExtensionFor(), 'mp3');
    });

    test('subsonic error bodies are detected and parsed', () {
      expect(isSubsonicErrorContentType('application/json'), isTrue);
      expect(isSubsonicErrorContentType('text/xml; charset=utf-8'), isTrue);
      expect(isSubsonicErrorContentType('audio/flac'), isFalse);
      expect(
        subsonicErrorMessage(jsonEncode({
          'subsonic-response': {
            'status': 'failed',
            'error': {'code': 70, 'message': 'Song not found'}
          }
        })),
        'Song not found',
      );
      expect(
          subsonicErrorMessage(
              '<subsonic-response><error code="40" message="Wrong password"/></subsonic-response>'),
          'Wrong password');
    });
  });

  group('SubsonicClient downloads', () {
    late HttpServer server;
    late Directory tmp;
    late SubsonicClient client;
    // Per-path response: (content type, body bytes).
    final responses = <String, (String, List<int>)>{};

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('melodize_dl_test');
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((req) async {
        final r = responses[req.uri.path];
        if (r == null) {
          req.response.statusCode = 404;
        } else {
          req.response.headers.set('content-type', r.$1);
          req.response.contentLength = r.$2.length;
          req.response.add(r.$2);
        }
        await req.response.close();
      });
      client = SubsonicClient(SubsonicConfig(
        serverUrl: 'http://127.0.0.1:${server.port}',
        username: 'u',
        password: 'p',
      ));
    });

    tearDown(() async {
      responses.clear();
      await server.close(force: true);
      await tmp.delete(recursive: true);
    });

    const song = Song(
        id: 's1', title: 'T', artist: 'A', album: 'B', suffix: 'flac');

    test('transcoded download is named by its real format, no .part left',
        () async {
      responses['/rest/stream'] = ('audio/mpeg', List.filled(1000, 7));
      final path = await client.downloadSong(song, '${tmp.path}/s1',
          quality: '320');
      expect(path, '${tmp.path}/s1.mp3');
      expect(await File(path).length(), 1000);
      expect(tmp.listSync().where((e) => e.path.endsWith('.part')), isEmpty);
    });

    test('an API error body fails loudly and leaves no file', () async {
      responses['/rest/download'] = (
        'application/json',
        utf8.encode(jsonEncode({
          'subsonic-response': {
            'status': 'failed',
            'error': {'code': 50, 'message': 'User not authorized'}
          }
        })),
      );
      await expectLater(
        client.downloadSong(song, '${tmp.path}/s1'),
        throwsA(isA<DownloadContentException>().having(
            (e) => e.message, 'message', contains('User not authorized'))),
      );
      expect(tmp.listSync(), isEmpty);
    });

    test('cover art is saved, and a non-image answer throws', () async {
      responses['/rest/getCoverArt'] = ('image/jpeg', [1, 2, 3]);
      final cover = '${tmp.path}/s1.cover.jpg';
      await client.downloadCoverArt('al-1', cover);
      expect(await File(cover).readAsBytes(), [1, 2, 3]);

      responses['/rest/getCoverArt'] = ('text/xml',
          utf8.encode('<subsonic-response><error message="Not found"/>'
              '</subsonic-response>'));
      await expectLater(
        client.downloadCoverArt('al-2', '${tmp.path}/s2.cover.jpg'),
        throwsA(isA<DownloadContentException>()),
      );
      expect(File('${tmp.path}/s2.cover.jpg').existsSync(), isFalse);
    });
  });
}
