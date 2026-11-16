import 'package:equatable/equatable.dart';

enum MediaType { ebook, audio }

/// Unified reading/listening progress — local-first source of truth.
///
/// Position contract:
/// - **audio**: [position] = seconds from start; [duration] = total seconds
/// - **PDF**: [position] = 0-based page index; [percent] ≈ (page+1)/pageCount
/// - **EPUB**: [percent] = vertical scroll fraction 0–1 (preferred);
///   [position] mirrors that fraction for legacy rows
///
/// Cross-device identity uses [workId] (same work across encodings).
/// [mediaId] is the local library item id on this device.
///
/// [cfi] is reserved for future EPUB CFI precision; readers may leave it null.
final class MediaProgress extends Equatable {
  const MediaProgress({
    required this.id,
    required this.userId,
    required this.mediaId,
    required this.workId,
    required this.mediaType,
    required this.position,
    required this.updatedAt,
    required this.deviceId,
    this.duration,
    this.percent,
    this.chapterOrPage,
    this.cfi,
    this.title,
  });

  final String id;
  final String userId;

  /// Local [LibraryItem.id] on the device that last wrote.
  final String mediaId;

  /// Stable work identity for cloud sync / orphan matching.
  final String workId;

  final MediaType mediaType;

  /// Absolute position: audio seconds; PDF page index; EPUB scroll fraction.
  final double position;
  final double? duration;
  final double? percent;
  final String? chapterOrPage;
  final String? cfi;

  /// Display title for orphan resumes (optional, mirrored from library).
  final String? title;

  final String deviceId;
  final DateTime updatedAt;

  MediaProgress copyWith({
    String? id,
    String? userId,
    String? mediaId,
    String? workId,
    MediaType? mediaType,
    double? position,
    double? duration,
    double? percent,
    String? chapterOrPage,
    String? cfi,
    String? title,
    String? deviceId,
    DateTime? updatedAt,
  }) {
    return MediaProgress(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      mediaId: mediaId ?? this.mediaId,
      workId: workId ?? this.workId,
      mediaType: mediaType ?? this.mediaType,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      percent: percent ?? this.percent,
      chapterOrPage: chapterOrPage ?? this.chapterOrPage,
      cfi: cfi ?? this.cfi,
      title: title ?? this.title,
      deviceId: deviceId ?? this.deviceId,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'mediaId': mediaId,
    'workId': workId,
    'mediaType': mediaType.name,
    'position': position,
    'duration': duration,
    'percent': percent,
    'chapterOrPage': chapterOrPage,
    'cfi': cfi,
    'title': title,
    'deviceId': deviceId,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  factory MediaProgress.fromJson(Map<String, dynamic> json) {
    final mediaId = json['mediaId'] as String;
    return MediaProgress(
      id: json['id'] as String,
      userId: json['userId'] as String,
      mediaId: mediaId,
      workId: (json['workId'] as String?) ?? mediaId,
      mediaType: MediaType.values.byName(json['mediaType'] as String),
      position: (json['position'] as num).toDouble(),
      duration: (json['duration'] as num?)?.toDouble(),
      percent: (json['percent'] as num?)?.toDouble(),
      chapterOrPage: json['chapterOrPage'] as String?,
      cfi: json['cfi'] as String?,
      title: json['title'] as String?,
      deviceId: json['deviceId'] as String,
      updatedAt: DateTime.parse(json['updatedAt'] as String).toUtc(),
    );
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    mediaId,
    workId,
    mediaType,
    position,
    duration,
    percent,
    chapterOrPage,
    cfi,
    title,
    deviceId,
    updatedAt,
  ];
}
