import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'core/utils/platform_info.dart';
import 'core/audio/shuffle_mode.dart';
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
  // Android-only system chrome — desktop windows have no system bars.
  if (isMobilePlatform) {
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

  // Phase 2: connect audio_service — Android MediaSession/lock-screen, macOS
  // Now Playing + remote commands — and register MPRIS on Linux so that
  // playerctl / niri XF86 keybindings work.
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
  ScrollPhysics getScrollPhysics(BuildContext context) {
    // Android's clamping physics avoids the extra overscroll animation and
    // matches native list behavior; desktop (Linux/macOS) gets the expressive
    // bounce that matches the rest of the desktop platform.
    if (isDesktopPlatform) {
      return const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      );
    }
    return const ClampingScrollPhysics(
      parent: AlwaysScrollableScrollPhysics(),
    );
  }
}

class MelodizeApp extends ConsumerStatefulWidget {
  const MelodizeApp({super.key});

  @override
  ConsumerState<MelodizeApp> createState() => _MelodizeAppState();
}

class _MelodizeAppState extends ConsumerState<MelodizeApp>
    with WidgetsBindingObserver {
  bool _handlerDisposed = false;
  ThemeData? _cachedLight;
  ThemeData? _cachedDark;
  ColorScheme? _lastLight;
  ColorScheme? _lastDark;

  // Read once here: ref can no longer be used in dispose().
  MelodizeAudioHandler? _handler;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _handler = ref.read(audioHandlerNotifierProvider);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Android audio_service owns the handler beyond the Activity lifecycle;
    // never dispose it when the UI is detached or backgrounded. Linux has no
    // equivalent background audio service, so release its player/MPRIS
    // resources when the desktop app is actually detached. macOS gets a
    // background Now Playing service through audio_service (MPRemoteCommandCenter)
    // and terminates on last-window-close, so it needs no disposal here.
    if (Platform.isLinux &&
        state == AppLifecycleState.detached &&
        !_handlerDisposed) {
      final handler = ref.read(audioHandlerNotifierProvider);
      if (handler != null) {
        _handlerDisposed = true;
        unawaited(handler.dispose());
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (Platform.isLinux && !_handlerDisposed) {
      final handler = _handler;
      if (handler != null) {
        _handlerDisposed = true;
        unawaited(handler.dispose());
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    return DynamicColorBuilder(
      builder: (lightScheme, darkScheme) {
        if (lightScheme != _lastLight || _cachedLight == null) {
          _cachedLight = AppTheme.light(lightScheme);
          _lastLight = lightScheme;
        }
        if (darkScheme != _lastDark || _cachedDark == null) {
          _cachedDark = AppTheme.dark(darkScheme);
          _lastDark = darkScheme;
        }
        return MaterialApp(
          title: 'Melodize',
          debugShowCheckedModeBanner: false,
          theme: _cachedLight!,
          darkTheme: _cachedDark!,
          themeMode: themeMode,
          scrollBehavior: const _AppScrollBehavior(),
          // System bar icons follow the *resolved* theme, so they also flip
          // when "System default" follows a device theme change. AppBars
          // and the Now Playing screen set their own region on top of this.
          builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
            value: AppTheme.systemOverlayFor(Theme.of(context).brightness),
            child: child!,
          ),
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
    // Provider listeners normally report changes only; seed the handler with
    // the already-available client as well so a configured companion works on
    // the first queue loaded after startup.
    handler?.setCompanionAudioApi(ref.read(companionAudioApiProvider));
    handler?.setDownloadedFiles(ref.read(downloadedPathsProvider));

    // Restore persisted shuffle mode and crossfade on startup.
    Future.microtask(() {
      if (!mounted) return;
      final prefs = ref.read(preferencesNotifierProvider);
      final h = ref.read(audioHandlerNotifierProvider);
      if (h == null) return;
      if (prefs.shuffleMode == 'shuffle') {
        h.restoreShuffleMode(ShuffleMode.shuffle);
      } else if (prefs.shuffleMode == 'smartShuffle') {
        h.restoreShuffleMode(ShuffleMode.smartShuffle);
      }
    });

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
        Future.delayed(const Duration(seconds: 15), () {
          if (!mounted) return;
          final prefs = ref.read(preferencesNotifierProvider);
          if (prefs.autoDownload != 'on_play') return;
          ref.read(downloadNotifierProvider.notifier).download(song);
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
    await ref
        .read(downloadNotifierProvider.notifier)
        .redownload(songs, quality: quality);
  }

  // Download every song in the library that isn't already on device.
  // Uses downloadBatch() so a single state update is emitted for all queued
  // songs instead of N individual updates — keeps the UI responsive.
  void _downloadAll(WidgetRef ref) {
    final songs = ref.read(allSongsProvider).valueOrNull ?? [];
    if (songs.isEmpty) return;
    ref.read(downloadNotifierProvider.notifier).downloadBatch(songs);
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(serverConfigProvider);

    // Sync companion analysis and rendered-transition client independently.
    // Either may be unavailable; playback must remain fully functional without
    // the companion.
    ref.listen(companionAnalysisProvider, (_, next) {
      final h = ref.read(audioHandlerNotifierProvider);
      h?.setCompanionAnalysis(next.valueOrNull);
    });
    ref.listen(companionAudioApiProvider, (_, next) {
      ref.read(audioHandlerNotifierProvider)?.setCompanionAudioApi(next);
    });
    // Finished downloads → handler, so any queue plays them from disk.
    ref.listen<Map<String, String>>(downloadedPathsProvider, (_, next) {
      ref.read(audioHandlerNotifierProvider)?.setDownloadedFiles(next);
    });
    ref.listen(companionAnalysisSyncProvider, (_, __) {});

    // Sync server config to audio handler
    ref.listen(serverConfigProvider, (_, next) {
      next.whenData((config) {
        if (config != null) {
          ref.read(audioHandlerNotifierProvider)?.setConfig(config);
        }
      });
    });

    // Sync stream quality and crossfade; re-download all on download quality
    // change; start full-library download when autoDownload is switched to 'all'.
    ref.listen(preferencesNotifierProvider, (prev, next) {
      ref
          .read(audioHandlerNotifierProvider)
          ?.setStreamQuality(next.streamQuality);
      if (prev != null && prev.downloadQuality != next.downloadQuality) {
        _redownloadAll(ref, next.downloadQuality);
      }
      if (prev != null &&
          prev.autoDownload != next.autoDownload &&
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
