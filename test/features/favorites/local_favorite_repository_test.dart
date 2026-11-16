import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:read_beat/core/database/app_database.dart';
import 'package:read_beat/features/favorites/data/repositories/local_favorite_repository.dart';
import 'package:read_beat/features/favorites/domain/models/favorite_record.dart';
import 'package:read_beat/features/library/data/repositories/local_library_repository.dart';
import 'package:read_beat/features/library/domain/models/library_item.dart';
import 'package:read_beat/features/progress/domain/models/media_progress.dart';
import 'package:read_beat/features/progress/domain/progress_user_ids.dart';
import 'package:read_beat/features/sync/domain/models/sync_outbox_item.dart';

void main() {
  late AppDatabase db;
  late LocalLibraryRepository library;
  late LocalFavoriteRepository favorites;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    library = LocalLibraryRepository(db);
    favorites = LocalFavoriteRepository(db);
  });

  tearDown(() async => db.close());

  Future<LibraryItem> seed() async {
    final now = DateTime.utc(2026, 8, 13);
    final item = LibraryItem(
      id: 'm1',
      workId: 'w1',
      title: 'Track',
      mediaType: MediaType.audio,
      format: MediaFormat.mp3,
      filePath: '/tmp/a.mp3',
      fileHash: 'hash',
      fileSizeBytes: 12,
      createdAt: now,
      updatedAt: now,
    );
    await library.upsert(item);
    return item;
  }

  test('setFavorite updates media flag and enqueues outbox', () async {
    await seed();
    final result = await favorites.setFavorite(
      mediaId: 'm1',
      workId: 'w1',
      favorite: true,
      userId: ProgressUserIds.local,
    );
    expect(result.isSuccess, isTrue);

    final item = (await library.getById('m1')).valueOrNull!;
    expect(item.isFavorite, isTrue);

    final outbox = await db.select(db.syncOutboxEntries).get();
    expect(outbox, hasLength(1));
    expect(outbox.single.entityType, SyncEntityType.favorite.name);
    expect(outbox.single.operation, SyncOperationType.upsert.name);
  });

  test('unfavorite enqueues delete and keeps tombstone', () async {
    await seed();
    await favorites.setFavorite(
      mediaId: 'm1',
      workId: 'w1',
      favorite: true,
      userId: 'auth-1',
    );
    await favorites.setFavorite(
      mediaId: 'm1',
      workId: 'w1',
      favorite: false,
      userId: 'auth-1',
    );

    final item = (await library.getById('m1')).valueOrNull!;
    expect(item.isFavorite, isFalse);
    final outbox = await db.select(db.syncOutboxEntries).get();
    expect(outbox.single.operation, SyncOperationType.delete.name);
  });

  test('applyRemote loses to newer local favorite', () async {
    await seed();
    await favorites.setFavorite(
      mediaId: 'm1',
      workId: 'w1',
      favorite: true,
      userId: 'auth-1',
    );
    final remote = FavoriteRecord(
      id: 'remote',
      userId: 'auth-1',
      workId: 'w1',
      isFavorite: false,
      updatedAt: DateTime.utc(2020, 1, 1),
    );
    await favorites.applyRemote(remote);
    final item = (await library.getById('m1')).valueOrNull!;
    expect(item.isFavorite, isTrue);
  });

  test('rebindLocalToUser moves guest favorites', () async {
    await seed();
    await favorites.setFavorite(
      mediaId: 'm1',
      workId: 'w1',
      favorite: true,
      userId: ProgressUserIds.local,
    );
    final moved = await favorites.rebindLocalToUser('auth-1');
    expect(moved.valueOrNull, 1);
    final rows = await db.select(db.favoriteEntries).get();
    expect(rows.single.userId, 'auth-1');
  });
}
