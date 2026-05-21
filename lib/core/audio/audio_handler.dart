import 'dart:async';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:just_audio/just_audio.dart';
import '../models/song.dart';
import '../api/subsonic_client.dart';
import '../linux/linux_mpris.dart';
import 'mix_transition_manager.dart';
import 'shuffle_mode.dart';
import 'smart_shuffle_engine.dart';

// ---------------------------------------------------------------------------
// Linux shuffle note:
//
// just_audio_media_kit does not implement setShuffleOrder, so just_audio's
// internal shuffle indices and mpv's independently-generated shuffle order
// diverge the moment setShuffleModeEnabled(true) is called.  Result:
// sequenceState.currentSource.tag (and thus cover art / song title) reflects
// a different song than what mpv is actually decoding.
//
// Fix: on Linux we never call player.setShuffleModeEnabled.  Instead we
// manage shuffle in two ways:
//
//   • At loadQueue() time — re-order the song list before the single
//     setAudioSource() call so the source is built in the correct order.
//
//   • On mid-playback toggle — use a virtual playback order (an in-memory
//     index list) instead of re-building the source.  skipToNext and
//     skipToPrevious navigate through the virtual order; a
//     currentIndexStream handler corrects auto-advance when it lands on
//     the wrong physical index.
//
// A StreamController carries the shuffle-on/off state for the UI.
// The physical ConcatenatingAudioSource never changes during playback,
// so the mpv playlist-move bug is never triggered and there is zero
// UI freeze from setAudioSource rebuilds.
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// MelodizeAudioHandler
//
// Extends BaseAudioHandler so that audio_service can:
//   • register an Android MediaSession (required for headphone buttons)
//   • show a media notification on the lock screen / notification shade
//   • route media button events → play / pause / skipToNext / skipToPrevious
//
// The playbackState and mediaItem BehaviorSubjects (inherited from
// BaseAudioHandler) are kept in sync with just_audio's player state so the
// MediaSession always reflects what is actually playing.
// ---------------------------------------------------------------------------

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
    audioLoadConfiguration: AudioLoadConfiguration(
      androidLoadControl: AndroidLoadControl(
        // Start playback after 500 ms buffered instead of the default ~2500 ms.
        bufferForPlaybackDuration: const Duration(milliseconds: 500),
        bufferForPlaybackAfterRebufferDuration: const Duration(seconds: 2),
        // Keep 60 s max buffer so ExoPlayer has room to pre-buffer the next
        // track before the current one ends, enabling gapless transitions.
        minBufferDuration: const Duration(seconds: 20),
        maxBufferDuration: const Duration(seconds: 60),
      ),
      darwinLoadControl: DarwinLoadControl(
        // AVQueuePlayer buffers automatically; 30 s forward is sufficient.
        preferredForwardBufferDuration: const Duration(seconds: 30),
      ),
    ),
  );

  // Replaced on every loadQueue call — using a fresh instance avoids the
  // expensive clear() platform-channel round-trip when loading a new queue.
  // Other queue-mutation methods (playNext, addToQueue, etc.) always operate
  // on this reference, which points to the currently active playlist.
  ConcatenatingAudioSource _playlistSource = ConcatenatingAudioSource(
    children: [],
    useLazyPreparation: true,
  );

  SubsonicConfig? _config;
  String _streamQuality = 'lossless';
  int _crossfadeSeconds = 0;
  StreamSubscription<Duration>? _crossfadeSub;
  Timer? _sleepTimer;
  bool _nowPlayingReported = false;
  bool _scrobbled = false;
  LinuxMprisService? _mpris;

  // Shuffle playback history — tracks the actual sequence of songs heard so
  // that skipToPrevious goes back to the song the user really listened to last,
  // not just the adjacent position in the (fixed) shuffled order.
  final _shuffleHistory = <int>[];  // original-sequence indices (fallback)
  int? _lastHistoryIndex;

  // Unified shuffle state for both platforms.
  ShuffleMode _shuffleMode = ShuffleMode.off;
  final _shuffleModeCtrl = StreamController<ShuffleMode>.broadcast();

  // Virtual ordering — maps playback-position → physical-source-index.
  // When non-empty, skipToNext/skipToPrevious navigate through this order
  // instead of the physical source order.  The physical source never changes,
  // so toggling shuffle is instant (no setAudioSource rebuild).
  List<int> _shuffleOrder = [];
  int _shufflePos = 0;

  // The full song list from the last loadQueue(), used to recalculate the
  // virtual order when the user toggles shuffle mid-playback.
  List<Song> _loadQueueSongs = [];

  // Guards the currentIndexStream handler from interfering while we
  // programmatically seek to a virtual-order position.
  bool _seekingVirtual = false;

  /// Expose current mode for external readers (e.g. MPRIS).
  ShuffleMode get currentShuffleMode => _shuffleMode;

  /// Optional companion analysis cache for real BPM/key data.
  BpmCache? _companionBpmCache;

  /// Transition mix manager (micro-level mixing).  Created externally with
  /// the companion API client and wired in from main.dart.
  TransitionMixManager? _mixManager;

  /// Pending mix offsets: when a mix A→B is inserted, Song B should skip
  /// [mixDuration] seconds (the portion already heard in the mix).
  final _pendingMixOffsets = <String, double>{};

  /// Set the companion analysis cache so smart shuffle uses real data.
  void setCompanionAnalysis(BpmCache? cache) {
    _companionBpmCache = cache;
    // Also feed BPM data to the mix manager for early BPM-gap checks.
    _mixManager?.companionBpm = cache?.bpm;
  }

  /// Wire in the transition mix manager for time-stretched crossfades.
  void setTransitionMixManager(TransitionMixManager manager) {
    _mixManager = manager;
    if (_companionBpmCache != null) {
      _mixManager!.companionBpm = _companionBpmCache!.bpm;
    }
    _mixManager!.onMixInserted = (songId, offset) {
      _pendingMixOffsets[songId] = offset;
    };
  }

  /// Restore a persisted shuffle mode without triggering reordering.
  /// Use on app startup — the mode takes effect on the next [loadQueue].
  void restoreShuffleMode(ShuffleMode mode) {
    _shuffleMode = mode;
    _shuffleModeCtrl.add(mode);
  }

  /// Shuffle-mode stream for the UI.
  Stream<ShuffleMode> get shuffleModeStream => _shuffleModeCtrl.stream;

  // ---------------------------------------------------------------------------
  // MediaSession sync — keeps audio_service's playbackState + mediaItem current
  // so the notification, lock screen, and Bluetooth display show correct info.

  void _initStateSync() {
    // Update MediaSession playback state on play/pause/processing changes.
    player.playerStateStream.listen((_) => _broadcastState());

    // Clear the MediaSession media item when the player becomes idle or the
    // playlist ends with no loop.  Without this, OriginOS (vivo) keeps
    // showing the Island widget with stale song info indefinitely.
    player.processingStateStream.listen((state) {
      if (state == ProcessingState.idle || state == ProcessingState.completed) {
        mediaItem.add(null);
      }
    });

    // Track shuffle playback history and correct auto-advance in virtual orders.
    player.currentIndexStream.listen((index) {
      if (_seekingVirtual || index == null) return;
      if (_shuffleMode == ShuffleMode.off) {
        _shuffleHistory.clear();
        _lastHistoryIndex = null;
        return;
      }
      if (_shuffleOrder.isNotEmpty) {
        final nextVp = _shufflePos + 1;
        if (nextVp < _shuffleOrder.length) {
          final expectedPhysical = _shuffleOrder[nextVp];
          if (index != expectedPhysical) {
            if (_seekingVirtual) return;
            _seekingVirtual = true;
            Future.microtask(() {
              player.seek(Duration.zero, index: expectedPhysical)
                .then((_) => _seekingVirtual = false);
            });
            return;
          }
        }
        final vp = _shuffleOrder.indexOf(index);
        if (vp >= 0) _shufflePos = vp;
      } else {
        if (_lastHistoryIndex != null && _lastHistoryIndex != index) {
          _shuffleHistory.add(_lastHistoryIndex!);
          if (_shuffleHistory.length > 100) _shuffleHistory.removeAt(0);
        }
        _lastHistoryIndex = index;
      }

      _mixManager?.prefetch(index);
    });

    // Update MediaSession media item when the current song changes.
    // Also immediately broadcast playbackState with position=0 so the system
    // player (OriginOS Island, lock screen) sees new song + correct time in
    // one event — prevents showing "new song title, position = 2:35 (old song)"
    // when mediaItem and playbackState update in separate microtasks.
    player.sequenceStateStream.listen((seqState) {
      final rawTag = seqState?.currentSource?.tag;
      Song? song = rawTag is Song ? rawTag : null;

      if (song == null && rawTag is String && rawTag.startsWith('transition:')) {
        song = _resolveTransitionDest(rawTag);
      }

      if (song == null) {
        mediaItem.add(null);
        return;
      }

      // Skip past the mix window when this real song just played in a mix WAV.
      if (rawTag is Song && !_seekingVirtual) {
        final skip = _pendingMixOffsets.remove(song.id);
        if (skip != null && skip > 0) {
          _seekingVirtual = true;
          Future.microtask(() {
            player.seek(Duration(milliseconds: (skip * 1000).round()))
                .then((_) => _seekingVirtual = false);
          });
        }
      }

      Uri? artUri;
      if (_config != null && (song.coverArt?.isNotEmpty ?? false)) {
        artUri = Uri.tryParse(
            SubsonicClient(_config!).coverArtUrl(song.coverArt!));
      } else if (song.externalCoverUrl != null) {
        artUri = Uri.tryParse(song.externalCoverUrl!);
      }
      mediaItem.add(MediaItem(
        id: song.id,
        title: song.title,
        artist: song.artist,
        album: song.album,
        duration: song.duration != null
            ? Duration(seconds: song.duration!)
            : null,
        artUri: artUri,
      ));
      // Force position=0 alongside the new mediaItem so the system player
      // never renders "new song + stale position from previous track."
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
    // Re-emit mediaItem with artUri now that the server config is available,
    // but only if playback is active — avoids spuriously waking the OriginOS
    // Island for a paused/idle player when the server config refreshes.
    if (!player.playing) return;
    final current = mediaItem.valueOrNull;
    final song = currentSong;
    if (current != null && song != null && (song.coverArt?.isNotEmpty ?? false)) {
      mediaItem.add(current.copyWith(
        artUri: Uri.tryParse(
            SubsonicClient(config).coverArtUrl(song.coverArt!)),
      ));
    }
  }

  void setStreamQuality(String quality) => _streamQuality = quality;

  Song? get currentSong {
    final tag = player.sequenceState?.currentSource?.tag;
    if (tag is Song) return tag;
    if (tag is String && tag.startsWith('transition:')) {
      return _resolveTransitionDest(tag);
    }
    return null;
  }

  Stream<Song?> get currentSongStream => player.sequenceStateStream.map((s) {
        final tag = s?.currentSource?.tag;
        if (tag is Song) return tag;
        if (tag is String && tag.startsWith('transition:')) {
          return _resolveTransitionDest(tag);
        }
        return null;
      });

  /// Extract destination song from a transition mix tag (format "transition:A_ID→B_ID").
  Song? _resolveTransitionDest(String tag) {
    final parts = tag.split('→');
    if (parts.length != 2) return null;
    final destId = parts[1];
    for (final s in _loadQueueSongs) {
      if (s.id == destId) return s;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Queue management

  Future<void> loadQueue(List<Song> songs, {int startIndex = 0}) async {
    if (_config == null || songs.isEmpty) return;
    _mixManager?.detach();
    _shuffleHistory.clear();
    _lastHistoryIndex = null;
    int idx = startIndex.clamp(0, songs.length - 1);

    // Apply active shuffle mode by re-ordering the song list before building
    // the audio source.  This runs before the platform branch so both Linux
    // and mobile build the ordered queue in their single setAudioSource call.
    if (_shuffleMode == ShuffleMode.shuffle && songs.length > 1) {
      final current = songs[idx];
      final shuffled = [...songs]..shuffle();
      shuffled.remove(current);
      shuffled.insert(idx.clamp(0, shuffled.length), current);
      songs = shuffled;
    } else if (_shuffleMode == ShuffleMode.smartShuffle && songs.length > 1) {
      final cache = buildBpmCache(songs,
          knownBpm: _companionBpmCache?.bpm,
          knownKeys: _companionBpmCache?.key,
          knownEnergy: _companionBpmCache?.energy,
          knownSpectralCentroid: _companionBpmCache?.spectralCentroid);
      songs = orderSongs(songs, idx, cache,
          seed: DateTime.now().microsecondsSinceEpoch,
          energyCurve: true);
      idx = 0;
    }

    // Store the full song list for virtual-order recalculation on mid-playback
    // toggle.  The source is already in the correct order — _shuffleOrder is
    // kept empty (identity) so navigation follows physical source order.
    _loadQueueSongs = List.from(songs);
    _pendingMixOffsets.clear();
    // Identity virtual order so skipToPrevious wraps to the last track
    // instead of being stuck at position 0.
    if (_shuffleMode != ShuffleMode.off && songs.length > 1) {
      _shuffleOrder = List.generate(songs.length, (i) => i);
    } else {
      _shuffleOrder = [];
    }
    _shufflePos = 0;

    if (Platform.isLinux) {
      // On Linux (just_audio_media_kit / libmpv), insertAll() before the
      // current index does not reliably update currentIndex, causing the
      // sequenceState to report the wrong song (wrong title/cover).
      // Load the full queue upfront instead — desktop doesn't have the
      // platform-channel latency that makes this slow on mobile.
      //
      // However, loading 100+ songs at once triggers a just_audio_media_kit
      // bug where concatenatingInsertAll generates bogus playlist-move
      // commands that eventually crash mpv with "Broken pipe" on the
      // display connection.  Cap initial load at ~50 songs and append the
      // rest after playback starts.
      const int maxInitial = 50;
      final List<Song> initialSongs;
      final List<Song> remainingSongs;
      int initialIndex = idx;
      if (songs.length <= maxInitial) {
        initialSongs = songs;
        remainingSongs = const [];
      } else {
        // Window the initial batch around the start index so the first
        // several tracks after the starting song are available immediately.
        final int start = idx.clamp(0, songs.length - maxInitial);
        initialSongs = songs.sublist(start, start + maxInitial);
        remainingSongs = [
          ...songs.sublist(0, start),
          ...songs.sublist(start + maxInitial),
        ];
        initialIndex = idx - start;
      }

      _playlistSource = ConcatenatingAudioSource(
        children: initialSongs.map(_songToSource).toList(),
        useLazyPreparation: true,
      );
      try {
        await player.setAudioSource(_playlistSource, initialIndex: initialIndex);
        await player.play();
      } catch (e) {
        debugPrint('loadQueue error: $e');
        return;
      }
      _mixManager?.attach(_playlistSource, songs);
      _mixManager?.prefetch(initialIndex);
      // Append remaining songs after playback starts so mpv isn't choked
      // by a massive playlist during initial load.
      if (remainingSongs.isNotEmpty) {
        Future.microtask(() async {
          for (final s in remainingSongs) {
            try {
              await _playlistSource.add(_songToSource(s));
            } catch (e) {
              debugPrint('loadQueue append error: $e');
            }
          }
        });
      }
      return;
    }

    // Mobile: build full queue upfront so the player starts at the correct index.
    // preload:false registers the source tree structure without preparing audio
    // decoders, so platform-channel latency is minimal — no tap-lag regression
    // compared to the previous two-phase approach (which was buggy — insertAll
    // at index 0 after playback starts doesn't reliably shift currentIndex).
    _playlistSource = ConcatenatingAudioSource(
      children: songs.map(_songToSource).toList(),
      useLazyPreparation: true,
    );
    try {
      await player.setAudioSource(_playlistSource, initialIndex: idx, preload: false);
      player.play().catchError((e) => debugPrint('loadQueue play: $e'));
    } catch (e) {
      debugPrint('loadQueue error: $e');
    }
    _mixManager?.attach(_playlistSource, songs);
    _mixManager?.prefetch(idx);
  }

  Future<void> playNext(Song song) async {
    if (_config == null) return;
    _mixManager?.sourceMutated();
    final idx =
        ((player.currentIndex ?? 0) + 1).clamp(0, _playlistSource.length);
    await _playlistSource.insert(idx, _songToSource(song));
    _shuffleOrder = [];
    _shufflePos = 0;
  }

  Future<void> addToQueue(Song song) async {
    if (_config == null) return;
    _mixManager?.sourceMutated();
    await _playlistSource.add(_songToSource(song));
    _shuffleOrder = []; // source changed, virtual order stale
    _shufflePos = 0;
  }

  Future<void> removeFromQueue(int index) async {
    _mixManager?.sourceMutated();
    await _playlistSource.removeAt(index);
    _shuffleOrder = [];
    _shufflePos = 0;
  }

  Future<void> removeSongById(String songId) async {
    _mixManager?.sourceMutated();
    for (int i = _playlistSource.length - 1; i >= 0; i--) {
      final child = _playlistSource[i];
      final tag = child is IndexedAudioSource ? child.tag : null;
      if (tag is Song && tag.id == songId) {
        await _playlistSource.removeAt(i);
      }
    }
    _shuffleOrder = [];
    _shufflePos = 0;
  }

  Future<void> reorderQueue(int oldIndex, int newIndex) async {
    _mixManager?.sourceMutated();
    await _playlistSource.move(oldIndex, newIndex);
    _shuffleOrder = [];
    _shufflePos = 0;
  }

  // ---------------------------------------------------------------------------
  // Playback controls — @override routes media button events from audio_service

  @override
  Future<void> play() => player.play();

  @override
  Future<void> pause() => player.pause();

  @override
  Future<void> stop() => player.stop();

  @override
  Future<void> seek(Duration position) => player.seek(position);

  @override
  Future<void> skipToNext() async {
    if (_shuffleOrder.isNotEmpty) {
      final nextVp = _shufflePos + 1;
      if (nextVp < _shuffleOrder.length) {
        _shufflePos = nextVp;
        _seekingVirtual = true;
        await player.seek(Duration.zero, index: _shuffleOrder[_shufflePos]);
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
      _seekingVirtual = true;
      await player.seek(Duration.zero, index: _shuffleOrder[_shufflePos]);
      _seekingVirtual = false;
      return;
    } else if (_shuffleMode != ShuffleMode.off && _shuffleHistory.isNotEmpty) {
      final prevIndex = _shuffleHistory.removeLast();
      _seekingVirtual = true;
      _lastHistoryIndex = prevIndex;
      try {
        await player.seek(Duration.zero, index: prevIndex);
      } finally {
        _seekingVirtual = false;
      }
    } else {
      await player.seekToPrevious();
    }
  }

  Future<void> skipToIndex(int index) async {
    _seekingVirtual = true;
    if (_shuffleOrder.isNotEmpty) {
      final vp = _shuffleOrder.indexOf(index);
      if (vp >= 0) {
        _shufflePos = vp;
      } else {
        // Target is outside the virtual order — user broke out, clear it.
        _shuffleOrder = [];
        _shufflePos = 0;
      }
    }
    await player.seek(Duration.zero, index: index);
    _seekingVirtual = false;
  }

  /// Calculate a virtual playback order for the current [shuffleMode].
  ///
  /// Reads the currently loaded songs from [_playlistSource] and builds an
  /// index list that maps playback-position → physical-source-index.  When
  /// the list is non-empty [skipToNext] and [skipToPrevious] follow it.
  ///
  /// Called on mid-playback toggle — no source rebuild, instant (~O(n)).
  void _recalculateShuffleOrder() {
    final loaded = _playlistSource.length;
    if (loaded < 2 || _config == null) {
      _shuffleOrder = [];
      _shufflePos = 0;
      return;
    }

    switch (_shuffleMode) {
      case ShuffleMode.off:
        _shuffleOrder = [];
        _shufflePos = 0;
        break;

      case ShuffleMode.shuffle: {
        final validIndices = <int>[];
        for (int i = 0; i < loaded; i++) {
          final child = _playlistSource[i];
          if (child is IndexedAudioSource && child.tag is Song) {
            validIndices.add(i);
          }
        }
        _shuffleOrder = validIndices..shuffle();
        final currentIdx = player.currentIndex ?? 0;
        final pos = _shuffleOrder.indexOf(currentIdx);
        if (pos >= 0) _shuffleOrder.removeAt(pos);
        _shuffleOrder.insert(0, currentIdx);
        _shufflePos = 0;
        break;
      }

      case ShuffleMode.smartShuffle: {
        if (_loadQueueSongs.length < 2) {
          _shuffleOrder = [];
          _shufflePos = 0;
          break;
        }
        final cache = buildBpmCache(_loadQueueSongs,
            knownBpm: _companionBpmCache?.bpm,
            knownKeys: _companionBpmCache?.key,
            knownEnergy: _companionBpmCache?.energy,
            knownSpectralCentroid: _companionBpmCache?.spectralCentroid);
        final ordered = orderSongs(
          _loadQueueSongs, 0, cache,
          seed: DateTime.now().microsecondsSinceEpoch,
          energyCurve: true,
        );

        // Build virtual order: map each ordered song to its physical index.
        final physMap = <String, int>{};
        for (int i = 0; i < _playlistSource.length; i++) {
          final child = _playlistSource[i];
          if (child is IndexedAudioSource) {
            final tag = child.tag;
            if (tag is Song) physMap[tag.id] = i;
          }
        }
        _shuffleOrder = ordered
            .map((s) => physMap[s.id] ?? -1)
            .where((i) => i >= 0)
            .toList();
        final currentIdx = player.currentIndex ?? 0;
        _shufflePos = _shuffleOrder.indexOf(currentIdx);
        if (_shufflePos < 0) _shufflePos = 0;
        break;
      }
    }
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
    _shuffleModeCtrl.add(ShuffleMode.off);
    _shuffleOrder = [];
    _shufflePos = 0;
    _shuffleHistory.clear();
    _lastHistoryIndex = null;
    await player.setLoopMode(LoopMode.off);
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

  // ---------------------------------------------------------------------------
  // Crossfade — volume ramp between tracks

  void _initCrossfade() {
    // Reset volume on song change.
    player.sequenceStateStream.listen((_) {
      if (_crossfadeSeconds > 0 && player.volume < 0.99) {
        player.setVolume(1.0);
      }
    });

    // Ramp volume down near the end of each song, offset by trailing silence.
    _crossfadeSub = player.positionStream.listen((position) {
      final dur = player.duration;
      final secs = _crossfadeSeconds;
      if (dur == null || secs <= 0 || !player.playing) return;

      // Offset the effective duration by the current song's trailing silence
      // so the fade doesn't start during silence at the end of the track.
      final song = currentSong;
      final tailOff = (song != null)
          ? (_companionBpmCache?.tailSilenceFor(song) ?? 0.0).clamp(0.0, dur.inSeconds * 0.5)
          : 0.0;
      final effectiveDur = tailOff > 0
          ? dur - Duration(milliseconds: (tailOff * 1000).round())
          : dur;

      final remain = effectiveDur - position;
      if (remain.inSeconds > secs || remain <= Duration.zero) return;
      // Linear fade: vol goes from 1.0 → 0.08 over the last N seconds.
      final fadeProgress = remain.inMilliseconds / (secs * 1000.0);
      player.setVolume((fadeProgress * 0.92 + 0.08).clamp(0.0, 1.0));
    });
  }

  /// Set crossfade duration (0 = off).  Called when preferences change.
  void setCrossfadeDuration(int seconds) {
    _crossfadeSeconds = seconds.clamp(0, 12);
    if (seconds <= 0) player.setVolume(1.0);
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

  // ---------------------------------------------------------------------------
  // Linux MPRIS (playerctl / niri XF86 keybindings)

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

  // ---------------------------------------------------------------------------
  // Linux media key handling via HardwareKeyboard
  //
  // On Wayland (niri), the compositor forwards XF86 media keys to the focused
  // window as standard key events. MPRIS (via audio_service) handles the
  // unfocused case; this covers when the app window is in focus.

  // Returns true if a text-input widget currently has keyboard focus.
  // Used to suppress vim shortcuts while the user is typing.
  //
  // In Flutter 3.27+, EditableText wraps its FocusNode in an inner Focus
  // widget, so primaryFocus.context.widget is Focus (not EditableText).
  // visitAncestorElements from that Focus context walks up and finds the
  // enclosing EditableText, making the check reliable across Flutter versions.
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
    player.seek(next < Duration.zero ? Duration.zero : next > dur ? dur : next);
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
        player.playing ? player.pause() : player.play();
        return true;
      case LogicalKeyboardKey.mediaPause:
        player.pause();
        return true;
      case LogicalKeyboardKey.mediaTrackNext:
        skipToNext();
        return true;
      case LogicalKeyboardKey.mediaTrackPrevious:
        skipToPrevious();
        return true;
      case LogicalKeyboardKey.mediaStop:
        player.stop();
        return true;
    }

    // Vim-style shortcuts — skip when a text field has focus.
    if (_isTextFieldFocused()) return false;

    final shift = HardwareKeyboard.instance.isShiftPressed;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.space:
        player.playing ? player.pause() : player.play();
        return true;
      case LogicalKeyboardKey.keyN:
        skipToNext();
        return true;
      case LogicalKeyboardKey.keyP:
        skipToPrevious();
        return true;
      case LogicalKeyboardKey.keyL:
        _seekRelative(shift ? const Duration(seconds: 30) : const Duration(seconds: 5));
        return true;
      case LogicalKeyboardKey.keyH:
        _seekRelative(shift ? const Duration(seconds: -30) : const Duration(seconds: -5));
        return true;
      case LogicalKeyboardKey.digit0:
        player.seek(Duration.zero);
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
    _shuffleOrder = [];
    _shufflePos = 0;
    _loadQueueSongs = const [];
    _pendingMixOffsets.clear();
    _crossfadeSub?.cancel();
    _sleepTimer?.cancel();
    _historyController.close();
    _mixManager?.detach();
    player.dispose();
  }
}

// ---------------------------------------------------------------------------
// Two-phase audio initialisation:
//
//   Phase 1 (sync, before runApp) — createAudioHandler()
//     Creates the handler so the app can play audio immediately.
//
//   Phase 2 (async, after runApp) — connectAudioService(handler)
//     Registers the handler with audio_service's Android MediaSession so
//     headphone buttons, lock-screen controls, and the notification work.
//     If the device/OS blocks the service, the app silently continues
//     without a MediaSession — playback still works fine.
//
// Never blocking runApp() on audio_service prevents the black-screen issue
// on devices (e.g. vivo OriginOS) where MediaBrowserService init is slow.

MelodizeAudioHandler createAudioHandler() => MelodizeAudioHandler();

Future<void> connectAudioService(MelodizeAudioHandler handler) async {
  try {
    await AudioService.init<MelodizeAudioHandler>(
      // Pass the already-created instance so audio_service uses it as the
      // handler for media-button callbacks without creating a second one.
      builder: () => handler,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.catgirl.melodize.channel.audio',
        androidNotificationChannelName: 'Melodize',
        // androidNotificationOngoing must be false when stopForegroundOnPause
        // is false — audio_service asserts they can't both be true (ongoing
        // is redundant when the foreground service never stops).
        androidNotificationOngoing: false,
        // Keep the foreground service alive when paused — otherwise OriginOS
        // and other aggressive-OEM ROMs kill the MediaSession after pause,
        // causing the system player (Island, lock screen) to vanish.
        androidStopForegroundOnPause: false,
        androidNotificationIcon: 'mipmap/ic_launcher',
      ),
    );
  } catch (e, st) {
    debugPrint('AudioService.init failed: $e\n$st');
  }
}
