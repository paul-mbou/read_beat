import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:read_beat/core/database/app_database.dart';
import 'package:read_beat/core/errors/result.dart';
import 'package:read_beat/features/progress/data/repositories/local_progress_repository.dart';
import 'package:read_beat/features/progress/domain/models/media_progress.dart';
import 'package:read_beat/features/progress/domain/progress_user_ids.dart';
import 'package:read_beat/features/sync/domain/models/sync_outbox_item.dart';
import 'dart:convert';

void main() {
  late AppDatabase db;
  late LocalProgressRepository repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = LocalProgressRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  MediaProgress progress({
    String id = 'prog-1',
    String userId = 'user-1',
    String mediaId = 'track-1',
    double position = 12.5,
    DateTime? updatedAt,
  }) {
    return MediaProgress(
      id: id,
      userId: userId,
      mediaId: mediaId,
      workId: mediaId,
      mediaType: MediaType.audio,
      position: position,
      duration: 200,
      percent: position / 200,
      deviceId: 'device-1',
      updatedAt: updatedAt ?? DateTime.utc(2026, 8, 12, 9, 0),
    );
  }

  test('saveLocal persists progress and enqueues outbox atomically', () async {
    final saved = await repository.saveLocal(progress());
    expect(saved, isA<Success<MediaProgress>>());

    final loaded = await repository.getLocal(
      userId: 'user-1',
      mediaId: 'track-1',
    );
    expect(loaded.valueOrNull?.position, 12.5);

    final outbox = await db.select(db.syncOutboxEntries).get();
    expect(outbox, hasLength(1));
    expect(outbox.first.entityType, SyncEntityType.progress.name);
    expect(outbox.first.status, SyncOutboxStatus.pending.name);
  });

  test('saveLocal keeps stable id and coalesces pending outbox', () async {
    final first = await repository.saveLocal(progress(position: 10));
    final second = await repository.saveLocal(
      progress(
        id: 'other-id',
        position: 40,
        updatedAt: DateTime.utc(2026, 8, 12, 10),
      ),
    );

    expect(second.valueOrNull?.id, first.valueOrNull?.id);

    final outbox = await db.select(db.syncOutboxEntries).get();
    expect(outbox, hasLength(1));
    final payload = jsonDecode(outbox.single.payloadJson) as Map<String, dynamic>;
    expect(payload['position'], 40);
    expect(outbox.single.idempotencyKey, 'progress:user-1:track-1');
  });

  test('upsertFromRemote keeps newer local progress and does not enqueue', () async {
    final local = progress(
      mediaId: 'book-1',
      position: 80,
      updatedAt: DateTime.utc(2026, 8, 12, 12),
    );
    await repository.saveLocal(local);
    await db.delete(db.syncOutboxEntries).go();

    final olderRemote = local.copyWith(
      position: 20,
      deviceId: 'tablet',
      updatedAt: DateTime.utc(2026, 8, 12, 10),
    );
    final merged = await repository.upsertFromRemote(olderRemote);
    expect(merged.valueOrNull?.position, 80);
    expect(await db.select(db.syncOutboxEntries).get(), isEmpty);
  });

  test('upsertFromRemote replaces with newer remote progress', () async {
    final local = progress(
      mediaId: 'book-1',
      position: 20,
      updatedAt: DateTime.utc(2026, 8, 12, 10),
    );
    await repository.saveLocal(local);

    final newerRemote = local.copyWith(
      position: 55,
      deviceId: 'tablet',
      updatedAt: DateTime.utc(2026, 8, 12, 13),
    );
    final merged = await repository.upsertFromRemote(newerRemote);
    expect(merged.valueOrNull?.position, 55);
  });

  test('getBestLocal falls back from preferred to guest', () async {
    await repository.saveLocal(
      progress(userId: ProgressUserIds.local, mediaId: 'm1', position: 9),
    );
    final best = await repository.getBestLocal(
      preferredUserId: 'auth-user',
      mediaId: 'm1',
    );
    expect(best.valueOrNull?.position, 9);
  });

  test('rebindLocalToUser moves guest rows and rewrites outbox', () async {
    await repository.saveLocal(
      progress(
        userId: ProgressUserIds.local,
        mediaId: 'm1',
        position: 33,
      ),
    );

    final moved = await repository.rebindLocalToUser('auth-user');
    expect(moved.valueOrNull, 1);

    final guest = await repository.getLocal(
      userId: ProgressUserIds.local,
      mediaId: 'm1',
    );
    expect(guest.valueOrNull, isNull);

    final auth = await repository.getLocal(userId: 'auth-user', mediaId: 'm1');
    expect(auth.valueOrNull?.position, 33);

    final outbox = await db.select(db.syncOutboxEntries).get();
    expect(outbox, hasLength(1));
    final payload = jsonDecode(outbox.single.payloadJson) as Map<String, dynamic>;
    expect(payload['userId'], 'auth-user');
  });

  test('rebindLocalToUser LWW-merges when auth row exists', () async {
    await repository.saveLocal(
      progress(
        id: 'local-row',
        userId: ProgressUserIds.local,
        mediaId: 'm1',
        position: 10,
        updatedAt: DateTime.utc(2026, 8, 12, 9),
      ),
    );
    await repository.saveLocal(
      progress(
        id: 'auth-row',
        userId: 'auth-user',
        mediaId: 'm1',
        position: 90,
        updatedAt: DateTime.utc(2026, 8, 12, 11),
      ),
    );

    await repository.rebindLocalToUser('auth-user');
    final auth = await repository.getLocal(userId: 'auth-user', mediaId: 'm1');
    expect(auth.valueOrNull?.position, 90);
    final all = await db.select(db.progressEntries).get();
    expect(all, hasLength(1));
  });
}
