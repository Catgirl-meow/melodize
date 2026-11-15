import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:melodize/core/errors/app_errors.dart';
import 'package:melodize/core/library/local_search.dart';
import 'package:melodize/core/models/song.dart';

Song _song(
  String id,
  String title, {
  String artist = 'Artist',
  String album = 'Album',
  String? albumId = 'al-1',
  String? artistId = 'ar-1',
  int? track,
  bool downloaded = false,
}) =>
    Song(
      id: id,
      title: title,
      artist: artist,
      album: album,
      albumId: albumId,
      artistId: artistId,
      track: track,
      coverArt: 'mf-$id',
      duration: 100,
      isDownloaded: downloaded,
    );

void main() {
  group('searchCachedLibrary', () {
    final songs = [
      _song('1', 'Diamonds',
          artist: 'Rihanna',
          album: 'Unapologetic',
          albumId: 'al-u',
          artistId: 'ar-r'),
      _song('2', 'MONTAGEM TRAVADA (Super Slowed)',
          artist: 'LVGHTER',
          album: 'Single',
          albumId: 'al-m',
          artistId: 'ar-l',
          downloaded: true),
      _song('3', 'Café del Mar',
          artist: 'Energy 52',
          album: 'Classics',
          albumId: 'al-c',
          artistId: 'ar-e'),
      _song('4', 'Diamond Heart',
          artist: 'Lady Gaga',
          album: 'Joanne',
          albumId: 'al-j',
          artistId: 'ar-g',
          downloaded: true),
    ];

    test('matches title prefix case-insensitively, downloaded first', () {
      final r = searchCachedLibrary(songs, 'dia');
      expect(r.fromCache, isTrue);
      expect(r.songs.map((s) => s.id), ['4', '1']);
    });

    test('every word must match somewhere in title, artist or album', () {
      expect(searchCachedLibrary(songs, 'slowed lvghter').songs.single.id, '2');
      expect(searchCachedLibrary(songs, 'diamonds gaga').songs, isEmpty);
    });

    test('keeps bracketed words and ignores accents and punctuation', () {
      expect(searchCachedLibrary(songs, 'super slowed').songs.single.id, '2');
      expect(searchCachedLibrary(songs, 'cafe').songs.single.id, '3');
      expect(searchCachedLibrary(songs, 'CAFÉ, DEL').songs.single.id, '3');
    });

    test('derives albums and artists from cached songs', () {
      final r = searchCachedLibrary(songs, 'rihanna');
      expect(r.artists.single.name, 'Rihanna');
      expect(r.artists.single.albumCount, 1);
      expect(r.albums.single.name, 'Unapologetic');
    });

    test('blank query returns an empty cached result', () {
      final r = searchCachedLibrary(songs, '  ');
      expect(r.isEmpty, isTrue);
      expect(r.fromCache, isTrue);
    });
  });

  group('cached library views', () {
    final songs = [
      _song('a2', 'Second', albumId: 'al-x', track: 2),
      _song('a1', 'First', albumId: 'al-x', track: 1),
      _song('b1', 'Other', album: 'B-Side', albumId: 'al-y', track: 1),
      _song('c1', 'Elsewhere',
          artist: 'Someone', albumId: 'al-z', artistId: 'ar-2'),
      _song('n1', 'No ids', albumId: null, artistId: null),
    ];

    test('albumsFromSongs groups by album id and counts songs', () {
      final albums = albumsFromSongs(songs);
      expect(albums.map((a) => a.id).toSet(), {'al-x', 'al-y', 'al-z'});
      final x = albums.firstWhere((a) => a.id == 'al-x');
      expect(x.songCount, 2);
      expect(x.duration, 200);
      expect(x.coverArt, isNotNull);
    });

    test('artistsFromSongs counts distinct albums', () {
      final artists = artistsFromSongs(songs);
      expect(artists.firstWhere((a) => a.id == 'ar-1').albumCount, 2);
      expect(artists.firstWhere((a) => a.id == 'ar-2').albumCount, 1);
    });

    test('cachedAlbumSongs is in track order', () {
      expect(cachedAlbumSongs(songs, 'al-x').map((s) => s.id), ['a1', 'a2']);
    });

    test('cachedArtistSongs groups by album then track', () {
      expect(cachedArtistSongs(songs, 'ar-1').map((s) => s.id),
          ['a1', 'a2', 'b1']);
    });
  });

  group('isConnectionError', () {
    final req = RequestOptions(path: '/rest/search3');

    test('connection failures and timeouts count', () {
      expect(
          isConnectionError(DioException(
              requestOptions: req, type: DioExceptionType.connectionError)),
          isTrue);
      expect(
          isConnectionError(DioException(
              requestOptions: req, type: DioExceptionType.receiveTimeout)),
          isTrue);
      expect(
          isConnectionError(DioException(
              requestOptions: req,
              type: DioExceptionType.unknown,
              error: const SocketException('Failed host lookup'))),
          isTrue);
      expect(isConnectionError(const DeviceOfflineException()), isTrue);
    });

    test('answers from the server do not count', () {
      expect(
          isConnectionError(DioException(
              requestOptions: req,
              type: DioExceptionType.badResponse,
              response: Response(requestOptions: req, statusCode: 500))),
          isFalse);
      expect(isConnectionError(const FormatException('not subsonic')), isFalse);
    });

    test('offline error reads as a sentence', () {
      expect(describeError(const DeviceOfflineException()),
          'No internet connection');
    });
  });
}
