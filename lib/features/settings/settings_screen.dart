import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/app_preferences.dart';
import '../../core/providers.dart';
import '../../core/utils/platform_dirs.dart';
import '../../widgets/grouped_list_tile.dart';
import 'downloaded_songs_screen.dart';

const _streamQualityOptions = [
  _ChoiceOption(
    value: 'lossless',
    title: 'Lossless (FLAC/ALAC)',
    subtitle: 'Best quality, larger files',
  ),
  _ChoiceOption(
    value: '320',
    title: '320 kbps',
    subtitle: 'High quality',
  ),
  _ChoiceOption(
    value: '192',
    title: '192 kbps',
    subtitle: 'Good quality',
  ),
  _ChoiceOption(
    value: '128',
    title: '128 kbps',
    subtitle: 'Smaller files',
  ),
];

const _autoDownloadOptions = [
  _ChoiceOption(
    value: 'never',
    title: 'Never',
    subtitle: 'Songs are not downloaded automatically',
  ),
  _ChoiceOption(
    value: 'on_play',
    title: 'When played',
    subtitle: 'Download each song after playback starts',
  ),
  _ChoiceOption(
    value: 'all',
    title: 'All songs',
    subtitle: 'Download the entire library in the background',
  ),
];

const _themeOptions = [
  _ChoiceOption(
    value: 'dark',
    title: 'Dark',
    subtitle: 'Always use dark theme',
  ),
  _ChoiceOption(
    value: 'light',
    title: 'Light',
    subtitle: 'Always use light theme',
  ),
  _ChoiceOption(
    value: 'system',
    title: 'System default',
    subtitle: 'Follow device theme',
  ),
];

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(preferencesNotifierProvider);
    final activeDownloadCount = ref.watch(
      downloadNotifierProvider.select(
        (m) => m.values
            .where((d) => d.status == 'downloading' || d.status == 'queued')
            .length,
      ),
    );
    final config = ref.watch(serverConfigProvider).valueOrNull;

    return _SettingsPageScaffold(
      title: 'Settings',
      automaticallyImplyLeading: false,
      children: [
        const _SectionHeader('Appearance'),
        GroupedSection(
          children: [
            ListTile(
              leading: const Icon(Icons.brightness_6_rounded),
              title: const Text('Theme'),
              subtitle: Text(_themeLabel(prefs.themeMode)),
              trailing: const _TileTrailing(),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _ChoiceSettingScreen<String>(
                      title: 'Theme',
                      currentValue: prefs.themeMode,
                      options: _themeOptions,
                      onSelected: (value) {
                        ref.read(preferencesNotifierProvider.notifier).update(
                              prefs.copyWith(themeMode: value),
                            );
                      },
                    ),
                  ),
                );
              },
            ),
            SwitchListTile.adaptive(
              title: const Text('Floating navigation bar'),
              subtitle: const Text('Use the floating pill dock'),
              secondary: const Icon(Icons.dock_rounded),
              value: prefs.floatingNavBar,
              onChanged: (value) {
                ref.read(preferencesNotifierProvider.notifier).update(
                      prefs.copyWith(floatingNavBar: value),
                    );
              },
            ),
          ],
        ),
        const _SectionHeader('Playback'),
        GroupedSection(
          children: [
            ListTile(
              leading: const Icon(Icons.high_quality_rounded),
              title: const Text('Streaming quality'),
              subtitle: Text(_qualityLabel(prefs.streamQuality)),
              trailing: const _TileTrailing(),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _ChoiceSettingScreen<String>(
                      title: 'Streaming quality',
                      currentValue: prefs.streamQuality,
                      options: _streamQualityOptions,
                      onSelected: (value) {
                        ref.read(preferencesNotifierProvider.notifier).update(
                              prefs.copyWith(streamQuality: value),
                            );
                      },
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        const _SectionHeader('Downloads'),
        GroupedSection(
          children: [
            ListTile(
              leading: const Icon(Icons.download_rounded),
              title: const Text('Download quality'),
              subtitle: Text(_qualityLabel(prefs.downloadQuality)),
              trailing: const _TileTrailing(),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _ChoiceSettingScreen<String>(
                      title: 'Download quality',
                      currentValue: prefs.downloadQuality,
                      options: _streamQualityOptions,
                      onSelected: (value) {
                        ref.read(preferencesNotifierProvider.notifier).update(
                              prefs.copyWith(downloadQuality: value),
                            );
                      },
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.sync_rounded),
              title: const Text('Auto-download'),
              subtitle: Text(_autoDownloadLabel(prefs.autoDownload)),
              trailing: const _TileTrailing(),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _ChoiceSettingScreen<String>(
                      title: 'Auto-download',
                      currentValue: prefs.autoDownload,
                      options: _autoDownloadOptions,
                      onSelected: (value) {
                        ref.read(preferencesNotifierProvider.notifier).update(
                              prefs.copyWith(autoDownload: value),
                            );
                      },
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_rounded),
              title: const Text('Downloaded songs'),
              subtitle: Text(
                activeDownloadCount > 0
                    ? '$activeDownloadCount downloading now'
                    : 'Browse songs saved on this device',
              ),
              trailing: const _TileTrailing(),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DownloadedSongsScreen(),
                  ),
                );
              },
            ),
          ],
        ),
        const _SectionHeader('Connections'),
        GroupedSection(
          children: [
            ListTile(
              leading: const Icon(Icons.dns_rounded),
              title: const Text('Library server'),
              subtitle: Text(
                config == null
                    ? 'Not connected'
                    : '${config.username} • ${_displayServerUrl(config.serverUrl)}',
              ),
              trailing: const _TileTrailing(),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const _ServerSettingsScreen(),
                  ),
                );
              },
            ),
            const _DeezerOverviewTile(),
            const _CompanionOverviewTile(),
          ],
        ),
      ],
    );
  }
}

