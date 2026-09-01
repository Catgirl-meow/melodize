import 'package:dio/dio.dart';

/// Plain-lyrics fallback for tracks that are missing from LRCLIB.
///
/// lyrics.ovh does not provide synced timestamps, so this client is only used
/// after the synced-capable LRCLIB provider has no usable result.
class LyricsOvhClient {
  static final LyricsOvhClient _instance = LyricsOvhClient._();
  factory LyricsOvhClient() => _instance;
  LyricsOvhClient._();

  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://api.lyrics.ovh',
    connectTimeout: const Duration(seconds: 6),
    receiveTimeout: const Duration(seconds: 8),
  ));

  Future<String?> getLyrics({
    required String artist,
    required String title,
    CancelToken? cancelToken,
  }) async {
    final cleanArtist = artist.trim();
    final cleanTitle = title.trim();
    if (cleanArtist.isEmpty || cleanTitle.isEmpty) return null;

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/v1/${Uri.encodeComponent(cleanArtist)}/${Uri.encodeComponent(cleanTitle)}',
        cancelToken: cancelToken,
      );
      final lyrics = response.data?['lyrics'];
      if (lyrics is! String) return null;
      final value = lyrics.trim();
      return value.isEmpty ? null : value;
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return null;
      rethrow;
    }
  }
}
