import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../api/companion_audio_api.dart';
import '../models/song.dart';


// ---------------------------------------------------------------------------
// TransitionMixManager
//
// Manages the lifecycle of time-stretched transition mixes from the companion
// server.  For each adjacent pair in a playlist, it:
//   1. Requests a mix WAV from the companion API
//   2. Polls until the mix is ready (or the job falls back)
//   3. Inserts the mix WAV between the two songs in the audio source
//   4. Offsets Song B to skip the head that was already consumed in the mix
//
// Every failure mode has a fallback — the manager never blocks playback.
// ---------------------------------------------------------------------------

/// Max number of concurrent mix requests (companion-side worker pool).
const _kMaxConcurrentMixes = 3;

/// How often to poll a pending mix job.
const _kPollInterval = Duration(seconds: 2);

/// Max polls before abandoning a mix job (60 s total).
const _kMaxPolls = 30;

/// Default mix window in seconds.
const _kDefaultMixDuration = 10.0;

/// Minimum queue length to bother prefetching mixes.
const _kMinQueueForMixes = 4;

class TransitionMixManager {
  final CompanionAudioApi _api;

  ConcatenatingAudioSource? _source;
  List<Song> _baseSongs = const [];
  final _insertedPairs = <String>{};
  final _pendingJobs = <String, _MixJob>{};
  final _fallbackPairs = <String>{};
  bool _disposed = false;

  /// How many transitions ahead to prefetch (1 = only the next pair).
  int prefetchAhead = 3;

  /// Callback invoked when a mix WAV is successfully inserted.
  /// Passes the destination song ID and the mix duration in seconds,
  /// so the caller can offset the destination song to skip its consumed intro.
  void Function(String destSongId, double offsetSeconds)? onMixInserted;

  TransitionMixManager({required CompanionAudioApi api}) : _api = api;

  /// Mix window duration exposed so callers can offset songs by the same amount.
  double get mixDurationSeconds => _kDefaultMixDuration;

  /// Attach to a new queue.  Clears all previous state.
  void attach(ConcatenatingAudioSource source, List<Song> baseSongs) {
    if (_disposed) return;
    _cancelAllJobs();
    _source = source;
    _baseSongs = List.from(baseSongs);
    _insertedPairs.clear();
    _fallbackPairs.clear();
  }

  /// Disconnect from the current queue and cancel all pending jobs.
  void detach() {
    _cancelAllJobs();
    _source = null;
    _baseSongs = const [];
  }

  /// Request mixes for upcoming transitions starting from [fromIndex].
  /// Call this after the source is built and whenever playback advances.
  void prefetch(int fromIndex) {
    if (_disposed || _source == null) return;
    if (_baseSongs.length < _kMinQueueForMixes) return;

    int started = 0;
    for (int i = fromIndex;
        i < _baseSongs.length - 1 && started < _kMaxConcurrentMixes;
        i++) {
      final a = _baseSongs[i];
      final b = _baseSongs[i + 1];
      final pairId = _pairKey(a.id, b.id);

      if (_insertedPairs.contains(pairId) ||
          _pendingJobs.containsKey(pairId) ||
          _fallbackPairs.contains(pairId)) {
        continue;
      }

      // Check BPM gap — skip if too wide for time-stretching.
      // This early check avoids wasting a companion request.
      final bpmA = _companionBpm?[a.id];
      final bpmB = _companionBpm?[b.id];
      if (bpmA != null && bpmB != null) {
        final ratio = bpmA > bpmB ? bpmA / bpmB : bpmB / bpmA;
        if (ratio > 1.15) {
          _fallbackPairs.add(pairId);
          continue;
        }
      }

      _requestMix(i, a, b, pairId);
      started++;
    }
  }

  /// Notify the manager that playback skipped to [songIndex].  Cancels any
  /// pending mixes that are now stale (pairs before the current position
  /// that haven't been inserted yet).
  void onSkipTo(int songIndex) {
    if (_disposed) return;
    // Cancel pending jobs for pairs that are now behind us.
    final staleIds = <String>[];
    for (final entry in _pendingJobs.entries) {
      if (entry.value.transitionIndex < songIndex - 1) {
        staleIds.add(entry.key);
      }
    }
    for (final id in staleIds) {
      _pendingJobs.remove(id)?.cancel();
    }
  }

  /// Remove any inserted mix sources that are at or after [fromIndex]
  /// (used when the source is being rebuilt).
  void clearInsertedAfter(int fromIndex) {
    // Can't easily remove from ConcatenatingAudioSource without knowing
    // exact positions.  Instead, mark all pairs from this index as
    // needing re-insertion on next prefetch.
    _insertedPairs.clear();
  }

  /// Notify the manager that the audio source was mutated externally (playNext,
  /// addToQueue, removeFromQueue, reorderQueue).  Clears pending and inserted
  /// state so prefetch re-requests mixes for the new arrangement.
  void sourceMutated() {
    // Cancel pending jobs but keep _insertedPairs/_fallbackPairs so already-
    // inserted mixes aren't re-requested. _findSongById handles dynamic lookup.
    for (final job in _pendingJobs.values) {
      job.cancel();
    }
    _pendingJobs.clear();
  }

  void dispose() {
    _disposed = true;
    _cancelAllJobs();
    _source = null;
    _baseSongs = const [];
  }

