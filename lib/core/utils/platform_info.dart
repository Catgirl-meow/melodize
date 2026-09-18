import 'dart:io';

// Platform helpers shared by the UI and the audio handler.
//
// Melodize ships on Android, Linux and macOS. The distinction that actually
// matters in the code is mobile (system-managed window, system bars,
// edge-to-edge, background service owns the handler) versus desktop
// (app-owned window, bouncing scroll physics, keyboard shortcuts, an in-app
// volume slider because the OS volume keys control the output device rather
// than the app).

/// True on desktop platforms (Linux, macOS, Windows).
bool get isDesktopPlatform =>
    Platform.isLinux || Platform.isMacOS || Platform.isWindows;

/// True on mobile platforms (Android, iOS).
bool get isMobilePlatform => Platform.isAndroid || Platform.isIOS;
