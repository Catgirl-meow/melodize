import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import '../models/song.dart';
import '../api/subsonic_client.dart';
import '../api/companion_audio_api.dart';
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

  /// Separate deck for companion-rendered transitions. It is deliberately
  /// not part of [_playlistSource]: transition WAVs are implementation
  /// details, not queue entries, so song indices and media metadata remain
  /// one-to-one on Android and Linux.
  final AudioPlayer _transitionPlayer = AudioPlayer(
    audioLoadConfiguration: const AudioLoadConfiguration(
      androidLoadControl: AndroidLoadControl(
        bufferForPlaybackDuration: Duration(milliseconds: 250),
        bufferForPlaybackAfterRebufferDuration: Duration(seconds: 1),
        minBufferDuration: Duration(seconds: 10),
        maxBufferDuration: Duration(seconds: 30),
      ),
      darwinLoadControl: DarwinLoadControl(
        preferredForwardBufferDuration: Duration(seconds: 10),
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
  // Volume-ramp fallback remains available whenever the companion cannot
  // prepare a rendered transition. The second deck is used only for a fully
  // loaded, validated transition asset.
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
  bool _disposed = false;

  /// Safety timeout: if a crossfade fade-out completes but the player
  /// never auto-advances (e.g. network stall), restore volume after a
  /// few seconds so the user isn't stuck muted.
  Timer? _crossfadeTimeout;
  Timer? _renderedTransitionTimeout;
  Future<void> _volumeWrite = Future<void>.value();
  Future<void> _transitionDeckOperation = Future<void>.value();

  // Companion-rendered transition state. A key binds a prepared asset to one
  // exact song pair and duration so stale async responses can never be played
  // for a different queue generation.
  CompanionAudioApi? _companionAudioApi;
  String? _preparedTransitionKey;
  String? _preparingTransitionKey;
  bool _renderedTransitionActive = false;
  int? _renderedTransitionNextIndex;
  String? _renderedTransitionFromId;
  String? _renderedTransitionToId;
  int _renderedTransitionGeneration = 0;
  Duration? _renderedTransitionDuration;
  Duration? _renderedMixDuration;
  Duration? _preparedTransitionDuration;
  String? _preparedTransitionPath;
  bool _renderedPausedMainPlayer = false;
  int _renderedQueueGeneration = -1;
  int _transitionPlayerGeneration = 0;
  int? _activeTransitionPlayerGeneration;
  StreamSubscription<ProcessingState>? _transitionStateSub;

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
  int _crossfadeGeneration = 0;
  int _recalcGeneration = 0;

  // Building the fallback BPM/genre cache is linear in queue size. Keep it
  // across shuffle recalculations so toggling modes or a queue snapshot does
  // not repeatedly redo the same work on Android's main isolate.
  BpmCache? _queueBpmCache;
  int _queueBpmCacheSignature = 0;
  BpmCache? _queueBpmCacheCompanion;

  /// Supplies the companion client used only to prepare rendered DJ mixes.
  /// Analysis and ordinary playback remain usable when this is null.
  void setCompanionAudioApi(CompanionAudioApi? api) {
    if (identical(_companionAudioApi, api)) return;
    _companionAudioApi = api;
    _renderedTransitionGeneration++;
    _preparedTransitionKey = null;
    _preparingTransitionKey = null;
    // If the companion changes while a rendered handoff is in flight, restore
    // the main deck before allowing any stale operation to continue.
    unawaited(_cancelCrossfade(resumeRendered: true));
  }

  Future<void> _queueTransitionDeck(Future<void> Function() operation) {
    final next = _transitionDeckOperation.then<void>(
      (_) => operation(),
      onError: (_, __) => operation(),
    );
    _transitionDeckOperation = next;
    return next;
  }

  void setCompanionAnalysis(BpmCache? cache) {
    // Guard: only recalculate if the analysis data actually changed.
    // The companion provider refreshes every ~30 s via health polling;
    // without this guard the smart-shuffle queue would jump constantly.
    if (_isSameCompanionCache(_companionBpmCache, cache)) {
      return;
    }
    _companionBpmCache = cache;
    _queueBpmCache = null;
    _queueBpmCacheSignature = 0;
    _queueBpmCacheCompanion = null;
    // Invalidate transition-plan cache so transition pills update.
    _cachedNormalSnapshot = null;
    _cachedShuffleOrder = null;
    _cachedPlannedSongs = null;
    // Re-plan when real data arrives mid-session.
    if (_shuffleMode == ShuffleMode.smartShuffle) {
      // Fresh analysis can invalidate both the planned pair and a prepared
      // rendered asset. Cancel it before the new order is exposed.
      if (_renderedTransitionActive ||
          _preparedTransitionKey != null ||
          _preparingTransitionKey != null) {
        unawaited(_cancelCrossfade(resumeRendered: true));
      }
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

  BpmCache _cacheForSongs(List<Song> songs) {
    final signature = Object.hashAll(songs.map((song) => Object.hash(
          song.id,
          song.genre,
          song.bpm,
          song.albumId,
          song.track,
        )));
    if (_queueBpmCache != null &&
        _queueBpmCacheSignature == signature &&
        identical(_queueBpmCacheCompanion, _companionBpmCache)) {
      return _queueBpmCache!;
    }

    final companion = _companionBpmCache;
    final cache = buildBpmCache(
      songs,
      knownBpm: companion?.bpm,
      knownKeys: companion?.key,
      knownEnergy: companion?.energy,
      knownSpectralCentroid: companion?.spectralCentroid,
      knownTailSilence: companion?.tailSilence,
      knownPhrasePositions: companion?.phrasePositions,
      knownFirstBeatOffset: companion?.firstBeatOffset,
      knownVocalSections: companion?.vocalSections,
    );
    _queueBpmCache = cache;
    _queueBpmCacheSignature = signature;
    _queueBpmCacheCompanion = companion;
    return cache;
  }

  // Restore persisted shuffle mode on startup.
  void restoreShuffleMode(ShuffleMode mode) {
    _shuffleMode = mode;
    _queue.setMode(_playbackModeFor(mode));
    _shuffleModeCtrl.add(mode);
    _invalidateSnapshotCaches();
    if (mode == ShuffleMode.off) {
      _shuffleOrder = [];
      _shufflePos = 0;
      _physicalToVirtual = {};
    }

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
        unawaited(_cancelCrossfade(resumeRendered: true));
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
      if (_shuffleMode == ShuffleMode.off) {
        _shuffleHistory.clear();
        _lastHistoryIndex = null;
        _emitQueueSnapshot();
        return;
      }
      if (_shuffleOrder.isNotEmpty && !_isTransitionFading) {
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
                    .then<void>((_) {
                      _seekingVirtual = false;
                    })
                    .catchError((Object _) {
                      _seekingVirtual = false;
                    });
              });
              return;
            }
          }
        }
        final vp = _physicalToVirtual[index];
        if (vp != null) _shufflePos = vp;
        _emitQueueSnapshot();
      } else {
        if (_lastHistoryIndex != null && _lastHistoryIndex != index) {
          _shuffleHistory.add(_lastHistoryIndex!);
          if (_shuffleHistory.length > 100) _shuffleHistory.removeAt(0);
        }
        _lastHistoryIndex = index;
        _emitQueueSnapshot();
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

  void _invalidateSnapshotCaches() {
    _cachedShuffleOrder = null;
    _cachedShuffleSource = null;
    _cachedPlannedSongs = null;
    _cachedNormalSnapshot = null;
    _cachedNormalQueueLength = -1;
    _cachedNormalCurrentIndex = -1;
  }

  // Cached snapshot to avoid repeated List allocations.
  List<Song>? _cachedPlannedSongs;
  List<int>? _cachedShuffleOrder;
  List<int>? _cachedShuffleSource;

  // Normal-mode snapshot cache.
  PlaybackQueueSnapshot? _cachedNormalSnapshot;
  int _cachedNormalQueueLength = -1;
  int _cachedNormalCurrentIndex = -1;
  PlaybackMode _cachedNormalMode = PlaybackMode.normal;
  int _cachedNormalCompanionHash = 0;

  PlaybackQueueSnapshot _snapshot() {
    if (_shuffleOrder.isNotEmpty &&
        _shufflePos < _shuffleOrder.length) {
      // The order is replaced (rather than mutated) whenever its contents
      // change. Identity is therefore a constant-time cache validity check.
      if (_cachedShuffleOrder == null ||
          !identical(_cachedShuffleSource, _shuffleOrder)) {
        _cachedShuffleOrder = List.of(_shuffleOrder);
        _cachedShuffleSource = _shuffleOrder;
        // [_loadQueueSongs] is the authoritative physical queue order and is
        // updated before snapshots are emitted. Reading it here avoids a
        // transient wrong/placeholder queue while just_audio is still
        // attaching a newly loaded ConcatenatingAudioSource.
        _cachedPlannedSongs = _shuffleOrder.map((i) {
          if (i >= 0 && i < _loadQueueSongs.length) {
            return _loadQueueSongs[i];
          }
          // Safety: index out of bounds — return a placeholder so the UI
          // doesn't crash; the next recalculation will fix the mapping.
          return _queue.songs.isNotEmpty ? _queue.songs[0] : Song.empty();
        }).toList();
      }
      final plannedSongs = _cachedPlannedSongs!;
      return PlaybackQueueSnapshot(
        songs: plannedSongs,
        currentIndex:
            _shufflePos.clamp(0, plannedSongs.length - 1).toInt(),
        mode: _queue.mode,
        upcomingTransitions: _queue.mode == PlaybackMode.smartShuffle
            ? _transitionPolicy.planUpcoming(plannedSongs, _shufflePos)
            : const [],
      );
    }
    // Shuffle planning is intentionally deferred. Do not rebuild here: this
    // method is called from player streams and queue widgets, so doing smart
    // planning synchronously would put the Android UI/audio isolate back under
    // load and could recurse through snapshot emission. The scheduled
    // recalculation will replace this temporary physical-order snapshot.
    _cachedShuffleOrder = null;
    _cachedShuffleSource = null;
    _cachedPlannedSongs = null;

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
      // Regular playback and regular shuffle are strictly gapless. Only DJ
      // shuffle exposes transition planning to the queue UI.
      upcomingTransitions: qMode == PlaybackMode.smartShuffle
          ? _transitionPolicy.planUpcoming(
              _queue.songs,
              _queue.currentIndex,
            )
          : const [],
    );
    return _cachedNormalSnapshot!;
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
    _recalcGeneration++;
    _recalcDebounceTimer?.cancel();
    _loading = true;
    _recalcDebounceTimer = null;
    await _cancelCrossfade(resumeRendered: true);
    _shuffleHistory.clear();
    _lastHistoryIndex = null;
    final idx = startIndex.clamp(0, songs.length - 1).toInt();
    // Keep the physical source in the caller's order. Shuffle and DJ order
    // are virtual playback orders layered over this stable source, so
    // switching back to normal playback can show the original queue again.
    _queue.load(
      songs,
      startIndex: idx,
      mode: _playbackModeFor(_shuffleMode),
    );

    _loadQueueSongs = List.from(songs);
    _lastKnownPhysicalIndex = null;
    // Invalidate any stale snapshot cache from a previous queue.
    _invalidateSnapshotCaches();
    // The source is installed below before a virtual order is calculated.
    // Until then, expose the stable physical queue rather than a guessed
    // shuffle mapping.
    _shuffleOrder = [];
    _shufflePos = 0;
    _physicalToVirtual = {};
    if (_shuffleMode != ShuffleMode.off) {
      _ensureShuffleSeed();
    }
    // Do not emit while [_playlistSource] still points at the previous queue:
    // a shuffle snapshot could be built against the wrong physical indices.

    // Build the source upfront on both platforms. Linux needs the full source
    // because media_kit/libmpv does not reliably support playlist moves;
    // Android benefits from lazy preparation and preload:false so the first
    // track can start without preparing the entire queue.
    _playlistSource = ConcatenatingAudioSource(
      children: songs.map(_songToSource).toList(),
      useLazyPreparation: true,
    );
    try {
      await player.setAudioSource(_playlistSource,
          initialIndex: idx, preload: false);
      // Start playback before smart-shuffle planning. Planning can be
      // relatively expensive for large queues and must not delay Android's
      // first audio frame. The debounced recalculation runs on a later event
      // turn after the player has been handed back to the platform.
      player.play().catchError((e) => debugPrint('loadQueue play: $e'));
      _loading = false;
      _recalculateShuffleOrder();
    } catch (e) {
      debugPrint('loadQueue error: $e');
      _loading = false;
    }
  }

  Future<void> playNext(Song song) async {
    await _cancelCrossfade(resumeRendered: true);
    if (_config == null) return;
    _recalcGeneration++;
    final idx =
        ((player.currentIndex ?? 0) + 1).clamp(0, _playlistSource.length).toInt();
    final hadVirtualOrder = _shuffleOrder.isNotEmpty;
    _queue.playNext(song);
    _loadQueueSongs = List.from(_queue.songs);
    _invalidateSnapshotCaches();
    await _playlistSource.insert(idx, _songToSource(song));
    if (hadVirtualOrder) {
      _insertIntoVirtualOrder(idx, _shufflePos + 1);
      _emitQueueSnapshot(immediate: true);
    } else {
      _emitQueueSnapshot(immediate: true);
    }
  }

  Future<void> addToQueue(Song song) async {
    await _cancelCrossfade(resumeRendered: true);
    if (_config == null) return;
    _recalcGeneration++;
    final hadVirtualOrder = _shuffleOrder.isNotEmpty;
    final physicalIndex = _playlistSource.length;
    _queue.add(song);
    _loadQueueSongs = List.from(_queue.songs);
    _invalidateSnapshotCaches();
    await _playlistSource.add(_songToSource(song));
    if (hadVirtualOrder) {
      _insertIntoVirtualOrder(physicalIndex, _shuffleOrder.length);
      _emitQueueSnapshot(immediate: true);
    } else {
      _emitQueueSnapshot(immediate: true);
    }
  }

  void _insertIntoVirtualOrder(int physicalIndex, int virtualIndex) {
    final shifted = _shuffleOrder
        .map((index) => index >= physicalIndex ? index + 1 : index)
        .toList();
    final insertAt = virtualIndex.clamp(0, shifted.length).toInt();
    shifted.insert(insertAt, physicalIndex);
    _shuffleOrder = shifted;
    _physicalToVirtual = {
      for (int vp = 0; vp < _shuffleOrder.length; vp++)
        _shuffleOrder[vp]: vp,
    };
    _shufflePos =
        _shufflePos.clamp(0, _shuffleOrder.length - 1).toInt();
    _invalidateSnapshotCaches();
  }

  Future<void> removeFromQueue(int index) async {
    await _cancelCrossfade(resumeRendered: true);
    _recalcGeneration++;
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
    _invalidateSnapshotCaches();
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
      _shufflePos = _shufflePos
          .clamp(0, max(0, _shuffleOrder.length - 1))
          .toInt();
      _physicalToVirtual = {
        for (int vp = 0; vp < _shuffleOrder.length; vp++)
          _shuffleOrder[vp]: vp,
      };
      _emitQueueSnapshot(immediate: true);
    }
    // The virtual order was patched in place above. Replanning here would
    // unexpectedly reshuffle every remaining song after a single removal.
    if (_shuffleOrder.isEmpty && _shuffleMode == ShuffleMode.off) {
      _emitQueueSnapshot(immediate: true);
    }
  }

  Future<void> removeSongById(String songId) async {
    await _cancelCrossfade(resumeRendered: true);
    _recalcGeneration++;
    final removedPhysical = <int>{};
    for (int i = 0; i < _playlistSource.length; i++) {
      final child = _playlistSource[i];
      final tag = child is IndexedAudioSource ? child.tag : null;
      if (tag is Song && tag.id == songId) removedPhysical.add(i);
    }
    final hadVirtualOrder = _shuffleOrder.isNotEmpty;
    _queue.removeById(songId);
    _loadQueueSongs = List.from(_queue.songs);
    _invalidateSnapshotCaches();
    for (final i in removedPhysical.toList()..sort((a, b) => b.compareTo(a))) {
      await _playlistSource.removeAt(i);
    }
    if (hadVirtualOrder) {
      _removePhysicalIndicesFromVirtualOrder(removedPhysical);
      _emitQueueSnapshot(immediate: true);
    } else {
      _emitQueueSnapshot(immediate: true);
    }
  }

  void _removePhysicalIndicesFromVirtualOrder(Set<int> removed) {
    if (removed.isEmpty) return;
    final oldPos = _shufflePos;
    final nextOrder = <int>[];
    for (final oldIndex in _shuffleOrder) {
      if (removed.contains(oldIndex)) continue;
      final shift = removed.where((index) => index < oldIndex).length;
      nextOrder.add(oldIndex - shift);
    }
    final removedBefore = removed.where((index) {
      final vp = _physicalToVirtual[index];
      return vp != null && vp < oldPos;
    }).length;
    _shuffleOrder = nextOrder;
    _shufflePos = (oldPos - removedBefore)
        .clamp(0, max(0, _shuffleOrder.length - 1))
        .toInt();
    _physicalToVirtual = {
      for (int vp = 0; vp < _shuffleOrder.length; vp++)
        _shuffleOrder[vp]: vp,
    };
    _invalidateSnapshotCaches();
  }

  Future<void> reorderQueue(int oldIndex, int newIndex) async {
    await _cancelCrossfade(resumeRendered: true);
    _recalcGeneration++;
    // When shuffle is active, reorder the virtual playback order
    // instead of the physical source (which never changes mid-shuffle).
    if (_shuffleOrder.isNotEmpty) {
      final oldVp = oldIndex.clamp(0, _shuffleOrder.length - 1).toInt();
      final newVp = newIndex.clamp(0, _shuffleOrder.length - 1).toInt();
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
      _cachedShuffleOrder = null;
      _cachedShuffleSource = null;
      _cachedPlannedSongs = null;
      _emitQueueSnapshot(immediate: true);
      return;
    }
    _queue.reorder(oldIndex, newIndex);
    _loadQueueSongs = List.from(_queue.songs);
    _invalidateSnapshotCaches();
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
        // Target is outside the virtual order — fall back to normal physical
        // indexing and clear every virtual mapping so the queue display and
        // media-session index cannot retain stale shuffle state.
        _recalcGeneration++;
        _shuffleOrder = [];
        _shufflePos = 0;
        _physicalToVirtual = {};
        _shuffleMode = ShuffleMode.off;
        _queue.setMode(PlaybackMode.normal);
        _invalidateSnapshotCaches();
      }
    }
    // Clamp to valid player bounds so seek doesn't throw on a stale index.
    final maxIndex = _playlistSource.length > 0 ? _playlistSource.length - 1 : 0;
    physicalIndex = physicalIndex.clamp(0, maxIndex).toInt();
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
    final generation = ++_recalcGeneration;
    _recalcDebounceTimer = Timer(const Duration(milliseconds: 150), () {
      unawaited(_recalculateShuffleOrderImpl(generation));
    });
  }

  /// Calculate a virtual playback order for the current [shuffleMode].
  ///
  /// Reads the currently loaded songs from [_playlistSource] and builds an
  /// index list that maps playback-position → physical-source-index.  When
  /// the list is non-empty [skipToNext] and [skipToPrevious] follow it.
  ///
  /// Called on mid-playback toggle — no source rebuild, instant (~O(n)).
  Future<void> _recalculateShuffleOrderImpl(int generation) async {
    if (generation != _recalcGeneration || _queueSnapshotCtrl.isClosed) return;
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
        _physicalToVirtual = {};
        _invalidateSnapshotCaches();
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
          if (_shufflePos < 0 && _loadQueueSongs.isNotEmpty) {
            // Fallback: find by song ID in case the physical index shifted.
            final currentSong = currentIdx < _loadQueueSongs.length
                ? _loadQueueSongs[currentIdx]
                : null;
            if (currentSong != null) {
              for (int vp = 0; vp < _shuffleOrder.length; vp++) {
                final physIdx = _shuffleOrder[vp];
                if (physIdx >= 0 &&
                    physIdx < _loadQueueSongs.length &&
                    _loadQueueSongs[physIdx].id == currentSong.id) {
                  _shufflePos = vp;
                  break;
                }
              }
            }
          }
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
              .clamp(0, _loadQueueSongs.length - 1)
              .toInt();
          // Run cache construction and the expensive DJ planner away from
          // Flutter's UI/audio isolate. Copy the inputs first because queue
          // mutations may replace the authoritative list while the worker is
          // running.
          final songsForPlanning = List<Song>.of(_loadQueueSongs);
          final planningSeed =
              _shuffleSeed ?? DateTime.now().microsecondsSinceEpoch;
          final orderedIds = await Isolate.run(() => _planSongsInIsolate(
                songData: songsForPlanning.map(_songToIsolateData).toList(
                  growable: false,
                ),
                currentIndex: currentIdx
                    .clamp(0, songsForPlanning.length - 1)
                    .toInt(),
                cacheData: _cacheToIsolateData(_companionBpmCache),
                seed: planningSeed,
              ));
          if (generation != _recalcGeneration ||
              _queueSnapshotCtrl.isClosed) {
            return;
          }

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
          _shuffleOrder = orderedIds.map((id) {
            final indices = physIndicesById[id];
            if (indices == null) return -1;
            final i = nextIndex.putIfAbsent(id, () => 0);
            if (i >= indices.length) return -1;
            nextIndex[id] = i + 1;
            return indices[i];
          }).where((i) => i >= 0).toList();
          _shufflePos = _shuffleOrder.indexOf(currentIdx);
          if (_shufflePos < 0 && _loadQueueSongs.isNotEmpty) {
            // Fallback: find by song ID in case the physical index shifted.
            final currentSong = currentIdx < _loadQueueSongs.length
                ? _loadQueueSongs[currentIdx]
                : null;
            if (currentSong != null) {
              for (int vp = 0; vp < _shuffleOrder.length; vp++) {
                final physIdx = _shuffleOrder[vp];
                if (physIdx >= 0 &&
                    physIdx < _loadQueueSongs.length &&
                    _loadQueueSongs[physIdx].id == currentSong.id) {
                  _shufflePos = vp;
                  break;
                }
              }
            }
          }
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

  static List<String> _planSongsInIsolate({
    required List<Map<String, Object?>> songData,
    required int currentIndex,
    required Map<String, Object?> cacheData,
    required int seed,
  }) {
    final songs = songData.map(_songFromIsolateData).toList(growable: false);
    final companion = _cacheFromIsolateData(cacheData);
    // Rebuild the complete cache in the worker so song-owned BPM values and
    // genre estimates are retained alongside companion analysis. Passing only
    // the companion cache would silently drop those fallbacks.
    final cache = buildBpmCache(
      songs,
      knownBpm: companion.bpm,
      knownKeys: companion.key,
      knownEnergy: companion.energy,
      knownSpectralCentroid: companion.spectralCentroid,
      knownTailSilence: companion.tailSilence,
      knownPhrasePositions: companion.phrasePositions,
      knownFirstBeatOffset: companion.firstBeatOffset,
      knownVocalSections: companion.vocalSections,
    );
    final ordered = PlaybackPlanner().plan(
      songs: songs,
      currentIndex: currentIndex,
      mode: PlaybackMode.smartShuffle,
      cache: cache,
      seed: seed,
    );
    return ordered.map((song) => song.id).toList(growable: false);
  }

  static Map<String, Object?> _songToIsolateData(Song song) => {
        'id': song.id,
        'title': song.title,
        'artist': song.artist,
        'album': song.album,
        'albumId': song.albumId,
        'duration': song.duration,
        'genre': song.genre,
        'track': song.track,
        'bpm': song.bpm,
      };

  static Song _songFromIsolateData(Map<String, Object?> data) => Song(
        id: data['id']! as String,
        title: data['title']! as String,
        artist: data['artist']! as String,
        album: data['album']! as String,
        albumId: data['albumId'] as String?,
        duration: data['duration'] as int?,
        genre: data['genre'] as String?,
        track: data['track'] as int?,
        bpm: data['bpm'] as int?,
      );

  static Map<String, Object?> _cacheToIsolateData(BpmCache? cache) => {
        'bpm': cache?.bpm ?? const <String, int>{},
        'key': cache?.key ?? const <String, String>{},
        'isEstimated': cache?.isEstimated ?? const <String, bool>{},
        'tailSilence': cache?.tailSilence ?? const <String, double>{},
        'energy': cache?.energy ?? const <String, double>{},
        'spectralCentroid':
            cache?.spectralCentroid ?? const <String, double>{},
        'phrasePositions':
            cache?.phrasePositions ?? const <String, List<double>>{},
        'firstBeatOffset':
            cache?.firstBeatOffset ?? const <String, double>{},
        'vocalSections': (cache?.vocalSections ??
                const <String, List<VocalSection>>{})
            .map(
          (id, sections) => MapEntry(
            id,
            sections
                .map((section) => {
                      'start': section.start,
                      'end': section.end,
                    })
                .toList(growable: false),
          ),
        ),
      };

  static BpmCache _cacheFromIsolateData(Map<String, Object?> data) {
    final rawSections = data['vocalSections'] as Map;
    return BpmCache(
      bpm: Map<String, int>.from(data['bpm'] as Map),
      key: Map<String, String>.from(data['key'] as Map),
      isEstimated: Map<String, bool>.from(data['isEstimated'] as Map),
      tailSilence: Map<String, double>.from(data['tailSilence'] as Map),
      energy: Map<String, double>.from(data['energy'] as Map),
      spectralCentroid:
          Map<String, double>.from(data['spectralCentroid'] as Map),
      phrasePositions: (data['phrasePositions'] as Map).map(
        (key, value) => MapEntry(key as String, List<double>.from(value as List)),
      ),
      firstBeatOffset:
          Map<String, double>.from(data['firstBeatOffset'] as Map),
      vocalSections: rawSections.map(
        (key, value) => MapEntry(
          key as String,
          (value as List)
              .map((section) => VocalSection(
                    start: (section as Map)['start'] as double,
                    end: section['end'] as double,
                  ))
              .toList(growable: false),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3-state shuffle: Off → Shuffle → Smart Shuffle → Off

  /// Cycle through Off → Shuffle → Smart Shuffle → Off.
  /// Recalculates the virtual order — the current song keeps playing;
  /// skipToNext will navigate to the first song in the new order.
  Future<void> toggleShuffle() async {
    await _cancelCrossfade(resumeRendered: true);
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
    _invalidateSnapshotCaches();
    if (_shuffleMode == ShuffleMode.off) {
      _shuffleOrder = [];
      _shufflePos = 0;
      _physicalToVirtual = {};
      _queue.setMode(PlaybackMode.normal);
      _queue.setCurrentIndex(player.currentIndex ?? _queue.currentIndex);
      _emitQueueSnapshot(immediate: true);
    } else {
      _queue.setMode(_playbackModeFor(_shuffleMode));
    }

    _ensureShuffleSeed();
    _recalculateShuffleOrder();
  }

  /// Directly set the shuffle mode (used by playlist "Shuffle" button, etc.).
  /// Also recalculates the virtual order.
  Future<void> applyShuffleMode(ShuffleMode mode) async {
    // Mode changes must wait for volume restoration before recalculating the
    // virtual order; otherwise an in-flight fade can mute the new track.
    await _cancelCrossfade(resumeRendered: true);
    _shuffleMode = mode;
    _shuffleModeCtrl.add(mode);
    _shuffleHistory.clear();
    _lastHistoryIndex = null;
    _invalidateSnapshotCaches();
    if (mode == ShuffleMode.off) {
      _shuffleOrder = [];
      _shufflePos = 0;
      _physicalToVirtual = {};
      _queue.setMode(PlaybackMode.normal);
      _queue.setCurrentIndex(player.currentIndex ?? _queue.currentIndex);
      _emitQueueSnapshot(immediate: true);
    } else {
      _queue.setMode(_playbackModeFor(mode));
    }

    _ensureShuffleSeed();
    _recalculateShuffleOrder();
  }

  Future<void> resetPlaybackModes() async {
    _recalcGeneration++;
    await _cancelCrossfade(resumeRendered: true);
    _shuffleMode = ShuffleMode.off;
    _queue.setMode(PlaybackMode.normal);
    _shuffleModeCtrl.add(ShuffleMode.off);
    _shuffleOrder = [];
    _shufflePos = 0;
    _physicalToVirtual = {};
    _invalidateSnapshotCaches();
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

  /// Prepare a rendered companion mix for the exact upcoming pair. Preparation
  /// is intentionally best-effort and never blocks the position stream.
  Future<void> _abortRenderedTransition({bool resume = false}) async {
    final shouldResume = resume && _renderedPausedMainPlayer;
    _renderedTransitionGeneration++;
    _activeTransitionPlayerGeneration = null;
    _renderedTransitionTimeout?.cancel();
    _renderedTransitionTimeout = null;
    _renderedTransitionActive = false;
    _renderedTransitionNextIndex = null;
    _renderedTransitionFromId = null;
    _renderedTransitionToId = null;
    _renderedTransitionDuration = null;
    _renderedMixDuration = null;
    _preparedTransitionDuration = null;
    _renderedPausedMainPlayer = false;
    _renderedQueueGeneration = -1;
    _isTransitionFading = false;
    _preparedTransitionKey = null;
    _preparingTransitionKey = null;
    final path = _preparedTransitionPath;
    _preparedTransitionPath = null;
    await _queueTransitionDeck(() => _transitionPlayer.stop());
    if (path != null) {
      try {
        await File(path).delete();
      } catch (_) {}
    }
    await _writeCrossfadeVolume(_userVolume);
    if (shouldResume && !_disposed) {
      try {
        await player.play();
      } catch (e) {
        debugPrint('Rendered transition recovery play failed: $e');
      }
    }
  }

  Future<void> _prepareRenderedTransition(
    PlannedTransition transition,
  ) async {
    final api = _companionAudioApi;
    String? installedPath;
    if (api == null || transition.kind != TransitionKind.djBlend) return;
    final duration = transition.duration.inMilliseconds / 1000.0;
    final key = '${transition.from.id}|${transition.to.id}|${transition.duration.inMilliseconds}';
    if (_preparedTransitionKey == key || _preparingTransitionKey == key) return;

    _preparingTransitionKey = key;
    final generation = _renderedTransitionGeneration;
    () async {
      try {
        final response = await api.requestTransition(
          songAId: transition.from.id,
          songBId: transition.to.id,
          mixDuration: duration,
        );
        if (generation != _renderedTransitionGeneration ||
            _companionAudioApi != api) return;

        Map<String, dynamic>? result = response;
        final initialStatus = result?['status']?.toString().toLowerCase();
        final jobId = result?['job_id']?.toString() ??
            result?['jobId']?.toString();
        if (jobId != null &&
            jobId.isNotEmpty &&
            initialStatus != 'done' &&
            initialStatus != 'ok') {
          // A mix is normally ready well before the next track. Bound polling
          // so a dead companion can never hold playback or a Dart timer open.
          for (var attempt = 0; attempt < 20; attempt++) {
            await Future<void>.delayed(const Duration(seconds: 1));
            result = await api.pollTransition(jobId);
            final status = result?['status']?.toString().toLowerCase();
            if (status == 'done' ||
                status == 'ok' ||
                status == 'fallback' ||
                status == 'error') {
              break;
            }
          }
        }

        final status = result?['status']?.toString().toLowerCase();
        final rawUrl = result?['url']?.toString();
        if (generation != _renderedTransitionGeneration ||
            status == 'fallback' ||
            status == 'error' ||
            rawUrl == null ||
            rawUrl.isEmpty) {
          return;
        }

        // Fetch through Dio rather than the native player. This preserves the
        // companion API key and self-signed-certificate behavior on both
        // Android and Linux, then lets just_audio play a local WAV file.
        final bytes = await api.downloadTransition(rawUrl);
        if (bytes == null || bytes.length < 12 ||
            String.fromCharCodes(bytes.take(4)) != 'RIFF' ||
            String.fromCharCodes(bytes.skip(8).take(4)) != 'WAVE' ||
            bytes.length > 25 * 1024 * 1024) {
          return;
        }
        if (generation != _renderedTransitionGeneration ||
            _companionAudioApi != api) return;
        final tempDir = await getTemporaryDirectory();
        final safeName = 'melodize_transition_${key.hashCode.abs()}.wav';
        final path = '${tempDir.path}/$safeName';
        installedPath = path;
        await File(path).writeAsBytes(bytes, flush: true);
        if (generation != _renderedTransitionGeneration ||
            _companionAudioApi != api) {
          try { await File(path).delete(); } catch (_) {}
          return;
        }
        final oldPath = _preparedTransitionPath;
        _preparedTransitionPath = path;
        if (oldPath != null && oldPath != path) {
          try { await File(oldPath).delete(); } catch (_) {}
        }
        var sourceLoaded = false;
        await _queueTransitionDeck(() async {
          // Cancellation may have queued a stop while the download was in
          // flight. Do not install an asset that belongs to an old pair.
          if (generation != _renderedTransitionGeneration ||
              _companionAudioApi != api) {
            return;
          }
          await _transitionPlayer.setAudioSource(
            AudioSource.file(path),
            preload: true,
          );
          sourceLoaded = true;
        });
        if (!sourceLoaded ||
            generation != _renderedTransitionGeneration ||
            _companionAudioApi != api) {
          try { await File(path).delete(); } catch (_) {}
          if (_preparedTransitionPath == path) _preparedTransitionPath = null;
          return;
        }
        final renderedDuration = _transitionPlayer.duration;
        if (renderedDuration == null ||
            renderedDuration < const Duration(seconds: 1) ||
            renderedDuration.inMilliseconds >
                transition.duration.inMilliseconds + 500) {
          try { await File(path).delete(); } catch (_) {}
          if (_preparedTransitionPath == path) _preparedTransitionPath = null;
          return;
        }
        _preparedTransitionDuration = renderedDuration;
        if (generation == _renderedTransitionGeneration &&
            _companionAudioApi == api) {
          _preparedTransitionKey = key;
        } else {
          try { await File(path).delete(); } catch (_) {}
          if (_preparedTransitionPath == path) _preparedTransitionPath = null;
        }
      } catch (e) {
        // The live volume crossfade is the deliberate, safe fallback. Remove
        // an asset that was installed before native source loading failed.
        if (installedPath != null) {
          try {
            await File(installedPath!).delete();
          } catch (_) {}
          if (_preparedTransitionPath == installedPath) {
            _preparedTransitionPath = null;
          }
        }
        debugPrint('Rendered transition preparation failed: $e');
      } finally {
        if (_preparingTransitionKey == key) {
          _preparingTransitionKey = null;
        }
      }
    }();
  }

  Future<void> _startRenderedTransition(
    PlannedTransition transition,
    int nextPhysical,
  ) async {
    if (_shuffleMode != ShuffleMode.smartShuffle ||
        _preparedTransitionKey == null ||
        _companionAudioApi == null) {
      _startCrossfadeFadeOut(transition, nextPhysical);
      return;
    }

    final key = '${transition.from.id}|${transition.to.id}|${transition.duration.inMilliseconds}';
    if (_preparedTransitionKey != key) {
      _startCrossfadeFadeOut(transition, nextPhysical);
      return;
    }

    // The companion renderer currently creates the bridge from the final
    // [duration] seconds of A (after known tail silence). Only use it when the
    // live player is at that exact boundary; otherwise its first samples would
    // duplicate or skip audio and the safe volume ramp is preferable.
    final actualMs = player.duration?.inMilliseconds;
    final renderedMs = _preparedTransitionDuration?.inMilliseconds;
    final tailMs = ((_companionBpmCache?.tailSilenceFor(transition.from) ?? 0)
            .clamp(0.0, (actualMs ?? 0) / 2) * 1000)
        .round();
    final expectedStartMs = (actualMs ?? 0) -
        tailMs -
        (renderedMs ?? transition.duration.inMilliseconds);
    if (actualMs == null ||
        expectedStartMs < 0 ||
        renderedMs == null ||
        (player.position.inMilliseconds - expectedStartMs).abs() > 500) {
      _startCrossfadeFadeOut(transition, nextPhysical);
      return;
    }

    final generation = ++_renderedTransitionGeneration;
    _renderedTransitionActive = true;
    _renderedTransitionNextIndex = nextPhysical;
    _renderedTransitionFromId = transition.from.id;
    _renderedTransitionToId = transition.to.id;
    _renderedTransitionDuration = transition.duration;
    _renderedMixDuration = null;
    _renderedPausedMainPlayer = player.playing;
    _renderedQueueGeneration = _recalcGeneration;
    _isTransitionFading = true;

    try {
      // Pause the main deck before the current song can naturally advance.
      // The rendered WAV contains the outgoing tail and incoming head.
      await _writeCrossfadeVolume(
        0,
        generation: _crossfadeGeneration,
      );
      if (generation != _renderedTransitionGeneration ||
          _shuffleMode != ShuffleMode.smartShuffle) {
        await _abortRenderedTransition(resume: true);
        return;
      }
      await player.pause();
      if (generation != _renderedTransitionGeneration ||
          _shuffleMode != ShuffleMode.smartShuffle) {
        await _abortRenderedTransition(resume: true);
        return;
      }
      await _queueTransitionDeck(() async {
        _transitionPlayerGeneration++;
        _activeTransitionPlayerGeneration = _transitionPlayerGeneration;
        await _transitionPlayer.setVolume(_userVolume);
        await _transitionPlayer.seek(Duration.zero);
        await _transitionPlayer.play();
      });
      if (generation != _renderedTransitionGeneration ||
          _shuffleMode != ShuffleMode.smartShuffle) {
        await _abortRenderedTransition(resume: true);
        return;
      }
      _renderedMixDuration = _transitionPlayer.duration;
      _preparedTransitionKey = null;
      _renderedTransitionTimeout?.cancel();
      _renderedTransitionTimeout = Timer(
        transition.duration + const Duration(seconds: 8),
        () => unawaited(_finishRenderedTransition(generation)),
      );
    } catch (e) {
      debugPrint('Rendered transition start failed: $e');
      await _abortRenderedTransition(resume: true);
      // Do not fail playback because the companion deck could not start.
    }
  }

  Future<void> _finishRenderedTransition(int generation) async {
    if (!_renderedTransitionActive ||
        generation != _renderedTransitionGeneration ||
        _queueSnapshotCtrl.isClosed) {
      return;
    }
    final nextIndex = _renderedTransitionNextIndex;
    final duration = _renderedTransitionDuration;
    final mixDuration = _renderedMixDuration ?? duration;
    final fromId = _renderedTransitionFromId;
    final toId = _renderedTransitionToId;
    final preparedPath = _preparedTransitionPath;
    final pausedMainPlayer = _renderedPausedMainPlayer;
    final queueGeneration = _renderedQueueGeneration;
    final currentPhysical = player.currentIndex;
    _renderedTransitionTimeout?.cancel();
    _renderedTransitionTimeout = null;
    _renderedTransitionActive = false;
    _renderedTransitionNextIndex = null;
    _renderedTransitionFromId = null;
    _renderedTransitionToId = null;
    _renderedTransitionDuration = null;
    _renderedMixDuration = null;
    _renderedPausedMainPlayer = false;
    _renderedQueueGeneration = -1;
    _preparedTransitionKey = null;
    _preparedTransitionPath = null;
    _isTransitionFading = false;
    if (nextIndex == null || duration == null ||
        nextIndex < 0 || nextIndex >= _playlistSource.length ||
        nextIndex >= _loadQueueSongs.length) {
      await _queueTransitionDeck(() => _transitionPlayer.stop());
      if (preparedPath != null) {
        try { await File(preparedPath).delete(); } catch (_) {}
      }
      await _writeCrossfadeVolume(_userVolume);
      if (pausedMainPlayer && !_disposed) await player.play();
      return;
    }

    final from = currentSong;
    final to = _loadQueueSongs[nextIndex];
    final currentVirtual = currentPhysical == null
        ? null
        : _physicalToVirtual[currentPhysical];
    final targetVirtual = _physicalToVirtual[nextIndex];
    final mappingStillMatches = currentVirtual != null &&
        queueGeneration == _recalcGeneration &&
        currentVirtual == _shufflePos &&
        targetVirtual != null &&
        currentVirtual + 1 == targetVirtual &&
        targetVirtual >= 0 &&
        targetVirtual < _shuffleOrder.length &&
        _shuffleOrder[targetVirtual] == nextIndex;
    if (from == null ||
        from.id != fromId ||
        to.id != toId ||
        !mappingStillMatches ||
        _shuffleMode != ShuffleMode.smartShuffle) {
      await _queueTransitionDeck(() => _transitionPlayer.stop());
      if (preparedPath != null) {
        try { await File(preparedPath).delete(); } catch (_) {}
      }
      await _writeCrossfadeVolume(_userVolume);
      if (pausedMainPlayer && !_disposed) await player.play();
      return;
    }
    final bpmA = _companionBpmCache?.bpmFor(from);
    final bpmB = _companionBpmCache?.bpmFor(to);
    final rate = bpmA != null && bpmB != null && bpmA > 0 && bpmB > 0
        ? bpmA / bpmB
        : 1.0;
    final sourceOffset = Duration(
      microseconds: (mixDuration!.inMicroseconds * rate).round(),
    );
    final destinationDuration = to.duration == null
        ? null
        : Duration(seconds: to.duration!);
    if (destinationDuration != null &&
        sourceOffset >= destinationDuration - const Duration(milliseconds: 250)) {
      await _queueTransitionDeck(() => _transitionPlayer.stop());
      if (preparedPath != null) {
        try { await File(preparedPath).delete(); } catch (_) {}
      }
      await _writeCrossfadeVolume(_userVolume);
      if (pausedMainPlayer && !_disposed) await player.play();
      return;
    }

    try {
      _seekingVirtual = true;
      await player.seek(sourceOffset, index: nextIndex);
      _queue.setCurrentIndex(nextIndex);
      final vp = _physicalToVirtual[nextIndex];
      if (vp != null) _shufflePos = vp;
      await _queueTransitionDeck(() => _transitionPlayer.stop());
      if (preparedPath != null) {
        try { await File(preparedPath).delete(); } catch (_) {}
      }
      await _writeCrossfadeVolume(_userVolume);
      await player.play();
      _seekingVirtual = false;
      _emitQueueSnapshot(immediate: true);
    } catch (e) {
      _seekingVirtual = false;
      debugPrint('Rendered transition handoff failed: $e');
      await _queueTransitionDeck(() => _transitionPlayer.stop());
      if (preparedPath != null) {
        try { await File(preparedPath).delete(); } catch (_) {}
      }
      await _writeCrossfadeVolume(_userVolume);
      if (pausedMainPlayer && !_disposed) await player.play();
      // A failed handoff leaves the player in a known audible state. The
      // normal skip path remains available to the user.
    }
  }

  void _initCrossfade() {
    _transitionStateSub = _transitionPlayer.processingStateStream.listen((state) {
      final playerGeneration = _activeTransitionPlayerGeneration;
      if (state == ProcessingState.completed &&
          _renderedTransitionActive &&
          playerGeneration != null &&
          playerGeneration == _transitionPlayerGeneration &&
          _renderedQueueGeneration == _recalcGeneration) {
        final generation = _renderedTransitionGeneration;
        unawaited(_finishRenderedTransition(generation));
      }
    });

    // Keep _userVolume in sync with external controllers (system UI, MPRIS).
    player.volumeStream.listen((vol) {
      if (!_isTransitionFading) {
        _userVolume = vol.clamp(0.0, 1.0).toDouble();
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

      // Normal playback and regular shuffle are always gapless. Smart/DJ
      // shuffle is the only mode that may inspect transition metadata or
      // modify volume.
      if (_shuffleMode != ShuffleMode.smartShuffle) return;

      final from = _loadQueueSongs[index];

      // ── Smart shuffle (DJ mode): crossfade using virtual order ──
      if (_shuffleMode == ShuffleMode.smartShuffle) {
        if (_shuffleOrder.isEmpty) return;
        final vp = _physicalToVirtual[index];
        if (vp == null || vp >= _shuffleOrder.length - 1) return;
        final nextPhysical = _shuffleOrder[vp + 1];

        // Anti-loop: don't crossfade to the same song.
        if (nextPhysical == index) { return; }
        if (nextPhysical < 0 ||
            nextPhysical >= _loadQueueSongs.length) { return; }
        final to = _loadQueueSongs[nextPhysical];
        if (from.id == to.id) { return; }
        if (!_canPlayOffline(to)) { return; }

        final actualDuration = player.duration?.inSeconds;
        final transition = _transitionPolicy.planPair(
          from, to,
          actualDurationSeconds: actualDuration,
        );

        // DJ mode: force crossfade even for gapless transitions.
        if (transition.kind == TransitionKind.gapless ||
            transition.duration == Duration.zero) {
          final dur = actualDuration ?? from.duration ?? 0;
          if (dur < 10) { return; } // Too short for any crossfade
          final forcedTransition = PlannedTransition(
            from: from,
            to: to,
            kind: TransitionKind.volumeCrossfade,
            duration: const Duration(seconds: 3),
            fromStart: Duration(seconds: max(0, dur - 4)),
            toStart: Duration.zero,
            reason: 'DJ mode forced crossfade',
          );
          if (position < forcedTransition.fromStart) return;
          _startCrossfadeFadeOut(forcedTransition, nextPhysical);
          return;
        }
        // Request the rendered bridge while there is still time to prepare it.
        // If it is not ready at the boundary, the normal fail-safe volume ramp
        // below is used instead.
        final prepareLead = const Duration(seconds: 15);
        if (position >= transition.fromStart - prepareLead &&
            position < transition.fromStart) {
          unawaited(_prepareRenderedTransition(transition));
          return;
        }
        if (position < transition.fromStart) return;
        if (transition.kind == TransitionKind.djBlend &&
            _preparedTransitionKey != null) {
          unawaited(_startRenderedTransition(transition, nextPhysical));
        } else {
          _startCrossfadeFadeOut(transition, nextPhysical);
        }
        return;
      }
    });
  }

  void _resetCrossfadeState() {
    _crossfadeGeneration++;
    _renderedTransitionGeneration++;
    _activeTransitionPlayerGeneration = null;
    _renderedTransitionTimeout?.cancel();
    _renderedTransitionTimeout = null;
    _crossfadeTimer?.cancel();
    _crossfadeTimer = null;
    _crossfadeTimeout?.cancel();
    _crossfadeTimeout = null;
    _crossfadeActive = false;
    _crossfadeNextIndex = null;
    _renderedTransitionActive = false;
    _renderedTransitionNextIndex = null;
    _renderedTransitionFromId = null;
    _renderedTransitionToId = null;
    _renderedTransitionDuration = null;
    _renderedMixDuration = null;
    _preparedTransitionDuration = null;
    _renderedPausedMainPlayer = false;
    _preparedTransitionKey = null;
    final stalePreparedPath = _preparedTransitionPath;
    _preparedTransitionPath = null;
    if (stalePreparedPath != null) {
      unawaited(() async {
        try {
          await File(stalePreparedPath).delete();
        } catch (_) {}
      }());
    }

    _preparingTransitionKey = null;
    _isTransitionFading = false;
    unawaited(_queueTransitionDeck(() => _transitionPlayer.stop()));
  }

  void _startCrossfadeFadeOut(PlannedTransition transition, int nextIdx) {
    // Defensive guard: only DJ shuffle may ever start a transition.
    if (_shuffleMode != ShuffleMode.smartShuffle) return;
    // Reset synchronously. Awaiting volume restoration here lets an older
    // cancellation finish after this fade starts and overwrite its volume.
    _resetCrossfadeState();
    _crossfadeActive = true;
    _crossfadeNextIndex = nextIdx;

    final totalMs =
        transition.duration.inMilliseconds.clamp(100, 30000).toInt();
    final startVol = _userVolume;
    final startTime = DateTime.now();

    _isTransitionFading = true;

    final fadeGeneration = _crossfadeGeneration;
    _crossfadeTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (timer) {
        if (fadeGeneration != _crossfadeGeneration ||
            _queueSnapshotCtrl.isClosed) {
          timer.cancel();
          return;
        }
        final elapsed = DateTime.now().difference(startTime).inMilliseconds;
        final t = (elapsed / totalMs).clamp(0.0, 1.0);
        final vol = (startVol * (1.0 - t)).clamp(0.0, 1.0).toDouble();
        final write = _writeCrossfadeVolume(vol, generation: fadeGeneration);
        if (t >= 1.0) {
          timer.cancel();
          // Do not seek or arm the timeout until the final fade-out write has
          // reached the platform player.
          unawaited(write.then((_) {
            if (fadeGeneration != _crossfadeGeneration ||
                !_crossfadeActive) {
              return;
            }
            if (_shuffleMode == ShuffleMode.smartShuffle &&
                _crossfadeNextIndex != null) {
              // DJ mode: explicitly seek to the next virtual song
              // instead of relying on physical auto-advance.
              _performVirtualSeekForCrossfade(_crossfadeNextIndex!);
            } else {
              // Normal mode: wait for auto-advance.
              _crossfadeTimeout = Timer(const Duration(seconds: 5), () {
                if (_crossfadeActive) {
                  _cancelCrossfade();
                }
              });
            }
          }));
        }
      },
    );
  }

  /// DJ mode: explicitly seek to the next virtual song after crossfade
  /// fade-out completes. Handles the case where physical auto-advance
  /// would go to the wrong song in virtual shuffle orders.
  void _performVirtualSeekForCrossfade(int targetPhysicalIndex) {
    // Verify target is still valid.
    if (targetPhysicalIndex < 0 ||
        targetPhysicalIndex >= _playlistSource.length ||
        targetPhysicalIndex >= _loadQueueSongs.length) {
      _cancelCrossfade();
      return;
    }

    // Anti-loop: verify target differs from current.
    final currentIdx = player.currentIndex;
    if (currentIdx == null || targetPhysicalIndex == currentIdx) {
      _cancelCrossfade();
      return;
    }

    // Anti-loop: verify different song by ID.
    if (currentIdx >= 0 &&
        currentIdx < _loadQueueSongs.length &&
        targetPhysicalIndex < _loadQueueSongs.length &&
        _loadQueueSongs[currentIdx].id ==
            _loadQueueSongs[targetPhysicalIndex].id) {
      _cancelCrossfade();
      return;
    }

    // Safety timeout: if seek never completes, restore volume.
    _crossfadeTimeout = Timer(const Duration(seconds: 8), () {
      if (_crossfadeActive) {
        debugPrint('Crossfade virtual seek timeout — restoring volume');
        _cancelCrossfade();
      }
    });

    _seekingVirtual = true;
    player.seek(Duration.zero, index: targetPhysicalIndex).then((_) {
      _seekingVirtual = false;
    }).catchError((Object e) {
      debugPrint('Crossfade virtual seek error: $e');
      _seekingVirtual = false;
      unawaited(_cancelCrossfade());
    });

    // Update virtual position immediately so the UI reflects the change.
    final vp = _physicalToVirtual[targetPhysicalIndex];
    if (vp != null) _shufflePos = vp;
    _queue.setCurrentIndex(targetPhysicalIndex);
    _emitQueueSnapshot(immediate: true);
  }

  Future<void> _startCrossfadeFadeIn() async {
    // Defensive guard: regular playback and regular shuffle are gapless.
    if (_shuffleMode != ShuffleMode.smartShuffle) return;
    // A natural advance can arrive before fade-out's final timer tick. Stop
    // that timer, let queued volume writes drain, then start from the actual
    // player volume instead of jumping over a pending platform write.
    _crossfadeTimer?.cancel();
    _crossfadeTimer = null;
    _crossfadeTimeout?.cancel();
    _crossfadeTimeout = null;
    _crossfadeActive = false;
    _crossfadeNextIndex = null;
    _isTransitionFading = false;

    await _volumeWrite;
    if (_queueSnapshotCtrl.isClosed) return;

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

    final fadeGeneration = _crossfadeGeneration;
    _crossfadeTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (timer) {
        if (fadeGeneration != _crossfadeGeneration ||
            _queueSnapshotCtrl.isClosed) {
          timer.cancel();
          return;
        }
        final elapsed = DateTime.now().difference(startTime).inMilliseconds;
        final t = (elapsed / totalMs).clamp(0.0, 1.0);
        final vol =
            (startVol + (targetVol - startVol) * t).clamp(0.0, 1.0).toDouble();
        unawaited(_writeCrossfadeVolume(vol, generation: fadeGeneration));
        if (t >= 1.0) {
          timer.cancel();
          _isTransitionFading = false;
        }
      },
    );
  }

  Future<void> _writeCrossfadeVolume(double volume, {int? generation}) {
    final operation = _volumeWrite.then<void>((_) async {
      // Queue volume operations so an older platform-channel write cannot
      // overtake a newer fade. Re-check the generation when this operation
      // reaches the front of the queue.
      if (generation != null && generation != _crossfadeGeneration) return;
      try {
        await player.setVolume(volume);
      } catch (e) {
        debugPrint('Crossfade volume error: $e');
      }
    });
    _volumeWrite = operation;
    return operation;
  }

  Future<void> _cancelCrossfade({bool resumeRendered = false}) async {
    final shouldResumeRendered = resumeRendered &&
        _renderedTransitionActive &&
        _renderedPausedMainPlayer;
    _resetCrossfadeState();
    final generation = _crossfadeGeneration;
    await _writeCrossfadeVolume(_userVolume, generation: generation);
    await _transitionDeckOperation;
    final path = _preparedTransitionPath;
    _preparedTransitionPath = null;
    _preparedTransitionDuration = null;
    if (path != null) {
      try { await File(path).delete(); } catch (_) {}
    }
    if (shouldResumeRendered && !_disposed) {
      try { await player.play(); } catch (_) {}
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
    if (!Platform.isLinux || _disposed) return;
    await _mpris?.dispose();
    if (_disposed) return;
    final service = LinuxMprisService(
      player: player,
      getCurrentSong: () => currentSong,
      play: play,
      pause: pause,
      stop: stop,
      seek: seek,
      setVolume: _setExternalVolume,
      skipToPrevious: skipToPrevious,
      skipToNext: skipToNext,
      getShuffleMode: () => _shuffleMode,
      shuffleModeStream: _shuffleModeCtrl.stream,
    );
    _mpris = service;
    await service.start();
    if (_disposed) {
      await service.dispose();
      if (identical(_mpris, service)) _mpris = null;
    }
  }

  Future<void> _setExternalVolume(double volume) async {
    _userVolume = volume.clamp(0.0, 1.0).toDouble();
    await _cancelCrossfade();
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
    final vol = (player.volume + delta).clamp(0.0, 1.0).toDouble();
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

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    if (Platform.isLinux) {
      HardwareKeyboard.instance.removeHandler(_handleMediaKey);
      await _mpris?.dispose();
      _mpris = null;
    }
    _shuffleModeCtrl.close();
    _queueSnapshotCtrl.close();
    _shuffleOrder = [];
    _shufflePos = 0;
    _physicalToVirtual = {};
    _invalidateSnapshotCaches();
    _loadQueueSongs = const [];
    _queueBpmCache = null;
    _queueBpmCacheSignature = 0;
    _queueBpmCacheCompanion = null;
    await _transitionStateSub?.cancel();
    _crossfadeSub?.cancel();
    _crossfadeTimer?.cancel();
    _crossfadeTimeout?.cancel();
    _renderedTransitionTimeout?.cancel();
    _renderedTransitionTimeout = null;
    _recalcDebounceTimer?.cancel();
    _recalcGeneration++;
    await _cancelCrossfade(resumeRendered: false);
    await _transitionPlayer.dispose();
    _sleepTimer?.cancel();
    _historyController.close();
    await player.dispose();
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