class _ServerSettingsScreen extends ConsumerWidget {
  const _ServerSettingsScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(serverConfigProvider).valueOrNull;
    final scheme = Theme.of(context).colorScheme;

    return _SettingsPageScaffold(
      title: 'Library server',
      children: [
        if (config != null) ...[
          const _SectionHeader('Current connection'),
          GroupedSection(
            children: [
              ListTile(
                leading: const Icon(Icons.link_rounded),
                title: const Text('Server URL'),
                subtitle: Text(config.serverUrl),
              ),
              ListTile(
                leading: const Icon(Icons.person_rounded),
                title: const Text('Username'),
                subtitle: Text(config.username),
              ),
            ],
          ),
        ],
        const _SectionHeader('Actions'),
        GroupedSection(
          children: [
            ListTile(
              leading: Icon(Icons.swap_horiz_rounded, color: scheme.error),
              title: Text(
                'Connect a different server',
                style: TextStyle(color: scheme.error),
              ),
              subtitle: const Text('Clears cache and downloads on this device'),
              onTap: () => _changeServer(context, ref),
            ),
          ],
        ),
      ],
    );
  }
}

class _DeezerSettingsScreen extends ConsumerWidget {
  const _DeezerSettingsScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(preferencesNotifierProvider);
    final statusAsync =
        prefs.hasDeezerArl ? ref.watch(deezerArlStatusProvider) : null;

