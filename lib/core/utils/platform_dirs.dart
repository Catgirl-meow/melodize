import 'dart:io';
import 'package:path_provider/path_provider.dart';

import 'platform_info.dart';

/// Returns the directory where Melodize stores its database, preferences, and
/// downloads.
///
/// On Android we keep using [getApplicationDocumentsDirectory] so that
/// existing users' data at its original location is preserved.
///
/// On Linux we use [getApplicationSupportDirectory]
/// (`~/.local/share/melodize`) because it is always present and doesn't rely on XDG_DOCUMENTS_DIR, which is frequently unset on
/// minimal desktop setups and causes MissingPlatformDirectoryException.
Future<Directory> getAppStorageDirectory() async {
  if (isMobilePlatform) {
    return getApplicationDocumentsDirectory();
  }
  return getApplicationSupportDirectory();
}
