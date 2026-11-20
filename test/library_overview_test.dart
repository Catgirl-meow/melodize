import 'package:flutter_test/flutter_test.dart';
import 'package:melodize/core/library/library_overview.dart';
import 'package:melodize/core/models/artist.dart';
import 'package:melodize/core/models/playlist.dart';
import 'package:melodize/core/models/song.dart';

Song _song(String id, {String? album, DateTime? created}) => Song(
    id: id,
    title: id,
    artist: 'A',
    album: album ?? 'Album $id',
    albumId: album,
    created: created);

void main() {
  test('recentlyAddedSongs is newest first and skips undated songs', () {
    final songs = [
      _song('old', created: DateTime(2024)),
      _song('none'),
      _song('new', created: DateTime(2026)),
    ];
    expect(recentlyAddedSongs(songs).map((s) => s.id), ['new', 'old']);
    expect(recentlyAddedSongs(songs, limit: 1).single.id, 'new');
  });

  test('recentlyAddedAlbums orders by each album\'s newest song', () {
    final songs = [
      _song('1', album: 'x', created: DateTime(2020)),
      _song('2', album: 'x', created: DateTime(2026, 3)),
      _song('3', album: 'y', created: DateTime(2025)),
      _song('4', album: 'z'),
    ];
    expect(recentlyAddedAlbums(songs).map((a) => a.id), ['x', 'y']);
  });

  test('artistsByPlays ranks by local plays, then album count', () {
    const artists = [
      Artist(id: '1', name: 'Quiet', albumCount: 9),
      Artist(id: '2', name: 'Loved', albumCount: 1),
      Artist(id: '3', name: 'Some', albumCount: 2),
    ];
    final ranked = artistsByPlays(artists, ['loved', 'Loved', 'Some']);
    expect(ranked.map((a) => a.name), ['Loved', 'Some', 'Quiet']);
  });

  test('sortPlaylists', () {
    const a = Playlist(
        id: 'a', name: 'beta', songCount: 1, duration: 0,
        changed: '2026-01-01T00:00:00Z');
    const b = Playlist(
        id: 'b', name: 'Alpha', songCount: 5, duration: 0,
        changed: '2026-11-01T00:00:00Z');
    expect(sortPlaylists([a, b], PlaylistSort.updated).first.id, 'b');
    expect(sortPlaylists([a, b], PlaylistSort.name).first.id, 'b');
    expect(sortPlaylists([b, a], PlaylistSort.songCount).first.id, 'b');
  });
}
