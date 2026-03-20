class RecommendedTrack {
  final int deezerId;
  final String title;
  final String artist;
  final String album;
  final int durationSeconds;
  final String? previewUrl;  // 30-second MP3 from Deezer CDN
  final String? coverUrl;    // album art, full HTTPS URL

  const RecommendedTrack({
    required this.deezerId,
    required this.title,
    required this.artist,
    required this.album,
    required this.durationSeconds,
    this.previewUrl,
    this.coverUrl,
  });

  factory RecommendedTrack.fromDeezerJson(Map<String, dynamic> json) {
    final artist = json['artist'] as Map<String, dynamic>? ?? {};
    final album = json['album'] as Map<String, dynamic>? ?? {};
    return RecommendedTrack(
      deezerId: json['id'] as int,
      title: (json['title'] as String?) ?? 'Unknown Title',
      artist: (artist['name'] as String?) ?? 'Unknown Artist',
      album: (album['title'] as String?) ?? '',
      durationSeconds: (json['duration'] as int?) ?? 0,
      previewUrl: json['preview'] as String?,
      coverUrl: (album['cover_medium'] as String?) ??
          (album['cover_big'] as String?),
    );
  }
}
