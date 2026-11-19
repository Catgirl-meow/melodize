// Compares today's recommendations with the taste model on a real listening
// history and real Deezer radios. Skipped unless MELODIZE_REC_DB is set.
//
//   cp ~/.local/share/com.catgirl.melodize/melodize.db /tmp/rec-eval.db
//   MELODIZE_REC_DB=/tmp/rec-eval.db MELODIZE_REC_REPORT=/tmp/rec-real.md \
//     flutter test test/live/recommendations_real_test.dart
//
// Always point it at a COPY: opening the database may migrate it.
//
// Two checks:
//  1. Hold-out: history older than 14 days is the input; artists first played
//     in the last 14 days are what the user went on to discover. Counts how
//     often each algorithm recommends one of them.
//  2. Side by side: both lists from the full history, for a human to judge.
import 'dart:io';
import 'dart:math' as math;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:melodize/core/api/deezer_client.dart';
import 'package:melodize/core/db/database.dart';
import 'package:melodize/core/models/recommended_track.dart';
import 'package:melodize/core/recs/taste_model.dart';
import 'package:melodize/core/utils/title_normalize.dart';

import '../recs/recommenders.dart';

void main() {
  final dbPath = Platform.environment['MELODIZE_REC_DB'];
  final reportPath = Platform.environment['MELODIZE_REC_REPORT'];
  final skip = dbPath == null ? 'set MELODIZE_REC_DB to a copy of melodize.db' : null;

  test('real history: today vs taste model', skip: skip, () async {
    final db = AppDatabase.forTesting(NativeDatabase(File(dbPath!)));
    addTearDown(db.close);
    final rows = await db.getRecentHistory(limit: 100000);
    final songs = await db.getAllCachedSongs();
    final genreByArtist = <String, String>{};
    final plays = <String, int>{};
    final likes = <LikedTrack>[];
    final owned = <String>{};
    for (final s in songs) {
      owned.add(keyFor(s.title, s.artist));
      if (s.genre != null && s.genre!.isNotEmpty) {
        genreByArtist.putIfAbsent(s.artist, () => s.genre!);
      }
      if ((s.playCount ?? 0) > 0) {
        plays[s.artist] = (plays[s.artist] ?? 0) + s.playCount!;
      }
      if (s.starred != null) {
        likes.add(LikedTrack(artist: s.artist, title: s.title, genre: s.genre));
      }
    }
    final history = [
      for (final h in rows)
        ListenEvent(
          artist: h.artist,
          title: h.songTitle,
          at: h.playedAt,
          genre: genreByArtist[h.artist],
        ),
    ];
    final now = DateTime.now();
    if (history.isEmpty) {
      markTestSkipped('$dbPath has no play history to compare on');
      return;
    }

    // One radio per artist, shared by both algorithms so they pick from the
    // same pool.
    final deezer = DeezerClient();
    final radioCache = <String, Future<List<RecommendedTrack>>>{};
    final titleOf = {for (final h in history.reversed) h.artist: h.title};
    Future<List<RecommendedTrack>> radio(String artist) =>
        radioCache.putIfAbsent(artist, () async {
          try {
            final id = await deezer.searchBestArtist(
                artistName: artist,
                trackTitle: titleOf[artist],
                genreHint: genreByArtist[artist]);
            return id == null ? const [] : await deezer.artistRadio(id, limit: 20);
          } catch (e) {
            // ignore: avoid_print
            print('radio for $artist failed: $e');
            return const [];
          }
        });

    TasteSignals signalsFor(List<ListenEvent> h) => TasteSignals(
          history: h,
          likes: likes,
          serverPlaysByArtist: plays,
          genreByArtist: genreByArtist,
          ownedTracks: owned,
        );

    final buf = StringBuffer('# Recommendations on your real history\n\n')
      ..writeln('${history.length} plays, ${songs.length} library songs, '
          '${likes.length} liked, ${plays.length} artists with server play '
          'counts.\n');

    // 1. Hold-out.
    final cutoff = now.subtract(const Duration(days: 14));
    final train = history.where((e) => e.at.isBefore(cutoff)).toList();
    final trainArtists = {for (final e in train) normalize(e.artist)};
    final discovered = {
      for (final e in history.where((e) => !e.at.isBefore(cutoff)))
        if (!trainArtists.contains(normalize(e.artist))) normalize(e.artist)
    };
    buf.writeln('## Hold-out: did it predict what you discovered next?\n');
    if (train.length < 20 || discovered.length < 3) {
      buf.writeln('Not enough history for this check (${train.length} plays '
          'before the last 14 days, ${discovered.length} artists first played '
          'since).\n');
    } else {
      buf
        ..writeln('Input: ${train.length} plays older than 14 days. '
            'Target: ${discovered.length} artists you first played since.\n')
        ..writeln('| Algorithm | Refreshes that hit a discovered artist | '
            'Discovered artists found (5 refreshes) | Distinct artists per list |')
        ..writeln('|---|---|---|---|');
      for (final name in ['Today', 'Taste model']) {
        var hitRefreshes = 0;
        final found = <String>{};
        var distinct = 0;
        for (var i = 0; i < 5; i++) {
          final rng = math.Random(i + 1);
          final recs = name == 'Today'
              ? await todayAlgorithm(train, owned, radio, rng)
              : await tasteAlgorithm(signalsFor(train), cutoff, radio, rng);
          final artists = {for (final r in recs) normalize(r.track.artist)};
          final hits = artists.intersection(discovered);
          if (hits.isNotEmpty) hitRefreshes++;
          found.addAll(hits);
          distinct += artists.length;
        }
        buf.writeln('| $name | $hitRefreshes of 5 | ${found.length} | '
            '${(distinct / 5).toStringAsFixed(1)} |');
      }
      buf.writeln();
    }

    // 2. Side by side on the full history.
    final today = await todayAlgorithm(history, owned, radio, math.Random(42));
    final model =
        await tasteAlgorithm(signalsFor(history), now, radio, math.Random(42));
    final profile = TasteProfile.build(signalsFor(history), now: now);
    final top = profile.affinity.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    buf
      ..writeln('## Your top artists by affinity\n')
      ..writeln(top
          .take(10)
          .map((e) =>
              '${profile.displayName[e.key]} (${e.value.toStringAsFixed(1)})')
          .join(', '))
      ..writeln()
      ..writeln('## Side by side (full history, one refresh)\n')
      ..writeln('| # | Today | Taste model | Why (taste model) |')
      ..writeln('|---|---|---|---|');
    for (var i = 0; i < math.max(today.length, model.length); i++) {
      String cell(List<Rec> l) => i < l.length
          ? '${l[i].track.artist} – ${l[i].track.title}'.replaceAll('|', '/')
          : '';
      buf.writeln('| ${i + 1} | ${cell(today)} | ${cell(model)} | '
          '${i < model.length ? model[i].reason ?? '' : ''} |');
    }

    // ignore: avoid_print
    print(buf);
    if (reportPath != null) File(reportPath).writeAsStringSync(buf.toString());
    expect(today.isNotEmpty || model.isNotEmpty, isTrue,
        reason: 'Deezer returned no radio for any seed');
  }, timeout: const Timeout(Duration(minutes: 5)));
}
