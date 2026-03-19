import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Returns the directory where Melodize stores its database, preferences, and
/// downloads.
///
/// On Android/iOS we keep using [getApplicationDocumentsDirectory] so that
/// existing users' data at its original location is preserved.
///
/// On desktop (Linux, Windows, macOS) we use [getApplicationSupportDirectory]
/// (`~/.local/share/melodize` on Linux) because it is always present and
/// doesn't rely on XDG_DOCUMENTS_DIR, which is frequently unset on minimal
/// desktop setups and causes MissingPlatformDirectoryException.
Future<Directory> getAppStorageDirectory() async {
  if (Platform.isAndroid || Platform.isIOS) {
    return getApplicationDocumentsDirectory();
  }
  return getApplicationSupportDirectory();
}
