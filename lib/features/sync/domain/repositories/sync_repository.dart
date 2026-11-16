import 'package:read_beat/core/errors/result.dart';
import 'package:read_beat/features/sync/domain/models/sync_outbox_item.dart';

abstract interface class SyncRepository {
  Future<Result<void>> enqueue(SyncOutboxItem item);

  /// Due pending/failed items (respects backoff + recovers stale in-flight).
  Future<Result<List<SyncOutboxItem>>> pending({int limit = 50});

  Future<Result<void>> markCompleted(String id);

  Future<Result<void>> markFailed(String id, String error);

  Future<Result<void>> markInFlight(String id);
}

/// Orchestrates push/pull for progress, catalog, favorites, and playlists.
abstract interface class SyncEngine {
  /// Push due outbox items when online + signed in.
  Future<Result<void>> flush();

  /// Pull remote progress for [userId] and LWW-merge locally.
  Future<Result<void>> pullRemoteProgress({required String userId});

  /// Rebind guest progress → auth user, then pull, then flush.
  Future<Result<void>> syncNow();
}
