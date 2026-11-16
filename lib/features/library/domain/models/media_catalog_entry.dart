import 'package:equatable/equatable.dart';
import 'package:read_beat/features/library/domain/models/library_item.dart';
import 'package:read_beat/features/progress/domain/models/media_progress.dart';

/// Lightweight cloud catalog card — never the media binary.
///
/// Enables orphan-resume UX and cross-device matching without file sync.
/// Future [contentStore] listings can share title/author/format fields but are
/// a separate product surface.
final class MediaCatalogEntry extends Equatable {
  const MediaCatalogEntry({
    required this.id,
    required this.userId,
    required this.workId,
    required this.title,
    required this.mediaType,
    required this.format,
    required this.exactHash,
    required this.updatedAt,
    this.author,
    this.softKey,
    this.durationSeconds,
    this.source = MediaCatalogSource.userLibrary,
  });

  final String id;
  final String userId;
  final String workId;
  final String title;
  final String? author;
  final MediaType mediaType;
  final MediaFormat format;
  final String exactHash;
  final String? softKey;
  final double? durationSeconds;
  final DateTime updatedAt;

  /// Distinguishes user-imported works from a future store acquisition.
  final MediaCatalogSource source;

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'workId': workId,
    'title': title,
    'author': author,
    'mediaType': mediaType.name,
    'format': format.name,
    'exactHash': exactHash,
    'softKey': softKey,
    'durationSeconds': durationSeconds,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'source': source.name,
  };

  factory MediaCatalogEntry.fromJson(Map<String, dynamic> json) {
    return MediaCatalogEntry(
      id: json['id'] as String,
      userId: json['userId'] as String,
      workId: json['workId'] as String,
      title: json['title'] as String,
      author: json['author'] as String?,
      mediaType: MediaType.values.byName(json['mediaType'] as String),
      format: MediaFormat.values.byName(json['format'] as String),
      exactHash: json['exactHash'] as String,
      softKey: json['softKey'] as String?,
      durationSeconds: (json['durationSeconds'] as num?)?.toDouble(),
      updatedAt: DateTime.parse(json['updatedAt'] as String).toUtc(),
      source: MediaCatalogSource.values.byName(
        (json['source'] as String?) ?? MediaCatalogSource.userLibrary.name,
      ),
    );
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    workId,
    title,
    author,
    mediaType,
    format,
    exactHash,
    softKey,
    durationSeconds,
    updatedAt,
    source,
  ];
}

enum MediaCatalogSource {
  /// File the user imported / opened.
  userLibrary,

  /// Reserved: acquired via future in-app content store.
  contentStore,

  /// Reserved: restored from paid cloud file backup.
  cloudBackup,
}
