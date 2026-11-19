/// Artist details from Subsonic `getArtistInfo2` (Navidrome fills these from
/// Last.fm and Spotify/Deezer images when the server is configured for it).
class ArtistInfo {
  /// Plain-text biography, or null when the server has none.
  final String? biography;
  final String? lastFmUrl;
  final String? musicBrainzId;

  /// Largest artist image the server offers, or null.
  final String? imageUrl;
  final List<SimilarArtist> similar;

  const ArtistInfo({
    this.biography,
    this.lastFmUrl,
    this.musicBrainzId,
    this.imageUrl,
    this.similar = const [],
  });

  static const empty = ArtistInfo();

  factory ArtistInfo.fromSubsonicJson(Map<String, dynamic> json) {
    String? str(Object? v) {
      final s = v?.toString().trim();
      return s == null || s.isEmpty ? null : s;
    }

    return ArtistInfo(
      biography: cleanBiography(json['biography']?.toString()),
      lastFmUrl: str(json['lastFmUrl']),
      musicBrainzId: str(json['musicBrainzId']),
      imageUrl: str(json['largeImageUrl']) ??
          str(json['mediumImageUrl']) ??
          str(json['smallImageUrl']),
      similar: [
        for (final a in (json['similarArtist'] as List? ?? const []))
          if (a is Map<String, dynamic> && str(a['name']) != null)
            SimilarArtist(
              id: str(a['id']),
              name: str(a['name'])!,
              albumCount: (a['albumCount'] as num?)?.toInt() ?? 0,
              coverArt: str(a['coverArt']),
              imageUrl: str(a['artistImageUrl']),
            ),
      ],
    );
  }
}

/// A similar artist. [id] is set only when the artist is in the library.
class SimilarArtist {
  final String? id;
  final String name;
  final int albumCount;
  final String? coverArt;
  final String? imageUrl;

  const SimilarArtist({
    this.id,
    required this.name,
    this.albumCount = 0,
    this.coverArt,
    this.imageUrl,
  });

  bool get inLibrary => id != null;
}

/// Turns Last.fm's HTML biography into plain text: drops tags and the
/// trailing "Read more on Last.fm" link, decodes the common entities.
/// Returns null when nothing readable is left.
String? cleanBiography(String? raw) {
  if (raw == null) return null;
  var s = raw;
  // Last.fm appends `<a href="…">Read more on Last.fm</a>` (sometimes with a
  // licence sentence after it). Cut from the link on.
  final readMore = RegExp(r'<a\b[^>]*>\s*Read more on Last\.fm', caseSensitive: false)
      .firstMatch(s);
  if (readMore != null) s = s.substring(0, readMore.start);
  s = s
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</p\s*>', caseSensitive: false), '\n\n')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&nbsp;', ' ')
      .replaceAll(RegExp(r'[ \t]+'), ' ')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
  return s.isEmpty ? null : s;
}
