import 'package:flutter/material.dart';

/// The Play / Shuffle / Download row under the album, playlist and artist
/// headers. One widget so the three pages can't drift apart again.
class DetailActions extends StatelessWidget {
  final VoidCallback? onPlay;
  final VoidCallback? onShuffle;

  /// Hidden when null (playlists have no bulk download).
  final VoidCallback? onDownload;
  final String downloadTooltip;
  final bool downloadBusy;

  const DetailActions({
    super.key,
    required this.onPlay,
    required this.onShuffle,
    this.onDownload,
    this.downloadTooltip = 'Download all',
    this.downloadBusy = false,
  });

  static const _height = 48.0;

  @override
  Widget build(BuildContext context) {
    final buttonStyle = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(0, _height)),
      textStyle: WidgetStatePropertyAll(Theme.of(context).textTheme.titleSmall),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              style: buttonStyle,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Play'),
              onPressed: onPlay,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton.tonalIcon(
              style: buttonStyle,
              icon: const Icon(Icons.shuffle_rounded),
              label: const Text('Shuffle'),
              onPressed: onShuffle,
            ),
          ),
          if (onDownload != null || downloadBusy) ...[
            const SizedBox(width: 8),
            IconButton.filledTonal(
              constraints: const BoxConstraints.tightFor(
                  width: _height, height: _height),
              tooltip: downloadTooltip,
              onPressed: downloadBusy ? null : onDownload,
              icon: downloadBusy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.download_rounded),
            ),
          ],
        ],
      ),
    );
  }
}
