import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class AppPreferences {
  final String streamQuality;   // 'lossless' | '320' | '192' | '128'
  final String autoDownload;    // 'never' | 'on_play' | 'all'
  final String downloadQuality; // 'lossless' | '320' | '192' | '128'
  final String companionUrl;    // e.g. 'http://100.73.73.73:8765'  (empty = disabled)
  final String companionApiKey; // X-API-Key value

  const AppPreferences({
    this.streamQuality = 'lossless',
    this.autoDownload = 'never',
    this.downloadQuality = 'lossless',
    this.companionUrl = '',
    this.companionApiKey = '',
  });

  bool get hasCompanion => companionUrl.isNotEmpty && companionApiKey.isNotEmpty;

  AppPreferences copyWith({
    String? streamQuality,
    String? autoDownload,
    String? downloadQuality,
    String? companionUrl,
    String? companionApiKey,
  }) =>
      AppPreferences(
        streamQuality: streamQuality ?? this.streamQuality,
        autoDownload: autoDownload ?? this.autoDownload,
        downloadQuality: downloadQuality ?? this.downloadQuality,
        companionUrl: companionUrl ?? this.companionUrl,
        companionApiKey: companionApiKey ?? this.companionApiKey,
      );

  factory AppPreferences.fromJson(Map<String, dynamic> j) => AppPreferences(
        streamQuality: j['streamQuality'] as String? ?? 'lossless',
        autoDownload: j['autoDownload'] as String? ?? 'never',
        downloadQuality: j['downloadQuality'] as String? ?? 'lossless',
        companionUrl: j['companionUrl'] as String? ?? '',
        companionApiKey: j['companionApiKey'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'streamQuality': streamQuality,
        'autoDownload': autoDownload,
        'downloadQuality': downloadQuality,
        'companionUrl': companionUrl,
        'companionApiKey': companionApiKey,
      };

  static Future<File> get _file async {
    final dir = await getApplicationDocumentsDirectory();
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
