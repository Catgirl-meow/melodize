import 'package:flutter/material.dart';

import '../../core/models/song.dart';

/// Songs being dragged onto a playlist (desktop Library sidebar).
class SongDragData {
  final List<Song> songs;
  const SongDragData(this.songs);
}

/// Present above a list when its songs can be dragged onto playlists. Only
/// the wide (desktop) Library layout provides it, so phones keep their
/// normal long-press behaviour.
class SongDragScope extends InheritedWidget {
  const SongDragScope({super.key, required super.child});

  static bool enabled(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SongDragScope>() != null;

  @override
  bool updateShouldNotify(SongDragScope oldWidget) => false;
}

/// The chip that follows the pointer while dragging songs.
class SongDragFeedback extends StatelessWidget {
  final List<Song> songs;
  const SongDragFeedback({super.key, required this.songs});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label =
        songs.length == 1 ? songs.single.title : '${songs.length} songs';
    return Material(
      color: scheme.primaryContainer,
      elevation: 6,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.music_note_rounded,
                size: 18, color: scheme.onPrimaryContainer),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 240),
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}
