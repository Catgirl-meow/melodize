import 'dart:convert';
import 'dart:io';

import '../models/playlist.dart';
import '../utils/platform_dirs.dart';

/// The last playlists (and their song order) seen from the server, so they
/// can be listed and played while the device is offline.
///
/// One JSON file next to the preferences. Songs are stored as ids and
/// resolved from the cached library, which already holds every song.
/// Entries belong to one server and user; another account's cache is
/// ignored.
class PlaylistCache {
  final Future<Directory> Function() _dir;
  PlaylistCache({Future<Directory> Function()? directory})
      : _dir = directory ?? getAppStorageDirectory;

  Future<File> get _file async =>
      File('${(await _dir()).path}/melodize_playlists.json');

  Future<Map<String, dynamic>?> _read(String account) async {
    final f = await _file;
    if (!await f.exists()) return null;
    final data = jsonDecode(await f.readAsString());
    if (data is! Map<String, dynamic> || data['account'] != account) {
      return null;
    }
    return data;
  }

  Future<void> _write(Map<String, dynamic> data) async {
    final f = await _file;
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode(data), flush: true);
    await tmp.rename(f.path);
  }

  /// Null when nothing was cached for [account] yet.
  Future<List<Playlist>?> playlists(String account) async {
    final data = await _read(account);
    final list = data?['playlists'];
    if (list is! List) return null;
    return [
      for (final p in list) Playlist.fromSubsonicJson(p as Map<String, dynamic>)
    ];
  }

  /// Null when this playlist's songs were never cached.
  Future<List<String>?> songIds(String account, String playlistId) async {
    final data = await _read(account);
    final songs = data?['songs'];
    if (songs is! Map) return null;
    final ids = songs[playlistId];
    return ids is List ? ids.map((e) => e.toString()).toList() : null;
  }

  Future<void> savePlaylists(String account, List<Playlist> playlists) async {
    final data = await _read(account) ?? {'account': account};
    final live = playlists.map((p) => p.id).toSet();
    final songs = Map<String, dynamic>.from(data['songs'] as Map? ?? {})
      ..removeWhere((id, _) => !live.contains(id));
    await _write({
      ...data,
      'playlists': [for (final p in playlists) p.toJson()],
      'songs': songs,
    });
  }

  Future<void> saveSongIds(
      String account, String playlistId, List<String> ids) async {
    final data = await _read(account) ?? {'account': account};
    final songs = Map<String, dynamic>.from(data['songs'] as Map? ?? {});
    songs[playlistId] = ids;
    await _write({...data, 'songs': songs});
  }
}

/// Cache key for a server account.
String playlistCacheAccount(String serverUrl, String username) =>
    '${serverUrl.replaceAll(RegExp(r'/+$'), '')}|$username';
