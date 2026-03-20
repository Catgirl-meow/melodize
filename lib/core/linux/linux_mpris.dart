import 'dart:async';
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../models/song.dart';

/// Registers an MPRIS2 D-Bus service under org.mpris.MediaPlayer2.melodize
/// so that playerctl (and niri's XF86 keybindings) can control Melodize.
///
/// Only active on Linux. Call [start] once after app init, [dispose] on exit.
class LinuxMprisService {
  final AudioPlayer player;
  final Song? Function() getCurrentSong;
  final Future<void> Function() skipToPrevious;

  DBusClient? _client;
  _MprisObject? _obj;
  final _subs = <StreamSubscription<dynamic>>[];

  LinuxMprisService({
    required this.player,
    required this.getCurrentSong,
    required this.skipToPrevious,
  });

  Future<void> start() async {
    if (!Platform.isLinux) return;
    try {
      _client = DBusClient.session();
      _obj = _MprisObject(
        player: player,
        getCurrentSong: getCurrentSong,
        skipToPrevious: skipToPrevious,
      );
      await _client!.registerObject(_obj!);
      final reply = await _client!.requestName('org.mpris.MediaPlayer2.melodize');
      debugPrint('[MPRIS] registered: $reply');

      _subs.add(player.playerStateStream.listen((_) => _obj!._onPlayerState()));
      _subs.add(player.sequenceStateStream.listen((_) => _obj!._onSequence()));
      _subs.add(player.shuffleModeEnabledStream.listen((_) => _obj!._onShuffle()));
    } catch (e, st) {
      debugPrint('[MPRIS] start failed: $e\n$st');
    }
  }

  Future<void> dispose() async {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    await _client?.close();
    _client = null;
  }
}

// ---------------------------------------------------------------------------

class _MprisObject extends DBusObject {
  final AudioPlayer player;
  final Song? Function() getCurrentSong;
  final Future<void> Function() skipToPrevious;

  _MprisObject({
    required this.player,
    required this.getCurrentSong,
    required this.skipToPrevious,
  }) : super(DBusObjectPath('/org/mpris/MediaPlayer2'));

