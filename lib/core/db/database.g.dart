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
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
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
      cachedAt);
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
  @override
  List<GeneratedColumn> get $columns =>
      [historyId, songId, songTitle, artist, coverArt, playedAt];
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
  const PlayHistoryData(
      {required this.historyId,
      required this.songId,
      required this.songTitle,
      required this.artist,
      this.coverArt,
      required this.playedAt});
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
    };
  }

  PlayHistoryData copyWith(
          {int? historyId,
          String? songId,
          String? songTitle,
          String? artist,
          Value<String?> coverArt = const Value.absent(),
          DateTime? playedAt}) =>
      PlayHistoryData(
        historyId: historyId ?? this.historyId,
        songId: songId ?? this.songId,
        songTitle: songTitle ?? this.songTitle,
        artist: artist ?? this.artist,
        coverArt: coverArt.present ? coverArt.value : this.coverArt,
        playedAt: playedAt ?? this.playedAt,
      );
  PlayHistoryData copyWithCompanion(PlayHistoryCompanion data) {
    return PlayHistoryData(
      historyId: data.historyId.present ? data.historyId.value : this.historyId,
      songId: data.songId.present ? data.songId.value : this.songId,
      songTitle: data.songTitle.present ? data.songTitle.value : this.songTitle,
      artist: data.artist.present ? data.artist.value : this.artist,
      coverArt: data.coverArt.present ? data.coverArt.value : this.coverArt,
      playedAt: data.playedAt.present ? data.playedAt.value : this.playedAt,
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
          ..write('playedAt: $playedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(historyId, songId, songTitle, artist, coverArt, playedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlayHistoryData &&
          other.historyId == this.historyId &&
          other.songId == this.songId &&
          other.songTitle == this.songTitle &&
          other.artist == this.artist &&
          other.coverArt == this.coverArt &&
          other.playedAt == this.playedAt);
}

class PlayHistoryCompanion extends UpdateCompanion<PlayHistoryData> {
  final Value<int> historyId;
  final Value<String> songId;
  final Value<String> songTitle;
  final Value<String> artist;
  final Value<String?> coverArt;
  final Value<DateTime> playedAt;
  const PlayHistoryCompanion({
    this.historyId = const Value.absent(),
    this.songId = const Value.absent(),
    this.songTitle = const Value.absent(),
    this.artist = const Value.absent(),
    this.coverArt = const Value.absent(),
    this.playedAt = const Value.absent(),
  });
  PlayHistoryCompanion.insert({
    this.historyId = const Value.absent(),
    required String songId,
    required String songTitle,
    required String artist,
    this.coverArt = const Value.absent(),
    this.playedAt = const Value.absent(),
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
  }) {
    return RawValuesInsertable({
      if (historyId != null) 'history_id': historyId,
      if (songId != null) 'song_id': songId,
      if (songTitle != null) 'song_title': songTitle,
      if (artist != null) 'artist': artist,
      if (coverArt != null) 'cover_art': coverArt,
      if (playedAt != null) 'played_at': playedAt,
    });
  }

  PlayHistoryCompanion copyWith(
      {Value<int>? historyId,
      Value<String>? songId,
      Value<String>? songTitle,
      Value<String>? artist,
      Value<String?>? coverArt,
      Value<DateTime>? playedAt}) {
    return PlayHistoryCompanion(
      historyId: historyId ?? this.historyId,
      songId: songId ?? this.songId,
      songTitle: songTitle ?? this.songTitle,
      artist: artist ?? this.artist,
      coverArt: coverArt ?? this.coverArt,
      playedAt: playedAt ?? this.playedAt,
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
          ..write('playedAt: $playedAt')
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
  static const VerificationMeta _addedAtMeta =
      const VerificationMeta('addedAt');
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
      'added_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns =>
      [songId, songTitle, artist, savePath, status, progress, addedAt];
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
  final DateTime addedAt;
  const DownloadQueueData(
      {required this.songId,
      required this.songTitle,
      required this.artist,
      required this.savePath,
      required this.status,
      required this.progress,
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
          DateTime? addedAt}) =>
      DownloadQueueData(
        songId: songId ?? this.songId,
        songTitle: songTitle ?? this.songTitle,
        artist: artist ?? this.artist,
        savePath: savePath ?? this.savePath,
        status: status ?? this.status,
        progress: progress ?? this.progress,
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
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      songId, songTitle, artist, savePath, status, progress, addedAt);
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
          other.addedAt == this.addedAt);
}

class DownloadQueueCompanion extends UpdateCompanion<DownloadQueueData> {
  final Value<String> songId;
  final Value<String> songTitle;
  final Value<String> artist;
  final Value<String> savePath;
  final Value<String> status;
  final Value<int> progress;
  final Value<DateTime> addedAt;
  final Value<int> rowid;
  const DownloadQueueCompanion({
    this.songId = const Value.absent(),
    this.songTitle = const Value.absent(),
    this.artist = const Value.absent(),
    this.savePath = const Value.absent(),
    this.status = const Value.absent(),
    this.progress = const Value.absent(),
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
      Value<DateTime>? addedAt,
      Value<int>? rowid}) {
    return DownloadQueueCompanion(
      songId: songId ?? this.songId,
      songTitle: songTitle ?? this.songTitle,
      artist: artist ?? this.artist,
      savePath: savePath ?? this.savePath,
      status: status ?? this.status,
      progress: progress ?? this.progress,
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
          ..write('addedAt: $addedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $QueueEntriesTable extends QueueEntries
    with TableInfo<$QueueEntriesTable, QueueEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $QueueEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _positionMeta =
      const VerificationMeta('position');
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
      'position', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
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
  static const VerificationMeta _isCurrentMeta =
      const VerificationMeta('isCurrent');
  @override
  late final GeneratedColumn<bool> isCurrent = GeneratedColumn<bool>(
      'is_current', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_current" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns => [
        position,
        songId,
        songTitle,
        artist,
        album,
        albumId,
        artistId,
        duration,
        coverArt,
        suffix,
        contentType,
        bitRate,
        isDownloaded,
        localPath,
        isCurrent
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'queue_entries';
  @override
  VerificationContext validateIntegrity(Insertable<QueueEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('position')) {
      context.handle(_positionMeta,
          position.isAcceptableOrUnknown(data['position']!, _positionMeta));
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
    if (data.containsKey('is_current')) {
      context.handle(_isCurrentMeta,
          isCurrent.isAcceptableOrUnknown(data['is_current']!, _isCurrentMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {position};
  @override
  QueueEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return QueueEntry(
      position: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}position'])!,
      songId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}song_id'])!,
      songTitle: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}song_title'])!,
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
      coverArt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}cover_art']),
      suffix: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}suffix']),
      contentType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}content_type']),
      bitRate: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}bit_rate']),
      isDownloaded: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_downloaded'])!,
      localPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}local_path']),
      isCurrent: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_current'])!,
    );
  }

  @override
  $QueueEntriesTable createAlias(String alias) {
    return $QueueEntriesTable(attachedDatabase, alias);
  }
}

class QueueEntry extends DataClass implements Insertable<QueueEntry> {
  final int position;
  final String songId;
  final String songTitle;
  final String artist;
  final String album;
  final String? albumId;
  final String? artistId;
  final int? duration;
  final String? coverArt;
  final String? suffix;
  final String? contentType;
  final int? bitRate;
  final bool isDownloaded;
  final String? localPath;
  final bool isCurrent;
  const QueueEntry(
      {required this.position,
      required this.songId,
      required this.songTitle,
      required this.artist,
      required this.album,
      this.albumId,
      this.artistId,
      this.duration,
      this.coverArt,
      this.suffix,
      this.contentType,
      this.bitRate,
      required this.isDownloaded,
      this.localPath,
      required this.isCurrent});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['position'] = Variable<int>(position);
    map['song_id'] = Variable<String>(songId);
    map['song_title'] = Variable<String>(songTitle);
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
    map['is_downloaded'] = Variable<bool>(isDownloaded);
    if (!nullToAbsent || localPath != null) {
      map['local_path'] = Variable<String>(localPath);
    }
    map['is_current'] = Variable<bool>(isCurrent);
    return map;
  }

  QueueEntriesCompanion toCompanion(bool nullToAbsent) {
    return QueueEntriesCompanion(
      position: Value(position),
      songId: Value(songId),
      songTitle: Value(songTitle),
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
      isDownloaded: Value(isDownloaded),
      localPath: localPath == null && nullToAbsent
          ? const Value.absent()
          : Value(localPath),
      isCurrent: Value(isCurrent),
    );
  }

  factory QueueEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return QueueEntry(
      position: serializer.fromJson<int>(json['position']),
      songId: serializer.fromJson<String>(json['songId']),
      songTitle: serializer.fromJson<String>(json['songTitle']),
      artist: serializer.fromJson<String>(json['artist']),
      album: serializer.fromJson<String>(json['album']),
      albumId: serializer.fromJson<String?>(json['albumId']),
      artistId: serializer.fromJson<String?>(json['artistId']),
      duration: serializer.fromJson<int?>(json['duration']),
      coverArt: serializer.fromJson<String?>(json['coverArt']),
      suffix: serializer.fromJson<String?>(json['suffix']),
      contentType: serializer.fromJson<String?>(json['contentType']),
      bitRate: serializer.fromJson<int?>(json['bitRate']),
      isDownloaded: serializer.fromJson<bool>(json['isDownloaded']),
      localPath: serializer.fromJson<String?>(json['localPath']),
      isCurrent: serializer.fromJson<bool>(json['isCurrent']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'position': serializer.toJson<int>(position),
      'songId': serializer.toJson<String>(songId),
      'songTitle': serializer.toJson<String>(songTitle),
      'artist': serializer.toJson<String>(artist),
      'album': serializer.toJson<String>(album),
      'albumId': serializer.toJson<String?>(albumId),
      'artistId': serializer.toJson<String?>(artistId),
      'duration': serializer.toJson<int?>(duration),
      'coverArt': serializer.toJson<String?>(coverArt),
      'suffix': serializer.toJson<String?>(suffix),
      'contentType': serializer.toJson<String?>(contentType),
      'bitRate': serializer.toJson<int?>(bitRate),
      'isDownloaded': serializer.toJson<bool>(isDownloaded),
      'localPath': serializer.toJson<String?>(localPath),
      'isCurrent': serializer.toJson<bool>(isCurrent),
    };
  }

  QueueEntry copyWith(
          {int? position,
          String? songId,
          String? songTitle,
          String? artist,
          String? album,
          Value<String?> albumId = const Value.absent(),
          Value<String?> artistId = const Value.absent(),
          Value<int?> duration = const Value.absent(),
          Value<String?> coverArt = const Value.absent(),
          Value<String?> suffix = const Value.absent(),
          Value<String?> contentType = const Value.absent(),
          Value<int?> bitRate = const Value.absent(),
          bool? isDownloaded,
          Value<String?> localPath = const Value.absent(),
          bool? isCurrent}) =>
      QueueEntry(
        position: position ?? this.position,
        songId: songId ?? this.songId,
        songTitle: songTitle ?? this.songTitle,
        artist: artist ?? this.artist,
        album: album ?? this.album,
        albumId: albumId.present ? albumId.value : this.albumId,
        artistId: artistId.present ? artistId.value : this.artistId,
        duration: duration.present ? duration.value : this.duration,
        coverArt: coverArt.present ? coverArt.value : this.coverArt,
        suffix: suffix.present ? suffix.value : this.suffix,
        contentType: contentType.present ? contentType.value : this.contentType,
        bitRate: bitRate.present ? bitRate.value : this.bitRate,
        isDownloaded: isDownloaded ?? this.isDownloaded,
        localPath: localPath.present ? localPath.value : this.localPath,
        isCurrent: isCurrent ?? this.isCurrent,
      );
  QueueEntry copyWithCompanion(QueueEntriesCompanion data) {
    return QueueEntry(
      position: data.position.present ? data.position.value : this.position,
      songId: data.songId.present ? data.songId.value : this.songId,
      songTitle: data.songTitle.present ? data.songTitle.value : this.songTitle,
      artist: data.artist.present ? data.artist.value : this.artist,
      album: data.album.present ? data.album.value : this.album,
      albumId: data.albumId.present ? data.albumId.value : this.albumId,
      artistId: data.artistId.present ? data.artistId.value : this.artistId,
      duration: data.duration.present ? data.duration.value : this.duration,
      coverArt: data.coverArt.present ? data.coverArt.value : this.coverArt,
      suffix: data.suffix.present ? data.suffix.value : this.suffix,
      contentType:
          data.contentType.present ? data.contentType.value : this.contentType,
      bitRate: data.bitRate.present ? data.bitRate.value : this.bitRate,
      isDownloaded: data.isDownloaded.present
          ? data.isDownloaded.value
          : this.isDownloaded,
      localPath: data.localPath.present ? data.localPath.value : this.localPath,
      isCurrent: data.isCurrent.present ? data.isCurrent.value : this.isCurrent,
    );
  }

  @override
  String toString() {
    return (StringBuffer('QueueEntry(')
          ..write('position: $position, ')
          ..write('songId: $songId, ')
          ..write('songTitle: $songTitle, ')
          ..write('artist: $artist, ')
          ..write('album: $album, ')
          ..write('albumId: $albumId, ')
          ..write('artistId: $artistId, ')
          ..write('duration: $duration, ')
          ..write('coverArt: $coverArt, ')
          ..write('suffix: $suffix, ')
          ..write('contentType: $contentType, ')
          ..write('bitRate: $bitRate, ')
          ..write('isDownloaded: $isDownloaded, ')
          ..write('localPath: $localPath, ')
          ..write('isCurrent: $isCurrent')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      position,
      songId,
      songTitle,
      artist,
      album,
      albumId,
      artistId,
      duration,
      coverArt,
      suffix,
      contentType,
      bitRate,
      isDownloaded,
      localPath,
      isCurrent);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QueueEntry &&
          other.position == this.position &&
          other.songId == this.songId &&
          other.songTitle == this.songTitle &&
          other.artist == this.artist &&
          other.album == this.album &&
          other.albumId == this.albumId &&
          other.artistId == this.artistId &&
          other.duration == this.duration &&
          other.coverArt == this.coverArt &&
          other.suffix == this.suffix &&
          other.contentType == this.contentType &&
          other.bitRate == this.bitRate &&
          other.isDownloaded == this.isDownloaded &&
          other.localPath == this.localPath &&
          other.isCurrent == this.isCurrent);
}

