import 'package:flutter/material.dart';

import '../../core/recs/taste_model.dart' show SeedReason, TasteSeed;

/// Icon and label for why a recommendation was picked ("You like Kaito
/// Ren"), shown as a chip in the player.
(IconData, String) describeRecReason(TasteSeed seed) => switch (seed.reason) {
      SeedReason.liked => (
          Icons.favorite_rounded,
          'Because you like ${seed.artist}'
        ),
      SeedReason.recent => (
          Icons.history_rounded,
          'You played ${seed.artist} lately'
        ),
      SeedReason.topArtist => (
          Icons.graphic_eq_rounded,
          'Similar to ${seed.artist}'
        ),
    };

/// "Not interested" row of the player's menu for a recommendation. Tapping it reveals a
/// choice: hide just this song, or every song by the artist.
class NotInterestedTile extends StatefulWidget {
  final String artist;
  final ValueChanged<bool> onChoose; // true = whole artist
  final String subtitle;
  const NotInterestedTile({
    super.key,
    required this.artist,
    required this.onChoose,
    this.subtitle = 'Hide it and show less like it',
  });

  @override
  State<NotInterestedTile> createState() => _NotInterestedTileState();
}

class _NotInterestedTileState extends State<NotInterestedTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: Icon(Icons.block_rounded, color: scheme.error),
          title: Text('Not interested', style: TextStyle(color: scheme.error)),
          subtitle: Text(widget.subtitle),
          onTap: () => setState(() => _open = !_open),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: !_open
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.fromLTRB(72, 0, 16, 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<bool>(
                      segments: [
                        const ButtonSegment(
                            value: false, label: Text('This song')),
                        ButtonSegment(
                          value: true,
                          label: Text(widget.artist,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      ],
                      selected: const {},
                      emptySelectionAllowed: true,
                      showSelectedIcon: false,
                      onSelectionChanged: (sel) {
                        if (sel.isNotEmpty) widget.onChoose(sel.first);
                      },
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
