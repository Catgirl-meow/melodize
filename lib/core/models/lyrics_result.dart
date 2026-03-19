class LyricsResult {
  final String? plain;
  final String? synced;

  const LyricsResult({this.plain, this.synced});

  bool get hasSynced => synced != null && synced!.isNotEmpty;
  bool get hasPlain => plain != null && plain!.isNotEmpty;

  List<LyricLine> get syncedLines {
    if (synced == null) return [];
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
          final text = match.group(4) ?? '';
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