    return _SettingsPageScaffold(
      title: 'Deezer',
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Text(
            'Connect a Deezer session if you want the companion to fetch full FLAC releases. Without it, Melodize stays in preview-only mode.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const _SectionHeader('Account'),
        GroupedSection(
          children: [
            ListTile(
              leading: const Icon(Icons.account_circle_rounded),
              title: const Text('ARL cookie'),
              subtitle: Text(
                _deezerSubtitle(
                  prefs.hasDeezerArl,
                  statusAsync?.valueOrNull,
                  statusAsync?.isLoading ?? false,
                  statusAsync?.hasError ?? false,
                ),
              ),
              trailing: _TileTrailing(
                status: _deezerStatusIcon(
                  context,
                  prefs.hasDeezerArl,
                  statusAsync?.valueOrNull,
                  statusAsync?.isLoading ?? false,
                  statusAsync?.hasError ?? false,
                ),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _TextSettingScreen(
                      title: 'ARL cookie',
                      initialValue: prefs.deezerArl,
                      hintText: 'Paste your Deezer ARL cookie',
                      helperText: 'Used only for companion downloads',
                      obscureText: true,
                      description:
                          'The ARL is a Deezer session cookie. Melodize stores it locally on this device and sends it only to your own companion server when starting a Deezer download.',
                      clearActionLabel:
                          prefs.hasDeezerArl ? 'Disconnect' : null,
                      onClear: prefs.hasDeezerArl
                          ? () {
                              ref
                                  .read(preferencesNotifierProvider.notifier)
                                  .update(prefs.copyWith(deezerArl: ''));
                            }
                          : null,
                      onSaved: (value) {
                        ref.read(preferencesNotifierProvider.notifier).update(
                              prefs.copyWith(deezerArl: value.trim()),
                            );
                      },
                      footer: Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const _DeezerHelpScreen(),
                              ),
                            );
                          },
                          icon:
                              const Icon(Icons.help_outline_rounded, size: 18),
                          label: const Text('How to find the ARL'),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.help_outline_rounded),
              title: const Text('ARL help'),
              subtitle: const Text('Step-by-step browser instructions'),
              trailing: const _TileTrailing(),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const _DeezerHelpScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _CompanionSettingsScreen extends ConsumerWidget {
  const _CompanionSettingsScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(preferencesNotifierProvider);
    final serverUrl =
        ref.watch(serverConfigProvider).valueOrNull?.serverUrl ?? '';
    final statusAsync =
        prefs.hasCompanion ? ref.watch(companionAvailableProvider) : null;

    return _SettingsPageScaffold(
      title: 'Melodize Companion',
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Text(
            'The companion unlocks server-side downloads and delete-from-server actions. Point it at the same host as Navidrome unless you run it elsewhere.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const _SectionHeader('Connection'),
        GroupedSection(
          children: [
            ListTile(
              leading: const Icon(Icons.hub_rounded),
              title: const Text('Companion URL'),
              subtitle: Text(
                prefs.companionUrl.isEmpty
                    ? 'Not configured'
                    : prefs.companionUrl,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const _TileTrailing(),
              onTap: () {
                final initialValue = prefs.companionUrl.isNotEmpty
                    ? prefs.companionUrl
                    : serverUrl;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _TextSettingScreen(
                      title: 'Companion URL',
                      initialValue: initialValue,
                      hintText: 'https://your-navidrome-server.example.com',
                      helperText:
                          'Same URL as Navidrome, with no /companion suffix',
                      keyboardType: TextInputType.url,
                      description:
                          'If you use an nginx/Caddy mux, the companion usually shares the same base URL as your Navidrome server.',
                      onSaved: (value) {
                        ref.read(preferencesNotifierProvider.notifier).update(
                              prefs.copyWith(companionUrl: value.trim()),
                            );
                        ref.invalidate(companionAvailableProvider);
                      },
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.key_rounded),
              title: const Text('API key'),
              subtitle: Text(_maskApiKey(prefs.companionApiKey)),
              trailing: const _TileTrailing(),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _TextSettingScreen(
                      title: 'API key',
                      initialValue: prefs.companionApiKey,
                      hintText: 'Paste the key from config.json',
                      obscureText: true,
                      description:
                          'This key is sent with companion requests so your server can verify that Melodize is allowed to start downloads or delete files.',
                      onSaved: (value) {
                        ref.read(preferencesNotifierProvider.notifier).update(
                              prefs.copyWith(companionApiKey: value.trim()),
                            );
                        ref.invalidate(companionAvailableProvider);
                      },
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        const _SectionHeader('Status'),
        GroupedSection(
          children: [
            ListTile(
              leading: _companionStatusIcon(context, prefs, statusAsync),
              title: Text(_companionStatusTitle(prefs, statusAsync)),
              subtitle: Text(_companionStatusSubtitle(prefs, statusAsync)),
              trailing: prefs.hasCompanion
                  ? IconButton(
                      icon: const Icon(Icons.refresh_rounded),
                      onPressed: () =>
                          ref.invalidate(companionAvailableProvider),
                    )
                  : null,
            ),
          ],
        ),
      ],
    );
  }
}

class _ChoiceSettingScreen<T> extends StatelessWidget {
  final String title;
  final T currentValue;
  final List<_ChoiceOption<T>> options;
  final ValueChanged<T> onSelected;

  const _ChoiceSettingScreen({
    required this.title,
    required this.currentValue,
    required this.options,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return _SettingsPageScaffold(
      title: title,
      children: [
        RadioGroup<T>(
          groupValue: currentValue,
          onChanged: (value) {
            if (value == null) return;
            onSelected(value);
            Navigator.pop(context);
          },
          child: GroupedSection(
            children: [
              for (final option in options)
                RadioListTile<T>(
                  value: option.value,
                  title: Text(option.title),
                  subtitle: Text(option.subtitle),
                  selected: option.value == currentValue,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TextSettingScreen extends StatefulWidget {
  final String title;
  final String initialValue;
  final String hintText;
  final String? helperText;
  final String? description;
  final bool obscureText;
  final TextInputType? keyboardType;
  final ValueChanged<String> onSaved;
  final String? clearActionLabel;
  final VoidCallback? onClear;
  final Widget? footer;

  const _TextSettingScreen({
    required this.title,
    required this.initialValue,
    required this.hintText,
    required this.onSaved,
    this.helperText,
    this.description,
    this.obscureText = false,
    this.keyboardType,
    this.clearActionLabel,
    this.onClear,
    this.footer,
  });

  @override
  State<_TextSettingScreen> createState() => _TextSettingScreenState();
}

class _TextSettingScreenState extends State<_TextSettingScreen> {
  late final TextEditingController _controller;
  late bool _obscure;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _controller.addListener(() => setState(() {}));
    _obscure = widget.obscureText;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canSave => _controller.text.trim() != widget.initialValue.trim();

  void _save() {
    widget.onSaved(_controller.text);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return _SettingsPageScaffold(
      title: widget.title,
      actions: [
        TextButton(
          onPressed: _canSave ? _save : null,
          child: const Text('Save'),
        ),
      ],
      children: [
        if (widget.description != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              widget.description!,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: widget.hintText,
              helperText: widget.helperText,
              helperMaxLines: 2,
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: scheme.surfaceContainerLow,
              suffixIcon: widget.obscureText
                  ? IconButton(
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscure = !_obscure;
                        });
                      },
                    )
                  : null,
            ),
            keyboardType: widget.keyboardType,
            autocorrect: false,
            enableSuggestions: !widget.obscureText,
            obscureText: _obscure,
            maxLines: 1,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              if (_canSave) _save();
            },
          ),
        ),
        if (widget.footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: widget.footer!,
          ),
        if (widget.clearActionLabel != null && widget.onClear != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () {
                  widget.onClear!();
                  Navigator.pop(context);
                },
                style: TextButton.styleFrom(
                  foregroundColor: scheme.error,
                ),
                child: Text(widget.clearActionLabel!),
              ),
            ),
          ),
      ],
    );
  }
}

class _DeezerHelpScreen extends StatelessWidget {
  const _DeezerHelpScreen();

  @override
  Widget build(BuildContext context) {
    return const _SettingsPageScaffold(
      title: 'ARL help',
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Text(
            'The ARL is a Deezer session cookie that lets the companion download lossless releases using your existing Deezer subscription.',
          ),
        ),
        _SectionHeader('Steps'),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              _Step(
                n: 1,
                text: 'Open deezer.com in a desktop browser and sign in.',
              ),
              _Step(
                n: 2,
                text: 'Open Developer Tools with F12.',
              ),
              _Step(
                n: 3,
                text: 'Go to Application in Chrome/Edge or Storage in Firefox.',
              ),
              _Step(
                n: 4,
                text: 'Open Cookies and select https://www.deezer.com.',
              ),
              _Step(
                n: 5,
                text: 'Find the cookie named arl and copy its value.',
              ),
              _Step(
                n: 6,
                text: 'Paste that value into the ARL cookie field in Melodize.',
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(
            'The cookie usually stays valid for a long time, but if Deezer logs you out you may need to paste a fresh one.',
          ),
        ),
      ],
    );
  }
}

class _DeezerOverviewTile extends ConsumerWidget {
  const _DeezerOverviewTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(preferencesNotifierProvider);
    final statusAsync =
        prefs.hasDeezerArl ? ref.watch(deezerArlStatusProvider) : null;

    return ListTile(
      leading: const Icon(Icons.graphic_eq_rounded),
      title: const Text('Deezer'),
      subtitle: Text(
        _deezerSubtitle(
          prefs.hasDeezerArl,
          statusAsync?.valueOrNull,
          statusAsync?.isLoading ?? false,
          statusAsync?.hasError ?? false,
        ),
      ),
      trailing: _TileTrailing(
        status: _deezerStatusIcon(
          context,
          prefs.hasDeezerArl,
          statusAsync?.valueOrNull,
          statusAsync?.isLoading ?? false,
          statusAsync?.hasError ?? false,
        ),
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const _DeezerSettingsScreen(),
          ),
        );
      },
    );
  }
}

class _CompanionOverviewTile extends ConsumerWidget {
  const _CompanionOverviewTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(preferencesNotifierProvider);
    final statusAsync =
        prefs.hasCompanion ? ref.watch(companionAvailableProvider) : null;

    return ListTile(
      leading: const Icon(Icons.hub_rounded),
      title: const Text('Melodize Companion'),
      subtitle: Text(_companionStatusSubtitle(prefs, statusAsync)),
      trailing: _TileTrailing(
        status: _companionStatusIcon(context, prefs, statusAsync),
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const _CompanionSettingsScreen(),
          ),
        );
      },
    );
  }
}

class _SettingsPageScaffold extends StatelessWidget {
  final String title;
  final bool automaticallyImplyLeading;
  final List<Widget> children;
  final List<Widget>? actions;

  const _SettingsPageScaffold({
    required this.title,
    required this.children,
    this.actions,
    this.automaticallyImplyLeading = true,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        automaticallyImplyLeading: automaticallyImplyLeading,
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        actions: actions,
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            children: [
              ...children,
              SizedBox(height: MediaQuery.paddingOf(context).bottom + 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _TileTrailing extends StatelessWidget {
  final Widget? status;

  const _TileTrailing({this.status});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (status != null) ...[
          status!,
          const SizedBox(width: 4),
        ],
        const Icon(Icons.chevron_right_rounded),
      ],
    );
  }
}

class _ChoiceOption<T> {
  final T value;
  final String title;
  final String subtitle;

  const _ChoiceOption({
    required this.value,
    required this.title,
    required this.subtitle,
  });
}

class _Step extends StatelessWidget {
  final int n;
  final String text;

  const _Step({
    required this.n,
    required this.text,
  });

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
                  color: scheme.onPrimary,
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 13)),
          ),
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
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

Future<void> _changeServer(BuildContext context, WidgetRef ref) async {
  final scheme = Theme.of(context).colorScheme;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog.adaptive(
      title: const Text('Connect a different server?'),
      content: const Text(
        'This stops playback and permanently clears cached songs, downloaded files, and lyrics on this device. Play history is kept so recommendations still work.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: TextButton.styleFrom(foregroundColor: scheme.error),
          child: const Text('Continue'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;

  final handler = ref.read(audioHandlerNotifierProvider);
  await handler?.stop();
  await handler?.resetPlaybackModes();

  try {
    final dir = await getAppStorageDirectory();
    final downloadsDir = Directory('${dir.path}/melodize_downloads');
    if (await downloadsDir.exists()) {
      await downloadsDir.delete(recursive: true);
    }
  } catch (_) {}

  await ref.read(databaseProvider).clearAllData();

  ref.invalidate(serverConfigProvider);
  ref.invalidate(downloadedSongsProvider);
  ref.invalidate(downloadNotifierProvider);
  ref.invalidate(allSongsProvider);
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

String _themeLabel(String theme) {
  switch (theme) {
    case 'dark':
      return 'Dark';
    case 'light':
      return 'Light';
    case 'system':
      return 'System default';
    default:
      return theme;
  }
}

String _maskApiKey(String apiKey) {
  if (apiKey.isEmpty) return 'Not set';
  if (apiKey.length <= 8) return '••••••••';
  return '••••••••${apiKey.substring(apiKey.length - 8)}';
}

String _displayServerUrl(String url) {
  final trimmed = url.replaceAll(RegExp(r'/+$'), '');
  final uri = Uri.tryParse(trimmed);
  if (uri == null || uri.host.isEmpty) {
    return trimmed.replaceFirst(RegExp(r'^https?://'), '');
  }
  final host = uri.hasPort ? '${uri.host}:${uri.port}' : uri.host;
  final path = (uri.path.isEmpty || uri.path == '/') ? '' : uri.path;
  return '$host$path';
}

String _deezerSubtitle(
  bool hasArl,
  DeezerArlStatus? status,
  bool isLoading,
  bool hasError,
) {
  if (!hasArl) return 'Not connected • 30s previews only';
  if (isLoading) return 'Checking session…';
  if (hasError) return 'Could not verify right now';
  switch (status) {
    case DeezerArlStatus.valid:
      return 'Connected • FLAC downloads enabled';
    case DeezerArlStatus.invalid:
      return 'Session expired • update required';
    case DeezerArlStatus.notSet:
    case null:
      return 'Not connected • 30s previews only';
  }
}

Widget? _deezerStatusIcon(
  BuildContext context,
  bool hasArl,
  DeezerArlStatus? status,
  bool isLoading,
  bool hasError,
) {
  final scheme = Theme.of(context).colorScheme;
  if (!hasArl) return null;
  if (isLoading) {
    return const SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
  if (hasError) {
    return Icon(Icons.help_outline_rounded, color: scheme.onSurfaceVariant);
  }
  switch (status) {
    case DeezerArlStatus.valid:
      return const Icon(Icons.check_circle_rounded, color: Colors.green);
    case DeezerArlStatus.invalid:
      return Icon(Icons.error_rounded, color: scheme.error);
    case DeezerArlStatus.notSet:
    case null:
      return null;
  }
}

String _companionStatusTitle(
  AppPreferences prefs,
  AsyncValue<bool>? statusAsync,
) {
  if (!prefs.hasCompanion) return 'Not configured';
  return statusAsync?.when(
        data: (ok) => ok ? 'Connected' : 'Cannot reach companion',
        loading: () => 'Checking connection…',
        error: (_, __) => 'Connection error',
      ) ??
      'Checking connection…';
}

String _companionStatusSubtitle(
  AppPreferences prefs,
  AsyncValue<bool>? statusAsync,
) {
  if (!prefs.hasCompanion) {
    return 'Add the URL and API key to enable server downloads';
  }
  return statusAsync?.maybeWhen(
        data: (ok) => ok
            ? 'Server downloads and delete-from-server are available'
            : 'Check the URL and API key',
        orElse: () => 'Waiting for companion status',
      ) ??
      'Waiting for companion status';
}

Widget? _companionStatusIcon(
  BuildContext context,
  AppPreferences prefs,
  AsyncValue<bool>? statusAsync,
) {
  final scheme = Theme.of(context).colorScheme;
  if (!prefs.hasCompanion) return null;
  return statusAsync?.when(
        data: (ok) => Icon(
          ok ? Icons.check_circle_rounded : Icons.error_rounded,
          color: ok ? Colors.green : scheme.error,
        ),
        loading: () => const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        error: (_, __) => Icon(Icons.error_rounded, color: scheme.error),
      ) ??
      const SizedBox.shrink();
}
