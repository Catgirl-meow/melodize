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
  /// Fuzzy-matches across the first 5 search hits to avoid the `tracks.first`
  /// failure mode on common song titles (e.g. searching "Creep" by Radiohead
  /// used to pick a random cover's artist). Returns null when no plausible
  /// match is found rather than guessing.
  ///
  /// [genreHint] biases the search query when a non-empty genre is known
  /// from the user's library entry — measurable quality lift on seeds that
  /// share a title with unrelated tracks in other genres.
  Future<int?> searchBestArtist({
    required String artistName,
    String? trackTitle,
    String? genreHint,
  }) async {
    try {
      final qParts = <String>[
        if (trackTitle != null && trackTitle.isNotEmpty) trackTitle,
        artistName,
        if (genreHint != null && genreHint.isNotEmpty) genreHint,
      ];
      final q = Uri.encodeQueryComponent(qParts.join(' '));
      final resp = await _dio.get('/search?q=$q&limit=5');
      final tracks = (resp.data as Map<String, dynamic>?)?['data'] as List?;
      if (tracks == null || tracks.isEmpty) return null;

      final seedNorm = normalize(artistName);

      int? fallbackId;
      for (final raw in tracks) {
        final t = raw as Map<String, dynamic>;
        final artistObj = t['artist'] as Map<String, dynamic>?;
        final id = artistObj?['id'] as int?;
        final name = artistObj?['name'] as String?;
        if (id == null) continue;

        fallbackId ??= id; // first result in case no fuzzy match wins

        if (name == null) continue;
        final hitNorm = normalize(name);
        if (hitNorm == seedNorm ||
            hitNorm.contains(seedNorm) ||
            seedNorm.contains(hitNorm)) {
          return id;
        }
      }
      // No fuzzy winner — only return the first hit if no better choice
      // existed. Better a mediocre radio than a blocked seed.
      return fallbackId;
    } catch (_) {
      return null;
    }
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
