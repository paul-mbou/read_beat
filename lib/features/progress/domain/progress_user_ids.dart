/// Progress ownership ids for local-first sync.
abstract final class ProgressUserIds {
  /// Guest / unsigned device namespace (never syncs as-is to Appwrite).
  static const local = 'local';

  static bool isLocal(String userId) => userId == local;
}
