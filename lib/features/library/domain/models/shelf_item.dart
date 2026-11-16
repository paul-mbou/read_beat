/// Media kind for shelf / resume surfaces.
enum MediaKind { ebook, audio }

/// Lightweight view model for Desk Shelf / mini-player.
final class ShelfItem {
  const ShelfItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.kind,
    required this.progress,
    this.author,
    this.positionLabel,
    this.coverColorValue,
    this.coverPath,
    this.libraryId,
  });

  final String id;
  final String title;
  final String subtitle;
  final String? author;
  final MediaKind kind;

  /// 0.0 – 1.0
  final double progress;
  final String? positionLabel;
  final int? coverColorValue;

  /// Local JPEG path for feature art (extracted or brand default).
  final String? coverPath;

  /// Real [LibraryItem.id] when backed by Drift.
  final String? libraryId;

  bool get isEbook => kind == MediaKind.ebook;
  bool get isAudio => kind == MediaKind.audio;

  String get resumeLabel => isEbook ? 'Resume reading' : 'Resume listening';
}
