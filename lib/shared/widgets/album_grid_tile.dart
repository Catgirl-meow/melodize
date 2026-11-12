import 'package:flutter/material.dart';

import 'cover_art_image.dart';

/// Album tile for two-column grids (Library > Albums, artist pages): a
/// square cover with the name (up to two lines) and up to two detail lines
/// underneath. Use [AlbumGridTile.extent] for the grid's `mainAxisExtent`
/// so long names and large system fonts never overflow.
class AlbumGridTile extends StatelessWidget {
  final String? coverArtId;
  final String title;
  final String? subtitle;
  final String? caption;
  final Widget? trailing;
  final VoidCallback onTap;

  const AlbumGridTile({
    super.key,
    required this.coverArtId,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.caption,
    this.trailing,
  });

  static const radius = 12.0;
  static const _lineHeight = 1.3;
  static const _gap = 8.0;

  static TextStyle? _titleStyle(BuildContext context) => Theme.of(context)
      .textTheme
      .titleSmall
      ?.copyWith(fontWeight: FontWeight.w600, height: _lineHeight);

  static TextStyle? _detailStyle(BuildContext context) =>
      Theme.of(context).textTheme.bodySmall?.copyWith(
          height: _lineHeight,
          color: Theme.of(context).colorScheme.onSurfaceVariant);

  /// Height of a tile [width] wide with [detailLines] lines under the name.
  static double extent(BuildContext context, double width,
      {int detailLines = 2}) {
    final scaler = MediaQuery.textScalerOf(context);
    final title = scaler.scale(_titleStyle(context)?.fontSize ?? 14);
    final detail = scaler.scale(_detailStyle(context)?.fontSize ?? 12);
    // +4: slack for font metrics rounding.
    return width +
        _gap +
        title * _lineHeight * 2 +
        detail * _lineHeight * detailLines +
        12;
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detailStyle(context);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: CoverArtImage(
                coverArtId: coverArtId,
                size: double.infinity,
                borderRadius: radius,
              ),
            ),
            const SizedBox(height: _gap),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: _titleStyle(context)),
                        if (subtitle != null)
                          Text(subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: detail),
                        if (caption != null)
                          Text(caption!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: detail),
                      ],
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
