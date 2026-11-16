import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Thin secure storage for tokens and device secrets.
final class SecureStorageService {
  SecureStorageService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const sessionKey = 'readbeat_session_secret';
  static const deviceIdKey = 'readbeat_device_id';
  static const onboardingCompletedKey = 'readbeat_onboarding_completed';
  static const recapConsentKey = 'readbeat_recap_consent';
  static const lastSyncAtKey = 'readbeat_last_sync_at';
  static const libraryLayoutKey = 'readbeat_library_layout';

  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  Future<String?> read(String key) => _storage.read(key: key);

  Future<void> delete(String key) => _storage.delete(key: key);

  Future<void> clear() => _storage.deleteAll();
}
