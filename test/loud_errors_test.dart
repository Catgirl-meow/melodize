import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:melodize/core/api/subsonic_client.dart';
import 'package:melodize/core/errors/app_errors.dart';

class _FakeAdapter implements HttpClientAdapter {
  final ResponseBody Function(RequestOptions) handler;
  _FakeAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

SubsonicClient _client(ResponseBody Function(RequestOptions) handler) {
  final dio = Dio(BaseOptions(baseUrl: 'http://nd.test'))
    ..httpClientAdapter = _FakeAdapter(handler);
  return SubsonicClient(
    const SubsonicConfig(
        serverUrl: 'http://nd.test', username: 'u', password: 'p'),
    dio: dio,
  );
}

ResponseBody _json(int status, Object body) =>
    ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });

void main() {
  group('describeError', () {
    test('keeps the HTTP status of a bad response', () {
      final e = DioException.badResponse(
        statusCode: 503,
        requestOptions: RequestOptions(path: '/rest/ping'),
        response: Response(
            requestOptions: RequestOptions(path: '/rest/ping'),
            statusCode: 503),
      );
      expect(describeError(e), 'Server error (HTTP 503)');
    });

    test('names the OS error of a refused connection', () {
      final e = DioException.connectionError(
        requestOptions: RequestOptions(path: '/'),
        reason: 'refused',
        error: const SocketException('Connection refused',
            osError: OSError('Connection refused', 111)),
      );
      expect(describeError(e), 'Could not connect: Connection refused');
    });

    test('strips Dart exception prefixes', () {
      expect(describeError(Exception('Subsonic error: Wrong password')),
          'Wrong password');
    });
  });

  group('AppErrors', () {
    setUp(AppErrors.resetForTest);

    test('buffers errors until the first listener and then delivers them',
        () async {
      AppErrors.report('Startup failure A');
      AppErrors.report("Couldn't save settings", Exception('disk full'));
      final got = <String>[];
      final sub = AppErrors.stream.listen((e) => got.add(e.message));
      await Future<void>.delayed(Duration.zero);
      expect(got, [
        'Startup failure A',
        "Couldn't save settings: disk full",
      ]);
      await sub.cancel();
    });

    test('shows one failure reported twice in quick succession once',
        () async {
      final got = <String>[];
      final sub = AppErrors.stream.listen((e) => got.add(e.message));
      await Future<void>.delayed(Duration.zero);
      AppErrors.report('Playback failed', Exception('404'));
      AppErrors.report('Playback failed', Exception('404'));
      AppErrors.report('Playback failed', Exception('500'));
      await Future<void>.delayed(Duration.zero);
      expect(got, ['Playback failed: 404', 'Playback failed: 500']);
      await sub.cancel();
    });
  });

  group('SubsonicClient no longer hides failures as empty results', () {
    test('top songs failure is an error, not an empty list', () async {
      final client = _client((_) => _json(500, {}));
      expect(client.getTopSongs('Artist'), throwsA(isA<DioException>()));
    });

    test('a non-Subsonic page says so instead of a cast error', () async {
      final client = _client((_) => ResponseBody.fromString(
            '<html>login</html>',
            200,
            headers: {
              Headers.contentTypeHeader: ['text/html'],
            },
          ));
      await expectLater(
        client.getArtists(),
        throwsA(isA<FormatException>().having((e) => e.message, 'message',
            contains('did not return a Subsonic response'))),
      );
    });

    test('an empty top-songs answer is still an empty list', () async {
      final client = _client((_) => _json(200, {
            'subsonic-response': {'status': 'ok', 'topSongs': {}},
          }));
      expect(await client.getTopSongs('Artist'), isEmpty);
    });
  });
}
