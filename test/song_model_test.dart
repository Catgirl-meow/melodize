import 'package:flutter_test/flutter_test.dart';
import 'package:melodize/core/models/song.dart';

void main() {
  group('Song.fromSubsonicJson', () {
    test('parses a full Navidrome song entry', () {
      final s = Song.fromSubsonicJson({
        'id': 'abc',
        'title': 'Песня №1',
        'artist': 'Группа Кино',
        'album': 'Звезда',
        'albumId': 'al1',
        'artistId': 'ar1',
        'duration': 30,
        'year': 1989,
        'genre': 'Рок',
        'track': 1,
        'coverArt': 'mf-abc',
        'suffix': 'mp3',
        'contentType': 'audio/mpeg',
        'bitRate': 128,
        'size': 480000,
        'created': '2026-10-27T00:23:18.5Z',
      });
      expect(s.id, 'abc');
      expect(s.title, 'Песня №1');
      expect(s.duration, 30);
      expect(s.created, DateTime.utc(2026, 10, 27, 0, 23, 18, 500));
    });

    test('untagged files get placeholders instead of nulls', () {
      final s = Song.fromSubsonicJson({'id': 42});
      expect(s.id, '42');
      expect(s.title, 'Unknown Title');
      expect(s.artist, 'Unknown Artist');
      expect(s.album, 'Unknown Album');
      expect(s.duration, isNull);
      expect(s.created, isNull);
    });

    test('a malformed created date is ignored', () {
      final s = Song.fromSubsonicJson({'id': 'x', 'created': 'yesterday'});
      expect(s.created, isNull);
    });
  });
}
