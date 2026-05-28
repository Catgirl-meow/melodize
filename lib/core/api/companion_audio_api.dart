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
}
