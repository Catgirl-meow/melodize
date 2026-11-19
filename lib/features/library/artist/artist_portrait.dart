import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../shared/widgets/cover_art_image.dart';

/// Material 3 Expressive "cookie" shape: a circle with [lobes] soft scallops.
class CookieShape extends ShapeBorder {
  final int lobes;

  /// Depth of the scallops as a fraction of the radius.
  final double depth;

  const CookieShape({this.lobes = 9, this.depth = 0.055});

  Path _path(Rect rect) {
    final c = rect.center;
    final radius = rect.shortestSide / 2;
    const steps = 180;
    final path = Path();
    for (var i = 0; i <= steps; i++) {
      final t = i / steps * 2 * pi;
      final r = radius * (1 + depth * cos(lobes * t)) / (1 + depth);
      // Start at the top so a lobe points up.
      final a = t - pi / 2;
      final p = Offset(c.dx + r * cos(a), c.dy + r * sin(a));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => _path(rect);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => _path(rect);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) => this;
}

/// The artist image: a network [imageUrl] (server or Deezer artist photo)
/// when there is one, else the Subsonic [coverArtId].
class ArtistImage extends StatelessWidget {
  final String? imageUrl;
  final String? coverArtId;
  final double size;

  const ArtistImage({
    super.key,
    required this.imageUrl,
    required this.coverArtId,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final fallback = CoverArtImage(
      coverArtId: coverArtId,
      size: size,
      borderRadius: 0,
      placeholderIcon: false,
    );
    final url = imageUrl;
    if (url == null || url.isEmpty) return fallback;
    return CachedNetworkImage(
      imageUrl: url,
      width: size,
      height: size,
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 200),
      placeholder: (_, __) => fallback,
      errorWidget: (_, __, ___) => fallback,
    );
  }
}

/// [ArtistImage] clipped to the cookie shape, on a tinted backdrop so a
/// missing image still shows the shape.
class ArtistPortrait extends StatelessWidget {
  final String? imageUrl;
  final String? coverArtId;
  final double size;
  final String name;

  const ArtistPortrait({
    super.key,
    required this.imageUrl,
    required this.coverArtId,
    required this.size,
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      image: true,
      label: 'Photo of $name',
      child: ClipPath(
        clipper: const ShapeBorderClipper(shape: CookieShape()),
        child: ColoredBox(
          color: scheme.primaryContainer,
          child: SizedBox.square(
            dimension: size,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Center(
                  child: Icon(Icons.person_rounded,
                      size: size * 0.45, color: scheme.onPrimaryContainer),
                ),
                ArtistImage(
                    imageUrl: imageUrl, coverArtId: coverArtId, size: size),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
