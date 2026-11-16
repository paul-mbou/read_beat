import 'package:read_beat/core/services/secure_storage_service.dart';
import 'package:uuid/uuid.dart';

/// Stable per-install device identifier used in progress sync.
final class DeviceIdService {
  DeviceIdService(this._secureStorage, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  final SecureStorageService _secureStorage;
  final Uuid _uuid;

  String? _cached;

  Future<String> getDeviceId() async {
    if (_cached != null) return _cached!;
    final existing = await _secureStorage.read(
      SecureStorageService.deviceIdKey,
    );
    if (existing != null && existing.isNotEmpty) {
      _cached = existing;
      return existing;
    }
    final created = _uuid.v4();
    await _secureStorage.write(SecureStorageService.deviceIdKey, created);
    _cached = created;
    return created;
  }
}
