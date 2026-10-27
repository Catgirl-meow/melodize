import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:melodize/core/api/navidrome_native_client.dart';
import 'package:melodize/core/api/subsonic_client.dart';

// Answers requests from a handler and records what was sent.
class _FakeAdapter implements HttpClientAdapter {
  final ResponseBody Function(RequestOptions) handler;
  final requests = <RequestOptions>[];
  _FakeAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(int status, Object body, {Map<String, List<String>>? headers}) =>
    ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
      ...?headers,
    });

const _config = SubsonicConfig(
    serverUrl: 'http://nd.test/', username: 'u', password: 'p');

NavidromeNativeClient _client(_FakeAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'http://nd.test'))
    ..httpClientAdapter = adapter;
  return NavidromeNativeClient(_config, dio: dio);
}

void main() {
  test('logs in once and deletes only the given ids', () async {
    final adapter = _FakeAdapter((o) {
      if (o.path == '/auth/login') return _json(200, {'token': 'tok'});
      return _json(200, {'ids': ['a b']});
    });
    final client = _client(adapter);

    expect(await client.removeMissingFiles(['a b']), isTrue);
    expect(await client.removeMissingFiles(['c']), isTrue);

    final logins = adapter.requests.where((r) => r.path == '/auth/login');
    expect(logins, hasLength(1));
    final del = adapter.requests[1];
    expect(del.method, 'DELETE');
    expect(del.uri.toString(), 'http://nd.test/api/missing?id=a+b');
    expect(del.headers['X-ND-Authorization'], 'Bearer tok');
  });

  test('empty list never reaches the server', () async {
    final adapter = _FakeAdapter((_) => _json(200, {}));
    expect(await _client(adapter).removeMissingFiles([]), isTrue);
    expect(adapter.requests, isEmpty);
  });

  test('404 means not flagged missing yet', () async {
    final adapter = _FakeAdapter((o) => o.path == '/auth/login'
        ? _json(200, {'token': 'tok'})
        : ResponseBody.fromString('not found', 404));
    expect(await _client(adapter).removeMissingFiles(['x']), isFalse);
  });

  test('re-logs in when the token expired', () async {
    var deletes = 0;
    final adapter = _FakeAdapter((o) {
      if (o.path == '/auth/login') return _json(200, {'token': 'tok'});
      deletes++;
      return deletes == 2
          ? _json(200, {})
          : ResponseBody.fromString('expired', 401);
    });
    final client = _client(adapter);
    expect(await client.removeMissingFiles(['x']), isTrue);
    expect(adapter.requests.where((r) => r.path == '/auth/login'), hasLength(2));
  });

  test('purgeDeletedSongs waits for the scan, then rescans until flagged',
      () async {
    var deleteCalls = 0;
    final nd = _FakeAdapter((o) {
      if (o.path == '/auth/login') return _json(200, {'token': 'tok'});
      deleteCalls++;
      return deleteCalls < 2
          ? ResponseBody.fromString('not found', 404)
          : _json(200, {});
    });
    var statusCalls = 0;
    final rest = <String>[];
    final subsonicDio = Dio()
      ..httpClientAdapter = _FakeAdapter((o) {
        rest.add(o.path);
        final scanning = o.path.endsWith('getScanStatus') && statusCalls++ < 2;
        return _json(200, {
          'subsonic-response': {
            'status': 'ok',
            'scanStatus': {'scanning': scanning},
          }
        });
      });
    final subsonic = SubsonicClient(_config, dio: subsonicDio);

    await purgeDeletedSongs(
      subsonic: subsonic,
      native: _client(nd),
      songIds: ['x'],
      pollInterval: Duration.zero,
    );

    expect(deleteCalls, 2);
    expect(rest.where((p) => p.endsWith('startScan')), hasLength(1));
    expect(rest.where((p) => p.endsWith('getScanStatus')).length,
        greaterThanOrEqualTo(3));
  });

  test('remove all skips the delete when nothing is missing', () async {
    final adapter = _FakeAdapter((o) {
      if (o.path == '/auth/login') return _json(200, {'token': 'tok'});
      return _json(200, [], headers: {'x-total-count': ['0']});
    });
    expect(await _client(adapter).removeAllMissingFiles(), 0);
    expect(adapter.requests.where((r) => r.method == 'DELETE'), isEmpty);
  });

  test('remove all reports the count it removed', () async {
    final adapter = _FakeAdapter((o) {
      if (o.path == '/auth/login') return _json(200, {'token': 'tok'});
      if (o.method == 'GET') {
        return _json(200, [{}], headers: {'x-total-count': ['83']});
      }
      return _json(200, {});
    });
    expect(await _client(adapter).removeAllMissingFiles(), 83);
    final del = adapter.requests.last;
    expect(del.method, 'DELETE');
    expect(del.uri.query, isEmpty);
  });
}
