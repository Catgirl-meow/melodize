import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';

/// Client for the melodize-companion sidecar service.
///
/// The companion is a small Python HTTP service that runs on the same host
/// as Navidrome and provides file-management operations that Navidrome's own
/// API intentionally does not expose (delete, upload).
///
/// Auth: every request carries an [X-API-Key] header.
class CompanionClient {
  final String baseUrl;
  final String apiKey;
  late final Dio _dio;

  CompanionClient({required this.baseUrl, required this.apiKey}) {
    final url = baseUrl.replaceAll(RegExp(r'/+$'), '');
    _dio = Dio(BaseOptions(
      baseUrl: url,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'X-API-Key': apiKey},
    ));
    // Accept self-signed / local certificates — companion runs on the user's
    // own server so cert validation adds no security benefit here.
    (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () =>
        HttpClient()..badCertificateCallback = (_, __, ___) => true;
  }

  /// Returns true if the companion is reachable and the API key is valid.
  ///
  /// Does NOT follow redirects — Navidrome returns 302→200 for unknown paths,
  /// which would make a mis-configured URL (e.g. with a /companion suffix)
  /// appear healthy while DELETE/POST would return 405.
  Future<bool> checkHealth() async {
    try {
      final resp = await _dio.get(
        '/health',
        options: Options(
          followRedirects: false,
          validateStatus: (s) => s != null,
        ),
      );
      if (resp.statusCode != 200) return false;
      final data = resp.data;
      return data is Map && data['status'] == 'ok';
    } catch (_) {
      return false;
    }
  }

  /// Permanently delete a song from the server by its Navidrome song ID.
  /// Throws [DioException] on network error or non-2xx response.
  Future<void> deleteSong(String songId) async {
    await _dio.delete('/api/songs/$songId');
  }

  /// Start a background download job on the server.
  /// [deezerArl] is forwarded to yt-dlp for authenticated Deezer FLAC downloads.
  /// Returns the job ID — poll [getDownloadStatus] to track progress.
  Future<String> startDownload(String url, {String? deezerArl}) async {
    final body = <String, dynamic>{'url': url};
    if (deezerArl != null && deezerArl.isNotEmpty) {
      body['deezer_arl'] = deezerArl;
    }
    final resp = await _dio.post('/api/songs/download', data: body);
    return (resp.data as Map<String, dynamic>)['job_id'] as String;
  }

  /// Poll a download job started with [startDownload].
  Future<Map<String, dynamic>> getDownloadStatus(String jobId) async {
    final resp = await _dio.get('/api/songs/download/$jobId');
    return resp.data as Map<String, dynamic>;
  }
}
