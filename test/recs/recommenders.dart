// The two algorithms under comparison, written against a radio function so
// the same code runs on the simulated world and on real Deezer.
import 'dart:math' as math;

import 'package:melodize/core/models/recommended_track.dart';
import 'package:melodize/core/recs/taste_model.dart';
import 'package:melodize/core/utils/title_normalize.dart';

typedef Radio = Future<List<RecommendedTrack>> Function(String artist);

/// A recommendation with the reason it would show on its card (null for
/// today's algorithm, which has none).
typedef Rec = ({RecommendedTrack track, String? reason});

/// Today's recommendationsProvider, step for step: 6 distinct artists from
/// the last 30 plays (shuffled), 20 radio tracks each, owned tracks
/// dropped, max 2 per artist, 30 tracks. It knows nothing about skips,
/// likes or hides.
Future<List<Rec>> todayAlgorithm(
  List<ListenEvent> history,
  Set<String> owned,
  Radio radio,
  math.Random rng,
) async {
  final recent = [...history]..sort((a, b) => b.at.compareTo(a.at));
  final byArtist = <String, ListenEvent>{};
  for (final h in recent.take(30)) {
    byArtist.putIfAbsent(h.artist, () => h);
  }
  // With no history the app shows "play a few songs" instead.
  if (byArtist.isEmpty) return const [];
  final seeds = byArtist.values.toList()..shuffle(rng);
  final byId = <int, RecommendedTrack>{};
  for (final seed in seeds.take(6)) {
    for (final t in await radio(seed.artist)) {
      byId.putIfAbsent(t.deezerId, () => t);
    }
  }
  final discoveries = byId.values
      .where((t) => !owned.contains(keyFor(t.title, t.artist)))
      .toList();
  final buckets = <String, List<RecommendedTrack>>{};
  for (final t in discoveries) {
    buckets.putIfAbsent(normalize(t.artist), () => []).add(t);
  }
  final shuffled = buckets.values
      .map((b) => (b.toList()..shuffle(rng)).take(2).toList())
      .toList()
    ..shuffle(rng);
  final out = <Rec>[];
  for (var round = 0; out.length < 30; round++) {
    var any = false;
    for (final b in shuffled) {
      if (round < b.length) {
        out.add((track: b[round], reason: null));
        any = true;
        if (out.length >= 30) break;
      }
    }
    if (!any) break;
  }
  return out;
}

/// The taste model: affinity → seeds → radios → ranked picks.
Future<List<Rec>> tasteAlgorithm(
  TasteSignals signals,
  DateTime now,
  Radio radio,
  math.Random rng, {
  TasteWeights weights = const TasteWeights(),
}) async {
  final profile = TasteProfile.build(signals, now: now, w: weights);
  final seeds = pickSeeds(profile, rng);
  final radios = {for (final seed in seeds) seed: await radio(seed.artist)};
  return [
    for (final t in rankCandidates(radios, profile, signals, rng, w: weights))
      (track: t.track, reason: reasonLabel(t.because)),
  ];
}
