import 'dart:math';

import '../models/song.dart';
import 'smart_shuffle_engine.dart';

enum PlaybackMode { normal, shuffle, smartShuffle }

enum TransitionKind { gapless, volumeCrossfade, djBlend }

class PlannedTransition {
  final Song from;
  final Song to;
  final TransitionKind kind;
  final Duration duration;
  final Duration fromStart;
  final Duration toStart;
  final String reason;

  const PlannedTransition({
    required this.from,
    required this.to,
    required this.kind,
    required this.duration,
    required this.fromStart,
    required this.toStart,
    required this.reason,
  });
}

class PlaybackQueueSnapshot {
  final List<Song> songs;
  final int currentIndex;
  final PlaybackMode mode;
  final List<PlannedTransition> upcomingTransitions;

  const PlaybackQueueSnapshot({
    required this.songs,
    required this.currentIndex,
    required this.mode,
    this.upcomingTransitions = const [],
  });

  factory PlaybackQueueSnapshot.empty() => const PlaybackQueueSnapshot(
        songs: [],
        currentIndex: 0,
        mode: PlaybackMode.normal,
      );
}

class PlaybackQueue {
  final _songs = <Song>[];
  int _currentIndex = 0;
  PlaybackMode _mode = PlaybackMode.normal;

  List<Song> get songs => List.unmodifiable(_songs);
  int get currentIndex =>
      _songs.isEmpty ? 0 : _currentIndex.clamp(0, _songs.length - 1);
  PlaybackMode get mode => _mode;
  Song? get currentSong => _songs.isEmpty ? null : _songs[currentIndex];

  void load(List<Song> songs,
      {int startIndex = 0, PlaybackMode mode = PlaybackMode.normal}) {
    _songs
      ..clear()
      ..addAll(songs);
    _currentIndex = _songs.isEmpty ? 0 : startIndex.clamp(0, _songs.length - 1);
    _mode = mode;
  }

  void setMode(PlaybackMode mode) {
    _mode = mode;
  }

  void setCurrentIndex(int index) {
    if (_songs.isEmpty) {
      _currentIndex = 0;
    } else {
      _currentIndex = index.clamp(0, _songs.length - 1);
    }
  }

  void replaceSongs(List<Song> songs, {int? currentIndex}) {
    _songs
      ..clear()
      ..addAll(songs);
    setCurrentIndex(currentIndex ?? _currentIndex);
  }

  void playNext(Song song) {
    final idx = _songs.isEmpty ? 0 : currentIndex + 1;
    _songs.insert(idx.clamp(0, _songs.length), song);
  }

  void add(Song song) {
    _songs.add(song);
  }

  Song? removeAt(int index) {
    if (index < 0 || index >= _songs.length) return null;
    final wasCurrent = index == _currentIndex;
    final removed = _songs.removeAt(index);
    if (_songs.isEmpty) {
      _currentIndex = 0;
    } else if (index < _currentIndex) {
      _currentIndex--;
    } else if (wasCurrent) {
      // Removing the currently playing song: keep index pointing at the song
      // that slid into this slot (or clamp if we were at the end).
      if (_currentIndex >= _songs.length) {
        _currentIndex = _songs.length - 1;
      }
    } else if (_currentIndex >= _songs.length) {
      _currentIndex = _songs.length - 1;
    }
    return removed;
  }

  bool removeById(String songId) {
    var removed = false;
    for (int i = _songs.length - 1; i >= 0; i--) {
      if (_songs[i].id == songId) {
        removeAt(i);
        removed = true;
      }
    }
    return removed;
  }

  // Reorder a song. Expects Flutter-adjusted indices (i.e. newIndex is
  // already decremented by 1 for downward moves, matching ReorderableListView
  // onReorder semantics).
  void reorder(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _songs.length) return;
    final insertIndex = newIndex.clamp(0, _songs.length - 1);
    // Use the actual current index (not song ID) because duplicate IDs can
    // cause indexWhere to return the wrong position. The current song stays
    // at the same logical position unless it itself is being moved.
    final previousCurrent = _currentIndex;
    final song = _songs.removeAt(oldIndex);
    _songs.insert(insertIndex.clamp(0, _songs.length), song);
    // Adjust current index: if we moved the current song, it lands at insertIndex.
    if (oldIndex == previousCurrent) {
      _currentIndex = insertIndex.clamp(0, _songs.length - 1);
    } else if (oldIndex < previousCurrent && insertIndex >= previousCurrent) {
      // Removed before current, inserted after → current slides back one.
      _currentIndex = (previousCurrent - 1).clamp(0, _songs.length - 1);
    } else if (oldIndex < previousCurrent && insertIndex < previousCurrent) {
      // removeAt already decremented; inserting before current's new
      // position should restore it.
      _currentIndex = previousCurrent.clamp(0, _songs.length - 1);
    } else if (oldIndex > previousCurrent && insertIndex <= previousCurrent) {
      // Removed after current, inserted before → current slides forward one.
      _currentIndex = (previousCurrent + 1).clamp(0, _songs.length - 1);
    }
    // Otherwise current is unaffected.
  }

  PlaybackQueueSnapshot snapshot({
    List<PlannedTransition> upcomingTransitions = const [],
  }) =>
      PlaybackQueueSnapshot(
        songs: songs,
        currentIndex: currentIndex,
        mode: _mode,
        upcomingTransitions: upcomingTransitions,
      );
}

