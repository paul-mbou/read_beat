import 'package:read_beat/core/services/secure_storage_service.dart';
import 'package:read_beat/features/recap_ai/domain/recap_service.dart';

/// Consent-only recap stub — never sends chapter text.
final class LocalRecapService implements RecapService {
  LocalRecapService(this._storage);

  final SecureStorageService _storage;

  @override
  Future<bool> get isConsentGranted async {
    final raw = await _storage.read(SecureStorageService.recapConsentKey);
    return raw == '1';
  }

  @override
  Future<void> setConsent(bool granted) {
    return _storage.write(
      SecureStorageService.recapConsentKey,
      granted ? '1' : '0',
    );
  }

  @override
  Future<String?> summarizePreviousChapters({
    required String mediaId,
    required String upToChapterId,
  }) async {
    if (!await isConsentGranted) return null;
    return null;
  }
}
