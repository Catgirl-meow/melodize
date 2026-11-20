import '../models/album.dart';
import '../models/artist.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import 'local_search.dart';

// Pure helpers behind the Library overview, built from data the app already
// has (the cached library and local play history), so the overview also
// works offline and costs no extra requests.

/// The [limit] songs most recently added to the server, newest first. Songs
/// without a creation date are left out.
List<Song> recentlyAddedSongs(List<Song> songs, {int limit = 100}) {
  final dated = [for (final s in songs) if (s.created != null) s]
    ..sort((a, b) => b.created!.compareTo(a.created!));
  return dated.take(limit).toList();
}

/// Albums ordered by their newest song's creation date, newest first.
List<Album> recentlyAddedAlbums(List<Song> songs, {int limit = 20}) {
  final newest = <String, DateTime>{};
  for (final s in songs) {
    final id = s.albumId;
    final created = s.created;
    if (id == null || created == null) continue;
    final seen = newest[id];
    if (seen == null || created.isAfter(seen)) newest[id] = created;
  }
  final albums = [
    for (final a in albumsFromSongs(songs))
      if (newest.containsKey(a.id)) a
  ]..sort((a, b) => newest[b.id]!.compareTo(newest[a.id]!));
  return albums.take(limit).toList();
}

/// Artists by how often they appear in [playedArtists] (local play history,
/// artist names), then by album count. Names compare case-insensitively.
List<Artist> artistsByPlays(List<Artist> artists, Iterable<String> playedArtists,
    {int limit = 20}) {
  final plays = <String, int>{};
  for (final name in playedArtists) {
    final key = name.toLowerCase();
    plays[key] = (plays[key] ?? 0) + 1;
  }
  final list = List<Artist>.of(artists)
    ..sort((a, b) {
      final c = (plays[b.name.toLowerCase()] ?? 0)
          .compareTo(plays[a.name.toLowerCase()] ?? 0);
      if (c != 0) return c;
      final d = b.albumCount.compareTo(a.albumCount);
      return d != 0 ? d : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
  return list.take(limit).toList();
}

enum PlaylistSort { updated, name, songCount }

String playlistSortLabel(PlaylistSort s) => switch (s) {
      PlaylistSort.updated => 'Recently updated',
      PlaylistSort.name => 'Name',
      PlaylistSort.songCount => 'Song count',
    };

List<Playlist> sortPlaylists(List<Playlist> playlists, PlaylistSort sort) {
  final list = List<Playlist>.of(playlists);
  switch (sort) {
    case PlaylistSort.updated:
      // ISO 8601 timestamps sort as strings; unknown dates go last.
      list.sort((a, b) => b.changed.compareTo(a.changed));
    case PlaylistSort.name:
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    case PlaylistSort.songCount:
      list.sort((a, b) => b.songCount.compareTo(a.songCount));
  }
  return list;
}
