// "Song radio": songs like the one playing, from its artist's Deezer radio,
// queued right after it. Replaces "More like this", which rebuilt the Home
// row instead of changing what plays.
import '../api/deezer_client.dart';
import '../models/song.dart';
import '../utils/title_normalize.dart';
import 'artist_credit.dart';
import 'taste_model.dart' show NoDeezerRadio;

/// Up to [limit] songs like [seed], in Deezer's radio order. The seed track
/// itself, duplicates and songs [hide] rejects ("Not interested") are left
/// out.
///
/// Throws [NoDeezerRadio] when Deezer has no artist or radio for the seed,
/// and lets network errors through: an empty result never means "failed".
Future<List<Song>> songRadio({
  required DeezerClient deezer,
  required Song seed,
  bool Function(Song song)? hide,
  int limit = 20,
}) async {
  int? id;
  for (final name in artistLookupNames(seed.artist)) {
    id =
        await deezer.searchBestArtist(artistName: name, trackTitle: seed.title);
    if (id != null) break;
  }
  if (id == null) throw NoDeezerRadio(seed.artist);
  final tracks = (await deezer.artistRadio(id, limit: limit + 10))
      .where((track) => track.previewUrl?.trim().isNotEmpty ?? false);
  if (tracks.isEmpty) throw NoDeezerRadio(seed.artist);

  final seen = {
    keyFor(seed.title, seed.artist),
    for (final artist in splitArtistCredit(seed.artist))
      keyFor(seed.title, artist),
  };
  final out = <Song>[];
  for (final t in tracks) {
    if (out.length >= limit) break;
    if (!seen.add(keyFor(t.title, t.artist))) continue;
    final song = Song.fromRecommendation(
      deezerId: t.deezerId,
      title: t.title,
      artist: t.artist,
      album: t.album,
      durationSeconds: t.durationSeconds,
      previewUrl: t.previewUrl,
      coverUrl: t.coverUrl,
      bpm: t.bpm,
      genre: t.genre,
    );
    if (hide != null && hide(song)) continue;
    out.add(song);
  }
  return out;
}
