import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:just_audio/just_audio.dart';
import '../models/song.dart';
import '../api/subsonic_client.dart';
import '../linux/linux_mpris.dart';
import 'playback_core.dart';
import 'shuffle_mode.dart';
import 'smart_shuffle_engine.dart';

// Linux shuffle workaround:
// just_audio_media_kit does not implement setShuffleOrder, so just_audio's
// shuffle indices diverge from mpv's internal order. Fix: never call
// setShuffleModeEnabled on Linux. Instead, re-order the list at loadQueue()
// time and use a virtual playback index for mid-playback toggles.

// Audio handler. Bridges just_audio with audio_service for MediaSession,
// notifications, lock-screen controls, and media-button routing.

class MelodizeAudioHandler extends BaseAudioHandler {
  MelodizeAudioHandler() {
    _initStateSync();
    _initScrobbling();
    _initCrossfade();
    if (Platform.isLinux) {
      HardwareKeyboard.instance.addHandler(_handleMediaKey);
    }
  }

  final AudioPlayer player = AudioPlayer(
    audioLoadConfiguration: const AudioLoadConfiguration(
      androidLoadControl: AndroidLoadControl(
            // Start playback after 500 ms buffered (default ~2.5 s).
        bufferForPlaybackDuration: Duration(milliseconds: 500),
        bufferForPlaybackAfterRebufferDuration: Duration(seconds: 2),
        // 60 s max buffer so ExoPlayer can pre-buffer the next track.
        minBufferDuration: Duration(seconds: 20),
        maxBufferDuration: Duration(seconds: 60),
      ),
      darwinLoadControl: DarwinLoadControl(
        // AVQueuePlayer buffers automatically.
        preferredForwardBufferDuration: Duration(seconds: 30),
      ),
    ),
  );

  // Replaced on every loadQueue call to avoid an expensive clear() round-trip.
  ConcatenatingAudioSource _playlistSource = ConcatenatingAudioSource(
    children: [],
    useLazyPreparation: true,
  );

  SubsonicConfig? _config;
  String _streamQuality = 'lossless';
  StreamSubscription<Duration>? _crossfadeSub;
  // Single-player crossfade: no second deck, just a volume ramp on the
  // main player. Eliminates double-playback, handoff races, and seek
  // desyncs across platforms.
  Timer? _crossfadeTimer;
  bool _isTransitionFading = false;
  bool _crossfadeActive = false;
  int? _crossfadeNextIndex;

  /// User's preferred volume level (0.0–1.0).  Crossfade ramps are scaled
  /// relative to this so a user who likes quiet playback doesn't get blasted
  /// when a transition ends.
  double _userVolume = 1.0;

  Timer? _sleepTimer;
  bool _nowPlayingReported = false;
  bool _scrobbled = false;
  LinuxMprisService? _mpris;

  /// Safety timeout: if a crossfade fade-out completes but the player
  /// never auto-advances (e.g. network stall), restore volume after a
  /// few seconds so the user isn't stuck muted.
  Timer? _crossfadeTimeout;

  // Playback history for skipToPrevious in shuffle mode.
  final _shuffleHistory = <int>[]; // original-sequence indices (fallback)
  int? _lastHistoryIndex;

  // Unified shuffle state for both platforms.
  ShuffleMode _shuffleMode = ShuffleMode.off;
  final _shuffleModeCtrl = StreamController<ShuffleMode>.broadcast();

  // Virtual playback index → physical source index. Toggling shuffle is
  // instant because the physical source never changes.
  List<int> _shuffleOrder = [];
  int _shufflePos = 0;

  // Inverted map for O(1) virtual position lookups.
  Map<int, int> _physicalToVirtual = {};

  // Last physical index. Distinguishes auto-advance from programmatic seeks.
  int? _lastKnownPhysicalIndex;

  // Guard against re-entering virtual-order correction during an in-flight seek.
  bool _correctingAutoAdvance = false;

  final PlaybackQueue _queue = PlaybackQueue();
  final PlaybackPlanner _planner = PlaybackPlanner();
  final _queueSnapshotCtrl =
      StreamController<PlaybackQueueSnapshot>.broadcast();

  // Full logical song list from the last loadQueue().
  List<Song> _loadQueueSongs = [];

  // Guard while programmatically seeking to a virtual position.
  bool _seekingVirtual = false;

  /// Expose current mode for external readers (e.g. MPRIS).
  ShuffleMode get currentShuffleMode => _shuffleMode;

  /// Optional companion analysis cache for real BPM/key data.
  BpmCache? _companionBpmCache;

  DateTime _lastSnapshotEmit = DateTime(2000);
  bool _loading = false;

  Timer? _recalcDebounceTimer;
  int? _shuffleSeed;
  bool _snapshotRecalculating = false;

  void setCompanionAnalysis(BpmCache? cache) {
    // Guard: only recalculate if the analysis data actually changed.
    // The companion provider refreshes every ~30 s via health polling;
    // without this guard the smart-shuffle queue would jump constantly.
    if (_isSameCompanionCache(_companionBpmCache, cache)) {
      return;
    }
    _companionBpmCache = cache;
    // Invalidate transition-plan cache so transition pills update.
    _cachedNormalSnapshot = null;
    _cachedShuffleOrder = null;
    _cachedPlannedSongs = null;
    // Re-plan when real data arrives mid-session.
    if (_shuffleMode == ShuffleMode.smartShuffle) {
      _recalculateShuffleOrder();
    } else {
      _emitQueueSnapshot(immediate: true);
    }
  }

  static bool _isSameCompanionCache(BpmCache? a, BpmCache? b) {
    if (identical(a, b)) return true;
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (!_mapEquals(a.bpm, b.bpm)) return false;
    if (!_mapEquals(a.key, b.key)) return false;
    if (!_mapEquals(a.isEstimated, b.isEstimated)) return false;
    if (!_mapEquals(a.tailSilence, b.tailSilence)) return false;
    if (!_mapEquals(a.energy, b.energy)) return false;
    if (!_mapEquals(a.spectralCentroid, b.spectralCentroid)) return false;
    if (!_mapEquals(a.firstBeatOffset, b.firstBeatOffset)) return false;
    if (!_vocalSectionsEquals(a.vocalSections, b.vocalSections)) return false;
    if (!_phrasePositionsEquals(a.phrasePositions, b.phrasePositions)) {
      return false;
    }
    if (!_mapEquals(a.genreCache, b.genreCache)) return false;
    if (!_mapEquals(a.parsedKeyCache, b.parsedKeyCache)) return false;
    return true;
  }

