// Scores recommendation quality against simulated listeners with a known
// true taste (see sim_world.dart), comparing today's algorithm with the
// taste model over several rounds of feedback.
//
// Run:   flutter test test/recs/recommendation_quality_test.dart
// Report: MELODIZE_REC_REPORT=/path/report.md flutter test test/recs/...
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:melodize/core/models/recommended_track.dart';
import 'package:melodize/core/recs/taste_model.dart';
import 'package:melodize/core/utils/title_normalize.dart';

import 'recommenders.dart';
import 'sim_world.dart';

typedef Recommender = Future<List<RecommendedTrack>> Function(
    SimWorld w, SimState s, math.Random rng, int call);

Future<List<RecommendedTrack>> baseline(
    SimWorld w, SimState s, math.Random rng, int call) async {
  final recs = await todayAlgorithm(
      s.history, s.owned, (a) async => w.radio(a, call), rng);
  return recs.map((r) => r.track).toList();
}

Recommender tasteModel([TasteWeights weights = const TasteWeights()]) =>
    (w, s, rng, call) async {
      final recs = await tasteAlgorithm(
          s.signals(), s.now, (a) async => w.radio(a, call), rng,
          weights: weights);
      return recs.map((r) => r.track).toList();
    };

class RoundMetrics {
  double meanPref = 0; // average true taste of the recommended artists
  double hitRate = 0; // share the listener would enjoy (pref > 0.3)
  double missRate = 0; // share they dislike (pref < -0.3)
  double dismissedLeak = 0; // tracks from artists/songs they hid
  double distinctArtists = 0;
  double overlapWithLast = 0; // Jaccard with the previous refresh
  double newArtistShare = 0; // artists never played before
  double count = 0;
}

/// One run: [rounds] refreshes; after each, the listener reacts to what
/// was shown and the app's signals update.
Future<List<RoundMetrics>> simulate(
  Persona p,
  SimWorld w,
  Recommender rec,
  int runSeed, {
  int rounds = 6,
}) async {
  final rng = math.Random(runSeed);
  final s = SimState();
  p.seedHistory(p, w, s, math.Random(runSeed * 31 + 1));
  final out = <RoundMetrics>[];
  Set<String>? last;
  for (var r = 0; r < rounds; r++) {
    final known = {for (final e in s.history) e.artist};
    final recs = await rec(w, s, rng, runSeed * 100 + r);
    final m = RoundMetrics()..count = recs.length.toDouble();
    if (recs.isEmpty) {
      out.add(m);
      continue;
    }
    final keys = {for (final t in recs) keyFor(t.title, t.artist)};
    var prefSum = 0.0, hits = 0, misses = 0, leaks = 0, fresh = 0;
    for (final t in recs) {
      final a = w.byName[t.artist]!;
      final pr = p.pref(a);
      prefSum += pr;
      if (pr > 0.3) hits++;
      if (pr < -0.3) misses++;
      if (s.dismissedArtists.contains(a.name) ||
          s.dismissedTracks.contains(keyFor(t.title, t.artist))) {
        leaks++;
      }
      if (!known.contains(a.name)) fresh++;
    }
    m
      ..meanPref = prefSum / recs.length
      ..hitRate = hits / recs.length
      ..missRate = misses / recs.length
      ..dismissedLeak = leaks.toDouble()
      ..distinctArtists = {for (final t in recs) t.artist}.length.toDouble()
      ..newArtistShare = fresh / recs.length
      ..overlapWithLast = last == null
          ? double.nan
          : keys.intersection(last).length / keys.union(last).length;
    last = keys;
    out.add(m);

    // The listener reacts: plays some, skips what they dislike, likes the
    // best, hides the worst. Unplayed cards count as an impression.
    final day = s.now.add(Duration(days: r));
    for (final t in recs) {
      final a = w.byName[t.artist]!;
      final pr = p.pref(a);
      final key = keyFor(t.title, t.artist);
      final plays = rng.nextDouble() < 0.25 + 0.3 * pr.clamp(0, 1);
      if (plays) {
        final skipped = rng.nextDouble() < skipChance(pr);
        s.play(a, t.title, day, skipped);
        if (!skipped && pr > 0.6 && rng.nextDouble() < 0.35) {
          s.likes.add(LikedTrack(artist: a.name, title: t.title, genre: a.genreName));
        }
      } else {
        s.impressions[key] = (s.impressions[key] ?? 0) + 1;
      }
      if (pr < -0.4 && rng.nextDouble() < 0.4) {
        s.dismissedTracks.add(key);
        final n = (s.dismissalsByArtist[a.name] ?? 0) + 1;
        s.dismissalsByArtist[a.name] = n;
        if (n >= 2 && rng.nextDouble() < 0.5) s.dismissedArtists.add(a.name);
      }
    }
  }
  return out;
}

