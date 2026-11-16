import 'package:equatable/equatable.dart';
import 'package:read_beat/features/progress/domain/models/media_progress.dart';

enum MediaFormat { epub, pdf, mp3, m4a }

enum CloudStatus { localOnly, synced, remoteOnly, conflict }

/// Local library item (ebook or audio file).
final class LibraryItem extends Equatable {
  const LibraryItem({
    required this.id,
    required this.workId,
    required this.title,
    required this.mediaType,
    required this.format,
    required this.filePath,
    required this.fileHash,
    required this.fileSizeBytes,
    required this.createdAt,
    required this.updatedAt,
    this.author,
    this.softKey,
    this.coverPath,
    this.durationSeconds,
    this.pageCount,
    this.isFavorite = false,
    this.cloudStatus = CloudStatus.localOnly,
    this.lastOpenedAt,
    this.progressPercent,
    this.progressLabel,
  });

  final String id;

  /// Stable work identity across encodings / devices (progress sync key).
  final String workId;

  final String title;
  final String? author;
  final MediaType mediaType;
  final MediaFormat format;
  final String filePath;
  final String fileHash;

  /// Soft fingerprint key (title/author), nullable if title missing.
  final String? softKey;
  final int fileSizeBytes;

  /// Local path to derived/default feature cover JPEG.
  final String? coverPath;
  final double? durationSeconds;
  final int? pageCount;
  final bool isFavorite;
  final CloudStatus cloudStatus;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastOpenedAt;

  /// Joined from progress when available (0–1).
  final double? progressPercent;
  final String? progressLabel;

  bool get isEbook => mediaType == MediaType.ebook;
  bool get isAudio => mediaType == MediaType.audio;

  String get resumeLabel => isEbook ? 'Resume reading' : 'Resume listening';

  LibraryItem copyWith({
    String? workId,
    String? title,
    String? author,
    String? softKey,
    String? coverPath,
    bool clearCoverPath = false,
    bool? isFavorite,
    CloudStatus? cloudStatus,
    DateTime? updatedAt,
    DateTime? lastOpenedAt,
    double? progressPercent,
    String? progressLabel,
    double? durationSeconds,
    int? pageCount,
  }) {
    return LibraryItem(
      id: id,
      workId: workId ?? this.workId,
      title: title ?? this.title,
      author: author ?? this.author,
      softKey: softKey ?? this.softKey,
      mediaType: mediaType,
      format: format,
      filePath: filePath,
      fileHash: fileHash,
      fileSizeBytes: fileSizeBytes,
      coverPath: clearCoverPath ? null : (coverPath ?? this.coverPath),
      durationSeconds: durationSeconds ?? this.durationSeconds,
      pageCount: pageCount ?? this.pageCount,
      isFavorite: isFavorite ?? this.isFavorite,
      cloudStatus: cloudStatus ?? this.cloudStatus,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      progressPercent: progressPercent ?? this.progressPercent,
      progressLabel: progressLabel ?? this.progressLabel,
    );
  }

  @override
  List<Object?> get props => [
    id,
    workId,
    title,
    author,
    softKey,
    mediaType,
    format,
    filePath,
    fileHash,
    fileSizeBytes,
    coverPath,
    durationSeconds,
    pageCount,
    isFavorite,
    cloudStatus,
    createdAt,
    updatedAt,
    lastOpenedAt,
    progressPercent,
    progressLabel,
  ];
}
