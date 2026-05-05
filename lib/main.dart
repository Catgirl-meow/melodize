import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'core/utils/platform_dirs.dart';
import 'core/audio/audio_handler.dart';
import 'core/db/database.dart';
import 'core/models/song.dart';
import 'core/providers.dart';
import 'features/setup/setup_screen.dart';
import 'features/shell/main_shell.dart';
import 'shared/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  if (defaultTargetPlatform == TargetPlatform.linux) {
    // prefetchPlaylist: mpv starts buffering the next track before the current
    // one ends, giving seamless gapless transitions between songs.
    JustAudioMediaKit.prefetchPlaylist = true;
    JustAudioMediaKit.ensureInitialized();
  }

  // Edge-to-edge: content renders behind status bar and nav bar so the camera
  // cutout area is filled with app content rather than a solid system-bar color.
  // SafeArea widgets throughout the app handle the inset padding automatically.
  if (!Platform.isLinux) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

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

  // Phase 2: connect audio_service (Android MediaSession + lock-screen) and
  // register MPRIS on Linux so that playerctl / niri XF86 keybindings work.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    connectAudioService(audioHandler);
    audioHandler.setupMpris();
  });
}

// Light spring physics for all scroll views — gives a satisfying elastic
// overscroll on desktop (no bounce on mobile; ClampingScrollPhysics is kept
// there via the platform override).
class _AppScrollBehavior extends ScrollBehavior {
  const _AppScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
}

class MelodizeApp extends ConsumerWidget {
  const MelodizeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    // Derive effective brightness for status-bar icon color
    final brightness = themeMode == ThemeMode.system
        ? PlatformDispatcher.instance.platformBrightness
        : themeMode == ThemeMode.light
            ? Brightness.light
            : Brightness.dark;

    if (!Platform.isLinux) {
      SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            brightness == Brightness.dark ? Brightness.light : Brightness.dark,
        statusBarBrightness:
            brightness == Brightness.dark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
      ));
    }

    return DynamicColorBuilder(
      builder: (lightScheme, darkScheme) {
        return MaterialApp(
          title: 'Melodize',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(lightScheme),
          darkTheme: AppTheme.dark(darkScheme),
          themeMode: themeMode,
          scrollBehavior: const _AppScrollBehavior(),
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
  // Signature of last allSongs list passed to _downloadAll. Guards against
  // refiring on every cache/fresh emission with the same content.
  int? _lastAutoDownloadSig;

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
          final dir = await getAppStorageDirectory();
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
    final dir = await getAppStorageDirectory();
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
    final dir = await getAppStorageDirectory();
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
    // Guard against re-firing on every cache/fresh emission with same songs.
    ref.listen(allSongsProvider, (_, next) {
      final prefs = ref.read(preferencesNotifierProvider);
      if (prefs.autoDownload != 'all') return;
      next.whenData((songs) {
        final sig = Object.hashAll(songs.map((s) => s.id));
        if (sig == _lastAutoDownloadSig) return;
        _lastAutoDownloadSig = sig;
        _downloadAll(ref);
      });
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
