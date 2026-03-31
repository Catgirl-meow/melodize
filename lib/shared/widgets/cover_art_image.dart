import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';

class CoverArtImage extends ConsumerWidget {
  final String? coverArtId;
  /// Direct HTTPS URL used when [coverArtId] is absent (e.g. external tracks).
  final String? externalUrl;
  final double size;
  final double borderRadius;
  final BoxFit fit;

  const CoverArtImage({
    super.key,
    required this.coverArtId,
    this.externalUrl,
    required this.size,
    this.borderRadius = 8,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final subsonicUrl = coverArtId != null && coverArtId!.isNotEmpty
        ? ref.watch(coverArtUrlProvider(coverArtId!))
        : null;
    final url = subsonicUrl ?? externalUrl;

    Widget child;
    if (url != null) {
      // Cap the in-memory decoded size to 2× display pixels so full-resolution
      // server images (1000 px+) don't inflate the image cache for small tiles.
      // double.infinity means the container controls size — skip the cap.
      final cacheSize = size.isFinite
          ? (size * MediaQuery.devicePixelRatioOf(context) * 1.5).ceil()
          : null;
      child = CachedNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: fit,
        memCacheWidth: cacheSize,
        memCacheHeight: cacheSize,
        errorWidget: (_, __, ___) => _placeholder(scheme),
        placeholder: (_, __) => _placeholder(scheme),
      );
    } else {
      child = _placeholder(scheme);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: child,
    );
  }

  Widget _placeholder(ColorScheme scheme) => Container(
        width: size,
        height: size,
        color: scheme.surfaceContainerHigh,
        child: Icon(
          Icons.music_note_rounded,
          size: size * 0.4,
          color: scheme.onSurfaceVariant,
        ),
      );
}
