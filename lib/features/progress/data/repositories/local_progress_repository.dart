import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:read_beat/core/database/app_database.dart';
import 'package:read_beat/core/errors/app_exception.dart';
import 'package:read_beat/core/errors/result.dart';
import 'package:read_beat/core/logger/app_logger.dart';
import 'package:read_beat/features/progress/domain/models/media_progress.dart';
import 'package:read_beat/features/progress/domain/progress_user_ids.dart';
import 'package:read_beat/features/progress/domain/repositories/progress_repository.dart';
import 'package:read_beat/features/sync/domain/models/sync_outbox_item.dart';
import 'package:read_beat/features/sync/domain/sync_policy.dart';
import 'package:uuid/uuid.dart';

final class LocalProgressRepository implements ProgressRepository {
  LocalProgressRepository(this._db, {Uuid? uuid, AppLogger? logger})
    : _uuid = uuid ?? const Uuid(),
      _logger = logger ?? AppLogger();

  final AppDatabase _db;
  final Uuid _uuid;
  final AppLogger _logger;

  @override
  Future<Result<MediaProgress>> saveLocal(MediaProgress progress) async {
    try {
      final existing =
          await (_db.select(_db.progressEntries)..where(
                (t) =>
                    t.userId.equals(progress.userId) &
                    t.mediaId.equals(progress.mediaId),
              ))
              .getSingleOrNull();

      final toSave = existing == null
          ? progress
          : progress.copyWith(id: existing.id);

      final now = DateTime.now().toUtc();
      await _db.transaction(() async {
        await _db
            .into(_db.progressEntries)
            .insertOnConflictUpdate(
              _toCompanion(toSave, createdAt: existing?.createdAt ?? now),
            );

        // Coalesce: keep a single pending outbox row per progress entity.
        await (_db.delete(_db.syncOutboxEntries)..where(
              (t) =>
                  t.entityType.equals(SyncEntityType.progress.name) &
                  t.entityId.equals(toSave.id) &
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
                entityType: SyncEntityType.progress.name,
                entityId: toSave.id,
                operation: SyncOperationType.upsert.name,
                payloadJson: jsonEncode(toSave.toJson()),
                createdAt: now,
                updatedAt: now,
                idempotencyKey: Value(
                  'progress:${toSave.userId}:${toSave.workId}',
                ),
              ),
            );
      });
      return Success(toSave);
    } catch (e, st) {
      _logger.error('Failed to save progress locally', e, st);
      return Failure(
        UnexpectedException(
          'Failed to save progress locally',
          cause: e,
          code: 'progress.save_local',
        ),
      );
    }
  }

  @override
  Future<Result<MediaProgress?>> getLocal({
    required String userId,
    required String mediaId,
  }) async {
    try {
      final row =
          await (_db.select(_db.progressEntries)..where(
                (t) => t.userId.equals(userId) & t.mediaId.equals(mediaId),
              ))
              .getSingleOrNull();
      return Success(row == null ? null : _fromRow(row));
    } catch (e, st) {
      _logger.error('Failed to read local progress', e, st);
      return Failure(
        UnexpectedException(
          'Failed to read local progress',
          cause: e,
          code: 'progress.get_local',
        ),
      );
    }
  }

  @override
  Future<Result<MediaProgress?>> getBestLocal({
    required String preferredUserId,
    required String mediaId,
  }) async {
    final preferred = await getLocal(
      userId: preferredUserId,
      mediaId: mediaId,
    );
    if (preferred is Failure<MediaProgress?>) return preferred;
    if (preferred.valueOrNull != null) return preferred;
    if (preferredUserId == ProgressUserIds.local) return preferred;
    return getLocal(userId: ProgressUserIds.local, mediaId: mediaId);
  }

  @override
  Future<Result<List<MediaProgress>>> listRecent({
    required String userId,
    MediaType? mediaType,
    int limit = 20,
  }) async {
    try {
      final query = _db.select(_db.progressEntries)
        ..where((t) => t.userId.equals(userId))
        ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
        ..limit(limit);
      if (mediaType != null) {
        query.where((t) => t.mediaType.equals(mediaType.name));
      }
      final rows = await query.get();
      return Success(rows.map(_fromRow).toList());
    } catch (e, st) {
      _logger.error('Failed to list local progress', e, st);
      return Failure(
        UnexpectedException(
          'Failed to list local progress',
          cause: e,
          code: 'progress.list_recent',
        ),
      );
    }
  }

