import 'package:flutter_test/flutter_test.dart';
import 'package:melodize/core/models/app_preferences.dart';

void main() {
  group('AppPreferences JSON', () {
    test('round-trips every field', () {
      const prefs = AppPreferences(
        streamQuality: '320',
        autoDownload: 'on_play',
        downloadQuality: '192',
        companionUrl: 'https://companion.lan:8765',
        companionApiKey: 'key',
        deezerArl: 'arl',
        librarySongSort: 'artist',
        librarySongAscending: false,
        libraryAlbumSort: 'year',
        libraryAlbumAscending: false,
        libraryArtistSort: 'albumCount',
        libraryArtistAscending: false,
        floatingNavBar: false,
        themeMode: 'light',
        shuffleMode: 'smartShuffle',
      );
      final back = AppPreferences.fromJson(prefs.toJson());
      expect(back.toJson(), prefs.toJson());
    });

    test('missing fields fall back to defaults', () {
      final prefs = AppPreferences.fromJson({});
      expect(prefs.toJson(), const AppPreferences().toJson());
      expect(prefs.hasCompanion, isFalse);
      expect(prefs.hasDeezerArl, isFalse);
    });

    test('a field with the wrong type does not discard the others', () {
      final prefs = AppPreferences.fromJson({
        'streamQuality': 320, // was an int in a hand-edited file
        'floatingNavBar': 'yes',
        'companionUrl': 'http://192.168.1.2:8765',
        'companionApiKey': 'secret',
      });
      expect(prefs.streamQuality, 'lossless');
      expect(prefs.floatingNavBar, isTrue);
      expect(prefs.companionUrl, 'http://192.168.1.2:8765');
      expect(prefs.hasCompanion, isTrue);
    });

    test('hasCompanion needs both URL and key', () {
      expect(const AppPreferences(companionUrl: 'http://x').hasCompanion, isFalse);
      expect(const AppPreferences(companionApiKey: 'k').hasCompanion, isFalse);
    });

    test('copyWith only changes the given fields', () {
      const prefs = AppPreferences(themeMode: 'light', deezerArl: 'a');
      final next = prefs.copyWith(deezerArl: '');
      expect(next.themeMode, 'light');
      expect(next.hasDeezerArl, isFalse);
    });
  });
}
