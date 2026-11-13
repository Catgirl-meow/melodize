import 'dart:io';

import 'package:flutter/painting.dart';

/// Remembers which saved cover files exist so list tiles don't stat the disk
/// on every rebuild. Download code calls [evictLocalCoverCache] whenever it
/// writes or deletes a cover so the next lookup (and the decoded image) is
/// fresh.
final Map<String, bool> _exists = {};

bool localCoverExists(String path) =>
    _exists.putIfAbsent(path, () => File(path).existsSync());

void evictLocalCoverCache(String path) {
  _exists.remove(path);
  FileImage(File(path)).evict();
}
