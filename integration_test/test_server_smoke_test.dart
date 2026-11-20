// Setup screen, library, playback and server switch against the throwaway
// Navidrome. Run with scripts/test-linux.sh or scripts/test-android.sh
// (docs/testing.md); both start from an empty app profile.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:melodize/features/setup/setup_screen.dart';
import 'package:melodize/features/shell/main_shell.dart';
import 'package:melodize/main.dart' as app;

import 'helpers.dart';

void main() {
  initIntegration();

  testWidgets('setup, library, playback and server switch', (tester) async {
    requireServer();
    app.main();
    await pumpUntil(tester, find.byType(SetupScreen));

    // A non-http URL is caught by the form.
    await fillSetup(tester, 'ftp://example', ndUser, ndPass);
    expect(find.text('URL must start with http:// or https://'),
        findsOneWidget);

    // A wrong password names the problem instead of "did not respond".
    await fillSetup(tester, ndUrl, ndUser, 'definitely-wrong');
    await pumpUntil(tester, find.textContaining('password'));

    // A trailing slash and stray spaces are fine.
    await fillSetup(tester, '  $ndUrl/ ', ndUser, ndPass);
    await pumpUntil(tester, find.byType(MainShell));
    expect(find.byType(SetupScreen), findsNothing);

    // Library lists songs. Sorted by name, "Electro" is on the first screen.
    await openLibraryView(tester, 'songs');
    await pumpUntil(tester, find.textContaining('Electro'));

    // Play a song and skip through a few quickly.
    await tapVisible(tester, find.textContaining('Electro'));
    await pumpUntil(tester, find.byIcon(Icons.skip_next_rounded));
    final h = handlerOf(tester);
    await pumpUntilTrue(tester, () => h.currentSong != null,
        reason: 'a current song');
    final first = h.currentSong!.id;
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byIcon(Icons.skip_next_rounded).first);
      await tester.pump(const Duration(milliseconds: 150));
    }
    await pumpUntilTrue(tester, () => h.currentSong?.id != first,
        reason: 'skip next to change the song');
    await pauseIfPlaying(tester);

    // Settings → Library server → Remove missing files.
    await openTab(tester, 'Settings');
    await tapVisible(tester, find.text('Library server'));
    await tapVisible(tester, find.text('Remove missing files'));
    await tapVisible(tester, find.text('Remove'));
    await pumpUntil(tester,
        find.textContaining(RegExp(r'missing file|no missing files')));

    // "Connect a different server" lands back on the setup screen; a second
    // shell stacked by setup used to hide it.
    await tapVisible(tester, find.text('Connect a different server'));
    await tapVisible(tester, find.text('Continue'));
    await pumpUntil(tester, find.byType(SetupScreen));
    expect(find.byType(MainShell), findsNothing);
  });
}
