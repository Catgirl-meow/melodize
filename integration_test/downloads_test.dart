// A local download end to end against the throwaway Navidrome: start it
// from a song's options, wait until audio and cover are saved (the song
// appears in downloadedPathsProvider, which the player reads), find it under
// Settings → Downloaded songs and Library → Downloaded, then remove it.
//
// Run with scripts/test-linux.sh or scripts/test-android.sh (docs/testing.md).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:melodize/core/providers.dart';
import 'package:melodize/main.dart' as app;

import 'helpers.dart';

void main() {
  initIntegration();

  testWidgets('download a song for offline and remove it', (tester) async {
    requireServer();
    app.main();
    await connectIfNeeded(tester);
    final c = container(tester);

    await searchSong(tester, 'Electro 3', 'Electro 3');
    final song = songTile(tester, 'Electro 3').id;
    expect(c.read(downloadedPathsProvider).containsKey(song), isFalse);

    await openSongOptions(tester, 'Electro 3');
    await tapVisible(tester, find.text('Download'));
    await pumpUntilTrue(
        tester, () => c.read(downloadedPathsProvider).containsKey(song),
        reason: 'Electro 3 downloaded', timeout: const Duration(seconds: 60));

    // It shows up under Settings → Downloaded songs.
    await openTab(tester, 'Settings');
    await tapVisible(tester, find.text('Downloaded songs'));
    await pumpUntil(tester, find.text('Electro 3'));
    await goBack(tester);

    // And under Library → Downloaded (a pushed page on phones, the right
    // pane on desktop).
    await openLibraryView(tester, 'all');
    await tapVisible(tester, find.byKey(const Key('pinned-downloaded')));
    await pumpUntil(tester, find.text('Electro 3'));
    if (libraryIsWide()) {
      await openLibraryView(tester, 'all');
    } else {
      await goBack(tester);
    }

    // Remove download from the song's options.
    await searchSong(tester, 'Electro 3', 'Electro 3');
    await openSongOptions(tester, 'Electro 3');
    await tapVisible(tester, find.text('Remove download'));
    await pumpUntilTrue(
        tester, () => !c.read(downloadedPathsProvider).containsKey(song),
        reason: 'download removed');
  });
}
