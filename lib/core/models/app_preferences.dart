import 'dart:convert';
import 'dart:io';
import '../utils/platform_dirs.dart';
import '../utils/platform_info.dart';

class AppPreferences {
  final String streamQuality; // 'lossless' | '320' | '192' | '128'
  final String autoDownload; // 'never' | 'on_play' | 'all'
  final String downloadQuality; // 'lossless' | '320' | '192' | '128'
  final String
      companionUrl; // e.g. 'http://192.0.2.1:8765'  (empty = disabled)
  final String companionApiKey; // X-API-Key value
  final String
      deezerArl; // Deezer ARL cookie — enables FLAC downloads via companion
  final String
      librarySongSort; // 'name' | 'artist' | 'recentlyAdded' | 'downloaded'
  final bool librarySongAscending;
  final String libraryAlbumSort; // 'name' | 'artist' | 'year' | 'songCount'
  final bool libraryAlbumAscending;
  final String libraryArtistSort; // 'name' | 'albumCount'
  final bool libraryArtistAscending;
  final bool
      floatingNavBar; // true = floating pill dock, false = classic nav bar
  final String themeMode; // 'dark' | 'light' | 'system'
  final String shuffleMode; // 'off' | 'shuffle' | 'smartShuffle'

  const AppPreferences({
    this.streamQuality = 'lossless',
    this.autoDownload = 'never',
    this.downloadQuality = 'lossless',
    this.companionUrl = '',
    this.companionApiKey = '',
    this.deezerArl = '',
    this.librarySongSort = 'name',
    this.librarySongAscending = true,
    this.libraryAlbumSort = 'name',
    this.libraryAlbumAscending = true,
    this.libraryArtistSort = 'name',
    this.libraryArtistAscending = true,
    this.floatingNavBar = true,
    this.themeMode = 'dark',
    this.shuffleMode = 'off',
  });

  bool get hasCompanion =>
      companionUrl.isNotEmpty && companionApiKey.isNotEmpty;
  bool get hasDeezerArl => deezerArl.isNotEmpty;

  AppPreferences copyWith({
    String? streamQuality,
    String? autoDownload,
    String? downloadQuality,
    String? companionUrl,
    String? companionApiKey,
    String? deezerArl,
    String? librarySongSort,
    bool? librarySongAscending,
    String? libraryAlbumSort,
    bool? libraryAlbumAscending,
    String? libraryArtistSort,
    bool? libraryArtistAscending,
    bool? floatingNavBar,
    String? themeMode,
    String? shuffleMode,
  }) =>
      AppPreferences(
        streamQuality: streamQuality ?? this.streamQuality,
        autoDownload: autoDownload ?? this.autoDownload,
        downloadQuality: downloadQuality ?? this.downloadQuality,
        companionUrl: companionUrl ?? this.companionUrl,
        companionApiKey: companionApiKey ?? this.companionApiKey,
        deezerArl: deezerArl ?? this.deezerArl,
        librarySongSort: librarySongSort ?? this.librarySongSort,
        librarySongAscending: librarySongAscending ?? this.librarySongAscending,
        libraryAlbumSort: libraryAlbumSort ?? this.libraryAlbumSort,
        libraryAlbumAscending:
            libraryAlbumAscending ?? this.libraryAlbumAscending,
        libraryArtistSort: libraryArtistSort ?? this.libraryArtistSort,
        libraryArtistAscending:
            libraryArtistAscending ?? this.libraryArtistAscending,
        floatingNavBar: floatingNavBar ?? this.floatingNavBar,
        themeMode: themeMode ?? this.themeMode,
        shuffleMode: shuffleMode ?? this.shuffleMode,
      );

  // Tolerant field readers: one field with an unexpected type must not make
  // fromJson throw, because load() would then reset every setting.
  static String _str(Object? v, String fallback) => v is String ? v : fallback;
  static bool _bool(Object? v, bool fallback) => v is bool ? v : fallback;

  factory AppPreferences.fromJson(Map<String, dynamic> j) => AppPreferences(
        streamQuality: _str(j['streamQuality'], 'lossless'),
        autoDownload: _str(j['autoDownload'], 'never'),
        downloadQuality: _str(j['downloadQuality'], 'lossless'),
        companionUrl: _str(j['companionUrl'], ''),
        companionApiKey: _str(j['companionApiKey'], ''),
        deezerArl: _str(j['deezerArl'], ''),
        librarySongSort: _str(j['librarySongSort'], 'name'),
        librarySongAscending: _bool(j['librarySongAscending'], true),
        libraryAlbumSort: _str(j['libraryAlbumSort'], 'name'),
        libraryAlbumAscending: _bool(j['libraryAlbumAscending'], true),
        libraryArtistSort: _str(j['libraryArtistSort'], 'name'),
        libraryArtistAscending: _bool(j['libraryArtistAscending'], true),
        floatingNavBar: _bool(j['floatingNavBar'], true),
        themeMode: _str(j['themeMode'], 'dark'),
        shuffleMode: _str(j['shuffleMode'], 'off'),
      );

  Map<String, dynamic> toJson() => {
        'streamQuality': streamQuality,
        'autoDownload': autoDownload,
        'downloadQuality': downloadQuality,
        'companionUrl': companionUrl,
        'companionApiKey': companionApiKey,
        'deezerArl': deezerArl,
        'librarySongSort': librarySongSort,
        'librarySongAscending': librarySongAscending,
        'libraryAlbumSort': libraryAlbumSort,
        'libraryAlbumAscending': libraryAlbumAscending,
        'libraryArtistSort': libraryArtistSort,
        'libraryArtistAscending': libraryArtistAscending,
        'floatingNavBar': floatingNavBar,
        'themeMode': themeMode,
        'shuffleMode': shuffleMode,
      };

  static Future<File> get _file async {
    final dir = await getAppStorageDirectory();
    return File('${dir.path}/melodize_prefs.json');
  }

  static Future<AppPreferences> load() async {
    try {
      final f = await _file;
      if (await f.exists()) {
        return AppPreferences.fromJson(
            jsonDecode(await f.readAsString()) as Map<String, dynamic>);
      }
    } catch (_) {}
    return const AppPreferences();
  }

  // Written to a temp file and renamed so a crash mid-write can't leave a
  // truncated file (load() would then silently reset every setting, including
  // the companion API key). The file holds secrets, so on desktop it is made
  // readable by the owner only.
  Future<void> save() async {
    try {
      final f = await _file;
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(jsonEncode(toJson()), flush: true);
      if (isDesktopPlatform && !Platform.isWindows) {
        await Process.run('chmod', ['600', tmp.path]);
      }
      await tmp.rename(f.path);
    } catch (_) {}
  }
}
