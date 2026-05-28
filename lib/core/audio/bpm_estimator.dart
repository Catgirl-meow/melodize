// Genre-average BPM ranges. Used as a fallback when no real BPM data exists.

// Returns an estimated BPM range [low, high] for a genre, or null.
({double low, double high})? bpmRangeForGenre(String? genre) {
  if (genre == null || genre.trim().isEmpty) return null;
  final g = genre.trim().toLowerCase();

  // genre → [min, max] BPM ranges.
  const ranges = <String, ({double low, double high})>{
    'rock': (low: 110, high: 140),
    'alternative': (low: 100, high: 140),
    'indie': (low: 100, high: 130),
    'punk': (low: 140, high: 200),
    'hard rock': (low: 120, high: 180),
    'classic rock': (low: 100, high: 140),
    'progressive rock': (low: 100, high: 150),
    'pop': (low: 100, high: 130),
    'synth-pop': (low: 100, high: 130),
    'k-pop': (low: 100, high: 140),
    'j-pop': (low: 100, high: 140),
    'dance-pop': (low: 110, high: 140),
    'hip-hop': (low: 80, high: 115),
    'rap': (low: 80, high: 115),
    'trap': (low: 60, high: 100),
    'r&b': (low: 60, high: 100),
    'soul': (low: 60, high: 100),
    'funk': (low: 90, high: 120),
    'electronic': (low: 120, high: 150),
    'edm': (low: 120, high: 150),
    'house': (low: 120, high: 130),
    'techno': (low: 120, high: 150),
    'trance': (low: 130, high: 150),
    'dubstep': (low: 70, high: 90),
    'drum and bass': (low: 160, high: 180),
    'ambient': (low: 50, high: 90),
    'downtempo': (low: 60, high: 100),
    'lofi': (low: 60, high: 90),
    'jazz': (low: 60, high: 120),
    'classical': (low: 60, high: 120),
    'orchestral': (low: 60, high: 120),
    'metal': (low: 140, high: 200),
    'death metal': (low: 150, high: 200),
    'black metal': (low: 140, high: 180),
    'doom metal': (low: 60, high: 90),
    'country': (low: 70, high: 110),
    'folk': (low: 80, high: 120),
    'bluegrass': (low: 100, high: 140),
    'latin': (low: 100, high: 140),
    'reggaeton': (low: 80, high: 110),
    'salsa': (low: 150, high: 220),
    'bossa nova': (low: 100, high: 140),
    'blues': (low: 60, high: 100),
    'reggae': (low: 60, high: 90),
    'ska': (low: 120, high: 160),
    'gospel': (low: 80, high: 140),
    'christian': (low: 70, high: 130),
    'new age': (low: 50, high: 90),
    'world': (low: 80, high: 140),
    'soundtrack': (low: 60, high: 140),
    'comedy': (low: 80, high: 140),
  };

  // Exact match first
  final exact = ranges[g];
  if (exact != null) return exact;

  // Partial match: check if the genre contains any known keyword
  for (final entry in ranges.entries) {
    if (g.contains(entry.key)) return entry.value;
  }

  return null;
}

// Best-effort BPM estimate for a song based on genre. Returns null when
// the genre is unknown so callers can skip BPM constraints.
int? estimateBpm(String? genre) {
  final range = bpmRangeForGenre(genre);
  if (range == null) return null;
  final mid = ((range.low + range.high) / 2).round();
  // Round to nearest 5 for a cleaner estimate
  return (mid / 5).round() * 5;
}
