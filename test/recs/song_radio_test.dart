// Song radio: songs like the playing one, from its artist's Deezer radio.
import 'package:flutter_test/flutter_test.dart';
import 'package:melodize/core/api/deezer_client.dart';
import 'package:melodize/core/models/recommended_track.dart';
import 'package:melodize/core/models/song.dart';
import 'package:melodize/core/recs/song_radio.dart';
import 'package:melodize/core/recs/taste_model.dart' show NoDeezerRadio;

class _FakeDeezer extends DeezerClient {
  static const known = {'Kaito Ren', 'Glass Parade'};
  final bool down;
  final searched = <String>[];
  _FakeDeezer({this.down = false});

  @override
  Future<int?> searchBestArtist(
      {required String artistName,
      String? trackTitle,
      String? genreHint}) async {
    searched.add(artistName);
    if (down) throw Exception('HTTP 503');
    return known.contains(artistName) ? 7 : null;
  }

  @override
  Future<List<RecommendedTrack>> artistRadio(int artistId,
          {int limit = 10}) async =>
      [
        const RecommendedTrack(
            deezerId: 1,
            title: 'Tokyo Rain',
            artist: 'Kaito Ren',
            album: 'A',
            durationSeconds: 200,
            previewUrl: 'https://example.test/1.mp3'),
        const RecommendedTrack(
            deezerId: 2,
            title: 'Unavailable',
            artist: 'Fan',
            album: 'A',
            durationSeconds: 200,
            previewUrl: ''),
        for (var i = 0; i < 5; i++)
          RecommendedTrack(
              deezerId: 10 + i,
              title: 'Song $i',
              artist: 'Fan $i',
              album: 'A',
              durationSeconds: 200,
              previewUrl: 'https://example.test/$i.mp3'),
        const RecommendedTrack(
            deezerId: 99,
            title: 'Song 0',
            artist: 'Fan 0',
            album: 'A',
            durationSeconds: 200,
            previewUrl: 'https://example.test/99.mp3'),
      ];
}

Song _song(String artist, String title) =>
    Song(id: 'x', title: title, artist: artist, album: 'A');

void main() {
  test(
      'radio queues playable previews without the joined-credit seed or duplicates',
      () async {
    final songs = await songRadio(
        deezer: _FakeDeezer(), seed: _song('Kaito Ren • Mio', 'Tokyo Rain'));
    expect(songs.map((s) => s.title),
        ['Song 0', 'Song 1', 'Song 2', 'Song 3', 'Song 4']);
    expect(songs.every((s) => s.isExternal), isTrue);
  });

  test('hidden songs are left out', () async {
    final songs = await songRadio(
        deezer: _FakeDeezer(),
        seed: _song('Kaito Ren', 'Tokyo Rain'),
        hide: (s) => s.artist == 'Fan 1');
    expect(songs.map((s) => s.artist), isNot(contains('Fan 1')));
  });

  test('a joined credit "A • B" finds A', () async {
    final deezer = _FakeDeezer();
    await songRadio(deezer: deezer, seed: _song('Glass Parade • Mio', 'T'));
    expect(deezer.searched, ['Glass Parade • Mio', 'Glass Parade']);
  });

  test('an artist Deezer doesn\'t know: NoDeezerRadio, not an empty list',
      () async {
    await expectLater(
        songRadio(deezer: _FakeDeezer(), seed: _song('Nobody', 'T')),
        throwsA(isA<NoDeezerRadio>()));
  });

  test('Deezer down: the error comes through', () async {
    await expectLater(
        songRadio(
            deezer: _FakeDeezer(down: true), seed: _song('Kaito Ren', 'T')),
        throwsA(isA<Exception>()));
  });
}
