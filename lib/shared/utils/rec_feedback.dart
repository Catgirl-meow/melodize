import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/errors/app_errors.dart';
import '../../core/models/song.dart';
import '../../core/providers.dart';
import '../../core/recs/song_radio.dart';
import '../../core/recs/taste_model.dart' show NoDeezerRadio;
import 'snack.dart';

/// "Not interested" on a recommendation: hides [song] (or every song by its
/// artist) from recommendations, with Undo on the snackbar. Home drops the
/// card as soon as the row is saved; the taste model counts it on the next
/// refresh.
Future<void> dismissRecommendation(
  BuildContext context,
  WidgetRef ref,
  Song song, {
  required bool wholeArtist,
}) async {
  final db = ref.read(databaseProvider);
  final key = wholeArtist
      ? dismissedArtistKey(song.artist)
      : dismissedTrackKey(song.title, song.artist);
  // Shown before the write: the card (and [context]) leaves the tree as soon
  // as the row lands.
  showStyledSnack(
    context,
    wholeArtist
        ? "Hidden ${song.artist}. You won't see this artist again."
        : "Hidden. You'll see less like this.",
    actionLabel: 'Undo',
    onAction: () => db.removeDismissedRec(key).catchError((Object e) =>
        AppErrors.report("Couldn't undo hiding the recommendation", e)),
  );
  try {
    await db.addDismissedRec(DismissedRecsCompanion.insert(
      key: key,
      kind: wholeArtist ? 'artist' : 'track',
      artist: song.artist,
      title: Value(wholeArtist ? null : song.title),
      coverUrl: Value(song.externalCoverUrl),
    ));
  } catch (e) {
    AppErrors.report("Couldn't hide the recommendation", e);
  }
}

/// Thumbs-down in the player: hides [song] like "Not interested" and skips
/// to the next song, so disliking while listening is one tap.
Future<void> dislikeAndSkip(
  BuildContext context,
  WidgetRef ref,
  Song song, {
  bool wholeArtist = false,
}) async {
  final handler = ref.read(audioHandlerNotifierProvider);
  final hiding =
      dismissRecommendation(context, ref, song, wholeArtist: wholeArtist);
  await handler?.skipToNext();
  await hiding;
}

/// "Song radio": queues songs like [song] (its artist's Deezer radio) right
/// after the current one, and counts the start as a lasting signal for the
/// artist. Every failure is shown on a snackbar.
Future<void> startSongRadio(
    BuildContext context, WidgetRef ref, Song song) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  void snack(String msg, {bool isError = false}) {
    if (!context.mounted) return;
    showStyledSnack(context, msg, isError: isError, messenger: messenger);
  }

  if (ref.read(isOnlineProvider).valueOrNull == false) {
    snack('Song radio needs an internet connection.', isError: true);
    return;
  }
  final handler = ref.read(audioHandlerNotifierProvider);
  if (handler == null) return;
  ref.read(databaseProvider).addMoreLikeThis(song.artist).catchError(
      (Object e) => AppErrors.report("Couldn't save the song radio start", e));
  final dismissed = ref.read(dismissedRecsProvider).valueOrNull ?? const [];
  final List<Song> songs;
  try {
    songs = await songRadio(
      deezer: ref.read(deezerClientProvider),
      seed: song,
      hide: (s) => isDismissed(s, dismissed),
    );
  } on NoDeezerRadio {
    snack('Deezer has no radio for ${song.artist}.', isError: true);
    return;
  } catch (e) {
    snack("Couldn't load song radio: ${describeError(e)}", isError: true);
    return;
  }
  if (songs.isEmpty) {
    snack('Every song in the radio for ${song.artist} is hidden.',
        isError: true);
    return;
  }
  // Reversed, because each one goes in right after the current song.
  for (final s in songs.reversed) {
    await handler.playNext(s);
  }
  snack('Queued ${songs.length} songs like "${song.title}"');
}
