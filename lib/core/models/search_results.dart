import 'song.dart';
import 'album.dart';
import 'artist.dart';

class SearchResults {
  final List<Song> songs;
  final List<Album> albums;
  final List<Artist> artists;

  const SearchResults({
    required this.songs,
    required this.albums,
    required this.artists,
  });

  bool get isEmpty => songs.isEmpty && albums.isEmpty && artists.isEmpty;
}
