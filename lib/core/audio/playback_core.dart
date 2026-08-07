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
  int get length => _songs.length;
  int get currentIndex => _songs.isEmpty
      ? 0
      : _currentIndex.clamp(0, _songs.length - 1).toInt();
  PlaybackMode get mode => _mode;
  Song? get currentSong => _songs.isEmpty ? null : _songs[currentIndex];

  void load(List<Song> songs,
      {int startIndex = 0, PlaybackMode mode = PlaybackMode.normal}) {
    _songs
      ..clear()
      ..addAll(songs);
    _currentIndex = _songs.isEmpty
        ? 0
        : startIndex.clamp(0, _songs.length - 1).toInt();
    _mode = mode;
  }

  void setMode(PlaybackMode mode) {
    _mode = mode;
  }

  void setCurrentIndex(int index) {
    if (_songs.isEmpty) {
      _currentIndex = 0;
    } else {
      _currentIndex = index.clamp(0, _songs.length - 1).toInt();
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
    _songs.insert(idx.clamp(0, _songs.length).toInt(), song);
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
    final insertIndex = newIndex.clamp(0, _songs.length - 1).toInt();
    // Use the actual current index (not song ID) because duplicate IDs can
    // cause indexWhere to return the wrong position. The current song stays
    // at the same logical position unless it itself is being moved.
    final previousCurrent = _currentIndex;
    final song = _songs.removeAt(oldIndex);
    _songs.insert(insertIndex.clamp(0, _songs.length).toInt(), song);
    // Adjust current index: if we moved the current song, it lands at insertIndex.
    if (oldIndex == previousCurrent) {
      _currentIndex = insertIndex.clamp(0, _songs.length - 1).toInt();
    } else if (oldIndex < previousCurrent && insertIndex >= previousCurrent) {
      // Removed before current, inserted after → current slides back one.
      _currentIndex =
          (previousCurrent - 1).clamp(0, _songs.length - 1).toInt();
    } else if (oldIndex < previousCurrent && insertIndex < previousCurrent) {
      // removeAt already decremented; inserting before current's new
      // position should restore it.
      _currentIndex = previousCurrent.clamp(0, _songs.length - 1).toInt();
    } else if (oldIndex > previousCurrent && insertIndex <= previousCurrent) {
      // Removed after current, inserted before → current slides forward one.
      _currentIndex =
          (previousCurrent + 1).clamp(0, _songs.length - 1).toInt();
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
        // Transition metadata is a DJ-shuffle-only feature. Keep this
        // invariant in the model as well as in the audio handler so normal
        // and regular shuffle queues can never expose smart transitions.
        upcomingTransitions: _mode == PlaybackMode.smartShuffle
            ? upcomingTransitions
            : const [],
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

    final idx = currentIndex.clamp(0, songs.length - 1).toInt();
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
    final idx = currentIndex.clamp(0, songs.length - 1).toInt();
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
  final bool djTransitionsEnabled;
  final BpmCache? analysis;

  const TransitionPolicy({
    this.djTransitionsEnabled = true,
    this.analysis,
  });

  // Plan transitions for the next 1–3 upcoming pairs. The UI and crossfade
  // listener only need a small lookahead.
  List<PlannedTransition> planUpcoming(List<Song> songs, int currentIndex) {
    if (songs.isEmpty || songs.length < 2) return const [];
    final idx = currentIndex.clamp(0, songs.length - 1).toInt();
    // Safety: if current index is at or past the end, no upcoming transitions.
    if (idx >= songs.length - 1) return const [];
    final transitions = <PlannedTransition>[];
    // Only plan up to 3 transitions ahead — enough for the UI preview and the
    // crossfade listener to peek at the next song, without O(n) allocation.
    final limit = (idx + 3).clamp(0, songs.length - 1).toInt();
    for (int i = idx; i < limit; i++) {
      transitions.add(planPair(songs[i], songs[i + 1]));
    }
    return transitions;
  }

  PlannedTransition planPair(Song from, Song to, {int? actualDurationSeconds}) {
    final durationSeconds = actualDurationSeconds ?? from.duration;

    // Safety: corrupted metadata may produce negative or zero duration.
    if (durationSeconds == null || durationSeconds <= 0) {
      return _gapless(from, to, 'unknown duration');
    }

    // Compute auto per-pair crossfade duration from BPM, energy, tail silence.
    final fadeSeconds = _computeAutoDuration(from, to,
        actualDurationSeconds: actualDurationSeconds);

    // --- Outro start detection ---
    // Use phrase boundaries when available: the crossfade should start at a
    // phrase boundary so we don't cut mid-phrase. If no phrase data, fall
    // back to duration minus tail silence.
    final rawTail = analysis?.tailSilenceFor(from) ?? 0.0;
    final maxTail = durationSeconds * 0.5;
    final tailSilence = rawTail.clamp(0.0, maxTail).toDouble();
    final effectiveMs =
        max(0, (durationSeconds * 1000) - (tailSilence * 1000).round());

    // Safety: the track must have at least 15 s of audible content.
    if (effectiveMs < 15000) {
      return _gapless(from, to, 'track too short');
    }

    // Cap fade duration to 1/3 of the effective track length, matching
    // the original safety rule. Phrase boundaries change where the fade
    // starts, not how long it lasts.
    final fadeMs = min(
      fadeSeconds * 1000,
      max(1000, effectiveMs ~/ 3),
    );

    int fromStartMs;
    final phrases = analysis?.phrasePositionsFor(from);
    if (phrases != null && phrases.isNotEmpty) {
      // Find the last phrase boundary that still leaves room for the actual
      // fade duration (fadeMs), not the requested fadeSeconds.
      final desiredStartSec =
          durationSeconds - tailSilence - (fadeMs / 1000.0);
      int? bestPhrase;
      for (final p in phrases.reversed) {
        if (p <= desiredStartSec) {
          bestPhrase = (p * 1000).round();
          break;
        }
      }
      fromStartMs = bestPhrase ?? max(0, effectiveMs - fadeMs);
    } else {
      fromStartMs = max(0, effectiveMs - fadeMs);
    }

    // --- Vocal-aware fromStart adjustment ---
    // If the crossfade would start inside a vocal section, nudge it earlier
    // to land in an instrumental gap.
    final vocals = analysis?.vocalSectionsFor(from);
    if (vocals != null && vocals.isNotEmpty) {
      final fadeStartSec = fromStartMs / 1000.0;
      final fadeEndSec = fadeStartSec + (fadeMs / 1000.0);
      bool overlapsVocal = false;
      for (final v in vocals) {
        if (v.start < fadeEndSec && v.end > fadeStartSec) {
          overlapsVocal = true;
          break;
        }
      }
      if (overlapsVocal) {
        // Try to find the last instrumental gap before the fade window.
        int? candidateMs;
        // Start from the desired fade start and walk backward.
        for (int probeSec = fadeStartSec.round();
            probeSec >= 15;
            probeSec--) {
          final probeStart = probeSec.toDouble();
          final probeEnd = probeStart + (fadeMs / 1000.0);
          bool probeClean = true;
          for (final v in vocals) {
            if (v.start < probeEnd && v.end > probeStart) {
              probeClean = false;
              break;
            }
          }
          if (probeClean) {
            candidateMs = probeSec * 1000;
            break;
          }
        }
        if (candidateMs != null) {
          fromStartMs = candidateMs;
        }
      }
    }

    // --- Beat-grid aligned toStart ---
    // Start the incoming song on its first detected beat so the crossfade
    // lands on a downbeat. If no beat-grid data, start at 0.
    final beatOffset = analysis?.firstBeatOffsetFor(to);
    final toStartMs = beatOffset != null && beatOffset >= 0
        ? (beatOffset * 1000).round()
        : 0;

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
      fromStart: Duration(milliseconds: fromStartMs),
      toStart: Duration(milliseconds: toStartMs),
      reason: reason,
    );
  }

  /// Compute an auto per-pair crossfade duration based on BPM, energy
  /// differential, tail silence, and track length. Returns seconds in [2,12].
  int _computeAutoDuration(Song from, Song to,
      {int? actualDurationSeconds}) {
    final bpm = analysis?.bpmFor(from);
    final tailSilence = analysis?.tailSilenceFor(from) ?? 0.0;
    final fromEnergy = analysis?.energyFor(from);
    final toEnergy = analysis?.energyFor(to);
    final duration = actualDurationSeconds ?? from.duration;

    // Base: 16 beats at from-song BPM, or 6 s default.
    double seconds;
    if (bpm != null && bpm > 0) {
      seconds = (16 * 60) / bpm;
    } else {
      seconds = 6.0;
    }

    // Clamp to usable range.
    seconds = seconds.clamp(2.0, 12.0);

    // Energy differential: big gap → snappier; similar → smoother/longer.
    if (fromEnergy != null && toEnergy != null) {
      final diff = (fromEnergy - toEnergy).abs();
      if (diff > 0.30) {
        seconds *= 0.75;
      } else if (diff < 0.10) {
        seconds *= 1.15;
      }
    }

    // Tail silence adjustment — only when we have real data (> 0).
    if (tailSilence > 0.0 && tailSilence < 2.0) {
      // Short tail → don't cut into actual content.
      seconds = seconds.clamp(2.0, max(2.0, tailSilence * 1.5));
    } else if (tailSilence > 8.0) {
      // Long tail → room for a longer blend.
      seconds = min(seconds * 1.1, 12.0);
    }

    // Track length safety cap.
    if (duration != null && duration > 0) {
      final maxFade = (duration * 0.35).clamp(2.0, 12.0).toDouble();
      seconds = seconds.clamp(2.0, maxFade);
    }

    // Short tracks get shorter fades.
    if (duration != null && duration < 90) {
      seconds = seconds.clamp(2.0, 4.0);
    }

    return seconds.round().clamp(2, 12).toInt();
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
