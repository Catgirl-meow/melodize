import 'package:dio/dio.dart';
import '../models/recommended_track.dart';

/// Free Deezer API wrapper — no API key required.
///
/// Flow for recommendations:
///   1. Search by title + artist to resolve a Deezer artist ID.
///   2. Fetch that artist's radio (a curated mix of similar tracks).
///
/// Preview URLs are 30-second MP3 clips served from Deezer's CDN.
class DeezerClient {
  static const _base = 'https://api.deezer.com';
  late final Dio _dio;

  DeezerClient() {
    _dio = Dio(BaseOptions(
      baseUrl: _base,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));
  }

  /// Returns up to [limit] recommended tracks based on [artistName] / [trackTitle].
  /// Returns [] silently on any network or parse error.
  Future<List<RecommendedTrack>> getRecommendations(
    String artistName,
    String trackTitle, {
    int limit = 25,
  }) async {
    try {
      // Step 1: resolve artist ID via search
      final q = Uri.encodeQueryComponent('$trackTitle $artistName');
      final searchResp = await _dio.get('/search?q=$q&limit=5');
      final searchData = searchResp.data as Map<String, dynamic>?;
      final tracks = searchData?['data'] as List?;
      if (tracks == null || tracks.isEmpty) return [];

      final firstTrack = tracks.first as Map<String, dynamic>;
      final artistObj = firstTrack['artist'] as Map<String, dynamic>?;
      final artistId = artistObj?['id'] as int?;
      if (artistId == null) return [];

      // Step 2: fetch artist radio — a curated list of similar-sounding tracks
      final radioResp =
          await _dio.get('/artist/$artistId/radio?limit=$limit');
      final radioData = radioResp.data as Map<String, dynamic>?;
      final radioTracks = radioData?['data'] as List?;
      if (radioTracks == null) return [];

      return radioTracks
          .map((t) => RecommendedTrack.fromDeezerJson(
              t as Map<String, dynamic>))
          .where((t) => t.previewUrl != null)
          .toList();
    } catch (_) {
      return [];
    }
  }
}
