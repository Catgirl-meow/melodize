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
          showStyledSnack(context, 'Download failed: $err',
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
