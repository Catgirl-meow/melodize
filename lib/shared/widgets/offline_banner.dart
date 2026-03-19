import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../features/downloads/downloads_screen.dart';

/// Inline offline banner. Animates in/out as the device goes offline/online.
/// Shows "Offline. Browse downloads" with "downloads" tappable as a link.
///
/// Usage: embed directly in a Column or as a SliverToBoxAdapter — it manages
/// its own visibility internally.
class OfflineBanner extends ConsumerStatefulWidget {
  const OfflineBanner({super.key});

  @override
  ConsumerState<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends ConsumerState<OfflineBanner> {
  // null  = hidden
  // true  = offline (persistent)
  // false = back-online flash (auto-hides after 2s)
  bool? _mode;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    // ref.listen only fires on *changes*. If the device is already offline
    // when this widget first mounts, we need to seed the initial state here.
    final current = ref.read(isOnlineProvider).valueOrNull;
    if (current == false) _mode = true;
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<bool>>(isOnlineProvider, (prev, next) {
      final wasOnline = prev?.valueOrNull ?? true;
      final isNowOnline = next.valueOrNull ?? true;

      if (!isNowOnline && wasOnline) {
        _hideTimer?.cancel();
        setState(() => _mode = true);
      } else if (isNowOnline && wasOnline == false) {
        _hideTimer?.cancel();
        setState(() => _mode = false);
        _hideTimer = Timer(const Duration(seconds: 2), () {
          if (mounted) setState(() => _mode = null);
        });
      }
    });

    final visible = _mode != null;

    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      child: visible ? _BannerRow(isOffline: _mode!) : const SizedBox.shrink(),
    );
  }
}

class _BannerRow extends StatelessWidget {
  final bool isOffline;
  const _BannerRow({required this.isOffline});

  @override
  Widget build(BuildContext context) {
    final bg = isOffline ? const Color(0xFFBF360C) : const Color(0xFF2E7D32);

    Widget content;
    if (isOffline) {
      content = Text.rich(
        TextSpan(
          children: [
            const TextSpan(text: 'Offline. Browse '),
            TextSpan(
              text: 'downloads',
              style: const TextStyle(
                decoration: TextDecoration.underline,
                decorationColor: Colors.white,
                fontWeight: FontWeight.w600,
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DownloadsScreen(),
                      ),
                    ),
            ),
          ],
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            decoration: TextDecoration.none,
          ),
        ),
      );
    } else {
      content = const Text(
        'Back online',
        style: TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          decoration: TextDecoration.none,
        ),
      );
    }

    return Container(
      width: double.infinity,
      color: bg,
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isOffline ? Icons.wifi_off_rounded : Icons.wifi_rounded,
            size: 14,
            color: Colors.white,
          ),
          const SizedBox(width: 6),
          content,
        ],
      ),
    );
  }
}
