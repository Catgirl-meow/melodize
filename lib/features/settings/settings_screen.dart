import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/platform_dirs.dart';
import '../../core/models/app_preferences.dart';
import '../../core/providers.dart';
import '../../widgets/grouped_list_tile.dart';
import 'downloaded_songs_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _changeServer(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Change server?'),
        content: const Text(
            'This will stop playback and permanently clear all cached songs, '
            'downloaded files, and lyrics. Play history is kept so recommendations still work.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Clear & Change'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    // Stop playback and reset playback state
    final handler = ref.read(audioHandlerNotifierProvider);
    await handler?.stop();
    await handler?.resetPlaybackModes();

    // Delete downloaded files
    try {
      final dir = await getAppStorageDirectory();
      final downloadsDir = Directory('${dir.path}/melodize_downloads');
      if (await downloadsDir.exists()) {
        await downloadsDir.delete(recursive: true);
      }
    } catch (_) {}

    // Wipe entire database
    await ref.read(databaseProvider).clearAllData();

    // Invalidate providers — _StartupRouter will show SetupScreen automatically
    // because serverConfigProvider now returns null.
    ref.invalidate(serverConfigProvider);
    ref.invalidate(downloadedSongsProvider);
    ref.invalidate(downloadNotifierProvider);
    ref.invalidate(allSongsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(preferencesNotifierProvider);
    final scheme = Theme.of(context).colorScheme;
    final activeDownloadCount = ref.watch(
      downloadNotifierProvider.select((m) => m.values
          .where((d) => d.status == 'downloading' || d.status == 'queued')
          .length),
    );
    final config = ref.watch(serverConfigProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        automaticallyImplyLeading: false,
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        children: [
              // --- Appearance ---
              _SectionHeader('Appearance'),
              GroupedSection(children: [
                SwitchListTile(
                  title: const Text('Floating navigation bar'),
                  subtitle: const Text('Pill-shaped dock at the bottom'),
                  secondary: const Icon(Icons.dock_rounded),
                  value: prefs.floatingNavBar,
                  onChanged: (v) => ref
                      .read(preferencesNotifierProvider.notifier)
                      .update(prefs.copyWith(floatingNavBar: v)),
                ),
              ]),

              // --- Playback ---
              _SectionHeader('Playback'),
              GroupedSection(children: [
                ListTile(
                  title: const Text('Streaming quality'),
                  subtitle: Text(_qualityLabel(prefs.streamQuality)),
                  leading: const Icon(Icons.high_quality_rounded),
                  onTap: () => _showQualityPicker(
                    context,
                    ref,
                    title: 'Streaming quality',
                    current: prefs.streamQuality,
                    onSelected: (q) => ref
                        .read(preferencesNotifierProvider.notifier)
                        .update(prefs.copyWith(streamQuality: q)),
                  ),
                ),
              ]),

              // --- Downloads ---
              _SectionHeader('Downloads'),
              GroupedSection(children: [
                ListTile(
                  title: const Text('Download quality'),
                  subtitle: Text(_qualityLabel(prefs.downloadQuality)),
                  leading: const Icon(Icons.download_rounded),
                  onTap: () => _showQualityPicker(
                    context,
                    ref,
                    title: 'Download quality',
                    current: prefs.downloadQuality,
                    onSelected: (q) => ref
                        .read(preferencesNotifierProvider.notifier)
                        .update(prefs.copyWith(downloadQuality: q)),
                  ),
                ),
                ListTile(
                  title: const Text('Auto-download'),
                  subtitle: Text(_autoDownloadLabel(prefs.autoDownload)),
                  leading: const Icon(Icons.sync_rounded),
                  onTap: () => _showAutoDownloadPicker(context, ref, prefs),
                ),
                ListTile(
                  title: const Text('Downloaded songs'),
                  subtitle: Text(
                    activeDownloadCount > 0
                        ? '$activeDownloadCount downloading...'
                        : 'View and manage downloaded songs',
                  ),
                  leading: const Icon(Icons.folder_rounded),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DownloadedSongsScreen(),
                    ),
                  ),
                ),
              ]),

              // --- Server ---
              _SectionHeader('Server'),
              GroupedSection(children: [
                if (config != null)
                  ListTile(
                    title: Text(
                      config.serverUrl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(config.username),
                    leading: const Icon(Icons.dns_rounded),
                  ),
                ListTile(
                  title: const Text('Change server'),
                  subtitle: const Text('Clears all cache and downloaded files'),
                  leading: const Icon(Icons.swap_horiz_rounded),
                  onTap: () => _changeServer(context, ref),
                ),
              ]),

              // --- Deezer ---
              _SectionHeader('Deezer'),
              GroupedSection(children: [
                ListTile(
                  leading: const Icon(Icons.account_circle_rounded),
                  title: const Text('Deezer Account'),
                  subtitle: Text(
                    prefs.hasDeezerArl
                        ? 'Connected — FLAC downloads enabled'
                        : 'Not connected — 30s previews only',
                  ),
                  trailing: prefs.hasDeezerArl
                      ? const Icon(Icons.check_circle_rounded, color: Colors.green)
                      : null,
                  onTap: () => _editDeezerArl(context, ref, prefs),
                ),
                ListTile(
                  leading: const Icon(Icons.help_outline_rounded),
                  title: const Text('How to connect'),
                  subtitle: const Text('Step-by-step instructions'),
                  onTap: () => _showDeezerInstructions(context),
                ),
              ]),

              // --- Companion ---
              _SectionHeader('Melodize Companion'),
              GroupedSection(children: [
                ListTile(
                  title: const Text('Companion URL'),
                  subtitle: Text(
                    prefs.companionUrl.isEmpty ? 'Not configured' : prefs.companionUrl,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  leading: const Icon(Icons.hub_rounded),
                  onTap: () => _editCompanionUrl(context, ref, prefs),
                ),
                ListTile(
                  title: const Text('API Key'),
                  subtitle: Text(
                    prefs.companionApiKey.isEmpty
                        ? 'Not set'
                        : '••••••••${prefs.companionApiKey.substring(prefs.companionApiKey.length.clamp(8, prefs.companionApiKey.length) - 8)}',
                  ),
                  leading: const Icon(Icons.key_rounded),
                  onTap: () => _editCompanionApiKey(context, ref, prefs),
                ),
                if (prefs.hasCompanion) _CompanionStatusTile(),
              ]),

              // Bottom clearance — dock + mini player + breathing room.
              SizedBox(height: MediaQuery.paddingOf(context).bottom + 16),
            ],
      ),
    );
  }

  String _qualityLabel(String quality) {
    switch (quality) {
      case 'lossless':
        return 'Lossless (FLAC/ALAC)';
      case '320':
        return '320 kbps';
      case '192':
        return '192 kbps';
      case '128':
        return '128 kbps';
      default:
        return quality;
    }
  }

  String _autoDownloadLabel(String mode) {
    switch (mode) {
      case 'never':
        return 'Never';
      case 'on_play':
        return 'When played';
      case 'all':
        return 'All songs';
      default:
        return mode;
    }
  }

  void _showQualityPicker(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String current,
    required void Function(String) onSelected,
  }) {
    final options = [
      ('lossless', 'Lossless (FLAC/ALAC)', 'Best quality, larger files'),
      ('320', '320 kbps', 'High quality'),
      ('192', '192 kbps', 'Good quality'),
      ('128', '128 kbps', 'Smaller files'),
    ];
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(title,
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            for (final (value, label, sublabel) in options)
              ListTile(
                title: Text(label),
                subtitle: Text(sublabel),
                trailing: current == value
                    ? Icon(Icons.check_rounded,
                        color: Theme.of(context).colorScheme.primary)
                    : null,
                onTap: () {
                  onSelected(value);
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _editDeezerArl(
      BuildContext context, WidgetRef ref, AppPreferences prefs) {
    final ctrl = TextEditingController(text: prefs.deezerArl);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Deezer ARL Cookie'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                hintText: 'Paste your ARL cookie here',
                border: OutlineInputBorder(),
              ),
              autocorrect: false,
              obscureText: true,
              maxLines: 1,
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => _showDeezerInstructions(context),
              icon: const Icon(Icons.help_outline_rounded, size: 16),
              label: const Text('How to get your ARL'),
            ),
          ],
        ),
        actions: [
          if (prefs.hasDeezerArl)
            TextButton(
              onPressed: () {
                ref.read(preferencesNotifierProvider.notifier)
                    .update(prefs.copyWith(deezerArl: ''));
                Navigator.pop(context);
              },
              style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error),
              child: const Text('Disconnect'),
            ),
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              ref.read(preferencesNotifierProvider.notifier)
                  .update(prefs.copyWith(deezerArl: ctrl.text.trim()));
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeezerInstructions(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('How to get your Deezer ARL'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text(
                'The ARL is a session cookie that lets Melodize download '
                'lossless FLAC tracks via your Deezer HiFi subscription.',
                style: TextStyle(fontSize: 13),
              ),
              SizedBox(height: 16),
              _Step(n: 1, text: 'Open deezer.com in a desktop browser and log in.'),
              _Step(n: 2, text: 'Press F12 to open Developer Tools.'),
              _Step(n: 3, text: 'Go to the Application tab (Chrome/Edge) or Storage tab (Firefox).'),
              _Step(n: 4, text: 'Expand Cookies → click on https://www.deezer.com'),
              _Step(n: 5, text: 'Find the cookie named "arl" and copy its Value (a long hex string).'),
              _Step(n: 6, text: 'Paste it in the ARL field in Settings → Deezer Account.'),
              SizedBox(height: 12),
              Text(
                'The ARL is valid as long as your session is active (typically months). '
                'It is stored locally on this device and sent only to your own '
                'Melodize Companion server when downloading songs.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _editCompanionUrl(
      BuildContext context, WidgetRef ref, AppPreferences prefs) {
    final serverUrl = ref.read(serverConfigProvider).valueOrNull?.serverUrl ?? '';
    // Default to the same URL as Navidrome — the nginx mux routes /health and
    // /api/songs to the companion without any path prefix.  Do NOT append
    // '/companion' — that path is not handled by the companion and health
    // checks will fail.
    final defaultUrl = prefs.companionUrl.isNotEmpty
        ? prefs.companionUrl
        : serverUrl;
    final ctrl = TextEditingController(text: defaultUrl);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Companion URL'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            hintText: 'https://your-navidrome-server.example.com',
            helperText: 'Same URL as your Navidrome server (no /companion suffix)',
            helperMaxLines: 2,
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.url,
          autocorrect: false,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              ref.read(preferencesNotifierProvider.notifier).update(
                  prefs.copyWith(companionUrl: ctrl.text.trim()));
              ref.invalidate(companionAvailableProvider);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _editCompanionApiKey(
      BuildContext context, WidgetRef ref, AppPreferences prefs) {
    final ctrl = TextEditingController(text: prefs.companionApiKey);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('API Key'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            hintText: 'Paste the key from config.json',
            border: OutlineInputBorder(),
          ),
          autocorrect: false,
          obscureText: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              ref.read(preferencesNotifierProvider.notifier).update(
                  prefs.copyWith(companionApiKey: ctrl.text.trim()));
              ref.invalidate(companionAvailableProvider);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAutoDownloadPicker(
      BuildContext context, WidgetRef ref, dynamic prefs) {
    final options = [
      ('never', 'Never', 'Songs are not downloaded automatically'),
      ('on_play', 'When played', 'Download each song when you play it'),
      ('all', 'All songs', 'Download entire library in background'),
    ];
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Auto-download',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            for (final (value, label, sublabel) in options)
              ListTile(
                title: Text(label),
                subtitle: Text(sublabel),
                trailing: prefs.autoDownload == value
                    ? Icon(Icons.check_rounded,
                        color: Theme.of(context).colorScheme.primary)
                    : null,
                onTap: () {
                  ref
                      .read(preferencesNotifierProvider.notifier)
                      .update(prefs.copyWith(autoDownload: value));
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _CompanionStatusTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final status = ref.watch(companionAvailableProvider);
    return ListTile(
      leading: status.when(
        data: (ok) => Icon(
          ok ? Icons.check_circle_rounded : Icons.error_rounded,
          color: ok ? Colors.green : scheme.error,
        ),
        loading: () => const SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator(strokeWidth: 2)),
        error: (_, __) =>
            Icon(Icons.error_rounded, color: scheme.error),
      ),
      title: status.when(
        data: (ok) => Text(ok ? 'Connected' : 'Cannot reach companion'),
        loading: () => const Text('Checking...'),
        error: (_, __) => const Text('Connection error'),
      ),
      subtitle: status.maybeWhen(
        data: (ok) => ok
            ? const Text('Server management available')
            : const Text('Check URL and API key'),
        orElse: () => null,
      ),
      trailing: IconButton(
        icon: const Icon(Icons.refresh_rounded),
        onPressed: () => ref.invalidate(companionAvailableProvider),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final int n;
  final String text;
  const _Step({required this.n, required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            margin: const EdgeInsets.only(right: 10, top: 1),
            decoration: BoxDecoration(
              color: scheme.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$n',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: scheme.onPrimary),
              ),
            ),
          ),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: scheme.primary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
