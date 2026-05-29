import 'dart:async';
import 'dart:io';
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
  int _crossfadeSeconds = 0;
  StreamSubscription<Duration>? _crossfadeSub;
  AudioPlayer? _transitionDeck;
  Timer? _transitionFadeTimer;
  bool _deckTransitionActive = false;
  int? _deckTransitionFromIndex;
  int? _deckTransitionToIndex;
  Song? _deckTransitionToSong;
  bool _mainPlayerMutedDuringTransition = false;
  Timer? _sleepTimer;
  bool _nowPlayingReported = false;
  bool _scrobbled = false;
  LinuxMprisService? _mpris;

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

  bool _djTransitionsEnabled = true;
  DateTime _lastSnapshotEmit = DateTime(2000);
  bool _loading = false;

  Timer? _recalcDebounceTimer;

  void setCompanionAnalysis(BpmCache? cache) {
    _companionBpmCache = cache;
    // Re-plan when real data arrives mid-session.
    if (_shuffleMode == ShuffleMode.smartShuffle) {
      _recalculateShuffleOrder();
    } else {
      _emitQueueSnapshot(immediate: true);
    }
  }

  // Restore persisted shuffle mode on startup.
  void restoreShuffleMode(ShuffleMode mode) {
    _shuffleMode = mode;
    _queue.setMode(_playbackModeFor(mode));
    _shuffleModeCtrl.add(mode);
    _recalculateShuffleOrder();
  }

  Stream<ShuffleMode> get shuffleModeStream => _shuffleModeCtrl.stream;

  Stream<PlaybackQueueSnapshot> get queueSnapshotStream =>
      _queueSnapshotCtrl.stream;

  PlaybackQueueSnapshot get queueSnapshot => _snapshot();

  void _initStateSync() {
    player.playerStateStream.listen((_) => _broadcastState());

    // Clear media item on idle/completed so OriginOS doesn't show stale info.
    player.processingStateStream.listen((state) {
      if (state == ProcessingState.idle || state == ProcessingState.completed) {
        mediaItem.add(null);
      }
    });      // Track shuffle history and correct auto-advance in virtual orders.
      player.currentIndexStream.listen((index) {
      if (index == null) return;        if (_queueSnapshotCtrl.isClosed || _playlistSource.length == 0) return;

      final prevPhysical = _lastKnownPhysicalIndex;
      _lastKnownPhysicalIndex = index;        if (_deckTransitionActive || _loading) {
          // Mute the main player if it auto-advanced during a crossfade.
          if (_deckTransitionActive &&
              !_seekingVirtual &&
              _deckTransitionFromIndex != null &&
              index != _deckTransitionFromIndex) {
          _mainPlayerMutedDuringTransition = true;
          unawaited(player.setVolume(0.0));
        }
        return;
      }

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
      // Suppress metadata updates during a deck crossfade so the UI doesn't
      // flash the auto-advanced main-player track before the handoff.
      if (_deckTransitionActive) return;

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
      queueIndex: player.currentIndex,
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
    if (_deckTransitionActive) return _deckTransitionToSong;
    final tag = player.sequenceState?.currentSource?.tag;
    if (tag is Song) return tag;
    return null;
  }

  Stream<Song?> get currentSongStream => player.sequenceStateStream.map((s) {
        if (_deckTransitionActive) return _deckTransitionToSong;
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
        crossfadeSeconds: _crossfadeSeconds,
        djTransitionsEnabled: _djTransitionsEnabled,
        analysis: _companionBpmCache,
      );

  // Cached snapshot to avoid repeated List allocations.
  List<Song>? _cachedPlannedSongs;
  List<int>? _cachedShuffleOrder;
  int _cachedShuffleHash = 0;

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
    _cachedShuffleOrder = null;
    _cachedPlannedSongs = null;
    _cachedShuffleHash = 0;
    return _queue.snapshot(
      upcomingTransitions: _transitionPolicy.planUpcoming(
        _queue.songs,
        _queue.currentIndex,
      ),
    );
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
      if (now.difference(_lastSnapshotEmit).inMilliseconds < 500) return;
      _lastSnapshotEmit = now;
    }
    _queueSnapshotCtrl.add(_snapshot());
  }

  // ---------------------------------------------------------------------------
  // Queue management

  Future<void> loadQueue(List<Song> songs, {int startIndex = 0}) async {
    if (_config == null || songs.isEmpty || _loading) return;
    _loading = true;
    await _cancelDeckTransition();
    _shuffleHistory.clear();
    _lastHistoryIndex = null;
    final idx = startIndex.clamp(0, songs.length - 1);
    final cache = buildBpmCache(songs,
        knownBpm: _companionBpmCache?.bpm,
        knownKeys: _companionBpmCache?.key,
        knownEnergy: _companionBpmCache?.energy,
        knownSpectralCentroid: _companionBpmCache?.spectralCentroid,
        knownTailSilence: _companionBpmCache?.tailSilence);
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
    if (_shuffleMode != ShuffleMode.off && songs.length > 1) {
      _shuffleOrder = List.generate(songs.length, (i) => i);
      _shufflePos = idx.clamp(0, _shuffleOrder.length - 1);
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
    await _cancelDeckTransition();
    if (_config == null) return;
    final idx =
        ((player.currentIndex ?? 0) + 1).clamp(0, _playlistSource.length);
    _queue.playNext(song);
    _loadQueueSongs = List.from(_queue.songs);
    await _playlistSource.insert(idx, _songToSource(song));
    _recalculateShuffleOrder();
  }

  Future<void> addToQueue(Song song) async {
    await _cancelDeckTransition();
    if (_config == null) return;
    _queue.add(song);
    _loadQueueSongs = List.from(_queue.songs);
    await _playlistSource.add(_songToSource(song));
    _recalculateShuffleOrder();
  }

  Future<void> removeFromQueue(int index) async {
    await _cancelDeckTransition();
    final physicalIndex = (_shuffleOrder.isNotEmpty &&
            index >= 0 &&
            index < _shuffleOrder.length)
        ? _shuffleOrder[index]
        : index;
    _shuffleOrder = [];
    _physicalToVirtual = {};
    if (physicalIndex < 0 ||
        physicalIndex >= _queue.songs.length ||
        physicalIndex >= _playlistSource.length) {
      return;
    }
    _queue.removeAt(physicalIndex);
    _loadQueueSongs = List.from(_queue.songs);
    await _playlistSource.removeAt(physicalIndex);
    _recalculateShuffleOrder();
  }

  Future<void> removeSongById(String songId) async {
    await _cancelDeckTransition();
    _shuffleOrder = [];
    _physicalToVirtual = {};
    _queue.removeById(songId);
    _loadQueueSongs = List.from(_queue.songs);
    for (int i = _playlistSource.length - 1; i >= 0; i--) {
      final child = _playlistSource[i];
      final tag = child is IndexedAudioSource ? child.tag : null;
      if (tag is Song && tag.id == songId) {
        await _playlistSource.removeAt(i);
      }
    }
    _recalculateShuffleOrder();
  }

  Future<void> reorderQueue(int oldIndex, int newIndex) async {
    await _cancelDeckTransition();
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
    await _cancelDeckTransition();
    await player.pause();
  }

  @override
  Future<void> stop() async {
    await _cancelDeckTransition();
    await player.stop();
  }

  @override
  Future<void> seek(Duration position) async {
    await _cancelDeckTransition();
    await player.seek(position);
  }

  @override
  Future<void> skipToNext() async {
    await _cancelDeckTransition();
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
        _emitQueueSnapshot();
        _seekingVirtual = false;
        return;
      }
      // End of virtual order — player continues in physical order.
      _shuffleOrder = [];
    }
    await player.seekToNext();
  }

  @override
  Future<void> skipToPrevious() async {
    await _cancelDeckTransition();
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
      _emitQueueSnapshot();
      _seekingVirtual = false;
      return;
    } else if (_shuffleMode != ShuffleMode.off && _shuffleHistory.isNotEmpty) {
      final prevIndex = _shuffleHistory.removeLast();
      _seekingVirtual = true;
      _lastHistoryIndex = prevIndex;
      try {
        await player.seek(Duration.zero, index: prevIndex);
        _queue.setCurrentIndex(prevIndex);
        _emitQueueSnapshot();
      } finally {
        _seekingVirtual = false;
      }
    } else {
      await player.seekToPrevious();
    }
  }

  Future<void> skipToIndex(int index) async {
    await _cancelDeckTransition();
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
    _emitQueueSnapshot();
    _seekingVirtual = false;
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
    if (loaded < 2 || _config == null || _loadQueueSongs.length < 2) {
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
            seed: DateTime.now().microsecondsSinceEpoch,
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
              knownTailSilence: _companionBpmCache?.tailSilence);
          final ordered = _planner.plan(
            songs: _loadQueueSongs,
            currentIndex: currentIdx.clamp(0, _loadQueueSongs.length - 1),
            mode: PlaybackMode.smartShuffle,
            cache: cache,
            seed: DateTime.now().microsecondsSinceEpoch,
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

    _recalculateShuffleOrder();
  }

  /// Directly set the shuffle mode (used by playlist "Shuffle" button, etc.).
  /// Also recalculates the virtual order.
  void applyShuffleMode(ShuffleMode mode) {
    _shuffleMode = mode;
    _shuffleModeCtrl.add(mode);
    _shuffleHistory.clear();
    _lastHistoryIndex = null;

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

  // Crossfade: overlap the main player with a temporary deck.

  void _initCrossfade() {
    player.sequenceStateStream.listen((_) {
      if (!_deckTransitionActive &&
          _crossfadeSeconds > 0 &&
          player.volume < 0.99) {
        player.setVolume(1.0);
      }
    });

    _crossfadeSub = player.positionStream.listen((position) {
      if (_queueSnapshotCtrl.isClosed ||
          _deckTransitionActive ||
          _transitionFadeTimer?.isActive == true) {
        return;
      }
      final secs = _crossfadeSeconds;
      final index = player.currentIndex;
      if (secs <= 0 ||
          !player.playing ||
          index == null ||
          _loading ||
          _deckTransitionFromIndex == index) {
        return;
      }

      if (index < 0 || index >= _loadQueueSongs.length) return;
      final from = _loadQueueSongs[index];

      final nextIdx = _resolveNextPhysicalIndex(index);
      if (nextIdx == null) return;
      if (nextIdx < 0 || nextIdx >= _loadQueueSongs.length) return;
      final to = _loadQueueSongs[nextIdx];

      if (!_canPlayOffline(to)) return;

      if (from.id.isEmpty || to.id.isEmpty) return;

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

      _deckTransitionFromIndex = index;
      unawaited(_startDeckTransition(transition, index, nextIdx));
    });
  }

  Future<void> _startDeckTransition(
    PlannedTransition transition,
    int fromIndex,
    int toIndex,
  ) async {
    _deckTransitionActive = true;
    _deckTransitionToIndex = toIndex;
    _deckTransitionToSong = transition.to;

    final deck = _transitionDeck ?? AudioPlayer();
    _transitionDeck = deck;
    try {
      await deck.setAudioSource(
        _songToSource(transition.to),
        initialPosition: transition.toStart,
      );
      await deck.play();
      await deck.setVolume(0.0);
    } catch (e) {
      debugPrint('Deck transition load failed: $e');
      await _cancelDeckTransition();
      return;
    }

    // Guard: if the user skipped during the async gap above, cancel immediately.
    if (!_deckTransitionActive) {
      await deck.stop();
      return;
    }

    final totalMs = transition.duration.inMilliseconds.clamp(1, 60000);

    // Delay so the deck initializes before the volume ramp starts.
    await Future.delayed(const Duration(milliseconds: 300));
    if (!_deckTransitionActive) {
      await deck.stop();
      return;
    }

    final startedAt = DateTime.now();
    _transitionFadeTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (timer) {
        if (_queueSnapshotCtrl.isClosed) {
          timer.cancel();
          return;
        }
        final elapsed = DateTime.now().difference(startedAt).inMilliseconds;
        final t = (elapsed / totalMs).clamp(0.0, 1.0);
        if (!_mainPlayerMutedDuringTransition) {
          try {
            player.setVolume((1.0 - t).clamp(0.0, 1.0));
          } catch (e) {
            debugPrint('Crossfade main-player volume error: $e');
          }
        }
        try {
          deck.setVolume(t.clamp(0.0, 1.0));
        } catch (e) {
          debugPrint('Crossfade deck volume error: $e');
        }
        if (t >= 1.0) {
          timer.cancel();
          unawaited(_finishDeckTransition(transition, fromIndex));
        }
      },
    );
  }

  Future<void> _finishDeckTransition(
    PlannedTransition transition,
    int fromIndex,
  ) async {
    if (!_deckTransitionActive) return;

    final toIndex = _deckTransitionToIndex ?? fromIndex + 1;
    // Account for the 300 ms pre-fade delay so the handoff doesn't repeat
    // the first 300 ms of the next song.
    final handoffPosition = transition.toStart + transition.duration + const Duration(milliseconds: 300);
    final toSongDuration = (_loadQueueSongs.length > toIndex && toIndex >= 0)
        ? _loadQueueSongs[toIndex].duration
        : null;
    final clampedHandoff = (toSongDuration != null && toSongDuration > 0)
        ? Duration(
            milliseconds: handoffPosition.inMilliseconds.clamp(
              0,
              (toSongDuration * 1000).round(),
            ),
          )
        : handoffPosition;

    // Update virtual shuffle position to reflect where we're going.
    if (_shuffleOrder.isNotEmpty) {
      final newVp = _physicalToVirtual[toIndex];
      if (newVp != null) _shufflePos = newVp;
    }

    try {
      _seekingVirtual = true;
      // Only seek if the target index is valid; otherwise fall through to seekToNext.
      if (toIndex >= 0 && toIndex < _playlistSource.length) {
        await player.seek(clampedHandoff, index: toIndex);
      } else if (_playlistSource.length > 0) {
        await player.seekToNext();
      }
      await player.setVolume(1.0);
      _queue.setCurrentIndex(toIndex.clamp(0, _playlistSource.length - 1));
      _emitQueueSnapshot();
    } catch (e) {
      debugPrint('Deck transition handoff failed: $e');
      // Fallback: seek to the pinned target at position 0.
      if (toIndex >= 0 && toIndex < _playlistSource.length) {
        _seekingVirtual = true;
        try {
          await player.seek(Duration.zero, index: toIndex);
          _queue.setCurrentIndex(toIndex);
          _emitQueueSnapshot();
        } catch (_) {}
        _seekingVirtual = false;
      } else {
        await player.seekToNext();
      }
      await player.setVolume(1.0);
    } finally {
      _seekingVirtual = false;
      _deckTransitionFromIndex = null;
      _deckTransitionToIndex = null;
      _deckTransitionToSong = null;
      _mainPlayerMutedDuringTransition = false;
      await _stopTransitionDeck();
      _deckTransitionActive = false;
    }
  }

  Future<void> _cancelDeckTransition() async {
    _transitionFadeTimer?.cancel();
    _transitionFadeTimer = null;
    _deckTransitionActive = false;
    _deckTransitionFromIndex = null;
    _deckTransitionToIndex = null;
    _deckTransitionToSong = null;
    _mainPlayerMutedDuringTransition = false;
    await _stopTransitionDeck();
    await player.setVolume(1.0);
  }

  Future<void> _stopTransitionDeck() async {
    final deck = _transitionDeck;
    if (deck == null) return;
    try {
      await deck.stop();
    } catch (_) {}
    // Don't dispose — reuse for next transition.
  }

  Future<void> _disposeTransitionDeck() async {
    final deck = _transitionDeck;
    _transitionDeck = null;
    if (deck == null) return;
    try {
      await deck.stop();
    } catch (_) {}
    await deck.dispose();
  }

  void setCrossfadeDuration(int seconds) {
    _crossfadeSeconds = seconds.clamp(0, 12);
    if (seconds <= 0) {
      unawaited(_cancelDeckTransition());
    }
    _emitQueueSnapshot(immediate: true);
  }

  void setDjTransitionsEnabled(bool enabled) {
    _djTransitionsEnabled = enabled;
    _emitQueueSnapshot(immediate: true);
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
        player.setVolume(player.volume > 0 ? 0.0 : 1.0);
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
    _loadQueueSongs = const [];
    _crossfadeSub?.cancel();
    _transitionFadeTimer?.cancel();
    _recalcDebounceTimer?.cancel();
    unawaited(_disposeTransitionDeck());
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
