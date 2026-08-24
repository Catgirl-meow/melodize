import 'package:dio/dio.dart';
import '../models/recommended_track.dart';
import '../utils/title_normalize.dart';

/// Rich result from [DeezerClient.checkAccountStatus].
class DeezerAccountStatus {
  final bool arlValid;
  final String userName;
  final int offerId;

  /// Whether Deezer explicitly reported a paid offer. Null means the
  /// response did not include reliable offer metadata; that is not proof of
  /// an expired subscription when the ARL itself is valid.
  final bool? hasPaidOffer;
  final bool isFreemiumCountry;

  factory DeezerAccountStatus.fromUserJson(Map<String, dynamic> user) {
    final userId = _asInt(user['USER_ID']);
    if (userId == null || userId == 0) return const DeezerAccountStatus();

    // Deezer has changed the shape/types of offer metadata over time. An
    // absent or non-numeric OFFER_ID is unknown, not proof of expiration;
    // the companion's successful download is also a valid capability signal.
    final rawOfferId = _asInt(user['OFFER_ID']);
    // Zero is commonly used for absent/legacy offer metadata. Do not turn a
    // valid ARL into a false subscription-expired warning from that value.
    final hasPaidOffer =
        rawOfferId == null || rawOfferId == 0 ? null : rawOfferId > 0;
    final isFreemiumCountry = _asBool(user['IS_FREEMIUM_COUNTRY']) ?? false;
    final userName = (user['NAME'] as String?)?.trim() ?? '';

    return DeezerAccountStatus(
      arlValid: true,
      userName: userName,
      offerId: rawOfferId ?? 0,
      hasPaidOffer: hasPaidOffer,
      isFreemiumCountry: isFreemiumCountry,
    );
  }

  const DeezerAccountStatus({
    this.arlValid = false,
    this.userName = '',
    this.offerId = 0,
    this.hasPaidOffer,
    this.isFreemiumCountry = false,
  });

  /// Whether the account has an explicitly confirmed plan that can download.
  bool get canDownload =>
      arlValid && (hasPaidOffer == true || isFreemiumCountry);

  /// Whether Deezer returned enough offer metadata to classify the plan.
  bool get subscriptionStatusKnown => hasPaidOffer != null || isFreemiumCountry;

  /// Human-readable subscription tier description.
  String get offerLabel {
    if (!arlValid) return 'Not connected';
    if (hasPaidOffer == true) {
      switch (offerId) {
        case 1:
          return 'Deezer Premium';
        case 2:
          return 'Deezer Premium Family';
        case 4:
          return 'Deezer HiFi';
        case 5:
          return 'Deezer HiFi Family';
        default:
          return 'Deezer Premium';
      }
    }
    if (isFreemiumCountry) return 'Deezer Free (region)';
    if (!subscriptionStatusKnown) return 'Deezer account verified';
    return 'Free / No subscription';
  }
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

bool? _asBool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final normalized = value?.toString().trim().toLowerCase();
  if (normalized == 'true' || normalized == '1') return true;
  if (normalized == 'false' || normalized == '0') return false;
  return null;
}

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
    bool matches(String? name) {
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
        if (id != null && matches(a['name'] as String?)) return id;
      }

      // Pass 2: track search fallback — strict name-match only, no fallback ID.
      final qParts = <String>[
        if (trackTitle != null && trackTitle.isNotEmpty) trackTitle,
        artistName,
      ];
      final q2 = Uri.encodeQueryComponent(qParts.join(' '));
      final r2 = await _dio.get('/search?q=$q2&limit=8');
      for (final t in (r2.data?['data'] as List? ?? [])) {
        final artistObj =
            (t as Map<String, dynamic>)['artist'] as Map<String, dynamic>?;
        final id = artistObj?['id'] as int?;
        if (id != null && matches(artistObj?['name'] as String?)) return id;
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
          .map(
              (t) => RecommendedTrack.fromDeezerJson(t as Map<String, dynamic>))
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
          .map(
              (t) => RecommendedTrack.fromDeezerJson(t as Map<String, dynamic>))
          .where((t) => t.previewUrl != null && t.previewUrl!.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  // Validate an ARL cookie against Deezer's gw-light endpoint.
  //
  // Returns `true` only on a confirmed-valid response (non-zero USER_ID).
  // Returns `false` when Deezer explicitly rejects the ARL (USER_ID == 0).
  // Throws on network errors (timeout, DNS, TLS) so callers can distinguish
  // "can't reach Deezer" from "ARL is expired".
  static Future<bool> validateArl(String arl) async {
    if (arl.isEmpty) return false;
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
    ));
    // Let DioExceptions propagate — callers need to know whether the
    // failure is network (unknown) or Deezer-response (confirmed invalid).
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
    final userId = _asInt(user?['USER_ID']);
    // Anonymous (invalid ARL) responses come back with USER_ID == 0.
    return userId != null && userId != 0;
  }

  /// Rich Deezer account check — returns [DeezerAccountStatus] with
  /// subscription tier and streaming capability info.
  ///
  /// Unlike [validateArl] (which only checks ARL validity), this also
  /// inspects the account's offer/subscription fields so the app can
  /// warn when downloads will fail due to an expired plan.
  static Future<DeezerAccountStatus> checkAccountStatus(String arl) async {
    if (arl.isEmpty) return const DeezerAccountStatus();
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
    if (user == null) return const DeezerAccountStatus();

    return DeezerAccountStatus.fromUserJson(user);
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
          .map(
              (t) => RecommendedTrack.fromDeezerJson(t as Map<String, dynamic>))
          .where((t) => t.previewUrl != null)
          .toList();
    } catch (_) {
      return [];
    }
  }
}
