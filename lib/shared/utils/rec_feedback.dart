import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/errors/app_errors.dart';
import '../../core/models/song.dart';
import '../../core/providers.dart';
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

/// "More like this": rebuilds recommendations around [song]'s artist and
/// remembers the tap as a lasting signal for that artist.
void requestMoreLikeThis(WidgetRef ref, Song song) {
  // Queued before the rebuild's reads, so the new list already counts it.
  ref.read(databaseProvider).addMoreLikeThis(song.artist).catchError(
      (Object e) => AppErrors.report("Couldn't save \"More like this\"", e));
  ref.read(recommendationsSeedOverrideProvider.notifier).state = (
    artist: song.artist,
    title: song.title,
    genre: song.genre,
  );
  ref.invalidate(recommendationsProvider);
}
