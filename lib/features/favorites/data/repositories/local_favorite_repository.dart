import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:read_beat/core/database/app_database.dart';
import 'package:read_beat/core/errors/app_exception.dart';
import 'package:read_beat/core/errors/result.dart';
import 'package:read_beat/core/logger/app_logger.dart';
import 'package:read_beat/features/favorites/domain/models/favorite_record.dart';
import 'package:read_beat/features/progress/domain/progress_user_ids.dart';
import 'package:read_beat/features/sync/domain/models/sync_outbox_item.dart';
import 'package:uuid/uuid.dart';

final class LocalFavoriteRepository {
  LocalFavoriteRepository(this._db, {Uuid? uuid, AppLogger? logger})
    : _uuid = uuid ?? const Uuid(),
      _logger = logger ?? AppLogger();

  final AppDatabase _db;
  final Uuid _uuid;
  final AppLogger _logger;

  Future<Result<FavoriteRecord>> setFavorite({
    required String mediaId,
    required String workId,
    required bool favorite,
    required String userId,
  }) async {
    try {
      final now = DateTime.now().toUtc();
      final existing = await (_db.select(
        _db.favoriteEntries,
      )..where((t) => t.userId.equals(userId) & t.workId.equals(workId)))
          .getSingleOrNull();

      final record = FavoriteRecord(
        id: existing?.id ?? _uuid.v4(),
        userId: userId,
        workId: workId,
        isFavorite: favorite,
        updatedAt: now,
      );

      await _db.transaction(() async {
        await (_db.update(_db.mediaItems)..where((t) => t.id.equals(mediaId)))
            .write(
              MediaItemsCompanion(
                isFavorite: Value(favorite),
                updatedAt: Value(now),
              ),
            );

        await _db
            .into(_db.favoriteEntries)
            .insertOnConflictUpdate(_toCompanion(record));

        await _replaceOutbox(record);
      });
      return Success(record);
    } catch (e, st) {
      _logger.error('setFavorite failed', e, st);
      return Failure(StorageException('Failed to update favorite', cause: e));
    }
  }

  Future<Result<void>> applyRemote(FavoriteRecord remote) async {
    try {
      final local = await (_db.select(
        _db.favoriteEntries,
      )..where(
            (t) => t.userId.equals(remote.userId) & t.workId.equals(remote.workId),
          ))
          .getSingleOrNull();

      if (local != null && !remote.updatedAt.isAfter(local.updatedAt)) {
        return const Success(null);
      }

      await _db.transaction(() async {
        await _db
            .into(_db.favoriteEntries)
            .insertOnConflictUpdate(_toCompanion(remote));

        await (_db.update(_db.mediaItems)
              ..where((t) => t.workId.equals(remote.workId)))
            .write(
              MediaItemsCompanion(
                isFavorite: Value(remote.isFavorite),
                updatedAt: Value(remote.updatedAt),
              ),
            );
      });
      return const Success(null);
    } catch (e, st) {
      _logger.error('applyRemote favorite failed', e, st);
      return Failure(StorageException('Failed to merge favorite', cause: e));
    }
  }

  Future<Result<List<FavoriteRecord>>> listForUser(String userId) async {
    try {
      final rows = await (_db.select(
        _db.favoriteEntries,
      )..where((t) => t.userId.equals(userId))).get();
      return Success(rows.map(_fromRow).toList());
    } catch (e, st) {
      _logger.error('list favorites failed', e, st);
      return Failure(StorageException('Failed to list favorites', cause: e));
    }
  }

