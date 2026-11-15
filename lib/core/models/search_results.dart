import 'song.dart';
import 'album.dart';
import 'artist.dart';

class SearchResults {
  final List<Song> songs;
  final List<Album> albums;
  final List<Artist> artists;

  /// True when these came from the on-device library cache because the
  /// server could not be asked (offline, or the request failed to connect).
  /// The search screen says so, since the cache may be out of date.
  final bool fromCache;

  const SearchResults({
    required this.songs,
    required this.albums,
    required this.artists,
    this.fromCache = false,
  });

  bool get isEmpty => songs.isEmpty && albums.isEmpty && artists.isEmpty;

  factory SearchResults.empty({bool fromCache = false}) => SearchResults(
      songs: const [],
      albums: const [],
      artists: const [],
      fromCache: fromCache);
}
