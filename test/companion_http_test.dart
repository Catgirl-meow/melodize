import 'package:flutter_test/flutter_test.dart';
import 'package:melodize/core/api/companion_audio_api.dart';
import 'package:melodize/core/api/companion_http.dart';

void main() {
  group('isPrivateNetworkHost', () {
    test('accepts LAN, loopback, Tailscale and local names', () {
      for (final h in [
        'localhost',
        '127.0.0.1',
        '10.0.0.5',
        '172.16.0.1',
        '172.31.255.255',
        '192.168.2.2',
        '169.254.1.1',
        '100.64.0.1',
        '100.127.255.254',
        '::1',
        '[::1]',
        'fd12:3456::1',
        'fe80::1',
        'nas.local',
        'NAS.LAN',
        'music.home.arpa',
      ]) {
        expect(isPrivateNetworkHost(h), isTrue, reason: h);
      }
    });

    test('rejects public hosts', () {
      for (final h in [
        'example.com',
        'music.catg1rl.com',
        '8.8.8.8',
        '172.32.0.1',
        '172.15.0.1',
        '100.128.0.1',
        '192.169.0.1',
        '2001:4860:4860::8888',
        'local.example.com',
        'evil-localhost.com',
      ]) {
        expect(isPrivateNetworkHost(h), isFalse, reason: h);
      }
    });
  });

  group('serverUrlError', () {
    test('accepts https anywhere and http on private hosts', () {
      for (final u in [
        'https://music.example.com',
        'https://8.8.8.8:4533',
        'http://localhost:4533',
        'http://192.168.2.2:4533/',
        'http://10.0.2.2:4534',
        'http://100.101.102.103:4533',
        'http://[fd00::5]:4533',
        'http://nas.lan',
        '  http://192.168.1.10:4533  ',
      ]) {
        expect(serverUrlError(u), isNull, reason: u);
      }
    });

    test('rejects http on public hosts', () {
      for (final u in [
        'http://music.example.com',
        'http://8.8.8.8:4533',
        'http://music.catg1rl.com',
      ]) {
        expect(serverUrlError(u), contains('https://'), reason: u);
      }
    });

    test('rejects other schemes and missing hosts', () {
      for (final u in ['ftp://example', 'example.com', 'http://', '']) {
        expect(serverUrlError(u), 'URL must start with http:// or https://',
            reason: u);
      }
    });
  });

  group('CompanionAudioApi.resolveUrl', () {
    final api = CompanionAudioApi(
        baseUrl: 'https://192.168.2.22:8765/', apiKey: 'k');

    test('joins relative paths onto the base URL', () {
      expect(api.resolveUrl('/api/audio/transition/a.wav'),
          'https://192.168.2.22:8765/api/audio/transition/a.wav');
      expect(api.resolveUrl('api/audio/transition/a.wav'),
          'https://192.168.2.22:8765/api/audio/transition/a.wav');
    });

    test('keeps absolute URLs on the same origin', () {
      expect(api.resolveUrl('https://192.168.2.22:8765/x.wav'),
          'https://192.168.2.22:8765/x.wav');
    });

    test('refuses absolute URLs on another origin (would leak the API key)', () {
      expect(api.resolveUrl('https://evil.example/x.wav'), isNull);
      expect(api.resolveUrl('http://192.168.2.22:8765/x.wav'), isNull);
      expect(api.resolveUrl('https://192.168.2.22:9999/x.wav'), isNull);
    });

    test('downloadTransition does not contact foreign hosts', () async {
      expect(await api.downloadTransition('https://evil.example/x.wav'), isNull);
    });
  });

  test('isSameOrigin compares scheme, host and port', () {
    final base = Uri.parse('http://nas.lan:8765');
    expect(isSameOrigin(Uri.parse('http://nas.lan:8765/a'), base), isTrue);
    expect(isSameOrigin(Uri.parse('https://nas.lan:8765/a'), base), isFalse);
    expect(isSameOrigin(Uri.parse('http://nas.lan/a'), base), isFalse);
  });
}