  @override
  Future<Result<MediaProgress>> upsertFromRemote(MediaProgress remote) async {
    try {
      final existingResult = await getLocal(
        userId: remote.userId,
        mediaId: remote.mediaId,
      );
      if (existingResult is Failure<MediaProgress?>) {
        return Failure(existingResult.error);
      }
      final existing = existingResult.valueOrNull;
      final winner = existing == null
          ? remote
          : SyncPolicy.pickWinner(existing, remote);
      final createdAt = existing == null
          ? DateTime.now().toUtc()
          : (await (_db.select(
              _db.progressEntries,
            )..where((t) => t.id.equals(existing.id))).getSingle()).createdAt;

      await _db
          .into(_db.progressEntries)
          .insertOnConflictUpdate(
            _toCompanion(
              winner.copyWith(id: existing?.id ?? remote.id),
              createdAt: createdAt,
            ),
          );
      return Success(winner.copyWith(id: existing?.id ?? remote.id));
    } catch (e, st) {
      _logger.error('Failed to merge remote progress', e, st);
      return Failure(
        UnexpectedException(
          'Failed to merge remote progress',
          cause: e,
          code: 'progress.upsert_remote',
        ),
      );
    }
  }

  @override
  Future<Result<int>> rebindLocalToUser(String authUserId) async {
    if (ProgressUserIds.isLocal(authUserId)) {
      return const Success(0);
    }
    try {
      var moved = 0;
      await _db.transaction(() async {
        final locals =
            await (_db.select(_db.progressEntries)..where(
                  (t) => t.userId.equals(ProgressUserIds.local),
                ))
                .get();

        for (final local in locals) {
          final authRow =
              await (_db.select(_db.progressEntries)..where(
                    (t) =>
                        t.userId.equals(authUserId) &
                        t.mediaId.equals(local.mediaId),
                  ))
                  .getSingleOrNull();

          final localProgress = _fromRow(local);
          if (authRow == null) {
            await (_db.update(
              _db.progressEntries,
            )..where((t) => t.id.equals(local.id))).write(
              ProgressEntriesCompanion(
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

          final authProgress = _fromRow(authRow);
          final winner = SyncPolicy.pickWinner(authProgress, localProgress);
          final keepId = authRow.id;
          await _db
              .into(_db.progressEntries)
              .insertOnConflictUpdate(
                _toCompanion(
                  winner.copyWith(id: keepId, userId: authUserId),
                  createdAt: authRow.createdAt,
                ),
              );
          await (_db.delete(
            _db.progressEntries,
          )..where((t) => t.id.equals(local.id))).go();
          await (_db.delete(_db.syncOutboxEntries)..where(
                (t) =>
                    t.entityType.equals(SyncEntityType.progress.name) &
                    t.entityId.equals(local.id),
              ))
              .go();
          await _rewriteOutboxUserId(
            entityId: keepId,
            fromUserId: ProgressUserIds.local,
            toUserId: authUserId,
          );
          moved++;
        }
      });
      return Success(moved);
    } catch (e, st) {
      _logger.error('Failed to rebind local progress', e, st);
      return Failure(
        UnexpectedException(
          'Failed to rebind local progress',
          cause: e,
          code: 'progress.rebind',
        ),
      );
    }
  }

  Future<void> _rewriteOutboxUserId({
    required String entityId,
    required String fromUserId,
    required String toUserId,
  }) async {
    final rows =
        await (_db.select(_db.syncOutboxEntries)..where(
              (t) =>
                  t.entityType.equals(SyncEntityType.progress.name) &
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
          idempotencyKey: Value(
            'progress:$toUserId:${map['mediaId']}',
          ),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );
    }
  }

  ProgressEntriesCompanion _toCompanion(
    MediaProgress p, {
    required DateTime createdAt,
  }) {
    return ProgressEntriesCompanion.insert(
      id: p.id,
      userId: p.userId,
      mediaId: p.mediaId,
      workId: Value(p.workId),
      mediaType: p.mediaType.name,
      position: p.position,
      duration: Value(p.duration),
      percent: Value(p.percent),
      chapterOrPage: Value(p.chapterOrPage),
      cfi: Value(p.cfi),
      title: Value(p.title),
      deviceId: p.deviceId,
      updatedAt: p.updatedAt.toUtc(),
      createdAt: createdAt.toUtc(),
    );
  }

  MediaProgress _fromRow(ProgressEntry row) {
    return MediaProgress(
      id: row.id,
      userId: row.userId,
      mediaId: row.mediaId,
      workId: row.workId.isEmpty ? row.mediaId : row.workId,
      mediaType: MediaType.values.byName(row.mediaType),
      position: row.position,
      duration: row.duration,
      percent: row.percent,
      chapterOrPage: row.chapterOrPage,
      cfi: row.cfi,
      title: row.title,
      deviceId: row.deviceId,
      updatedAt: row.updatedAt.toUtc(),
    );
  }
}
