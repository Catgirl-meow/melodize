import 'package:dio/dio.dart';
import '../models/recommended_track.dart';
import '../utils/title_normalize.dart';

/// Free Deezer API wrapper — no API key required.
///
/// Recommendations pipeline (in [recommendationsProvider]):
///   1. [searchBestArtist] → fuzzy-match the seed artist to a Deezer artist ID.
///   2. [artistRadio] → fetch that artist's radio, a curated mix of similar
///      tracks (30-second MP3 previews served from Deezer's CDN).
///
/// The two methods are exposed separately so the provider can parallelise
/// the whole seed fan-out via `Future.wait`. The old combined method did
/// one sequential round-trip per seed, turning a handful of seeds into a
/// multi-second wait.
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

  /// Resolve a Deezer artist ID for a given seed.
  ///
  /// Strategy (two-pass):
  ///   1. Query /search/artist — Deezer's dedicated artist-name search.
  ///      Results are ranked by name relevance, not track popularity, so
  ///      this reliably surfaces the right artist for niche/non-mainstream acts.
  ///   2. Fall back to /search (track search) only if pass 1 returns nothing.
  ///      Accept a result ONLY when the artist name fuzzy-matches; never use
  ///      a popularity-ranked "first result" as that was the root cause of
  ///      unrelated pop recommendations.
  ///
  /// Returns null when no confident match is found — the caller should skip
  /// this seed rather than guessing a random popular artist.
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

  /// Fetch an artist's Deezer radio — a curated list of similar-sounding
  /// tracks. Only returns entries that carry a non-null preview URL (the
  /// whole point of using these as recommendations is that they are
  /// immediately playable in-app).
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

  /// Fetch an artist's actual top tracks from Deezer (distinct from the radio,
  /// which is a curated mix of *similar* artists). Used on the artist detail
  /// page so the user can preview tracks they don't own yet.
  ///
  /// Only returns entries with a preview URL (no preview = not playable in-app).
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

  /// Validate an ARL cookie by calling Deezer's gw-light endpoint with it
  /// and checking whether the returned user object has a non-zero USER_ID.
  ///
  /// This is the same check deemix runs internally — matches server-side
  /// truth without needing a companion round-trip.
  ///
  /// Returns `true` only on a confirmed-valid response. Network errors,
  /// rate-limit hiccups, or malformed responses return `false` to keep the
  /// UI caller simple — we'd rather show "invalid" once and let the user
  /// retry than show "valid" on a transient glitch.
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

  /// Direct Deezer catalog search — used by the search tab.
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
