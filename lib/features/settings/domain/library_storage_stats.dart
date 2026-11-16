import 'package:equatable/equatable.dart';
import 'package:read_beat/features/library/domain/models/library_item.dart';
import 'package:read_beat/features/playlists/domain/models/audio_playlist.dart';

/// Snapshot of on-device library weight for Settings → Storage.
final class LibraryStorageStats extends Equatable {
  const LibraryStorageStats({
    required this.itemCount,
    required this.ebookCount,
    required this.audioCount,
    required this.favoriteCount,
    required this.playlistCount,
    required this.totalBytes,
  });

  final int itemCount;
  final int ebookCount;
  final int audioCount;
  final int favoriteCount;
  final int playlistCount;
  final int totalBytes;

  factory LibraryStorageStats.from({
    required List<LibraryItem> items,
    required List<AudioPlaylist> playlists,
  }) {
    var ebooks = 0;
    var audio = 0;
    var favorites = 0;
    var bytes = 0;
    for (final item in items) {
      bytes += item.fileSizeBytes;
      if (item.isEbook) ebooks++;
      if (item.isAudio) audio++;
      if (item.isFavorite) favorites++;
    }
    return LibraryStorageStats(
      itemCount: items.length,
      ebookCount: ebooks,
      audioCount: audio,
      favoriteCount: favorites,
      playlistCount: playlists.length,
      totalBytes: bytes,
    );
  }

  String get readableSize {
    if (totalBytes < 1024) return '$totalBytes B';
    final kb = totalBytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(kb >= 10 ? 0 : 1)} KB';
    final mb = kb / 1024;
    if (mb < 1024) return '${mb.toStringAsFixed(mb >= 10 ? 0 : 1)} MB';
    final gb = mb / 1024;
    return '${gb.toStringAsFixed(1)} GB';
  }

  @override
  List<Object?> get props => [
    itemCount,
    ebookCount,
    audioCount,
    favoriteCount,
    playlistCount,
    totalBytes,
  ];
}
