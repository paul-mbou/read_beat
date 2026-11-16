import 'package:drift/drift.dart';
import 'package:read_beat/core/constants/app_constants.dart';
import 'package:read_beat/core/database/app_database.dart';
import 'package:read_beat/core/errors/app_exception.dart';
import 'package:read_beat/core/errors/result.dart';
import 'package:read_beat/core/logger/app_logger.dart';
import 'package:read_beat/features/sync/domain/models/sync_outbox_item.dart';
import 'package:read_beat/features/sync/domain/repositories/sync_repository.dart';
import 'package:read_beat/features/sync/domain/sync_policy.dart';

final class LocalSyncRepository implements SyncRepository {
  LocalSyncRepository(this._db, {AppLogger? logger})
    : _logger = logger ?? AppLogger();

  final AppDatabase _db;
  final AppLogger _logger;

  /// Stale in-flight rows older than this are recovered as pending.
  static const staleInFlight = Duration(minutes: 10);

  @override
  Future<Result<void>> enqueue(SyncOutboxItem item) async {
    try {
      await _db
          .into(_db.syncOutboxEntries)
          .insert(
            SyncOutboxEntriesCompanion.insert(
              id: item.id,
              entityType: item.entityType.name,
              entityId: item.entityId,
              operation: item.operation.name,
              payloadJson: item.payloadJson,
              createdAt: item.createdAt.toUtc(),
              updatedAt: item.updatedAt.toUtc(),
              status: Value(item.status.name),
              attempts: Value(item.attempts),
              lastError: Value(item.lastError),
              idempotencyKey: Value(item.idempotencyKey),
              nextAttemptAt: Value(item.nextAttemptAt),
            ),
          );
      return const Success(null);
    } catch (e, st) {
      _logger.error('Failed to enqueue sync item', e, st);
      return Failure(SyncException('Failed to enqueue sync item', cause: e));
    }
  }

  @override
  Future<Result<List<SyncOutboxItem>>> pending({int limit = 50}) async {
    try {
      final now = DateTime.now().toUtc();
      await _recoverStaleInFlight(now);

      final rows =
          await (_db.select(_db.syncOutboxEntries)
                ..where(
                  (t) =>
                      t.status.equals(SyncOutboxStatus.pending.name) |
                      t.status.equals(SyncOutboxStatus.failed.name),
                )
                ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])
                ..limit(limit * 3))
              .get();

      final due = <SyncOutboxItem>[];
      for (final row in rows) {
        if (row.attempts >= AppConstants.syncMaxAttempts) {
          await (_db.update(
            _db.syncOutboxEntries,
          )..where((t) => t.id.equals(row.id))).write(
            SyncOutboxEntriesCompanion(
              status: Value(SyncOutboxStatus.deadLetter.name),
              updatedAt: Value(now),
              lastError: Value(
                row.lastError ?? 'Exceeded ${AppConstants.syncMaxAttempts} attempts',
              ),
            ),
          );
          continue;
        }
        final next = row.nextAttemptAt;
        if (next != null && next.isAfter(now)) continue;
        due.add(_fromRow(row));
        if (due.length >= limit) break;
      }
      return Success(due);
    } catch (e, st) {
      _logger.error('Failed to load pending sync items', e, st);
      return Failure(
        SyncException('Failed to load pending sync items', cause: e),
      );
    }
  }

  Future<void> _recoverStaleInFlight(DateTime now) async {
    final cutoff = now.subtract(staleInFlight);
    await (_db.update(_db.syncOutboxEntries)..where(
          (t) =>
              t.status.equals(SyncOutboxStatus.inFlight.name) &
              t.updatedAt.isSmallerThanValue(cutoff),
        ))
        .write(
          SyncOutboxEntriesCompanion(
            status: Value(SyncOutboxStatus.pending.name),
            updatedAt: Value(now),
            nextAttemptAt: const Value(null),
          ),
        );
  }

  @override
  Future<Result<void>> markCompleted(String id) =>
      _updateStatus(id, SyncOutboxStatus.completed);

  @override
  Future<Result<void>> markInFlight(String id) =>
      _updateStatus(id, SyncOutboxStatus.inFlight);

  @override
  Future<Result<void>> markFailed(String id, String error) async {
    try {
      final row = await (_db.select(
        _db.syncOutboxEntries,
      )..where((t) => t.id.equals(id))).getSingle();
      final attempts = row.attempts + 1;
      final now = DateTime.now().toUtc();
      final dead = attempts >= AppConstants.syncMaxAttempts;
      final backoff = SyncPolicy.backoffForAttempt(attempts - 1);
      await (_db.update(
        _db.syncOutboxEntries,
      )..where((t) => t.id.equals(id))).write(
        SyncOutboxEntriesCompanion(
          status: Value(
            dead
                ? SyncOutboxStatus.deadLetter.name
                : SyncOutboxStatus.failed.name,
          ),
          attempts: Value(attempts),
          lastError: Value(error),
          nextAttemptAt: Value(dead ? null : now.add(backoff)),
          updatedAt: Value(now),
        ),
      );
      return const Success(null);
    } catch (e, st) {
      _logger.error('Failed to mark sync item failed', e, st);
      return Failure(
        SyncException('Failed to mark sync item failed', cause: e),
      );
    }
  }

  Future<Result<void>> _updateStatus(String id, SyncOutboxStatus status) async {
    try {
      await (_db.update(
        _db.syncOutboxEntries,
      )..where((t) => t.id.equals(id))).write(
        SyncOutboxEntriesCompanion(
          status: Value(status.name),
          updatedAt: Value(DateTime.now().toUtc()),
          nextAttemptAt: status == SyncOutboxStatus.inFlight ||
                  status == SyncOutboxStatus.completed
              ? const Value(null)
              : const Value.absent(),
        ),
      );
      return const Success(null);
    } catch (e, st) {
      _logger.error('Failed to update sync status', e, st);
      return Failure(SyncException('Failed to update sync status', cause: e));
    }
  }

  SyncOutboxItem _fromRow(SyncOutboxEntry row) {
    return SyncOutboxItem(
      id: row.id,
      entityType: SyncEntityType.values.byName(row.entityType),
      entityId: row.entityId,
      operation: SyncOperationType.values.byName(row.operation),
      payloadJson: row.payloadJson,
      status: SyncOutboxStatus.values.byName(row.status),
      attempts: row.attempts,
      lastError: row.lastError,
      idempotencyKey: row.idempotencyKey,
      nextAttemptAt: row.nextAttemptAt?.toUtc(),
      createdAt: row.createdAt.toUtc(),
      updatedAt: row.updatedAt.toUtc(),
    );
  }
}
