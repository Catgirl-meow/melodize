import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';

// Client for the melodize-companion sidecar service.
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
    // Accept self-signed certs; companion runs on the user's own server.
    (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () =>
        HttpClient()..badCertificateCallback = (_, __, ___) => true;
  }

  // Returns true if reachable and the API key is valid.
  // Does NOT follow redirects so mis-configured URLs don't appear healthy.
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

  Future<void> deleteSong(String songId) async {
    await _dio.delete('/api/songs/$songId');
  }

  // Start a server-side download job. Returns the job ID for polling.
  Future<String> startDownload(String url, {String? deezerArl}) async {
    final body = <String, dynamic>{'url': url};
    if (deezerArl != null && deezerArl.isNotEmpty) {
      body['deezer_arl'] = deezerArl;
    }
    final resp = await _dio.post('/api/songs/download', data: body);
    return (resp.data as Map<String, dynamic>)['job_id'] as String;
  }

  Future<Map<String, dynamic>> getDownloadStatus(String jobId) async {
    final resp = await _dio.get('/api/songs/download/$jobId');
    return resp.data as Map<String, dynamic>;
  }
}
