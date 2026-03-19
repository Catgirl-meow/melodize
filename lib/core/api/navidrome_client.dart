import 'package:dio/dio.dart';

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
  }

  /// Returns true if the companion is reachable and the API key is valid.
  Future<bool> checkHealth() async {
    try {
      final resp = await _dio.get('/health');
      return resp.statusCode == 200;
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
  /// Returns the job ID — poll [getDownloadStatus] to track progress.
  Future<String> startDownload(String url) async {
    final resp = await _dio.post('/api/songs/download', data: {'url': url});
    return (resp.data as Map<String, dynamic>)['job_id'] as String;
  }

  /// Poll a download job started with [startDownload].
  Future<Map<String, dynamic>> getDownloadStatus(String jobId) async {
    final resp = await _dio.get('/api/songs/download/$jobId');
    return resp.data as Map<String, dynamic>;
  }
}
