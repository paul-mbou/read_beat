import 'package:flutter_test/flutter_test.dart';
import 'package:read_beat/features/library/domain/models/library_item.dart';
import 'package:read_beat/features/playlists/domain/models/audio_playlist.dart';
import 'package:read_beat/features/progress/domain/models/media_progress.dart';
import 'package:read_beat/features/settings/domain/library_storage_stats.dart';

void main() {
  test('aggregates counts and readable size', () {
    final now = DateTime.utc(2026, 8, 13);
    final items = [
      LibraryItem(
        id: '1',
        workId: '1',
        title: 'Book',
        mediaType: MediaType.ebook,
        format: MediaFormat.epub,
        filePath: '/tmp/1',
        fileHash: '1',
        fileSizeBytes: 1500,
        isFavorite: true,
        createdAt: now,
        updatedAt: now,
      ),
      LibraryItem(
        id: '2',
        workId: '2',
        title: 'Track',
        mediaType: MediaType.audio,
        format: MediaFormat.mp3,
        filePath: '/tmp/2',
        fileHash: '2',
        fileSizeBytes: 2048,
        createdAt: now,
        updatedAt: now,
      ),
    ];
    final stats = LibraryStorageStats.from(
      items: items,
      playlists: [
        AudioPlaylist(
          id: 'p1',
          userId: 'local',
          title: 'Queue',
          createdAt: now,
          updatedAt: now,
        ),
      ],
    );
    expect(stats.itemCount, 2);
    expect(stats.ebookCount, 1);
    expect(stats.audioCount, 1);
    expect(stats.favoriteCount, 1);
    expect(stats.playlistCount, 1);
    expect(stats.totalBytes, 3548);
    expect(stats.readableSize, contains('KB'));
  });
}