  // ---------------------------------------------------------------------------
  // Internal helpers

  // Set externally to provide companion BPM data for the early BPM-gap check.
  Map<String, int>? _companionBpm;
  set companionBpm(Map<String, int>? bpm) => _companionBpm = bpm;

  void _requestMix(int index, Song a, Song b, String pairId) {
    final job = _MixJob(
      pairId: pairId,
      transitionIndex: index,
      onMixInserted: onMixInserted,
    );
    _pendingJobs[pairId] = job;
    job.start(index, a, b, _api, _source!, _insertedPairs, _fallbackPairs,
        () => _pendingJobs.remove(pairId));
  }

  void _cancelAllJobs() {
    for (final job in _pendingJobs.values) {
      job.cancel();
    }
    _pendingJobs.clear();
    _insertedPairs.clear();
    _fallbackPairs.clear();
  }

  static String _pairKey(String aId, String bId) => '$aId→$bId';
}

// ---------------------------------------------------------------------------
// Internal state for a single mix request

class _MixJob {
  final String pairId;
  final int transitionIndex;
  final void Function(String destSongId, double offsetSeconds)? onMixInserted;
  bool _cancelled = false;

  _MixJob({
    required this.pairId,
    required this.transitionIndex,
    this.onMixInserted,
  });

  void cancel() => _cancelled = true;

  static String _resolveUrl(CompanionAudioApi api, String url) {
    final uri = Uri.tryParse(url);
    if (uri != null && uri.hasScheme) return url;
    return '${api.serverUrl}$url';
  }

  Future<void> start(
    int index,
    Song a,
    Song b,
    CompanionAudioApi api,
    ConcatenatingAudioSource source,
    Set<String> insertedPairs,
    Set<String> fallbackPairs,
    VoidCallback onDone,
  ) async {
    try {
      final result = await api.requestTransition(
        songAId: a.id,
        songBId: b.id,
        mixDuration: _kDefaultMixDuration,
      );
      if (_cancelled || result == null) return;

      final jobId = result['job_id'] as String?;
      if (jobId != null) {
        // Async mix — poll for completion
        await _poll(jobId, api, source, a, b, insertedPairs, fallbackPairs, index);
      } else if (result['status'] == 'ok' || result['cached'] == true) {
        final url = result['url'] as String?;
        if (url != null && !_cancelled) {
          await _insertMix(index, source, a, b,
              _resolveUrl(api, url), insertedPairs, fallbackPairs);
        }
      }
    } catch (e) {
      if (!_cancelled) {
        debugPrint('TransitionMix: request failed for $pairId: $e');
        fallbackPairs.add(pairId);
      }
    } finally {
      onDone();
    }
  }

  Future<void> _poll(
    String jobId,
    CompanionAudioApi api,
    ConcatenatingAudioSource source,
    Song a,
    Song b,
    Set<String> insertedPairs,
    Set<String> fallbackPairs,
    int index,
  ) async {
    for (int i = 0; i < _kMaxPolls && !_cancelled; i++) {
      await Future.delayed(_kPollInterval);
      if (_cancelled) return;

      final status = await api.pollTransition(jobId);
      if (status == null) continue;

      switch (status['status']) {
        case 'done':
          final url = status['url'] as String?;
          if (url != null && !_cancelled) {
            await _insertMix(index, source, a, b,
                _resolveUrl(api, url), insertedPairs, fallbackPairs);
          }
          return;
        case 'fallback':
          if (!_cancelled) fallbackPairs.add(pairId);
          return;
        case 'error':
          if (!_cancelled) {
            debugPrint('TransitionMix: job $jobId error: ${status['error']}');
            fallbackPairs.add(pairId);
          }
          return;
        case 'mixing':
          continue; // poll again
      }
    }
    if (!_cancelled) fallbackPairs.add(pairId);
  }

  Future<void> _insertMix(
    int index,
    ConcatenatingAudioSource source,
    Song a,
    Song b,
    String url,
    Set<String> insertedPairs,
    Set<String> fallbackPairs,
  ) async {
    if (_cancelled || insertedPairs.contains(pairId)) return;

    // Find Song A's current position in the source (it may have shifted
    // due to previous mix insertions).
    final pos = _findSongById(source, a.id);
    if (pos < 0) {
      // Song A is no longer in the source — skip (user may have cleared the queue).
      if (!_cancelled) fallbackPairs.add(pairId);
      return;
    }

    final mixSource = AudioSource.uri(
      Uri.parse(url),
      tag: 'transition:$pairId',
    );

    try {
      await source.insert(pos + 1, mixSource);
      if (!_cancelled) {
        insertedPairs.add(pairId);
        // Notify so the handler can offset Song B's playback start.
        onMixInserted?.call(b.id, _kDefaultMixDuration);
      }
      debugPrint('TransitionMix: inserted mix for $pairId');
    } catch (e) {
      if (!_cancelled) {
        debugPrint('TransitionMix: insert failed for $pairId: $e');
        fallbackPairs.add(pairId);
      }
    }
  }

  int _findSongById(ConcatenatingAudioSource source, String songId) {
    for (int i = 0; i < source.length; i++) {
      final child = source[i];
      if (child is IndexedAudioSource) {
        final tag = child.tag;
        if (tag is Song && tag.id == songId) return i;
      }
    }
    return -1;
  }

}
