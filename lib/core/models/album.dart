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

  /// OpenSubsonic release types read from tags ("album", "ep", "single",
  /// "compilation", …). Empty when the server doesn't report them.
  final List<String> releaseTypes;

  /// OpenSubsonic `isCompilation`; null when the server doesn't say.
  final bool? isCompilation;

  /// Server-side play count (OpenSubsonic); null when not reported.
  final int? playCount;

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
    this.releaseTypes = const [],
    this.isCompilation,
    this.playCount,
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
        releaseTypes: [
          for (final t in (json['releaseTypes'] as List? ?? const []))
            if (t != null && t.toString().trim().isNotEmpty) t.toString(),
        ],
        isCompilation: json['isCompilation'] is bool
            ? json['isCompilation'] as bool
            : null,
        playCount: (json['playCount'] as num?)?.toInt(),
      );
}
