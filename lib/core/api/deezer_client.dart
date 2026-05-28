import 'package:dio/dio.dart';
import '../models/recommended_track.dart';
import '../utils/title_normalize.dart';

// Free Deezer API wrapper (no API key required).
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

  // Resolve a Deezer artist ID. Two-pass: /search/artist first, then
  // /search fallback with strict fuzzy name-matching only.
  Future<int?> searchBestArtist({
    required String artistName,
    String? trackTitle,
    String? genreHint,
  }) async {
    final seedNorm = normalize(artistName);
    bool _matches(String? name) {
      if (name == null) return false;
      final h = normalize(name);
      return h == seedNorm || h.contains(seedNorm) || seedNorm.contains(h);
    }

    try {
      // Pass 1: artist-name search — no popularity bias.
      final q1 = Uri.encodeQueryComponent(artistName);
      final r1 = await _dio.get('/search/artist?q=$q1&limit=8');
      for (final a in (r1.data?['data'] as List? ?? [])) {
        final id = (a as Map<String, dynamic>)['id'] as int?;
        if (id != null && _matches(a['name'] as String?)) return id;
      }

      // Pass 2: track search fallback — strict name-match only, no fallback ID.
      final qParts = <String>[
        if (trackTitle != null && trackTitle.isNotEmpty) trackTitle,
        artistName,
      ];
      final q2 = Uri.encodeQueryComponent(qParts.join(' '));
      final r2 = await _dio.get('/search?q=$q2&limit=8');
      for (final t in (r2.data?['data'] as List? ?? [])) {
        final artistObj = (t as Map<String, dynamic>)['artist']
            as Map<String, dynamic>?;
        final id = artistObj?['id'] as int?;
        if (id != null && _matches(artistObj?['name'] as String?)) return id;
      }
    } catch (_) {}
    return null;
  }

  // Fetch an artist's radio (curated similar tracks). Only returns tracks
  // with a preview URL.
  Future<List<RecommendedTrack>> artistRadio(
    int artistId, {
    int limit = 10,
  }) async {
    try {
      final resp = await _dio.get('/artist/$artistId/radio?limit=$limit');
      final tracks = (resp.data as Map<String, dynamic>?)?['data'] as List?;
      if (tracks == null) return [];
      return tracks
          .map((t) =>
              RecommendedTrack.fromDeezerJson(t as Map<String, dynamic>))
          .where((t) => t.previewUrl != null)
          .toList();
    } catch (_) {
      return [];
    }
  }

  // Fetch an artist's top tracks. Only returns tracks with a preview URL.
  Future<List<RecommendedTrack>> artistTopTracks(
    int artistId, {
    int limit = 15,
  }) async {
    try {
      final resp = await _dio.get('/artist/$artistId/top?limit=$limit');
      final tracks = (resp.data as Map<String, dynamic>?)?['data'] as List?;
      if (tracks == null) return [];
      return tracks
          .map((t) => RecommendedTrack.fromDeezerJson(t as Map<String, dynamic>))
          .where((t) => t.previewUrl != null && t.previewUrl!.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  // Validate an ARL cookie against Deezer's gw-light endpoint. Returns true
  // only on a confirmed-valid response; errors return false.
  static Future<bool> validateArl(String arl) async {
    if (arl.isEmpty) return false;
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
      ));
      final resp = await dio.post<Map<String, dynamic>>(
        'https://www.deezer.com/ajax/gw-light.php',
        queryParameters: {
          'method': 'deezer.getUserData',
          'api_version': '1.0',
          'api_token': '',
          'input': '3',
        },
        options: Options(
          headers: {'Cookie': 'arl=$arl'},
          responseType: ResponseType.json,
        ),
      );
      final results = resp.data?['results'] as Map<String, dynamic>?;
      final user = results?['USER'] as Map<String, dynamic>?;
      final userId = user?['USER_ID'];
      // Anonymous (invalid ARL) responses come back with USER_ID == 0.
      return userId is int && userId != 0;
    } catch (_) {
      return false;
    }
  }

  // Deezer catalog search.
  Future<List<RecommendedTrack>> search(String query, {int limit = 12}) async {
    if (query.trim().isEmpty) return [];
    try {
      final q = Uri.encodeQueryComponent(query.trim());
      final resp = await _dio.get('/search?q=$q&limit=$limit');
      final data = resp.data as Map<String, dynamic>?;
      final tracks = data?['data'] as List? ?? [];
      return tracks
          .map((t) => RecommendedTrack.fromDeezerJson(t as Map<String, dynamic>))
          .where((t) => t.previewUrl != null)
          .toList();
    } catch (_) {
      return [];
    }
  }
}
