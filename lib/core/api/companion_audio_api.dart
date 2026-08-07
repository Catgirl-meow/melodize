import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';

class CompanionAudioApi {
  final String baseUrl;
  final String apiKey;
  late final Dio _dio;

  CompanionAudioApi({required this.baseUrl, required this.apiKey}) {
    final url = baseUrl.replaceAll(RegExp(r'/+$'), '');
    _resolvedBaseUrl = url;
    _dio = Dio(BaseOptions(
      baseUrl: url,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 60), // longer for analysis
      headers: {'X-API-Key': apiKey},
    ));
    (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () =>
        HttpClient()..badCertificateCallback = (_, __, ___) => true;
  }

  late final String _resolvedBaseUrl;

  String get serverUrl => _resolvedBaseUrl;

  /// Resolve a companion API path returned by a job into an absolute URL.
  /// The companion may return either a relative path or an absolute URL.
  String resolveUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    return '$_resolvedBaseUrl${path.startsWith('/') ? path : '/$path'}';
  }

  /// Headers required when just_audio fetches a rendered transition directly.
  Map<String, String> get requestHeaders => {'X-API-Key': apiKey};

  // Batch analysis

  Future<Map<String, dynamic>?> startAnalysis({List<String>? songIds}) async {
    try {
      final body = <String, dynamic>{};
      if (songIds != null && songIds.isNotEmpty) {
        body['song_ids'] = songIds;
      }
      final resp = await _dio.post('/api/audio/analyze-batch', data: body);
      return resp.data as Map<String, dynamic>?;
    } on DioException {
      return null;
    }
  }

  Future<Map<String, dynamic>?> pollAnalysis(String jobId) async {
    try {
      final resp = await _dio.get('/api/audio/analyze-batch/$jobId');
      return resp.data as Map<String, dynamic>?;
    } on DioException {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getAllResults() async {
    try {
      final resp = await _dio.get('/api/audio/analysis');
      final data = resp.data as Map<String, dynamic>?;
      return (data?['results'] as List<dynamic>?)
              ?.cast<Map<String, dynamic>>() ??
          [];
    } on DioException {
      return [];
    }
  }

  Future<Map<String, dynamic>?> getAnalysis(String songId) async {
    try {
      final resp = await _dio.get('/api/audio/analysis/$songId');
      return resp.data as Map<String, dynamic>?;
    } on DioException {
      return null;
    }
  }

  // Transition mixing

  Future<Map<String, dynamic>?> requestTransition({
    required String songAId,
    required String songBId,
    double mixDuration = 10,
  }) async {
    try {
      final resp = await _dio.post('/api/audio/mix-transition', data: {
        'song_a_id': songAId,
        'song_b_id': songBId,
        'mix_duration': mixDuration,
      });
      return resp.data as Map<String, dynamic>?;
    } on DioException {
      return null;
    }
  }

  Future<Map<String, dynamic>?> pollTransition(String jobId) async {
    try {
      final resp = await _dio.get('/api/audio/mix-transition/$jobId');
      return resp.data as Map<String, dynamic>?;
    } on DioException {
      return null;
    }
  }

  /// Download a rendered transition using the same authenticated Dio client
  /// as the API calls. This is important for self-signed companion HTTPS,
  /// which native audio backends do not inherit from Dio.
  Future<List<int>?> downloadTransition(String path) async {
    try {
      final resp = await _dio.get<List<int>>(
        resolveUrl(path),
        options: Options(
          responseType: ResponseType.bytes,
          validateStatus: (status) => status != null && status >= 200 && status < 300,
        ),
      );
      final data = resp.data;
      return data == null ? null : List<int>.unmodifiable(data);
    } on DioException {
      return null;
    }
  }
}
