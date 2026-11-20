import 'dart:convert';
import 'dart:io';
import '../errors/app_errors.dart';
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
  /// Library chip shown when the tab opens: 'all' | 'playlists' | 'albums'
  /// | 'artists' | 'songs'.
  final String libraryView;
  final String libraryPlaylistSort; // 'updated' | 'name' | 'songCount'
  final bool libraryAlbumsGrid; // false = list
  final bool libraryPlaylistsGrid; // false = list
  final bool
      floatingNavBar; // true = floating pill dock, false = classic nav bar
  final String themeMode; // 'dark' | 'light' | 'system'
  final String shuffleMode; // 'off' | 'shuffle' | 'smartShuffle'
  final bool downloadLikedOffline; // liking a song also saves it on device
  /// Recommendations: boost for artists never played, 0 (familiar) – 2
  /// (adventurous). See TasteWeights.discovery.
  final double recDiscovery;

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
    this.libraryView = 'all',
    this.libraryPlaylistSort = 'updated',
    this.libraryAlbumsGrid = true,
    this.libraryPlaylistsGrid = false,
    this.floatingNavBar = true,
    this.themeMode = 'dark',
    this.shuffleMode = 'off',
    this.downloadLikedOffline = false,
    this.recDiscovery = 0.5,
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
    String? libraryView,
    String? libraryPlaylistSort,
    bool? libraryAlbumsGrid,
    bool? libraryPlaylistsGrid,
    bool? floatingNavBar,
    String? themeMode,
    String? shuffleMode,
    bool? downloadLikedOffline,
    double? recDiscovery,
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
        libraryView: libraryView ?? this.libraryView,
        libraryPlaylistSort: libraryPlaylistSort ?? this.libraryPlaylistSort,
        libraryAlbumsGrid: libraryAlbumsGrid ?? this.libraryAlbumsGrid,
        libraryPlaylistsGrid: libraryPlaylistsGrid ?? this.libraryPlaylistsGrid,
        floatingNavBar: floatingNavBar ?? this.floatingNavBar,
        themeMode: themeMode ?? this.themeMode,
        shuffleMode: shuffleMode ?? this.shuffleMode,
        downloadLikedOffline: downloadLikedOffline ?? this.downloadLikedOffline,
        recDiscovery: recDiscovery ?? this.recDiscovery,
      );

  // Tolerant field readers: one field with an unexpected type must not make
  // fromJson throw, because load() would then reset every setting.
  static String _str(Object? v, String fallback) => v is String ? v : fallback;
  static bool _bool(Object? v, bool fallback) => v is bool ? v : fallback;
  static double _discovery(Object? v) =>
      v is num && v.isFinite && v >= 0 && v <= 2 ? v.toDouble() : 0.5;

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
        libraryView: _str(j['libraryView'], 'all'),
        libraryPlaylistSort: _str(j['libraryPlaylistSort'], 'updated'),
        libraryAlbumsGrid: _bool(j['libraryAlbumsGrid'], true),
        libraryPlaylistsGrid: _bool(j['libraryPlaylistsGrid'], false),
        floatingNavBar: _bool(j['floatingNavBar'], true),
        themeMode: _str(j['themeMode'], 'dark'),
        shuffleMode: _str(j['shuffleMode'], 'off'),
        downloadLikedOffline: _bool(j['downloadLikedOffline'], false),
        recDiscovery: _discovery(j['recDiscovery']),
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
        'libraryView': libraryView,
        'libraryPlaylistSort': libraryPlaylistSort,
        'libraryAlbumsGrid': libraryAlbumsGrid,
        'libraryPlaylistsGrid': libraryPlaylistsGrid,
        'floatingNavBar': floatingNavBar,
        'themeMode': themeMode,
        'shuffleMode': shuffleMode,
        'downloadLikedOffline': downloadLikedOffline,
        'recDiscovery': recDiscovery,
      };

  static Future<File> get _file async {
    final dir = await getAppStorageDirectory();
    return File('${dir.path}/melodize_prefs.json');
  }

  // A missing file is a first run and yields defaults. An unreadable one is
  // not: it is moved aside (so the next save can't overwrite the only copy
  // of the user's settings and API keys) and the failure is reported, so
  // the user knows why their settings reset.
  static Future<AppPreferences> load() async {
    final File f;
    try {
      f = await _file;
      if (!await f.exists()) return const AppPreferences();
    } catch (e) {
      AppErrors.report("Couldn't open the settings file", e);
      return const AppPreferences();
    }
    try {
      return AppPreferences.fromJson(
          jsonDecode(await f.readAsString()) as Map<String, dynamic>);
    } catch (e) {
      final backup =
          '${f.path}.unreadable-${DateTime.now().millisecondsSinceEpoch}';
      var where = '';
      try {
        await f.rename(backup);
        where = ' The old file was kept as $backup.';
      } catch (_) {
        // Reported below either way; the original file is still in place.
      }
      AppErrors.report(
          'Settings could not be read and were reset to defaults.$where', e);
      return const AppPreferences();
    }
  }

  // Written to a temp file and renamed so a crash mid-write can't leave a
  // truncated file (load() would then silently reset every setting, including
  // the companion API key). The file holds secrets, so on desktop it is made
  // readable by the owner only.
  //
  // Throws on failure; PreferencesNotifier reports it to the user.
  Future<void> save() async {
    final f = await _file;
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode(toJson()), flush: true);
    if (isDesktopPlatform && !Platform.isWindows) {
      await Process.run('chmod', ['600', tmp.path]);
    }
    await tmp.rename(f.path);
  }
}
