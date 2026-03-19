class Artist {
  final String id;
  final String name;
  final int albumCount;
  final String? coverArt;

  const Artist({
    required this.id,
    required this.name,
    required this.albumCount,
    this.coverArt,
  });

  factory Artist.fromSubsonicJson(Map<String, dynamic> json) => Artist(
        id: json['id'].toString(),
        name: json['name'] ?? 'Unknown Artist',
        albumCount: json['albumCount'] ?? 0,
        coverArt: json['coverArt']?.toString(),
      );
}
