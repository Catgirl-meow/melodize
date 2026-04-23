import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/recommended_track.dart';
import '../../core/models/song.dart';
import '../../core/providers.dart';
import '../utils/download_polling_mixin.dart';
import '../utils/snack.dart';

/// Reusable tile for a Deezer track — play 30s preview, optionally save to
/// Navidrome via the companion. Used in search results and the artist page.
class DeezerTrackTile extends ConsumerStatefulWidget {
  final RecommendedTrack track;
  const DeezerTrackTile({super.key, required this.track});

  @override
  ConsumerState<DeezerTrackTile> createState() => _DeezerTrackTileState();
}

class _DeezerTrackTileState extends ConsumerState<DeezerTrackTile>
    with DownloadPollingMixin {
  void _playPreview() {
    final song = Song.fromRecommendation(
      deezerId: widget.track.deezerId,
      title: widget.track.title,
      artist: widget.track.artist,
      album: widget.track.album,
      durationSeconds: widget.track.durationSeconds,
      previewUrl: widget.track.previewUrl,
      coverUrl: widget.track.coverUrl,
    );
    ref.read(audioHandlerNotifierProvider)?.loadQueue([song]);
  }

  Future<void> _saveToServer() async {
    final companion = ref.read(companionClientProvider);
    if (companion == null) return;
    final prefs = ref.read(preferencesNotifierProvider);
    final url = 'https://www.deezer.com/track/${widget.track.deezerId}';
    try {
      final jobId = await companion.startDownload(
        url,
        deezerArl: prefs.hasDeezerArl ? prefs.deezerArl : null,
      );
      if (!mounted) return;
      showStyledSnack(
        context,
        prefs.hasDeezerArl
            ? 'Downloading FLAC to Navidrome server…'
            : 'Downloading to Navidrome server (add Deezer ARL in Settings for lossless)',
      );
      startDownloadPolling(companion, jobId);
    } catch (e) {
      if (!mounted) return;
      showStyledSnack(context, 'Could not start download: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final canSave = ref.watch(canDeleteFromServerProvider);

    final Widget leading;
    if (widget.track.coverUrl != null) {
      leading = ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: CachedNetworkImage(
          imageUrl: widget.track.coverUrl!,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          placeholder: (_, __) => _placeholder(scheme),
          errorWidget: (_, __, ___) => _placeholder(scheme),
        ),
      );
    } else {
      leading = _placeholder(scheme);
    }

    return ListTile(
      leading: leading,
      title: Text(widget.track.title,
          maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        widget.track.album.isNotEmpty
            ? '${widget.track.artist} · ${widget.track.album}'
            : widget.track.artist,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: scheme.onSurfaceVariant),
      ),
      onTap: _playPreview,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.play_circle_outline_rounded),
            tooltip: 'Play 30s preview',
            onPressed: _playPreview,
          ),
          if (canSave)
            IconButton(
              icon: const Icon(Icons.download_for_offline_rounded),
              tooltip: 'Save to Navidrome server',
              onPressed: _saveToServer,
            ),
        ],
      ),
    );
  }

  Widget _placeholder(ColorScheme scheme) => ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 48,
          height: 48,
          color: scheme.surfaceContainerHigh,
          child: Icon(Icons.music_note_rounded,
              size: 20, color: scheme.onSurfaceVariant),
        ),
      );
}
