import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/navidrome_client.dart';
import '../../core/providers.dart';

/// Mixin for ConsumerState subclasses that poll a companion download job.
/// Provides [startDownloadPolling] and automatically cancels the timer on
/// dispose.  Mix into any ConsumerState that needs Deezer→server downloads.
mixin DownloadPollingMixin<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  Timer? _pollTimer;

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void startDownloadPolling(CompanionClient companion, String jobId) {
    var attempts = 0;
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (++attempts >= 24) {
        timer.cancel();
        return;
      }
      try {
        final status = await companion.getDownloadStatus(jobId);
        final s = status['status'] as String?;
        if (s == 'done') {
          timer.cancel();
          ref.read(subsonicClientProvider)?.startScan();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Added to Navidrome server — library scan started'),
            ));
          }
        } else if (s == 'error') {
          timer.cancel();
          if (mounted) {
            final err = (status['error'] as String?) ?? 'unknown error';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Download failed: $err')),
            );
          }
        }
      } catch (_) {}
    });
  }
}
