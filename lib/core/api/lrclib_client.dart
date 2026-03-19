import 'package:dio/dio.dart';
import '../models/lyrics_result.dart';

class LrcLibClient {
  static final LrcLibClient _instance = LrcLibClient._();
  factory LrcLibClient() => _instance;
  LrcLibClient._();

  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://lrclib.net',
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 10),
  ));

  Future<LyricsResult?> getLyrics({
    required String artist,
    required String title,
    required String album,
    required int duration,
  }) async {
    try {
      final resp = await _dio.get('/api/get', queryParameters: {
        'artist_name': artist,
        'track_name': title,
        'album_name': album,
        'duration': duration,
      });
      final data = resp.data as Map<String, dynamic>;
      if (data['instrumental'] == true) {
        return const LyricsResult(plain: '[Instrumental]');
      }
      return LyricsResult(
        plain: data['plainLyrics'] as String?,
        synced: data['syncedLyrics'] as String?,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }
}
