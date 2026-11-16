import 'package:equatable/equatable.dart';

final class PlaylistTrack extends Equatable {
  const PlaylistTrack({
    required this.id,
    required this.playlistId,
    required this.mediaId,
    required this.workId,
    required this.sortIndex,
    required this.addedAt,
  });

  final String id;
  final String playlistId;
  final String mediaId;
  final String workId;
  final int sortIndex;
  final DateTime addedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'playlistId': playlistId,
    'mediaId': mediaId,
    'workId': workId,
    'sortIndex': sortIndex,
    'addedAt': addedAt.toUtc().toIso8601String(),
  };

  factory PlaylistTrack.fromJson(Map<String, dynamic> json) {
    return PlaylistTrack(
      id: json['id'] as String,
      playlistId: json['playlistId'] as String? ?? '',
      mediaId: json['mediaId'] as String? ?? '',
      workId: json['workId'] as String,
      sortIndex: (json['sortIndex'] as num?)?.toInt() ?? 0,
      addedAt: DateTime.parse(
        (json['addedAt'] as String?) ?? DateTime.now().toUtc().toIso8601String(),
      ).toUtc(),
    );
  }

  @override
  List<Object?> get props => [id, playlistId, mediaId, workId, sortIndex, addedAt];
}

/// Simple audio queue owned by a user (or guest `local`).
final class AudioPlaylist extends Equatable {
  const AudioPlaylist({
    required this.id,
    required this.userId,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.tracks = const [],
  });

  final String id;
  final String userId;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<PlaylistTrack> tracks;

  int get trackCount => tracks.length;

  AudioPlaylist copyWith({
    String? userId,
    String? title,
    DateTime? updatedAt,
    List<PlaylistTrack>? tracks,
  }) {
    return AudioPlaylist(
      id: id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      tracks: tracks ?? this.tracks,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'title': title,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'tracks': tracks.map((t) => t.toJson()).toList(),
  };

  factory AudioPlaylist.fromJson(Map<String, dynamic> json) {
    final rawTracks = json['tracks'];
    final tracks = <PlaylistTrack>[];
    if (rawTracks is List) {
      for (final item in rawTracks) {
        if (item is Map<String, dynamic>) {
          tracks.add(PlaylistTrack.fromJson(item));
        } else if (item is Map) {
          tracks.add(PlaylistTrack.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }
    tracks.sort((a, b) => a.sortIndex.compareTo(b.sortIndex));
    return AudioPlaylist(
      id: json['id'] as String,
      userId: json['userId'] as String,
      title: json['title'] as String,
      createdAt: DateTime.parse(
        (json['createdAt'] as String?) ?? json['updatedAt'] as String,
      ).toUtc(),
      updatedAt: DateTime.parse(json['updatedAt'] as String).toUtc(),
      tracks: tracks,
    );
  }

  @override
  List<Object?> get props => [id, userId, title, createdAt, updatedAt, tracks];
}
