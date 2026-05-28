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
  final int failedSeeds;
  const RecsReady(this.songs, {this.failedSeeds = 0});
}

class RecsEmptyNoHistory extends RecommendationsState {
  const RecsEmptyNoHistory();
}

class RecsError extends RecommendationsState {
  final String reason;
  const RecsError(this.reason);
}
