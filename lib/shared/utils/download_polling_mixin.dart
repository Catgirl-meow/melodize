import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/navidrome_client.dart';
import '../../core/providers.dart';
import 'snack.dart';

/// Polls a companion download job and shows snackbars for completion/failure.
/// Mix into any [ConsumerState] that initiates Deezer→server downloads.
mixin DownloadPollingMixin<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  Timer? _pollTimer;
  // Warn after sustained connection loss instead of failing silently.
  int _consecutiveErrors = 0;
  bool _connectionLostSnackShown = false;

  /// Bottom margin for snackbars. Override when the widget lives outside
  /// the shell's MediaQuery (e.g. NowPlaying overlay).
  double? get snackBottomOffset => null;

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void startDownloadPolling(CompanionClient companion, String jobId) {
    var attempts = 0;
    _pollTimer?.cancel();
    _consecutiveErrors = 0;
    _connectionLostSnackShown = false;
    // Fast first tick for small files, then every 10 s.
    _pollTimer = Timer(const Duration(seconds: 3), () => _poll(companion, jobId, ++attempts));
  }

  void _poll(CompanionClient companion, String jobId, int attempts) async {
    if (!mounted) return;
    if (attempts >= 36) {
      // 5 min budget exhausted.
      if (mounted) {
        showStyledSnack(context,
            'Download timed out — companion may be slow or stalled. Try again.',
            isError: true, bottomOffset: snackBottomOffset);
      }
      return;
    }
    try {
      final status = await companion.getDownloadStatus(jobId);
      _consecutiveErrors = 0;
      final s = status['status'] as String?;
      if (s == 'done') {
        ref.read(subsonicClientProvider)?.startScan();
          // Navidrome needs time to index; the immediate refresh always
        // missed, so only the delayed one remains.
        Future.delayed(const Duration(seconds: 12), () {
          if (mounted) ref.invalidate(allSongsProvider);
        });
        if (mounted) {
          showStyledSnack(
              context, 'Added to Navidrome — refreshing library…',
              bottomOffset: snackBottomOffset);
        }
        return;
      }
      if (s == 'error') {
        if (mounted) {
          final err = (status['error'] as String?) ?? 'unknown error';
          // Friendly error messages for common failure modes.
          final msg = _friendlyDownloadError(err);
          showStyledSnack(context, msg,
              isError: true, bottomOffset: snackBottomOffset);
        }
        return;
      }
    } catch (_) {
      // Keep polling on transient errors. Warn after 3 failures (~30 s).
      _consecutiveErrors++;
      if (_consecutiveErrors >= 3 && !_connectionLostSnackShown && mounted) {
        _connectionLostSnackShown = true;
        showStyledSnack(context,
            'Lost connection to companion — still trying…',
            isError: true, bottomOffset: snackBottomOffset);
      }
    }
    if (!mounted) return;
    _pollTimer = Timer(
      const Duration(seconds: 10),
      () => _poll(companion, jobId, attempts + 1),
    );
  }
}

/// Map raw companion error strings to user-friendly messages.
String _friendlyDownloadError(String err) {
  final lower = err.toLowerCase();
  if (lower.contains('unreachable from server') ||
      lower.contains('server network or proxy')) {
    return 'Deezer unreachable from server — check server network or VPN';
  }
  if (lower.contains('session expired') ||
      lower.contains('update your arl')) {
    return 'Deezer session expired — update ARL in Settings';
  }
  if (lower.contains('could not authenticate despite valid')) {
    return 'Deezer download error — deemix failed despite valid ARL';
  }
  if (lower.contains('arl not configured')) {
    return 'Deezer ARL required — add it in Settings';
  }
  if (lower.contains('not installed')) {
    return 'Download tool not installed on companion server';
  }
  if (lower.contains('timed out')) {
    return 'Download timed out — try again or check the server';
  }
  if (lower.contains('drm')) {
    return 'Track is DRM-protected and cannot be downloaded';
  }
  if (lower.contains('cannot download at the desired quality') ||
      lower.contains('subscription may have ended')) {
    return 'Deezer subscription issue — cannot download at this quality. Check your Deezer plan.';
  }
  if (lower.contains('not available in your region') ||
      lower.contains('has been removed')) {
    return 'Track is not available in your region or has been removed from Deezer';
  }
  if (lower.contains('no file was created')) {
    return 'Download failed — no file was produced. The track may be unavailable.';
  }
  return 'Download failed: $err';
}
