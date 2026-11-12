import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Turns an exception into one short sentence a user can act on.
///
/// Keeps the real cause visible (status code, server message, OS error)
/// instead of a generic "something went wrong", but strips the Dart type
/// prefixes and stack noise that mean nothing to a user.
String describeError(Object error) {
  if (error is DioException) {
    final status = error.response?.statusCode;
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
        return 'Connection timed out';
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'The server took too long to answer';
      case DioExceptionType.badCertificate:
        return 'The server\'s TLS certificate was rejected';
      case DioExceptionType.cancel:
        return 'Request was cancelled';
      case DioExceptionType.badResponse:
        if (status == 401 || status == 403) {
          return 'Access denied (HTTP $status) — check your credentials';
        }
        if (status == 404) return 'Not found on the server (HTTP 404)';
        if (status != null && status >= 500) {
          return 'Server error (HTTP $status)';
        }
        return 'Unexpected server response (HTTP $status)';
      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
        final inner = error.error;
        if (inner is SocketException) return _describeSocket(inner);
        if (inner is HandshakeException) {
          return 'TLS handshake failed — check the server address';
        }
        if (inner != null) return describeError(inner);
        return 'Could not connect to the server';
    }
  }
  if (error is SocketException) return _describeSocket(error);
  if (error is FileSystemException) {
    final os = error.osError?.message;
    final path = error.path;
    return [
      error.message,
      if (os != null && os.isNotEmpty) os,
      if (path != null && path.isNotEmpty) path,
    ].join(': ');
  }
  if (error is TimeoutException) return 'Timed out';
  var text = error.toString();
  for (final prefix in const [
    'Exception: ',
    'FormatException: ',
    'Subsonic error: ',
  ]) {
    if (text.startsWith(prefix)) text = text.substring(prefix.length);
  }
  return text;
}

String _describeSocket(SocketException e) {
  final os = e.osError?.message;
  if (os != null && os.isNotEmpty) return 'Could not connect: $os';
  return 'Could not connect: ${e.message}';
}

/// One user-visible failure. Identity equality on purpose: two identical
/// failures in a row are two events, and both must reach the UI.
class AppError {
  final String message;
  final DateTime at;
  AppError(this.message) : at = DateTime.now();

  @override
  String toString() => message;
}

/// App-wide channel for failures that happen away from any screen that could
/// show them (audio handler, settings persistence, startup). The main shell
/// listens and shows each one as an error snackbar.
///
/// The rule this exists for: a failure is never swallowed into a silent
/// default. Either the screen that asked shows the error, or it goes here.
class AppErrors {
  AppErrors._();

  static final _pending = <AppError>[];
  static AppError? _last;
  static const _maxPending = 5;
  static final StreamController<AppError> _ctrl =
      StreamController<AppError>.broadcast(onListen: _flushPending);

  /// Every reported error, in order. Errors reported before anything
  /// listens (e.g. during startup, before the shell is on screen) are kept
  /// and delivered to the first listener.
  static Stream<AppError> get stream => _ctrl.stream;

  /// Report a failure. [what] says what the user was trying to do, e.g.
  /// "Couldn't save settings"; the cause from [error] is appended.
  static void report(String what, [Object? error]) {
    final message = error == null ? what : '$what: ${describeError(error)}';
    debugPrint('[AppErrors] $message${error == null ? '' : ' ($error)'}');
    // One failure can surface through two paths at once (e.g. the player's
    // event stream and the play() call that triggered it). Show it once.
    final last = _last;
    if (last != null &&
        last.message == message &&
        DateTime.now().difference(last.at) < const Duration(seconds: 2)) {
      return;
    }
    final appError = AppError(message);
    _last = appError;
    if (_ctrl.hasListener) {
      _ctrl.add(appError);
    } else {
      _pending.add(appError);
      if (_pending.length > _maxPending) _pending.removeAt(0);
    }
  }

  static void _flushPending() {
    // Deliver on a later microtask so the new listener is fully attached.
    scheduleMicrotask(() {
      final queued = List<AppError>.from(_pending);
      _pending.clear();
      queued.forEach(_ctrl.add);
    });
  }

  @visibleForTesting
  static void resetForTest() {
    _pending.clear();
    _last = null;
  }
}
