import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import 'package:path_provider/path_provider.dart';
import 'core/audio/audio_handler.dart';
import 'core/db/database.dart';
import 'core/models/song.dart';
import 'core/providers.dart';
import 'features/setup/setup_screen.dart';
import 'features/shell/main_shell.dart';
import 'shared/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Phase 1: create the handler synchronously so the app starts immediately.
  final audioHandler = createAudioHandler();

  runApp(
    ProviderScope(
      overrides: [
        audioHandlerNotifierProvider.overrideWith(
          (ref) => AudioHandlerNotifier()..setHandler(audioHandler),
        ),
      ],
      child: const MelodizeApp(),
    ),
  );

  // Phase 2: connect to audio_service after the first frame is rendered.
  // Waiting for the post-frame callback ensures the platform channels and
  // the Activity are fully ready before we try to register the MediaSession.
  // Failures are logged and ignored — playback still works without it.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    connectAudioService(audioHandler);
  });
}

class MelodizeApp extends ConsumerWidget {
  const MelodizeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DynamicColorBuilder(
      builder: (lightScheme, darkScheme) {
        return MaterialApp(
          title: 'Melodize',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(lightScheme),
          darkTheme: AppTheme.dark(darkScheme),
          themeMode: ThemeMode.dark,
          home: const _StartupRouter(),
        );
      },
    );
  }
}

class _StartupRouter extends ConsumerStatefulWidget {
  const _StartupRouter();

  @override
  ConsumerState<_StartupRouter> createState() => _StartupRouterState();
}

class _StartupRouterState extends ConsumerState<_StartupRouter> {
  StreamSubscription<Song>? _historySubscription;

  @override
  void initState() {
    super.initState();
    final handler = ref.read(audioHandlerNotifierProvider);
    _historySubscription = handler?.playHistoryStream.listen((song) async {
      if (!mounted) return;
      // Save play history to DB
      ref.read(databaseProvider).addToHistory(
            PlayHistoryCompanion.insert(
              songId: song.id,
              songTitle: song.title,
              artist: song.artist,
              coverArt: Value(song.coverArt),
            ),
          );
      // Auto-download if configured — wait 15s so the download doesn't
      // compete with the stream connection during initial buffering.
      // Prefs are read inside the delay so a setting change made after the
      // song starts but before 15 s elapses is still picked up.
      if (!song.isDownloaded) {
        Future.delayed(const Duration(seconds: 15), () async {
          if (!mounted) return;
          final prefs = ref.read(preferencesNotifierProvider);
          if (prefs.autoDownload != 'on_play') return;
          final dir = await getApplicationDocumentsDirectory();
          final path =
              '${dir.path}/melodize_downloads/${song.id}.${song.suffix ?? 'mp3'}';
          ref
              .read(downloadNotifierProvider.notifier)
              .download(song, path, quality: prefs.downloadQuality);
        });
      }
    });
  }

  @override
  void dispose() {
    _historySubscription?.cancel();
    super.dispose();
  }

  Future<void> _redownloadAll(WidgetRef ref, String quality) async {
    final songs = await ref.read(downloadedSongsProvider.future);
    if (songs.isEmpty) return;
    final dir = await getApplicationDocumentsDirectory();
    for (final song in songs) {
      final path =
          '${dir.path}/melodize_downloads/${song.id}.${song.suffix ?? 'mp3'}';
      ref
          .read(downloadNotifierProvider.notifier)
          .download(song, path, quality: quality, force: true);
    }
  }

  // Download every song in the library that isn't already on device.
  // Uses downloadBatch() so a single state update is emitted for all queued
  // songs instead of N individual updates — keeps the UI responsive.
  Future<void> _downloadAll(WidgetRef ref) async {
    final songs = ref.read(allSongsProvider).valueOrNull ?? [];
    if (songs.isEmpty) return;
    final prefs = ref.read(preferencesNotifierProvider);
    final dir = await getApplicationDocumentsDirectory();
    final baseDir = '${dir.path}/melodize_downloads';
    ref
        .read(downloadNotifierProvider.notifier)
        .downloadBatch(songs, baseDir, prefs.downloadQuality);
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(serverConfigProvider);

    // Sync server config to audio handler
    ref.listen(serverConfigProvider, (_, next) {
      next.whenData((config) {
        if (config != null) {
          ref.read(audioHandlerNotifierProvider)?.setConfig(config);
        }
      });
    });

    // Sync stream quality; re-download all on download quality change;
    // start full-library download when autoDownload is switched to 'all'.
    ref.listen(preferencesNotifierProvider, (prev, next) {
      ref.read(audioHandlerNotifierProvider)?.setStreamQuality(next.streamQuality);
      if (prev != null && prev.downloadQuality != next.downloadQuality) {
        _redownloadAll(ref, next.downloadQuality);
      }
      if (prev != null && prev.autoDownload != next.autoDownload &&
          next.autoDownload == 'all') {
        _downloadAll(ref);
      }
    });

    // If the app starts with autoDownload='all' and songs arrive, download them.
    ref.listen(allSongsProvider, (_, next) {
      final prefs = ref.read(preferencesNotifierProvider);
      if (prefs.autoDownload == 'all') {
        _downloadAll(ref);
      }
    });

    return configAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SetupScreen(),
      data: (config) =>
          config == null ? const SetupScreen() : const MainShell(),
    );
  }
}
