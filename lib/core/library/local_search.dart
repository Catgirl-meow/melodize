import '../models/album.dart';
import '../models/artist.dart';
import '../models/search_results.dart';
import '../models/song.dart';
import '../utils/title_normalize.dart';

// Library views built from the on-device song cache (the songs last synced
// from the server, downloaded or not). Used when the server can't be asked:
// the device is offline, or the request failed with a connection error.
// Albums and artists are derived from cached songs, so only the ones with at
// least one cached song exist here.

/// Searches the cached library. A song matches when every word of [query]
/// appears in its title, artist or album. Downloaded songs sort first, since
/// they are the ones that can play without a connection.
SearchResults searchCachedLibrary(
  List<Song> songs,
  String query, {
  int songLimit = 50,
  int albumLimit = 20,
  int artistLimit = 20,
}) {
  final terms =
      foldForSearch(query).split(' ').where((t) => t.isNotEmpty).toList();
  if (terms.isEmpty) return SearchResults.empty(fromCache: true);

  bool matches(String haystack) {
    final folded = foldForSearch(haystack);
    return terms.every(folded.contains);
  }

  final songHits =
      songs.where((s) => matches('${s.title} ${s.artist} ${s.album}')).toList()
        ..sort((a, b) {
          if (a.isDownloaded != b.isDownloaded) return a.isDownloaded ? -1 : 1;
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        });
  final albums = albumsFromSongs(songs)
      .where((a) => matches('${a.name} ${a.artist}'))
      .take(albumLimit)
      .toList();
  final artists = artistsFromSongs(songs)
      .where((a) => matches(a.name))
      .take(artistLimit)
      .toList();

  return SearchResults(
    songs: songHits.take(songLimit).toList(),
    albums: albums,
    artists: artists,
    fromCache: true,
  );
}

/// One album per album id, sorted by name.
List<Album> albumsFromSongs(List<Song> songs) {
  final byId = <String, List<Song>>{};
  for (final s in songs) {
    final id = s.albumId;
    if (id == null || id.isEmpty) continue;
    byId.putIfAbsent(id, () => []).add(s);
  }
  final albums = [
    for (final MapEntry(key: id, value: list) in byId.entries)
      Album(
        id: id,
        name: list.first.album,
        artist: list.first.artist,
        artistId: list.first.artistId,
        songCount: list.length,
        duration: list.fold(0, (sum, s) => sum + (s.duration ?? 0)),
        coverArt: _firstCover(list),
        year: list.first.year,
        genre: list.first.genre,
      ),
  ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return albums;
}

/// One artist per artist id, sorted by name.
List<Artist> artistsFromSongs(List<Song> songs) {
  final byId = <String, List<Song>>{};
  for (final s in songs) {
    final id = s.artistId;
    if (id == null || id.isEmpty) continue;
    byId.putIfAbsent(id, () => []).add(s);
  }
  final artists = [
    for (final MapEntry(key: id, value: list) in byId.entries)
      Artist(
        id: id,
        name: list.first.artist,
        albumCount: list
            .map((s) => s.albumId)
            .where((a) => a != null && a.isNotEmpty)
            .toSet()
            .length,
        coverArt: _firstCover(list),
      ),
  ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return artists;
}

/// The cached songs of one album, in track order.
List<Song> cachedAlbumSongs(List<Song> songs, String albumId) =>
    songs.where((s) => s.albumId == albumId).toList()
      ..sort((a, b) => (a.track ?? 0).compareTo(b.track ?? 0));

/// The cached songs of one artist, grouped by album, in track order.
List<Song> cachedArtistSongs(List<Song> songs, String artistId) =>
    songs.where((s) => s.artistId == artistId).toList()
      ..sort((a, b) {
        final byAlbum = a.album.toLowerCase().compareTo(b.album.toLowerCase());
        if (byAlbum != 0) return byAlbum;
        return (a.track ?? 0).compareTo(b.track ?? 0);
      });

String? _firstCover(List<Song> songs) {
  for (final s in songs) {
    final c = s.coverArt;
    if (c != null && c.isNotEmpty) return c;
  }
  return null;
}
