import 'package:read_beat/core/errors/result.dart';
import 'package:read_beat/features/progress/domain/models/media_progress.dart';
import 'package:read_beat/features/progress/domain/progress_user_ids.dart';

abstract interface class ProgressRepository {
  Future<Result<MediaProgress>> saveLocal(MediaProgress progress);

  Future<Result<MediaProgress?>> getLocal({
    required String userId,
    required String mediaId,
  });

  /// Prefers [preferredUserId], then falls back to [ProgressUserIds.local].
  Future<Result<MediaProgress?>> getBestLocal({
    required String preferredUserId,
    required String mediaId,
  });

  Future<Result<List<MediaProgress>>> listRecent({
    required String userId,
    MediaType? mediaType,
    int limit = 20,
  });

  /// Merge remote progress using SyncPolicy (last-write-wins). No outbox write.
  Future<Result<MediaProgress>> upsertFromRemote(MediaProgress remote);

  /// Move guest (`local`) progress into [authUserId], LWW-merging collisions.
  Future<Result<int>> rebindLocalToUser(String authUserId);
}
