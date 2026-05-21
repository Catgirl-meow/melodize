class RecommendedTrack {
  final int deezerId;
  final String title;
  final String artist;
  final String album;
  final int durationSeconds;
  final String? previewUrl;  // 30-second MP3 from Deezer CDN
  final String? coverUrl;    // album art, full HTTPS URL
  final double? bpm;         // BPM from Deezer API (track-level field)
  final String? genre;       // Genre name, extracted from Deezer genre_id if possible

  const RecommendedTrack({
    required this.deezerId,
    required this.title,
    required this.artist,
    required this.album,
    required this.durationSeconds,
    this.previewUrl,
    this.coverUrl,
    this.bpm,
    this.genre,
  });

  factory RecommendedTrack.fromDeezerJson(Map<String, dynamic> json) {
    final artist = json['artist'] as Map<String, dynamic>? ?? {};
    final album = json['album'] as Map<String, dynamic>? ?? {};

    // Extract genre from Deezer's genres.data array or genre_id field.
    String? genre;
    final genresData = json['genres'] as Map<String, dynamic>?;
    if (genresData != null) {
      final data = genresData['data'] as List?;
      if (data != null && data.isNotEmpty) {
        genre = (data.first as Map<String, dynamic>)['name'] as String?;
      }
    }
    if (genre == null && json['genre_id'] is int) {
      genre = _deezerGenreIdToName(json['genre_id'] as int);
    }

    return RecommendedTrack(
      deezerId: json['id'] as int,
      title: (json['title'] as String?) ?? 'Unknown Title',
      artist: (artist['name'] as String?) ?? 'Unknown Artist',
      album: (album['title'] as String?) ?? '',
      durationSeconds: (json['duration'] as int?) ?? 0,
      previewUrl: (json['preview'] ?? json['preview_url']) as String?,
      coverUrl: (album['cover_xl'] as String?) ??
          (album['cover_big'] as String?) ??
          (album['cover_medium'] as String?),
      bpm: (json['bpm'] as num?)?.toDouble(),
      genre: genre,
    );
  }
}

/// Best-effort mapping from Deezer genre_id to a readable genre name.
///
/// Deezer genre IDs are documented at https://developers.deezer.com/api/genre.
/// The mapping covers the most common genres; unknown IDs return null so the
/// caller falls through to other metadata or estimation.
String? _deezerGenreIdToName(int id) {
  switch (id) {
    case 0: return null; // "Not Found"
    case 1: return 'pop';
    case 2: return 'pop'; // "Various"
    case 3: return 'rock';
    case 4: return 'electronic';
    case 5: return 'electronic'; // "Dance"
    case 6: return 'electronic'; // "Techno"
    case 8: return 'jazz';
    case 9: return 'classical';
    case 10: return 'hip-hop';
    case 11: return 'rap';
    case 12: return 'soul';
    case 13: return 'reggae';
    case 14: return 'country';
    case 15: return 'rock'; // "Metal" / "Hard Rock" — use rock for BPM estimation
    case 16: return 'world';
    case 17: return 'blues';
    case 18: return 'punk';
    case 19: return 'folk';
    case 20: return 'electronic'; // "House" — sent to electronic range
    case 21: return 'alternative';
    case 22: return 'latin';
    case 23: return 'reggaeton';
    case 24: return 'soundtrack';
    case 25: return 'electronic'; // "Trance" — electronic range
    case 26: return 'comedy';
    case 27: return 'pop'; // "K-Pop"
    case 28: return 'classical'; // "Opera"
    case 29: return 'pop'; // "J-Pop"
    case 30: return 'rock'; // "Synthwave"
    case 52: return 'pop'; // "Chinese"
    case 60: return 'classical'; // "Orchestral"
    case 80: return 'pop'; // "Indian"
    case 96: return 'pop'; // "Mandopop"
    case 113: return 'rock'; // "Drum and Bass" → use rock midpoint
    case 129: return 'jazz'; // "Blues" — but ID 17 is also blues; this is "Acoustic Blues"
    case 132: return 'pop'; // "Singer-Songwriter"
    case 152: return 'electronic'; // "Dubstep"
    case 153: return 'electronic'; // "Drum and Bass"
    case 164: return 'electronic'; // "Ambient"
    default: return null;
  }
}
