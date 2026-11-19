import 'package:flutter_test/flutter_test.dart';
import 'package:melodize/core/library/artist_profile.dart';
import 'package:melodize/core/models/album.dart';
import 'package:melodize/core/models/artist_info.dart';
import 'package:melodize/core/models/song.dart';
import 'package:melodize/features/library/artist/artist_songs_screen.dart';

Album album(String name,
        {int songs = 10,
        int duration = 2400,
        int? year,
        String? genre,
        List<String> types = const [],
        bool? compilation}) =>
    Album(
      id: name,
      name: name,
      artist: 'A',
      songCount: songs,
      duration: duration,
      year: year,
      genre: genre,
      releaseTypes: types,
      isCompilation: compilation,
    );

Song song(String id,
        {String? title, String album = 'X', int? plays, int? year}) =>
    Song(
      id: id,
      title: title ?? id,
      artist: 'A',
      album: album,
      playCount: plays,
      year: year,
    );

PlayRecord play(String songId, String artist, DateTime at,
        {String? title}) =>
    (
      songId: songId,
      title: title ?? songId,
      artist: artist,
      coverArt: null,
      playedAt: at,
    );

void main() {
  group('releaseKindOf', () {
    test('uses tag release types first', () {
      expect(releaseKindOf(album('a', songs: 2, types: ['Album'])),
          ReleaseKind.album);
      expect(releaseKindOf(album('a', types: ['ep'])), ReleaseKind.ep);
      expect(releaseKindOf(album('a', types: ['single'])), ReleaseKind.single);
      expect(releaseKindOf(album('a', types: ['album', 'compilation'])),
          ReleaseKind.compilation);
      expect(releaseKindOf(album('a', compilation: true)),
          ReleaseKind.compilation);
    });

    test('falls back to the track count', () {
      expect(releaseKindOf(album('a', songs: 1)), ReleaseKind.single);
      expect(releaseKindOf(album('a', songs: 3)), ReleaseKind.single);
      expect(releaseKindOf(album('a', songs: 4)), ReleaseKind.ep);
      expect(releaseKindOf(album('a', songs: 6)), ReleaseKind.ep);
      expect(releaseKindOf(album('a', songs: 7)), ReleaseKind.album);
      expect(releaseKindOf(album('a', songs: 0)), ReleaseKind.album);
    });
  });

  group('discography', () {
    final albums = [
      album('Bravo', year: 2020),
      album('alpha', year: 2024),
      album('Undated'),
      album('Low Tide', songs: 5, year: 2022),
      album('Hits', compilation: true, year: 2023),
    ];

    test('newest first, undated last', () {
      expect(discography(albums).map((a) => a.name),
          ['alpha', 'Hits', 'Low Tide', 'Bravo', 'Undated']);
    });

    test('oldest first keeps undated last', () {
      expect(
          discography(albums, sort: DiscographySort.oldest)
              .map((a) => a.name),
          ['Bravo', 'Low Tide', 'Hits', 'alpha', 'Undated']);
    });

    test('A-Z ignores case', () {
      expect(
          discography(albums, sort: DiscographySort.title)
              .map((a) => a.name),
          ['alpha', 'Bravo', 'Hits', 'Low Tide', 'Undated']);
    });

    test('filters and counts by release type', () {
      expect(
          discography(albums, filter: DiscographyFilter.epsAndSingles)
              .map((a) => a.name),
          ['Low Tide']);
      expect(discographyCounts(albums), {
        DiscographyFilter.all: 5,
        DiscographyFilter.albums: 3,
        DiscographyFilter.epsAndSingles: 1,
        DiscographyFilter.compilations: 1,
      });
    });
  });

  test('artistTotals sums albums and ranks genres by songs', () {
    final t = artistTotals([
      album('a', songs: 10, duration: 3600, genre: 'Rock; Indie'),
      album('b', songs: 4, duration: 900, genre: 'indie'),
      album('c', songs: 2, duration: 300, genre: 'Jazz'),
    ]);
    expect(t.releases, 3);
    expect(t.songs, 16);
    expect(t.duration, const Duration(seconds: 4800));
    expect(t.genres, ['Indie', 'Rock']);
    expect(formatRuntime(t.duration), '1 h 20 min');
    expect(formatRuntime(const Duration(minutes: 45)), '45 min');
    expect(formatRuntime(const Duration(hours: 2)), '2 h');
  });

  test('latestRelease only within this year and last', () {
    final now = DateTime(2026, 11, 19);
    expect(
        latestRelease([album('old', year: 2020), album('new', year: 2025)],
                now: now)
            ?.name,
        'new');
    expect(latestRelease([album('old', year: 2024)], now: now), isNull);
    expect(latestRelease([album('undated')], now: now), isNull);
  });

  group('listeningStats', () {
    final now = DateTime(2026, 11, 19);
    final history = [
      play('s1', 'Nova Lyra', now.subtract(const Duration(days: 1))),
      play('s1', 'nova lyra', now.subtract(const Duration(days: 2))),
      play('s2', 'Nova Lyra', DateTime(2024, 3, 2)),
      play('x', 'Other', now.subtract(const Duration(days: 3))),
      play('x', 'Other', now.subtract(const Duration(days: 4))),
      play('x', 'Other', now.subtract(const Duration(days: 5))),
      play('y', 'Third', now.subtract(const Duration(days: 5))),
    ];

    test('counts plays, first play, top song and monthly rank', () {
      final s = listeningStats('Nova Lyra', history, now: now)!;
      expect(s.plays, 3);
      expect(s.firstPlayed, DateTime(2024, 3, 2));
      expect(s.topSong.songId, 's1');
      expect(s.topSong.plays, 2);
      expect(s.monthRank, 2); // Other has 3 plays this month, Nova Lyra 2.
    });

    test('null below the minimum', () {
      expect(listeningStats('Third', history, now: now), isNull);
    });

    test('no rank when not played this month', () {
      final s = listeningStats(
          'Old',
          [
            for (var i = 0; i < 3; i++) play('o', 'Old', DateTime(2020, 1, i + 1)),
          ],
          now: now)!;
      expect(s.monthRank, isNull);
    });
  });

  group('popularFromPlays', () {
    test('prefers server play counts', () {
      final r = popularFromPlays(
          [song('a', plays: 1), song('b', plays: 9), song('c')], const []);
      expect(r.source, PopularSource.serverPlays);
      expect(r.songs.map((s) => s.id), ['b', 'a']);
    });

    test('falls back to local plays and skips unplayed songs', () {
      final at = DateTime(2026);
      final r = popularFromPlays([song('a'), song('b'), song('c')], [
        play('b', 'A', at),
        play('b', 'A', at),
        play('a', 'A', at),
      ]);
      expect(r.source, PopularSource.yourPlays);
      expect(r.songs.map((s) => s.id), ['b', 'a']);
    });
  });

  group('buildArtistRadio', () {
    final own = [for (var i = 0; i < 6; i++) song('own$i')];
    final sim1 = [for (var i = 0; i < 3; i++) song('s1-$i')];
    final sim2 = [for (var i = 0; i < 3; i++) song('s2-$i')];

    test('two of the artist, then one similar song in turn', () {
      final q = buildArtistRadio(own, [sim1, sim2], seed: 1);
      final pattern =
          q.take(9).map((s) => s.id.startsWith('own') ? 'o' : 's').join();
      expect(pattern, 'oosoosoos');
      // Similar artists alternate.
      final similar = q.where((s) => !s.id.startsWith('own')).toList();
      expect(similar[0].id.substring(0, 2), isNot(similar[1].id.substring(0, 2)));
    });

    test('uses every song once and respects the caps', () {
      final q = buildArtistRadio(own, [sim1, sim2],
          ownCount: 4, perSimilar: 2, seed: 3);
      expect(q.length, 8);
      expect(q.map((s) => s.id).toSet().length, 8);
    });

    test('works with no similar artists', () {
      expect(buildArtistRadio(own, const [], seed: 2).length, 6);
    });
  });

  group('ArtistInfo', () {
    test('parses getArtistInfo2 and strips the Last.fm link', () {
      final info = ArtistInfo.fromSubsonicJson({
        'biography':
            'Nova Lyra is a <b>dream pop</b> act &amp; more.<br/>Second line. '
                '<a target="_blank" href="https://www.last.fm/music/x">'
                'Read more on Last.fm</a>. User-contributed text…',
        'lastFmUrl': 'https://www.last.fm/music/x',
        'musicBrainzId': 'mbid-1',
        'smallImageUrl': 'http://s',
        'largeImageUrl': 'http://l',
        'similarArtist': [
          {'id': 'ar-2', 'name': 'Velvet Harbor', 'albumCount': 3},
          {'name': 'Sora Kites'},
          {'name': ''},
        ],
      });
      expect(info.biography,
          'Nova Lyra is a dream pop act & more.\nSecond line.');
      expect(info.imageUrl, 'http://l');
      expect(info.musicBrainzId, 'mbid-1');
      expect(info.similar.map((s) => s.name), ['Velvet Harbor', 'Sora Kites']);
      expect(info.similar.first.inLibrary, isTrue);
      expect(info.similar.last.inLibrary, isFalse);
    });

    test('empty biography is null', () {
      expect(cleanBiography(' <a href="x">Read more on Last.fm</a>'), isNull);
      expect(cleanBiography(null), isNull);
    });
  });

  test('Album and Song read OpenSubsonic fields', () {
    final a = Album.fromSubsonicJson({
      'id': 1,
      'name': 'N',
      'releaseTypes': ['EP'],
      'isCompilation': false,
      'playCount': 12,
    });
    expect(a.releaseTypes, ['EP']);
    expect(a.isCompilation, isFalse);
    expect(a.playCount, 12);
    expect(Song.fromSubsonicJson({'id': 1, 'playCount': 4}).playCount, 4);
    expect(Song.fromSubsonicJson({'id': 1}).copyWith(isDownloaded: true),
        isA<Song>());
  });

  group('arrangeArtistSongs', () {
    final songs = [
      song('1', title: 'Beta', album: 'One', year: 2020, plays: 1),
      song('2', title: 'alpha', album: 'Two', year: 2024),
      song('3', title: 'Gamma', album: 'One', year: 2020, plays: 5),
    ];

    test('search matches title or album', () {
      expect(arrangeArtistSongs(songs, query: 'two').map((s) => s.id), ['2']);
      expect(arrangeArtistSongs(songs, query: 'gam').map((s) => s.id), ['3']);
    });

    test('orders', () {
      expect(
          arrangeArtistSongs(songs, order: ArtistSongsOrder.title)
              .map((s) => s.id),
          ['2', '1', '3']);
      expect(
          arrangeArtistSongs(songs,
              order: ArtistSongsOrder.mostPlayed,
              plays: {'2': 3}).map((s) => s.id),
          ['3', '2', '1']);
      expect(
          arrangeArtistSongs(songs, order: ArtistSongsOrder.newest).first.id,
          '2');
      expect(
          arrangeArtistSongs(songs,
              order: ArtistSongsOrder.downloaded,
              downloaded: {'3'}).map((s) => s.id),
          ['3']);
    });
  });
}