  static bool _phrasePositionsEquals(
    Map<String, List<double>> a,
    Map<String, List<double>> b,
  ) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      final other = b[entry.key];
      if (other == null || other.length != entry.value.length) return false;
      for (int i = 0; i < entry.value.length; i++) {
        if (other[i] != entry.value[i]) return false;
      }
    }
    return true;
  }

  static bool _vocalSectionsEquals(
    Map<String, List<VocalSection>> a,
    Map<String, List<VocalSection>> b,
  ) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      final other = b[entry.key];
      if (other == null || other.length != entry.value.length) return false;
      for (int i = 0; i < entry.value.length; i++) {
        if (other[i].start != entry.value[i].start ||
            other[i].end != entry.value[i].end) {
          return false;
        }
      }
    }
    return true;
  }

  static bool _mapEquals<K, V>(Map<K, V> a, Map<K, V> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (!b.containsKey(entry.key) || b[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }

  // Restore persisted shuffle mode on startup.
  void restoreShuffleMode(ShuffleMode mode) {
    _shuffleMode = mode;
    _queue.setMode(_playbackModeFor(mode));
    _shuffleModeCtrl.add(mode);

    _ensureShuffleSeed();
    _recalculateShuffleOrder();
  }

  /// Ensures a deterministic seed exists whenever shuffle is active.
  /// If the user loaded a queue in normal mode then later toggled shuffle,
  /// [_shuffleSeed] would still be null, causing every recalculation to
  /// generate a brand-new random order. This fixes that.
  void _ensureShuffleSeed() {
    if (_shuffleMode != ShuffleMode.off && _shuffleSeed == null) {
      _shuffleSeed = DateTime.now().microsecondsSinceEpoch;
    }
  }

  Stream<ShuffleMode> get shuffleModeStream => _shuffleModeCtrl.stream;

  Stream<PlaybackQueueSnapshot> get queueSnapshotStream =>
      _queueSnapshotCtrl.stream;

  PlaybackQueueSnapshot get queueSnapshot => _snapshot();

  void _initStateSync() {
    player.playerStateStream.listen((_) => _broadcastState());

    // Restore volume if a playback error happens during a crossfade so
    // the user isn't left muted.
    player.playbackEventStream.listen((event) {
      if (event.processingState == ProcessingState.idle &&
          _isTransitionFading) {
        _cancelCrossfade();
      }
    });

    // Clear media item on idle/completed so OriginOS doesn't show stale info.
    player.processingStateStream.listen((state) {
      if (state == ProcessingState.idle || state == ProcessingState.completed) {
        mediaItem.add(null);
      }
    });      // Track shuffle history and correct auto-advance in virtual orders.
      player.currentIndexStream.listen((index) {
      if (index == null) return;
      if (_queueSnapshotCtrl.isClosed || _playlistSource.length == 0) return;

      final prevPhysical = _lastKnownPhysicalIndex;
      _lastKnownPhysicalIndex = index;
      if (_crossfadeActive && index == _crossfadeNextIndex) {
        // Natural auto-advance happened while a crossfade fade-out was
        // in progress. Start the fade-in on the new song.
        _startCrossfadeFadeIn();
      }
      if (_loading) return;

      if (_seekingVirtual) {
        final vp = _physicalToVirtual[index];
        if (vp != null) _shufflePos = vp;
        return;
      }

      if (_correctingAutoAdvance) {
        _correctingAutoAdvance = false;
        _queue.setCurrentIndex(index);
        _emitQueueSnapshot();
        final vp = _physicalToVirtual[index];
        if (vp != null) _shufflePos = vp;
        return;
      }

      _queue.setCurrentIndex(index);
      _emitQueueSnapshot();
      if (_shuffleMode == ShuffleMode.off) {
        _shuffleHistory.clear();
        _lastHistoryIndex = null;
        return;
      }
      if (_shuffleOrder.isNotEmpty) {
          // Only correct on natural auto-advance (index + 1).
        final isAutoAdvance = prevPhysical != null && index == prevPhysical + 1;
        if (isAutoAdvance) {
          final nextVp = _shufflePos + 1;
          if (nextVp < _shuffleOrder.length) {
            final expectedPhysical = _shuffleOrder[nextVp];
            if (index != expectedPhysical &&
                expectedPhysical >= 0 &&
                expectedPhysical < _playlistSource.length) {
              _shufflePos = nextVp;
              _seekingVirtual = true;
              _correctingAutoAdvance = true;
              Future.microtask(() {
                player
                    .seek(Duration.zero, index: expectedPhysical)
                    .then((_) => _seekingVirtual = false)
                    .catchError((_) => _seekingVirtual = false);
              });
              return;
            }
          }
        }
        final vp = _physicalToVirtual[index];
        if (vp != null) _shufflePos = vp;
      } else {
        if (_lastHistoryIndex != null && _lastHistoryIndex != index) {
          _shuffleHistory.add(_lastHistoryIndex!);
          if (_shuffleHistory.length > 100) _shuffleHistory.removeAt(0);
        }
        _lastHistoryIndex = index;
      }
    });

    // Update MediaSession media item on song change. Broadcast position=0
    // immediately so the system player shows the correct time.
    player.sequenceStateStream.listen((seqState) {
      final rawTag = seqState?.currentSource?.tag;
      final song = rawTag is Song ? rawTag : null;

      if (song == null) {
        mediaItem.add(null);
        return;
      }

      Uri? artUri;
      if (_config != null && (song.coverArt?.isNotEmpty ?? false)) {
        artUri =
            Uri.tryParse(SubsonicClient(_config!).coverArtUrl(song.coverArt!));
      } else if (song.externalCoverUrl != null) {
        artUri = Uri.tryParse(song.externalCoverUrl!);
      }
      mediaItem.add(MediaItem(
        id: song.id,
        title: song.title,
        artist: song.artist,
        album: song.album,
        duration:
            song.duration != null ? Duration(seconds: song.duration!) : null,
        artUri: artUri,
      ));
      _broadcastState(positionOverride: Duration.zero);
    });
  }

  void _broadcastState({Duration? positionOverride}) {
    final ps = player.processingState;
    // Report the virtual queue index to the system player so shuffle
    // positions match what the user sees in the app.
    int reportQueueIndex;
    if (_shuffleOrder.isNotEmpty) {
      final vp = _physicalToVirtual[player.currentIndex ?? -1];
      reportQueueIndex = vp ?? _shufflePos;
    } else {
      reportQueueIndex = player.currentIndex ?? 0;
    }
    playbackState.add(PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        player.playing ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.skipToPrevious,
        MediaAction.skipToNext,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: switch (ps) {
        ProcessingState.idle => AudioProcessingState.idle,
        ProcessingState.loading => AudioProcessingState.loading,
        ProcessingState.buffering => AudioProcessingState.buffering,
        ProcessingState.ready => AudioProcessingState.ready,
        ProcessingState.completed => AudioProcessingState.completed,
      },
      playing: player.playing,
      updatePosition: positionOverride ?? player.position,
      bufferedPosition: player.bufferedPosition,
      speed: player.speed,
      queueIndex: reportQueueIndex,
    ));
  }

  // ---------------------------------------------------------------------------

  void setConfig(SubsonicConfig config) {
    _config = config;
    // Only re-emit artUri while playing to avoid waking OriginOS Island.
    if (!player.playing) return;
    final current = mediaItem.valueOrNull;
    final song = currentSong;
    if (current != null &&
        song != null &&
        (song.coverArt?.isNotEmpty ?? false)) {
      mediaItem.add(current.copyWith(
        artUri:
            Uri.tryParse(SubsonicClient(config).coverArtUrl(song.coverArt!)),
      ));
    }
  }

  void setStreamQuality(String quality) => _streamQuality = quality;

  Song? get currentSong {
    final tag = player.sequenceState?.currentSource?.tag;
    if (tag is Song) return tag;
    return null;
  }

  Stream<Song?> get currentSongStream => player.sequenceStateStream.map((s) {
        final tag = s?.currentSource?.tag;
        if (tag is Song) return tag;
        return null;
      });

  PlaybackMode _playbackModeFor(ShuffleMode mode) => switch (mode) {
        ShuffleMode.off => PlaybackMode.normal,
        ShuffleMode.shuffle => PlaybackMode.shuffle,
        ShuffleMode.smartShuffle => PlaybackMode.smartShuffle,
      };

  TransitionPolicy get _transitionPolicy => TransitionPolicy(
        djTransitionsEnabled: _shuffleMode == ShuffleMode.smartShuffle,
        analysis: _companionBpmCache,
      );

  // Cached snapshot to avoid repeated List allocations.
  List<Song>? _cachedPlannedSongs;
  List<int>? _cachedShuffleOrder;
  int _cachedShuffleHash = 0;

  // Normal-mode snapshot cache.
  PlaybackQueueSnapshot? _cachedNormalSnapshot;
  int _cachedNormalQueueLength = -1;
  int _cachedNormalCurrentIndex = -1;
  PlaybackMode _cachedNormalMode = PlaybackMode.normal;
  int _cachedNormalCompanionHash = 0;

  PlaybackQueueSnapshot _snapshot() {
    if (_shuffleOrder.isNotEmpty &&
        _shufflePos < _shuffleOrder.length) {
      // Content-hash check for mutations that keep length but permute.
      // Mix in _playlistSource.length so replacing the queue with another
      // queue of the same length still invalidates the cache.
      var hash = _playlistSource.length;
      for (int i = 0; i < _shuffleOrder.length; i++) {
        hash = hash * 31 + _shuffleOrder[i];
      }
      if (_cachedShuffleOrder == null ||
          _cachedShuffleHash != hash ||
          !_listEquals(_cachedShuffleOrder!, _shuffleOrder)) {
        _cachedShuffleOrder = List.of(_shuffleOrder);
        _cachedShuffleHash = hash;
        _cachedPlannedSongs = _shuffleOrder.map((i) {
          if (i >= 0 && i < _playlistSource.length) {
            final child = _playlistSource[i];
            if (child is IndexedAudioSource) {
              final tag = child.tag;
              if (tag is Song) return tag;
            }
          }
          // Safety: index out of bounds — return a placeholder so the UI
          // doesn't crash; the next recalculation will fix the mapping.
          return _queue.songs.isNotEmpty ? _queue.songs[0] : Song.empty();
        }).toList();
      }
      final plannedSongs = _cachedPlannedSongs!;
      return PlaybackQueueSnapshot(
        songs: plannedSongs,
        currentIndex: _shufflePos.clamp(0, plannedSongs.length - 1),
        mode: _queue.mode,
        upcomingTransitions: _transitionPolicy.planUpcoming(
            plannedSongs, _shufflePos),
      );
    }
    // Shuffle is active but the virtual order is empty (e.g. after a rapid
    // queue mutation or a code path that cleared it). Rebuild immediately
    // rather than showing the stale fallback.
    if (_shuffleMode != ShuffleMode.off && _loadQueueSongs.length >= 2 &&
        !_snapshotRecalculating) {
      _snapshotRecalculating = true;
      _recalculateShuffleOrderImpl();
      _snapshotRecalculating = false;
      if (_shuffleOrder.isNotEmpty) {
        return _snapshot();
      }
    }

    _cachedShuffleOrder = null;
    _cachedPlannedSongs = null;
    _cachedShuffleHash = 0;

    // Cache normal-mode snapshots so the queue screen doesn't rebuild
    // on every position tick when nothing changed.
    final qLength = _queue.length;
    final qIndex = _queue.currentIndex;
    final qMode = _queue.mode;
    final companionHash = _companionBpmCache?.hashCode ?? 0;
    if (_cachedNormalSnapshot != null &&
        _cachedNormalQueueLength == qLength &&
        _cachedNormalCurrentIndex == qIndex &&
        _cachedNormalMode == qMode &&
        _cachedNormalCompanionHash == companionHash) {
      return _cachedNormalSnapshot!;
    }
    _cachedNormalQueueLength = qLength;
    _cachedNormalCurrentIndex = qIndex;
    _cachedNormalMode = qMode;
    _cachedNormalCompanionHash = companionHash;
    _cachedNormalSnapshot = _queue.snapshot(
      upcomingTransitions: _transitionPolicy.planUpcoming(
        _queue.songs,
        _queue.currentIndex,
      ),
    );
    return _cachedNormalSnapshot!;
  }

  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  // Emit a queue snapshot. [immediate] skips the 500 ms debounce.
  void _emitQueueSnapshot({bool immediate = false}) {
    if (_queueSnapshotCtrl.isClosed) return;
    if (!immediate) {
      final now = DateTime.now();
      if (now.difference(_lastSnapshotEmit).inMilliseconds < 150) return;
      _lastSnapshotEmit = now;
    }
    _queueSnapshotCtrl.add(_snapshot());
  }

  // ---------------------------------------------------------------------------
  // Queue management

  Future<void> loadQueue(List<Song> songs, {int startIndex = 0}) async {
    if (_config == null || songs.isEmpty || _loading) return;
    _loading = true;
    await _cancelCrossfade();
    _shuffleHistory.clear();
    _lastHistoryIndex = null;
    final idx = startIndex.clamp(0, songs.length - 1);
    final cache = buildBpmCache(songs,
        knownBpm: _companionBpmCache?.bpm,
        knownKeys: _companionBpmCache?.key,
        knownEnergy: _companionBpmCache?.energy,
        knownSpectralCentroid: _companionBpmCache?.spectralCentroid,
        knownTailSilence: _companionBpmCache?.tailSilence,
        knownPhrasePositions: _companionBpmCache?.phrasePositions,
        knownFirstBeatOffset: _companionBpmCache?.firstBeatOffset,
        knownVocalSections: _companionBpmCache?.vocalSections);
    songs = _planner.plan(
      songs: songs,
      currentIndex: idx,
      mode: _playbackModeFor(_shuffleMode),
      cache: cache,
      seed: DateTime.now().microsecondsSinceEpoch,
    );
    _queue.load(
      songs,
      startIndex: idx,
      mode: _playbackModeFor(_shuffleMode),
    );

    _loadQueueSongs = List.from(songs);
    _lastKnownPhysicalIndex = null;
    // Invalidate any stale snapshot cache from a previous queue.
    _cachedShuffleOrder = null;
    _cachedPlannedSongs = null;
    _cachedShuffleHash = 0;
    _cachedNormalSnapshot = null;
    _cachedNormalQueueLength = -1;
    _cachedNormalCurrentIndex = -1;
    if (_shuffleMode != ShuffleMode.off && songs.length > 1) {
      _shuffleOrder = List.generate(songs.length, (i) => i);
      _shufflePos = idx.clamp(0, _shuffleOrder.length - 1);
      _shuffleSeed = DateTime.now().microsecondsSinceEpoch;
      _physicalToVirtual = {
        for (int vp = 0; vp < _shuffleOrder.length; vp++)
          _shuffleOrder[vp]: vp,
      };
    } else {
      _shuffleOrder = [];
      _shufflePos = 0;
      _physicalToVirtual = {};
    }
    _emitQueueSnapshot(immediate: true);

    if (Platform.isLinux) {
      // Load the full queue upfront on Linux to avoid playlist-move bugs
      // in just_audio_media_kit / libmpv.
      _playlistSource = ConcatenatingAudioSource(
        children: songs.map(_songToSource).toList(),
        useLazyPreparation: true,
      );
      try {
        await player.setAudioSource(_playlistSource,
            initialIndex: idx, preload: false);
        await player.play();
      } catch (e) {
        debugPrint('loadQueue error: $e');
        _loading = false;
        return;
      }
      _loading = false;
      return;
    }

    // Mobile: build full queue upfront with preload:false for minimal latency.
    _playlistSource = ConcatenatingAudioSource(
      children: songs.map(_songToSource).toList(),
      useLazyPreparation: true,
    );
    try {
      await player.setAudioSource(_playlistSource,
          initialIndex: idx, preload: false);
      player.play().catchError((e) => debugPrint('loadQueue play: $e'));
    } catch (e) {
      debugPrint('loadQueue error: $e');
    } finally {
      _loading = false;
    }
  }

  Future<void> playNext(Song song) async {
    await _cancelCrossfade();
    if (_config == null) return;
    final idx =
        ((player.currentIndex ?? 0) + 1).clamp(0, _playlistSource.length);
    _queue.playNext(song);
    _loadQueueSongs = List.from(_queue.songs);
    _cachedNormalSnapshot = null;
    await _playlistSource.insert(idx, _songToSource(song));
    _recalculateShuffleOrder();
  }

  Future<void> addToQueue(Song song) async {
    await _cancelCrossfade();
    if (_config == null) return;
    _queue.add(song);
    _loadQueueSongs = List.from(_queue.songs);
    _cachedNormalSnapshot = null;
    await _playlistSource.add(_songToSource(song));
    _recalculateShuffleOrder();
  }

  Future<void> removeFromQueue(int index) async {
    await _cancelCrossfade();
    final physicalIndex = (_shuffleOrder.isNotEmpty &&
            index >= 0 &&
            index < _shuffleOrder.length)
        ? _shuffleOrder[index]
        : index;
    if (physicalIndex < 0 ||
        physicalIndex >= _queue.songs.length ||
        physicalIndex >= _playlistSource.length) {
      return;
    }
    _queue.removeAt(physicalIndex);
    _loadQueueSongs = List.from(_queue.songs);
    _cachedNormalSnapshot = null;
    await _playlistSource.removeAt(physicalIndex);
    // Adjust virtual order in place so skip/next stay valid immediately.
    if (_shuffleOrder.isNotEmpty) {
      final removedVp = _physicalToVirtual[physicalIndex];
      _shuffleOrder = _shuffleOrder
          .where((i) => i != physicalIndex)
          .map((i) => i > physicalIndex ? i - 1 : i)
          .toList();
      if (removedVp != null && removedVp < _shufflePos) {
        _shufflePos--;
      }
      _shufflePos = _shufflePos.clamp(0, max(0, _shuffleOrder.length - 1));
      _physicalToVirtual = {
        for (int vp = 0; vp < _shuffleOrder.length; vp++)
          _shuffleOrder[vp]: vp,
      };
      _emitQueueSnapshot(immediate: true);
    }
    _recalculateShuffleOrder();
  }

  Future<void> removeSongById(String songId) async {
    await _cancelCrossfade();
    _queue.removeById(songId);
    _loadQueueSongs = List.from(_queue.songs);
    _cachedNormalSnapshot = null;
    for (int i = _playlistSource.length - 1; i >= 0; i--) {
      final child = _playlistSource[i];
      final tag = child is IndexedAudioSource ? child.tag : null;
      if (tag is Song && tag.id == songId) {
        await _playlistSource.removeAt(i);
      }
    }
    // Rebuild immediately so the virtual order is never stale.
    _recalculateShuffleOrderImpl();
  }

  Future<void> reorderQueue(int oldIndex, int newIndex) async {
    await _cancelCrossfade();
    // When shuffle is active, reorder the virtual playback order
    // instead of the physical source (which never changes mid-shuffle).
    if (_shuffleOrder.isNotEmpty) {
      final oldVp = oldIndex.clamp(0, _shuffleOrder.length - 1);
      final newVp = newIndex.clamp(0, _shuffleOrder.length - 1);
      if (oldVp == newVp) return;
      final moved = _shuffleOrder.removeAt(oldVp);
      _shuffleOrder.insert(newVp, moved);
      // Keep shufflePos pointing to the same song after the move.
      if (_shufflePos == oldVp) {
        _shufflePos = newVp;
      } else if (oldVp < _shufflePos && newVp >= _shufflePos) {
        _shufflePos--;
      } else if (oldVp > _shufflePos && newVp <= _shufflePos) {
        _shufflePos++;
      }
      // Rebuild the inverted map so virtual→physical lookups stay correct.
      _physicalToVirtual = {
        for (int vp = 0; vp < _shuffleOrder.length; vp++)
          _shuffleOrder[vp]: vp,
      };
      _emitQueueSnapshot(immediate: true);
      return;
    }
    _queue.reorder(oldIndex, newIndex);
    _loadQueueSongs = List.from(_queue.songs);
    _cachedNormalSnapshot = null;
    if (oldIndex >= 0 &&
        oldIndex < _playlistSource.length &&
        newIndex >= 0 &&
        newIndex < _playlistSource.length) {
      await _playlistSource.move(oldIndex, newIndex);
    }
    _recalculateShuffleOrder();
  }

  // Playback controls (override for audio_service media buttons)

  @override
  Future<void> play() => player.play();

  @override
  Future<void> pause() async {
    await _cancelCrossfade();
    await player.pause();
  }

  @override
  Future<void> stop() async {
    await _cancelCrossfade();
    await player.stop();
  }

  @override
  Future<void> seek(Duration position) async {
    await _cancelCrossfade();
    await player.seek(position);
  }

  @override
  Future<void> skipToNext() async {
    await _cancelCrossfade();
    if (_shuffleOrder.isNotEmpty) {
      final nextVp = _shufflePos + 1;
      if (nextVp < _shuffleOrder.length) {
        _shufflePos = nextVp;
        final targetIndex = _shuffleOrder[_shufflePos];
        _seekingVirtual = true;
        try {
          if (targetIndex >= 0 && targetIndex < _playlistSource.length) {
            await player.seek(Duration.zero, index: targetIndex);
            _queue.setCurrentIndex(targetIndex);
          } else {
            debugPrint('skipToNext: targetIndex $targetIndex out of bounds '
                '(source length ${_playlistSource.length})');
          }
        } catch (e) {
          debugPrint('skipToNext seek error: $e');
        }
        _emitQueueSnapshot(immediate: true);
        Future.microtask(() => _seekingVirtual = false);
        return;
      }
      // Wrap around to the beginning of the virtual order so the queue
      // stays in shuffle/smart-shuffle mode instead of reverting to the
      // original playlist order.
      _shufflePos = 0;
      final targetIndex = _shuffleOrder[_shufflePos];
      _seekingVirtual = true;
      try {
        if (targetIndex >= 0 && targetIndex < _playlistSource.length) {
          await player.seek(Duration.zero, index: targetIndex);
          _queue.setCurrentIndex(targetIndex);
        }
      } catch (e) {
        debugPrint('skipToNext wrap-around seek error: $e');
      }
      _emitQueueSnapshot(immediate: true);
      Future.microtask(() => _seekingVirtual = false);
      return;
    }
    await player.seekToNext();
  }

  @override
  Future<void> skipToPrevious() async {
    await _cancelCrossfade();
    if (player.position.inSeconds > 3) {
      await player.seek(Duration.zero);
      return;
    }
    if (_shuffleOrder.isNotEmpty) {
      // Navigate back in the virtual order.  At position 0, wrap to the
      // last song (matches wrap-around behavior of most music players).
      if (_shufflePos > 0) {
        _shufflePos--;
      } else {
        _shufflePos = _shuffleOrder.length - 1;
      }
      final targetIndex = _shuffleOrder[_shufflePos];
      _seekingVirtual = true;
      try {
        if (targetIndex >= 0 && targetIndex < _playlistSource.length) {
          await player.seek(Duration.zero, index: targetIndex);
          _queue.setCurrentIndex(targetIndex);
        }
      } catch (e) {
        debugPrint('skipToPrevious seek error: $e');
      }
      _emitQueueSnapshot(immediate: true);
      Future.microtask(() => _seekingVirtual = false);
      return;
    } else if (_shuffleMode != ShuffleMode.off && _shuffleHistory.isNotEmpty) {
      final prevIndex = _shuffleHistory.removeLast();
      _seekingVirtual = true;
      _lastHistoryIndex = prevIndex;
      try {
        await player.seek(Duration.zero, index: prevIndex);
        _queue.setCurrentIndex(prevIndex);
        _emitQueueSnapshot(immediate: true);
      } finally {
        Future.microtask(() => _seekingVirtual = false);
      }
    } else {
      await player.seekToPrevious();
    }
  }

  Future<void> skipToIndex(int index) async {
    await _cancelCrossfade();
    _seekingVirtual = true;
    int physicalIndex = index;
    if (_shuffleOrder.isNotEmpty) {
      if (index >= 0 && index < _shuffleOrder.length) {
        _shufflePos = index;
        physicalIndex = _shuffleOrder[_shufflePos];
      } else {
        // Target is outside the virtual order — user broke out, clear it.
        _shuffleOrder = [];
        _shufflePos = 0;
      }
    }
    // Clamp to valid player bounds so seek doesn't throw on a stale index.
    final maxIndex = _playlistSource.length > 0 ? _playlistSource.length - 1 : 0;
    physicalIndex = physicalIndex.clamp(0, maxIndex);
    await player.seek(Duration.zero, index: physicalIndex);
    _queue.setCurrentIndex(physicalIndex);
    _emitQueueSnapshot(immediate: true);
    Future.microtask(() => _seekingVirtual = false);
  }

  /// Debounced wrapper for [_recalculateShuffleOrderImpl]. Rapid queue
  /// mutations (e.g. removing 5 songs in a row) coalesce into a single
  /// recalculation instead of blocking the UI thread 5 times with O(N²) work.
  void _recalculateShuffleOrder() {
    _recalcDebounceTimer?.cancel();
    _recalcDebounceTimer = Timer(const Duration(milliseconds: 150), () {
      _recalculateShuffleOrderImpl();
    });
  }

  /// Calculate a virtual playback order for the current [shuffleMode].
  ///
  /// Reads the currently loaded songs from [_playlistSource] and builds an
  /// index list that maps playback-position → physical-source-index.  When
  /// the list is non-empty [skipToNext] and [skipToPrevious] follow it.
  ///
  /// Called on mid-playback toggle — no source rebuild, instant (~O(n)).
  void _recalculateShuffleOrderImpl() {
    final loaded = _playlistSource.length;
    if (loaded < 2 || _loadQueueSongs.length < 2) {
      _shuffleOrder = [];
      _shufflePos = 0;
      _physicalToVirtual = {};
      _queue.setMode(_playbackModeFor(_shuffleMode));
      _emitQueueSnapshot(immediate: true);
      return;
    }

    _queue.setMode(_playbackModeFor(_shuffleMode));

    switch (_shuffleMode) {
      case ShuffleMode.off:
        _shuffleOrder = [];
        _shufflePos = 0;
        break;

      case ShuffleMode.shuffle:
        {
          final currentIdx = player.currentIndex ?? _queue.currentIndex;
          final planned = _planner.plan(
            songs: _loadQueueSongs,
            currentIndex: currentIdx,
            mode: PlaybackMode.shuffle,
            seed: _shuffleSeed ?? DateTime.now().microsecondsSinceEpoch,
          );
          // Build the physical-index map from the actual player source so
          // that virtual indices always point to the correct source slot.
          // Use a list-of-indices approach so duplicate song IDs are handled
          // correctly (each planned song consumes the next available slot).
          final physIndicesById = <String, List<int>>{};
          for (int i = 0; i < _playlistSource.length; i++) {
            final child = _playlistSource[i];
            if (child is IndexedAudioSource) {
              final tag = child.tag;
              if (tag is Song) {
                physIndicesById.putIfAbsent(tag.id, () => []).add(i);
              }
            }
          }
          final nextIndex = <String, int>{};
          _shuffleOrder = planned.map((s) {
            final indices = physIndicesById[s.id];
            if (indices == null) return -1;
            final i = nextIndex.putIfAbsent(s.id, () => 0);
            if (i >= indices.length) return -1;
            nextIndex[s.id] = i + 1;
            return indices[i];
          }).where((i) => i >= 0).toList();
          _shufflePos = _shuffleOrder.indexOf(currentIdx);
          if (_shufflePos < 0) _shufflePos = 0;
          _physicalToVirtual = {
            for (int vp = 0; vp < _shuffleOrder.length; vp++)
              _shuffleOrder[vp]: vp,
          };
          break;
        }

      case ShuffleMode.smartShuffle:
        {
          if (_loadQueueSongs.length < 2) {
            _shuffleOrder = [];
            _shufflePos = 0;
            _physicalToVirtual = {};
            break;
          }
          final currentIdx = (player.currentIndex ?? _queue.currentIndex)
              .clamp(0, _loadQueueSongs.length - 1);
          final cache = buildBpmCache(_loadQueueSongs,
              knownBpm: _companionBpmCache?.bpm,
              knownKeys: _companionBpmCache?.key,
              knownEnergy: _companionBpmCache?.energy,
              knownSpectralCentroid: _companionBpmCache?.spectralCentroid,
              knownTailSilence: _companionBpmCache?.tailSilence,
              knownPhrasePositions: _companionBpmCache?.phrasePositions,
              knownFirstBeatOffset: _companionBpmCache?.firstBeatOffset,
              knownVocalSections: _companionBpmCache?.vocalSections);
          final ordered = _planner.plan(
            songs: _loadQueueSongs,
            currentIndex: currentIdx.clamp(0, _loadQueueSongs.length - 1),
            mode: PlaybackMode.smartShuffle,
            cache: cache,
            seed: _shuffleSeed ?? DateTime.now().microsecondsSinceEpoch,
          );

          // Build virtual order: map each ordered song to its physical index
          // in the actual player source so navigation always targets the
          // correct source slot.  Duplicate-safe so the same song ID appearing
          // multiple times in the queue doesn't collapse into a single index.
          final physIndicesById = <String, List<int>>{};
          for (int i = 0; i < _playlistSource.length; i++) {
            final child = _playlistSource[i];
            if (child is IndexedAudioSource) {
              final tag = child.tag;
              if (tag is Song) {
                physIndicesById.putIfAbsent(tag.id, () => []).add(i);
              }
            }
          }
          final nextIndex = <String, int>{};
          _shuffleOrder = ordered.map((s) {
            final indices = physIndicesById[s.id];
            if (indices == null) return -1;
            final i = nextIndex.putIfAbsent(s.id, () => 0);
            if (i >= indices.length) return -1;
            nextIndex[s.id] = i + 1;
            return indices[i];
          }).where((i) => i >= 0).toList();
          _shufflePos = _shuffleOrder.indexOf(currentIdx);
          if (_shufflePos < 0) _shufflePos = 0;
          _physicalToVirtual = {
            for (int vp = 0; vp < _shuffleOrder.length; vp++)
              _shuffleOrder[vp]: vp,
          };
          break;
        }
    }
    _emitQueueSnapshot(immediate: true);
  }

  // ---------------------------------------------------------------------------
  // 3-state shuffle: Off → Shuffle → Smart Shuffle → Off

  /// Cycle through Off → Shuffle → Smart Shuffle → Off.
  /// Recalculates the virtual order — the current song keeps playing;
  /// skipToNext will navigate to the first song in the new order.
  Future<void> toggleShuffle() async {
    switch (_shuffleMode) {
      case ShuffleMode.off:
        _shuffleMode = ShuffleMode.shuffle;
      case ShuffleMode.shuffle:
        _shuffleMode = ShuffleMode.smartShuffle;
      case ShuffleMode.smartShuffle:
        _shuffleMode = ShuffleMode.off;
    }
    _shuffleModeCtrl.add(_shuffleMode);
    _shuffleHistory.clear();
    _lastHistoryIndex = null;

    _ensureShuffleSeed();
    _recalculateShuffleOrder();
  }

  /// Directly set the shuffle mode (used by playlist "Shuffle" button, etc.).
  /// Also recalculates the virtual order.
  void applyShuffleMode(ShuffleMode mode) {
    _shuffleMode = mode;
    _shuffleModeCtrl.add(mode);
    _shuffleHistory.clear();
    _lastHistoryIndex = null;

    _ensureShuffleSeed();
    _recalculateShuffleOrder();
  }

  Future<void> resetPlaybackModes() async {
    _shuffleMode = ShuffleMode.off;
    _queue.setMode(PlaybackMode.normal);
    _shuffleModeCtrl.add(ShuffleMode.off);
    _shuffleOrder = [];
    _shufflePos = 0;
    _shuffleHistory.clear();
    _lastHistoryIndex = null;
    await player.setLoopMode(LoopMode.off);
    _emitQueueSnapshot(immediate: true);
  }

  Future<void> cycleLoopMode() async {
    switch (player.loopMode) {
      case LoopMode.off:
        await player.setLoopMode(LoopMode.all);
      case LoopMode.all:
        await player.setLoopMode(LoopMode.one);
      case LoopMode.one:
        await player.setLoopMode(LoopMode.off);
    }
  }

  // ---------------------------------------------------------------------------
  // Sleep timer

  void setSleepTimer(Duration duration) {
    _sleepTimer?.cancel();
    _sleepTimer = Timer(duration, () async {
      await player.pause();
    });
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
  }

  bool get hasSleepTimer => _sleepTimer?.isActive ?? false;

  // ---------------------------------------------------------------------------
  // Scrobbling via Subsonic

  void _initScrobbling() {
    player.currentIndexStream.listen((_) {
      _nowPlayingReported = false;
      _scrobbled = false;
    });

    player.positionStream.listen((position) {
      final cfg = _config;
      if (cfg == null) return;
      final song = currentSong;
      if (song == null) return;
      // positionStream ticks even when paused — only scrobble while actually playing.
      if (!player.playing) return;

      if (!_nowPlayingReported && position.inSeconds >= 1) {
        _nowPlayingReported = true;
        SubsonicClient(cfg).scrobble(song.id, submission: false);
        _historyController.add(song);
      }

      if (!_scrobbled) {
        final dur = player.duration;
        if (dur != null) {
          final pct = position.inMilliseconds / dur.inMilliseconds;
          if (pct >= 0.5 || position.inSeconds >= 240) {
            _scrobbled = true;
            SubsonicClient(cfg).scrobble(song.id, submission: true);
          }
        }
      }
    });
  }

  final _historyController = StreamController<Song>.broadcast();
  Stream<Song> get playHistoryStream => _historyController.stream;

  int? _resolveNextPhysicalIndex(int physicalIndex) {
    if (_shuffleOrder.isNotEmpty) {
      // O(1) lookup via inverted map instead of O(n) indexOf.
      final vp = _physicalToVirtual[physicalIndex];
      if (vp == null || vp >= _shuffleOrder.length - 1) return null;
      return _shuffleOrder[vp + 1];
    }
    if (physicalIndex < 0 ||
        physicalIndex >= _loadQueueSongs.length - 1 ||
        _loadQueueSongs.isEmpty) {
      return null;
    }
    return physicalIndex + 1;
  }

  bool _canPlayOffline(Song song) {
    if (song.externalStreamUrl != null) return true;
    if (song.isDownloaded && song.localPath != null) return true;
    if (_config != null) return true;
    return false;
  }

  // Single-player crossfade: volume ramp on the main player only.
  // No second deck, no handoff races, no double playback.

  void _initCrossfade() {
    // Keep _userVolume in sync with external controllers (system UI, MPRIS).
    player.volumeStream.listen((vol) {
      if (!_isTransitionFading) {
        _userVolume = vol.clamp(0.0, 1.0);
      }
    });

    _crossfadeSub = player.positionStream.listen((position) {
      if (_queueSnapshotCtrl.isClosed || _isTransitionFading || _loading) {
        return;
      }
      final index = player.currentIndex;
      if (!player.playing ||
          index == null ||
          _loading ||
          index < 0 ||
          index >= _loadQueueSongs.length) {
        return;
      }

      // Crossfade is too fragile with virtual shuffle orders — the main
      // player's physical auto-advance rarely matches the virtual next
      // song. Rely on simple gapless playback in shuffle modes.
      if (_shuffleMode != ShuffleMode.off) return;

      final from = _loadQueueSongs[index];
      final nextIdx = _resolveNextPhysicalIndex(index);
      if (nextIdx == null) return;
      if (nextIdx < 0 || nextIdx >= _loadQueueSongs.length) return;
      final to = _loadQueueSongs[nextIdx];

      if (from.id.isEmpty || to.id.isEmpty) return;
      if (!_canPlayOffline(to)) return;

      final actualDuration = player.duration?.inSeconds;
      final transition = _transitionPolicy.planPair(
        from,
        to,
        actualDurationSeconds: actualDuration,
      );
      if (transition.kind == TransitionKind.gapless ||
          transition.duration == Duration.zero ||
          position < transition.fromStart) {
        return;
      }

      _startCrossfadeFadeOut(transition, nextIdx);
    });
  }

  void _startCrossfadeFadeOut(PlannedTransition transition, int nextIdx) {
    _cancelCrossfade();
    _crossfadeActive = true;
    _crossfadeNextIndex = nextIdx;

    final totalMs = transition.duration.inMilliseconds.clamp(100, 30000);
    final startVol = _userVolume;
    final startTime = DateTime.now();

    _isTransitionFading = true;

    _crossfadeTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (timer) {
        if (_queueSnapshotCtrl.isClosed) {
          timer.cancel();
          return;
        }
        final elapsed = DateTime.now().difference(startTime).inMilliseconds;
        final t = (elapsed / totalMs).clamp(0.0, 1.0);
        final vol = (startVol * (1.0 - t)).clamp(0.0, 1.0);
        try {
          player.setVolume(vol);
        } catch (e) {
          debugPrint('Crossfade fade-out error: $e');
        }
        if (t >= 1.0) {
          timer.cancel();
          // Volume is now 0. Start a safety timer: if the player never
          // auto-advances (stuck track, network stall), restore volume.
          _crossfadeTimeout = Timer(const Duration(seconds: 5), () {
            if (_crossfadeActive) {
              _cancelCrossfade();
            }
          });
        }
      },
    );
  }

  void _startCrossfadeFadeIn() {
    _crossfadeTimeout?.cancel();
    _crossfadeTimeout = null;
    _crossfadeActive = false;
    _crossfadeNextIndex = null;

    // If the player isn't ready yet (buffering on Android/network),
    // wait before starting the fade-in so we don't ramp volume while
    // the track is still loading.
    if (player.processingState != ProcessingState.ready) {
      _waitForReadyThenFadeIn();
      return;
    }

    _runFadeIn();
  }

  void _waitForReadyThenFadeIn() {
    StreamSubscription<ProcessingState>? sub;
    sub = player.processingStateStream.listen((state) {
      if (state == ProcessingState.ready) {
        sub?.cancel();
        _runFadeIn();
      } else if (state == ProcessingState.completed ||
          state == ProcessingState.idle) {
        sub?.cancel();
        _cancelCrossfade();
      }
    });
  }

  void _runFadeIn() {
    // Guard: don't start a second fade-in if one is already running.
    if (_crossfadeTimer?.isActive == true && _isTransitionFading) {
      return;
    }

    const totalMs = 1200; // Slightly snappier fade-in than fade-out
    final startVol = player.volume; // Usually 0.0
    final targetVol = _userVolume;
    final startTime = DateTime.now();

    _isTransitionFading = true;

    _crossfadeTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (timer) {
        if (_queueSnapshotCtrl.isClosed) {
          timer.cancel();
          return;
        }
        final elapsed = DateTime.now().difference(startTime).inMilliseconds;
        final t = (elapsed / totalMs).clamp(0.0, 1.0);
        final vol = (startVol + (targetVol - startVol) * t).clamp(0.0, 1.0);
        try {
          player.setVolume(vol);
        } catch (e) {
          debugPrint('Crossfade fade-in error: $e');
        }
        if (t >= 1.0) {
          timer.cancel();
          _isTransitionFading = false;
        }
      },
    );
  }

  Future<void> _cancelCrossfade() async {
    _crossfadeTimer?.cancel();
    _crossfadeTimer = null;
    _crossfadeTimeout?.cancel();
    _crossfadeTimeout = null;
    _crossfadeActive = false;
    _crossfadeNextIndex = null;
    _isTransitionFading = false;
    try {
      await player.setVolume(_userVolume);
    } catch (e) {
      debugPrint('Crossfade cancel restore volume error: $e');
    }
  }

  // ---------------------------------------------------------------------------

  AudioSource _songToSource(Song song) {
    final Uri uri;
    if (song.externalStreamUrl != null) {
      uri = Uri.parse(song.externalStreamUrl!);
    } else if (song.isDownloaded && song.localPath != null) {
      uri = Uri.file(song.localPath!);
    } else if (_config != null) {
      uri = Uri.parse(
          SubsonicClient(_config!).streamUrl(song.id, quality: _streamQuality));
    } else {
      // No server config and song is not downloaded — produce a silent/error
      // source so just_audio can skip it gracefully instead of crashing.
      uri = Uri.parse('about:blank');
    }
    return AudioSource.uri(uri, tag: song);
  }

  // Linux MPRIS (playerctl / media keys)

  Future<void> setupMpris() async {
    if (!Platform.isLinux) return;
    _mpris = LinuxMprisService(
      player: player,
      getCurrentSong: () => currentSong,
      skipToPrevious: skipToPrevious,
      getShuffleMode: () => _shuffleMode,
      shuffleModeStream: _shuffleModeCtrl.stream,
    );
    await _mpris!.start();
  }

  // Linux media key handling via HardwareKeyboard.

  bool _isTextFieldFocused() {
    final focus = FocusManager.instance.primaryFocus;
    if (focus == null) return false;
    if (focus.context?.widget is EditableText) return true;
    bool found = false;
    focus.context?.visitAncestorElements((element) {
      if (element.widget is EditableText) {
        found = true;
        return false;
      }
      return true;
    });
    return found;
  }

  void _seekRelative(Duration delta) {
    final dur = player.duration;
    if (dur == null) return;
    final next = player.position + delta;
    seek(next < Duration.zero
        ? Duration.zero
        : next > dur
            ? dur
            : next);
  }

  void _adjustVolume(double delta) {
    final vol = (player.volume + delta).clamp(0.0, 1.0);
    _userVolume = vol;
    player.setVolume(vol);
  }

  bool _handleMediaKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    // XF86 media keys — always handle regardless of focus.
    switch (event.logicalKey) {
      case LogicalKeyboardKey.mediaPlay:
      case LogicalKeyboardKey.mediaPlayPause:
        player.playing ? pause() : play();
        return true;
      case LogicalKeyboardKey.mediaPause:
        pause();
        return true;
      case LogicalKeyboardKey.mediaTrackNext:
        skipToNext();
        return true;
      case LogicalKeyboardKey.mediaTrackPrevious:
        skipToPrevious();
        return true;
      case LogicalKeyboardKey.mediaStop:
        stop();
        return true;
    }

    // Vim-style shortcuts — skip when a text field has focus.
    if (_isTextFieldFocused()) return false;

    final shift = HardwareKeyboard.instance.isShiftPressed;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.space:
        player.playing ? pause() : play();
        return true;
      case LogicalKeyboardKey.keyN:
        skipToNext();
        return true;
      case LogicalKeyboardKey.keyP:
        skipToPrevious();
        return true;
      case LogicalKeyboardKey.keyL:
        _seekRelative(
            shift ? const Duration(seconds: 30) : const Duration(seconds: 5));
        return true;
      case LogicalKeyboardKey.keyH:
        _seekRelative(
            shift ? const Duration(seconds: -30) : const Duration(seconds: -5));
        return true;
      case LogicalKeyboardKey.digit0:
        seek(Duration.zero);
        return true;
      case LogicalKeyboardKey.keyJ:
        _adjustVolume(-0.05);
        return true;
      case LogicalKeyboardKey.keyK:
        _adjustVolume(0.05);
        return true;
      case LogicalKeyboardKey.keyM:
        _userVolume = player.volume > 0 ? 0.0 : 1.0;
        player.setVolume(_userVolume);
        return true;
      case LogicalKeyboardKey.keyS:
        toggleShuffle();
        return true;
      case LogicalKeyboardKey.keyR:
        cycleLoopMode();
        return true;
    }
    return false;
  }

  // ---------------------------------------------------------------------------

  void dispose() {
    if (Platform.isLinux) {
      HardwareKeyboard.instance.removeHandler(_handleMediaKey);
      _mpris?.dispose();
    }
    _shuffleModeCtrl.close();
    _queueSnapshotCtrl.close();
    _shuffleOrder = [];
    _shufflePos = 0;
    _physicalToVirtual = {};
    _cachedShuffleOrder = null;
    _cachedPlannedSongs = null;
    _cachedShuffleHash = 0;
    _cachedNormalSnapshot = null;
    _cachedNormalQueueLength = -1;
    _cachedNormalCurrentIndex = -1;
    _loadQueueSongs = const [];
    _crossfadeSub?.cancel();
    _crossfadeTimer?.cancel();
    _crossfadeTimeout?.cancel();
    _recalcDebounceTimer?.cancel();
    // No transition deck to dispose (single-player crossfade).
    _sleepTimer?.cancel();
    _historyController.close();
    player.dispose();
  }
}  // Two-phase audio init: createAudioHandler() before runApp (sync),
  // connectAudioService() after runApp (async). Prevents black-screen on
  // devices where MediaBrowserService init is slow.

MelodizeAudioHandler createAudioHandler() => MelodizeAudioHandler();

Future<void> connectAudioService(MelodizeAudioHandler handler) async {
  try {
    await AudioService.init<MelodizeAudioHandler>(
      builder: () => handler,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.catgirl.melodize.channel.audio',
        androidNotificationChannelName: 'Melodize',
        // ongoing must be false when stopForegroundOnPause is false.
        androidNotificationOngoing: false,
        // Keep foreground service alive when paused so aggressive ROMs don't
        // kill the MediaSession.
        androidStopForegroundOnPause: false,
        androidNotificationIcon: 'mipmap/ic_launcher',
      ),
    );
  } catch (e, st) {
    debugPrint('AudioService.init failed: $e\n$st');
  }
}