class QueueEntriesCompanion extends UpdateCompanion<QueueEntry> {
  final Value<int> position;
  final Value<String> songId;
  final Value<String> songTitle;
  final Value<String> artist;
  final Value<String> album;
  final Value<String?> albumId;
  final Value<String?> artistId;
  final Value<int?> duration;
  final Value<String?> coverArt;
  final Value<String?> suffix;
  final Value<String?> contentType;
  final Value<int?> bitRate;
  final Value<bool> isDownloaded;
  final Value<String?> localPath;
  final Value<bool> isCurrent;
  const QueueEntriesCompanion({
    this.position = const Value.absent(),
    this.songId = const Value.absent(),
    this.songTitle = const Value.absent(),
    this.artist = const Value.absent(),
    this.album = const Value.absent(),
    this.albumId = const Value.absent(),
    this.artistId = const Value.absent(),
    this.duration = const Value.absent(),
    this.coverArt = const Value.absent(),
    this.suffix = const Value.absent(),
    this.contentType = const Value.absent(),
    this.bitRate = const Value.absent(),
    this.isDownloaded = const Value.absent(),
    this.localPath = const Value.absent(),
    this.isCurrent = const Value.absent(),
  });
  QueueEntriesCompanion.insert({
    this.position = const Value.absent(),
    required String songId,
    required String songTitle,
    required String artist,
    required String album,
    this.albumId = const Value.absent(),
    this.artistId = const Value.absent(),
    this.duration = const Value.absent(),
    this.coverArt = const Value.absent(),
    this.suffix = const Value.absent(),
    this.contentType = const Value.absent(),
    this.bitRate = const Value.absent(),
    this.isDownloaded = const Value.absent(),
    this.localPath = const Value.absent(),
    this.isCurrent = const Value.absent(),
  })  : songId = Value(songId),
        songTitle = Value(songTitle),
        artist = Value(artist),
        album = Value(album);
  static Insertable<QueueEntry> custom({
    Expression<int>? position,
    Expression<String>? songId,
    Expression<String>? songTitle,
    Expression<String>? artist,
    Expression<String>? album,
    Expression<String>? albumId,
    Expression<String>? artistId,
    Expression<int>? duration,
    Expression<String>? coverArt,
    Expression<String>? suffix,
    Expression<String>? contentType,
    Expression<int>? bitRate,
    Expression<bool>? isDownloaded,
    Expression<String>? localPath,
    Expression<bool>? isCurrent,
  }) {
    return RawValuesInsertable({
      if (position != null) 'position': position,
      if (songId != null) 'song_id': songId,
      if (songTitle != null) 'song_title': songTitle,
      if (artist != null) 'artist': artist,
      if (album != null) 'album': album,
      if (albumId != null) 'album_id': albumId,
      if (artistId != null) 'artist_id': artistId,
      if (duration != null) 'duration': duration,
      if (coverArt != null) 'cover_art': coverArt,
      if (suffix != null) 'suffix': suffix,
      if (contentType != null) 'content_type': contentType,
      if (bitRate != null) 'bit_rate': bitRate,
      if (isDownloaded != null) 'is_downloaded': isDownloaded,
      if (localPath != null) 'local_path': localPath,
      if (isCurrent != null) 'is_current': isCurrent,
    });
  }

