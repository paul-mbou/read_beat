/// Global app-level constants for ReadBeat.
abstract final class AppConstants {
  static const String appName = 'ReadBeat';
  static const String databaseName = 'read_beat';

  /// Approximate audio progress persist interval.
  static const Duration audioProgressInterval = Duration(seconds: 5);

  /// Debounce for ebook page/chapter progress writes.
  static const Duration ebookProgressDebounce = Duration(milliseconds: 800);

  static const int syncMaxAttempts = 8;
  static const Duration syncInitialBackoff = Duration(seconds: 2);
}
