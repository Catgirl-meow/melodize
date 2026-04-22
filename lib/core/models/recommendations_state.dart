import 'song.dart';

/// Explicit states for the Home "Recommended for You" section so the UI can
/// surface a concrete reason instead of silently rendering an empty list.
///
/// The previous pipeline returned `List<Song>` and silently swallowed every
/// failure mode (no history, Deezer down, server down) into an empty list.
/// Users reported the section "just stopped working" after a while with no
/// way to tell what was wrong. Surfacing the state explicitly lets Home show
/// a hint when the user has no history yet and a retry affordance when a
/// transient failure prevents any recommendations from being built.
sealed class RecommendationsState {
  const RecommendationsState();
}

/// Provider is fetching / rebuilding. Show a skeleton or spinner.
class RecsLoading extends RecommendationsState {
  const RecsLoading();
}

/// At least one seed produced candidates and the final list is non-empty.
class RecsReady extends RecommendationsState {
  final List<Song> songs;
  /// How many of the seed fan-outs threw — zero means the happy path.
  /// Surfaced mainly for diagnostics; UI does not need to render anything
  /// different as long as [songs] is non-empty.
  final int failedSeeds;
  const RecsReady(this.songs, {this.failedSeeds = 0});
}

/// User hasn't played anything yet; no seeds available. UI shows a hint.
class RecsEmptyNoHistory extends RecommendationsState {
  const RecsEmptyNoHistory();
}

/// All pipeline attempts failed or returned nothing usable after filtering.
/// [reason] is a short human-readable string suitable for inline display.
class RecsError extends RecommendationsState {
  final String reason;
  const RecsError(this.reason);
}