  QueueEntriesCompanion copyWith(
      {Value<int>? position,
      Value<String>? songId,
      Value<String>? songTitle,
      Value<String>? artist,
      Value<String>? album,
      Value<String?>? albumId,
      Value<String?>? artistId,
      Value<int?>? duration,
      Value<String?>? coverArt,
      Value<String?>? suffix,
      Value<String?>? contentType,
      Value<int?>? bitRate,
      Value<bool>? isDownloaded,
      Value<String?>? localPath,
      Value<bool>? isCurrent}) {
    return QueueEntriesCompanion(
      position: position ?? this.position,
      songId: songId ?? this.songId,
      songTitle: songTitle ?? this.songTitle,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      albumId: albumId ?? this.albumId,
      artistId: artistId ?? this.artistId,
      duration: duration ?? this.duration,
      coverArt: coverArt ?? this.coverArt,
      suffix: suffix ?? this.suffix,
      contentType: contentType ?? this.contentType,
      bitRate: bitRate ?? this.bitRate,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      localPath: localPath ?? this.localPath,
      isCurrent: isCurrent ?? this.isCurrent,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (position.present) {
      map['position'] = Variable<int>(position.value);
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
    if (isDownloaded.present) {
      map['is_downloaded'] = Variable<bool>(isDownloaded.value);
    }
    if (localPath.present) {
      map['local_path'] = Variable<String>(localPath.value);
    }
    if (isCurrent.present) {
      map['is_current'] = Variable<bool>(isCurrent.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('QueueEntriesCompanion(')
          ..write('position: $position, ')
          ..write('songId: $songId, ')
          ..write('songTitle: $songTitle, ')
          ..write('artist: $artist, ')
          ..write('album: $album, ')
          ..write('albumId: $albumId, ')
          ..write('artistId: $artistId, ')
          ..write('duration: $duration, ')
          ..write('coverArt: $coverArt, ')
          ..write('suffix: $suffix, ')
          ..write('contentType: $contentType, ')
          ..write('bitRate: $bitRate, ')
          ..write('isDownloaded: $isDownloaded, ')
          ..write('localPath: $localPath, ')
          ..write('isCurrent: $isCurrent')
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

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CachedSongsTable cachedSongs = $CachedSongsTable(this);
  late final $PlayHistoryTable playHistory = $PlayHistoryTable(this);
  late final $ServerConfigTable serverConfig = $ServerConfigTable(this);
  late final $DownloadQueueTable downloadQueue = $DownloadQueueTable(this);
  late final $QueueEntriesTable queueEntries = $QueueEntriesTable(this);
  late final $LyricsCacheTable lyricsCache = $LyricsCacheTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        cachedSongs,
        playHistory,
        serverConfig,
        downloadQueue,
        queueEntries,
        lyricsCache
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
});
typedef $$PlayHistoryTableUpdateCompanionBuilder = PlayHistoryCompanion
    Function({
  Value<int> historyId,
  Value<String> songId,
  Value<String> songTitle,
  Value<String> artist,
  Value<String?> coverArt,
  Value<DateTime> playedAt,
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
          }) =>
              PlayHistoryCompanion(
            historyId: historyId,
            songId: songId,
            songTitle: songTitle,
            artist: artist,
            coverArt: coverArt,
            playedAt: playedAt,
          ),
          createCompanionCallback: ({
            Value<int> historyId = const Value.absent(),
            required String songId,
            required String songTitle,
            required String artist,
            Value<String?> coverArt = const Value.absent(),
            Value<DateTime> playedAt = const Value.absent(),
          }) =>
              PlayHistoryCompanion.insert(
            historyId: historyId,
            songId: songId,
            songTitle: songTitle,
            artist: artist,
            coverArt: coverArt,
            playedAt: playedAt,
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
typedef $$QueueEntriesTableCreateCompanionBuilder = QueueEntriesCompanion
    Function({
  Value<int> position,
  required String songId,
  required String songTitle,
  required String artist,
  required String album,
  Value<String?> albumId,
  Value<String?> artistId,
  Value<int?> duration,
  Value<String?> coverArt,
  Value<String?> suffix,
  Value<String?> contentType,
  Value<int?> bitRate,
  Value<bool> isDownloaded,
  Value<String?> localPath,
  Value<bool> isCurrent,
});
typedef $$QueueEntriesTableUpdateCompanionBuilder = QueueEntriesCompanion
    Function({
  Value<int> position,
  Value<String> songId,
  Value<String> songTitle,
  Value<String> artist,
  Value<String> album,
  Value<String?> albumId,
  Value<String?> artistId,
  Value<int?> duration,
  Value<String?> coverArt,
  Value<String?> suffix,
  Value<String?> contentType,
  Value<int?> bitRate,
  Value<bool> isDownloaded,
  Value<String?> localPath,
  Value<bool> isCurrent,
});

class $$QueueEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $QueueEntriesTable> {
  $$QueueEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get position => $composableBuilder(
      column: $table.position, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get songId => $composableBuilder(
      column: $table.songId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get songTitle => $composableBuilder(
      column: $table.songTitle, builder: (column) => ColumnFilters(column));

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

  ColumnFilters<String> get coverArt => $composableBuilder(
      column: $table.coverArt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get suffix => $composableBuilder(
      column: $table.suffix, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get contentType => $composableBuilder(
      column: $table.contentType, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get bitRate => $composableBuilder(
      column: $table.bitRate, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isDownloaded => $composableBuilder(
      column: $table.isDownloaded, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get localPath => $composableBuilder(
      column: $table.localPath, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isCurrent => $composableBuilder(
      column: $table.isCurrent, builder: (column) => ColumnFilters(column));
}

class $$QueueEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $QueueEntriesTable> {
  $$QueueEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get position => $composableBuilder(
      column: $table.position, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get songId => $composableBuilder(
      column: $table.songId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get songTitle => $composableBuilder(
      column: $table.songTitle, builder: (column) => ColumnOrderings(column));

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

  ColumnOrderings<String> get coverArt => $composableBuilder(
      column: $table.coverArt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get suffix => $composableBuilder(
      column: $table.suffix, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get contentType => $composableBuilder(
      column: $table.contentType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get bitRate => $composableBuilder(
      column: $table.bitRate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isDownloaded => $composableBuilder(
      column: $table.isDownloaded,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get localPath => $composableBuilder(
      column: $table.localPath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isCurrent => $composableBuilder(
      column: $table.isCurrent, builder: (column) => ColumnOrderings(column));
}

class $$QueueEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $QueueEntriesTable> {
  $$QueueEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get songId =>
      $composableBuilder(column: $table.songId, builder: (column) => column);

  GeneratedColumn<String> get songTitle =>
      $composableBuilder(column: $table.songTitle, builder: (column) => column);

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

  GeneratedColumn<String> get coverArt =>
      $composableBuilder(column: $table.coverArt, builder: (column) => column);

  GeneratedColumn<String> get suffix =>
      $composableBuilder(column: $table.suffix, builder: (column) => column);

  GeneratedColumn<String> get contentType => $composableBuilder(
      column: $table.contentType, builder: (column) => column);

  GeneratedColumn<int> get bitRate =>
      $composableBuilder(column: $table.bitRate, builder: (column) => column);

  GeneratedColumn<bool> get isDownloaded => $composableBuilder(
      column: $table.isDownloaded, builder: (column) => column);

  GeneratedColumn<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => column);

  GeneratedColumn<bool> get isCurrent =>
      $composableBuilder(column: $table.isCurrent, builder: (column) => column);
}

class $$QueueEntriesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $QueueEntriesTable,
    QueueEntry,
    $$QueueEntriesTableFilterComposer,
    $$QueueEntriesTableOrderingComposer,
    $$QueueEntriesTableAnnotationComposer,
    $$QueueEntriesTableCreateCompanionBuilder,
    $$QueueEntriesTableUpdateCompanionBuilder,
    (QueueEntry, BaseReferences<_$AppDatabase, $QueueEntriesTable, QueueEntry>),
    QueueEntry,
    PrefetchHooks Function()> {
  $$QueueEntriesTableTableManager(_$AppDatabase db, $QueueEntriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$QueueEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$QueueEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$QueueEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> position = const Value.absent(),
            Value<String> songId = const Value.absent(),
            Value<String> songTitle = const Value.absent(),
            Value<String> artist = const Value.absent(),
            Value<String> album = const Value.absent(),
            Value<String?> albumId = const Value.absent(),
            Value<String?> artistId = const Value.absent(),
            Value<int?> duration = const Value.absent(),
            Value<String?> coverArt = const Value.absent(),
            Value<String?> suffix = const Value.absent(),
            Value<String?> contentType = const Value.absent(),
            Value<int?> bitRate = const Value.absent(),
            Value<bool> isDownloaded = const Value.absent(),
            Value<String?> localPath = const Value.absent(),
            Value<bool> isCurrent = const Value.absent(),
          }) =>
              QueueEntriesCompanion(
            position: position,
            songId: songId,
            songTitle: songTitle,
            artist: artist,
            album: album,
            albumId: albumId,
            artistId: artistId,
            duration: duration,
            coverArt: coverArt,
            suffix: suffix,
            contentType: contentType,
            bitRate: bitRate,
            isDownloaded: isDownloaded,
            localPath: localPath,
            isCurrent: isCurrent,
          ),
          createCompanionCallback: ({
            Value<int> position = const Value.absent(),
            required String songId,
            required String songTitle,
            required String artist,
            required String album,
            Value<String?> albumId = const Value.absent(),
            Value<String?> artistId = const Value.absent(),
            Value<int?> duration = const Value.absent(),
            Value<String?> coverArt = const Value.absent(),
            Value<String?> suffix = const Value.absent(),
            Value<String?> contentType = const Value.absent(),
            Value<int?> bitRate = const Value.absent(),
            Value<bool> isDownloaded = const Value.absent(),
            Value<String?> localPath = const Value.absent(),
            Value<bool> isCurrent = const Value.absent(),
          }) =>
              QueueEntriesCompanion.insert(
            position: position,
            songId: songId,
            songTitle: songTitle,
            artist: artist,
            album: album,
            albumId: albumId,
            artistId: artistId,
            duration: duration,
            coverArt: coverArt,
            suffix: suffix,
            contentType: contentType,
            bitRate: bitRate,
            isDownloaded: isDownloaded,
            localPath: localPath,
            isCurrent: isCurrent,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$QueueEntriesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $QueueEntriesTable,
    QueueEntry,
    $$QueueEntriesTableFilterComposer,
    $$QueueEntriesTableOrderingComposer,
    $$QueueEntriesTableAnnotationComposer,
    $$QueueEntriesTableCreateCompanionBuilder,
    $$QueueEntriesTableUpdateCompanionBuilder,
    (QueueEntry, BaseReferences<_$AppDatabase, $QueueEntriesTable, QueueEntry>),
    QueueEntry,
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
  $$QueueEntriesTableTableManager get queueEntries =>
      $$QueueEntriesTableTableManager(_db, _db.queueEntries);
  $$LyricsCacheTableTableManager get lyricsCache =>
      $$LyricsCacheTableTableManager(_db, _db.lyricsCache);
}
