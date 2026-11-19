import 'dart:math';

import '../models/album.dart';
import '../models/song.dart';
import '../utils/title_normalize.dart';

/// Pure helpers behind the artist page: release grouping, totals, the
/// listening card and the radio queue. Kept free of Flutter and Riverpod so
/// they can be unit-tested.

// ---------------------------------------------------------------------------
// Release types

enum ReleaseKind { album, ep, single, compilation }

extension ReleaseKindLabel on ReleaseKind {
  String get label => switch (this) {
        ReleaseKind.album => 'Album',
        ReleaseKind.ep => 'EP',
        ReleaseKind.single => 'Single',
        ReleaseKind.compilation => 'Compilation',
      };
}

/// The release type of [album]. Uses the server's tag-based release types
/// when present; otherwise guesses from the track count (1–3 single, 4–6 EP).
ReleaseKind releaseKindOf(Album album) {
  final types = album.releaseTypes.map((t) => t.toLowerCase().trim()).toSet();
  if (album.isCompilation == true || types.contains('compilation')) {
    return ReleaseKind.compilation;
  }
  if (types.contains('single')) return ReleaseKind.single;
  if (types.contains('ep')) return ReleaseKind.ep;
  if (types.contains('album')) return ReleaseKind.album;
  if (album.songCount > 0 && album.songCount <= 3) return ReleaseKind.single;
  if (album.songCount >= 4 && album.songCount <= 6) return ReleaseKind.ep;
  return ReleaseKind.album;
}

/// Filter chips on the discography.
enum DiscographyFilter { all, albums, epsAndSingles, compilations }

extension DiscographyFilterLabel on DiscographyFilter {
  String get label => switch (this) {
        DiscographyFilter.all => 'All',
        DiscographyFilter.albums => 'Albums',
        DiscographyFilter.epsAndSingles => 'EPs & singles',
        DiscographyFilter.compilations => 'Compilations',
      };

  bool matches(ReleaseKind kind) => switch (this) {
        DiscographyFilter.all => true,
        DiscographyFilter.albums => kind == ReleaseKind.album,
        DiscographyFilter.epsAndSingles =>
          kind == ReleaseKind.ep || kind == ReleaseKind.single,
        DiscographyFilter.compilations => kind == ReleaseKind.compilation,
      };
}

enum DiscographySort { newest, oldest, title }

extension DiscographySortLabel on DiscographySort {
  String get label => switch (this) {
        DiscographySort.newest => 'Newest',
        DiscographySort.oldest => 'Oldest',
        DiscographySort.title => 'A–Z',
      };
}

/// [albums] filtered and sorted for the discography. Albums without a year
/// sort after dated ones in both date orders.
List<Album> discography(
  List<Album> albums, {
  DiscographyFilter filter = DiscographyFilter.all,
  DiscographySort sort = DiscographySort.newest,
}) {
  final list = albums.where((a) => filter.matches(releaseKindOf(a))).toList();
  int byTitle(Album a, Album b) =>
      a.name.toLowerCase().compareTo(b.name.toLowerCase());
  switch (sort) {
    case DiscographySort.title:
      list.sort(byTitle);
    case DiscographySort.newest:
    case DiscographySort.oldest:
      final dir = sort == DiscographySort.newest ? -1 : 1;
      list.sort((a, b) {
        if (a.year == null && b.year == null) return byTitle(a, b);
        if (a.year == null) return 1;
        if (b.year == null) return -1;
        final c = a.year!.compareTo(b.year!) * dir;
        return c != 0 ? c : byTitle(a, b);
      });
  }
  return list;
}

/// Count per filter, for the chip labels.
Map<DiscographyFilter, int> discographyCounts(List<Album> albums) => {
      for (final f in DiscographyFilter.values)
        f: albums.where((a) => f.matches(releaseKindOf(a))).length,
    };

// ---------------------------------------------------------------------------
// Header facts

class ArtistTotals {
  final int releases;
  final int songs;
  final Duration duration;
  final List<String> genres;

  const ArtistTotals({
    required this.releases,
    required this.songs,
    required this.duration,
    required this.genres,
  });
}

/// Release, song and runtime totals plus the top [maxGenres] genres, all
/// from album data, so the header needs no per-album requests.
ArtistTotals artistTotals(List<Album> albums, {int maxGenres = 2}) {
  final genreCounts = <String, int>{};
  final display = <String, String>{};
  for (final a in albums) {
    for (final g in (a.genre ?? '').split(RegExp(r'[;/,]'))) {
      final t = g.trim();
      if (t.isEmpty) continue;
      final key = t.toLowerCase();
      display.putIfAbsent(key, () => t);
      genreCounts[key] = (genreCounts[key] ?? 0) + max(1, a.songCount);
    }
  }
  final genres = genreCounts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return ArtistTotals(
    releases: albums.length,
    songs: albums.fold(0, (n, a) => n + a.songCount),
    duration: Duration(seconds: albums.fold(0, (n, a) => n + a.duration)),
    genres: [for (final e in genres.take(maxGenres)) display[e.key]!],
  );
}

/// "3 h 12 min", "45 min".
String formatRuntime(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  if (h == 0) return '$m min';
  return m == 0 ? '$h h' : '$h h $m min';
}

