class Album {
  final String id;
  final String name;
  final String artist;
  final String? artistId;
  final int songCount;
  final int duration;
  final String? coverArt;
  final int? year;
  final String? genre;

  const Album({
    required this.id,
    required this.name,
    required this.artist,
    this.artistId,
    required this.songCount,
    required this.duration,
    this.coverArt,
    this.year,
    this.genre,
  });

  factory Album.fromSubsonicJson(Map<String, dynamic> json) => Album(
        id: json['id'].toString(),
        name: json['name'] ?? 'Unknown Album',
        artist: json['artist'] ?? 'Unknown Artist',
        artistId: json['artistId']?.toString(),
        songCount: json['songCount'] ?? 0,
        duration: json['duration'] ?? 0,
        coverArt: json['coverArt']?.toString(),
        year: json['year'],
        genre: json['genre'],
      );
}
