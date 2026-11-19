import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/errors/app_errors.dart';
import '../../core/providers.dart';
import '../../shared/utils/snack.dart';
import '../../shared/widgets/error_notice.dart';
import '../../widgets/grouped_list_tile.dart';

/// Settings → Recommendations: how adventurous Home's suggestions are, the
/// songs and artists hidden with "Not interested", and a reset.
class RecommendationsSettingsScreen extends ConsumerWidget {
  const RecommendationsSettingsScreen({super.key});

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String _date(DateTime d) => '${_months[d.month - 1]} ${d.day}';

  Future<void> _restore(
      BuildContext context, WidgetRef ref, DismissedRec rec) async {
    try {
      await ref.read(databaseProvider).removeDismissedRec(rec.key);
      if (context.mounted) {
        showStyledSnack(context,
            rec.kind == 'artist' ? 'Restored ${rec.artist}' : 'Restored "${rec.title}"');
      }
    } catch (e) {
      AppErrors.report("Couldn't restore the hidden item", e);
    }
  }

  Future<void> _reset(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog.adaptive(
        title: const Text('Reset taste profile?'),
        content: const Text(
            'Shows hidden songs and artists again and forgets "More like '
            'this" taps and skips. Your play history and likes stay.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(databaseProvider).resetRecommendationFeedback();
      ref.invalidate(recommendationsProvider);
      if (context.mounted) showStyledSnack(context, 'Taste profile reset');
    } catch (e) {
      AppErrors.report("Couldn't reset the taste profile", e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final discovery =
        ref.watch(preferencesNotifierProvider.select((p) => p.recDiscovery));
    final hidden = ref.watch(dismissedRecsProvider);

    Widget header(String title) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
          child: Text(title,
              style: text.labelLarge?.copyWith(
                  color: scheme.primary, fontWeight: FontWeight.w700)),
        );

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.medium(
            title: const Text('Recommendations'),
            pinned: true,
            backgroundColor: scheme.surface,
            surfaceTintColor: Colors.transparent,
          ),
          SliverToBoxAdapter(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    header('Taste'),
                    GroupedSection(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Discovery', style: text.bodyLarge),
                              Text('How far from your usual artists',
                                  style: text.bodyMedium?.copyWith(
                                      color: scheme.onSurfaceVariant)),
                              Slider(
                                value: discovery,
                                min: 0,
                                max: 2,
                                divisions: 4,
                                label: _discoveryLabel(discovery),
                                onChanged: (v) {
                                  final notifier = ref
                                      .read(preferencesNotifierProvider.notifier);
                                  notifier.update(ref
                                      .read(preferencesNotifierProvider)
                                      .copyWith(recDiscovery: v));
                                },
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Familiar',
                                      style: text.labelSmall?.copyWith(
                                          color: scheme.onSurfaceVariant)),
                                  Text('Adventurous',
                                      style: text.labelSmall?.copyWith(
                                          color: scheme.onSurfaceVariant)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                      child: Text(
                          'Applies the next time you refresh recommendations.',
                          style: text.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant)),
                    ),
                    ...hidden.when(
                      loading: () => const [],
                      error: (e, _) => [
                        header('Hidden'),
                        ErrorNotice(
                          title: "Couldn't read hidden recommendations",
                          error: e,
                          onRetry: () => ref.invalidate(dismissedRecsProvider),
                        ),
                      ],
                      data: (rows) => [
                        header(rows.isEmpty ? 'Hidden' : 'Hidden · ${rows.length}'),
                        if (rows.isEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
                            child: Text(
                                'Nothing hidden. Use "Not interested" on a '
                                'recommendation to hide a song or artist.',
                                style: text.bodySmall
                                    ?.copyWith(color: scheme.onSurfaceVariant)),
                          )
                        else
                          GroupedSection(
                            children: [
                              for (final r in rows)
                                ListTile(
                                  leading: _HiddenThumb(rec: r),
                                  title: Text(
                                      r.kind == 'artist'
                                          ? r.artist
                                          : r.title ?? r.artist,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                  subtitle: Text(
                                      r.kind == 'artist'
                                          ? 'Artist · hidden ${_date(r.dismissedAt)}'
                                          : 'Song · ${r.artist}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                  trailing: TextButton(
                                    onPressed: () => _restore(context, ref, r),
                                    child: const Text('Restore'),
                                  ),
                                ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    GroupedSection(
                      children: [
                        ListTile(
                          leading: Icon(Icons.restart_alt_rounded,
                              color: scheme.error),
                          title: Text('Reset taste profile',
                              style: TextStyle(color: scheme.error)),
                          subtitle: const Text(
                              'Clears hidden items, "More like this" and '
                              'skips. Play history and likes stay.'),
                          onTap: () => _reset(context, ref),
                        ),
                      ],
                    ),
                    SizedBox(height: MediaQuery.paddingOf(context).bottom + 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _discoveryLabel(double v) => switch (v) {
        <= 0 => 'Familiar',
        <= 0.5 => 'Balanced',
        <= 1 => 'Curious',
        <= 1.5 => 'Exploring',
        _ => 'Adventurous',
      };
}

class _HiddenThumb extends StatelessWidget {
  final DismissedRec rec;
  const _HiddenThumb({required this.rec});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isArtist = rec.kind == 'artist';
    final fallback = Container(
      width: 40,
      height: 40,
      color: scheme.surfaceContainerHighest,
      child: Icon(isArtist ? Icons.person_rounded : Icons.music_note_rounded,
          size: 20, color: scheme.onSurfaceVariant),
    );
    final url = rec.coverUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(isArtist ? 20 : 6),
      child: url == null || url.isEmpty
          ? fallback
          : CachedNetworkImage(
              imageUrl: url,
              width: 40,
              height: 40,
              fit: BoxFit.cover,
              placeholder: (_, __) => fallback,
              errorWidget: (_, __, ___) => fallback,
            ),
    );
  }
}
