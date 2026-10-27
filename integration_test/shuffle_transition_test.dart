// Checks that shuffle and smart (DJ) shuffle move straight from one song to
// the planned next one, with no other song playing in between. Drives the
// real audio handler and platform player against a throwaway Navidrome:
//
//   ./flutter/bin/flutter test integration_test/shuffle_transition_test.dart \
//     -d linux --dart-define=ND_URL=http://localhost:4534 \
//     --dart-define=ND_USER=test --dart-define=ND_PASS=...
//
// Works on an Android emulator too (-d emulator-5554, ND_URL with 10.0.2.2),
// but the debug build needs cleartext HTTP allowed for that address.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:melodize/core/api/subsonic_client.dart';
import 'package:melodize/core/audio/audio_handler.dart';
import 'package:melodize/core/audio/shuffle_mode.dart';
import 'package:melodize/core/models/song.dart';

const _url = String.fromEnvironment('ND_URL');
const _user = String.fromEnvironment('ND_USER');
const _pass = String.fromEnvironment('ND_PASS');
const _transitions = int.fromEnvironment('TRANSITIONS', defaultValue: 8);

/// Plays [count] natural song changes in [mode] and returns, for each one,
/// the songs that became current before the planned next song did (empty
/// when the change was clean).
Future<List<String>> runTransitions(
  MelodizeAudioHandler handler,
  ShuffleMode mode,
  int count, {
  required Duration lead,
}) async {
  final problems = <String>[];
  for (var i = 0; i < count; i++) {
    final snapshot = handler.queueSnapshot;
    final from = handler.currentSong!;
    final pos = snapshot.songs.indexWhere((s) => s.id == from.id);
    expect(pos, greaterThanOrEqualTo(0));
    if (pos + 1 >= snapshot.songs.length) break;
    final expected = snapshot.songs[pos + 1];

    // Every song the player lands on until the planned one plays.
    final landed = <String>[];
    final done = Completer<void>();
    final sub = handler.player.currentIndexStream.listen((index) {
      final seq = handler.player.sequence;
      if (index == null || seq == null || index >= seq.length) return;
      final tag = seq[index].tag;
      if (tag is! Song || tag.id == from.id) return;
      landed.add(tag.title);
      if (tag.id == expected.id && !done.isCompleted) done.complete();
    });

    final duration =
        handler.player.duration ?? Duration(seconds: from.duration ?? 30);
    // Seeking past what mpv has buffered ends an HTTP stream on the spot,
    // which is not a natural song change, so wait for the whole file first.
    final buffered = DateTime.now().add(const Duration(seconds: 15));
    while (handler.player.bufferedPosition < duration - lead &&
        DateTime.now().isBefore(buffered)) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    await handler.seek(duration - lead);
    await done.future
        .timeout(lead + const Duration(seconds: 20), onTimeout: () {});
    // Leave room for a late corrective seek to show up.
    await Future<void>.delayed(const Duration(seconds: 2));
    await sub.cancel();

    final strays = landed.takeWhile((t) => t != expected.title).toList();
    debugPrint('[$mode] ${from.title} -> ${expected.title}: '
        'landed on ${landed.join(' -> ')}');
    if (strays.isNotEmpty || handler.currentSong?.id != expected.id) {
      problems.add('${from.title} -> ${expected.title}: '
          'played ${landed.join(' -> ')}');
    }
  }
  return problems;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late MelodizeAudioHandler handler;
  late List<Song> songs;

  setUpAll(() async {
    expect(_url, isNotEmpty, reason: 'pass --dart-define=ND_URL=...');
    if (defaultTargetPlatform == TargetPlatform.linux) {
      JustAudioMediaKit.prefetchPlaylist = true;
      JustAudioMediaKit.ensureInitialized();
    }
    const config =
        SubsonicConfig(serverUrl: _url, username: _user, password: _pass);
    // Skip the 1-second and 9-minute edge-case files.
    songs = (await SubsonicClient(config).getAllSongs())
        .where((s) => (s.duration ?? 0) >= 15 && (s.duration ?? 0) <= 120)
        .toList();
    expect(songs.length, greaterThan(10));
    handler = createAudioHandler()..setConfig(config);
  });

  Future<void> start(ShuffleMode mode) async {
    await handler.applyShuffleMode(mode);
    await handler.loadQueue(songs);
    // Wait for the virtual order to be planned and the first song to play.
    await handler.player.playerStateStream.firstWhere(
        (s) => s.playing && s.processingState == ProcessingState.ready);
    await Future<void>.delayed(const Duration(seconds: 2));
  }

  testWidgets('shuffle goes straight to the planned next song', (_) async {
    await start(ShuffleMode.shuffle);
    final problems = await runTransitions(
        handler, ShuffleMode.shuffle, _transitions,
        lead: const Duration(seconds: 4));
    await handler.pause();
    expect(problems, isEmpty);
  });

  testWidgets('smart shuffle goes straight to the planned next song',
      (_) async {
    await start(ShuffleMode.smartShuffle);
    // DJ mode starts its fade 4 s before the end; start before it.
    final problems = await runTransitions(
        handler, ShuffleMode.smartShuffle, _transitions,
        lead: const Duration(seconds: 6));
    await handler.pause();
    expect(problems, isEmpty);
  });
}
