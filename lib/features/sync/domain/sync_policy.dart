import 'package:read_beat/core/constants/app_constants.dart';
import 'package:read_beat/features/progress/domain/models/media_progress.dart';

/// Conflict resolution: newest [updatedAt] wins.
/// On equal timestamps, prefer lexicographically greater [deviceId].
abstract final class SyncPolicy {
  static MediaProgress pickWinner(MediaProgress a, MediaProgress b) {
    final cmp = a.updatedAt.compareTo(b.updatedAt);
    if (cmp > 0) return a;
    if (cmp < 0) return b;
    return a.deviceId.compareTo(b.deviceId) >= 0 ? a : b;
  }

  static bool shouldReplace({
    required MediaProgress existing,
    required MediaProgress incoming,
  }) {
    return pickWinner(existing, incoming) == incoming;
  }

  /// Exponential backoff delay for attempt index (0-based after increment).
  static Duration backoffForAttempt(
    int attempt, {
    Duration initial = AppConstants.syncInitialBackoff,
    int maxAttempts = AppConstants.syncMaxAttempts,
  }) {
    final capped = attempt.clamp(0, maxAttempts);
    final multiplier = 1 << capped;
    final seconds = initial.inSeconds * multiplier;
    return Duration(seconds: seconds.clamp(initial.inSeconds, 300));
  }
}
