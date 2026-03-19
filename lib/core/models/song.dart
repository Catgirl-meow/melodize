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
  final String? suffix;       // flac, mp3, etc.
  final String? contentType;
  final int? bitRate;
  final int? size;
  final bool isDownloaded;
  final String? localPath;
  final DateTime? created; // When the song was added to the server library

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
  });

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
    );
  }

  Song copyWith({bool? isDownloaded, String? localPath}) {
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
      isDownloaded: isDownloaded ?? this.isDownloaded,
      localPath: localPath ?? this.localPath,
      created: created,
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
