import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/navidrome_client.dart';
import '../../core/providers.dart';
import 'snack.dart';

/// Mixin for ConsumerState subclasses that poll a companion download job.
/// Provides [startDownloadPolling] and automatically cancels the timer on
/// dispose.  Mix into any ConsumerState that needs Deezer→server downloads.
mixin DownloadPollingMixin<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  Timer? _pollTimer;
  // Track consecutive poll failures so we can warn after sustained loss
  // instead of failing silently when the companion drops mid-job.
  int _consecutiveErrors = 0;
  bool _connectionLostSnackShown = false;

  /// Override to force a specific bottom-margin for snacks fired by this
  /// mixin. Needed when the host widget lives outside the shell's injected
  /// MediaQuery padding (e.g. the NowPlayingScreen player overlay) — the
  /// default offset would put the snack behind the mini player / dock.
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
    // First tick at 3 s for snappy small-file completion, then every 10 s.
    _pollTimer = Timer(const Duration(seconds: 3), () => _poll(companion, jobId, ++attempts));
  }

  void _poll(CompanionClient companion, String jobId, int attempts) async {
    if (!mounted) return;
    if (attempts >= 36) {
      // 5 min budget exhausted — surface a snackbar so the user knows the
      // job stopped instead of silently dropping it.
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
        // Single delayed invalidation only. The previous immediate +
        // delayed pair caused two full library refreshes back-to-back —
        // the immediate one always missed because the song hadn't been
        // indexed by Navidrome yet, so it was wasted work + UI jank.
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
          showStyledSnack(context, 'Download failed: $err',
              isError: true, bottomOffset: snackBottomOffset);
        }
        return;
      }
    } catch (_) {
      // Transient network hiccup — keep polling rather than giving up.
      // After 3 consecutive failures (≈30 s) surface a one-time snack so
      // the user knows the companion is unreachable.
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
