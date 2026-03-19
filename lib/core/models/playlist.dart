class Playlist {
  final String id;
  final String name;
  final String? comment;
  final int songCount;
  final int duration;
  final String? coverArt;
  final String changed;

  const Playlist({
    required this.id,
    required this.name,
    this.comment,
    required this.songCount,
    required this.duration,
    this.coverArt,
    required this.changed,
  });

  factory Playlist.fromSubsonicJson(Map<String, dynamic> json) {
    return Playlist(
      id: json['id'].toString(),
      name: json['name'] ?? 'Unnamed Playlist',
      comment: json['comment'],
      songCount: json['songCount'] ?? 0,
      duration: json['duration'] ?? 0,
      coverArt: json['coverArt']?.toString(),
      changed: json['changed'] ?? '',
    );
  }
}
