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
    // First tick at 3 s for snappy small-file completion, then every 10 s.
    _pollTimer = Timer(const Duration(seconds: 3), () => _poll(companion, jobId, ++attempts));
  }

  void _poll(CompanionClient companion, String jobId, int attempts) async {
    if (!mounted) return;
    if (attempts >= 36) return; // ≈5 min total budget
    try {
      final status = await companion.getDownloadStatus(jobId);
      final s = status['status'] as String?;
      if (s == 'done') {
        ref.read(subsonicClientProvider)?.startScan();
        // Kick the library immediately (fast path: song already indexed)
        // and again after 12 s (typical Navidrome scan duration). Without
        // this, a successful companion download doesn't surface in the app
        // until the user pulls-to-refresh.
        ref.invalidate(allSongsProvider);
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
    }
    if (!mounted) return;
    _pollTimer = Timer(
      const Duration(seconds: 10),
      () => _poll(companion, jobId, attempts + 1),
    );
  }
}
