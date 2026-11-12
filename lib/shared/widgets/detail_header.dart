import 'package:flutter/material.dart';

import 'cover_art_image.dart';

/// Collapsing cover header for the album, playlist and artist pages.
///
/// Expanded, the name wraps over up to three lines under the cover. Collapsed,
/// it moves into the toolbar as one ellipsized line. This replaces a
/// multi-line [FlexibleSpaceBar.title], which cannot shrink into the toolbar:
/// long names were cut to one line or overflowed the collapsed bar.
class DetailHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? coverArtId;

  /// Replaces the [coverArtId] image, e.g. a playlist's [PlaylistCover].
  final Widget? cover;
  final double expandedHeight;
  final bool stretch;

  const DetailHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.coverArtId,
    this.cover,
    this.expandedHeight = 280,
    this.stretch = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SliverAppBar(
      expandedHeight: expandedHeight,
      pinned: true,
      stretch: stretch,
      flexibleSpace: Stack(
        fit: StackFit.expand,
        children: [
          FlexibleSpaceBar(
            stretchModes: const [
              StretchMode.zoomBackground,
              StretchMode.blurBackground,
            ],
            background: Stack(
              fit: StackFit.expand,
              children: [
                cover ??
                    CoverArtImage(
                      coverArtId: coverArtId,
                      size: double.infinity,
                      borderRadius: 0,
                      fit: BoxFit.cover,
                      placeholderIcon: false,
                    ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        scheme.surface.withValues(alpha: 0.92),
                      ],
                      stops: const [0.3, 1.0],
                    ),
                  ),
                ),
              ],
            ),
          ),
          _HeaderTitles(title: title, subtitle: subtitle),
        ],
      ),
    );
  }
}

class _HeaderTitles extends StatelessWidget {
  final String title;
  final String? subtitle;
  const _HeaderTitles({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settings =
        context.dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
    // 1 = fully expanded, 0 = collapsed to the toolbar.
    var t = 1.0;
    if (settings != null && settings.maxExtent > settings.minExtent) {
      t = ((settings.currentExtent - settings.minExtent) /
              (settings.maxExtent - settings.minExtent))
          .clamp(0.0, 1.0);
    }
    final top = MediaQuery.paddingOf(context).top;
    // The big titles fade out over the last stretch of the collapse and the
    // toolbar title fades in, so the two never show at once.
    final bigOpacity = ((t - 0.25) / 0.45).clamp(0.0, 1.0);
    final barOpacity = ((0.3 - t) / 0.3).clamp(0.0, 1.0);

    return Stack(
      fit: StackFit.expand,
      children: [
        if (bigOpacity > 0)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Opacity(
              opacity: bigOpacity,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold, height: 1.2),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
          ),
        if (barOpacity > 0)
          Positioned(
            top: top,
            left: 64,
            right: 16,
            height: kToolbarHeight,
            child: Opacity(
              opacity: barOpacity,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
