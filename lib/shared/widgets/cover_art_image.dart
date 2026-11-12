import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../core/providers.dart';

/// Returns the local cover-art file path derived from an audio file path.
/// Convention: same directory and base name, with `.cover.jpg` suffix.
/// E.g. `/music/song.flac` → `/music/song.cover.jpg`
String? localCoverArtPath(String? audioPath) {
  if (audioPath == null || audioPath.isEmpty) return null;
  final dir = p.dirname(audioPath);
  final base = p.basenameWithoutExtension(audioPath);
  return p.join(dir, '$base.cover.jpg');
}

class CoverArtImage extends ConsumerWidget {
  final String? coverArtId;
  /// Direct HTTPS URL used when [coverArtId] is absent (e.g. external tracks).
  final String? externalUrl;
  /// Path to the local audio file — used to derive the cached cover art path
  /// for offline display of downloaded songs.
  final String? localPath;
  final double size;
  final double borderRadius;
  final BoxFit fit;

  /// Draw the music-note icon on the placeholder. Off for page headers,
  /// where the name text sits on top of the cover area.
  final bool placeholderIcon;

  const CoverArtImage({
    super.key,
    required this.coverArtId,
    this.externalUrl,
    this.localPath,
    required this.size,
    this.borderRadius = 8,
    this.fit = BoxFit.cover,
    this.placeholderIcon = true,
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
        errorWidget: (_, __, ___) => _localOrPlaceholder(scheme),
        placeholder: (_, __) => _localOrPlaceholder(scheme),
      );
    } else {
      child = _localOrPlaceholder(scheme);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: child,
    );
  }

  /// Try to load a locally-cached cover art file (saved alongside downloaded
  /// audio). Falls back to the music-note placeholder.
  Widget _localOrPlaceholder(ColorScheme scheme) {
    final local = localCoverArtPath(localPath);
    if (local != null && File(local).existsSync()) {
      return Image.file(
        File(local),
        width: size,
        height: size,
        fit: fit,
        errorBuilder: (_, __, ___) => _placeholder(scheme),
      );
    }
    return _placeholder(scheme);
  }

  Widget _placeholder(ColorScheme scheme) => Container(
        width: size,
        height: size,
        color: scheme.surfaceContainerHigh,
        child: !placeholderIcon ? null : Icon(
          Icons.music_note_rounded,
          // Grids pass size: double.infinity to fill their box; an
          // infinite icon size throws, so fall back to a fixed one there.
          size: size.isFinite ? size * 0.4 : 72,
          color: scheme.onSurfaceVariant,
        ),
      );
}
