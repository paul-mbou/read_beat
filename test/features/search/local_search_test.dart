import 'package:flutter_test/flutter_test.dart';
import 'package:read_beat/features/library/domain/models/library_item.dart';
import 'package:read_beat/features/progress/domain/models/media_progress.dart';
import 'package:read_beat/features/search/domain/local_search.dart';

LibraryItem _item({
  required String id,
  required String title,
  String? author,
  MediaType type = MediaType.ebook,
  MediaFormat format = MediaFormat.epub,
}) {
  final now = DateTime.utc(2026, 8, 13);
  return LibraryItem(
    id: id,
    workId: id,
    title: title,
    author: author,
    mediaType: type,
    format: format,
    filePath: '/tmp/$id',
    fileHash: id,
    fileSizeBytes: 10,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  final items = [
    _item(id: '1', title: 'Quiet Shelf', author: 'Ada'),
    _item(
      id: '2',
      title: 'Night Train',
      author: 'Bea',
      type: MediaType.audio,
      format: MediaFormat.mp3,
    ),
    _item(id: '3', title: 'Forest Notes', author: 'Ada Forest'),
  ];

  test('empty query returns all items', () {
    expect(LocalSearch.query(items, '  '), items);
  });

  test('title match outranks author', () {
    final hits = LocalSearch.query(items, 'forest');
    expect(hits.first.title, 'Forest Notes');
  });

  test('all tokens must match', () {
    final hits = LocalSearch.query(items, 'quiet missing');
    expect(hits, isEmpty);
  });

  test('format token finds audio', () {
    final hits = LocalSearch.query(items, 'mp3');
    expect(hits.map((e) => e.id), ['2']);
  });

  test('author token finds Ada titles', () {
    final hits = LocalSearch.query(items, 'ada');
    expect(hits.map((e) => e.id), unorderedEquals(['1', '3']));
  });
}
