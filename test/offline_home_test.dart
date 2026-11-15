// Offline Home: one offline banner, the downloaded songs, and none of the
// stacked "can't reach server / Deezer" errors.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:melodize/core/api/subsonic_client.dart';
import 'package:melodize/core/db/database.dart';
import 'package:melodize/core/providers.dart';
import 'package:melodize/features/home/home_screen.dart';
import 'package:melodize/shared/widgets/offline_banner.dart';

void main() {
  testWidgets('offline Home shows downloads and no stacked errors',
      (tester) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.runAsync(() => db.upsertSongs([
          const CachedSongsCompanion(
            id: Value('1'),
            title: Value('Saved Song'),
            artist: Value('Artist'),
            album: Value('Album'),
            isDownloaded: Value(true),
            localPath: Value('/nonexistent/1.flac'),
          ),
        ]));

    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        isOnlineProvider.overrideWith((_) => Stream.value(false)),
        subsonicClientProvider.overrideWithValue(SubsonicClient(
            const SubsonicConfig(
                serverUrl: 'http://127.0.0.1:9',
                username: 'u',
                password: 'p'))),
        deezerArlStatusProvider
            .overrideWith((_) async => DeezerArlStatus.unreachable),
        downloadedPathsProvider.overrideWithValue(const {}),
      ],
      child: const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
              size: Size(400, 1600), padding: EdgeInsets.only(top: 40)),
          child: Scaffold(body: HomeScreen()),
        ),
      ),
    ));
    for (var i = 0; i < 5; i++) {
      await tester
          .runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 500));
    }

    expect(find.text('Offline. Browse '), findsNothing); // part of a span
    expect(find.byType(OfflineBanner), findsOneWidget);
    expect(find.text('Downloaded'), findsOneWidget);
    expect(find.text('Saved Song'), findsOneWidget);
    expect(find.text('Recommended for You'), findsNothing);
    expect(find.textContaining("Can't reach Deezer"), findsNothing);
    expect(find.textContaining("Couldn't load"), findsNothing);

    // The banner sits below the status bar inset, not under it.
    final banner = tester.getRect(find.byType(OfflineBanner));
    expect(banner.top, greaterThanOrEqualTo(40));
  });
}
