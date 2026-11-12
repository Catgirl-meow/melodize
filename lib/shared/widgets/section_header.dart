import 'package:flutter/material.dart';

/// Header above a list section on the search and detail pages: a bold
/// title with an optional muted count, e.g. "Albums 3".
class SectionHeader extends StatelessWidget {
  final String title;
  final String? count;
  final IconData? icon;

  const SectionHeader(this.title, {super.key, this.count, this.icon});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: scheme.primary),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 8),
            Text(
              count!,
              style: text.titleMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}