  Future<Result<int>> rebindLocalToUser(String authUserId) async {
    if (ProgressUserIds.isLocal(authUserId)) return const Success(0);
    try {
      var moved = 0;
      await _db.transaction(() async {
        final locals = await (_db.select(
          _db.favoriteEntries,
        )..where((t) => t.userId.equals(ProgressUserIds.local))).get();

        for (final local in locals) {
          final authRow = await (_db.select(_db.favoriteEntries)..where(
                (t) =>
                    t.userId.equals(authUserId) & t.workId.equals(local.workId),
              ))
              .getSingleOrNull();

          if (authRow == null) {
            await (_db.update(
              _db.favoriteEntries,
            )..where((t) => t.id.equals(local.id))).write(
              FavoriteEntriesCompanion(
                userId: Value(authUserId),
                updatedAt: Value(DateTime.now().toUtc()),
              ),
            );
            await _rewriteOutboxUserId(
              entityId: local.id,
              fromUserId: ProgressUserIds.local,
              toUserId: authUserId,
            );
            moved++;
            continue;
          }

          final winner = local.updatedAt.isAfter(authRow.updatedAt)
              ? local
              : authRow;
          final keep = FavoriteRecord(
            id: authRow.id,
            userId: authUserId,
            workId: authRow.workId,
            isFavorite: winner.isFavorite,
            updatedAt: winner.updatedAt.isAfter(local.updatedAt)
                ? winner.updatedAt
                : local.updatedAt,
          );
          await _db
              .into(_db.favoriteEntries)
              .insertOnConflictUpdate(_toCompanion(keep));
          await (_db.delete(
            _db.favoriteEntries,
          )..where((t) => t.id.equals(local.id))).go();
          await (_db.delete(_db.syncOutboxEntries)..where(
                (t) =>
                    t.entityType.equals(SyncEntityType.favorite.name) &
                    t.entityId.equals(local.id),
              ))
              .go();
          await _replaceOutbox(keep);
          moved++;
        }
      });
      return Success(moved);
    } catch (e, st) {
      _logger.error('rebind favorites failed', e, st);
      return Failure(StorageException('Failed to rebind favorites', cause: e));
    }
  }

  /// Ensure signed-in favorites are queued for push (like catalog cards).
  Future<Result<void>> enqueueAllForUser(String userId) async {
    if (ProgressUserIds.isLocal(userId)) return const Success(null);
    try {
      final rows = await (_db.select(
        _db.favoriteEntries,
      )..where((t) => t.userId.equals(userId))).get();
      for (final row in rows) {
        await _replaceOutbox(_fromRow(row));
      }
      return const Success(null);
    } catch (e, st) {
      _logger.error('enqueue favorites failed', e, st);
      return Failure(StorageException('Failed to enqueue favorites', cause: e));
    }
  }

  Future<void> _replaceOutbox(FavoriteRecord record) async {
    final now = DateTime.now().toUtc();
    await (_db.delete(_db.syncOutboxEntries)..where(
          (t) =>
              t.entityType.equals(SyncEntityType.favorite.name) &
              t.entityId.equals(record.id) &
              (t.status.equals(SyncOutboxStatus.pending.name) |
                  t.status.equals(SyncOutboxStatus.failed.name) |
                  t.status.equals(SyncOutboxStatus.inFlight.name)),
        ))
        .go();

    await _db
        .into(_db.syncOutboxEntries)
        .insert(
          SyncOutboxEntriesCompanion.insert(
            id: _uuid.v4(),
            entityType: SyncEntityType.favorite.name,
            entityId: record.id,
            operation: record.isFavorite
                ? SyncOperationType.upsert.name
                : SyncOperationType.delete.name,
            payloadJson: jsonEncode(record.toJson()),
            createdAt: now,
            updatedAt: now,
            idempotencyKey: Value('favorite:${record.userId}:${record.workId}'),
          ),
        );
  }

  Future<void> _rewriteOutboxUserId({
    required String entityId,
    required String fromUserId,
    required String toUserId,
  }) async {
    final rows = await (_db.select(_db.syncOutboxEntries)..where(
          (t) =>
              t.entityType.equals(SyncEntityType.favorite.name) &
              t.entityId.equals(entityId) &
              (t.status.equals(SyncOutboxStatus.pending.name) |
                  t.status.equals(SyncOutboxStatus.failed.name) |
                  t.status.equals(SyncOutboxStatus.inFlight.name)),
        ))
        .get();
    for (final row in rows) {
      final map = jsonDecode(row.payloadJson) as Map<String, dynamic>;
      if (map['userId'] != fromUserId) continue;
      map['userId'] = toUserId;
      await (_db.update(
        _db.syncOutboxEntries,
      )..where((t) => t.id.equals(row.id))).write(
        SyncOutboxEntriesCompanion(
          payloadJson: Value(jsonEncode(map)),
          idempotencyKey: Value('favorite:$toUserId:${map['workId']}'),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );
    }
  }

  FavoriteEntriesCompanion _toCompanion(FavoriteRecord r) {
    return FavoriteEntriesCompanion(
      id: Value(r.id),
      userId: Value(r.userId),
      workId: Value(r.workId),
      isFavorite: Value(r.isFavorite),
      updatedAt: Value(r.updatedAt.toUtc()),
    );
  }

  FavoriteRecord _fromRow(FavoriteEntry row) {
    return FavoriteRecord(
      id: row.id,
      userId: row.userId,
      workId: row.workId,
      isFavorite: row.isFavorite,
      updatedAt: row.updatedAt.toUtc(),
    );
  }
}
