// Home's recommendation row: plain cards like every other row (the "why",
// like and "Not interested" live in the player), and a song hidden from the
// player leaving the row at once, Undo bringing it back.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:melodize/core/api/subsonic_client.dart';
import 'package:melodize/core/db/database.dart';
import 'package:melodize/core/models/app_preferences.dart';
import 'package:melodize/core/models/recommendations_state.dart';
import 'package:melodize/core/models/song.dart';
import 'package:melodize/core/providers.dart';
import 'package:melodize/core/recs/taste_model.dart';
import 'package:melodize/features/home/home_screen.dart';

void main() {
  testWidgets('plain cards; a hidden song leaves the row, Undo brings it back',
      (tester) async {
    tester.view.physicalSize = const Size(500, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    Song rec(int id, String title, String artist) => Song.fromRecommendation(
        deezerId: id, title: title, artist: artist, album: 'A',
        durationSeconds: 200);
    final songs = [
      rec(1, 'Neon Harbor', 'Lumen Drift'),
      rec(2, 'Low Orbit', 'Satellite Ghosts'),
    ];
    const seed = TasteSeed('Kaito Ren', SeedReason.liked, 5);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        isOnlineProvider.overrideWith((_) => Stream.value(true)),
        subsonicClientProvider.overrideWithValue(SubsonicClient(
            const SubsonicConfig(
                serverUrl: 'http://127.0.0.1:9',
                username: 'u',
                password: 'p'))),
        deezerArlStatusProvider
            .overrideWith((_) async => DeezerArlStatus.unreachable),
        downloadedPathsProvider.overrideWithValue(const {}),
        preferencesNotifierProvider.overrideWith(
            (_) => PreferencesNotifier.inMemory(const AppPreferences())),
        recommendationsProvider.overrideWith((_) async => RecsReady(songs,
            reasons: {for (final s in songs) s.id: seed},
            failedSeeds: const ['Orbit Theory'])),
      ],
      child: const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: Size(500, 1600)),
          child: Scaffold(body: HomeScreen()),
        ),
      ),
    ));
    Future<void> settle() async {
      for (var i = 0; i < 5; i++) {
        await tester
            .runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 300));
      }
    }

    await settle();
    expect(find.text('Neon Harbor'), findsOneWidget);
    // Nothing on the covers any more: no menu, reason or preview badge.
    expect(find.byIcon(Icons.more_vert_rounded), findsNothing);
    expect(find.text('You like Kaito Ren'), findsNothing);
    expect(find.text('PREVIEW'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Play'), findsOneWidget);
    expect(find.textContaining('based on Orbit Theory'), findsOneWidget);

    // "Not interested" in the player writes the row; Home drops the card.
    final key = dismissedTrackKey('Neon Harbor', 'Lumen Drift');
    await tester.runAsync(() => db.addDismissedRec(
        DismissedRecsCompanion.insert(
            key: key, kind: 'track', artist: 'Lumen Drift',
            title: const Value('Neon Harbor'))));
    await settle();
    expect(find.text('Neon Harbor'), findsNothing);
    expect(find.text('Low Orbit'), findsOneWidget);

    await tester.runAsync(() => db.removeDismissedRec(key));
    await settle();
    expect(find.text('Neon Harbor'), findsOneWidget);

    // Drift closes its query streams on a zero-length timer; let it run.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
