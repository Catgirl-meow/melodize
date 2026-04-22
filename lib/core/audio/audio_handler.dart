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
// manage shuffle by physically reordering the ConcatenatingAudioSource
// (setAudioSource with a re-built playlist).  A separate StreamController
// carries the shuffle-on/off state so the UI still reflects it correctly.
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

  // Linux-only manual shuffle state (see file-top comment).
  bool _linuxShuffled = false;
  List<Song> _preShuffleOrder = [];   // queue order captured before shuffle
  final _linuxShuffleCtrl = StreamController<bool>.broadcast();

  /// Shuffle-mode stream.  On Linux this is our own controller; on other
  /// platforms it forwards just_audio's native stream.
  Stream<bool> get shuffleStream => Platform.isLinux
      ? _linuxShuffleCtrl.stream
      : player.shuffleModeEnabledStream;

  // When true, currentSongStream holds its last non-null value instead of
  // emitting null.  Set during setAudioSource calls on Linux so the
  // now-playing screen doesn't flash/disappear while the source is reloading.
  bool _holdSongNull = false;
  Song? _lastSong;

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
    // Also immediately broadcast playbackState with position=0 so the system
    // player (OriginOS Island, lock screen) sees new song + correct time in
    // one event — prevents showing "new song title, position = 2:35 (old song)"
    // when mediaItem and playbackState update in separate microtasks.
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

  Song? get currentSong =>
      player.sequenceState?.currentSource?.tag as Song?;

  Stream<Song?> get currentSongStream => player.sequenceStateStream.map((s) {
        final song = s?.currentSource?.tag as Song?;
        if (song != null) _lastSong = song;
        // During setAudioSource reload (shuffle toggle), suppress the transient
        // null so the now-playing screen doesn't blink away.
        if (song == null && _holdSongNull) return _lastSong;
        return song;
      });

  // ---------------------------------------------------------------------------
  // Queue management

  Future<void> loadQueue(List<Song> songs, {int startIndex = 0}) async {
    if (_config == null || songs.isEmpty) return;
    _shuffleHistory.clear();
    _lastHistoryIndex = null;
    final idx = startIndex.clamp(0, songs.length - 1);

    if (Platform.isLinux) {
      // On Linux (just_audio_media_kit / libmpv), insertAll() before the
      // current index does not reliably update currentIndex, causing the
      // sequenceState to report the wrong song (wrong title/cover).
      // Load the full queue upfront instead — desktop doesn't have the
      // platform-channel latency that makes this slow on mobile.
      //
      // preload: true (default) tells mpv to open the audio device and start
      // buffering while setAudioSource awaits, so play() produces audio with
      // minimal delay instead of waiting for PipeWire to initialize on play().
      _linuxShuffled = false;
      _preShuffleOrder = [];
      _linuxShuffleCtrl.add(false);
      _playlistSource = ConcatenatingAudioSource(
        children: songs.map(_songToSource).toList(),
        useLazyPreparation: true,
      );
      try {
        await player.setAudioSource(_playlistSource, initialIndex: idx);
        await player.play();
      } catch (e) {
        debugPrint('loadQueue error: $e');
      }
      return;
    }

    // Mobile: two-phase loading to avoid tap-lag from pre-preparing all sources.
    // Phase 1: fresh playlist with only the selected song — single
    // platform-channel call, no expensive clear() of the old queue.
    _playlistSource = ConcatenatingAudioSource(
      children: [_songToSource(songs[idx])],
      useLazyPreparation: true,
    );
    try {
      await player.setAudioSource(_playlistSource, initialIndex: 0, preload: false);
      await player.play();
    } catch (e) {
      debugPrint('loadQueue error: $e');
      return;
    }
    // Phase 2: fill the rest of the queue while music plays.
    // insertAll(0, …) shifts current track from index 0 → idx.
    if (idx > 0) {
      await _playlistSource.insertAll(
          0, songs.sublist(0, idx).map(_songToSource).toList());
    }
    if (idx + 1 < songs.length) {
      await _playlistSource.addAll(
          songs.sublist(idx + 1).map(_songToSource).toList());
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
      try {
        await player.seek(Duration.zero, index: prevIndex);
      } finally {
        _seekingBack = false;
      }
    } else {
      await player.seekToPrevious();
    }
  }

  Future<void> skipToIndex(int index) =>
      player.seek(Duration.zero, index: index);

  Future<void> toggleShuffle() async {
    if (Platform.isLinux) {
      return _toggleShuffleLinux();
    }
    if (player.shuffleModeEnabled) {
      // Turning shuffle off — clear history so back works normally.
      _shuffleHistory.clear();
      _lastHistoryIndex = null;
    }
    await player.setShuffleModeEnabled(!player.shuffleModeEnabled);
  }

  // Rebuilds the ConcatenatingAudioSource in the desired order so that both
  // just_audio and mpv always agree on what is playing — bypassing mpv's
  // native shuffle whose order diverges from just_audio's shuffleIndices.
  Future<void> _toggleShuffleLinux() async {
    final song = currentSong;

    List<Song> orderedSongs;

    if (_linuxShuffled) {
      // Restore the pre-shuffle order.
      _linuxShuffled = false;
      orderedSongs = _preShuffleOrder;
      _preShuffleOrder = [];
    } else {
      // Snapshot current queue order, then shuffle with current song first.
      _linuxShuffled = true;
      final seqSongs = player.sequenceState?.effectiveSequence
              .map((s) => s.tag)
              .whereType<Song>()
              .toList() ??
          [];
      _preShuffleOrder = seqSongs;
      orderedSongs = List<Song>.from(seqSongs);
      if (song != null) {
        orderedSongs.removeWhere((s) => s.id == song.id);
        orderedSongs.shuffle();
        orderedSongs.insert(0, song);
      } else {
        orderedSongs.shuffle();
      }
    }

    // Emit the new shuffle state immediately so the button lights up at once.
    _linuxShuffleCtrl.add(_linuxShuffled);

    // Rebuild the ConcatenatingAudioSource in the desired order and reload it.
    //
    // The previous approach (removeRange + insertAll) issued N playlist-move
    // commands to MPV for an N-song queue.  MPV's event queue overflows and
    // all moves fail silently, leaving a 1-song queue that stops after the
    // current track.  setAudioSource avoids that: it issues a single loadlist
    // command and seeks back to the saved position, causing only a brief gap
    // (~1 s on LAN) instead of a silently broken queue.
    final pos = player.position;
    _holdSongNull = true;
    _playlistSource = ConcatenatingAudioSource(
      children: orderedSongs.map(_songToSource).toList(),
      useLazyPreparation: true,
    );
    try {
      await player.setAudioSource(_playlistSource, initialIndex: 0, preload: true);
      await player.seek(pos);
      await player.play();
    } catch (e) {
      debugPrint('toggleShuffle error: $e');
    } finally {
      _holdSongNull = false;
    }
  }

  Future<void> resetPlaybackModes() async {
    if (Platform.isLinux) {
      _linuxShuffled = false;
      _preShuffleOrder = [];
      _linuxShuffleCtrl.add(false);
    } else {
      await player.setShuffleModeEnabled(false);
    }
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

  // Returns true if a text-input widget currently has keyboard focus.
  // Used to suppress vim shortcuts while the user is typing.
  bool _isTextFieldFocused() {
    final focus = FocusManager.instance.primaryFocus;
    return focus?.context?.widget is EditableText;
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
        player.seekToNext();
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
        player.seekToNext();
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
      _linuxShuffleCtrl.close();
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
