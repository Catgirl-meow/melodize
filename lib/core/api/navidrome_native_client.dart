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

  // Removes the given songs from Navidrome's missing-files list.
  //
  // Returns false when none of them is flagged missing yet (the rescan has not
  // reached them). Never call this with an empty list: Navidrome treats that
  // as "remove every missing file".
  Future<bool> removeMissingFiles(List<String> songIds) async {
    if (songIds.isEmpty) return true;
    final query = songIds
        .map((id) => 'id=${Uri.encodeQueryComponent(id)}')
        .join('&');
    Future<Response> send(String token) => _dio.delete(
          '/api/missing?$query',
          options: Options(
            headers: {_authHeader: 'Bearer $token'},
            validateStatus: (s) => s != null && s < 500,
          ),
        );

    var resp = await send(_token ?? await _login());
    if (resp.statusCode == 401) resp = await send(await _login());
    switch (resp.statusCode) {
      case 200:
        return true;
      case 404:
        return false;
      case 403:
        throw Exception('Removing missing files needs a Navidrome admin user');
      default:
        throw Exception('Navidrome returned HTTP ${resp.statusCode}');
    }
  }

  // Removes every file Navidrome currently flags as missing, as the web UI's
  // "Remove all" does. Returns how many were removed.
  Future<int> removeAllMissingFiles() async {
    Future<Response> get(String token) => _dio.get(
          '/api/missing',
          queryParameters: {'_start': 0, '_end': 1},
          options: Options(
            headers: {_authHeader: 'Bearer $token'},
            validateStatus: (s) => s != null && s < 500,
          ),
        );
    var resp = await get(_token ?? await _login());
    if (resp.statusCode == 401) resp = await get(await _login());
    if (resp.statusCode == 403) {
      throw Exception('Removing missing files needs a Navidrome admin user');
    }
    final count =
        int.tryParse(resp.headers.value('x-total-count') ?? '') ?? 0;
    if (count == 0) return 0;

    final del = await _dio.delete(
      '/api/missing',
      options: Options(headers: {_authHeader: 'Bearer $_token'}),
    );
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
