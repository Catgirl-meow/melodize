import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

/// Pure helpers for the on-device download layout. Kept free of Flutter and
/// Riverpod so the rules are unit-testable.
///
/// Layout, all inside `<app storage>/melodize_downloads/`:
///   `<songId>.<ext>`         the audio file (ext from the server's real
///                            Content-Type, so a transcoded MP3 is never
///                            saved as `.flac`)
///   `<songId>.cover.jpg`     the cover art (any image format; the name is
///                            historical and decoders sniff the bytes)
///   `*.part`                 an in-flight download; renamed into place only
///                            once complete, so a crash or cancel never leaves
///                            a truncated file that looks downloaded.

const downloadsDirName = 'melodize_downloads';

/// Cover art is requested at this edge length. Navidrome otherwise serves the
/// original embedded art, which can be a multi-megabyte 3000 px scan.
const downloadCoverSize = 1200;

String downloadsDirPath(String storageRoot) =>
    p.join(storageRoot, downloadsDirName);

/// Base path (no extension) for a song's files inside [downloadsDir].
String downloadBasePath(String downloadsDir, String songId) =>
    p.join(downloadsDir, _safeFileName(songId));

/// Cover-art sibling of an audio file: same directory and base name.
/// `/d/abc.flac` → `/d/abc.cover.jpg`.
String coverPathForAudio(String audioPath) =>
    '${p.withoutExtension(audioPath)}.cover.jpg';

/// Temporary path a download is written to before the atomic rename.
String partPathFor(String finalPath) => '$finalPath.part';

String _safeFileName(String id) =>
    id.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

/// Picks the file extension for downloaded audio from the response
/// Content-Type. [fallbackSuffix] (the server's original suffix) is used only
/// when the type is missing or unrecognised.
String audioExtensionFor({String? contentType, String? fallbackSuffix}) {
  final type = contentType?.split(';').first.trim().toLowerCase();
  const byType = {
    'audio/mpeg': 'mp3',
    'audio/mp3': 'mp3',
    'audio/flac': 'flac',
    'audio/x-flac': 'flac',
    'audio/ogg': 'ogg',
    'application/ogg': 'ogg',
    'audio/opus': 'opus',
    'audio/mp4': 'm4a',
    'audio/x-m4a': 'm4a',
    'audio/m4a': 'm4a',
    'audio/aac': 'aac',
    'audio/wav': 'wav',
    'audio/x-wav': 'wav',
    'audio/wave': 'wav',
    'audio/aiff': 'aiff',
    'audio/x-aiff': 'aiff',
    'audio/x-ms-wma': 'wma',
    'audio/x-ape': 'ape',
    'audio/x-dsf': 'dsf',
    'audio/webm': 'webm',
  };
  final fromType = type == null ? null : byType[type];
  if (fromType != null) return fromType;
  final suffix = fallbackSuffix?.trim().toLowerCase();
  if (suffix != null && suffix.isNotEmpty) return suffix;
  return 'mp3';
}

/// True when a Subsonic binary endpoint answered with an API error body
/// (Subsonic reports errors as HTTP 200 + XML/JSON, never as a status code).
bool isSubsonicErrorContentType(String? contentType) {
  final type = contentType?.split(';').first.trim().toLowerCase() ?? '';
  return type.contains('xml') ||
      type.contains('json') ||
      type.startsWith('text/');
}

/// Extracts the human message from a Subsonic error body (JSON or XML).
String subsonicErrorMessage(String body) {
  try {
    final json = jsonDecode(body);
    final resp = json is Map ? json['subsonic-response'] : null;
    final err = resp is Map ? resp['error'] : null;
    final msg = err is Map ? err['message'] : null;
    if (msg is String && msg.isNotEmpty) return msg;
  } catch (_) {
    // Not JSON; try XML below.
  }
  final xml = RegExp(r'message="([^"]*)"').firstMatch(body);
  if (xml != null && xml.group(1)!.isNotEmpty) return xml.group(1)!;
  final trimmed = body.trim();
  if (trimmed.isEmpty) return 'empty response';
  return trimmed.length > 120 ? '${trimmed.substring(0, 120)}…' : trimmed;
}

/// Thrown when the server answers a download with something that is not the
/// file we asked for (an API error body, an empty file, a non-image cover).
class DownloadContentException implements Exception {
  final String message;
  const DownloadContentException(this.message);
  @override
  String toString() => message;
}

/// One-line, user-facing reason for a failed download. Specific where the
/// cause is known; otherwise the raw error so the user still sees *what*
/// broke instead of a generic "try again".
String friendlyDownloadError(Object error) {
  if (error is DownloadContentException) return error.message;
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return 'Timed out — check your connection';
      case DioExceptionType.connectionError:
        return 'Cannot reach the server';
      case DioExceptionType.badCertificate:
        return 'Server certificate rejected';
      case DioExceptionType.badResponse:
        final code = error.response?.statusCode;
        return switch (code) {
          401 => 'Server rejected the login — check Settings',
          403 => 'Server refused access (403)',
          404 => 'Not found on the server — it may have been removed',
          _ => 'Server error ($code)',
        };
      case DioExceptionType.cancel:
        return 'Cancelled';
      case DioExceptionType.unknown:
        final inner = error.error;
        if (inner != null) return friendlyDownloadError(inner);
    }
  }
  if (error is FileSystemException) {
    final os = error.osError;
    // ENOSPC on Linux/Android, 112 on Windows.
    if (os != null && (os.errorCode == 28 || os.errorCode == 112)) {
      return 'Not enough storage space on this device';
    }
    return 'Could not write the file: ${os?.message ?? error.message}';
  }
  if (error is SocketException) return 'Cannot reach the server';
  return error.toString();
}
