import '../models/song.dart';
import 'smart_shuffle_engine.dart';

// ---------------------------------------------------------------------------
// Transition plan — describes how the macro layer orders songs and how each
// adjacent pair transitions.  Produced by the energy-curve planner and
// consumed by TransitionMixManager for micro-level mix prefetching.
// ---------------------------------------------------------------------------

/// The type of audio transition to use between two songs.
enum MixType {
  /// Time-stretched, equal-power crossfade mix from the companion.
  timeStretched,
  /// Standard volume crossfade (Dart-side linear volume ramp).
  volumeCrossfade,
  /// No crossfade — gapless playback.
  none,
}

/// A complete plan for one playback session: the ordered song list plus
/// metadata about how each pair transitions.
class TransitionPlan {
  /// Songs in playback order.
  final List<Song> orderedSongs;

  /// How each adjacent pair transitions.
  /// `mixTypes[i]` describes the transition from `orderedSongs[i]` →
  /// `orderedSongs[i+1]`.  Length is `orderedSongs.length - 1` (or 0).
  final List<MixType> mixTypes;

  /// Optimal mix window duration in seconds for each transition (if known
  /// from analysis), or null to use a default window.
  final List<double?> mixWindows;

  /// Human-readable label for the strategy used.
  final String strategy;

  /// Data quality score 0.0–1.0 (fraction of songs with usable metadata).
  final double coverage;

  const TransitionPlan({
    required this.orderedSongs,
    required this.mixTypes,
    required this.mixWindows,
    required this.strategy,
    required this.coverage,
  });

  /// An empty plan (single song or empty list).
  factory TransitionPlan.empty() => const TransitionPlan(
        orderedSongs: [],
        mixTypes: [],
        mixWindows: [],
        strategy: 'empty',
        coverage: 0.0,
      );

  /// Build a plan that uses volume crossfade for every transition
  /// (fallback when companion data is unavailable).
  factory TransitionPlan.volumeOnly(List<Song> songs) {
    final mixTypes = songs.length > 1
        ? List.filled(songs.length - 1, MixType.volumeCrossfade)
        : <MixType>[];
    return TransitionPlan(
      orderedSongs: List.from(songs),
      mixTypes: mixTypes,
      mixWindows: List.filled(mixTypes.length, null),
      strategy: 'volume_crossfade',
      coverage: 0.0,
    );
  }

  /// Determine the mix type for a pair based on available data.
  ///
  /// Returns [MixType.timeStretched] only when BPM data exists for both
  /// songs and the BPM ratio is ≤ 1.15 (the threshold for acceptable
  /// time-stretching quality).
  static MixType mixTypeFor(
    Song a,
    Song b,
    BpmCache cache,
  ) {
    final bpmA = cache.bpmFor(a);
    final bpmB = cache.bpmFor(b);
    if (bpmA == null || bpmB == null) return MixType.volumeCrossfade;
    final ratio = bpmA > bpmB ? bpmA / bpmB : bpmB / bpmA;
    if (ratio > 1.15) return MixType.volumeCrossfade;
    return MixType.timeStretched;
  }
}
