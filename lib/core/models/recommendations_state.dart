import '../recs/taste_model.dart' show TasteSeed;
import 'song.dart';

// States for the Home "Recommended for You" section.
sealed class RecommendationsState {
  const RecommendationsState();
}

class RecsLoading extends RecommendationsState {
  const RecsLoading();
}

class RecsReady extends RecommendationsState {
  final List<Song> songs;

  /// The seed artist that contributed most to each song, by [Song.id]:
  /// the card's "why" label.
  final Map<String, TasteSeed> reasons;

  /// Seed artists whose Deezer radio failed this time, so a partial list
  /// says so instead of looking complete.
  final List<String> failedSeeds;

  const RecsReady(this.songs,
      {this.reasons = const {}, this.failedSeeds = const []});
}

class RecsEmptyNoHistory extends RecommendationsState {
  const RecsEmptyNoHistory();
}

class RecsError extends RecommendationsState {
  final String reason;
  const RecsError(this.reason);
}
