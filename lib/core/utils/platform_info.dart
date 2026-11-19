import 'dart:io';

// Platform helpers shared by the UI and the audio handler.
//
// Melodize ships on Android and Linux. The distinction that actually
// matters in the code is mobile (system-managed window, system bars,
// edge-to-edge, background service owns the handler) versus desktop
// (app-owned window, bouncing scroll physics, keyboard shortcuts, an in-app
// volume slider because the OS volume keys control the output device rather
// than the app).

/// True on the desktop build (Linux).
bool get isDesktopPlatform => Platform.isLinux;

/// True on the mobile build (Android).
bool get isMobilePlatform => Platform.isAndroid;
