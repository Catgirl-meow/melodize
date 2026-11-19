class Song {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String? albumId;
  final String? artistId;
  final int? duration; // seconds
  final int? year;
  final String? genre;
  final int? track;
  final String? coverArt;
  final String? suffix; // flac, mp3, etc.
  final String? contentType;
  final int? bitRate;
  final int? size;
  final bool isDownloaded;
  final String? localPath;
  final DateTime? created;

  /// When the user starred ("liked") the song on the server; null when not
  /// liked. Read from Subsonic's `starred` field and cached locally.
  final DateTime? starred;

  /// Navidrome's play count for this user, across every client.
  final int? playCount;

  // Only set for external tracks (e.g. Deezer previews). Never stored in DB.
  final String? externalStreamUrl;
  final String? externalCoverUrl;

  // BPM from Deezer API. Only set for recommendations; null for library songs.
  final int? bpm;

  const Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    this.albumId,
    this.artistId,
    this.duration,
    this.year,
    this.genre,
    this.track,
    this.coverArt,
    this.suffix,
    this.contentType,
    this.bitRate,
    this.size,
    this.isDownloaded = false,
    this.localPath,
    this.created,
    this.starred,
    this.playCount,
    this.externalStreamUrl,
    this.externalCoverUrl,
    this.bpm,
  });

  // Placeholder for out-of-bounds fallback. Never displayed.
  factory Song.empty() => const Song(
        id: '',
        title: 'Unknown',
        artist: 'Unknown',
        album: 'Unknown',
      );

  factory Song.fromSubsonicJson(Map<String, dynamic> json) {
    return Song(
      id: json['id'].toString(),
      title: json['title'] ?? 'Unknown Title',
      artist: json['artist'] ?? 'Unknown Artist',
      album: json['album'] ?? 'Unknown Album',
      albumId: json['albumId']?.toString(),
      artistId: json['artistId']?.toString(),
      duration: json['duration'],
      year: json['year'],
      genre: json['genre'],
      track: json['track'],
      coverArt: json['coverArt']?.toString(),
      suffix: json['suffix'],
      contentType: json['contentType'],
      bitRate: json['bitRate'],
      size: json['size'],
      created: json['created'] != null
          ? DateTime.tryParse(json['created'].toString())
          : null,
      starred: json['starred'] != null
          ? DateTime.tryParse(json['starred'].toString())
          : null,
      playCount: json['playCount'] is int ? json['playCount'] as int : null,
    );
  }

  bool get isStarred => starred != null;

  /// True for Deezer recommendations and previews, which aren't on the
  /// server (yet).
  bool get isExternal => id.startsWith('deezer:');

  Song copyWith({bool? isDownloaded, String? localPath}) => _copy(
      isDownloaded ?? this.isDownloaded, localPath ?? this.localPath, starred);

  /// This song with its download state cleared ([copyWith] cannot null
  /// [localPath]).
  Song withoutDownload() => _copy(false, null, starred);

  /// This song with its like set to [when], or cleared when null.
  Song withStarred(DateTime? when) => _copy(isDownloaded, localPath, when);

  Song _copy(bool isDownloaded, String? localPath, DateTime? starred) {
    return Song(
      id: id,
      title: title,
      artist: artist,
      album: album,
      albumId: albumId,
      artistId: artistId,
      duration: duration,
      year: year,
      genre: genre,
      track: track,
      coverArt: coverArt,
      suffix: suffix,
      contentType: contentType,
      bitRate: bitRate,
      size: size,
      isDownloaded: isDownloaded,
      localPath: localPath,
      created: created,
      starred: starred,
      playCount: playCount,
      externalStreamUrl: externalStreamUrl,
      externalCoverUrl: externalCoverUrl,
      bpm: bpm,
    );
  }

  // Build a Song from a Deezer recommendation.
  factory Song.fromRecommendation({
    required int deezerId,
    required String title,
    required String artist,
    required String album,
    required int durationSeconds,
    String? previewUrl,
    String? coverUrl,
    double? bpm,
    String? genre,
  }) {
    return Song(
      id: 'deezer:$deezerId',
      title: title,
      artist: artist,
      album: album,
      duration: durationSeconds,
      externalStreamUrl: previewUrl,
      externalCoverUrl: coverUrl,
      bpm: bpm?.round().clamp(40, 200),
      genre: genre,
    );
  }

  String get durationFormatted {
    if (duration == null) return '--:--';
    final m = duration! ~/ 60;
    final s = duration! % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String get qualityLabel {
    if (suffix != null) return suffix!.toUpperCase();
    return '';
  }
}

/// The Deezer track id behind a recommendation or preview, or null for a
/// library song.
int? deezerIdOf(Song song) => song.id.startsWith('deezer:')
    ? int.tryParse(song.id.substring('deezer:'.length))
    : null;
