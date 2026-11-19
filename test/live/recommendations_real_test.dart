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
  final csvPath = Platform.environment['MELODIZE_REC_NAVIDROME_CSV'];
  final skip = dbPath == null && csvPath == null
      ? 'set MELODIZE_REC_DB (copy of melodize.db) or '
          'MELODIZE_REC_NAVIDROME_CSV (Navidrome play counts export)'
      : null;

  test('real history: today vs taste model', skip: skip, () async {
    final genreByArtist = <String, String>{};
    final plays = <String, int>{};
    final likes = <LikedTrack>[];
    final owned = <String>{};
    final history = <ListenEvent>[];
    var songCount = 0;
    void addSong(String artist, String title, String? genre, int playCount,
        bool starred) {
      songCount++;
      owned.add(keyFor(title, artist));
      if (genre != null && genre.isNotEmpty) {
        genreByArtist.putIfAbsent(artist, () => genre);
      }
      if (playCount > 0) plays[artist] = (plays[artist] ?? 0) + playCount;
      if (starred) likes.add(LikedTrack(artist: artist, title: title, genre: genre));
    }

    final String source;
    if (dbPath != null) {
      source = 'the app\'s play history';
      final db = AppDatabase.forTesting(NativeDatabase(File(dbPath)));
      addTearDown(db.close);
      for (final s in await db.getAllCachedSongs()) {
        addSong(s.artist, s.title, s.genre, s.playCount ?? 0, s.starred != null);
      }
      for (final h in await db.getRecentHistory(limit: 100000)) {
        history.add(ListenEvent(
            artist: h.artist,
            title: h.songTitle,
            at: h.playedAt,
            genre: genreByArtist[h.artist]));
      }
    } else {
      // Navidrome keeps a play count and the last play per song, not every
      // play, so each played song becomes one history entry at its last
      // play. CSV columns: artist,title,genre,play_count,play_date,starred
      // (tab-separated, play_date ISO 8601 or empty, starred 0/1).
      source = 'Navidrome play counts (last play per song)';
      final lines = File(csvPath!).readAsLinesSync().skip(1);
      for (final line in lines) {
        final c = line.split('\t');
        if (c.length < 6) continue;
        final count = int.tryParse(c[3]) ?? 0;
        addSong(c[0], c[1], c[2], count, c[5] == '1');
        final at = DateTime.tryParse(c[4]);
        if (at != null && count > 0) {
          history.add(ListenEvent(
              artist: c[0], title: c[1], at: at, genre: c[2].isEmpty ? null : c[2]));
        }
      }
    }
    final now = DateTime.now();
    if (history.isEmpty) {
      markTestSkipped('no play history to compare on');
      return;
    }

    // One radio per artist, shared by both algorithms so they pick from the
    // same pool.
    final deezer = DeezerClient();
    final radioCache = <String, Future<List<RecommendedTrack>>>{};
    final titleOf = {for (final h in history.reversed) h.artist: h.title};
    final radioErrors = <String, Object>{};
    final failures = <String>[];
    Future<List<RecommendedTrack>> radio(String artist) =>
        radioCache.putIfAbsent(artist, () async {
          try {
            final id = await deezer.searchBestArtist(
                artistName: artist,
                trackTitle: titleOf[artist],
                genreHint: genreByArtist[artist]);
            return id == null ? const [] : await deezer.artistRadio(id, limit: 20);
          } catch (e) {
            radioErrors[artist] = e;
            rethrow;
          }
        });
    TasteSignals signalsFor(List<ListenEvent> h) => TasteSignals(
          history: h,
          likes: likes,
          serverPlaysByArtist: plays,
          genreByArtist: genreByArtist,
          ownedTracks: owned,
        );

    // Today's provider skips a seed whose radio fails (and records why);
    // the failure still lands in the report's Errors section.
    Future<List<Rec>> today_(List<ListenEvent> h, math.Random rng) =>
        todayAlgorithm(h, owned, (a) async {
          try {
            return await radio(a);
          } catch (_) {
            return const <RecommendedTrack>[];
          }
        }, rng);
    Future<List<Rec>> model_(List<ListenEvent> h, DateTime at, math.Random rng) async {
      try {
        return await tasteAlgorithm(signalsFor(h), at, radio, rng);
      } on RecsFailure catch (e) {
        failures.add('Taste model: ${e.message}');
        return const [];
      }
    }

    final buf = StringBuffer('# Recommendations on your real history\n\n')
      ..writeln('Source: $source.\n')
      ..writeln('${history.length} plays, $songCount library songs, '
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
              ? await today_(train, rng)
              : await model_(train, cutoff, rng);
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
    final today = await today_(history, math.Random(42));
    final model = await model_(history, now, math.Random(42));
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

    if (failures.isNotEmpty || radioErrors.isNotEmpty) {
      buf.writeln('\n## Errors\n');
      for (final f in failures.toSet()) {
        buf.writeln('- $f');
      }
      radioErrors.forEach((a, e) => buf.writeln('- Deezer radio for $a: $e'));
    }
    // ignore: avoid_print
    print(buf);
    if (reportPath != null) File(reportPath).writeAsStringSync(buf.toString());
    expect(today.isNotEmpty || model.isNotEmpty, isTrue,
        reason: 'Deezer returned no radio for any seed');
  }, timeout: const Timeout(Duration(minutes: 5)));
}
