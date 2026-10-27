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
  // Answers a GET of /api/missing with the rows in [missing] whose id was
  // asked for, the way Navidrome filters by id.
  ResponseBody missingList(RequestOptions o, Set<String> missing) => _json(
      200,
      [
        for (final id in o.uri.queryParametersAll['id'] ?? const <String>[])
          if (missing.contains(id)) {'id': id}
      ]);

  test('logs in once and deletes only the flagged ids', () async {
    final adapter = _FakeAdapter((o) {
      if (o.path == '/auth/login') return _json(200, {'token': 'tok'});
      if (o.method == 'GET') return missingList(o, {'a b', 'c'});
      return _json(200, {});
    });
    final client = _client(adapter);

    expect(await client.removeMissingFiles(['a b']), isTrue);
    expect(await client.removeMissingFiles(['c']), isTrue);

    final logins = adapter.requests.where((r) => r.path == '/auth/login');
    expect(logins, hasLength(1));
    final del = adapter.requests.firstWhere((r) => r.method == 'DELETE');
    expect(del.uri.toString(), 'http://nd.test/api/missing?id=a+b');
    expect(del.headers['X-ND-Authorization'], 'Bearer tok');
  });

  test('empty list never reaches the server', () async {
    final adapter = _FakeAdapter((_) => _json(200, {}));
    expect(await _client(adapter).removeMissingFiles([]), isTrue);
    expect(adapter.requests, isEmpty);
  });

  test('not flagged yet: returns false and sends no delete', () async {
    // Navidrome answers a delete of unknown ids with 200, so a bare delete
    // would wrongly report success.
    final adapter = _FakeAdapter((o) {
      if (o.path == '/auth/login') return _json(200, {'token': 'tok'});
      if (o.method == 'GET') return missingList(o, {});
      return _json(200, {});
    });
    expect(await _client(adapter).removeMissingFiles(['x']), isFalse);
    expect(adapter.requests.where((r) => r.method == 'DELETE'), isEmpty);
  });

  test('partly flagged: deletes those and reports not done', () async {
    final adapter = _FakeAdapter((o) {
      if (o.path == '/auth/login') return _json(200, {'token': 'tok'});
      if (o.method == 'GET') return missingList(o, {'x'});
      return _json(200, {});
    });
    expect(await _client(adapter).removeMissingFiles(['x', 'y']), isFalse);
    final del = adapter.requests.firstWhere((r) => r.method == 'DELETE');
    expect(del.uri.query, 'id=x');
  });

  test('re-logs in when the token expired', () async {
    var gets = 0;
    final adapter = _FakeAdapter((o) {
      if (o.path == '/auth/login') return _json(200, {'token': 'tok'});
      if (o.method == 'GET' && gets++ == 0) {
        return ResponseBody.fromString('expired', 401);
      }
      if (o.method == 'GET') return missingList(o, {'x'});
      return _json(200, {});
    });
    final client = _client(adapter);
    expect(await client.removeMissingFiles(['x']), isTrue);
    expect(adapter.requests.where((r) => r.path == '/auth/login'), hasLength(2));
  });

  test('purgeDeletedSongs waits for the scan, then rescans until flagged',
      () async {
    var listCalls = 0;
    var deleteCalls = 0;
    final nd = _FakeAdapter((o) {
      if (o.path == '/auth/login') return _json(200, {'token': 'tok'});
      if (o.method == 'GET') {
        return missingList(o, listCalls++ < 1 ? {} : {'x'});
      }
      deleteCalls++;
      return _json(200, {});
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

    expect(listCalls, 2);
    expect(deleteCalls, 1);
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
