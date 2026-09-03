class LyricsResult {
  final String? plain;
  final String? synced;

  LyricsResult({this.plain, this.synced});

  bool get hasSynced => syncedLines.isNotEmpty;
  bool get hasPlain => plain != null && plain!.trim().isNotEmpty;
  bool get isUsable => hasSynced || hasPlain;

  List<LyricLine>? _parsedSynced;

  /// Parsed [synced] lines. The parse result is cached on first access so
  /// callers can rely on instance identity (e.g. `identical()` comparisons
  /// guarding key regeneration) instead of re-parsing the LRC text on every
  /// read.
  List<LyricLine> get syncedLines => _parsedSynced ??= _parseSyncedLines();

  List<LyricLine> _parseSyncedLines() {
    if (synced == null) return const [];
    final lines = synced!.split('\n');
    final result = <LyricLine>[];
    final pattern = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\]\s*(.*)');
    for (final line in lines) {
      final match = pattern.firstMatch(line);
      if (match != null) {
        try {
          final min = int.parse(match.group(1)!);
          final sec = int.parse(match.group(2)!);
          final hundredths = match.group(3)!.padRight(3, '0').substring(0, 3);
          final ms = int.parse(hundredths);
          final text = (match.group(4) ?? '').trim();
          if (text.isEmpty) continue;
          result.add(LyricLine(
            timestamp: Duration(minutes: min, seconds: sec, milliseconds: ms),
            text: text,
          ));
        } on FormatException {
          // Skip malformed timestamp lines
        }
      }
    }
    result.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return result;
  }
}

class LyricLine {
  final Duration timestamp;
  final String text;
  const LyricLine({required this.timestamp, required this.text});
}