class PlaybackPlanner {
  List<Song> plan({
    required List<Song> songs,
    required int currentIndex,
    required PlaybackMode mode,
    BpmCache? cache,
    int? seed,
  }) {
    if (songs.length < 2 || mode == PlaybackMode.normal) {
      return List.from(songs);
    }

    final idx = currentIndex.clamp(0, songs.length - 1);
    final heardAndCurrent = songs.sublist(0, idx + 1);
    final upcoming = songs.sublist(idx + 1);
    if (upcoming.length < 2) return List.from(songs);

    final plannedUpcoming = switch (mode) {
      PlaybackMode.normal => upcoming,
      PlaybackMode.shuffle => _shuffleUpcoming(upcoming, seed),
      PlaybackMode.smartShuffle => _smartUpcoming(
          songs: songs,
          currentIndex: idx,
          cache: cache,
          seed: seed,
        ),
    };

    return [...heardAndCurrent, ...plannedUpcoming];
  }

  List<Song> _shuffleUpcoming(List<Song> upcoming, int? seed) {
    final copy = List<Song>.from(upcoming);
    // Derive a stable seed from the list contents when none is provided so
    // the same upcoming segment always shuffles the same way.
    final effectiveSeed = seed ?? Object.hashAll(upcoming.map((s) => s.id));
    final rng = Random(effectiveSeed);
    for (var i = copy.length - 1; i > 0; i--) {
      final j = rng.nextInt(i + 1);
      final tmp = copy[i];
      copy[i] = copy[j];
      copy[j] = tmp;
    }
    return copy;
  }

  List<Song> _smartUpcoming({
    required List<Song> songs,
    required int currentIndex,
    required BpmCache? cache,
    required int? seed,
  }) {
    if (songs.length < 2) return [];
    final idx = currentIndex.clamp(0, songs.length - 1);
    final ordered = orderSongs(
      songs,
      idx,
      cache ?? buildBpmCache(songs),
      seed: seed ?? DateTime.now().microsecondsSinceEpoch,
    );
    // Everything after the anchor song is the reordered upcoming segment.
    return ordered.sublist(idx + 1);
  }
}

class TransitionPolicy {
  final int crossfadeSeconds;
  final bool djTransitionsEnabled;
  final BpmCache? analysis;

  const TransitionPolicy({
    required this.crossfadeSeconds,
    this.djTransitionsEnabled = true,
    this.analysis,
  });

  // Plan transitions for the next 1–3 upcoming pairs. The UI and crossfade
  // listener only need a small lookahead.
  List<PlannedTransition> planUpcoming(List<Song> songs, int currentIndex) {
    if (songs.isEmpty || songs.length < 2) return const [];
    final idx = currentIndex.clamp(0, songs.length - 1);
    // Safety: if current index is at or past the end, no upcoming transitions.
    if (idx >= songs.length - 1) return const [];
    final transitions = <PlannedTransition>[];
    // Only plan up to 3 transitions ahead — enough for the UI preview and the
    // crossfade listener to peek at the next song, without O(n) allocation.
    final limit = (idx + 3).clamp(0, songs.length - 1);
    for (int i = idx; i < limit; i++) {
      transitions.add(planPair(songs[i], songs[i + 1]));
    }
    return transitions;
  }

  PlannedTransition planPair(Song from, Song to, {int? actualDurationSeconds}) {
    final requested = crossfadeSeconds.clamp(0, 12);
    final durationSeconds = actualDurationSeconds ?? from.duration;
    if (requested <= 0) {
      return _gapless(from, to, 'crossfade disabled');
    }
    // Safety: corrupted metadata may produce negative or zero duration.
    if (durationSeconds == null || durationSeconds <= 0) {
      return _gapless(from, to, 'unknown duration');
    }
    // Safety: cap tail silence to the smaller of half the track and
    // 1.5× the crossfade duration. The latter prevents the fade from
    // starting while the current song is still audibly playing.
    final rawTail = analysis?.tailSilenceFor(from) ?? 0.0;
    final maxTail = min(durationSeconds * 0.5, crossfadeSeconds * 1.5);
    final tailSilence = rawTail.clamp(0.0, maxTail);
    final effectiveMs =
        max(0, (durationSeconds * 1000) - (tailSilence * 1000).round());
    if (effectiveMs < 15000) {
      return _gapless(from, to, 'track too short');
    }

    final fadeMs = min(requested * 1000, max(1000, effectiveMs ~/ 3));
    final startMs = max(0, effectiveMs - fadeMs);
    final canBlend = _canDjBlend(from, to);
    final kind = canBlend
        ? TransitionKind.djBlend
        : TransitionKind.volumeCrossfade;
    final reason = canBlend
        ? 'compatible companion analysis'
        : 'standard volume crossfade';

    return PlannedTransition(
      from: from,
      to: to,
      kind: kind,
      duration: Duration(milliseconds: fadeMs),
      fromStart: Duration(milliseconds: startMs),
      toStart: Duration.zero,
      reason: reason,
    );
  }

  bool _canDjBlend(Song from, Song to) {
    if (!djTransitionsEnabled) return false;
    final cache = analysis;
    if (cache == null) return false;
    final bpmA = cache.bpmFor(from);
    final bpmB = cache.bpmFor(to);
    if (bpmA == null || bpmB == null) return false;
    if (cache.isEstimatedFor(from) || cache.isEstimatedFor(to)) return false;
    final ratio = bpmA > bpmB ? bpmA / bpmB : bpmB / bpmA;
    if (ratio > 1.15) return false;

    // Require harmonically compatible keys for a true DJ blend.
    final kd = cache.keyDistance(from, to);
    if (kd <= 2) return true;
    // If keys are unavailable, fall back to BPM-only (partial data).
    return kd == 99;
  }

  PlannedTransition _gapless(Song from, Song to, String reason) =>
      PlannedTransition(
        from: from,
        to: to,
        kind: TransitionKind.gapless,
        duration: Duration.zero,
        fromStart: Duration.zero,
        toStart: Duration.zero,
        reason: reason,
      );
}
