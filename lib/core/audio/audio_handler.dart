import 'dart:async';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import '../models/song.dart';
import '../api/subsonic_client.dart';
import '../linux/linux_mpris.dart';

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

  // useLazyPreparation: false on Android/iOS — ExoPlayer/AVPlayer eagerly
  // prepares all source timelines (lightweight header reads) so they can
  // buffer across track boundaries for gapless playback.
  // Set to true on Linux/desktop (just_audio_media_kit / libmpv backend).
  final _playlistSource = ConcatenatingAudioSource(
    children: [],
    useLazyPreparation: Platform.isLinux || Platform.isWindows || Platform.isMacOS,
  );

  SubsonicConfig? _config;
  String _streamQuality = 'lossless';
  Timer? _sleepTimer;
  bool _nowPlayingReported = false;
  bool _scrobbled = false;
  LinuxMprisService? _mpris;

  // Shuffle playback history — tracks the actual sequence of songs heard so
  // that skipToPrevious goes back to the song the user really listened to last,
  // not just the adjacent position in the (fixed) shuffled order.
  final _shuffleHistory = <int>[];  // original-sequence indices
  int? _lastHistoryIndex;
  bool _seekingBack = false;

  // ---------------------------------------------------------------------------
  // MediaSession sync — keeps audio_service's playbackState + mediaItem current
  // so the notification, lock screen, and Bluetooth display show correct info.

  void _initStateSync() {
    // Update MediaSession playback state on play/pause/processing changes.
    player.playerStateStream.listen((_) => _broadcastState());

    // Track shuffle playback history so skipToPrevious works correctly.
    player.currentIndexStream.listen((index) {
      if (_seekingBack || index == null) return;
      if (!player.shuffleModeEnabled) {
        _shuffleHistory.clear();
        _lastHistoryIndex = null;
        return;
      }
      if (_lastHistoryIndex != null && _lastHistoryIndex != index) {
        _shuffleHistory.add(_lastHistoryIndex!);
        if (_shuffleHistory.length > 100) _shuffleHistory.removeAt(0);
      }
      _lastHistoryIndex = index;
    });

    // Update MediaSession media item when the current song changes.
    player.sequenceStateStream.listen((seqState) {
      final song = seqState?.currentSource?.tag as Song?;
      if (song == null) {
        mediaItem.add(null);
        return;
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
    });
  }

  void _broadcastState() {
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
      updatePosition: player.position,
      bufferedPosition: player.bufferedPosition,
      speed: player.speed,
      queueIndex: player.currentIndex,
    ));
  }

  // ---------------------------------------------------------------------------

  void setConfig(SubsonicConfig config) {
    _config = config;
    // Re-emit mediaItem with artUri now that the server config is available.
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

  Song? get currentSong =>
      player.sequenceState?.currentSource?.tag as Song?;

  Stream<Song?> get currentSongStream => player.sequenceStateStream
      .map((s) => s?.currentSource?.tag as Song?);

  // ---------------------------------------------------------------------------
  // Queue management

  Future<void> loadQueue(List<Song> songs, {int startIndex = 0}) async {
    if (_config == null || songs.isEmpty) return;
    _shuffleHistory.clear();
    _lastHistoryIndex = null;
    await _playlistSource.clear();
    await _playlistSource.addAll(songs.map(_songToSource).toList());
    try {
      // preload: false — setAudioSource returns immediately; sources are
      // prepared in the background while the first track starts playing.
      // Without this, setAudioSource blocks until all sources in the
      // ConcatenatingAudioSource are prepared (useLazyPreparation: false
      // means all of them), causing a delay proportional to queue length.
      await player.setAudioSource(
        _playlistSource,
        initialIndex: startIndex.clamp(0, songs.length - 1),
        preload: false,
      );
      await player.play();
    } catch (e) {
      debugPrint('loadQueue error: $e');
    }
  }

  Future<void> playNext(Song song) async {
    if (_config == null) return;
    final idx =
        ((player.currentIndex ?? 0) + 1).clamp(0, _playlistSource.length);
    await _playlistSource.insert(idx, _songToSource(song));
  }

  Future<void> addToQueue(Song song) async {
    if (_config == null) return;
    await _playlistSource.add(_songToSource(song));
  }

  Future<void> removeFromQueue(int index) =>
      _playlistSource.removeAt(index);

  Future<void> removeSongById(String songId) async {
    for (int i = _playlistSource.length - 1; i >= 0; i--) {
      final child = _playlistSource[i];
      final tag = child is IndexedAudioSource ? child.tag : null;
      if (tag is Song && tag.id == songId) {
        await _playlistSource.removeAt(i);
      }
    }
  }

  Future<void> reorderQueue(int oldIndex, int newIndex) =>
      _playlistSource.move(oldIndex, newIndex);

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
  Future<void> skipToNext() => player.seekToNext();

  @override
  Future<void> skipToPrevious() async {
    if (player.position.inSeconds > 3) {
      await player.seek(Duration.zero);
      return;
    }
    if (player.shuffleModeEnabled && _shuffleHistory.isNotEmpty) {
      final prevIndex = _shuffleHistory.removeLast();
      _seekingBack = true;
      _lastHistoryIndex = prevIndex;
      await player.seek(Duration.zero, index: prevIndex);
      _seekingBack = false;
    } else {
      await player.seekToPrevious();
    }
  }

  Future<void> skipToIndex(int index) =>
      player.seek(Duration.zero, index: index);

  Future<void> toggleShuffle() {
    if (player.shuffleModeEnabled) {
      // Turning shuffle off — clear history so back works normally.
      _shuffleHistory.clear();
      _lastHistoryIndex = null;
    }
    return player.setShuffleModeEnabled(!player.shuffleModeEnabled);
  }

  Future<void> resetPlaybackModes() async {
    await player.setShuffleModeEnabled(false);
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
    );
    await _mpris!.start();
  }

  // ---------------------------------------------------------------------------
  // Linux media key handling via HardwareKeyboard
  //
  // On Wayland (niri), the compositor forwards XF86 media keys to the focused
  // window as standard key events. MPRIS (via audio_service) handles the
  // unfocused case; this covers when the app window is in focus.

  bool _handleMediaKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    // Debug: print all key-down events so we can see if XF86 keys reach Flutter
    // and what their logical key ID is. Remove once media keys are confirmed working.
    debugPrint('[media] key: ${event.logicalKey.debugName} id:0x${event.logicalKey.keyId.toRadixString(16)}');

    switch (event.logicalKey) {
      case LogicalKeyboardKey.mediaPlay:
      case LogicalKeyboardKey.mediaPlayPause:
        player.playing ? player.pause() : player.play();
        return true;
      case LogicalKeyboardKey.mediaPause:
        player.pause();
        return true;
      case LogicalKeyboardKey.mediaTrackNext:
        player.seekToNext();
        return true;
      case LogicalKeyboardKey.mediaTrackPrevious:
        skipToPrevious();
        return true;
      case LogicalKeyboardKey.mediaStop:
        player.stop();
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
    _sleepTimer?.cancel();
    _historyController.close();
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
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
        androidNotificationIcon: 'mipmap/ic_launcher',
      ),
    );
  } catch (e, st) {
    debugPrint('AudioService.init failed: $e\n$st');
  }
}
