import 'package:flutter_test/flutter_test.dart';
import 'package:melodize/core/models/song.dart';
import 'package:melodize/shared/widgets/playlist_cover.dart';

Song _song(String id, {String? album, String? cover}) => Song(
      id: id,
      title: id,
      artist: 'a',
      album: album ?? '',
      albumId: album,
      coverArt: cover,
      duration: 1,
    );

void main() {
  test('one cover per album, in playlist order, up to four', () {
    final songs = [
      for (final (i, a) in ['a', 'b', 'a', 'c', 'd', 'e'].indexed)
        _song('$a$i', album: a, cover: 'mf-$a-x'),
    ];
    // Distinct song cover ids within the same album still count once.
    songs.insert(1, _song('a2', album: 'a', cover: 'mf-a-other'));
    expect(playlistCoverIds(songs), ['mf-a-x', 'mf-b-x', 'mf-c-x', 'mf-d-x']);
  });

  test('songs without art are skipped', () {
    final songs = [
      _song('1', album: 'a'),
      _song('2', album: 'b', cover: ''),
      _song('3', album: 'c', cover: 'mf-c'),
    ];
    expect(playlistCoverIds(songs), ['mf-c']);
  });

  test('no art at all gives an empty list', () {
    expect(playlistCoverIds([_song('1', album: 'a')]), isEmpty);
    expect(playlistCoverIds(const []), isEmpty);
  });

  test('songs without albumId dedupe by cover id', () {
    final songs = [
      _song('1', cover: 'x'),
      _song('2', cover: 'x'),
      _song('3', cover: 'y'),
    ];
    expect(playlistCoverIds(songs), ['x', 'y']);
  });
}
