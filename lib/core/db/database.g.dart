// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $CachedSongsTable extends CachedSongs
    with TableInfo<$CachedSongsTable, CachedSong> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedSongsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _artistMeta = const VerificationMeta('artist');
  @override
  late final GeneratedColumn<String> artist = GeneratedColumn<String>(
      'artist', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _albumMeta = const VerificationMeta('album');
  @override
  late final GeneratedColumn<String> album = GeneratedColumn<String>(
      'album', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _albumIdMeta =
      const VerificationMeta('albumId');
  @override
  late final GeneratedColumn<String> albumId = GeneratedColumn<String>(
      'album_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _artistIdMeta =
      const VerificationMeta('artistId');
  @override
  late final GeneratedColumn<String> artistId = GeneratedColumn<String>(
      'artist_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _durationMeta =
      const VerificationMeta('duration');
  @override
  late final GeneratedColumn<int> duration = GeneratedColumn<int>(
      'duration', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<int> year = GeneratedColumn<int>(
      'year', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _genreMeta = const VerificationMeta('genre');
  @override
  late final GeneratedColumn<String> genre = GeneratedColumn<String>(
      'genre', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _trackMeta = const VerificationMeta('track');
  @override
  late final GeneratedColumn<int> track = GeneratedColumn<int>(
      'track', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _coverArtMeta =
      const VerificationMeta('coverArt');
  @override
  late final GeneratedColumn<String> coverArt = GeneratedColumn<String>(
      'cover_art', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _suffixMeta = const VerificationMeta('suffix');
  @override
  late final GeneratedColumn<String> suffix = GeneratedColumn<String>(
      'suffix', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _contentTypeMeta =
      const VerificationMeta('contentType');
  @override
  late final GeneratedColumn<String> contentType = GeneratedColumn<String>(
      'content_type', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _bitRateMeta =
      const VerificationMeta('bitRate');
  @override
  late final GeneratedColumn<int> bitRate = GeneratedColumn<int>(
      'bit_rate', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _sizeMeta = const VerificationMeta('size');
  @override
  late final GeneratedColumn<int> size = GeneratedColumn<int>(
      'size', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _isDownloadedMeta =
      const VerificationMeta('isDownloaded');
  @override
  late final GeneratedColumn<bool> isDownloaded = GeneratedColumn<bool>(
      'is_downloaded', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_downloaded" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _localPathMeta =
      const VerificationMeta('localPath');
  @override
  late final GeneratedColumn<String> localPath = GeneratedColumn<String>(
      'local_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdMeta =
      const VerificationMeta('created');
  @override
  late final GeneratedColumn<DateTime> created = GeneratedColumn<DateTime>(
      'created', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _starredMeta =
      const VerificationMeta('starred');
  @override
  late final GeneratedColumn<DateTime> starred = GeneratedColumn<DateTime>(
      'starred', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _playCountMeta =
      const VerificationMeta('playCount');
  @override
  late final GeneratedColumn<int> playCount = GeneratedColumn<int>(
      'play_count', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _cachedAtMeta =
      const VerificationMeta('cachedAt');
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
      'cached_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        title,
        artist,
        album,
        albumId,
        artistId,
        duration,
        year,
        genre,
        track,
        coverArt,
        suffix,
        contentType,
        bitRate,
        size,
        isDownloaded,
        localPath,
        created,
        starred,
        playCount,
        cachedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_songs';
  @override
  VerificationContext validateIntegrity(Insertable<CachedSong> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('artist')) {
      context.handle(_artistMeta,
          artist.isAcceptableOrUnknown(data['artist']!, _artistMeta));
    } else if (isInserting) {
      context.missing(_artistMeta);
    }
    if (data.containsKey('album')) {
      context.handle(
          _albumMeta, album.isAcceptableOrUnknown(data['album']!, _albumMeta));
    } else if (isInserting) {
      context.missing(_albumMeta);
    }
    if (data.containsKey('album_id')) {
      context.handle(_albumIdMeta,
          albumId.isAcceptableOrUnknown(data['album_id']!, _albumIdMeta));
    }
    if (data.containsKey('artist_id')) {
      context.handle(_artistIdMeta,
          artistId.isAcceptableOrUnknown(data['artist_id']!, _artistIdMeta));
    }
    if (data.containsKey('duration')) {
      context.handle(_durationMeta,
          duration.isAcceptableOrUnknown(data['duration']!, _durationMeta));
    }
    if (data.containsKey('year')) {
      context.handle(
          _yearMeta, year.isAcceptableOrUnknown(data['year']!, _yearMeta));
    }
    if (data.containsKey('genre')) {
      context.handle(
          _genreMeta, genre.isAcceptableOrUnknown(data['genre']!, _genreMeta));
    }
    if (data.containsKey('track')) {
      context.handle(
          _trackMeta, track.isAcceptableOrUnknown(data['track']!, _trackMeta));
    }
    if (data.containsKey('cover_art')) {
      context.handle(_coverArtMeta,
          coverArt.isAcceptableOrUnknown(data['cover_art']!, _coverArtMeta));
    }
    if (data.containsKey('suffix')) {
      context.handle(_suffixMeta,
          suffix.isAcceptableOrUnknown(data['suffix']!, _suffixMeta));
    }
    if (data.containsKey('content_type')) {
      context.handle(
          _contentTypeMeta,
          contentType.isAcceptableOrUnknown(
              data['content_type']!, _contentTypeMeta));
    }
    if (data.containsKey('bit_rate')) {
      context.handle(_bitRateMeta,
          bitRate.isAcceptableOrUnknown(data['bit_rate']!, _bitRateMeta));
    }
    if (data.containsKey('size')) {
      context.handle(
          _sizeMeta, size.isAcceptableOrUnknown(data['size']!, _sizeMeta));
    }
    if (data.containsKey('is_downloaded')) {
      context.handle(
          _isDownloadedMeta,
          isDownloaded.isAcceptableOrUnknown(
              data['is_downloaded']!, _isDownloadedMeta));
    }
    if (data.containsKey('local_path')) {
      context.handle(_localPathMeta,
          localPath.isAcceptableOrUnknown(data['local_path']!, _localPathMeta));
    }
    if (data.containsKey('created')) {
      context.handle(_createdMeta,
          created.isAcceptableOrUnknown(data['created']!, _createdMeta));
    }
    if (data.containsKey('starred')) {
      context.handle(_starredMeta,
          starred.isAcceptableOrUnknown(data['starred']!, _starredMeta));
    }
    if (data.containsKey('play_count')) {
      context.handle(_playCountMeta,
          playCount.isAcceptableOrUnknown(data['play_count']!, _playCountMeta));
    }
    if (data.containsKey('cached_at')) {
      context.handle(_cachedAtMeta,
          cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedSong map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedSong(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      artist: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}artist'])!,
      album: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}album'])!,
      albumId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}album_id']),
      artistId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}artist_id']),
      duration: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}duration']),
      year: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}year']),
      genre: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}genre']),
      track: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}track']),
      coverArt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}cover_art']),
      suffix: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}suffix']),
      contentType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}content_type']),
      bitRate: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}bit_rate']),
      size: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}size']),
      isDownloaded: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_downloaded'])!,
      localPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}local_path']),
      created: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created']),
      starred: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}starred']),
      playCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}play_count']),
      cachedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}cached_at'])!,
    );
  }

  @override
  $CachedSongsTable createAlias(String alias) {
    return $CachedSongsTable(attachedDatabase, alias);
  }
}

class CachedSong extends DataClass implements Insertable<CachedSong> {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String? albumId;
  final String? artistId;
  final int? duration;
  final int? year;
  final String? genre;
  final int? track;
  final String? coverArt;
  final String? suffix;
  final String? contentType;
  final int? bitRate;
  final int? size;
  final bool isDownloaded;
  final String? localPath;
  final DateTime? created;
  final DateTime? starred;
  final int? playCount;
  final DateTime cachedAt;
  const CachedSong(
      {required this.id,
      required this.title,
      required this.artist,
      required this.album,
      this.albumId,
      this.artistId,
      this.duration,
      this.year,
      this.genre,
      this.track,
      this.coverArt,
      this.suffix,
      this.contentType,
      this.bitRate,
      this.size,
      required this.isDownloaded,
      this.localPath,
      this.created,
      this.starred,
      this.playCount,
      required this.cachedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['artist'] = Variable<String>(artist);
    map['album'] = Variable<String>(album);
    if (!nullToAbsent || albumId != null) {
      map['album_id'] = Variable<String>(albumId);
    }
    if (!nullToAbsent || artistId != null) {
      map['artist_id'] = Variable<String>(artistId);
    }
    if (!nullToAbsent || duration != null) {
      map['duration'] = Variable<int>(duration);
    }
    if (!nullToAbsent || year != null) {
      map['year'] = Variable<int>(year);
    }
    if (!nullToAbsent || genre != null) {
      map['genre'] = Variable<String>(genre);
    }
    if (!nullToAbsent || track != null) {
      map['track'] = Variable<int>(track);
    }
    if (!nullToAbsent || coverArt != null) {
      map['cover_art'] = Variable<String>(coverArt);
    }
    if (!nullToAbsent || suffix != null) {
      map['suffix'] = Variable<String>(suffix);
    }
    if (!nullToAbsent || contentType != null) {
      map['content_type'] = Variable<String>(contentType);
    }
    if (!nullToAbsent || bitRate != null) {
      map['bit_rate'] = Variable<int>(bitRate);
    }
    if (!nullToAbsent || size != null) {
      map['size'] = Variable<int>(size);
    }
    map['is_downloaded'] = Variable<bool>(isDownloaded);
    if (!nullToAbsent || localPath != null) {
      map['local_path'] = Variable<String>(localPath);
    }
    if (!nullToAbsent || created != null) {
      map['created'] = Variable<DateTime>(created);
    }
    if (!nullToAbsent || starred != null) {
      map['starred'] = Variable<DateTime>(starred);
    }
    if (!nullToAbsent || playCount != null) {
      map['play_count'] = Variable<int>(playCount);
    }
    map['cached_at'] = Variable<DateTime>(cachedAt);
    return map;
  }

  CachedSongsCompanion toCompanion(bool nullToAbsent) {
    return CachedSongsCompanion(
      id: Value(id),
      title: Value(title),
      artist: Value(artist),
      album: Value(album),
      albumId: albumId == null && nullToAbsent
          ? const Value.absent()
          : Value(albumId),
      artistId: artistId == null && nullToAbsent
          ? const Value.absent()
          : Value(artistId),
      duration: duration == null && nullToAbsent
          ? const Value.absent()
          : Value(duration),
      year: year == null && nullToAbsent ? const Value.absent() : Value(year),
      genre:
          genre == null && nullToAbsent ? const Value.absent() : Value(genre),
      track:
          track == null && nullToAbsent ? const Value.absent() : Value(track),
      coverArt: coverArt == null && nullToAbsent
          ? const Value.absent()
          : Value(coverArt),
      suffix:
          suffix == null && nullToAbsent ? const Value.absent() : Value(suffix),
      contentType: contentType == null && nullToAbsent
          ? const Value.absent()
          : Value(contentType),
      bitRate: bitRate == null && nullToAbsent
          ? const Value.absent()
          : Value(bitRate),
      size: size == null && nullToAbsent ? const Value.absent() : Value(size),
      isDownloaded: Value(isDownloaded),
      localPath: localPath == null && nullToAbsent
          ? const Value.absent()
          : Value(localPath),
      created: created == null && nullToAbsent
          ? const Value.absent()
          : Value(created),
      starred: starred == null && nullToAbsent
          ? const Value.absent()
          : Value(starred),
      playCount: playCount == null && nullToAbsent
          ? const Value.absent()
          : Value(playCount),
      cachedAt: Value(cachedAt),
    );
  }

  factory CachedSong.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedSong(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      artist: serializer.fromJson<String>(json['artist']),
      album: serializer.fromJson<String>(json['album']),
      albumId: serializer.fromJson<String?>(json['albumId']),
      artistId: serializer.fromJson<String?>(json['artistId']),
      duration: serializer.fromJson<int?>(json['duration']),
      year: serializer.fromJson<int?>(json['year']),
      genre: serializer.fromJson<String?>(json['genre']),
      track: serializer.fromJson<int?>(json['track']),
      coverArt: serializer.fromJson<String?>(json['coverArt']),
      suffix: serializer.fromJson<String?>(json['suffix']),
      contentType: serializer.fromJson<String?>(json['contentType']),
      bitRate: serializer.fromJson<int?>(json['bitRate']),
      size: serializer.fromJson<int?>(json['size']),
      isDownloaded: serializer.fromJson<bool>(json['isDownloaded']),
      localPath: serializer.fromJson<String?>(json['localPath']),
      created: serializer.fromJson<DateTime?>(json['created']),
      starred: serializer.fromJson<DateTime?>(json['starred']),
      playCount: serializer.fromJson<int?>(json['playCount']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'artist': serializer.toJson<String>(artist),
      'album': serializer.toJson<String>(album),
      'albumId': serializer.toJson<String?>(albumId),
      'artistId': serializer.toJson<String?>(artistId),
      'duration': serializer.toJson<int?>(duration),
      'year': serializer.toJson<int?>(year),
      'genre': serializer.toJson<String?>(genre),
      'track': serializer.toJson<int?>(track),
      'coverArt': serializer.toJson<String?>(coverArt),
      'suffix': serializer.toJson<String?>(suffix),
      'contentType': serializer.toJson<String?>(contentType),
      'bitRate': serializer.toJson<int?>(bitRate),
      'size': serializer.toJson<int?>(size),
      'isDownloaded': serializer.toJson<bool>(isDownloaded),
      'localPath': serializer.toJson<String?>(localPath),
      'created': serializer.toJson<DateTime?>(created),
      'starred': serializer.toJson<DateTime?>(starred),
      'playCount': serializer.toJson<int?>(playCount),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
    };
  }

  CachedSong copyWith(
          {String? id,
          String? title,
          String? artist,
          String? album,
          Value<String?> albumId = const Value.absent(),
          Value<String?> artistId = const Value.absent(),
          Value<int?> duration = const Value.absent(),
          Value<int?> year = const Value.absent(),
          Value<String?> genre = const Value.absent(),
          Value<int?> track = const Value.absent(),
          Value<String?> coverArt = const Value.absent(),
          Value<String?> suffix = const Value.absent(),
          Value<String?> contentType = const Value.absent(),
          Value<int?> bitRate = const Value.absent(),
          Value<int?> size = const Value.absent(),
          bool? isDownloaded,
          Value<String?> localPath = const Value.absent(),
          Value<DateTime?> created = const Value.absent(),
          Value<DateTime?> starred = const Value.absent(),
          Value<int?> playCount = const Value.absent(),
          DateTime? cachedAt}) =>
      CachedSong(
        id: id ?? this.id,
        title: title ?? this.title,
        artist: artist ?? this.artist,
        album: album ?? this.album,
        albumId: albumId.present ? albumId.value : this.albumId,
        artistId: artistId.present ? artistId.value : this.artistId,
        duration: duration.present ? duration.value : this.duration,
        year: year.present ? year.value : this.year,
        genre: genre.present ? genre.value : this.genre,
        track: track.present ? track.value : this.track,
        coverArt: coverArt.present ? coverArt.value : this.coverArt,
        suffix: suffix.present ? suffix.value : this.suffix,
        contentType: contentType.present ? contentType.value : this.contentType,
        bitRate: bitRate.present ? bitRate.value : this.bitRate,
        size: size.present ? size.value : this.size,
        isDownloaded: isDownloaded ?? this.isDownloaded,
        localPath: localPath.present ? localPath.value : this.localPath,
        created: created.present ? created.value : this.created,
        starred: starred.present ? starred.value : this.starred,
        playCount: playCount.present ? playCount.value : this.playCount,
        cachedAt: cachedAt ?? this.cachedAt,
      );
  CachedSong copyWithCompanion(CachedSongsCompanion data) {
    return CachedSong(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      artist: data.artist.present ? data.artist.value : this.artist,
      album: data.album.present ? data.album.value : this.album,
      albumId: data.albumId.present ? data.albumId.value : this.albumId,
      artistId: data.artistId.present ? data.artistId.value : this.artistId,
      duration: data.duration.present ? data.duration.value : this.duration,
      year: data.year.present ? data.year.value : this.year,
      genre: data.genre.present ? data.genre.value : this.genre,
      track: data.track.present ? data.track.value : this.track,
      coverArt: data.coverArt.present ? data.coverArt.value : this.coverArt,
      suffix: data.suffix.present ? data.suffix.value : this.suffix,
      contentType:
          data.contentType.present ? data.contentType.value : this.contentType,
      bitRate: data.bitRate.present ? data.bitRate.value : this.bitRate,
      size: data.size.present ? data.size.value : this.size,
      isDownloaded: data.isDownloaded.present
          ? data.isDownloaded.value
          : this.isDownloaded,
      localPath: data.localPath.present ? data.localPath.value : this.localPath,
      created: data.created.present ? data.created.value : this.created,
      starred: data.starred.present ? data.starred.value : this.starred,
      playCount: data.playCount.present ? data.playCount.value : this.playCount,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedSong(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('artist: $artist, ')
          ..write('album: $album, ')
          ..write('albumId: $albumId, ')
          ..write('artistId: $artistId, ')
          ..write('duration: $duration, ')
          ..write('year: $year, ')
          ..write('genre: $genre, ')
          ..write('track: $track, ')
          ..write('coverArt: $coverArt, ')
          ..write('suffix: $suffix, ')
          ..write('contentType: $contentType, ')
          ..write('bitRate: $bitRate, ')
          ..write('size: $size, ')
          ..write('isDownloaded: $isDownloaded, ')
          ..write('localPath: $localPath, ')
          ..write('created: $created, ')
          ..write('starred: $starred, ')
          ..write('playCount: $playCount, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
        id,
        title,
        artist,
        album,
        albumId,
        artistId,
        duration,
        year,
        genre,
        track,
        coverArt,
        suffix,
        contentType,
        bitRate,
        size,
        isDownloaded,
        localPath,
        created,
        starred,
        playCount,
        cachedAt
      ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedSong &&
          other.id == this.id &&
          other.title == this.title &&
          other.artist == this.artist &&
          other.album == this.album &&
          other.albumId == this.albumId &&
          other.artistId == this.artistId &&
          other.duration == this.duration &&
          other.year == this.year &&
          other.genre == this.genre &&
          other.track == this.track &&
          other.coverArt == this.coverArt &&
          other.suffix == this.suffix &&
          other.contentType == this.contentType &&
          other.bitRate == this.bitRate &&
          other.size == this.size &&
          other.isDownloaded == this.isDownloaded &&
          other.localPath == this.localPath &&
          other.created == this.created &&
          other.starred == this.starred &&
          other.playCount == this.playCount &&
          other.cachedAt == this.cachedAt);
}

class CachedSongsCompanion extends UpdateCompanion<CachedSong> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> artist;
  final Value<String> album;
  final Value<String?> albumId;
  final Value<String?> artistId;
  final Value<int?> duration;
  final Value<int?> year;
  final Value<String?> genre;
  final Value<int?> track;
  final Value<String?> coverArt;
  final Value<String?> suffix;
  final Value<String?> contentType;
  final Value<int?> bitRate;
  final Value<int?> size;
  final Value<bool> isDownloaded;
  final Value<String?> localPath;
  final Value<DateTime?> created;
  final Value<DateTime?> starred;
  final Value<int?> playCount;
  final Value<DateTime> cachedAt;
  final Value<int> rowid;
  const CachedSongsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.artist = const Value.absent(),
    this.album = const Value.absent(),
    this.albumId = const Value.absent(),
    this.artistId = const Value.absent(),
    this.duration = const Value.absent(),
    this.year = const Value.absent(),
    this.genre = const Value.absent(),
    this.track = const Value.absent(),
    this.coverArt = const Value.absent(),
    this.suffix = const Value.absent(),
    this.contentType = const Value.absent(),
    this.bitRate = const Value.absent(),
    this.size = const Value.absent(),
    this.isDownloaded = const Value.absent(),
    this.localPath = const Value.absent(),
    this.created = const Value.absent(),
    this.starred = const Value.absent(),
    this.playCount = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedSongsCompanion.insert({
    required String id,
    required String title,
    required String artist,
    required String album,
    this.albumId = const Value.absent(),
    this.artistId = const Value.absent(),
    this.duration = const Value.absent(),
    this.year = const Value.absent(),
    this.genre = const Value.absent(),
    this.track = const Value.absent(),
    this.coverArt = const Value.absent(),
    this.suffix = const Value.absent(),
    this.contentType = const Value.absent(),
    this.bitRate = const Value.absent(),
    this.size = const Value.absent(),
    this.isDownloaded = const Value.absent(),
    this.localPath = const Value.absent(),
    this.created = const Value.absent(),
    this.starred = const Value.absent(),
    this.playCount = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        title = Value(title),
        artist = Value(artist),
        album = Value(album);
  static Insertable<CachedSong> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? artist,
    Expression<String>? album,
    Expression<String>? albumId,
    Expression<String>? artistId,
    Expression<int>? duration,
    Expression<int>? year,
    Expression<String>? genre,
    Expression<int>? track,
    Expression<String>? coverArt,
    Expression<String>? suffix,
    Expression<String>? contentType,
    Expression<int>? bitRate,
    Expression<int>? size,
    Expression<bool>? isDownloaded,
    Expression<String>? localPath,
    Expression<DateTime>? created,
    Expression<DateTime>? starred,
    Expression<int>? playCount,
    Expression<DateTime>? cachedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (artist != null) 'artist': artist,
      if (album != null) 'album': album,
      if (albumId != null) 'album_id': albumId,
      if (artistId != null) 'artist_id': artistId,
      if (duration != null) 'duration': duration,
      if (year != null) 'year': year,
      if (genre != null) 'genre': genre,
      if (track != null) 'track': track,
      if (coverArt != null) 'cover_art': coverArt,
      if (suffix != null) 'suffix': suffix,
      if (contentType != null) 'content_type': contentType,
      if (bitRate != null) 'bit_rate': bitRate,
      if (size != null) 'size': size,
      if (isDownloaded != null) 'is_downloaded': isDownloaded,
      if (localPath != null) 'local_path': localPath,
      if (created != null) 'created': created,
      if (starred != null) 'starred': starred,
      if (playCount != null) 'play_count': playCount,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedSongsCompanion copyWith(
      {Value<String>? id,
      Value<String>? title,
      Value<String>? artist,
      Value<String>? album,
      Value<String?>? albumId,
      Value<String?>? artistId,
      Value<int?>? duration,
      Value<int?>? year,
      Value<String?>? genre,
      Value<int?>? track,
      Value<String?>? coverArt,
      Value<String?>? suffix,
      Value<String?>? contentType,
      Value<int?>? bitRate,
      Value<int?>? size,
      Value<bool>? isDownloaded,
      Value<String?>? localPath,
      Value<DateTime?>? created,
      Value<DateTime?>? starred,
      Value<int?>? playCount,
      Value<DateTime>? cachedAt,
      Value<int>? rowid}) {
    return CachedSongsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      albumId: albumId ?? this.albumId,
      artistId: artistId ?? this.artistId,
      duration: duration ?? this.duration,
      year: year ?? this.year,
      genre: genre ?? this.genre,
      track: track ?? this.track,
      coverArt: coverArt ?? this.coverArt,
      suffix: suffix ?? this.suffix,
      contentType: contentType ?? this.contentType,
      bitRate: bitRate ?? this.bitRate,
      size: size ?? this.size,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      localPath: localPath ?? this.localPath,
      created: created ?? this.created,
      starred: starred ?? this.starred,
      playCount: playCount ?? this.playCount,
      cachedAt: cachedAt ?? this.cachedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (artist.present) {
      map['artist'] = Variable<String>(artist.value);
    }
    if (album.present) {
      map['album'] = Variable<String>(album.value);
    }
    if (albumId.present) {
      map['album_id'] = Variable<String>(albumId.value);
    }
    if (artistId.present) {
      map['artist_id'] = Variable<String>(artistId.value);
    }
    if (duration.present) {
      map['duration'] = Variable<int>(duration.value);
    }
    if (year.present) {
      map['year'] = Variable<int>(year.value);
    }
    if (genre.present) {
      map['genre'] = Variable<String>(genre.value);
    }
    if (track.present) {
      map['track'] = Variable<int>(track.value);
    }
    if (coverArt.present) {
      map['cover_art'] = Variable<String>(coverArt.value);
    }
    if (suffix.present) {
      map['suffix'] = Variable<String>(suffix.value);
    }
    if (contentType.present) {
      map['content_type'] = Variable<String>(contentType.value);
    }
    if (bitRate.present) {
      map['bit_rate'] = Variable<int>(bitRate.value);
    }
    if (size.present) {
      map['size'] = Variable<int>(size.value);
    }
    if (isDownloaded.present) {
      map['is_downloaded'] = Variable<bool>(isDownloaded.value);
    }
    if (localPath.present) {
      map['local_path'] = Variable<String>(localPath.value);
    }
    if (created.present) {
      map['created'] = Variable<DateTime>(created.value);
    }
    if (starred.present) {
      map['starred'] = Variable<DateTime>(starred.value);
    }
    if (playCount.present) {
      map['play_count'] = Variable<int>(playCount.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedSongsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('artist: $artist, ')
          ..write('album: $album, ')
          ..write('albumId: $albumId, ')
          ..write('artistId: $artistId, ')
          ..write('duration: $duration, ')
          ..write('year: $year, ')
          ..write('genre: $genre, ')
          ..write('track: $track, ')
          ..write('coverArt: $coverArt, ')
          ..write('suffix: $suffix, ')
          ..write('contentType: $contentType, ')
          ..write('bitRate: $bitRate, ')
          ..write('size: $size, ')
          ..write('isDownloaded: $isDownloaded, ')
          ..write('localPath: $localPath, ')
          ..write('created: $created, ')
          ..write('starred: $starred, ')
          ..write('playCount: $playCount, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlayHistoryTable extends PlayHistory
    with TableInfo<$PlayHistoryTable, PlayHistoryData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlayHistoryTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _historyIdMeta =
      const VerificationMeta('historyId');
  @override
  late final GeneratedColumn<int> historyId = GeneratedColumn<int>(
      'history_id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _songIdMeta = const VerificationMeta('songId');
  @override
  late final GeneratedColumn<String> songId = GeneratedColumn<String>(
      'song_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _songTitleMeta =
      const VerificationMeta('songTitle');
  @override
  late final GeneratedColumn<String> songTitle = GeneratedColumn<String>(
      'song_title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _artistMeta = const VerificationMeta('artist');
  @override
  late final GeneratedColumn<String> artist = GeneratedColumn<String>(
      'artist', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _coverArtMeta =
      const VerificationMeta('coverArt');
  @override
  late final GeneratedColumn<String> coverArt = GeneratedColumn<String>(
      'cover_art', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _playedAtMeta =
      const VerificationMeta('playedAt');
  @override
  late final GeneratedColumn<DateTime> playedAt = GeneratedColumn<DateTime>(
      'played_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _listenedMsMeta =
      const VerificationMeta('listenedMs');
  @override
  late final GeneratedColumn<int> listenedMs = GeneratedColumn<int>(
      'listened_ms', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _skippedMeta =
      const VerificationMeta('skipped');
  @override
  late final GeneratedColumn<bool> skipped = GeneratedColumn<bool>(
      'skipped', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("skipped" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns => [
        historyId,
        songId,
        songTitle,
        artist,
        coverArt,
        playedAt,
        listenedMs,
        skipped
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'play_history';
  @override
  VerificationContext validateIntegrity(Insertable<PlayHistoryData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('history_id')) {
      context.handle(_historyIdMeta,
          historyId.isAcceptableOrUnknown(data['history_id']!, _historyIdMeta));
    }
    if (data.containsKey('song_id')) {
      context.handle(_songIdMeta,
          songId.isAcceptableOrUnknown(data['song_id']!, _songIdMeta));
    } else if (isInserting) {
      context.missing(_songIdMeta);
    }
    if (data.containsKey('song_title')) {
      context.handle(_songTitleMeta,
          songTitle.isAcceptableOrUnknown(data['song_title']!, _songTitleMeta));
    } else if (isInserting) {
      context.missing(_songTitleMeta);
    }
    if (data.containsKey('artist')) {
      context.handle(_artistMeta,
          artist.isAcceptableOrUnknown(data['artist']!, _artistMeta));
    } else if (isInserting) {
      context.missing(_artistMeta);
    }
    if (data.containsKey('cover_art')) {
      context.handle(_coverArtMeta,
          coverArt.isAcceptableOrUnknown(data['cover_art']!, _coverArtMeta));
    }
    if (data.containsKey('played_at')) {
      context.handle(_playedAtMeta,
          playedAt.isAcceptableOrUnknown(data['played_at']!, _playedAtMeta));
    }
    if (data.containsKey('listened_ms')) {
      context.handle(
          _listenedMsMeta,
          listenedMs.isAcceptableOrUnknown(
              data['listened_ms']!, _listenedMsMeta));
    }
    if (data.containsKey('skipped')) {
      context.handle(_skippedMeta,
          skipped.isAcceptableOrUnknown(data['skipped']!, _skippedMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {historyId};
  @override
  PlayHistoryData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlayHistoryData(
      historyId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}history_id'])!,
      songId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}song_id'])!,
      songTitle: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}song_title'])!,
      artist: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}artist'])!,
      coverArt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}cover_art']),
      playedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}played_at'])!,
      listenedMs: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}listened_ms']),
      skipped: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}skipped'])!,
    );
  }

  @override
  $PlayHistoryTable createAlias(String alias) {
    return $PlayHistoryTable(attachedDatabase, alias);
  }
}

class PlayHistoryData extends DataClass implements Insertable<PlayHistoryData> {
  final int historyId;
  final String songId;
  final String songTitle;
  final String artist;
  final String? coverArt;
  final DateTime playedAt;
  final int? listenedMs;
  final bool skipped;
  const PlayHistoryData(
      {required this.historyId,
      required this.songId,
      required this.songTitle,
      required this.artist,
      this.coverArt,
      required this.playedAt,
      this.listenedMs,
      required this.skipped});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['history_id'] = Variable<int>(historyId);
    map['song_id'] = Variable<String>(songId);
    map['song_title'] = Variable<String>(songTitle);
    map['artist'] = Variable<String>(artist);
    if (!nullToAbsent || coverArt != null) {
      map['cover_art'] = Variable<String>(coverArt);
    }
    map['played_at'] = Variable<DateTime>(playedAt);
    if (!nullToAbsent || listenedMs != null) {
      map['listened_ms'] = Variable<int>(listenedMs);
    }
    map['skipped'] = Variable<bool>(skipped);
    return map;
  }

  PlayHistoryCompanion toCompanion(bool nullToAbsent) {
    return PlayHistoryCompanion(
      historyId: Value(historyId),
      songId: Value(songId),
      songTitle: Value(songTitle),
      artist: Value(artist),
      coverArt: coverArt == null && nullToAbsent
          ? const Value.absent()
          : Value(coverArt),
      playedAt: Value(playedAt),
      listenedMs: listenedMs == null && nullToAbsent
          ? const Value.absent()
          : Value(listenedMs),
      skipped: Value(skipped),
    );
  }

  factory PlayHistoryData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlayHistoryData(
      historyId: serializer.fromJson<int>(json['historyId']),
      songId: serializer.fromJson<String>(json['songId']),
      songTitle: serializer.fromJson<String>(json['songTitle']),
      artist: serializer.fromJson<String>(json['artist']),
      coverArt: serializer.fromJson<String?>(json['coverArt']),
      playedAt: serializer.fromJson<DateTime>(json['playedAt']),
      listenedMs: serializer.fromJson<int?>(json['listenedMs']),
      skipped: serializer.fromJson<bool>(json['skipped']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'historyId': serializer.toJson<int>(historyId),
      'songId': serializer.toJson<String>(songId),
      'songTitle': serializer.toJson<String>(songTitle),
      'artist': serializer.toJson<String>(artist),
      'coverArt': serializer.toJson<String?>(coverArt),
      'playedAt': serializer.toJson<DateTime>(playedAt),
      'listenedMs': serializer.toJson<int?>(listenedMs),
      'skipped': serializer.toJson<bool>(skipped),
    };
  }

  PlayHistoryData copyWith(
          {int? historyId,
          String? songId,
          String? songTitle,
          String? artist,
          Value<String?> coverArt = const Value.absent(),
          DateTime? playedAt,
          Value<int?> listenedMs = const Value.absent(),
          bool? skipped}) =>
      PlayHistoryData(
        historyId: historyId ?? this.historyId,
        songId: songId ?? this.songId,
        songTitle: songTitle ?? this.songTitle,
        artist: artist ?? this.artist,
        coverArt: coverArt.present ? coverArt.value : this.coverArt,
        playedAt: playedAt ?? this.playedAt,
        listenedMs: listenedMs.present ? listenedMs.value : this.listenedMs,
        skipped: skipped ?? this.skipped,
      );
  PlayHistoryData copyWithCompanion(PlayHistoryCompanion data) {
    return PlayHistoryData(
      historyId: data.historyId.present ? data.historyId.value : this.historyId,
      songId: data.songId.present ? data.songId.value : this.songId,
      songTitle: data.songTitle.present ? data.songTitle.value : this.songTitle,
      artist: data.artist.present ? data.artist.value : this.artist,
      coverArt: data.coverArt.present ? data.coverArt.value : this.coverArt,
      playedAt: data.playedAt.present ? data.playedAt.value : this.playedAt,
      listenedMs:
          data.listenedMs.present ? data.listenedMs.value : this.listenedMs,
      skipped: data.skipped.present ? data.skipped.value : this.skipped,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlayHistoryData(')
          ..write('historyId: $historyId, ')
          ..write('songId: $songId, ')
          ..write('songTitle: $songTitle, ')
          ..write('artist: $artist, ')
          ..write('coverArt: $coverArt, ')
          ..write('playedAt: $playedAt, ')
          ..write('listenedMs: $listenedMs, ')
          ..write('skipped: $skipped')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(historyId, songId, songTitle, artist,
      coverArt, playedAt, listenedMs, skipped);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlayHistoryData &&
          other.historyId == this.historyId &&
          other.songId == this.songId &&
          other.songTitle == this.songTitle &&
          other.artist == this.artist &&
          other.coverArt == this.coverArt &&
          other.playedAt == this.playedAt &&
          other.listenedMs == this.listenedMs &&
          other.skipped == this.skipped);
}

class PlayHistoryCompanion extends UpdateCompanion<PlayHistoryData> {
  final Value<int> historyId;
  final Value<String> songId;
  final Value<String> songTitle;
  final Value<String> artist;
  final Value<String?> coverArt;
  final Value<DateTime> playedAt;
  final Value<int?> listenedMs;
  final Value<bool> skipped;
  const PlayHistoryCompanion({
    this.historyId = const Value.absent(),
    this.songId = const Value.absent(),
    this.songTitle = const Value.absent(),
    this.artist = const Value.absent(),
    this.coverArt = const Value.absent(),
    this.playedAt = const Value.absent(),
    this.listenedMs = const Value.absent(),
    this.skipped = const Value.absent(),
  });
  PlayHistoryCompanion.insert({
    this.historyId = const Value.absent(),
    required String songId,
    required String songTitle,
    required String artist,
    this.coverArt = const Value.absent(),
    this.playedAt = const Value.absent(),
    this.listenedMs = const Value.absent(),
    this.skipped = const Value.absent(),
  })  : songId = Value(songId),
        songTitle = Value(songTitle),
        artist = Value(artist);
  static Insertable<PlayHistoryData> custom({
    Expression<int>? historyId,
    Expression<String>? songId,
    Expression<String>? songTitle,
    Expression<String>? artist,
    Expression<String>? coverArt,
    Expression<DateTime>? playedAt,
    Expression<int>? listenedMs,
    Expression<bool>? skipped,
  }) {
    return RawValuesInsertable({
      if (historyId != null) 'history_id': historyId,
      if (songId != null) 'song_id': songId,
      if (songTitle != null) 'song_title': songTitle,
      if (artist != null) 'artist': artist,
      if (coverArt != null) 'cover_art': coverArt,
      if (playedAt != null) 'played_at': playedAt,
      if (listenedMs != null) 'listened_ms': listenedMs,
      if (skipped != null) 'skipped': skipped,
    });
  }

  PlayHistoryCompanion copyWith(
      {Value<int>? historyId,
      Value<String>? songId,
      Value<String>? songTitle,
      Value<String>? artist,
      Value<String?>? coverArt,
      Value<DateTime>? playedAt,
      Value<int?>? listenedMs,
      Value<bool>? skipped}) {
    return PlayHistoryCompanion(
      historyId: historyId ?? this.historyId,
      songId: songId ?? this.songId,
      songTitle: songTitle ?? this.songTitle,
      artist: artist ?? this.artist,
      coverArt: coverArt ?? this.coverArt,
      playedAt: playedAt ?? this.playedAt,
      listenedMs: listenedMs ?? this.listenedMs,
      skipped: skipped ?? this.skipped,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (historyId.present) {
      map['history_id'] = Variable<int>(historyId.value);
    }
    if (songId.present) {
      map['song_id'] = Variable<String>(songId.value);
    }
    if (songTitle.present) {
      map['song_title'] = Variable<String>(songTitle.value);
    }
    if (artist.present) {
      map['artist'] = Variable<String>(artist.value);
    }
    if (coverArt.present) {
      map['cover_art'] = Variable<String>(coverArt.value);
    }
    if (playedAt.present) {
      map['played_at'] = Variable<DateTime>(playedAt.value);
    }
    if (listenedMs.present) {
      map['listened_ms'] = Variable<int>(listenedMs.value);
    }
    if (skipped.present) {
      map['skipped'] = Variable<bool>(skipped.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlayHistoryCompanion(')
          ..write('historyId: $historyId, ')
          ..write('songId: $songId, ')
          ..write('songTitle: $songTitle, ')
          ..write('artist: $artist, ')
          ..write('coverArt: $coverArt, ')
          ..write('playedAt: $playedAt, ')
          ..write('listenedMs: $listenedMs, ')
          ..write('skipped: $skipped')
          ..write(')'))
        .toString();
  }
}

class $ServerConfigTable extends ServerConfig
    with TableInfo<$ServerConfigTable, ServerConfigData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ServerConfigTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _configIdMeta =
      const VerificationMeta('configId');
  @override
  late final GeneratedColumn<int> configId = GeneratedColumn<int>(
      'config_id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _serverUrlMeta =
      const VerificationMeta('serverUrl');
  @override
  late final GeneratedColumn<String> serverUrl = GeneratedColumn<String>(
      'server_url', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _usernameMeta =
      const VerificationMeta('username');
  @override
  late final GeneratedColumn<String> username = GeneratedColumn<String>(
      'username', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _passwordMeta =
      const VerificationMeta('password');
  @override
  late final GeneratedColumn<String> password = GeneratedColumn<String>(
      'password', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _isActiveMeta =
      const VerificationMeta('isActive');
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
      'is_active', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_active" IN (0, 1))'),
      defaultValue: const Constant(true));
  @override
  List<GeneratedColumn> get $columns =>
      [configId, serverUrl, username, password, isActive];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'server_config';
  @override
  VerificationContext validateIntegrity(Insertable<ServerConfigData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('config_id')) {
      context.handle(_configIdMeta,
          configId.isAcceptableOrUnknown(data['config_id']!, _configIdMeta));
    }
    if (data.containsKey('server_url')) {
      context.handle(_serverUrlMeta,
          serverUrl.isAcceptableOrUnknown(data['server_url']!, _serverUrlMeta));
    } else if (isInserting) {
      context.missing(_serverUrlMeta);
    }
    if (data.containsKey('username')) {
      context.handle(_usernameMeta,
          username.isAcceptableOrUnknown(data['username']!, _usernameMeta));
    } else if (isInserting) {
      context.missing(_usernameMeta);
    }
    if (data.containsKey('password')) {
      context.handle(_passwordMeta,
          password.isAcceptableOrUnknown(data['password']!, _passwordMeta));
    } else if (isInserting) {
      context.missing(_passwordMeta);
    }
    if (data.containsKey('is_active')) {
      context.handle(_isActiveMeta,
          isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {configId};
  @override
  ServerConfigData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ServerConfigData(
      configId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}config_id'])!,
      serverUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}server_url'])!,
      username: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}username'])!,
      password: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}password'])!,
      isActive: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_active'])!,
    );
  }

  @override
  $ServerConfigTable createAlias(String alias) {
    return $ServerConfigTable(attachedDatabase, alias);
  }
}

class ServerConfigData extends DataClass
    implements Insertable<ServerConfigData> {
  final int configId;
  final String serverUrl;
  final String username;
  final String password;
  final bool isActive;
  const ServerConfigData(
      {required this.configId,
      required this.serverUrl,
      required this.username,
      required this.password,
      required this.isActive});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['config_id'] = Variable<int>(configId);
    map['server_url'] = Variable<String>(serverUrl);
    map['username'] = Variable<String>(username);
    map['password'] = Variable<String>(password);
    map['is_active'] = Variable<bool>(isActive);
    return map;
  }

  ServerConfigCompanion toCompanion(bool nullToAbsent) {
    return ServerConfigCompanion(
      configId: Value(configId),
      serverUrl: Value(serverUrl),
      username: Value(username),
      password: Value(password),
      isActive: Value(isActive),
    );
  }

  factory ServerConfigData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ServerConfigData(
      configId: serializer.fromJson<int>(json['configId']),
      serverUrl: serializer.fromJson<String>(json['serverUrl']),
      username: serializer.fromJson<String>(json['username']),
      password: serializer.fromJson<String>(json['password']),
      isActive: serializer.fromJson<bool>(json['isActive']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'configId': serializer.toJson<int>(configId),
      'serverUrl': serializer.toJson<String>(serverUrl),
      'username': serializer.toJson<String>(username),
      'password': serializer.toJson<String>(password),
      'isActive': serializer.toJson<bool>(isActive),
    };
  }

  ServerConfigData copyWith(
          {int? configId,
          String? serverUrl,
          String? username,
          String? password,
          bool? isActive}) =>
      ServerConfigData(
        configId: configId ?? this.configId,
        serverUrl: serverUrl ?? this.serverUrl,
        username: username ?? this.username,
        password: password ?? this.password,
        isActive: isActive ?? this.isActive,
      );
  ServerConfigData copyWithCompanion(ServerConfigCompanion data) {
    return ServerConfigData(
      configId: data.configId.present ? data.configId.value : this.configId,
      serverUrl: data.serverUrl.present ? data.serverUrl.value : this.serverUrl,
      username: data.username.present ? data.username.value : this.username,
      password: data.password.present ? data.password.value : this.password,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ServerConfigData(')
          ..write('configId: $configId, ')
          ..write('serverUrl: $serverUrl, ')
          ..write('username: $username, ')
          ..write('password: $password, ')
          ..write('isActive: $isActive')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(configId, serverUrl, username, password, isActive);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ServerConfigData &&
          other.configId == this.configId &&
          other.serverUrl == this.serverUrl &&
          other.username == this.username &&
          other.password == this.password &&
          other.isActive == this.isActive);
}

class ServerConfigCompanion extends UpdateCompanion<ServerConfigData> {
  final Value<int> configId;
  final Value<String> serverUrl;
  final Value<String> username;
  final Value<String> password;
  final Value<bool> isActive;
  const ServerConfigCompanion({
    this.configId = const Value.absent(),
    this.serverUrl = const Value.absent(),
    this.username = const Value.absent(),
    this.password = const Value.absent(),
    this.isActive = const Value.absent(),
  });
  ServerConfigCompanion.insert({
    this.configId = const Value.absent(),
    required String serverUrl,
    required String username,
    required String password,
    this.isActive = const Value.absent(),
  })  : serverUrl = Value(serverUrl),
        username = Value(username),
        password = Value(password);
  static Insertable<ServerConfigData> custom({
    Expression<int>? configId,
    Expression<String>? serverUrl,
    Expression<String>? username,
    Expression<String>? password,
    Expression<bool>? isActive,
  }) {
    return RawValuesInsertable({
      if (configId != null) 'config_id': configId,
      if (serverUrl != null) 'server_url': serverUrl,
      if (username != null) 'username': username,
      if (password != null) 'password': password,
      if (isActive != null) 'is_active': isActive,
    });
  }

  ServerConfigCompanion copyWith(
      {Value<int>? configId,
      Value<String>? serverUrl,
      Value<String>? username,
      Value<String>? password,
      Value<bool>? isActive}) {
    return ServerConfigCompanion(
      configId: configId ?? this.configId,
      serverUrl: serverUrl ?? this.serverUrl,
      username: username ?? this.username,
      password: password ?? this.password,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (configId.present) {
      map['config_id'] = Variable<int>(configId.value);
    }
    if (serverUrl.present) {
      map['server_url'] = Variable<String>(serverUrl.value);
    }
    if (username.present) {
      map['username'] = Variable<String>(username.value);
    }
    if (password.present) {
      map['password'] = Variable<String>(password.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ServerConfigCompanion(')
          ..write('configId: $configId, ')
          ..write('serverUrl: $serverUrl, ')
          ..write('username: $username, ')
          ..write('password: $password, ')
          ..write('isActive: $isActive')
          ..write(')'))
        .toString();
  }
}

class $DownloadQueueTable extends DownloadQueue
    with TableInfo<$DownloadQueueTable, DownloadQueueData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DownloadQueueTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _songIdMeta = const VerificationMeta('songId');
  @override
  late final GeneratedColumn<String> songId = GeneratedColumn<String>(
      'song_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _songTitleMeta =
      const VerificationMeta('songTitle');
  @override
  late final GeneratedColumn<String> songTitle = GeneratedColumn<String>(
      'song_title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _artistMeta = const VerificationMeta('artist');
  @override
  late final GeneratedColumn<String> artist = GeneratedColumn<String>(
      'artist', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _savePathMeta =
      const VerificationMeta('savePath');
  @override
  late final GeneratedColumn<String> savePath = GeneratedColumn<String>(
      'save_path', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('pending'));
  static const VerificationMeta _progressMeta =
      const VerificationMeta('progress');
  @override
  late final GeneratedColumn<int> progress = GeneratedColumn<int>(
      'progress', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _qualityMeta =
      const VerificationMeta('quality');
  @override
  late final GeneratedColumn<String> quality = GeneratedColumn<String>(
      'quality', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _errorMessageMeta =
      const VerificationMeta('errorMessage');
  @override
  late final GeneratedColumn<String> errorMessage = GeneratedColumn<String>(
      'error_message', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _addedAtMeta =
      const VerificationMeta('addedAt');
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
      'added_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        songId,
        songTitle,
        artist,
        savePath,
        status,
        progress,
        quality,
        errorMessage,
        addedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'download_queue';
  @override
  VerificationContext validateIntegrity(Insertable<DownloadQueueData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('song_id')) {
      context.handle(_songIdMeta,
          songId.isAcceptableOrUnknown(data['song_id']!, _songIdMeta));
    } else if (isInserting) {
      context.missing(_songIdMeta);
    }
    if (data.containsKey('song_title')) {
      context.handle(_songTitleMeta,
          songTitle.isAcceptableOrUnknown(data['song_title']!, _songTitleMeta));
    } else if (isInserting) {
      context.missing(_songTitleMeta);
    }
    if (data.containsKey('artist')) {
      context.handle(_artistMeta,
          artist.isAcceptableOrUnknown(data['artist']!, _artistMeta));
    } else if (isInserting) {
      context.missing(_artistMeta);
    }
    if (data.containsKey('save_path')) {
      context.handle(_savePathMeta,
          savePath.isAcceptableOrUnknown(data['save_path']!, _savePathMeta));
    } else if (isInserting) {
      context.missing(_savePathMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('progress')) {
      context.handle(_progressMeta,
          progress.isAcceptableOrUnknown(data['progress']!, _progressMeta));
    }
    if (data.containsKey('quality')) {
      context.handle(_qualityMeta,
          quality.isAcceptableOrUnknown(data['quality']!, _qualityMeta));
    }
    if (data.containsKey('error_message')) {
      context.handle(
          _errorMessageMeta,
          errorMessage.isAcceptableOrUnknown(
              data['error_message']!, _errorMessageMeta));
    }
    if (data.containsKey('added_at')) {
      context.handle(_addedAtMeta,
          addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {songId};
  @override
  DownloadQueueData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DownloadQueueData(
      songId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}song_id'])!,
      songTitle: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}song_title'])!,
      artist: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}artist'])!,
      savePath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}save_path'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      progress: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}progress'])!,
      quality: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}quality']),
      errorMessage: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}error_message']),
      addedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}added_at'])!,
    );
  }

  @override
  $DownloadQueueTable createAlias(String alias) {
    return $DownloadQueueTable(attachedDatabase, alias);
  }
}

class DownloadQueueData extends DataClass
    implements Insertable<DownloadQueueData> {
  final String songId;
  final String songTitle;
  final String artist;
  final String savePath;
  final String status;
  final int progress;
  final String? quality;
  final String? errorMessage;
  final DateTime addedAt;
  const DownloadQueueData(
      {required this.songId,
      required this.songTitle,
      required this.artist,
      required this.savePath,
      required this.status,
      required this.progress,
      this.quality,
      this.errorMessage,
      required this.addedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['song_id'] = Variable<String>(songId);
    map['song_title'] = Variable<String>(songTitle);
    map['artist'] = Variable<String>(artist);
    map['save_path'] = Variable<String>(savePath);
    map['status'] = Variable<String>(status);
    map['progress'] = Variable<int>(progress);
    if (!nullToAbsent || quality != null) {
      map['quality'] = Variable<String>(quality);
    }
    if (!nullToAbsent || errorMessage != null) {
      map['error_message'] = Variable<String>(errorMessage);
    }
    map['added_at'] = Variable<DateTime>(addedAt);
    return map;
  }

  DownloadQueueCompanion toCompanion(bool nullToAbsent) {
    return DownloadQueueCompanion(
      songId: Value(songId),
      songTitle: Value(songTitle),
      artist: Value(artist),
      savePath: Value(savePath),
      status: Value(status),
      progress: Value(progress),
      quality: quality == null && nullToAbsent
          ? const Value.absent()
          : Value(quality),
      errorMessage: errorMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(errorMessage),
      addedAt: Value(addedAt),
    );
  }

  factory DownloadQueueData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DownloadQueueData(
      songId: serializer.fromJson<String>(json['songId']),
      songTitle: serializer.fromJson<String>(json['songTitle']),
      artist: serializer.fromJson<String>(json['artist']),
      savePath: serializer.fromJson<String>(json['savePath']),
      status: serializer.fromJson<String>(json['status']),
      progress: serializer.fromJson<int>(json['progress']),
      quality: serializer.fromJson<String?>(json['quality']),
      errorMessage: serializer.fromJson<String?>(json['errorMessage']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'songId': serializer.toJson<String>(songId),
      'songTitle': serializer.toJson<String>(songTitle),
      'artist': serializer.toJson<String>(artist),
      'savePath': serializer.toJson<String>(savePath),
      'status': serializer.toJson<String>(status),
      'progress': serializer.toJson<int>(progress),
      'quality': serializer.toJson<String?>(quality),
      'errorMessage': serializer.toJson<String?>(errorMessage),
      'addedAt': serializer.toJson<DateTime>(addedAt),
    };
  }

  DownloadQueueData copyWith(
          {String? songId,
          String? songTitle,
          String? artist,
          String? savePath,
          String? status,
          int? progress,
          Value<String?> quality = const Value.absent(),
          Value<String?> errorMessage = const Value.absent(),
          DateTime? addedAt}) =>
      DownloadQueueData(
        songId: songId ?? this.songId,
        songTitle: songTitle ?? this.songTitle,
        artist: artist ?? this.artist,
        savePath: savePath ?? this.savePath,
        status: status ?? this.status,
        progress: progress ?? this.progress,
        quality: quality.present ? quality.value : this.quality,
        errorMessage:
            errorMessage.present ? errorMessage.value : this.errorMessage,
        addedAt: addedAt ?? this.addedAt,
      );
  DownloadQueueData copyWithCompanion(DownloadQueueCompanion data) {
    return DownloadQueueData(
      songId: data.songId.present ? data.songId.value : this.songId,
      songTitle: data.songTitle.present ? data.songTitle.value : this.songTitle,
      artist: data.artist.present ? data.artist.value : this.artist,
      savePath: data.savePath.present ? data.savePath.value : this.savePath,
      status: data.status.present ? data.status.value : this.status,
      progress: data.progress.present ? data.progress.value : this.progress,
      quality: data.quality.present ? data.quality.value : this.quality,
      errorMessage: data.errorMessage.present
          ? data.errorMessage.value
          : this.errorMessage,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DownloadQueueData(')
          ..write('songId: $songId, ')
          ..write('songTitle: $songTitle, ')
          ..write('artist: $artist, ')
          ..write('savePath: $savePath, ')
          ..write('status: $status, ')
          ..write('progress: $progress, ')
          ..write('quality: $quality, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(songId, songTitle, artist, savePath, status,
      progress, quality, errorMessage, addedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DownloadQueueData &&
          other.songId == this.songId &&
          other.songTitle == this.songTitle &&
          other.artist == this.artist &&
          other.savePath == this.savePath &&
          other.status == this.status &&
          other.progress == this.progress &&
          other.quality == this.quality &&
          other.errorMessage == this.errorMessage &&
          other.addedAt == this.addedAt);
}

class DownloadQueueCompanion extends UpdateCompanion<DownloadQueueData> {
  final Value<String> songId;
  final Value<String> songTitle;
  final Value<String> artist;
  final Value<String> savePath;
  final Value<String> status;
  final Value<int> progress;
  final Value<String?> quality;
  final Value<String?> errorMessage;
  final Value<DateTime> addedAt;
  final Value<int> rowid;
  const DownloadQueueCompanion({
    this.songId = const Value.absent(),
    this.songTitle = const Value.absent(),
    this.artist = const Value.absent(),
    this.savePath = const Value.absent(),
    this.status = const Value.absent(),
    this.progress = const Value.absent(),
    this.quality = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DownloadQueueCompanion.insert({
    required String songId,
    required String songTitle,
    required String artist,
    required String savePath,
    this.status = const Value.absent(),
    this.progress = const Value.absent(),
    this.quality = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : songId = Value(songId),
        songTitle = Value(songTitle),
        artist = Value(artist),
        savePath = Value(savePath);
  static Insertable<DownloadQueueData> custom({
    Expression<String>? songId,
    Expression<String>? songTitle,
    Expression<String>? artist,
    Expression<String>? savePath,
    Expression<String>? status,
    Expression<int>? progress,
    Expression<String>? quality,
    Expression<String>? errorMessage,
    Expression<DateTime>? addedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (songId != null) 'song_id': songId,
      if (songTitle != null) 'song_title': songTitle,
      if (artist != null) 'artist': artist,
      if (savePath != null) 'save_path': savePath,
      if (status != null) 'status': status,
      if (progress != null) 'progress': progress,
      if (quality != null) 'quality': quality,
      if (errorMessage != null) 'error_message': errorMessage,
      if (addedAt != null) 'added_at': addedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DownloadQueueCompanion copyWith(
      {Value<String>? songId,
      Value<String>? songTitle,
      Value<String>? artist,
      Value<String>? savePath,
      Value<String>? status,
      Value<int>? progress,
      Value<String?>? quality,
      Value<String?>? errorMessage,
      Value<DateTime>? addedAt,
      Value<int>? rowid}) {
    return DownloadQueueCompanion(
      songId: songId ?? this.songId,
      songTitle: songTitle ?? this.songTitle,
      artist: artist ?? this.artist,
      savePath: savePath ?? this.savePath,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      quality: quality ?? this.quality,
      errorMessage: errorMessage ?? this.errorMessage,
      addedAt: addedAt ?? this.addedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (songId.present) {
      map['song_id'] = Variable<String>(songId.value);
    }
    if (songTitle.present) {
      map['song_title'] = Variable<String>(songTitle.value);
    }
    if (artist.present) {
      map['artist'] = Variable<String>(artist.value);
    }
    if (savePath.present) {
      map['save_path'] = Variable<String>(savePath.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (progress.present) {
      map['progress'] = Variable<int>(progress.value);
    }
    if (quality.present) {
      map['quality'] = Variable<String>(quality.value);
    }
    if (errorMessage.present) {
      map['error_message'] = Variable<String>(errorMessage.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DownloadQueueCompanion(')
          ..write('songId: $songId, ')
          ..write('songTitle: $songTitle, ')
          ..write('artist: $artist, ')
          ..write('savePath: $savePath, ')
          ..write('status: $status, ')
          ..write('progress: $progress, ')
          ..write('quality: $quality, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('addedAt: $addedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LyricsCacheTable extends LyricsCache
    with TableInfo<$LyricsCacheTable, LyricsCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LyricsCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _songIdMeta = const VerificationMeta('songId');
  @override
  late final GeneratedColumn<String> songId = GeneratedColumn<String>(
      'song_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _plainLyricsMeta =
      const VerificationMeta('plainLyrics');
  @override
  late final GeneratedColumn<String> plainLyrics = GeneratedColumn<String>(
      'plain_lyrics', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _syncedLyricsMeta =
      const VerificationMeta('syncedLyrics');
  @override
  late final GeneratedColumn<String> syncedLyrics = GeneratedColumn<String>(
      'synced_lyrics', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _cachedAtMeta =
      const VerificationMeta('cachedAt');
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
      'cached_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns =>
      [songId, plainLyrics, syncedLyrics, cachedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'lyrics_cache';
  @override
  VerificationContext validateIntegrity(Insertable<LyricsCacheData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('song_id')) {
      context.handle(_songIdMeta,
          songId.isAcceptableOrUnknown(data['song_id']!, _songIdMeta));
    } else if (isInserting) {
      context.missing(_songIdMeta);
    }
    if (data.containsKey('plain_lyrics')) {
      context.handle(
          _plainLyricsMeta,
          plainLyrics.isAcceptableOrUnknown(
              data['plain_lyrics']!, _plainLyricsMeta));
    }
    if (data.containsKey('synced_lyrics')) {
      context.handle(
          _syncedLyricsMeta,
          syncedLyrics.isAcceptableOrUnknown(
              data['synced_lyrics']!, _syncedLyricsMeta));
    }
    if (data.containsKey('cached_at')) {
      context.handle(_cachedAtMeta,
          cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {songId};
  @override
  LyricsCacheData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LyricsCacheData(
      songId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}song_id'])!,
      plainLyrics: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}plain_lyrics']),
      syncedLyrics: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}synced_lyrics']),
      cachedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}cached_at'])!,
    );
  }

  @override
  $LyricsCacheTable createAlias(String alias) {
    return $LyricsCacheTable(attachedDatabase, alias);
  }
}

class LyricsCacheData extends DataClass implements Insertable<LyricsCacheData> {
  final String songId;
  final String? plainLyrics;
  final String? syncedLyrics;
  final DateTime cachedAt;
  const LyricsCacheData(
      {required this.songId,
      this.plainLyrics,
      this.syncedLyrics,
      required this.cachedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['song_id'] = Variable<String>(songId);
    if (!nullToAbsent || plainLyrics != null) {
      map['plain_lyrics'] = Variable<String>(plainLyrics);
    }
    if (!nullToAbsent || syncedLyrics != null) {
      map['synced_lyrics'] = Variable<String>(syncedLyrics);
    }
    map['cached_at'] = Variable<DateTime>(cachedAt);
    return map;
  }

  LyricsCacheCompanion toCompanion(bool nullToAbsent) {
    return LyricsCacheCompanion(
      songId: Value(songId),
      plainLyrics: plainLyrics == null && nullToAbsent
          ? const Value.absent()
          : Value(plainLyrics),
      syncedLyrics: syncedLyrics == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedLyrics),
      cachedAt: Value(cachedAt),
    );
  }

  factory LyricsCacheData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LyricsCacheData(
      songId: serializer.fromJson<String>(json['songId']),
      plainLyrics: serializer.fromJson<String?>(json['plainLyrics']),
      syncedLyrics: serializer.fromJson<String?>(json['syncedLyrics']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'songId': serializer.toJson<String>(songId),
      'plainLyrics': serializer.toJson<String?>(plainLyrics),
      'syncedLyrics': serializer.toJson<String?>(syncedLyrics),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
    };
  }

  LyricsCacheData copyWith(
          {String? songId,
          Value<String?> plainLyrics = const Value.absent(),
          Value<String?> syncedLyrics = const Value.absent(),
          DateTime? cachedAt}) =>
      LyricsCacheData(
        songId: songId ?? this.songId,
        plainLyrics: plainLyrics.present ? plainLyrics.value : this.plainLyrics,
        syncedLyrics:
            syncedLyrics.present ? syncedLyrics.value : this.syncedLyrics,
        cachedAt: cachedAt ?? this.cachedAt,
      );
  LyricsCacheData copyWithCompanion(LyricsCacheCompanion data) {
    return LyricsCacheData(
      songId: data.songId.present ? data.songId.value : this.songId,
      plainLyrics:
          data.plainLyrics.present ? data.plainLyrics.value : this.plainLyrics,
      syncedLyrics: data.syncedLyrics.present
          ? data.syncedLyrics.value
          : this.syncedLyrics,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LyricsCacheData(')
          ..write('songId: $songId, ')
          ..write('plainLyrics: $plainLyrics, ')
          ..write('syncedLyrics: $syncedLyrics, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(songId, plainLyrics, syncedLyrics, cachedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LyricsCacheData &&
          other.songId == this.songId &&
          other.plainLyrics == this.plainLyrics &&
          other.syncedLyrics == this.syncedLyrics &&
          other.cachedAt == this.cachedAt);
}

class LyricsCacheCompanion extends UpdateCompanion<LyricsCacheData> {
  final Value<String> songId;
  final Value<String?> plainLyrics;
  final Value<String?> syncedLyrics;
  final Value<DateTime> cachedAt;
  final Value<int> rowid;
  const LyricsCacheCompanion({
    this.songId = const Value.absent(),
    this.plainLyrics = const Value.absent(),
    this.syncedLyrics = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LyricsCacheCompanion.insert({
    required String songId,
    this.plainLyrics = const Value.absent(),
    this.syncedLyrics = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : songId = Value(songId);
  static Insertable<LyricsCacheData> custom({
    Expression<String>? songId,
    Expression<String>? plainLyrics,
    Expression<String>? syncedLyrics,
    Expression<DateTime>? cachedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (songId != null) 'song_id': songId,
      if (plainLyrics != null) 'plain_lyrics': plainLyrics,
      if (syncedLyrics != null) 'synced_lyrics': syncedLyrics,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LyricsCacheCompanion copyWith(
      {Value<String>? songId,
      Value<String?>? plainLyrics,
      Value<String?>? syncedLyrics,
      Value<DateTime>? cachedAt,
      Value<int>? rowid}) {
    return LyricsCacheCompanion(
      songId: songId ?? this.songId,
      plainLyrics: plainLyrics ?? this.plainLyrics,
      syncedLyrics: syncedLyrics ?? this.syncedLyrics,
      cachedAt: cachedAt ?? this.cachedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (songId.present) {
      map['song_id'] = Variable<String>(songId.value);
    }
    if (plainLyrics.present) {
      map['plain_lyrics'] = Variable<String>(plainLyrics.value);
    }
    if (syncedLyrics.present) {
      map['synced_lyrics'] = Variable<String>(syncedLyrics.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LyricsCacheCompanion(')
          ..write('songId: $songId, ')
          ..write('plainLyrics: $plainLyrics, ')
          ..write('syncedLyrics: $syncedLyrics, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PendingLikesTable extends PendingLikes
    with TableInfo<$PendingLikesTable, PendingLike> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingLikesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _deezerIdMeta =
      const VerificationMeta('deezerId');
  @override
  late final GeneratedColumn<int> deezerId = GeneratedColumn<int>(
      'deezer_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _artistMeta = const VerificationMeta('artist');
  @override
  late final GeneratedColumn<String> artist = GeneratedColumn<String>(
      'artist', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _albumMeta = const VerificationMeta('album');
  @override
  late final GeneratedColumn<String> album = GeneratedColumn<String>(
      'album', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _durationMeta =
      const VerificationMeta('duration');
  @override
  late final GeneratedColumn<int> duration = GeneratedColumn<int>(
      'duration', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _coverUrlMeta =
      const VerificationMeta('coverUrl');
  @override
  late final GeneratedColumn<String> coverUrl = GeneratedColumn<String>(
      'cover_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _previewUrlMeta =
      const VerificationMeta('previewUrl');
  @override
  late final GeneratedColumn<String> previewUrl = GeneratedColumn<String>(
      'preview_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _likedAtMeta =
      const VerificationMeta('likedAt');
  @override
  late final GeneratedColumn<DateTime> likedAt = GeneratedColumn<DateTime>(
      'liked_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns =>
      [deezerId, title, artist, album, duration, coverUrl, previewUrl, likedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_likes';
  @override
  VerificationContext validateIntegrity(Insertable<PendingLike> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('deezer_id')) {
      context.handle(_deezerIdMeta,
          deezerId.isAcceptableOrUnknown(data['deezer_id']!, _deezerIdMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('artist')) {
      context.handle(_artistMeta,
          artist.isAcceptableOrUnknown(data['artist']!, _artistMeta));
    } else if (isInserting) {
      context.missing(_artistMeta);
    }
    if (data.containsKey('album')) {
      context.handle(
          _albumMeta, album.isAcceptableOrUnknown(data['album']!, _albumMeta));
    } else if (isInserting) {
      context.missing(_albumMeta);
    }
    if (data.containsKey('duration')) {
      context.handle(_durationMeta,
          duration.isAcceptableOrUnknown(data['duration']!, _durationMeta));
    }
    if (data.containsKey('cover_url')) {
      context.handle(_coverUrlMeta,
          coverUrl.isAcceptableOrUnknown(data['cover_url']!, _coverUrlMeta));
    }
    if (data.containsKey('preview_url')) {
      context.handle(
          _previewUrlMeta,
          previewUrl.isAcceptableOrUnknown(
              data['preview_url']!, _previewUrlMeta));
    }
    if (data.containsKey('liked_at')) {
      context.handle(_likedAtMeta,
          likedAt.isAcceptableOrUnknown(data['liked_at']!, _likedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {deezerId};
  @override
  PendingLike map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingLike(
      deezerId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}deezer_id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      artist: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}artist'])!,
      album: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}album'])!,
      duration: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}duration']),
      coverUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}cover_url']),
      previewUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}preview_url']),
      likedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}liked_at'])!,
    );
  }

  @override
  $PendingLikesTable createAlias(String alias) {
    return $PendingLikesTable(attachedDatabase, alias);
  }
}

class PendingLike extends DataClass implements Insertable<PendingLike> {
  final int deezerId;
  final String title;
  final String artist;
  final String album;
  final int? duration;
  final String? coverUrl;
  final String? previewUrl;
  final DateTime likedAt;
  const PendingLike(
      {required this.deezerId,
      required this.title,
      required this.artist,
      required this.album,
      this.duration,
      this.coverUrl,
      this.previewUrl,
      required this.likedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['deezer_id'] = Variable<int>(deezerId);
    map['title'] = Variable<String>(title);
    map['artist'] = Variable<String>(artist);
    map['album'] = Variable<String>(album);
    if (!nullToAbsent || duration != null) {
      map['duration'] = Variable<int>(duration);
    }
    if (!nullToAbsent || coverUrl != null) {
      map['cover_url'] = Variable<String>(coverUrl);
    }
    if (!nullToAbsent || previewUrl != null) {
      map['preview_url'] = Variable<String>(previewUrl);
    }
    map['liked_at'] = Variable<DateTime>(likedAt);
    return map;
  }

  PendingLikesCompanion toCompanion(bool nullToAbsent) {
    return PendingLikesCompanion(
      deezerId: Value(deezerId),
      title: Value(title),
      artist: Value(artist),
      album: Value(album),
      duration: duration == null && nullToAbsent
          ? const Value.absent()
          : Value(duration),
      coverUrl: coverUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(coverUrl),
      previewUrl: previewUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(previewUrl),
      likedAt: Value(likedAt),
    );
  }

  factory PendingLike.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingLike(
      deezerId: serializer.fromJson<int>(json['deezerId']),
      title: serializer.fromJson<String>(json['title']),
      artist: serializer.fromJson<String>(json['artist']),
      album: serializer.fromJson<String>(json['album']),
      duration: serializer.fromJson<int?>(json['duration']),
      coverUrl: serializer.fromJson<String?>(json['coverUrl']),
      previewUrl: serializer.fromJson<String?>(json['previewUrl']),
      likedAt: serializer.fromJson<DateTime>(json['likedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'deezerId': serializer.toJson<int>(deezerId),
      'title': serializer.toJson<String>(title),
      'artist': serializer.toJson<String>(artist),
      'album': serializer.toJson<String>(album),
      'duration': serializer.toJson<int?>(duration),
      'coverUrl': serializer.toJson<String?>(coverUrl),
      'previewUrl': serializer.toJson<String?>(previewUrl),
      'likedAt': serializer.toJson<DateTime>(likedAt),
    };
  }

  PendingLike copyWith(
          {int? deezerId,
          String? title,
          String? artist,
          String? album,
          Value<int?> duration = const Value.absent(),
          Value<String?> coverUrl = const Value.absent(),
          Value<String?> previewUrl = const Value.absent(),
          DateTime? likedAt}) =>
      PendingLike(
        deezerId: deezerId ?? this.deezerId,
        title: title ?? this.title,
        artist: artist ?? this.artist,
        album: album ?? this.album,
        duration: duration.present ? duration.value : this.duration,
        coverUrl: coverUrl.present ? coverUrl.value : this.coverUrl,
        previewUrl: previewUrl.present ? previewUrl.value : this.previewUrl,
        likedAt: likedAt ?? this.likedAt,
      );
  PendingLike copyWithCompanion(PendingLikesCompanion data) {
    return PendingLike(
      deezerId: data.deezerId.present ? data.deezerId.value : this.deezerId,
      title: data.title.present ? data.title.value : this.title,
      artist: data.artist.present ? data.artist.value : this.artist,
      album: data.album.present ? data.album.value : this.album,
      duration: data.duration.present ? data.duration.value : this.duration,
      coverUrl: data.coverUrl.present ? data.coverUrl.value : this.coverUrl,
      previewUrl:
          data.previewUrl.present ? data.previewUrl.value : this.previewUrl,
      likedAt: data.likedAt.present ? data.likedAt.value : this.likedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingLike(')
          ..write('deezerId: $deezerId, ')
          ..write('title: $title, ')
          ..write('artist: $artist, ')
          ..write('album: $album, ')
          ..write('duration: $duration, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('previewUrl: $previewUrl, ')
          ..write('likedAt: $likedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      deezerId, title, artist, album, duration, coverUrl, previewUrl, likedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingLike &&
          other.deezerId == this.deezerId &&
          other.title == this.title &&
          other.artist == this.artist &&
          other.album == this.album &&
          other.duration == this.duration &&
          other.coverUrl == this.coverUrl &&
          other.previewUrl == this.previewUrl &&
          other.likedAt == this.likedAt);
}

class PendingLikesCompanion extends UpdateCompanion<PendingLike> {
  final Value<int> deezerId;
  final Value<String> title;
  final Value<String> artist;
  final Value<String> album;
  final Value<int?> duration;
  final Value<String?> coverUrl;
  final Value<String?> previewUrl;
  final Value<DateTime> likedAt;
  const PendingLikesCompanion({
    this.deezerId = const Value.absent(),
    this.title = const Value.absent(),
    this.artist = const Value.absent(),
    this.album = const Value.absent(),
    this.duration = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.previewUrl = const Value.absent(),
    this.likedAt = const Value.absent(),
  });
  PendingLikesCompanion.insert({
    this.deezerId = const Value.absent(),
    required String title,
    required String artist,
    required String album,
    this.duration = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.previewUrl = const Value.absent(),
    this.likedAt = const Value.absent(),
  })  : title = Value(title),
        artist = Value(artist),
        album = Value(album);
  static Insertable<PendingLike> custom({
    Expression<int>? deezerId,
    Expression<String>? title,
    Expression<String>? artist,
    Expression<String>? album,
    Expression<int>? duration,
    Expression<String>? coverUrl,
    Expression<String>? previewUrl,
    Expression<DateTime>? likedAt,
  }) {
    return RawValuesInsertable({
      if (deezerId != null) 'deezer_id': deezerId,
      if (title != null) 'title': title,
      if (artist != null) 'artist': artist,
      if (album != null) 'album': album,
      if (duration != null) 'duration': duration,
      if (coverUrl != null) 'cover_url': coverUrl,
      if (previewUrl != null) 'preview_url': previewUrl,
      if (likedAt != null) 'liked_at': likedAt,
    });
  }

  PendingLikesCompanion copyWith(
      {Value<int>? deezerId,
      Value<String>? title,
      Value<String>? artist,
      Value<String>? album,
      Value<int?>? duration,
      Value<String?>? coverUrl,
      Value<String?>? previewUrl,
      Value<DateTime>? likedAt}) {
    return PendingLikesCompanion(
      deezerId: deezerId ?? this.deezerId,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      duration: duration ?? this.duration,
      coverUrl: coverUrl ?? this.coverUrl,
      previewUrl: previewUrl ?? this.previewUrl,
      likedAt: likedAt ?? this.likedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (deezerId.present) {
      map['deezer_id'] = Variable<int>(deezerId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (artist.present) {
      map['artist'] = Variable<String>(artist.value);
    }
    if (album.present) {
      map['album'] = Variable<String>(album.value);
    }
    if (duration.present) {
      map['duration'] = Variable<int>(duration.value);
    }
    if (coverUrl.present) {
      map['cover_url'] = Variable<String>(coverUrl.value);
    }
    if (previewUrl.present) {
      map['preview_url'] = Variable<String>(previewUrl.value);
    }
    if (likedAt.present) {
      map['liked_at'] = Variable<DateTime>(likedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingLikesCompanion(')
          ..write('deezerId: $deezerId, ')
          ..write('title: $title, ')
          ..write('artist: $artist, ')
          ..write('album: $album, ')
          ..write('duration: $duration, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('previewUrl: $previewUrl, ')
          ..write('likedAt: $likedAt')
          ..write(')'))
        .toString();
  }
}

class $DismissedRecsTable extends DismissedRecs
    with TableInfo<$DismissedRecsTable, DismissedRec> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DismissedRecsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
      'kind', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _artistMeta = const VerificationMeta('artist');
  @override
  late final GeneratedColumn<String> artist = GeneratedColumn<String>(
      'artist', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _coverUrlMeta =
      const VerificationMeta('coverUrl');
  @override
  late final GeneratedColumn<String> coverUrl = GeneratedColumn<String>(
      'cover_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _dismissedAtMeta =
      const VerificationMeta('dismissedAt');
  @override
  late final GeneratedColumn<DateTime> dismissedAt = GeneratedColumn<DateTime>(
      'dismissed_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns =>
      [key, kind, artist, title, coverUrl, dismissedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dismissed_recs';
  @override
  VerificationContext validateIntegrity(Insertable<DismissedRec> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
          _kindMeta, kind.isAcceptableOrUnknown(data['kind']!, _kindMeta));
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('artist')) {
      context.handle(_artistMeta,
          artist.isAcceptableOrUnknown(data['artist']!, _artistMeta));
    } else if (isInserting) {
      context.missing(_artistMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    }
    if (data.containsKey('cover_url')) {
      context.handle(_coverUrlMeta,
          coverUrl.isAcceptableOrUnknown(data['cover_url']!, _coverUrlMeta));
    }
    if (data.containsKey('dismissed_at')) {
      context.handle(
          _dismissedAtMeta,
          dismissedAt.isAcceptableOrUnknown(
              data['dismissed_at']!, _dismissedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  DismissedRec map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DismissedRec(
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      kind: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}kind'])!,
      artist: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}artist'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title']),
      coverUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}cover_url']),
      dismissedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}dismissed_at'])!,
    );
  }

  @override
  $DismissedRecsTable createAlias(String alias) {
    return $DismissedRecsTable(attachedDatabase, alias);
  }
}

class DismissedRec extends DataClass implements Insertable<DismissedRec> {
  final String key;
  final String kind;
  final String artist;
  final String? title;
  final String? coverUrl;
  final DateTime dismissedAt;
  const DismissedRec(
      {required this.key,
      required this.kind,
      required this.artist,
      this.title,
      this.coverUrl,
      required this.dismissedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['kind'] = Variable<String>(kind);
    map['artist'] = Variable<String>(artist);
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    if (!nullToAbsent || coverUrl != null) {
      map['cover_url'] = Variable<String>(coverUrl);
    }
    map['dismissed_at'] = Variable<DateTime>(dismissedAt);
    return map;
  }

  DismissedRecsCompanion toCompanion(bool nullToAbsent) {
    return DismissedRecsCompanion(
      key: Value(key),
      kind: Value(kind),
      artist: Value(artist),
      title:
          title == null && nullToAbsent ? const Value.absent() : Value(title),
      coverUrl: coverUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(coverUrl),
      dismissedAt: Value(dismissedAt),
    );
  }

  factory DismissedRec.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DismissedRec(
      key: serializer.fromJson<String>(json['key']),
      kind: serializer.fromJson<String>(json['kind']),
      artist: serializer.fromJson<String>(json['artist']),
      title: serializer.fromJson<String?>(json['title']),
      coverUrl: serializer.fromJson<String?>(json['coverUrl']),
      dismissedAt: serializer.fromJson<DateTime>(json['dismissedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'kind': serializer.toJson<String>(kind),
      'artist': serializer.toJson<String>(artist),
      'title': serializer.toJson<String?>(title),
      'coverUrl': serializer.toJson<String?>(coverUrl),
      'dismissedAt': serializer.toJson<DateTime>(dismissedAt),
    };
  }

  DismissedRec copyWith(
          {String? key,
          String? kind,
          String? artist,
          Value<String?> title = const Value.absent(),
          Value<String?> coverUrl = const Value.absent(),
          DateTime? dismissedAt}) =>
      DismissedRec(
        key: key ?? this.key,
        kind: kind ?? this.kind,
        artist: artist ?? this.artist,
        title: title.present ? title.value : this.title,
        coverUrl: coverUrl.present ? coverUrl.value : this.coverUrl,
        dismissedAt: dismissedAt ?? this.dismissedAt,
      );
  DismissedRec copyWithCompanion(DismissedRecsCompanion data) {
    return DismissedRec(
      key: data.key.present ? data.key.value : this.key,
      kind: data.kind.present ? data.kind.value : this.kind,
      artist: data.artist.present ? data.artist.value : this.artist,
      title: data.title.present ? data.title.value : this.title,
      coverUrl: data.coverUrl.present ? data.coverUrl.value : this.coverUrl,
      dismissedAt:
          data.dismissedAt.present ? data.dismissedAt.value : this.dismissedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DismissedRec(')
          ..write('key: $key, ')
          ..write('kind: $kind, ')
          ..write('artist: $artist, ')
          ..write('title: $title, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('dismissedAt: $dismissedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(key, kind, artist, title, coverUrl, dismissedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DismissedRec &&
          other.key == this.key &&
          other.kind == this.kind &&
          other.artist == this.artist &&
          other.title == this.title &&
          other.coverUrl == this.coverUrl &&
          other.dismissedAt == this.dismissedAt);
}

class DismissedRecsCompanion extends UpdateCompanion<DismissedRec> {
  final Value<String> key;
  final Value<String> kind;
  final Value<String> artist;
  final Value<String?> title;
  final Value<String?> coverUrl;
  final Value<DateTime> dismissedAt;
  final Value<int> rowid;
  const DismissedRecsCompanion({
    this.key = const Value.absent(),
    this.kind = const Value.absent(),
    this.artist = const Value.absent(),
    this.title = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.dismissedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DismissedRecsCompanion.insert({
    required String key,
    required String kind,
    required String artist,
    this.title = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.dismissedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : key = Value(key),
        kind = Value(kind),
        artist = Value(artist);
  static Insertable<DismissedRec> custom({
    Expression<String>? key,
    Expression<String>? kind,
    Expression<String>? artist,
    Expression<String>? title,
    Expression<String>? coverUrl,
    Expression<DateTime>? dismissedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (kind != null) 'kind': kind,
      if (artist != null) 'artist': artist,
      if (title != null) 'title': title,
      if (coverUrl != null) 'cover_url': coverUrl,
      if (dismissedAt != null) 'dismissed_at': dismissedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DismissedRecsCompanion copyWith(
      {Value<String>? key,
      Value<String>? kind,
      Value<String>? artist,
      Value<String?>? title,
      Value<String?>? coverUrl,
      Value<DateTime>? dismissedAt,
      Value<int>? rowid}) {
    return DismissedRecsCompanion(
      key: key ?? this.key,
      kind: kind ?? this.kind,
      artist: artist ?? this.artist,
      title: title ?? this.title,
      coverUrl: coverUrl ?? this.coverUrl,
      dismissedAt: dismissedAt ?? this.dismissedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (artist.present) {
      map['artist'] = Variable<String>(artist.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (coverUrl.present) {
      map['cover_url'] = Variable<String>(coverUrl.value);
    }
    if (dismissedAt.present) {
      map['dismissed_at'] = Variable<DateTime>(dismissedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DismissedRecsCompanion(')
          ..write('key: $key, ')
          ..write('kind: $kind, ')
          ..write('artist: $artist, ')
          ..write('title: $title, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('dismissedAt: $dismissedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RecImpressionsTable extends RecImpressions
    with TableInfo<$RecImpressionsTable, RecImpression> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecImpressionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _trackKeyMeta =
      const VerificationMeta('trackKey');
  @override
  late final GeneratedColumn<String> trackKey = GeneratedColumn<String>(
      'track_key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _shownMeta = const VerificationMeta('shown');
  @override
  late final GeneratedColumn<int> shown = GeneratedColumn<int>(
      'shown', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  @override
  List<GeneratedColumn> get $columns => [trackKey, shown];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'rec_impressions';
  @override
  VerificationContext validateIntegrity(Insertable<RecImpression> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('track_key')) {
      context.handle(_trackKeyMeta,
          trackKey.isAcceptableOrUnknown(data['track_key']!, _trackKeyMeta));
    } else if (isInserting) {
      context.missing(_trackKeyMeta);
    }
    if (data.containsKey('shown')) {
      context.handle(
          _shownMeta, shown.isAcceptableOrUnknown(data['shown']!, _shownMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {trackKey};
  @override
  RecImpression map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecImpression(
      trackKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}track_key'])!,
      shown: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}shown'])!,
    );
  }

  @override
  $RecImpressionsTable createAlias(String alias) {
    return $RecImpressionsTable(attachedDatabase, alias);
  }
}

class RecImpression extends DataClass implements Insertable<RecImpression> {
  final String trackKey;
  final int shown;
  const RecImpression({required this.trackKey, required this.shown});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['track_key'] = Variable<String>(trackKey);
    map['shown'] = Variable<int>(shown);
    return map;
  }

  RecImpressionsCompanion toCompanion(bool nullToAbsent) {
    return RecImpressionsCompanion(
      trackKey: Value(trackKey),
      shown: Value(shown),
    );
  }

  factory RecImpression.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecImpression(
      trackKey: serializer.fromJson<String>(json['trackKey']),
      shown: serializer.fromJson<int>(json['shown']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'trackKey': serializer.toJson<String>(trackKey),
      'shown': serializer.toJson<int>(shown),
    };
  }

  RecImpression copyWith({String? trackKey, int? shown}) => RecImpression(
        trackKey: trackKey ?? this.trackKey,
        shown: shown ?? this.shown,
      );
  RecImpression copyWithCompanion(RecImpressionsCompanion data) {
    return RecImpression(
      trackKey: data.trackKey.present ? data.trackKey.value : this.trackKey,
      shown: data.shown.present ? data.shown.value : this.shown,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecImpression(')
          ..write('trackKey: $trackKey, ')
          ..write('shown: $shown')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(trackKey, shown);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecImpression &&
          other.trackKey == this.trackKey &&
          other.shown == this.shown);
}

class RecImpressionsCompanion extends UpdateCompanion<RecImpression> {
  final Value<String> trackKey;
  final Value<int> shown;
  final Value<int> rowid;
  const RecImpressionsCompanion({
    this.trackKey = const Value.absent(),
    this.shown = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RecImpressionsCompanion.insert({
    required String trackKey,
    this.shown = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : trackKey = Value(trackKey);
  static Insertable<RecImpression> custom({
    Expression<String>? trackKey,
    Expression<int>? shown,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (trackKey != null) 'track_key': trackKey,
      if (shown != null) 'shown': shown,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RecImpressionsCompanion copyWith(
      {Value<String>? trackKey, Value<int>? shown, Value<int>? rowid}) {
    return RecImpressionsCompanion(
      trackKey: trackKey ?? this.trackKey,
      shown: shown ?? this.shown,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (trackKey.present) {
      map['track_key'] = Variable<String>(trackKey.value);
    }
    if (shown.present) {
      map['shown'] = Variable<int>(shown.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecImpressionsCompanion(')
          ..write('trackKey: $trackKey, ')
          ..write('shown: $shown, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MoreLikeThisTapsTable extends MoreLikeThisTaps
    with TableInfo<$MoreLikeThisTapsTable, MoreLikeThisTap> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MoreLikeThisTapsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _artistMeta = const VerificationMeta('artist');
  @override
  late final GeneratedColumn<String> artist = GeneratedColumn<String>(
      'artist', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _tapsMeta = const VerificationMeta('taps');
  @override
  late final GeneratedColumn<int> taps = GeneratedColumn<int>(
      'taps', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  @override
  List<GeneratedColumn> get $columns => [artist, taps];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'more_like_this_taps';
  @override
  VerificationContext validateIntegrity(Insertable<MoreLikeThisTap> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('artist')) {
      context.handle(_artistMeta,
          artist.isAcceptableOrUnknown(data['artist']!, _artistMeta));
    } else if (isInserting) {
      context.missing(_artistMeta);
    }
    if (data.containsKey('taps')) {
      context.handle(
          _tapsMeta, taps.isAcceptableOrUnknown(data['taps']!, _tapsMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {artist};
  @override
  MoreLikeThisTap map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MoreLikeThisTap(
      artist: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}artist'])!,
      taps: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}taps'])!,
    );
  }

  @override
  $MoreLikeThisTapsTable createAlias(String alias) {
    return $MoreLikeThisTapsTable(attachedDatabase, alias);
  }
}

class MoreLikeThisTap extends DataClass implements Insertable<MoreLikeThisTap> {
  final String artist;
  final int taps;
  const MoreLikeThisTap({required this.artist, required this.taps});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['artist'] = Variable<String>(artist);
    map['taps'] = Variable<int>(taps);
    return map;
  }

  MoreLikeThisTapsCompanion toCompanion(bool nullToAbsent) {
    return MoreLikeThisTapsCompanion(
      artist: Value(artist),
      taps: Value(taps),
    );
  }

  factory MoreLikeThisTap.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MoreLikeThisTap(
      artist: serializer.fromJson<String>(json['artist']),
      taps: serializer.fromJson<int>(json['taps']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'artist': serializer.toJson<String>(artist),
      'taps': serializer.toJson<int>(taps),
    };
  }

  MoreLikeThisTap copyWith({String? artist, int? taps}) => MoreLikeThisTap(
        artist: artist ?? this.artist,
        taps: taps ?? this.taps,
      );
  MoreLikeThisTap copyWithCompanion(MoreLikeThisTapsCompanion data) {
    return MoreLikeThisTap(
      artist: data.artist.present ? data.artist.value : this.artist,
      taps: data.taps.present ? data.taps.value : this.taps,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MoreLikeThisTap(')
          ..write('artist: $artist, ')
          ..write('taps: $taps')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(artist, taps);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MoreLikeThisTap &&
          other.artist == this.artist &&
          other.taps == this.taps);
}

class MoreLikeThisTapsCompanion extends UpdateCompanion<MoreLikeThisTap> {
  final Value<String> artist;
  final Value<int> taps;
  final Value<int> rowid;
  const MoreLikeThisTapsCompanion({
    this.artist = const Value.absent(),
    this.taps = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MoreLikeThisTapsCompanion.insert({
    required String artist,
    this.taps = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : artist = Value(artist);
  static Insertable<MoreLikeThisTap> custom({
    Expression<String>? artist,
    Expression<int>? taps,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (artist != null) 'artist': artist,
      if (taps != null) 'taps': taps,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MoreLikeThisTapsCompanion copyWith(
      {Value<String>? artist, Value<int>? taps, Value<int>? rowid}) {
    return MoreLikeThisTapsCompanion(
      artist: artist ?? this.artist,
      taps: taps ?? this.taps,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (artist.present) {
      map['artist'] = Variable<String>(artist.value);
    }
    if (taps.present) {
      map['taps'] = Variable<int>(taps.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MoreLikeThisTapsCompanion(')
          ..write('artist: $artist, ')
          ..write('taps: $taps, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CachedSongsTable cachedSongs = $CachedSongsTable(this);
  late final $PlayHistoryTable playHistory = $PlayHistoryTable(this);
  late final $ServerConfigTable serverConfig = $ServerConfigTable(this);
  late final $DownloadQueueTable downloadQueue = $DownloadQueueTable(this);
  late final $LyricsCacheTable lyricsCache = $LyricsCacheTable(this);
  late final $PendingLikesTable pendingLikes = $PendingLikesTable(this);
  late final $DismissedRecsTable dismissedRecs = $DismissedRecsTable(this);
  late final $RecImpressionsTable recImpressions = $RecImpressionsTable(this);
  late final $MoreLikeThisTapsTable moreLikeThisTaps =
      $MoreLikeThisTapsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        cachedSongs,
        playHistory,
        serverConfig,
        downloadQueue,
        lyricsCache,
        pendingLikes,
        dismissedRecs,
        recImpressions,
        moreLikeThisTaps
      ];
}

typedef $$CachedSongsTableCreateCompanionBuilder = CachedSongsCompanion
    Function({
  required String id,
  required String title,
  required String artist,
  required String album,
  Value<String?> albumId,
  Value<String?> artistId,
  Value<int?> duration,
  Value<int?> year,
  Value<String?> genre,
  Value<int?> track,
  Value<String?> coverArt,
  Value<String?> suffix,
  Value<String?> contentType,
  Value<int?> bitRate,
  Value<int?> size,
  Value<bool> isDownloaded,
  Value<String?> localPath,
  Value<DateTime?> created,
  Value<DateTime?> starred,
  Value<int?> playCount,
  Value<DateTime> cachedAt,
  Value<int> rowid,
});
typedef $$CachedSongsTableUpdateCompanionBuilder = CachedSongsCompanion
    Function({
  Value<String> id,
  Value<String> title,
  Value<String> artist,
  Value<String> album,
  Value<String?> albumId,
  Value<String?> artistId,
  Value<int?> duration,
  Value<int?> year,
  Value<String?> genre,
  Value<int?> track,
  Value<String?> coverArt,
  Value<String?> suffix,
  Value<String?> contentType,
  Value<int?> bitRate,
  Value<int?> size,
  Value<bool> isDownloaded,
  Value<String?> localPath,
  Value<DateTime?> created,
  Value<DateTime?> starred,
  Value<int?> playCount,
  Value<DateTime> cachedAt,
  Value<int> rowid,
});

class $$CachedSongsTableFilterComposer
    extends Composer<_$AppDatabase, $CachedSongsTable> {
  $$CachedSongsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get artist => $composableBuilder(
      column: $table.artist, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get album => $composableBuilder(
      column: $table.album, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get albumId => $composableBuilder(
      column: $table.albumId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get artistId => $composableBuilder(
      column: $table.artistId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get duration => $composableBuilder(
      column: $table.duration, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get year => $composableBuilder(
      column: $table.year, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get genre => $composableBuilder(
      column: $table.genre, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get track => $composableBuilder(
      column: $table.track, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get coverArt => $composableBuilder(
      column: $table.coverArt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get suffix => $composableBuilder(
      column: $table.suffix, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get contentType => $composableBuilder(
      column: $table.contentType, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get bitRate => $composableBuilder(
      column: $table.bitRate, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get size => $composableBuilder(
      column: $table.size, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isDownloaded => $composableBuilder(
      column: $table.isDownloaded, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get localPath => $composableBuilder(
      column: $table.localPath, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get created => $composableBuilder(
      column: $table.created, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get starred => $composableBuilder(
      column: $table.starred, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get playCount => $composableBuilder(
      column: $table.playCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
      column: $table.cachedAt, builder: (column) => ColumnFilters(column));
}

class $$CachedSongsTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedSongsTable> {
  $$CachedSongsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get artist => $composableBuilder(
      column: $table.artist, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get album => $composableBuilder(
      column: $table.album, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get albumId => $composableBuilder(
      column: $table.albumId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get artistId => $composableBuilder(
      column: $table.artistId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get duration => $composableBuilder(
      column: $table.duration, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get year => $composableBuilder(
      column: $table.year, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get genre => $composableBuilder(
      column: $table.genre, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get track => $composableBuilder(
      column: $table.track, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get coverArt => $composableBuilder(
      column: $table.coverArt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get suffix => $composableBuilder(
      column: $table.suffix, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get contentType => $composableBuilder(
      column: $table.contentType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get bitRate => $composableBuilder(
      column: $table.bitRate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get size => $composableBuilder(
      column: $table.size, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isDownloaded => $composableBuilder(
      column: $table.isDownloaded,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get localPath => $composableBuilder(
      column: $table.localPath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get created => $composableBuilder(
      column: $table.created, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get starred => $composableBuilder(
      column: $table.starred, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get playCount => $composableBuilder(
      column: $table.playCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
      column: $table.cachedAt, builder: (column) => ColumnOrderings(column));
}

class $$CachedSongsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedSongsTable> {
  $$CachedSongsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get artist =>
      $composableBuilder(column: $table.artist, builder: (column) => column);

  GeneratedColumn<String> get album =>
      $composableBuilder(column: $table.album, builder: (column) => column);

  GeneratedColumn<String> get albumId =>
      $composableBuilder(column: $table.albumId, builder: (column) => column);

  GeneratedColumn<String> get artistId =>
      $composableBuilder(column: $table.artistId, builder: (column) => column);

  GeneratedColumn<int> get duration =>
      $composableBuilder(column: $table.duration, builder: (column) => column);

  GeneratedColumn<int> get year =>
      $composableBuilder(column: $table.year, builder: (column) => column);

  GeneratedColumn<String> get genre =>
      $composableBuilder(column: $table.genre, builder: (column) => column);

  GeneratedColumn<int> get track =>
      $composableBuilder(column: $table.track, builder: (column) => column);

  GeneratedColumn<String> get coverArt =>
      $composableBuilder(column: $table.coverArt, builder: (column) => column);

  GeneratedColumn<String> get suffix =>
      $composableBuilder(column: $table.suffix, builder: (column) => column);

  GeneratedColumn<String> get contentType => $composableBuilder(
      column: $table.contentType, builder: (column) => column);

  GeneratedColumn<int> get bitRate =>
      $composableBuilder(column: $table.bitRate, builder: (column) => column);

  GeneratedColumn<int> get size =>
      $composableBuilder(column: $table.size, builder: (column) => column);

  GeneratedColumn<bool> get isDownloaded => $composableBuilder(
      column: $table.isDownloaded, builder: (column) => column);

  GeneratedColumn<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => column);

  GeneratedColumn<DateTime> get created =>
      $composableBuilder(column: $table.created, builder: (column) => column);

  GeneratedColumn<DateTime> get starred =>
      $composableBuilder(column: $table.starred, builder: (column) => column);

  GeneratedColumn<int> get playCount =>
      $composableBuilder(column: $table.playCount, builder: (column) => column);

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);
}

class $$CachedSongsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CachedSongsTable,
    CachedSong,
    $$CachedSongsTableFilterComposer,
    $$CachedSongsTableOrderingComposer,
    $$CachedSongsTableAnnotationComposer,
    $$CachedSongsTableCreateCompanionBuilder,
    $$CachedSongsTableUpdateCompanionBuilder,
    (CachedSong, BaseReferences<_$AppDatabase, $CachedSongsTable, CachedSong>),
    CachedSong,
    PrefetchHooks Function()> {
  $$CachedSongsTableTableManager(_$AppDatabase db, $CachedSongsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedSongsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedSongsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedSongsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String> artist = const Value.absent(),
            Value<String> album = const Value.absent(),
            Value<String?> albumId = const Value.absent(),
            Value<String?> artistId = const Value.absent(),
            Value<int?> duration = const Value.absent(),
            Value<int?> year = const Value.absent(),
            Value<String?> genre = const Value.absent(),
            Value<int?> track = const Value.absent(),
            Value<String?> coverArt = const Value.absent(),
            Value<String?> suffix = const Value.absent(),
            Value<String?> contentType = const Value.absent(),
            Value<int?> bitRate = const Value.absent(),
            Value<int?> size = const Value.absent(),
            Value<bool> isDownloaded = const Value.absent(),
            Value<String?> localPath = const Value.absent(),
            Value<DateTime?> created = const Value.absent(),
            Value<DateTime?> starred = const Value.absent(),
            Value<int?> playCount = const Value.absent(),
            Value<DateTime> cachedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CachedSongsCompanion(
            id: id,
            title: title,
            artist: artist,
            album: album,
            albumId: albumId,
            artistId: artistId,
            duration: duration,
            year: year,
            genre: genre,
            track: track,
            coverArt: coverArt,
            suffix: suffix,
            contentType: contentType,
            bitRate: bitRate,
            size: size,
            isDownloaded: isDownloaded,
            localPath: localPath,
            created: created,
            starred: starred,
            playCount: playCount,
            cachedAt: cachedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String title,
            required String artist,
            required String album,
            Value<String?> albumId = const Value.absent(),
            Value<String?> artistId = const Value.absent(),
            Value<int?> duration = const Value.absent(),
            Value<int?> year = const Value.absent(),
            Value<String?> genre = const Value.absent(),
            Value<int?> track = const Value.absent(),
            Value<String?> coverArt = const Value.absent(),
            Value<String?> suffix = const Value.absent(),
            Value<String?> contentType = const Value.absent(),
            Value<int?> bitRate = const Value.absent(),
            Value<int?> size = const Value.absent(),
            Value<bool> isDownloaded = const Value.absent(),
            Value<String?> localPath = const Value.absent(),
            Value<DateTime?> created = const Value.absent(),
            Value<DateTime?> starred = const Value.absent(),
            Value<int?> playCount = const Value.absent(),
            Value<DateTime> cachedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CachedSongsCompanion.insert(
            id: id,
            title: title,
            artist: artist,
            album: album,
            albumId: albumId,
            artistId: artistId,
            duration: duration,
            year: year,
            genre: genre,
            track: track,
            coverArt: coverArt,
            suffix: suffix,
            contentType: contentType,
            bitRate: bitRate,
            size: size,
            isDownloaded: isDownloaded,
            localPath: localPath,
            created: created,
            starred: starred,
            playCount: playCount,
            cachedAt: cachedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CachedSongsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CachedSongsTable,
    CachedSong,
    $$CachedSongsTableFilterComposer,
    $$CachedSongsTableOrderingComposer,
    $$CachedSongsTableAnnotationComposer,
    $$CachedSongsTableCreateCompanionBuilder,
    $$CachedSongsTableUpdateCompanionBuilder,
    (CachedSong, BaseReferences<_$AppDatabase, $CachedSongsTable, CachedSong>),
    CachedSong,
    PrefetchHooks Function()>;
typedef $$PlayHistoryTableCreateCompanionBuilder = PlayHistoryCompanion
    Function({
  Value<int> historyId,
  required String songId,
  required String songTitle,
  required String artist,
  Value<String?> coverArt,
  Value<DateTime> playedAt,
  Value<int?> listenedMs,
  Value<bool> skipped,
});
typedef $$PlayHistoryTableUpdateCompanionBuilder = PlayHistoryCompanion
    Function({
  Value<int> historyId,
  Value<String> songId,
  Value<String> songTitle,
  Value<String> artist,
  Value<String?> coverArt,
  Value<DateTime> playedAt,
  Value<int?> listenedMs,
  Value<bool> skipped,
});

class $$PlayHistoryTableFilterComposer
    extends Composer<_$AppDatabase, $PlayHistoryTable> {
  $$PlayHistoryTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get historyId => $composableBuilder(
      column: $table.historyId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get songId => $composableBuilder(
      column: $table.songId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get songTitle => $composableBuilder(
      column: $table.songTitle, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get artist => $composableBuilder(
      column: $table.artist, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get coverArt => $composableBuilder(
      column: $table.coverArt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get playedAt => $composableBuilder(
      column: $table.playedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get listenedMs => $composableBuilder(
      column: $table.listenedMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get skipped => $composableBuilder(
      column: $table.skipped, builder: (column) => ColumnFilters(column));
}

class $$PlayHistoryTableOrderingComposer
    extends Composer<_$AppDatabase, $PlayHistoryTable> {
  $$PlayHistoryTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get historyId => $composableBuilder(
      column: $table.historyId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get songId => $composableBuilder(
      column: $table.songId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get songTitle => $composableBuilder(
      column: $table.songTitle, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get artist => $composableBuilder(
      column: $table.artist, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get coverArt => $composableBuilder(
      column: $table.coverArt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get playedAt => $composableBuilder(
      column: $table.playedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get listenedMs => $composableBuilder(
      column: $table.listenedMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get skipped => $composableBuilder(
      column: $table.skipped, builder: (column) => ColumnOrderings(column));
}

class $$PlayHistoryTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlayHistoryTable> {
  $$PlayHistoryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get historyId =>
      $composableBuilder(column: $table.historyId, builder: (column) => column);

  GeneratedColumn<String> get songId =>
      $composableBuilder(column: $table.songId, builder: (column) => column);

  GeneratedColumn<String> get songTitle =>
      $composableBuilder(column: $table.songTitle, builder: (column) => column);

  GeneratedColumn<String> get artist =>
      $composableBuilder(column: $table.artist, builder: (column) => column);

  GeneratedColumn<String> get coverArt =>
      $composableBuilder(column: $table.coverArt, builder: (column) => column);

  GeneratedColumn<DateTime> get playedAt =>
      $composableBuilder(column: $table.playedAt, builder: (column) => column);

  GeneratedColumn<int> get listenedMs => $composableBuilder(
      column: $table.listenedMs, builder: (column) => column);

  GeneratedColumn<bool> get skipped =>
      $composableBuilder(column: $table.skipped, builder: (column) => column);
}

class $$PlayHistoryTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PlayHistoryTable,
    PlayHistoryData,
    $$PlayHistoryTableFilterComposer,
    $$PlayHistoryTableOrderingComposer,
    $$PlayHistoryTableAnnotationComposer,
    $$PlayHistoryTableCreateCompanionBuilder,
    $$PlayHistoryTableUpdateCompanionBuilder,
    (
      PlayHistoryData,
      BaseReferences<_$AppDatabase, $PlayHistoryTable, PlayHistoryData>
    ),
    PlayHistoryData,
    PrefetchHooks Function()> {
  $$PlayHistoryTableTableManager(_$AppDatabase db, $PlayHistoryTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlayHistoryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlayHistoryTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlayHistoryTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> historyId = const Value.absent(),
            Value<String> songId = const Value.absent(),
            Value<String> songTitle = const Value.absent(),
            Value<String> artist = const Value.absent(),
            Value<String?> coverArt = const Value.absent(),
            Value<DateTime> playedAt = const Value.absent(),
            Value<int?> listenedMs = const Value.absent(),
            Value<bool> skipped = const Value.absent(),
          }) =>
              PlayHistoryCompanion(
            historyId: historyId,
            songId: songId,
            songTitle: songTitle,
            artist: artist,
            coverArt: coverArt,
            playedAt: playedAt,
            listenedMs: listenedMs,
            skipped: skipped,
          ),
          createCompanionCallback: ({
            Value<int> historyId = const Value.absent(),
            required String songId,
            required String songTitle,
            required String artist,
            Value<String?> coverArt = const Value.absent(),
            Value<DateTime> playedAt = const Value.absent(),
            Value<int?> listenedMs = const Value.absent(),
            Value<bool> skipped = const Value.absent(),
          }) =>
              PlayHistoryCompanion.insert(
            historyId: historyId,
            songId: songId,
            songTitle: songTitle,
            artist: artist,
            coverArt: coverArt,
            playedAt: playedAt,
            listenedMs: listenedMs,
            skipped: skipped,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PlayHistoryTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PlayHistoryTable,
    PlayHistoryData,
    $$PlayHistoryTableFilterComposer,
    $$PlayHistoryTableOrderingComposer,
    $$PlayHistoryTableAnnotationComposer,
    $$PlayHistoryTableCreateCompanionBuilder,
    $$PlayHistoryTableUpdateCompanionBuilder,
    (
      PlayHistoryData,
      BaseReferences<_$AppDatabase, $PlayHistoryTable, PlayHistoryData>
    ),
    PlayHistoryData,
    PrefetchHooks Function()>;
typedef $$ServerConfigTableCreateCompanionBuilder = ServerConfigCompanion
    Function({
  Value<int> configId,
  required String serverUrl,
  required String username,
  required String password,
  Value<bool> isActive,
});
typedef $$ServerConfigTableUpdateCompanionBuilder = ServerConfigCompanion
    Function({
  Value<int> configId,
  Value<String> serverUrl,
  Value<String> username,
  Value<String> password,
  Value<bool> isActive,
});

class $$ServerConfigTableFilterComposer
    extends Composer<_$AppDatabase, $ServerConfigTable> {
  $$ServerConfigTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get configId => $composableBuilder(
      column: $table.configId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get serverUrl => $composableBuilder(
      column: $table.serverUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get username => $composableBuilder(
      column: $table.username, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get password => $composableBuilder(
      column: $table.password, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isActive => $composableBuilder(
      column: $table.isActive, builder: (column) => ColumnFilters(column));
}

class $$ServerConfigTableOrderingComposer
    extends Composer<_$AppDatabase, $ServerConfigTable> {
  $$ServerConfigTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get configId => $composableBuilder(
      column: $table.configId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get serverUrl => $composableBuilder(
      column: $table.serverUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get username => $composableBuilder(
      column: $table.username, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get password => $composableBuilder(
      column: $table.password, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isActive => $composableBuilder(
      column: $table.isActive, builder: (column) => ColumnOrderings(column));
}

class $$ServerConfigTableAnnotationComposer
    extends Composer<_$AppDatabase, $ServerConfigTable> {
  $$ServerConfigTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get configId =>
      $composableBuilder(column: $table.configId, builder: (column) => column);

  GeneratedColumn<String> get serverUrl =>
      $composableBuilder(column: $table.serverUrl, builder: (column) => column);

  GeneratedColumn<String> get username =>
      $composableBuilder(column: $table.username, builder: (column) => column);

  GeneratedColumn<String> get password =>
      $composableBuilder(column: $table.password, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);
}

class $$ServerConfigTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ServerConfigTable,
    ServerConfigData,
    $$ServerConfigTableFilterComposer,
    $$ServerConfigTableOrderingComposer,
    $$ServerConfigTableAnnotationComposer,
    $$ServerConfigTableCreateCompanionBuilder,
    $$ServerConfigTableUpdateCompanionBuilder,
    (
      ServerConfigData,
      BaseReferences<_$AppDatabase, $ServerConfigTable, ServerConfigData>
    ),
    ServerConfigData,
    PrefetchHooks Function()> {
  $$ServerConfigTableTableManager(_$AppDatabase db, $ServerConfigTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ServerConfigTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ServerConfigTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ServerConfigTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> configId = const Value.absent(),
            Value<String> serverUrl = const Value.absent(),
            Value<String> username = const Value.absent(),
            Value<String> password = const Value.absent(),
            Value<bool> isActive = const Value.absent(),
          }) =>
              ServerConfigCompanion(
            configId: configId,
            serverUrl: serverUrl,
            username: username,
            password: password,
            isActive: isActive,
          ),
          createCompanionCallback: ({
            Value<int> configId = const Value.absent(),
            required String serverUrl,
            required String username,
            required String password,
            Value<bool> isActive = const Value.absent(),
          }) =>
              ServerConfigCompanion.insert(
            configId: configId,
            serverUrl: serverUrl,
            username: username,
            password: password,
            isActive: isActive,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ServerConfigTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ServerConfigTable,
    ServerConfigData,
    $$ServerConfigTableFilterComposer,
    $$ServerConfigTableOrderingComposer,
    $$ServerConfigTableAnnotationComposer,
    $$ServerConfigTableCreateCompanionBuilder,
    $$ServerConfigTableUpdateCompanionBuilder,
    (
      ServerConfigData,
      BaseReferences<_$AppDatabase, $ServerConfigTable, ServerConfigData>
    ),
    ServerConfigData,
    PrefetchHooks Function()>;
typedef $$DownloadQueueTableCreateCompanionBuilder = DownloadQueueCompanion
    Function({
  required String songId,
  required String songTitle,
  required String artist,
  required String savePath,
  Value<String> status,
  Value<int> progress,
  Value<String?> quality,
  Value<String?> errorMessage,
  Value<DateTime> addedAt,
  Value<int> rowid,
});
typedef $$DownloadQueueTableUpdateCompanionBuilder = DownloadQueueCompanion
    Function({
  Value<String> songId,
  Value<String> songTitle,
  Value<String> artist,
  Value<String> savePath,
  Value<String> status,
  Value<int> progress,
  Value<String?> quality,
  Value<String?> errorMessage,
  Value<DateTime> addedAt,
  Value<int> rowid,
});

class $$DownloadQueueTableFilterComposer
    extends Composer<_$AppDatabase, $DownloadQueueTable> {
  $$DownloadQueueTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get songId => $composableBuilder(
      column: $table.songId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get songTitle => $composableBuilder(
      column: $table.songTitle, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get artist => $composableBuilder(
      column: $table.artist, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get savePath => $composableBuilder(
      column: $table.savePath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get progress => $composableBuilder(
      column: $table.progress, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get quality => $composableBuilder(
      column: $table.quality, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get errorMessage => $composableBuilder(
      column: $table.errorMessage, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
      column: $table.addedAt, builder: (column) => ColumnFilters(column));
}

class $$DownloadQueueTableOrderingComposer
    extends Composer<_$AppDatabase, $DownloadQueueTable> {
  $$DownloadQueueTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get songId => $composableBuilder(
      column: $table.songId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get songTitle => $composableBuilder(
      column: $table.songTitle, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get artist => $composableBuilder(
      column: $table.artist, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get savePath => $composableBuilder(
      column: $table.savePath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get progress => $composableBuilder(
      column: $table.progress, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get quality => $composableBuilder(
      column: $table.quality, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get errorMessage => $composableBuilder(
      column: $table.errorMessage,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
      column: $table.addedAt, builder: (column) => ColumnOrderings(column));
}

class $$DownloadQueueTableAnnotationComposer
    extends Composer<_$AppDatabase, $DownloadQueueTable> {
  $$DownloadQueueTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get songId =>
      $composableBuilder(column: $table.songId, builder: (column) => column);

  GeneratedColumn<String> get songTitle =>
      $composableBuilder(column: $table.songTitle, builder: (column) => column);

  GeneratedColumn<String> get artist =>
      $composableBuilder(column: $table.artist, builder: (column) => column);

  GeneratedColumn<String> get savePath =>
      $composableBuilder(column: $table.savePath, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get progress =>
      $composableBuilder(column: $table.progress, builder: (column) => column);

  GeneratedColumn<String> get quality =>
      $composableBuilder(column: $table.quality, builder: (column) => column);

  GeneratedColumn<String> get errorMessage => $composableBuilder(
      column: $table.errorMessage, builder: (column) => column);

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);
}

class $$DownloadQueueTableTableManager extends RootTableManager<
    _$AppDatabase,
    $DownloadQueueTable,
    DownloadQueueData,
    $$DownloadQueueTableFilterComposer,
    $$DownloadQueueTableOrderingComposer,
    $$DownloadQueueTableAnnotationComposer,
    $$DownloadQueueTableCreateCompanionBuilder,
    $$DownloadQueueTableUpdateCompanionBuilder,
    (
      DownloadQueueData,
      BaseReferences<_$AppDatabase, $DownloadQueueTable, DownloadQueueData>
    ),
    DownloadQueueData,
    PrefetchHooks Function()> {
  $$DownloadQueueTableTableManager(_$AppDatabase db, $DownloadQueueTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DownloadQueueTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DownloadQueueTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DownloadQueueTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> songId = const Value.absent(),
            Value<String> songTitle = const Value.absent(),
            Value<String> artist = const Value.absent(),
            Value<String> savePath = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<int> progress = const Value.absent(),
            Value<String?> quality = const Value.absent(),
            Value<String?> errorMessage = const Value.absent(),
            Value<DateTime> addedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DownloadQueueCompanion(
            songId: songId,
            songTitle: songTitle,
            artist: artist,
            savePath: savePath,
            status: status,
            progress: progress,
            quality: quality,
            errorMessage: errorMessage,
            addedAt: addedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String songId,
            required String songTitle,
            required String artist,
            required String savePath,
            Value<String> status = const Value.absent(),
            Value<int> progress = const Value.absent(),
            Value<String?> quality = const Value.absent(),
            Value<String?> errorMessage = const Value.absent(),
            Value<DateTime> addedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DownloadQueueCompanion.insert(
            songId: songId,
            songTitle: songTitle,
            artist: artist,
            savePath: savePath,
            status: status,
            progress: progress,
            quality: quality,
            errorMessage: errorMessage,
            addedAt: addedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$DownloadQueueTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $DownloadQueueTable,
    DownloadQueueData,
    $$DownloadQueueTableFilterComposer,
    $$DownloadQueueTableOrderingComposer,
    $$DownloadQueueTableAnnotationComposer,
    $$DownloadQueueTableCreateCompanionBuilder,
    $$DownloadQueueTableUpdateCompanionBuilder,
    (
      DownloadQueueData,
      BaseReferences<_$AppDatabase, $DownloadQueueTable, DownloadQueueData>
    ),
    DownloadQueueData,
    PrefetchHooks Function()>;
typedef $$LyricsCacheTableCreateCompanionBuilder = LyricsCacheCompanion
    Function({
  required String songId,
  Value<String?> plainLyrics,
  Value<String?> syncedLyrics,
  Value<DateTime> cachedAt,
  Value<int> rowid,
});
typedef $$LyricsCacheTableUpdateCompanionBuilder = LyricsCacheCompanion
    Function({
  Value<String> songId,
  Value<String?> plainLyrics,
  Value<String?> syncedLyrics,
  Value<DateTime> cachedAt,
  Value<int> rowid,
});

class $$LyricsCacheTableFilterComposer
    extends Composer<_$AppDatabase, $LyricsCacheTable> {
  $$LyricsCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get songId => $composableBuilder(
      column: $table.songId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get plainLyrics => $composableBuilder(
      column: $table.plainLyrics, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get syncedLyrics => $composableBuilder(
      column: $table.syncedLyrics, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
      column: $table.cachedAt, builder: (column) => ColumnFilters(column));
}

class $$LyricsCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $LyricsCacheTable> {
  $$LyricsCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get songId => $composableBuilder(
      column: $table.songId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get plainLyrics => $composableBuilder(
      column: $table.plainLyrics, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get syncedLyrics => $composableBuilder(
      column: $table.syncedLyrics,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
      column: $table.cachedAt, builder: (column) => ColumnOrderings(column));
}

class $$LyricsCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $LyricsCacheTable> {
  $$LyricsCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get songId =>
      $composableBuilder(column: $table.songId, builder: (column) => column);

  GeneratedColumn<String> get plainLyrics => $composableBuilder(
      column: $table.plainLyrics, builder: (column) => column);

  GeneratedColumn<String> get syncedLyrics => $composableBuilder(
      column: $table.syncedLyrics, builder: (column) => column);

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);
}

class $$LyricsCacheTableTableManager extends RootTableManager<
    _$AppDatabase,
    $LyricsCacheTable,
    LyricsCacheData,
    $$LyricsCacheTableFilterComposer,
    $$LyricsCacheTableOrderingComposer,
    $$LyricsCacheTableAnnotationComposer,
    $$LyricsCacheTableCreateCompanionBuilder,
    $$LyricsCacheTableUpdateCompanionBuilder,
    (
      LyricsCacheData,
      BaseReferences<_$AppDatabase, $LyricsCacheTable, LyricsCacheData>
    ),
    LyricsCacheData,
    PrefetchHooks Function()> {
  $$LyricsCacheTableTableManager(_$AppDatabase db, $LyricsCacheTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LyricsCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LyricsCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LyricsCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> songId = const Value.absent(),
            Value<String?> plainLyrics = const Value.absent(),
            Value<String?> syncedLyrics = const Value.absent(),
            Value<DateTime> cachedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LyricsCacheCompanion(
            songId: songId,
            plainLyrics: plainLyrics,
            syncedLyrics: syncedLyrics,
            cachedAt: cachedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String songId,
            Value<String?> plainLyrics = const Value.absent(),
            Value<String?> syncedLyrics = const Value.absent(),
            Value<DateTime> cachedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LyricsCacheCompanion.insert(
            songId: songId,
            plainLyrics: plainLyrics,
            syncedLyrics: syncedLyrics,
            cachedAt: cachedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LyricsCacheTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $LyricsCacheTable,
    LyricsCacheData,
    $$LyricsCacheTableFilterComposer,
    $$LyricsCacheTableOrderingComposer,
    $$LyricsCacheTableAnnotationComposer,
    $$LyricsCacheTableCreateCompanionBuilder,
    $$LyricsCacheTableUpdateCompanionBuilder,
    (
      LyricsCacheData,
      BaseReferences<_$AppDatabase, $LyricsCacheTable, LyricsCacheData>
    ),
    LyricsCacheData,
    PrefetchHooks Function()>;
typedef $$PendingLikesTableCreateCompanionBuilder = PendingLikesCompanion
    Function({
  Value<int> deezerId,
  required String title,
  required String artist,
  required String album,
  Value<int?> duration,
  Value<String?> coverUrl,
  Value<String?> previewUrl,
  Value<DateTime> likedAt,
});
typedef $$PendingLikesTableUpdateCompanionBuilder = PendingLikesCompanion
    Function({
  Value<int> deezerId,
  Value<String> title,
  Value<String> artist,
  Value<String> album,
  Value<int?> duration,
  Value<String?> coverUrl,
  Value<String?> previewUrl,
  Value<DateTime> likedAt,
});

class $$PendingLikesTableFilterComposer
    extends Composer<_$AppDatabase, $PendingLikesTable> {
  $$PendingLikesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get deezerId => $composableBuilder(
      column: $table.deezerId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get artist => $composableBuilder(
      column: $table.artist, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get album => $composableBuilder(
      column: $table.album, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get duration => $composableBuilder(
      column: $table.duration, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get coverUrl => $composableBuilder(
      column: $table.coverUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get previewUrl => $composableBuilder(
      column: $table.previewUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get likedAt => $composableBuilder(
      column: $table.likedAt, builder: (column) => ColumnFilters(column));
}

class $$PendingLikesTableOrderingComposer
    extends Composer<_$AppDatabase, $PendingLikesTable> {
  $$PendingLikesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get deezerId => $composableBuilder(
      column: $table.deezerId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get artist => $composableBuilder(
      column: $table.artist, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get album => $composableBuilder(
      column: $table.album, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get duration => $composableBuilder(
      column: $table.duration, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get coverUrl => $composableBuilder(
      column: $table.coverUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get previewUrl => $composableBuilder(
      column: $table.previewUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get likedAt => $composableBuilder(
      column: $table.likedAt, builder: (column) => ColumnOrderings(column));
}

class $$PendingLikesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PendingLikesTable> {
  $$PendingLikesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get deezerId =>
      $composableBuilder(column: $table.deezerId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get artist =>
      $composableBuilder(column: $table.artist, builder: (column) => column);

  GeneratedColumn<String> get album =>
      $composableBuilder(column: $table.album, builder: (column) => column);

  GeneratedColumn<int> get duration =>
      $composableBuilder(column: $table.duration, builder: (column) => column);

  GeneratedColumn<String> get coverUrl =>
      $composableBuilder(column: $table.coverUrl, builder: (column) => column);

  GeneratedColumn<String> get previewUrl => $composableBuilder(
      column: $table.previewUrl, builder: (column) => column);

  GeneratedColumn<DateTime> get likedAt =>
      $composableBuilder(column: $table.likedAt, builder: (column) => column);
}

class $$PendingLikesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PendingLikesTable,
    PendingLike,
    $$PendingLikesTableFilterComposer,
    $$PendingLikesTableOrderingComposer,
    $$PendingLikesTableAnnotationComposer,
    $$PendingLikesTableCreateCompanionBuilder,
    $$PendingLikesTableUpdateCompanionBuilder,
    (
      PendingLike,
      BaseReferences<_$AppDatabase, $PendingLikesTable, PendingLike>
    ),
    PendingLike,
    PrefetchHooks Function()> {
  $$PendingLikesTableTableManager(_$AppDatabase db, $PendingLikesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingLikesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingLikesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PendingLikesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> deezerId = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String> artist = const Value.absent(),
            Value<String> album = const Value.absent(),
            Value<int?> duration = const Value.absent(),
            Value<String?> coverUrl = const Value.absent(),
            Value<String?> previewUrl = const Value.absent(),
            Value<DateTime> likedAt = const Value.absent(),
          }) =>
              PendingLikesCompanion(
            deezerId: deezerId,
            title: title,
            artist: artist,
            album: album,
            duration: duration,
            coverUrl: coverUrl,
            previewUrl: previewUrl,
            likedAt: likedAt,
          ),
          createCompanionCallback: ({
            Value<int> deezerId = const Value.absent(),
            required String title,
            required String artist,
            required String album,
            Value<int?> duration = const Value.absent(),
            Value<String?> coverUrl = const Value.absent(),
            Value<String?> previewUrl = const Value.absent(),
            Value<DateTime> likedAt = const Value.absent(),
          }) =>
              PendingLikesCompanion.insert(
            deezerId: deezerId,
            title: title,
            artist: artist,
            album: album,
            duration: duration,
            coverUrl: coverUrl,
            previewUrl: previewUrl,
            likedAt: likedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PendingLikesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PendingLikesTable,
    PendingLike,
    $$PendingLikesTableFilterComposer,
    $$PendingLikesTableOrderingComposer,
    $$PendingLikesTableAnnotationComposer,
    $$PendingLikesTableCreateCompanionBuilder,
    $$PendingLikesTableUpdateCompanionBuilder,
    (
      PendingLike,
      BaseReferences<_$AppDatabase, $PendingLikesTable, PendingLike>
    ),
    PendingLike,
    PrefetchHooks Function()>;
typedef $$DismissedRecsTableCreateCompanionBuilder = DismissedRecsCompanion
    Function({
  required String key,
  required String kind,
  required String artist,
  Value<String?> title,
  Value<String?> coverUrl,
  Value<DateTime> dismissedAt,
  Value<int> rowid,
});
typedef $$DismissedRecsTableUpdateCompanionBuilder = DismissedRecsCompanion
    Function({
  Value<String> key,
  Value<String> kind,
  Value<String> artist,
  Value<String?> title,
  Value<String?> coverUrl,
  Value<DateTime> dismissedAt,
  Value<int> rowid,
});

class $$DismissedRecsTableFilterComposer
    extends Composer<_$AppDatabase, $DismissedRecsTable> {
  $$DismissedRecsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get artist => $composableBuilder(
      column: $table.artist, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get coverUrl => $composableBuilder(
      column: $table.coverUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get dismissedAt => $composableBuilder(
      column: $table.dismissedAt, builder: (column) => ColumnFilters(column));
}

class $$DismissedRecsTableOrderingComposer
    extends Composer<_$AppDatabase, $DismissedRecsTable> {
  $$DismissedRecsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get artist => $composableBuilder(
      column: $table.artist, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get coverUrl => $composableBuilder(
      column: $table.coverUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get dismissedAt => $composableBuilder(
      column: $table.dismissedAt, builder: (column) => ColumnOrderings(column));
}

class $$DismissedRecsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DismissedRecsTable> {
  $$DismissedRecsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get artist =>
      $composableBuilder(column: $table.artist, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get coverUrl =>
      $composableBuilder(column: $table.coverUrl, builder: (column) => column);

  GeneratedColumn<DateTime> get dismissedAt => $composableBuilder(
      column: $table.dismissedAt, builder: (column) => column);
}

class $$DismissedRecsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $DismissedRecsTable,
    DismissedRec,
    $$DismissedRecsTableFilterComposer,
    $$DismissedRecsTableOrderingComposer,
    $$DismissedRecsTableAnnotationComposer,
    $$DismissedRecsTableCreateCompanionBuilder,
    $$DismissedRecsTableUpdateCompanionBuilder,
    (
      DismissedRec,
      BaseReferences<_$AppDatabase, $DismissedRecsTable, DismissedRec>
    ),
    DismissedRec,
    PrefetchHooks Function()> {
  $$DismissedRecsTableTableManager(_$AppDatabase db, $DismissedRecsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DismissedRecsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DismissedRecsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DismissedRecsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> kind = const Value.absent(),
            Value<String> artist = const Value.absent(),
            Value<String?> title = const Value.absent(),
            Value<String?> coverUrl = const Value.absent(),
            Value<DateTime> dismissedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DismissedRecsCompanion(
            key: key,
            kind: kind,
            artist: artist,
            title: title,
            coverUrl: coverUrl,
            dismissedAt: dismissedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String key,
            required String kind,
            required String artist,
            Value<String?> title = const Value.absent(),
            Value<String?> coverUrl = const Value.absent(),
            Value<DateTime> dismissedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DismissedRecsCompanion.insert(
            key: key,
            kind: kind,
            artist: artist,
            title: title,
            coverUrl: coverUrl,
            dismissedAt: dismissedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$DismissedRecsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $DismissedRecsTable,
    DismissedRec,
    $$DismissedRecsTableFilterComposer,
    $$DismissedRecsTableOrderingComposer,
    $$DismissedRecsTableAnnotationComposer,
    $$DismissedRecsTableCreateCompanionBuilder,
    $$DismissedRecsTableUpdateCompanionBuilder,
    (
      DismissedRec,
      BaseReferences<_$AppDatabase, $DismissedRecsTable, DismissedRec>
    ),
    DismissedRec,
    PrefetchHooks Function()>;
typedef $$RecImpressionsTableCreateCompanionBuilder = RecImpressionsCompanion
    Function({
  required String trackKey,
  Value<int> shown,
  Value<int> rowid,
});
typedef $$RecImpressionsTableUpdateCompanionBuilder = RecImpressionsCompanion
    Function({
  Value<String> trackKey,
  Value<int> shown,
  Value<int> rowid,
});

class $$RecImpressionsTableFilterComposer
    extends Composer<_$AppDatabase, $RecImpressionsTable> {
  $$RecImpressionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get trackKey => $composableBuilder(
      column: $table.trackKey, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get shown => $composableBuilder(
      column: $table.shown, builder: (column) => ColumnFilters(column));
}

class $$RecImpressionsTableOrderingComposer
    extends Composer<_$AppDatabase, $RecImpressionsTable> {
  $$RecImpressionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get trackKey => $composableBuilder(
      column: $table.trackKey, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get shown => $composableBuilder(
      column: $table.shown, builder: (column) => ColumnOrderings(column));
}

class $$RecImpressionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RecImpressionsTable> {
  $$RecImpressionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get trackKey =>
      $composableBuilder(column: $table.trackKey, builder: (column) => column);

  GeneratedColumn<int> get shown =>
      $composableBuilder(column: $table.shown, builder: (column) => column);
}

class $$RecImpressionsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $RecImpressionsTable,
    RecImpression,
    $$RecImpressionsTableFilterComposer,
    $$RecImpressionsTableOrderingComposer,
    $$RecImpressionsTableAnnotationComposer,
    $$RecImpressionsTableCreateCompanionBuilder,
    $$RecImpressionsTableUpdateCompanionBuilder,
    (
      RecImpression,
      BaseReferences<_$AppDatabase, $RecImpressionsTable, RecImpression>
    ),
    RecImpression,
    PrefetchHooks Function()> {
  $$RecImpressionsTableTableManager(
      _$AppDatabase db, $RecImpressionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecImpressionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecImpressionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecImpressionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> trackKey = const Value.absent(),
            Value<int> shown = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              RecImpressionsCompanion(
            trackKey: trackKey,
            shown: shown,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String trackKey,
            Value<int> shown = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              RecImpressionsCompanion.insert(
            trackKey: trackKey,
            shown: shown,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$RecImpressionsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $RecImpressionsTable,
    RecImpression,
    $$RecImpressionsTableFilterComposer,
    $$RecImpressionsTableOrderingComposer,
    $$RecImpressionsTableAnnotationComposer,
    $$RecImpressionsTableCreateCompanionBuilder,
    $$RecImpressionsTableUpdateCompanionBuilder,
    (
      RecImpression,
      BaseReferences<_$AppDatabase, $RecImpressionsTable, RecImpression>
    ),
    RecImpression,
    PrefetchHooks Function()>;
typedef $$MoreLikeThisTapsTableCreateCompanionBuilder
    = MoreLikeThisTapsCompanion Function({
  required String artist,
  Value<int> taps,
  Value<int> rowid,
});
typedef $$MoreLikeThisTapsTableUpdateCompanionBuilder
    = MoreLikeThisTapsCompanion Function({
  Value<String> artist,
  Value<int> taps,
  Value<int> rowid,
});

class $$MoreLikeThisTapsTableFilterComposer
    extends Composer<_$AppDatabase, $MoreLikeThisTapsTable> {
  $$MoreLikeThisTapsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get artist => $composableBuilder(
      column: $table.artist, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get taps => $composableBuilder(
      column: $table.taps, builder: (column) => ColumnFilters(column));
}

class $$MoreLikeThisTapsTableOrderingComposer
    extends Composer<_$AppDatabase, $MoreLikeThisTapsTable> {
  $$MoreLikeThisTapsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get artist => $composableBuilder(
      column: $table.artist, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get taps => $composableBuilder(
      column: $table.taps, builder: (column) => ColumnOrderings(column));
}

class $$MoreLikeThisTapsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MoreLikeThisTapsTable> {
  $$MoreLikeThisTapsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get artist =>
      $composableBuilder(column: $table.artist, builder: (column) => column);

  GeneratedColumn<int> get taps =>
      $composableBuilder(column: $table.taps, builder: (column) => column);
}

class $$MoreLikeThisTapsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $MoreLikeThisTapsTable,
    MoreLikeThisTap,
    $$MoreLikeThisTapsTableFilterComposer,
    $$MoreLikeThisTapsTableOrderingComposer,
    $$MoreLikeThisTapsTableAnnotationComposer,
    $$MoreLikeThisTapsTableCreateCompanionBuilder,
    $$MoreLikeThisTapsTableUpdateCompanionBuilder,
    (
      MoreLikeThisTap,
      BaseReferences<_$AppDatabase, $MoreLikeThisTapsTable, MoreLikeThisTap>
    ),
    MoreLikeThisTap,
    PrefetchHooks Function()> {
  $$MoreLikeThisTapsTableTableManager(
      _$AppDatabase db, $MoreLikeThisTapsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MoreLikeThisTapsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MoreLikeThisTapsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MoreLikeThisTapsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> artist = const Value.absent(),
            Value<int> taps = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              MoreLikeThisTapsCompanion(
            artist: artist,
            taps: taps,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String artist,
            Value<int> taps = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              MoreLikeThisTapsCompanion.insert(
            artist: artist,
            taps: taps,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$MoreLikeThisTapsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $MoreLikeThisTapsTable,
    MoreLikeThisTap,
    $$MoreLikeThisTapsTableFilterComposer,
    $$MoreLikeThisTapsTableOrderingComposer,
    $$MoreLikeThisTapsTableAnnotationComposer,
    $$MoreLikeThisTapsTableCreateCompanionBuilder,
    $$MoreLikeThisTapsTableUpdateCompanionBuilder,
    (
      MoreLikeThisTap,
      BaseReferences<_$AppDatabase, $MoreLikeThisTapsTable, MoreLikeThisTap>
    ),
    MoreLikeThisTap,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CachedSongsTableTableManager get cachedSongs =>
      $$CachedSongsTableTableManager(_db, _db.cachedSongs);
  $$PlayHistoryTableTableManager get playHistory =>
      $$PlayHistoryTableTableManager(_db, _db.playHistory);
  $$ServerConfigTableTableManager get serverConfig =>
      $$ServerConfigTableTableManager(_db, _db.serverConfig);
  $$DownloadQueueTableTableManager get downloadQueue =>
      $$DownloadQueueTableTableManager(_db, _db.downloadQueue);
  $$LyricsCacheTableTableManager get lyricsCache =>
      $$LyricsCacheTableTableManager(_db, _db.lyricsCache);
  $$PendingLikesTableTableManager get pendingLikes =>
      $$PendingLikesTableTableManager(_db, _db.pendingLikes);
  $$DismissedRecsTableTableManager get dismissedRecs =>
      $$DismissedRecsTableTableManager(_db, _db.dismissedRecs);
  $$RecImpressionsTableTableManager get recImpressions =>
      $$RecImpressionsTableTableManager(_db, _db.recImpressions);
  $$MoreLikeThisTapsTableTableManager get moreLikeThisTaps =>
      $$MoreLikeThisTapsTableTableManager(_db, _db.moreLikeThisTaps);
}
