// Walks every main screen with the long-name test library loaded (see
// scripts/gen-test-library.sh, "Long Names") and fails on any layout
// overflow ("A RenderFlex overflowed ..."), which is what hard-clipped text
// looks like to Flutter. With --dart-define=SHOT_URL=http://host:port it
// calls GET <SHOT_URL>/<stop-name> at each stop and waits for the reply, so a
// small server on the host can take a screenshot in sync (adb exec-out
// screencap for Android, grim for the Linux sandbox).
//
//   ./flutter/bin/flutter test integration_test/text_overflow_tour_test.dart \
//     -d linux --dart-define=ND_URL=http://localhost:4534 \
//     --dart-define=ND_USER=test --dart-define=ND_PASS=...
//
// As with the smoke test, point XDG_DATA_HOME/CONFIG/CACHE at an empty folder
// on Linux; on Android clear the app's data first (`adb shell pm clear`).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:melodize/features/player/mini_player.dart';
import 'package:melodize/features/shell/main_shell.dart';
import 'package:melodize/main.dart' as app;

import 'test_server_smoke_test.dart' show pumpUntil, fillSetup;

const _url = String.fromEnvironment('ND_URL');
const _user = String.fromEnvironment('ND_USER');
const _pass = String.fromEnvironment('ND_PASS');
const _shotUrl = String.fromEnvironment('SHOT_URL');

const _longSong = 'This Is a Very Long Song Title';
const _longAlbum = 'A Collection of Songs Whose Titles';
const _longArtist = 'The Extraordinarily Long-Named';
const _longArtistFull =
    'The Extraordinarily Long-Named Philharmonic Orchestra of Unnecessarily Verbose Titles';
const _longPlaylist = 'My Absolutely Enormous';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('no text overflows on any screen', (tester) async {
    expect(_url, isNotEmpty, reason: 'pass --dart-define=ND_URL=...');
    final overflows = <String>[];
    var stop = 'startup';
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      final msg = details.exceptionAsString();
      if (msg.contains('overflowed')) {
        final line = '[$stop] ${msg.split('\n').first}';
        overflows.add(line);
        debugPrint('OVERFLOW $line');
        // Name the widget that overflowed, not just the stop.
        final where = details.toString().split('\n').where(
            (l) => l.contains('file:///') || l.contains('creator:'));
        for (final l in where.take(3)) {
          debugPrint('  $l');
        }
      } else {
        original?.call(details);
      }
    };

    Future<void> shot(String name) async {
      stop = name;
      // Let images and animations land before the screenshot.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      debugPrint('SHOT $name');
      if (_shotUrl.isEmpty) return;
      final client = HttpClient();
      try {
        final req = await client.getUrl(Uri.parse('$_shotUrl/$name'));
        await (await req.close()).drain<void>();
      } finally {
        client.close();
      }
    }

    Future<void> tapText(String text) async {
      final f = find.textContaining(text);
      await pumpUntil(tester, f);
      await tester.ensureVisible(f.first);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(f.first, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 600));
    }

    Future<void> back() async {
      // Detail pages and sheets go on the root navigator, above the shell's
      // tab navigators, so pop that one first when it has something to pop.
      final navs = find.byType(Navigator).evaluate()
          .map((e) => (e as StatefulElement).state as NavigatorState)
          .toList();
      final root = navs.first;
      (root.canPop() ? root : navs.lastWhere((n) => n.canPop(),
              orElse: () => root))
          .maybePop();
      await tester.pump(const Duration(milliseconds: 800));
    }

    Future<void> tab(String label) async {
      await tester.tap(find.byTooltip(label).last);
      await tester.pump(const Duration(milliseconds: 800));
    }

    app.main();
    await pumpUntil(tester, find.byType(TextFormField));
    await fillSetup(tester, _url, _user, _pass);
    await pumpUntil(tester, find.byType(MainShell));

    // The user's layout: the classic bottom bar instead of the floating dock.
    await tab('Settings');
    final dock = find.widgetWithText(SwitchListTile, 'Floating navigation bar');
    await pumpUntil(tester, dock);
    if (tester.widget<SwitchListTile>(dock).value) {
      await tester.tap(dock);
      await tester.pump(const Duration(milliseconds: 600));
    }
    await shot('settings');

    await tab('Home');
    await pumpUntil(tester, find.textContaining(_longPlaylist));
    await shot('home');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
    await shot('home-scrolled');

    await tapText(_longPlaylist);
    await shot('playlist-detail');
    // Collapsed header.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
    await shot('playlist-detail-collapsed');
    await back();

    await tab('Library');
    await pumpUntil(tester, find.text('Songs'));
    await tester.scrollUntilVisible(find.textContaining('Another Painfully'), 200,
        scrollable: find.byType(Scrollable).last);
    await shot('library-songs');

    await tester.tap(find.text('Albums'));
    await tester.pump(const Duration(milliseconds: 800));
    await pumpUntil(tester, find.textContaining(_longAlbum));
    await shot('library-albums');
    await tapText(_longAlbum);
    await shot('album-detail');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
    await shot('album-detail-collapsed');
    await back();

    await tester.tap(find.text('Artists'));
    await tester.pump(const Duration(milliseconds: 800));
    await pumpUntil(tester, find.textContaining('Test Artist'));
    await tester.scrollUntilVisible(find.text(_longArtistFull), 200,
        scrollable: find.byType(Scrollable).last);
    await shot('library-artists');
    await tapText(_longArtist);
    await shot('artist-detail');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
    await shot('artist-detail-scrolled');
    await back();

    await tab('Search');
    await tester.enterText(find.byType(TextField).first, 'Long');
    await tester.pump(const Duration(seconds: 2));
    await pumpUntil(tester, find.textContaining(_longSong));
    await shot('search');

    // Song options sheet, then play the long song.
    final longRow = find.ancestor(
        of: find.textContaining(_longSong).first,
        matching: find.byType(ListTile));
    await tester.tap(find.descendant(
        of: longRow.first, matching: find.byIcon(Icons.more_vert_rounded)));
    await tester.pump(const Duration(milliseconds: 800));
    await shot('song-options');
    await back();
    await tapText(_longSong);
    await tester.pump(const Duration(seconds: 2));
    await pumpUntil(tester, find.byIcon(Icons.skip_next_rounded));
    final pause = find.byIcon(Icons.pause_rounded);
    if (pause.evaluate().isNotEmpty) await tester.tap(pause.first);
    await shot('mini-player');

    // Now Playing: open it from the mini player title.
    await tester.tap(find
        .descendant(of: find.byType(MiniPlayer), matching: find.byType(Text))
        .first);
    await tester.pump(const Duration(seconds: 1));
    await shot('now-playing');
    await tester.tap(find.text('Queue'));
    await tester.pump(const Duration(seconds: 1));
    await shot('queue');
    await back();
    await tester.tap(find.byIcon(Icons.more_vert_rounded).last);
    await tester.pump(const Duration(milliseconds: 800));
    await shot('now-playing-options');
    await back();
    await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded).last);
    await tester.pump(const Duration(seconds: 1));

    await tab('Settings');
    await tapText('Library server');
    await shot('settings-server');
    await back();

    FlutterError.onError = original;
    if (overflows.isNotEmpty) {
      fail('Layout overflows:\n${overflows.join('\n')}');
    }
  });
}
