// Splitting a track's artist credit into the artists Deezer knows.
//
// Navidrome joins a track's artists into one display string with " • "
// ("qaraqshy • !Nxght • KIXIA"), and tags often use ";", " / " or "feat.".
// Deezer only has single artists, so a whole credit used as a radio seed
// finds nothing and the seed fails.

/// Separators that always mean "more than one artist".
final _strongSeparator = RegExp(
  r'\s*[•·;]\s*|\s+/\s+|\s+(?:feat\.?|ft\.?|featuring)\s+',
  caseSensitive: false,
);

/// Separators that can also be part of one artist's name ("Simon &
/// Garfunkel", "Earth, Wind & Fire", "Malcolm X"); only tried when the whole
/// name isn't on Deezer.
final _weakSeparator = RegExp(r'\s*,\s*|\s+&\s+|\s+x\s+|\s+vs\.?\s+');

/// The artists in [credit], split on separators that always mean several
/// artists. A single artist comes back as a one-element list; an empty
/// credit as an empty one.
List<String> splitArtistCredit(String credit) {
  final out = <String>[];
  for (final part in credit.split(_strongSeparator)) {
    final p = part.trim();
    if (p.isNotEmpty && !out.contains(p)) out.add(p);
  }
  return out;
}

/// Names to try, in order, when looking [artist] up on Deezer: the name as
/// written, then each artist of a joined credit, then parts split on ","
/// "&" "x" "vs" ("MC KAIQUE SP, merunes" → "MC KAIQUE SP", "merunes").
List<String> artistLookupNames(String artist) {
  final out = [artist.trim()];
  void addAll(Iterable<String> parts) {
    for (final part in parts) {
      final p = part.trim();
      if (p.isNotEmpty && !out.contains(p)) out.add(p);
    }
  }

  // A joined credit can still arrive whole (song radio on a library
  // track by "A • B"), so split that first.
  final credited = splitArtistCredit(artist);
  addAll(credited);
  for (final a in credited) {
    addAll(a.split(_weakSeparator));
  }
  return out;
}
