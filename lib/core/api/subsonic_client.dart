import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import '../models/song.dart';
import '../models/album.dart';
import '../models/artist.dart';
import '../models/playlist.dart';
import '../models/search_results.dart';

class SubsonicConfig {
  final String serverUrl;
  final String username;
  final String password;

  const SubsonicConfig({
    required this.serverUrl,
    required this.username,
    required this.password,
  });
}

class SubsonicClient {
  final SubsonicConfig config;
  late final Dio _dio;
  late final String _baseUrl;

  static const _clientName = 'melodize';
  static const _apiVersion = '1.16.1';

  SubsonicClient(this.config) {
    _baseUrl = config.serverUrl.replaceAll(RegExp(r'/+$'), '');
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
    ));
  }

  // --- Auth ---
  Map<String, String> _authParams() {
    final salt = DateTime.now().millisecondsSinceEpoch.toString();
    final token = md5.convert(utf8.encode(config.password + salt)).toString();
    return {
      'u': config.username,
      't': token,
      's': salt,
      'v': _apiVersion,
      'c': _clientName,
      'f': 'json',
    };
  }

  // Stable auth params with fixed salt — used for cover art URLs so
  // CachedNetworkImage disk cache keys are deterministic across app sessions.
  Map<String, String> _stableAuthParams() {
    const salt = 'melodize';
    final token = md5.convert(utf8.encode(config.password + salt)).toString();
    return {
      'u': config.username,
      't': token,
      's': salt,
      'v': _apiVersion,
      'c': _clientName,
      'f': 'json',
    };
  }

  Future<Map<String, dynamic>> _get(
    String endpoint, [
    Map<String, dynamic>? params,
  ]) async {
    final queryParams = <String, dynamic>{
      ..._authParams(),
      ...?params,
    };
    final response = await _dio.get(
      '/rest/$endpoint',
      queryParameters: queryParams,
    );
    final data = response.data is String
        ? jsonDecode(response.data as String)
        : response.data;
    final subsonic = data['subsonic-response'] as Map<String, dynamic>;
    if (subsonic['status'] != 'ok') {
      throw Exception(
          'Subsonic error: ${subsonic['error']?['message'] ?? 'Unknown'}');
    }
    return subsonic;
  }

  // --- Songs ---
  Future<List<Song>> getAllSongs() async {
    final List<Song> allSongs = [];
    int offset = 0;
    const size = 500;
    while (true) {
      final resp = await _get('search3', {
        'query': '',
        'songCount': size,
        'songOffset': offset,
        'albumCount': 0,
        'artistCount': 0,
      });
      final songs = (resp['searchResult3']?['song'] as List? ?? [])
          .map((s) => Song.fromSubsonicJson(s as Map<String, dynamic>))
          .toList();
      allSongs.addAll(songs);
      if (songs.length < size) break;
      offset += size;
    }
    return allSongs;
  }

  Future<List<Song>> getRandomSongs({int count = 20}) async {
    final resp = await _get('getRandomSongs', {'size': count});
    final songs = resp['randomSongs']?['song'] as List? ?? [];
    return songs
        .map((s) => Song.fromSubsonicJson(s as Map<String, dynamic>))
        .toList();
  }

  Future<List<Song>> getAlbumSongs(String albumId) async {
    final resp = await _get('getAlbum', {'id': albumId});
    final songs = resp['album']?['song'] as List? ?? [];
    return songs
        .map((s) => Song.fromSubsonicJson(s as Map<String, dynamic>))
        .toList();
  }

  Future<List<Song>> getPlaylistSongs(String playlistId) async {
    final resp = await _get('getPlaylist', {'id': playlistId});
    final songs = resp['playlist']?['entry'] as List? ?? [];
    return songs
        .map((s) => Song.fromSubsonicJson(s as Map<String, dynamic>))
        .toList();
  }

  Future<List<Song>> getSimilarSongs(String songId, {int count = 20}) async {
    try {
      final resp = await _get('getSimilarSongs', {'id': songId, 'count': count});
      final songs = resp['similarSongs']?['song'] as List? ?? [];
      return songs
          .map((s) => Song.fromSubsonicJson(s as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // --- Albums ---
  Future<List<Album>> getAlbums({
    String type = 'alphabeticalByName',
    int size = 100,
    int offset = 0,
  }) async {
    final resp = await _get('getAlbumList2', {
      'type': type,
      'size': size,
      'offset': offset,
    });
    final albums = resp['albumList2']?['album'] as List? ?? [];
    return albums
        .map((a) => Album.fromSubsonicJson(a as Map<String, dynamic>))
        .toList();
  }

  Future<List<Album>> getNewestAlbums({int size = 20}) =>
      getAlbums(type: 'newest', size: size);

  Future<List<Album>> getRecentAlbums({int size = 20}) =>
      getAlbums(type: 'recent', size: size);

  Future<List<Album>> getArtistAlbums(String artistId) async {
    final resp = await _get('getArtist', {'id': artistId});
    final albums = resp['artist']?['album'] as List? ?? [];
    return albums
        .map((a) => Album.fromSubsonicJson(a as Map<String, dynamic>))
        .toList();
  }

  // --- Artists ---
  Future<List<Artist>> getArtists() async {
    final resp = await _get('getArtists');
    final indices = resp['artists']?['index'] as List? ?? [];
    final artists = <Artist>[];
    for (final index in indices) {
      final artistList = index['artist'] as List? ?? [];
      artists.addAll(artistList.map(
          (a) => Artist.fromSubsonicJson(a as Map<String, dynamic>)));
    }
    return artists;
  }

  // --- Playlists ---
  Future<List<Playlist>> getPlaylists() async {
    final resp = await _get('getPlaylists');
    final playlists = resp['playlists']?['playlist'] as List? ?? [];
    return playlists
        .map((p) => Playlist.fromSubsonicJson(p as Map<String, dynamic>))
        .toList();
  }

  // --- Search ---
  Future<SearchResults> search(String query, {int songCount = 30}) async {
    final resp = await _get('search3', {
      'query': query,
      'songCount': songCount,
      'albumCount': 10,
      'artistCount': 5,
    });
    final result = resp['searchResult3'] as Map<String, dynamic>? ?? {};
    return SearchResults(
      songs: (result['song'] as List? ?? [])
          .map((s) => Song.fromSubsonicJson(s as Map<String, dynamic>))
          .toList(),
      albums: (result['album'] as List? ?? [])
          .map((a) => Album.fromSubsonicJson(a as Map<String, dynamic>))
          .toList(),
      artists: (result['artist'] as List? ?? [])
          .map((a) => Artist.fromSubsonicJson(a as Map<String, dynamic>))
          .toList(),
    );
  }

  // --- URLs ---
  // quality: 'lossless' → format=raw, '320'/'192'/'128' → maxBitRate=X
  String streamUrl(String songId, {String quality = 'lossless'}) {
    final params = <String, String>{..._authParams(), 'id': songId};
    if (quality == 'lossless') {
      params['format'] = 'raw';
    } else {
      params['maxBitRate'] = quality;
    }
    return '$_baseUrl/rest/stream?${_encodeParams(params)}';
  }

  String downloadUrl(String songId) {
    final params = {..._authParams(), 'id': songId};
    return '$_baseUrl/rest/download?${_encodeParams(params)}';
  }

  // size=0 → Navidrome returns the original embedded image at full resolution.
  // Use 0 for high-quality contexts (now-playing, album grids); list tiles can
  // pass a smaller value if needed, but 0 is fine everywhere given image caching.
  String coverArtUrl(String coverArtId, {int size = 0}) {
    final params = <String, String>{
      ..._stableAuthParams(),
      'id': coverArtId,
    };
    if (size > 0) params['size'] = size.toString();
    return '$_baseUrl/rest/getCoverArt?${_encodeParams(params)}';
  }

  String _encodeParams(Map<String, String> params) => params.entries
      .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
      .join('&');

  // --- Downloads ---
  // quality: 'lossless' → /rest/download (original file),
  //          '320'/'192'/'128' → /rest/stream with maxBitRate (transcoded)
  Future<void> downloadSong(
    Song song,
    String savePath, {
    String quality = 'lossless',
    void Function(int received, int total)? onProgress,
  }) async {
    final endpoint =
        quality == 'lossless' ? '/rest/download' : '/rest/stream';
    final params = <String, dynamic>{..._authParams(), 'id': song.id};
    if (quality != 'lossless') params['maxBitRate'] = quality;
    await _dio.download(
      endpoint,
      savePath,
      queryParameters: params,
      onReceiveProgress: onProgress,
    );
  }

  // --- Scrobble ---
  Future<void> scrobble(String songId, {bool submission = true}) async {
    try {
      await _dio.get(
        '/rest/scrobble',
        queryParameters: {
          ..._authParams(),
          'id': songId,
          'submission': submission.toString(),
        },
        options: Options(receiveTimeout: const Duration(seconds: 5)),
      );
    } catch (_) {
      // Scrobble failures are non-fatal
    }
  }

  // --- Library scan ---
  Future<void> startScan() async {
    try {
      await _get('startScan');
    } catch (_) {
      // Non-fatal — Navidrome will do a scheduled scan anyway
    }
  }

  // --- Ping ---
  Future<bool> ping() async {
    try {
      await _get('ping');
      return true;
    } catch (_) {
      return false;
    }
  }
}
