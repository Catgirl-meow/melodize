import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/errors/app_errors.dart';
import '../../core/providers.dart';
import '../../core/utils/platform_info.dart';
import '../../shared/utils/snack.dart';
import '../../widgets/grouped_list_tile.dart';

/// Settings → Debug: tools for diagnosing and tuning the app on a real
/// device, where release builds can't be inspected over adb.
class DebugScreen extends ConsumerStatefulWidget {
  const DebugScreen({super.key});

  @override
  ConsumerState<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends ConsumerState<DebugScreen> {
  String? _lastExport;
  bool _exporting = false;

  /// Where the export goes. On Android: the app's external files folder,
  /// which `adb pull` can read without root
  /// (/sdcard/Android/data/<app>/files). On Linux: ~/Downloads.
  Future<Directory> _exportDir() async {
    if (isMobilePlatform) {
      final dir = await getExternalStorageDirectory();
      if (dir == null) throw StateError('No external storage on this device');
      return dir;
    }
    return await getDownloadsDirectory() ??
        await getApplicationSupportDirectory();
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final dir = await _exportDir();
      final path = p.join(dir.path, 'melodize-history.db');
      await ref.read(databaseProvider).exportForAnalysis(path);
      if (!mounted) return;
      setState(() => _lastExport = path);
      showStyledSnack(context, 'Exported to $path');
    } catch (e) {
      AppErrors.report("Couldn't export listening history", e);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Debug')),
      body: ListView(
        children: [
          GroupedSection(
            children: [
              ListTile(
                leading: const Icon(Icons.ios_share_rounded),
                title: const Text('Export listening history'),
                subtitle: Text(_lastExport ??
                    'Saves play history, library cache and likes for '
                        'recommendation tuning. No passwords.'),
                trailing: _exporting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : null,
                onTap: _exporting ? null : _export,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Text(
              isMobilePlatform
                  ? 'The file lands in Android/data/<app>/files on this '
                      'phone. Connect it to a computer and pull it with adb.'
                  : 'The file lands in your Downloads folder.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
