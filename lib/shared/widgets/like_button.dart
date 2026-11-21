import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/errors/app_errors.dart';
import '../../core/models/song.dart';
import '../../core/providers.dart';
import '../utils/download_polling_mixin.dart';
import '../utils/snack.dart';
import '../theme/motion.dart';

/// Likes or unlikes a library song (a Navidrome star). Failures are reported
/// by [LikesNotifier] as an error snackbar.
Future<void> toggleLibraryLike(WidgetRef ref, Song song) =>
    ref.read(likesProvider.notifier).toggle(song);

/// The heart toggle. On a library song it stars/unstars on the server; on a
/// Deezer recommendation, liking also adds the track to the server library
/// (through the companion) and the like is applied once it arrives.
class LikeButton extends ConsumerStatefulWidget {
  final Song song;

  /// Tint for the unliked outline and icon (e.g. Now Playing's cover
  /// accent); the liked state always uses the tonal container.
  final Color? color;

  const LikeButton({super.key, required this.song, this.color});

  @override
  ConsumerState<LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends ConsumerState<LikeButton>
    with DownloadPollingMixin {
  Future<void> _toggle(bool liked) async {
    final song = widget.song;
    if (!song.isExternal) return toggleLibraryLike(ref, song);
    await toggleRecommendationLike(this, song, liked: liked);
  }

  @override
  Widget build(BuildContext context) {
    final liked = ref.watch(isLikedProvider(widget.song.id));
    final scheme = Theme.of(context).colorScheme;
    final fg = widget.color ?? scheme.onSurfaceVariant;
    return Tooltip(
      message: liked ? 'Unlike' : 'Like',
      child: IconButton(
        isSelected: liked,
        onPressed: () => _toggle(liked),
        style: IconButton.styleFrom(
          backgroundColor:
              liked ? scheme.secondaryContainer : Colors.transparent,
          foregroundColor: liked ? scheme.onSecondaryContainer : fg,
          side: liked
              ? BorderSide.none
              : BorderSide(color: fg.withValues(alpha: 0.4)),
        ),
        icon: const Icon(Icons.favorite_border_rounded),
        selectedIcon: TweenAnimationBuilder<double>(
          // A quick spring when the heart fills.
          key: ValueKey('liked-${widget.song.id}'),
          tween: Tween(begin: 0.6, end: 1),
          duration: Motion.spring.duration,
          curve: Motion.spring.curve,
          builder: (_, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: const Icon(Icons.favorite_rounded),
        ),
      ),
    );
  }
}

/// Likes or unlikes the Deezer track [song] from a widget that can run a
/// companion download ([host]). Liking saves the like right away and starts
/// adding the track to the server library; without a companion the like is
/// kept under Library → Liked until it can be added.
Future<void> toggleRecommendationLike<T extends ConsumerStatefulWidget>(
  DownloadPollingMixin<T> host,
  Song song, {
  required bool liked,
}) async {
  final ref = host.ref;
  final likes = ref.read(likesProvider.notifier);
  final deezerId = deezerIdOf(song);
  if (deezerId == null) {
    throw ArgumentError.value(song.id, 'song', 'is not a Deezer track');
  }
  try {
    if (liked) {
      await likes.unlikeRecommendation(deezerId);
      return;
    }
    await likes.likeRecommendation(song);
  } catch (e) {
    AppErrors.report(
        liked ? "Couldn't unlike \"${song.title}\"" : "Couldn't like \"${song.title}\"",
        e);
    return;
  }
  if (!host.mounted) return;
  if (ref.read(companionClientProvider) == null) {
    showStyledSnack(host.context,
        'Liked. Set up the companion in Settings to add it to your library.');
    return;
  }
  await host.addDeezerTrackToServer(deezerId);
}
