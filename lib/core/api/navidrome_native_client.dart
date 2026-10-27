import 'package:dio/dio.dart';

import 'subsonic_client.dart';

// Client for Navidrome's own REST API (the one its web UI uses), which can do
// things the Subsonic API cannot.
//
// Navidrome 0.55+ never drops a deleted file from its database: a rescan only
// flags it as "missing" (so playlists, stars and play counts survive a file
// that comes back). Melodize deletes are permanent, so after the rescan has
// flagged the song we purge it here, the same as the web UI's
// "Missing files → Remove" action.
class NavidromeNativeClient {
  final SubsonicConfig config;
  late final Dio _dio;
  String? _token;

  static const _authHeader = 'X-ND-Authorization';

  NavidromeNativeClient(this.config, {Dio? dio}) {
    _dio = dio ??
        Dio(BaseOptions(
          baseUrl: config.serverUrl.replaceAll(RegExp(r'/+$'), ''),
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 30),
        ));
  }

  Future<String> _login() async {
    final resp = await _dio.post('/auth/login', data: {
      'username': config.username,
      'password': config.password,
    });
    final token = (resp.data as Map)['token'] as String?;
    if (token == null || token.isEmpty) {
      throw Exception('Navidrome login returned no token');
    }
    return _token = token;
  }

  // Sends a request with the session token, logging in again once if the
  // token has expired.
  Future<Response> _authed(Future<Response> Function(Options) send) async {
    Options opts(String token) => Options(
          headers: {_authHeader: 'Bearer $token'},
          validateStatus: (s) => s != null && s < 500,
        );
    var resp = await send(opts(_token ?? await _login()));
    if (resp.statusCode == 401) resp = await send(opts(await _login()));
    if (resp.statusCode == 403) {
      throw Exception('Removing missing files needs a Navidrome admin user');
    }
    return resp;
  }

  // Removes the given songs from Navidrome's missing-files list.
  //
  // Returns false when none of them is flagged missing yet (the rescan has not
  // reached them). Navidrome answers a delete of unknown ids with 200, so the
  // list is checked first, and only ids it holds are sent: a delete with no
  // ids means "remove every missing file".
  Future<bool> removeMissingFiles(List<String> songIds) async {
    if (songIds.isEmpty) return true;
    String idQuery(Iterable<String> ids) =>
        ids.map((id) => 'id=${Uri.encodeQueryComponent(id)}').join('&');

    final list = await _authed(
        (o) => _dio.get('/api/missing?${idQuery(songIds)}', options: o));
    if (list.statusCode != 200) {
      throw Exception('Navidrome returned HTTP ${list.statusCode}');
    }
    final wanted = songIds.toSet();
    final flagged = [
      for (final row in (list.data as List? ?? const []))
        if (row is Map && wanted.contains(row['id'])) row['id'] as String,
    ];
    if (flagged.isEmpty) return false;

    final del = await _authed(
        (o) => _dio.delete('/api/missing?${idQuery(flagged)}', options: o));
    if (del.statusCode != 200) {
      throw Exception('Navidrome returned HTTP ${del.statusCode}');
    }
    return flagged.length == wanted.length;
  }

  // Removes every file Navidrome currently flags as missing, as the web UI's
  // "Remove all" does. Returns how many were removed.
  Future<int> removeAllMissingFiles() async {
    final resp = await _authed((o) => _dio.get(
          '/api/missing',
          queryParameters: {'_start': 0, '_end': 1},
          options: o,
        ));
    final count =
        int.tryParse(resp.headers.value('x-total-count') ?? '') ?? 0;
    if (count == 0) return 0;

    final del = await _authed((o) => _dio.delete('/api/missing', options: o));
    if (del.statusCode != 200) {
      throw Exception('Navidrome returned HTTP ${del.statusCode}');
    }
    return count;
  }
}

// Waits for the rescan that follows a delete to flag [songIds] as missing,
// then purges them. Retries a few times because Navidrome may still be busy
// with an earlier scan when the delete happens. Never throws.
Future<void> purgeDeletedSongs({
  required SubsonicClient subsonic,
  required NavidromeNativeClient native,
  required List<String> songIds,
  Duration pollInterval = const Duration(seconds: 2),
  int attempts = 4,
}) async {
  if (songIds.isEmpty) return;
  try {
    for (var attempt = 0; attempt < attempts; attempt++) {
      await Future.delayed(pollInterval);
      // Wait out the scan (at most ~2 minutes per attempt).
      for (var i = 0; i < 60 && await subsonic.isScanning(); i++) {
        await Future.delayed(pollInterval);
      }
      if (await native.removeMissingFiles(songIds)) return;
      // Not flagged yet: the scan that ran may have started before the file
      // was gone. Ask for another one.
      await subsonic.startScan();
    }
  } catch (_) {
    // Non-fatal: the song is still gone from disk; only Navidrome's
    // missing-files list keeps a ghost entry.
  }
}
