// Drives the real app against a throwaway Navidrome server. Not part of the
// unit test run; start it on Linux with:
//
//   ./flutter/bin/flutter test integration_test -d linux \
//     --dart-define=ND_URL=http://localhost:4534 \
//     --dart-define=ND_USER=test --dart-define=ND_PASS=...
//
// It saves a server config and plays songs, so point XDG_DATA_HOME,
// XDG_CONFIG_HOME and XDG_CACHE_HOME at an empty folder to keep it away from
// your own setup.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:melodize/features/setup/setup_screen.dart';
import 'package:melodize/features/shell/main_shell.dart';
import 'package:melodize/main.dart' as app;

const _url = String.fromEnvironment('ND_URL');
const _user = String.fromEnvironment('ND_USER');
const _pass = String.fromEnvironment('ND_PASS');

// pumpAndSettle never settles while a progress indicator spins, so pump
// until the finder matches or the timeout passes.
Future<void> pumpUntil(WidgetTester tester, Finder finder,
    {Duration timeout = const Duration(seconds: 30)}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timed out waiting for $finder');
}

Future<void> fillSetup(WidgetTester tester, String url, String user,
    String pass) async {
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), url);
  await tester.enterText(fields.at(1), user);
  await tester.enterText(fields.at(2), pass);
  await tester.tap(find.text('Connect'));
  await tester.pump();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('setup, library, playback and server switch', (tester) async {
    expect(_url, isNotEmpty, reason: 'pass --dart-define=ND_URL=...');
    app.main();
    await pumpUntil(tester, find.byType(SetupScreen));

    // A non-http URL is caught by the form.
    await fillSetup(tester, 'ftp://example', _user, _pass);
    expect(find.text('URL must start with http:// or https://'),
        findsOneWidget);

    // A wrong password names the problem instead of "did not respond".
    await fillSetup(tester, _url, _user, 'definitely-wrong');
    await pumpUntil(tester, find.textContaining('password'));

    // A trailing slash and stray spaces are fine.
    await fillSetup(tester, '  $_url/ ', _user, _pass);
    await pumpUntil(tester, find.byType(MainShell));
    expect(find.byType(SetupScreen), findsNothing);

    // Library lists songs with odd names.
    await tester.tap(find.byTooltip('Library'));
    await pumpUntil(tester, find.text('Songs'));
    await pumpUntil(tester, find.textContaining('Rock'));

    // Play a song and skip through a few quickly.
    await tester.tap(find.textContaining('Rock').first);
    await tester.pump(const Duration(seconds: 2));
    await pumpUntil(tester, find.byIcon(Icons.skip_next_rounded));
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byIcon(Icons.skip_next_rounded).first);
      await tester.pump(const Duration(milliseconds: 150));
    }
    await tester.pump(const Duration(seconds: 2));
    // Pause so the rest of the run is quiet.
    await tester.tap(find.byIcon(Icons.pause_rounded).first);
    await tester.pump();

    // Settings → Library server → Remove missing files.
    await tester.tap(find.byTooltip('Settings'));
    await pumpUntil(tester, find.text('Library server'));
    await tester.tap(find.text('Library server'));
    await pumpUntil(tester, find.text('Remove missing files'));
    await tester.tap(find.text('Remove missing files'));
    await pumpUntil(tester, find.text('Remove'));
    await tester.tap(find.text('Remove'));
    await pumpUntil(tester,
        find.textContaining(RegExp(r'missing file|no missing files')));

    // "Connect a different server" lands back on the setup screen; a second
    // shell stacked by setup used to hide it.
    await tester.tap(find.text('Connect a different server'));
    await pumpUntil(tester, find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await pumpUntil(tester, find.byType(SetupScreen));
    expect(find.byType(MainShell), findsNothing);
  });
}
