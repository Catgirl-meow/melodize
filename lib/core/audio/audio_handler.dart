import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../models/song.dart';
import '../api/subsonic_client.dart';

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

  // useLazyPreparation: false — ExoPlayer eagerly prepares all sources in the
  // playlist (lightweight: reads headers / timelines, does not download audio).
  // This lets ExoPlayer buffer across track boundaries for gapless playback.
  // With true (default), each source is only prepared when it becomes current,
  // causing a perceptible gap at every track transition.
  final _playlistSource = ConcatenatingAudioSource(
    children: [],
    useLazyPreparation: false,
  );

  SubsonicConfig? _config;
  String _streamQuality = 'lossless';
  Timer? _sleepTimer;
  bool _nowPlayingReported = false;
  bool _scrobbled = false;

  // ---------------------------------------------------------------------------
  // MediaSession sync — keeps audio_service's playbackState + mediaItem current
  // so the notification, lock screen, and Bluetooth display show correct info.

  void _initStateSync() {
    // Update MediaSession playback state on play/pause/processing changes.
    player.playerStateStream.listen((_) => _broadcastState());

    // Update MediaSession media item when the current song changes.
    player.sequenceStateStream.listen((seqState) {
      final song = seqState?.currentSource?.tag as Song?;
      if (song == null) {
        mediaItem.add(null);
        return;
      }
      mediaItem.add(MediaItem(
        id: song.id,
        title: song.title,
        artist: song.artist,
        album: song.album,
        duration: song.duration != null
            ? Duration(seconds: song.duration!)
            : null,
        artUri: _config != null && (song.coverArt?.isNotEmpty ?? false)
            ? Uri.tryParse(
                SubsonicClient(_config!).coverArtUrl(song.coverArt!))
            : null,
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
    } else {
      await player.seekToPrevious();
    }
  }

  Future<void> skipToIndex(int index) =>
      player.seek(Duration.zero, index: index);

  Future<void> toggleShuffle() =>
      player.setShuffleModeEnabled(!player.shuffleModeEnabled);

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
    if (song.isDownloaded && song.localPath != null) {
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

  void dispose() {
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
  } catch (e) {
    debugPrint('MediaSession setup failed (headphone buttons unavailable): $e');
  }
}
