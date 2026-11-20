// Pure playlist-editing logic, kept apart from the API and the UI so it can
// be unit tested.

/// How to bring a playlist from [original] to [edited] (both song id lists)
/// with the fewest Subsonic requests.
sealed class PlaylistSongChange {
  const PlaylistSongChange();
}

/// Nothing to send.
class NoSongChange extends PlaylistSongChange {
  const NoSongChange();
}

/// Only removals: `updatePlaylist?songIndexToRemove=…` with indices into the
/// server's current list.
class RemoveSongs extends PlaylistSongChange {
  final List<int> indices;
  const RemoveSongs(this.indices);
}

/// Only additions at the end: `updatePlaylist?songIdToAdd=…`.
class AppendSongs extends PlaylistSongChange {
  final List<String> songIds;
  const AppendSongs(this.songIds);
}

/// Anything else (reorders, mixed edits): replace the whole list.
class ReplaceSongs extends PlaylistSongChange {
  final List<String> songIds;
  const ReplaceSongs(this.songIds);
}

PlaylistSongChange planSongChange(List<String> original, List<String> edited) {
  if (_sameList(original, edited)) return const NoSongChange();

  // Appends only: the original is a prefix of the edited list.
  if (edited.length > original.length &&
      _sameList(original, edited.sublist(0, original.length))) {
    return AppendSongs(edited.sublist(original.length));
  }

  // Removals only: the edited list is the original with some entries taken
  // out, order kept. Walk both lists and collect the skipped indices.
  if (edited.length < original.length) {
    final removed = <int>[];
    var j = 0;
    for (var i = 0; i < original.length; i++) {
      if (j < edited.length && original[i] == edited[j]) {
        j++;
      } else {
        removed.add(i);
      }
    }
    if (j == edited.length) return RemoveSongs(removed);
  }

  return ReplaceSongs(List.unmodifiable(edited));
}

bool _sameList(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Moves an item the way Flutter's ReorderableListView reports it:
/// [newIndex] is the slot *before* removal, so a downward move arrives one
/// too high.
List<T> reorderedList<T>(List<T> items, int oldIndex, int newIndex) {
  final list = List<T>.of(items);
  if (oldIndex < 0 || oldIndex >= list.length) return list;
  var target = newIndex;
  if (target > oldIndex) target -= 1;
  target = target.clamp(0, list.length - 1);
  final item = list.removeAt(oldIndex);
  list.insert(target, item);
  return list;
}

/// Splits [toAdd] into songs not yet in [existing] (de-duplicated, order
/// kept) and songs already there.
({List<String> fresh, List<String> already}) splitNewSongs(
    Iterable<String> existing, Iterable<String> toAdd) {
  final have = existing.toSet();
  final seen = <String>{};
  final fresh = <String>[];
  final already = <String>[];
  for (final id in toAdd) {
    if (!seen.add(id)) continue;
    if (have.contains(id)) {
      already.add(id);
    } else {
      fresh.add(id);
    }
  }
  return (fresh: fresh, already: already);
}

/// "Gym" → "Gym (copy)", then "Gym (copy 2)", … skipping names in use.
String copyName(String name, Iterable<String> taken) {
  final used = taken.map((n) => n.toLowerCase()).toSet();
  final first = '$name (copy)';
  if (!used.contains(first.toLowerCase())) return first;
  for (var n = 2;; n++) {
    final candidate = '$name (copy $n)';
    if (!used.contains(candidate.toLowerCase())) return candidate;
  }
}

/// A trimmed name, or an error message for the name field.
String? validatePlaylistName(String? raw) {
  final name = raw?.trim() ?? '';
  if (name.isEmpty) return 'Give the playlist a name';
  if (name.length > 200) return 'Keep the name under 200 characters';
  return null;
}
