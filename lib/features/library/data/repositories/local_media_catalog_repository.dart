import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:read_beat/core/database/app_database.dart';
import 'package:read_beat/core/errors/app_exception.dart';
import 'package:read_beat/core/errors/result.dart';
import 'package:read_beat/core/logger/app_logger.dart';
import 'package:read_beat/features/library/domain/models/library_item.dart';
import 'package:read_beat/features/library/domain/models/media_catalog_entry.dart';
import 'package:read_beat/features/progress/domain/models/media_progress.dart';
import 'package:read_beat/features/sync/domain/models/sync_outbox_item.dart';
import 'package:uuid/uuid.dart';

/// Local cache + outbox enqueue for lightweight media catalog cards.
final class LocalMediaCatalogRepository {
  LocalMediaCatalogRepository(this._db, {Uuid? uuid, AppLogger? logger})
    : _uuid = uuid ?? const Uuid(),
      _logger = logger ?? AppLogger();

  final AppDatabase _db;
  final Uuid _uuid;
  final AppLogger _logger;

  Future<Result<void>> cacheAll(List<MediaCatalogEntry> entries) async {
    try {
      await _db.transaction(() async {
        for (final e in entries) {
          await _db
              .into(_db.mediaCatalogCacheEntries)
              .insertOnConflictUpdate(_toCompanion(e));
        }
      });
      return const Success(null);
    } catch (e, st) {
      _logger.error('cache catalog failed', e, st);
      return Failure(StorageException('Failed to cache catalog', cause: e));
    }
  }

  Future<Result<List<MediaCatalogEntry>>> listCached({
    required String userId,
  }) async {
    try {
      final rows =
          await (_db.select(_db.mediaCatalogCacheEntries)
                ..where((t) => t.userId.equals(userId))
                ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
              .get();
      return Success(rows.map(_fromRow).toList());
    } catch (e, st) {
      _logger.error('list catalog cache failed', e, st);
      return Failure(StorageException('Failed to list catalog', cause: e));
    }
  }

  /// Enqueue a catalog upsert for a library item (no binary).
  Future<Result<void>> enqueueFromLibraryItem({
    required LibraryItem item,
    required String userId,
  }) async {
    if (userId == 'local') return const Success(null);
    try {
      final now = DateTime.now().toUtc();
      final entry = MediaCatalogEntry(
        id: item.workId,
        userId: userId,
        workId: item.workId,
        title: item.title,
        author: item.author,
        mediaType: item.mediaType,
        format: item.format,
        exactHash: item.fileHash,
        softKey: item.softKey,
        durationSeconds: item.durationSeconds,
        updatedAt: now,
      );

      await _db.transaction(() async {
        await _db
            .into(_db.mediaCatalogCacheEntries)
            .insertOnConflictUpdate(_toCompanion(entry));

        await (_db.delete(_db.syncOutboxEntries)..where(
              (t) =>
                  t.entityType.equals(SyncEntityType.mediaCatalog.name) &
                  t.entityId.equals(entry.workId) &
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
                entityType: SyncEntityType.mediaCatalog.name,
                entityId: entry.workId,
                operation: SyncOperationType.upsert.name,
                payloadJson: jsonEncode(entry.toJson()),
                createdAt: now,
                updatedAt: now,
                idempotencyKey: Value('catalog:$userId:${entry.workId}'),
              ),
            );
      });
      return const Success(null);
    } catch (e, st) {
      _logger.error('enqueue catalog failed', e, st);
      return Failure(StorageException('Failed to enqueue catalog', cause: e));
    }
  }

  MediaCatalogCacheEntriesCompanion _toCompanion(MediaCatalogEntry e) {
    return MediaCatalogCacheEntriesCompanion(
      id: Value(e.id),
      userId: Value(e.userId),
      workId: Value(e.workId),
      title: Value(e.title),
      author: Value(e.author),
      mediaType: Value(e.mediaType.name),
      format: Value(e.format.name),
      exactHash: Value(e.exactHash),
      softKey: Value(e.softKey),
      durationSeconds: Value(e.durationSeconds),
      source: Value(e.source.name),
      updatedAt: Value(e.updatedAt.toUtc()),
    );
  }

  MediaCatalogEntry _fromRow(MediaCatalogCacheEntry row) {
    return MediaCatalogEntry(
      id: row.id,
      userId: row.userId,
      workId: row.workId,
      title: row.title,
      author: row.author,
      mediaType: MediaType.values.byName(row.mediaType),
      format: MediaFormat.values.byName(row.format),
      exactHash: row.exactHash,
      softKey: row.softKey,
      durationSeconds: row.durationSeconds,
      updatedAt: row.updatedAt.toUtc(),
      source: MediaCatalogSource.values.byName(row.source),
    );
  }
}
