// The artist page: which sections show for the data a server returns, the
// phone and desktop layouts, and the All songs page.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:melodize/core/api/subsonic_client.dart';
import 'package:melodize/core/db/database.dart';
import 'package:melodize/core/library/artist_profile.dart';
import 'package:melodize/core/models/album.dart';
import 'package:melodize/core/models/artist.dart';
import 'package:melodize/core/models/artist_info.dart';
import 'package:melodize/core/models/song.dart';
import 'package:melodize/core/providers.dart';
import 'package:melodize/features/library/artist/artist_songs_screen.dart';
import 'package:melodize/features/library/artist_detail_screen.dart';

const artist = Artist(id: 'ar1', name: 'Nova Lyra', albumCount: 3);

final thisYear = DateTime.now().year;

List<Album> albums() => [
      const Album(
          id: 'al1',
          name: 'Glasshouse',
          artist: 'Nova Lyra',
          songCount: 11,
          duration: 2700,
          year: 2022,
          genre: 'Dream Pop'),
      const Album(
          id: 'al2',
          name: 'Low Tide',
          artist: 'Nova Lyra',
          songCount: 4,
          duration: 900,
          year: 2021,
          releaseTypes: ['EP']),
      Album(
          id: 'al3',
          name: 'Afterglow',
          artist: 'Nova Lyra',
          songCount: 1,
          duration: 200,
          year: thisYear),
    ];

const songs = [
  Song(id: 's1', title: 'Glasshouse Heart', artist: 'Nova Lyra', album: 'Glasshouse'),
  Song(id: 's2', title: 'Undertow', artist: 'Nova Lyra', album: 'Low Tide'),
  Song(id: 's3', title: 'Afterglow', artist: 'Nova Lyra', album: 'Afterglow'),
];

List<PlayRecord> history() {
  final now = DateTime.now();
  return [
    for (var i = 0; i < 4; i++)
      (
        songId: 's1',
        title: 'Glasshouse Heart',
        artist: 'Nova Lyra',
        coverArt: null,
        playedAt: now.subtract(Duration(days: i + 1)),
      ),
    (
      songId: 's2',
      title: 'Undertow',
      artist: 'Nova Lyra',
      coverArt: null,
      playedAt: now.subtract(const Duration(days: 2)),
    ),
  ];
}

Future<void> pumpArtist(WidgetTester tester, Size size,
    {ArtistInfo info = const ArtistInfo(
      biography: 'Nova Lyra make dream pop.',
      lastFmUrl: 'https://www.last.fm/music/Nova+Lyra',
      similar: [
        SimilarArtist(id: 'ar2', name: 'Velvet Harbor', albumCount: 2),
        SimilarArtist(name: 'Sora Kites'),
      ],
    )}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);

  await tester.pumpWidget(ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      isOnlineProvider.overrideWith((_) => Stream.value(true)),
      subsonicClientProvider.overrideWithValue(SubsonicClient(
          const SubsonicConfig(
              serverUrl: 'http://127.0.0.1:9', username: 'u', password: 'p'))),
      downloadedPathsProvider.overrideWithValue(const {}),
      artistAlbumsProvider(artist.id).overrideWith((_) async => albums()),
      // No Last.fm on this server: Popular comes from your plays.
      artistTopSongsProvider(artist.name).overrideWith((_) async => const []),
      artistAllSongsProvider(artist.id).overrideWith((_) async => songs),
      artistInfoProvider(artist.id).overrideWith((_) async => info),
      deezerArtistIdProvider(artist.name).overrideWith((_) async => null),
      playRecordsProvider.overrideWith((_) async => history()),
    ],
    child: const MaterialApp(home: ArtistDetailScreen(artist: artist)),
  ));
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('phone layout shows every section that has data',
      (tester) async {
    await pumpArtist(tester, const Size(412, 4000));

    expect(find.text('Nova Lyra'), findsWidgets);
    expect(find.text('3 releases · 16 songs · 1 h 3 min'), findsOneWidget);
    expect(find.text('Dream Pop'), findsOneWidget);
    expect(find.byTooltip('Artist radio'), findsOneWidget);

    // Your listening: 5 plays, most played song.
    expect(find.text('Your listening'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.textContaining('Glasshouse Heart · 4 plays'), findsOneWidget);

    // Popular falls back to your plays instead of disappearing.
    expect(find.text('Popular'), findsOneWidget);
    expect(find.text('Your plays'), findsOneWidget);

    expect(find.text('Latest release'), findsOneWidget);
    expect(find.text('Discography'), findsOneWidget);
    expect(find.text('Albums 1'), findsOneWidget);
    expect(find.text('EPs & singles 2'), findsOneWidget);

    expect(find.text('Fans also like'), findsOneWidget);
    expect(find.text('Velvet Harbor'), findsOneWidget);
    expect(find.text('Sora Kites'), findsOneWidget);

    expect(find.text('About'), findsOneWidget);
    expect(find.text('Nova Lyra make dream pop.'), findsOneWidget);
    expect(find.text('Last.fm'), findsOneWidget);
    expect(find.text('All songs'), findsOneWidget);

    // The full song list is no longer inline.
    expect(find.text('Undertow'), findsOneWidget); // only in Popular
    expect(find.text('Not in your library'), findsNothing); // no Deezer match
  });

  testWidgets('sections without data stay hidden', (tester) async {
    await pumpArtist(tester, const Size(412, 4000), info: ArtistInfo.empty);
    expect(find.text('About'), findsNothing);
    expect(find.text('Fans also like'), findsNothing);
    expect(find.textContaining("Couldn't"), findsNothing);
  });

  testWidgets('discography filter narrows the releases', (tester) async {
    await pumpArtist(tester, const Size(412, 4000));
    // The test font is wide, so the chip row scrolls.
    await tester.ensureVisible(find.text('EPs & singles 2'));
    await tester.tap(find.text('EPs & singles 2'));
    await tester.pump();
    // Grid for two or fewer releases, so both titles render.
    expect(find.text('Low Tide'), findsWidgets);
    expect(find.text('Glasshouse'), findsNothing);
  });

  testWidgets('wide layout splits into identity pane and content',
      (tester) async {
    await pumpArtist(tester, const Size(1280, 1600));
    final name = tester.getRect(find.text('Nova Lyra').first);
    final popular = tester.getRect(find.text('Popular'));
    expect(name.right, lessThan(400));
    expect(popular.left, greaterThan(380));
    expect(find.text('Latest release'), findsOneWidget);
    expect(find.text('Discography'), findsOneWidget);
  });

  testWidgets('All songs opens a searchable list', (tester) async {
    await pumpArtist(tester, const Size(412, 4000));
    await tester.tap(find.text('All songs'));
    await tester.pumpAndSettle();
    expect(find.byType(ArtistSongsScreen), findsOneWidget);
    expect(find.text('Afterglow'), findsWidgets);
    await tester.enterText(find.byType(SearchBar), 'under');
    await tester.pump();
    expect(find.text('Undertow'), findsOneWidget);
    expect(find.text('Glasshouse Heart'), findsNothing);
  });
}
