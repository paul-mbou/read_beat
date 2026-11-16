/// Compile-time feature flags (dart-define). Off by default for MVP.
///
/// Future:
/// - [cloudFileBackup] — upload user media binaries to Appwrite Storage (paid).
/// - [contentStore] — browse/acquire free or paid ebooks & audio from a catalog.
abstract final class FeatureFlags {
  /// Backup the user's own files to ReadBeat cloud (subscription).
  static const cloudFileBackup = bool.fromEnvironment(
    'FF_CLOUD_FILE_BACKUP',
    defaultValue: false,
  );

  /// In-app content store (free/paid listings). Distant / optional product.
  static const contentStore = bool.fromEnvironment(
    'FF_CONTENT_STORE',
    defaultValue: false,
  );
}
