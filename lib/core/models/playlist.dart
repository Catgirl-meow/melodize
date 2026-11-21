class Playlist {
  final String id;
  final String name;
  final String? comment;
  final int songCount;
  final int duration;
  final String? coverArt;
  final String changed;

  /// Navidrome user name of the owner. Null when the server doesn't say.
  final String? owner;
  final bool public;

  /// OpenSubsonic `readonly`: Navidrome sets it on smart playlists (and on
  /// playlists the user can't change).
  final bool readonly;

  const Playlist({
    required this.id,
    required this.name,
    this.comment,
    required this.songCount,
    required this.duration,
    this.coverArt,
    required this.changed,
    this.owner,
    this.public = false,
    this.readonly = false,
  });

  factory Playlist.fromSubsonicJson(Map<String, dynamic> json) {
    final comment = json['comment']?.toString();
    return Playlist(
      id: json['id'].toString(),
      name: json['name']?.toString() ?? 'Unnamed Playlist',
      comment: comment == null || comment.trim().isEmpty ? null : comment,
      songCount: (json['songCount'] as num?)?.toInt() ?? 0,
      duration: (json['duration'] as num?)?.toInt() ?? 0,
      coverArt: json['coverArt']?.toString(),
      changed: json['changed']?.toString() ?? '',
      owner: json['owner']?.toString(),
      public: json['public'] == true,
      readonly: json['readonly'] == true,
    );
  }

  /// Same shape as the Subsonic JSON, so the offline cache can store it.
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (comment != null) 'comment': comment,
        'songCount': songCount,
        'duration': duration,
        if (coverArt != null) 'coverArt': coverArt,
        'changed': changed,
        if (owner != null) 'owner': owner,
        'public': public,
        'readonly': readonly,
      };

  /// Whether [username] may rename, edit or delete this playlist: not a
  /// smart playlist and not someone else's.
  bool isEditableBy(String? username) {
    if (readonly) return false;
    if (owner == null || username == null) return true;
    return owner == username;
  }

  DateTime? get changedAt => DateTime.tryParse(changed);

  Playlist copyWith({
    String? name,
    String? comment,
    bool clearComment = false,
    int? songCount,
    int? duration,
    String? changed,
  }) =>
      Playlist(
        id: id,
        name: name ?? this.name,
        comment: clearComment ? null : (comment ?? this.comment),
        songCount: songCount ?? this.songCount,
        duration: duration ?? this.duration,
        coverArt: coverArt,
        changed: changed ?? this.changed,
        owner: owner,
        public: public,
        readonly: readonly,
      );
}