/// The newest release when it came out this year or last year, else null.
Album? latestRelease(List<Album> albums, {DateTime? now}) {
  final year = (now ?? DateTime.now()).year;
  Album? best;
  for (final a in albums) {
    final y = a.year;
    if (y == null || y < year - 1) continue;
    if (best == null || y > best.year!) best = a;
  }
  return best;
}

// ---------------------------------------------------------------------------
// Listening stats (from the local play history)

/// One play from the local history, reduced to what the stats need.
typedef PlayRecord = ({
  String songId,
  String title,
  String artist,
  String? coverArt,
  DateTime playedAt,
});

class ArtistListeningStats {
  final int plays;
  final DateTime firstPlayed;

  /// This artist's rank among all artists by plays in the last 30 days, or
  /// null when they weren't played in that window.
  final int? monthRank;
  final ({String songId, String title, String? coverArt, int plays}) topSong;

  const ArtistListeningStats({
    required this.plays,
    required this.firstPlayed,
    required this.monthRank,
    required this.topSong,
  });
}

/// Artist names as the history stores them, compared loosely.
bool sameArtist(String a, String b) => normalize(a) == normalize(b);

/// Stats for [artistName] from [history] (all plays, any order), or null
/// when there are fewer than [minPlays] plays of the artist.
ArtistListeningStats? listeningStats(
  String artistName,
  List<PlayRecord> history, {
  DateTime? now,
  int minPlays = 3,
}) {
  final mine = history.where((h) => sameArtist(h.artist, artistName)).toList();
  if (mine.length < minPlays) return null;

  final perSong = <String, int>{};
  final latestById = <String, PlayRecord>{};
  var first = mine.first.playedAt;
  for (final h in mine) {
    perSong[h.songId] = (perSong[h.songId] ?? 0) + 1;
    latestById.putIfAbsent(h.songId, () => h);
    if (h.playedAt.isBefore(first)) first = h.playedAt;
  }
  final top = perSong.entries.reduce((a, b) => b.value > a.value ? b : a);
  final topRec = latestById[top.key]!;

  final since = (now ?? DateTime.now()).subtract(const Duration(days: 30));
  final monthByArtist = <String, int>{};
  for (final h in history) {
    if (h.playedAt.isBefore(since)) continue;
    final key = normalize(h.artist);
    monthByArtist[key] = (monthByArtist[key] ?? 0) + 1;
  }
  final myMonth = monthByArtist[normalize(artistName)];
  final rank = myMonth == null
      ? null
      : 1 + monthByArtist.values.where((v) => v > myMonth).length;

  return ArtistListeningStats(
    plays: mine.length,
    firstPlayed: first,
    monthRank: rank,
    topSong: (
      songId: top.key,
      title: topRec.title,
      coverArt: topRec.coverArt,
      plays: top.value,
    ),
  );
}

// ---------------------------------------------------------------------------
// Popular songs

/// Where the Popular list came from, for its caption.
enum PopularSource { lastFm, serverPlays, yourPlays }

/// Up to [limit] of [songs] ranked by the server's play count, or by plays
/// in the local [history] when the server reports none. Songs never played
/// are left out.
({List<Song> songs, PopularSource source}) popularFromPlays(
  List<Song> songs,
  List<PlayRecord> history, {
  int limit = 5,
}) {
  final withServer = songs.where((s) => (s.playCount ?? 0) > 0).toList();
  if (withServer.isNotEmpty) {
    withServer.sort((a, b) => b.playCount!.compareTo(a.playCount!));
    return (
      songs: withServer.take(limit).toList(),
      source: PopularSource.serverPlays,
    );
  }
  final counts = <String, int>{};
  for (final h in history) {
    counts[h.songId] = (counts[h.songId] ?? 0) + 1;
  }
  final played = songs.where((s) => (counts[s.id] ?? 0) > 0).toList()
    ..sort((a, b) => counts[b.id]!.compareTo(counts[a.id]!));
  return (songs: played.take(limit).toList(), source: PopularSource.yourPlays);
}

// ---------------------------------------------------------------------------
// Artist radio

/// A radio queue: up to [ownCount] songs by the artist mixed with up to
/// [perSimilar] songs from each similar artist, two of the artist's songs
/// then one from the next similar artist in turn. Seeded so a test can pin
/// the order; the app passes a fresh seed per tap.
List<Song> buildArtistRadio(
  List<Song> artistSongs,
  List<List<Song>> similarSongs, {
  int ownCount = 25,
  int perSimilar = 8,
  int? seed,
}) {
  final rng = Random(seed);
  final own = ([...artistSongs]..shuffle(rng)).take(ownCount).toList();
  final others = [
    for (final list in similarSongs)
      if (list.isNotEmpty) ([...list]..shuffle(rng)).take(perSimilar).toList(),
  ];
  final out = <Song>[];
  final seen = <String>{};
  void add(Song s) {
    if (seen.add(s.id)) out.add(s);
  }

  var oi = 0;
  var turn = 0;
  final cursors = List.filled(others.length, 0);
  while (true) {
    var added = false;
    for (var k = 0; k < 2 && oi < own.length; k++) {
      add(own[oi++]);
      added = true;
    }
    for (var tries = 0; tries < others.length; tries++) {
      final i = (turn + tries) % others.length;
      if (cursors[i] < others[i].length) {
        add(others[i][cursors[i]++]);
        turn = i + 1;
        added = true;
        break;
      }
    }
    if (!added) break;
  }
  return out;
}