/// Averages [runs] simulations per round.
Future<List<RoundMetrics>> averaged(Persona p, SimWorld w, Recommender rec,
    {int runs = 20, int rounds = 6}) async {
  final all = [
    for (var i = 0; i < runs; i++) await simulate(p, w, rec, i + 1, rounds: rounds)
  ];
  return [
    for (var r = 0; r < rounds; r++)
      () {
        final m = RoundMetrics();
        final ms = all.map((run) => run[r]).toList();
        double avg(double Function(RoundMetrics) f) {
          final vals = ms.map(f).where((v) => !v.isNaN).toList();
          return vals.isEmpty ? double.nan : vals.reduce((a, b) => a + b) / vals.length;
        }

        return m
          ..meanPref = avg((x) => x.meanPref)
          ..hitRate = avg((x) => x.hitRate)
          ..missRate = avg((x) => x.missRate)
          ..dismissedLeak = avg((x) => x.dismissedLeak)
          ..distinctArtists = avg((x) => x.distinctArtists)
          ..overlapWithLast = avg((x) => x.overlapWithLast)
          ..newArtistShare = avg((x) => x.newArtistShare)
          ..count = avg((x) => x.count);
      }(),
  ];
}

void main() {
  final world = SimWorld();
  final recommenders = <String, Recommender>{
    'Today': baseline,
    'Taste model, no skip data': tasteModel(const TasteWeights(useSkips: false)),
    'Taste model': tasteModel(),
    'Taste model, Discovery at max':
        tasteModel(const TasteWeights(discovery: 2)),
  };
  final results = <String, Map<String, List<RoundMetrics>>>{};

  String pct(double v) => v.isNaN ? '–' : '${(v * 100).round()} %';
  String num2(double v) => v.isNaN ? '–' : v.toStringAsFixed(2);

  setUpAll(() async {
    for (final p in personas()) {
      results[p.name] = {
        for (final e in recommenders.entries)
          e.key: await averaged(p, world, e.value)
      };
    }
    final buf = StringBuffer()
      ..writeln('# Recommendation quality (simulated listeners)')
      ..writeln()
      ..writeln('20 runs per listener, 6 refreshes each; the listener plays, '
          'skips, likes and hides after every refresh. "Taste" is the '
          'listener\'s hidden preference for the recommended artists, from '
          '−1 to +1.')
      ..writeln();
    for (final p in personas()) {
      buf
        ..writeln('## ${p.name}')
        ..writeln()
        ..writeln(p.description)
        ..writeln()
        ..writeln('| Algorithm | Taste, 1st | Taste, 6th | Hits, 1st → 6th | '
            'Misses, 1st → 6th | Hidden shown again | Artists | New artists | '
            'Same as last refresh |')
        ..writeln('|---|---|---|---|---|---|---|---|---|');
      for (final e in results[p.name]!.entries) {
        final first = e.value.first, lastR = e.value.last;
        final leaks = e.value.map((m) => m.dismissedLeak).reduce((a, b) => a + b);
        final overlap = e.value.skip(1).map((m) => m.overlapWithLast).toList();
        buf.writeln('| ${e.key} | ${num2(first.meanPref)} | ${num2(lastR.meanPref)} | '
            '${pct(first.hitRate)} → ${pct(lastR.hitRate)} | '
            '${pct(first.missRate)} → ${pct(lastR.missRate)} | '
            '${num2(leaks)} | ${first.distinctArtists.toStringAsFixed(0)} | '
            '${pct(first.newArtistShare)} | '
            '${pct(overlap.reduce((a, b) => a + b) / overlap.length)} |');
      }
      buf.writeln();
    }
    // ignore: avoid_print
    print(buf);
    final path = Platform.environment['MELODIZE_REC_REPORT'];
    if (path != null) File(path).writeAsStringSync(buf.toString());
  });

  for (final p in personas()) {
    group(p.name, () {
      List<RoundMetrics> today() => results[p.name]!['Today']!;
      List<RoundMetrics> model() => results[p.name]!['Taste model']!;

      test('fits the listener\'s taste better than today\'s algorithm', () {
        expect(model().first.meanPref, greaterThan(today().first.meanPref));
        expect(model().last.meanPref, greaterThan(today().last.meanPref));
      });

      test('recommends fewer disliked artists than today', () {
        expect(model().last.missRate, lessThanOrEqualTo(today().last.missRate));
      });

      test('never shows a hidden song or artist again', () {
        for (final m in model()) {
          expect(m.dismissedLeak, 0);
        }
      });

      test('keeps the list varied: 15+ artists, refreshes change', () {
        expect(model().first.count, 30);
        expect(model().first.distinctArtists, greaterThanOrEqualTo(15));
        for (final m in model().skip(1)) {
          expect(m.overlapWithLast, lessThan(0.6));
        }
      });

      test('still introduces new artists', () {
        // Accuracy and discovery pull against each other; the default keeps
        // at least a fifth of the list from artists never played.
        expect(model().first.newArtistShare, greaterThan(0.2));
        final adventurous = results[p.name]!['Taste model, Discovery at max']!;
        expect(adventurous.first.newArtistShare,
            greaterThan(model().first.newArtistShare));
      });
    });
  }
}
