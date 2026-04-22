// Normalization helpers for comparing track titles + artists across sources
// (Subsonic library vs Deezer catalog) when surface variants like
// "Song (Remastered 2019)" vs "Song" should be treated as the same track.
//
// Intentionally conservative: aggressive normalization risks collapsing
// genuinely different tracks (e.g. two songs both called "Intro" by different
// artists). That's why [keyFor] includes the artist — matching is only claimed
// when title+artist both normalize to the same string.

// Trailing / inline decorations we want to drop before comparison.
// Ordered by specificity: parenthetical/bracketed groups first, then
// dash-prefixed suffixes, then feat./ft. clauses anywhere in the title.
final _parenBlock = RegExp(r'\s*[\(\[][^)\]]*[\)\]]', multiLine: false);
final _dashSuffix = RegExp(
  r"\s*-\s*(remaster(ed)?|remix|mono|stereo|live|acoustic|edit|version|demo|radio edit|extended)\b.*$",
  caseSensitive: false,
);
final _featClause = RegExp(
  r'\s*(feat\.?|ft\.?|featuring)\s+.*$',
  caseSensitive: false,
);
final _whitespace = RegExp(r'\s+');
final _punctuation = RegExp(r'[^\p{L}\p{N}\s]', unicode: true);

/// Normalize a title or artist for fuzzy equality checks.
///
/// - lowercase
/// - NFD-style accent strip (combining marks removed)
/// - strip (...) and [...] blocks
/// - strip `- Remastered / - Live / - Acoustic / - Mono / ...` trailing suffixes
/// - strip `feat. X`, `ft. X`, `featuring X` clauses
/// - strip non-letter / non-digit punctuation (hyphens, apostrophes, ...)
/// - collapse whitespace
String normalize(String input) {
  // Cheap lowercasing before the heavy regex work.
  var s = input.toLowerCase();

  // Accent strip — Dart's String doesn't expose NFD directly, but stripping
  // combining marks from a pre-decomposed source works for our input set.
  // For typical Latin / Cyrillic / Greek song metadata this is enough.
  s = _stripDiacritics(s);

  s = s.replaceAll(_parenBlock, '');
  s = s.replaceAll(_dashSuffix, '');
  s = s.replaceAll(_featClause, '');
  s = s.replaceAll(_punctuation, ' ');
  s = s.replaceAll(_whitespace, ' ').trim();
  return s;
}

/// Cross-source identity key — matches only when both title and artist
/// normalize to the same strings. Cheap to hash in a [Set].
String keyFor(String title, String artist) =>
    '${normalize(title)}|${normalize(artist)}';

// --- Internal ---------------------------------------------------------------

// Approximate NFD + combining-mark strip. Dart's unicode normalization lives
// in package:characters, but we avoid a new dep for this narrow use case and
// fall back to a manual decompose table for common Latin diacritics.
String _stripDiacritics(String s) {
  // Fast path — if the string is plain ASCII, nothing to strip.
  if (_isAscii(s)) return s;

  final buf = StringBuffer();
  for (final rune in s.runes) {
    final replacement = _diacriticMap[rune];
    if (replacement != null) {
      buf.write(replacement);
    } else if (!_isCombiningMark(rune)) {
      buf.writeCharCode(rune);
    }
  }
  return buf.toString();
}

bool _isAscii(String s) {
  for (final c in s.codeUnits) {
    if (c > 0x7F) return false;
  }
  return true;
}

bool _isCombiningMark(int rune) {
  // U+0300..U+036F: common combining diacritics. Covers accents applied to
  // NFD-decomposed Latin text. Good enough for song metadata.
  return rune >= 0x0300 && rune <= 0x036F;
}

// Precomposed-form fallback for common diacritics that servers may send
// without NFD decomposition. Kept small on purpose — expand only as needed.
const Map<int, String> _diacriticMap = {
  0x00C0: 'a', 0x00C1: 'a', 0x00C2: 'a', 0x00C3: 'a', 0x00C4: 'a', 0x00C5: 'a',
  0x00C6: 'ae', 0x00C7: 'c',
  0x00C8: 'e', 0x00C9: 'e', 0x00CA: 'e', 0x00CB: 'e',
  0x00CC: 'i', 0x00CD: 'i', 0x00CE: 'i', 0x00CF: 'i',
  0x00D1: 'n',
  0x00D2: 'o', 0x00D3: 'o', 0x00D4: 'o', 0x00D5: 'o', 0x00D6: 'o', 0x00D8: 'o',
  0x00D9: 'u', 0x00DA: 'u', 0x00DB: 'u', 0x00DC: 'u',
  0x00DD: 'y',
  0x00DF: 'ss',
  0x00E0: 'a', 0x00E1: 'a', 0x00E2: 'a', 0x00E3: 'a', 0x00E4: 'a', 0x00E5: 'a',
  0x00E6: 'ae', 0x00E7: 'c',
  0x00E8: 'e', 0x00E9: 'e', 0x00EA: 'e', 0x00EB: 'e',
  0x00EC: 'i', 0x00ED: 'i', 0x00EE: 'i', 0x00EF: 'i',
  0x00F1: 'n',
  0x00F2: 'o', 0x00F3: 'o', 0x00F4: 'o', 0x00F5: 'o', 0x00F6: 'o', 0x00F8: 'o',
  0x00F9: 'u', 0x00FA: 'u', 0x00FB: 'u', 0x00FC: 'u',
  0x00FD: 'y', 0x00FF: 'y',
  0x0141: 'l', 0x0142: 'l',
};
