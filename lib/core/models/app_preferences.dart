import 'dart:convert';
import 'dart:io';
import '../utils/platform_dirs.dart';

class AppPreferences {
  final String streamQuality;      // 'lossless' | '320' | '192' | '128'
  final String autoDownload;       // 'never' | 'on_play' | 'all'
  final String downloadQuality;    // 'lossless' | '320' | '192' | '128'
  final String companionUrl;       // e.g. 'http://100.73.73.73:8765'  (empty = disabled)
  final String companionApiKey;    // X-API-Key value
  final String deezerArl;          // Deezer ARL cookie — enables FLAC downloads via companion
  final String librarySongSort;    // 'name' | 'artist' | 'recentlyAdded' | 'downloaded'
  final bool librarySongAscending;
  final String libraryAlbumSort;   // 'name' | 'artist' | 'year' | 'songCount'
  final bool libraryAlbumAscending;
  final String libraryArtistSort;  // 'name' | 'albumCount'
  final bool libraryArtistAscending;
  final bool floatingNavBar;       // true = floating pill dock, false = classic nav bar

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
  });

  bool get hasCompanion => companionUrl.isNotEmpty && companionApiKey.isNotEmpty;
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
        libraryAlbumAscending: libraryAlbumAscending ?? this.libraryAlbumAscending,
        libraryArtistSort: libraryArtistSort ?? this.libraryArtistSort,
        libraryArtistAscending: libraryArtistAscending ?? this.libraryArtistAscending,
        floatingNavBar: floatingNavBar ?? this.floatingNavBar,
      );

  factory AppPreferences.fromJson(Map<String, dynamic> j) => AppPreferences(
        streamQuality: j['streamQuality'] as String? ?? 'lossless',
        autoDownload: j['autoDownload'] as String? ?? 'never',
        downloadQuality: j['downloadQuality'] as String? ?? 'lossless',
        companionUrl: j['companionUrl'] as String? ?? '',
        companionApiKey: j['companionApiKey'] as String? ?? '',
        deezerArl: j['deezerArl'] as String? ?? '',
        librarySongSort: j['librarySongSort'] as String? ?? 'name',
        librarySongAscending: j['librarySongAscending'] as bool? ?? true,
        libraryAlbumSort: j['libraryAlbumSort'] as String? ?? 'name',
        libraryAlbumAscending: j['libraryAlbumAscending'] as bool? ?? true,
        libraryArtistSort: j['libraryArtistSort'] as String? ?? 'name',
        libraryArtistAscending: j['libraryArtistAscending'] as bool? ?? true,
        floatingNavBar: j['floatingNavBar'] as bool? ?? true,
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

  Future<void> save() async {
    try {
      final f = await _file;
      await f.writeAsString(jsonEncode(toJson()));
    } catch (_) {}
  }
}
