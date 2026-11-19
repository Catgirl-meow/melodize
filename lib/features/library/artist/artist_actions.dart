import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_errors.dart';
import '../../../core/library/artist_profile.dart';
import '../../../core/models/artist.dart';
import '../../../core/models/song.dart';
import '../../../core/providers.dart';
import '../../../shared/utils/snack.dart';
import '../../../shared/utils/song_actions.dart';

/// Loads every song by [artist] (cached when offline) or reports why not.
Future<List<Song>?> loadArtistSongs(
    BuildContext context, WidgetRef ref, Artist artist) async {
  try {
    return await ref.read(artistAllSongsProvider(artist.id).future);
  } catch (e) {
    if (context.mounted) {
      showStyledSnack(context, "Couldn't load ${artist.name}'s songs: $e",
          isError: true);
    }
    return null;
  }
}

Future<void> playArtist(BuildContext context, WidgetRef ref, Artist artist,
    {bool shuffle = false}) async {
  final songs = await loadArtistSongs(context, ref, artist);
  if (songs == null || songs.isEmpty) return;
  final queue = shuffle ? ([...songs]..shuffle()) : songs;
  await ref.read(audioHandlerNotifierProvider)?.loadQueue(queue);
}

/// Artist radio: this artist mixed with the similar artists that are in the
/// library (up to five), so it works without Deezer. When smart shuffle is on
/// the player orders the queue as a DJ set like any other queue.
Future<void> startArtistRadio(
    BuildContext context, WidgetRef ref, Artist artist) async {
  final own = await loadArtistSongs(context, ref, artist);
  if (own == null) return;

  final similarIds = <String>[];
  try {
    final info = await ref.read(artistInfoProvider(artist.id).future);
    similarIds.addAll(info.similar
        .where((s) => s.inLibrary && s.id != artist.id)
        .map((s) => s.id!)
        .take(5));
  } on DeviceOfflineException {
    // Offline there is no similar-artists data; the radio is this artist.
  } catch (e) {
    AppErrors.report("Couldn't load similar artists for the radio", e);
  }

  final similarSongs = <List<Song>>[];
  for (final id in similarIds) {
    try {
      similarSongs.add(await ref.read(artistAllSongsProvider(id).future));
    } catch (e) {
      AppErrors.report("Couldn't load a similar artist for the radio", e);
    }
  }

  final queue = buildArtistRadio(own, similarSongs,
      seed: Random().nextInt(1 << 31));
  if (queue.isEmpty) return;
  await ref.read(audioHandlerNotifierProvider)?.loadQueue(queue);
  if (context.mounted) {
    showStyledSnack(
      context,
      similarSongs.isEmpty
          ? 'Playing ${artist.name} radio'
          : 'Playing ${artist.name} radio with ${similarSongs.length} similar '
              'artist${similarSongs.length == 1 ? '' : 's'}',
    );
  }
}

/// Play, Shuffle, Artist radio and Download all, as an M3 Expressive button
/// group: a large Play pill and three square tonal buttons.
class ArtistActions extends ConsumerStatefulWidget {
  final Artist artist;

  /// Button height: 64 on phones, 56 in the desktop side pane.
  final double height;

  const ArtistActions({super.key, required this.artist, this.height = 64});

  @override
  ConsumerState<ArtistActions> createState() => _ArtistActionsState();
}

class _ArtistActionsState extends ConsumerState<ArtistActions> {
  String? _busy;

  Future<void> _run(String key, Future<void> Function() action) async {
    if (_busy != null) return;
    setState(() => _busy = key);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final h = widget.height;
    final artist = widget.artist;

    Widget square({
      required String key,
      required IconData icon,
      required String tooltip,
      required Color bg,
      required Color fg,
      required Future<void> Function() onTap,
    }) {
      return Tooltip(
        message: tooltip,
        child: SizedBox.square(
          dimension: h,
          child: FilledButton(
            onPressed: _busy == null ? () => _run(key, onTap) : null,
            style: FilledButton.styleFrom(
              backgroundColor: bg,
              foregroundColor: fg,
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(h * 0.31)),
            ),
            child: _busy == key
                ? SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: fg))
                : Icon(icon, semanticLabel: tooltip),
          ),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: h,
            child: FilledButton.icon(
              onPressed: _busy == null
                  ? () => _run('play', () => playArtist(context, ref, artist))
                  : null,
              style: FilledButton.styleFrom(
                shape: const StadiumBorder(),
                textStyle: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              icon: _busy == 'play'
                  ? SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: scheme.onPrimary))
                  : const Icon(Icons.play_arrow_rounded, size: 30),
              label: const Text('Play'),
            ),
          ),
        ),
        const SizedBox(width: 8),
        square(
          key: 'shuffle',
          icon: Icons.shuffle_rounded,
          tooltip: 'Shuffle',
          bg: scheme.secondaryContainer,
          fg: scheme.onSecondaryContainer,
          onTap: () => playArtist(context, ref, artist, shuffle: true),
        ),
        const SizedBox(width: 8),
        square(
          key: 'radio',
          icon: Icons.radio_rounded,
          tooltip: 'Artist radio',
          bg: scheme.tertiaryContainer,
          fg: scheme.onTertiaryContainer,
          onTap: () => startArtistRadio(context, ref, artist),
        ),
        const SizedBox(width: 8),
        square(
          key: 'download',
          icon: Icons.download_rounded,
          tooltip: 'Download all',
          bg: scheme.surfaceContainerHigh,
          fg: scheme.onSurfaceVariant,
          onTap: () async {
            final songs = await loadArtistSongs(context, ref, artist);
            if (songs == null || !context.mounted) return;
            await downloadSongs(context, ref, songs);
          },
        ),
      ],
    );
  }
}