  // --- Method dispatch -------------------------------------------------------

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall call) async {
    if (call.interface == 'org.mpris.MediaPlayer2') {
      // Raise / Quit — no-ops for a background audio app
      return DBusMethodSuccessResponse();
    }

    if (call.interface != 'org.mpris.MediaPlayer2.Player') {
      return DBusMethodErrorResponse.unknownInterface();
    }

    switch (call.name) {
      case 'Play':
        await player.play();
      case 'Pause':
        await player.pause();
      case 'PlayPause':
        player.playing ? await player.pause() : await player.play();
      case 'Stop':
        await player.stop();
      case 'Next':
        await player.seekToNext();
      case 'Previous':
        await skipToPrevious();
      case 'Seek':
        if (call.values.isNotEmpty) {
          final us = (call.values[0] as DBusInt64).value;
          final newPos = player.position + Duration(microseconds: us);
          await player.seek(newPos.isNegative ? Duration.zero : newPos);
        }
      case 'SetPosition':
        if (call.values.length >= 2) {
          final us = (call.values[1] as DBusInt64).value;
          await player.seek(Duration(microseconds: us));
        }
      case 'OpenUri':
        break; // not supported
      default:
        return DBusMethodErrorResponse.unknownMethod();
    }
    return DBusMethodSuccessResponse();
  }

  // --- Properties -----------------------------------------------------------

  String get _playbackStatus {
    final ps = player.processingState;
    if (ps == ProcessingState.idle || ps == ProcessingState.completed) {
      return 'Stopped';
    }
    return player.playing ? 'Playing' : 'Paused';
  }

  DBusValue get _metadataValue {
    final song = getCurrentSong();
    final map = <DBusValue, DBusValue>{};
    if (song == null) {
      map[const DBusString('mpris:trackid')] = DBusVariant(
        DBusObjectPath('/org/mpris/MediaPlayer2/TrackList/NoTrack'),
      );
    } else {
      final trackId = '/melodize/${_sanitize(song.id)}';
      map[const DBusString('mpris:trackid')] =
          DBusVariant(DBusObjectPath(trackId));
      map[const DBusString('xesam:title')] =
          DBusVariant(DBusString(song.title));
      map[const DBusString('xesam:artist')] = DBusVariant(
        DBusArray(
          DBusSignature('s'),
          [DBusString(song.artist ?? '')],
        ),
      );
      map[const DBusString('xesam:album')] =
          DBusVariant(DBusString(song.album ?? ''));
      if (song.duration != null) {
        map[const DBusString('mpris:length')] =
            DBusVariant(DBusInt64((song.duration! * 1000000).toInt()));
      }
    }
    return DBusDict(DBusSignature('s'), DBusSignature('v'), map);
  }

  String _sanitize(String id) => id.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');

  Map<String, DBusValue> get _playerProps => {
        'PlaybackStatus': DBusString(_playbackStatus),
        'LoopStatus': const DBusString('None'),
        'Rate': const DBusDouble(1.0),
        'Shuffle': DBusBoolean(player.shuffleModeEnabled),
        'Metadata': _metadataValue,
        'Volume': DBusDouble(player.volume),
        'Position': DBusInt64(player.position.inMicroseconds),
        'MinimumRate': const DBusDouble(1.0),
        'MaximumRate': const DBusDouble(1.0),
        'CanGoNext': const DBusBoolean(true),
        'CanGoPrevious': const DBusBoolean(true),
        'CanPlay': const DBusBoolean(true),
        'CanPause': const DBusBoolean(true),
        'CanSeek': const DBusBoolean(true),
        'CanControl': const DBusBoolean(true),
      };

  Map<String, DBusValue> get _appProps => {
        'CanQuit': const DBusBoolean(false),
        'CanRaise': const DBusBoolean(false),
        'HasTrackList': const DBusBoolean(false),
        'Identity': const DBusString('Melodize'),
        'DesktopEntry': const DBusString('melodize'),
        'SupportedUriSchemes':
            DBusArray(DBusSignature('s'), const []),
        'SupportedMimeTypes':
            DBusArray(DBusSignature('s'), const []),
      };

  @override
  Future<DBusMethodResponse> getAllProperties(String interface) async {
    final raw = interface == 'org.mpris.MediaPlayer2'
        ? _appProps
        : interface == 'org.mpris.MediaPlayer2.Player'
            ? _playerProps
            : <String, DBusValue>{};
    final dict = DBusDict(
      DBusSignature('s'),
      DBusSignature('v'),
      raw.map((k, v) => MapEntry(DBusString(k), DBusVariant(v))),
    );
    return DBusMethodSuccessResponse([dict]);
  }

  @override
  Future<DBusMethodResponse> getProperty(
      String interface, String name) async {
    final raw = interface == 'org.mpris.MediaPlayer2'
        ? _appProps
        : interface == 'org.mpris.MediaPlayer2.Player'
            ? _playerProps
            : <String, DBusValue>{};
    final value = raw[name];
    if (value == null) return DBusMethodErrorResponse.unknownProperty();
    return DBusMethodSuccessResponse([DBusVariant(value)]);
  }

  @override
  Future<DBusMethodResponse> setProperty(
      String interface, String name, DBusValue value) async {
    if (interface == 'org.mpris.MediaPlayer2.Player' && name == 'Volume') {
      await player.setVolume((value as DBusDouble).value.clamp(0.0, 1.0));
      return DBusMethodSuccessResponse();
    }
    return DBusMethodErrorResponse.propertyReadOnly();
  }

  // --- PropertiesChanged signals -------------------------------------------

  void _onPlayerState() {
    emitPropertiesChanged(
      'org.mpris.MediaPlayer2.Player',
      changedProperties: {'PlaybackStatus': DBusString(_playbackStatus)},
    );
  }

  void _onSequence() {
    emitPropertiesChanged(
      'org.mpris.MediaPlayer2.Player',
      changedProperties: {'Metadata': _metadataValue},
    );
  }

  void _onShuffle() {
    emitPropertiesChanged(
      'org.mpris.MediaPlayer2.Player',
      changedProperties: {'Shuffle': DBusBoolean(player.shuffleModeEnabled)},
    );
  }
}
