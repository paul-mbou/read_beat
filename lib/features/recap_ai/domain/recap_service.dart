/// Future AI chapter recap — interface only in MVP.
///
/// No content is sent without explicit user consent.
abstract interface class RecapService {
  Future<bool> get isConsentGranted;

  Future<void> setConsent(bool granted);

  /// Anticipated API — not implemented in MVP.
  Future<String?> summarizePreviousChapters({
    required String mediaId,
    required String upToChapterId,
  });
}

final class DisabledRecapService implements RecapService {
  const DisabledRecapService();

  @override
  Future<bool> get isConsentGranted async => false;

  @override
  Future<void> setConsent(bool granted) async {}

  @override
  Future<String?> summarizePreviousChapters({
    required String mediaId,
    required String upToChapterId,
  }) async => null;
}
