// Playlists end to end against the throwaway Navidrome: create one from
// Library, add songs from their menus, open it, rename and reorder it in the
// editor, remove a song, and delete it. Works in both Library layouts (phone
// chips on Android, the desktop sidebar on the Linux runner).
//
// Run with scripts/test-linux.sh or scripts/test-android.sh (docs/testing.md).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:melodize/core/models/playlist.dart';
import 'package:melodize/core/models/song.dart';
import 'package:melodize/core/providers.dart';
import 'package:melodize/main.dart' as app;

import 'helpers.dart';

void main() {
  initIntegration();

  testWidgets('create, fill, edit, reorder and delete a playlist',
      (tester) async {
    requireServer();
    app.main();
    await connectIfNeeded(tester);
    final c = container(tester);
    // Keep the playlist providers alive so the checks below see reloads.
    c.listen(playlistsProvider, (_, __) {});
    final name = 'IT playlist ${DateTime.now().millisecondsSinceEpoch}';

    Playlist? find_() {
      for (final p in c.read(playlistsProvider).valueOrNull ?? <Playlist>[]) {
        if (p.name.startsWith(name)) return p;
      }
      return null;
    }

    List<String>? titles(String id) => c
        .read(playlistSongsProvider(id))
        .valueOrNull
        ?.map((Song s) => s.title)
        .toList();

    // Create from Library.
    await openLibraryView(tester, 'all');
    await tapVisible(tester, find.byKey(const Key('library-new-playlist')));
    await pumpUntil(tester, find.byKey(const Key('playlist-name-field')));
    await tester.enterText(
        find.byKey(const Key('playlist-name-field')), name);
    await tapVisible(tester, find.text('Create'));
    await pumpUntilTrue(tester, () => find_() != null,
        reason: 'the new playlist on the server');
    final id = find_()!.id;
    c.listen(playlistSongsProvider(id), (_, __) {});

    // Add two songs from their menus.
    for (final title in ['Electro 1', 'Electro 2']) {
      await searchSong(tester, title, title);
      await openSongOptions(tester, title);
      await tapVisible(tester, find.text('Add to playlist'));
      await pumpUntil(tester, find.text(name));
      await tapVisible(tester, find.text(name));
      await tapVisible(tester, find.text('Save'));
      await pumpUntilTrue(
          tester, () => titles(id)?.contains(title) ?? false,
          reason: '$title in the playlist');
    }
    expect(titles(id), ['Electro 1', 'Electro 2']);

    // Open it from Library → Playlists.
    await openLibraryView(tester, 'playlists');
    await tapVisible(tester, find.text(name).first);
    await pumpUntil(tester, songRow('Electro 2'));

    // Edit: rename and move Electro 2 above Electro 1, saved on Done.
    await tapVisible(tester, find.byKey(const Key('playlist-edit')));
    await pumpUntil(tester, find.byKey(const Key('playlist-edit-name')));
    await tester.enterText(
        find.byKey(const Key('playlist-edit-name')), '$name renamed');
    await tester.pump();
    final handle = find.descendant(
        of: find.ancestor(
            of: find.text('Electro 2'), matching: find.byType(ListTile)),
        matching: find.byIcon(Icons.drag_handle_rounded));
    final gesture =
        await tester.startGesture(tester.getCenter(handle.first));
    await tester.pump(const Duration(milliseconds: 100));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(0, -12));
      await tester.pump(const Duration(milliseconds: 30));
    }
    await gesture.up();
    await pumpFor(tester, const Duration(milliseconds: 600));
    await tapVisible(tester, find.byKey(const Key('playlist-edit-done')));
    await pumpUntilTrue(
        tester,
        () =>
            find_()?.name == '$name renamed' &&
            titles(id)?.join(',') == 'Electro 2,Electro 1',
        reason: 'renamed and reordered on the server');

    // Remove a song from its menu on the playlist page.
    await openSongOptions(tester, 'Electro 1');
    await tapVisible(tester, find.text('Remove from this playlist'));
    await pumpUntilTrue(tester, () => titles(id)?.join(',') == 'Electro 2',
        reason: 'Electro 1 removed');

    // Delete it.
    await tapVisible(tester, find.byKey(const Key('playlist-more')));
    await tapVisible(tester, find.text('Delete'));
    await pumpUntil(tester, find.byType(AlertDialog));
    await tapVisible(
        tester,
        find.descendant(
            of: find.byType(AlertDialog), matching: find.text('Delete')));
    await pumpUntilTrue(tester, () {
      final list = c.read(playlistsProvider).valueOrNull;
      return list != null && !list.any((p) => p.id == id);
    }, reason: 'the playlist deleted on the server');
    await pauseIfPlaying(tester);
  });
}
