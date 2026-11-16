import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:read_beat/core/database/app_database.dart';
import 'package:read_beat/features/library/data/repositories/local_library_repository.dart';
import 'package:read_beat/features/library/domain/models/library_item.dart';
import 'package:read_beat/features/playlists/data/repositories/local_playlist_repository.dart';
import 'package:read_beat/features/progress/domain/models/media_progress.dart';
import 'package:read_beat/features/progress/domain/progress_user_ids.dart';
import 'package:read_beat/features/sync/domain/models/sync_outbox_item.dart';

void main() {
  late AppDatabase db;
  late LocalLibraryRepository library;
  late LocalPlaylistRepository playlists;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    library = LocalLibraryRepository(db);
    playlists = LocalPlaylistRepository(db);
  });

  tearDown(() async => db.close());

  Future<LibraryItem> audio(String id) async {
    final now = DateTime.utc(2026, 8, 13);
    final item = LibraryItem(
      id: id,
      workId: id,
      title: 'Track $id',
      mediaType: MediaType.audio,
      format: MediaFormat.mp3,
      filePath: '/tmp/$id.mp3',
      fileHash: id,
      fileSizeBytes: 8,
      createdAt: now,
      updatedAt: now,
    );
    await library.upsert(item);
    return item;
  }

  test('create, add, reorder, remove, delete', () async {
    final a = await audio('a');
    final b = await audio('b');
    final created = await playlists.create(
      title: 'Commute',
      userId: ProgressUserIds.local,
    );
    final playlist = created.valueOrNull!;
    expect(playlist.title, 'Commute');

    await playlists.addTrack(playlistId: playlist.id, item: a);
    await playlists.addTrack(playlistId: playlist.id, item: b);
    var loaded = (await playlists.getById(playlist.id)).valueOrNull!;
    expect(loaded.tracks.map((t) => t.mediaId), ['a', 'b']);

    await playlists.moveTrack(
      playlistId: playlist.id,
      trackId: loaded.tracks.first.id,
      delta: 1,
    );
    loaded = (await playlists.getById(playlist.id)).valueOrNull!;
    expect(loaded.tracks.map((t) => t.mediaId), ['b', 'a']);

    await playlists.removeTrack(
      playlistId: playlist.id,
      trackId: loaded.tracks.first.id,
    );
    loaded = (await playlists.getById(playlist.id)).valueOrNull!;
    expect(loaded.tracks.map((t) => t.mediaId), ['a']);

    await playlists.delete(playlist.id);
    expect((await playlists.getById(playlist.id)).valueOrNull, isNull);

    final outbox = await db.select(db.syncOutboxEntries).get();
    expect(
      outbox.any((e) => e.entityType == SyncEntityType.playlist.name),
      isTrue,
    );
  });

  test('rejects ebook tracks', () async {
    final now = DateTime.utc(2026, 8, 13);
    final book = LibraryItem(
      id: 'book',
      workId: 'book',
      title: 'Novel',
      mediaType: MediaType.ebook,
      format: MediaFormat.epub,
      filePath: '/tmp/book.epub',
      fileHash: 'book',
      fileSizeBytes: 4,
      createdAt: now,
      updatedAt: now,
    );
    await library.upsert(book);
    final playlist = (await playlists.create(
      title: 'Queue',
      userId: ProgressUserIds.local,
    )).valueOrNull!;
    final result = await playlists.addTrack(
      playlistId: playlist.id,
      item: book,
    );
    expect(result.isFailure, isTrue);
  });

  test('rebindLocalToUser rewrites guest owner', () async {
    await playlists.create(title: 'Guest', userId: ProgressUserIds.local);
    final moved = await playlists.rebindLocalToUser('auth-1');
    expect(moved.valueOrNull, 1);
    final rows = await db.select(db.playlistEntries).get();
    expect(rows.single.userId, 'auth-1');
  });
}
