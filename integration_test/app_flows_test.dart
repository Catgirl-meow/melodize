// Everyday features end to end against the throwaway Navidrome: browsing
// albums and artists, search, queue editing (play next / add to queue),
// skip, shuffle and repeat, the queue sheet and the sleep timer. Checks go through the real audio handler and
// providers, not only through what is on screen.
//
// Run with scripts/test-linux.sh or scripts/test-android.sh (docs/testing.md).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:melodize/core/audio/shuffle_mode.dart';
import 'package:melodize/main.dart' as app;

import 'helpers.dart';

void main() {
  initIntegration();

  testWidgets('browse, queue, player controls and sleep timer',
      (tester) async {
    requireServer();
    app.main();
    await connectIfNeeded(tester);
    final h = handlerOf(tester);

    // Library → Albums → album page → Play plays the album in track order.
    await openLibraryView(tester, 'albums');
    await tapVisible(tester, find.text('Electro Album'));
    await tapVisible(tester, find.text('Play'));
    await pumpUntilTrue(tester, () => h.currentSong?.title == 'Electro 1',
        reason: 'Electro 1 to start');
    var q = h.queueSnapshot;
    expect(q.songs.map((s) => s.title).toList(),
        ['Electro 1', 'Electro 2', 'Electro 3', 'Electro 4', 'Electro 5',
         'Electro 6']);
    await pauseIfPlaying(tester);
    await goBack(tester);

    // Library → Artists → artist page lists both of the artist's albums.
    await openLibraryView(tester, 'artists');
    await tapVisible(tester, find.text('Test Artist'));
    await pumpUntil(tester, find.text('Rock Album'));
    expect(find.text('Electro Album'), findsWidgets);
    await goBack(tester);

    // Search → song options → Play next puts it right after the current song.
    await searchSong(tester, 'Rock 1', 'Rock 1');
    await openSongOptions(tester, 'Rock 1');
    await tapVisible(tester, find.text('Play next'));
    await pumpUntilTrue(tester, () {
      final s = h.queueSnapshot;
      return s.songs.length == 7 &&
          s.songs[s.currentIndex + 1].title == 'Rock 1';
    }, reason: 'Rock 1 queued next');

    // Add to queue appends it at the end.
    await searchSong(tester, 'Vorb 2', 'Vorb 2');
    await openSongOptions(tester, 'Vorb 2');
    await tapVisible(tester, find.text('Add to queue'));
    await pumpUntilTrue(tester, () => h.queueSnapshot.songs.last.title == 'Vorb 2',
        reason: 'Vorb 2 at the end of the queue');
    expect(h.queueSnapshot.songs.length, 8);

    // Skip next (mini player) goes to the song queued with Play next.
    await tester.tap(find.byIcon(Icons.skip_next_rounded).first);
    await pumpUntilTrue(tester, () => h.currentSong?.title == 'Rock 1',
        reason: 'skip to Rock 1');
    await pauseIfPlaying(tester);

    // Now Playing: shuffle cycles off → shuffle → smart shuffle → off and
    // never changes the current song; repeat cycles off → all → one → off.
    await openNowPlaying(tester);
    expect(h.currentShuffleMode, ShuffleMode.off);
    await tester.tap(find.byIcon(Icons.shuffle_rounded));
    await pumpUntilTrue(tester, () => h.currentShuffleMode == ShuffleMode.shuffle,
        reason: 'shuffle on');
    expect(h.currentSong?.title, 'Rock 1');
    expect(h.queueSnapshot.songs.length, 8);
    await tester.tap(find.byIcon(Icons.shuffle_rounded));
    await pumpUntilTrue(
        tester, () => h.currentShuffleMode == ShuffleMode.smartShuffle,
        reason: 'smart shuffle on');
    expect(h.currentSong?.title, 'Rock 1');
    await tester.tap(find.byIcon(Icons.auto_awesome_rounded));
    await pumpUntilTrue(tester, () => h.currentShuffleMode == ShuffleMode.off,
        reason: 'shuffle off');
    expect(h.currentSong?.title, 'Rock 1');

    expect(h.player.loopMode, LoopMode.off);
    await tester.tap(find.byIcon(Icons.repeat_rounded));
    await pumpUntilTrue(tester, () => h.player.loopMode == LoopMode.all,
        reason: 'repeat all');
    await tester.tap(find.byIcon(Icons.repeat_rounded));
    await pumpUntilTrue(tester, () => h.player.loopMode == LoopMode.one,
        reason: 'repeat one');
    await tester.tap(find.byIcon(Icons.repeat_one_rounded));
    await pumpUntilTrue(tester, () => h.player.loopMode == LoopMode.off,
        reason: 'repeat off');

    // Queue sheet lists what is coming up.
    await tapVisible(tester, find.text('Queue'));
    await pumpUntil(tester, find.text('Up Next'));
    expect(find.text('Vorb 2'), findsWidgets);
    await goBack(tester);

    // Sleep timer: set 15 minutes, then cancel it.
    await tapVisible(tester, find.text('Sleep'));
    await tapVisible(tester, find.text('15 minutes'));
    expect(h.hasSleepTimer, isTrue);
    await tapVisible(tester, find.byIcon(Icons.bedtime_rounded));
    await tapVisible(tester, find.text('Cancel timer'));
    expect(h.hasSleepTimer, isFalse);
    await pumpUntil(tester, find.text('Sleep'));

    await pauseIfPlaying(tester);
    await goBack(tester);
  });
}
