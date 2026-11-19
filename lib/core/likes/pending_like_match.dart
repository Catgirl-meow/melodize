import '../models/song.dart';
import '../utils/title_normalize.dart';

/// A liked Deezer track waiting to show up in the server library.
typedef PendingLikeKey = ({int deezerId, String title, String artist});

/// Pairs each pending like with the library song it became, matched on
/// normalized title + artist (the same key the recommendations use to skip
/// owned tracks). Pending likes with no library match are left out; when
/// several library songs match, the first one wins.
List<(PendingLikeKey, Song)> matchPendingLikes(
  Iterable<PendingLikeKey> pending,
  Iterable<Song> library,
) {
  final byKey = <String, Song>{};
  for (final s in library) {
    if (s.isExternal) continue;
    byKey.putIfAbsent(keyFor(s.title, s.artist), () => s);
  }
  return [
    for (final p in pending)
      if (byKey[keyFor(p.title, p.artist)] case final song?) (p, song),
  ];
}

/// The liked song ids after a library sync: the server's stars, with any
/// like/unlike still in flight applied on top so a sync that raced the
/// request can't flip the heart back.
Set<String> mergeLikes(
  Iterable<Song> library,
  Map<String, bool> inFlight,
) {
  final ids = <String>{
    for (final s in library)
      if (s.isStarred) s.id,
  };
  inFlight.forEach((id, liked) => liked ? ids.add(id) : ids.remove(id));
  return ids;
}
