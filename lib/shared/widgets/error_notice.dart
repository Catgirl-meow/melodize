import 'package:flutter/material.dart';

import '../../core/errors/app_errors.dart';

/// Inline error card: says what failed, why, and offers a retry.
///
/// Used wherever a load can fail, so a failure reads as a failure and not
/// as an empty list ("No albums") or a section that silently disappears.
class ErrorNotice extends StatelessWidget {
  /// What failed, e.g. "Couldn't load albums".
  final String title;

  /// The cause; rendered through [describeError].
  final Object? error;
  final VoidCallback? onRetry;

  /// Compact variant for a section inside a longer page.
  final bool compact;

  const ErrorNotice({
    super.key,
    required this.title,
    this.error,
    this.onRetry,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final detail = error == null ? null : describeError(error!);

    final card = Container(
      constraints: const BoxConstraints(maxWidth: 520),
      padding: EdgeInsets.fromLTRB(16, compact ? 10 : 14, 8, compact ? 10 : 14),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded,
              color: scheme.onErrorContainer, size: compact ? 20 : 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    style: (compact ? text.bodyMedium : text.titleSmall)
                        ?.copyWith(
                            color: scheme.onErrorContainer,
                            fontWeight: FontWeight.w600)),
                if (detail != null && detail.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(detail,
                      style: text.bodySmall
                          ?.copyWith(color: scheme.onErrorContainer)),
                ],
              ],
            ),
          ),
          if (onRetry != null)
            TextButton(
              style: TextButton.styleFrom(
                  foregroundColor: scheme.onErrorContainer),
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
        ],
      ),
    );

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: compact ? 8 : 24),
      child: Center(child: card),
    );
  }
}
