import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:melodize/core/models/recommended_track.dart';
import 'package:melodize/core/recs/taste_model.dart';

RecommendedTrack _t(String artist, int i) => RecommendedTrack(
    deezerId: artist.hashCode * 100 + i,
    title: '$artist $i',
    artist: artist,
    album: 'A',
    durationSeconds: 200);

void main() {
  test('one dominant seed fills at most 30 % of the list', () {
    // Seen on a real library: one liked song made one artist's radio take
    // half the list.
    const strong = TasteSeed('Liked Artist', SeedReason.liked, 12);
    final weak = [
      for (var i = 0; i < 4; i++) TasteSeed('Other $i', SeedReason.topArtist, 1)
    ];
    final radios = {
      strong: [for (var a = 0; a < 20; a++) _t('S$a', 0)],
      for (final w in weak) w: [for (var a = 0; a < 10; a++) _t('${w.artist}-$a', 0)],
    };
    const profile = TasteProfile(
        affinity: {}, displayName: {}, genreShare: {},
        recentArtists: [], likedArtists: []);
    for (var seed = 0; seed < 20; seed++) {
      final picks = rankCandidates(
          radios, profile, const TasteSignals(), math.Random(seed));
      expect(picks, hasLength(30));
      expect(picks.where((p) => p.because == strong).length, lessThanOrEqualTo(9));
    }
  });

  test('the cap gives way when nothing else is left', () {
    const only = TasteSeed('Only', SeedReason.liked, 5);
    final picks = rankCandidates(
      {only: [for (var a = 0; a < 20; a++) _t('X$a', 0)]},
      const TasteProfile(affinity: {}, displayName: {}, genreShare: {},
          recentArtists: [], likedArtists: []),
      const TasteSignals(),
      math.Random(1),
    );
    expect(picks, hasLength(20));
  });

  test('hidden songs and artists and owned tracks are never picked', () {
    const s = TasteSeed('Seed', SeedReason.topArtist, 1);
    final picks = rankCandidates(
      {s: [_t('Hidden', 0), _t('Fine', 0), _t('Owned', 0), _t('Gone', 0)]},
      const TasteProfile(affinity: {}, displayName: {}, genreShare: {},
          recentArtists: [], likedArtists: []),
      const TasteSignals(
        dismissedArtists: {'Hidden'},
        dismissedTracks: {'gone 0|gone'},
        ownedTracks: {'owned 0|owned'},
      ),
      math.Random(1),
    );
    expect(picks.map((p) => p.track.artist), ['Fine']);
  });

  test('songFamily folds edits of the same song together', () {
    expect(songFamily('?К0N3Ц.. - Slowed'), songFamily('?К0N3Ц.. - Mega Slowed'));
    expect(songFamily('I Kissed A Girl'), songFamily('I Kissed A Girl (Slowed)'));
    expect(songFamily('Skins (Sped Up)'), songFamily('Skins (Slowed + Reverb)'));
    expect(songFamily('Rock Your Body'), isNot(songFamily('Rock Your Soul')));
    expect(songFamily('(Slowed)'), isNotEmpty);
  });

  test('two edits of one song never both make the list', () {
    const s = TasteSeed('Seed', SeedReason.topArtist, 1);
    final picks = rankCandidates(
      {
        s: const [
          RecommendedTrack(deezerId: 1, title: 'Skins (Sped Up)', artist: 'A',
              album: '', durationSeconds: 1),
          RecommendedTrack(deezerId: 2, title: 'Skins (Slowed + Reverb)',
              artist: 'B', album: '', durationSeconds: 1),
        ]
      },
      const TasteProfile(affinity: {}, displayName: {}, genreShare: {},
          recentArtists: [], likedArtists: []),
      const TasteSignals(),
      math.Random(1),
    );
    expect(picks, hasLength(1));
  });

  group('recommend() fails loudly', () {
    final now = DateTime(2026, 11, 19);
    final played = TasteSignals(history: [
      ListenEvent(artist: 'Kaito Ren', title: 'Tokyo Rain', at: now),
      ListenEvent(artist: 'Orbit Theory', title: 'Small Hours', at: now),
    ]);

    test('no history or likes: NoTasteYet', () async {
      await expectLater(
        recommend(
            signals: const TasteSignals(),
            now: now,
            radio: (_) async => [],
            rng: math.Random(1)),
        throwsA(isA<NoTasteYet>()),
      );
    });

    test('only skipped artists: NoTasteYet, not a list built on them',
        () async {
      await expectLater(
        recommend(
            signals: TasteSignals(history: [
              ListenEvent(artist: 'X', title: 'Y', at: now, skipped: true)
            ]),
            now: now,
            radio: (_) async => [_t('Z', 1)],
            rng: math.Random(1)),
        throwsA(isA<NoTasteYet>()),
      );
    });

    test('every radio failing: AllRadiosFailed with the cause', () async {
      try {
        await recommend(
            signals: played,
            now: now,
            radio: (_) async => throw Exception('HTTP 503'),
            rng: math.Random(1));
        fail('expected AllRadiosFailed');
      } on AllRadiosFailed catch (e) {
        expect(e.errors.keys, containsAll(['Kaito Ren', 'Orbit Theory']));
        expect(e.message, contains('HTTP 503'));
      }
    });

    test('one radio failing: a list, with the failure reported', () async {
      final r = await recommend(
          signals: played,
          now: now,
          radio: (seed) async => seed.artist == 'Kaito Ren'
              ? throw Exception('timeout')
              : [for (var i = 0; i < 5; i++) _t('New $i', i)],
          rng: math.Random(1));
      expect(r.tracks, isNotEmpty);
      expect(r.failedSeeds.keys, ['Kaito Ren']);
    });

    test('Deezer has nothing: NoRadioTracks naming the artists', () async {
      await expectLater(
        recommend(
            signals: played, now: now, radio: (_) async => [], rng: math.Random(1)),
        throwsA(isA<NoRadioTracks>()
            .having((e) => e.message, 'message', contains('Kaito Ren'))),
      );
    });

    test('everything owned: NothingNew', () async {
      await expectLater(
        recommend(
            signals: TasteSignals(
                history: played.history, ownedTracks: {'z 1|z'}),
            now: now,
            radio: (_) async => [_t('Z', 1)],
            rng: math.Random(1)),
        throwsA(isA<NothingNew>()),
      );
    });

    test('a broken weight is rejected up front', () {
      expect(
          () => TasteProfile.build(played,
              now: now, w: const TasteWeights(like: double.nan)),
          throwsArgumentError);
      expect(
          () => TasteProfile.build(played,
              now: now, w: const TasteWeights(halfLifeDays: 0)),
          throwsArgumentError);
    });
  });
}
