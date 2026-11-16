import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:read_beat/app/di.dart';
import 'package:read_beat/core/services/secure_storage_service.dart';
import 'package:read_beat/features/library/presentation/providers/desk_home_providers.dart';
import 'package:read_beat/features/sync/data/app_sync_engine.dart';
import 'package:read_beat/features/sync/domain/repositories/sync_repository.dart';

final syncEngineProvider = Provider<SyncEngine>(
  (ref) => AppSyncEngine(
    syncRepository: ref.watch(syncRepositoryProvider),
    progressRepository: ref.watch(progressRepositoryProvider),
    remoteProgress: ref.watch(progressRemoteDataSourceProvider),
    mediaCatalogRemote: ref.watch(mediaCatalogRemoteDataSourceProvider),
    mediaCatalogLocal: ref.watch(mediaCatalogLocalProvider),
    libraryRepository: ref.watch(libraryRepositoryProvider),
    favoritesLocal: ref.watch(favoriteRepositoryProvider),
    favoritesRemote: ref.watch(favoritesRemoteDataSourceProvider),
    playlistsLocal: ref.watch(playlistRepositoryProvider),
    playlistsRemote: ref.watch(playlistsRemoteDataSourceProvider),
    connectivity: ref.watch(connectivityProvider),
    authRepository: ref.watch(authRepositoryProvider),
    logger: ref.watch(appLoggerProvider),
  ),
);

final class SyncStatus {
  const SyncStatus({
    this.lastSuccessAt,
    this.busy = false,
    this.pendingCount = 0,
    this.online = true,
  });

  final DateTime? lastSuccessAt;
  final bool busy;
  final int pendingCount;
  final bool online;

  SyncStatus copyWith({
    DateTime? lastSuccessAt,
    bool? busy,
    int? pendingCount,
    bool? online,
    bool clearLastSuccess = false,
  }) {
    return SyncStatus(
      lastSuccessAt: clearLastSuccess
          ? null
          : (lastSuccessAt ?? this.lastSuccessAt),
      busy: busy ?? this.busy,
      pendingCount: pendingCount ?? this.pendingCount,
      online: online ?? this.online,
    );
  }
}

final syncStatusProvider = NotifierProvider<SyncStatusController, SyncStatus>(
  SyncStatusController.new,
);

final class SyncStatusController extends Notifier<SyncStatus> {
  @override
  SyncStatus build() {
    Future<void>.microtask(_hydrate);
    return const SyncStatus();
  }

  Future<void> _hydrate() async {
    final raw = await ref
        .read(secureStorageProvider)
        .read(SecureStorageService.lastSyncAtKey);
    final online = await ref.read(connectivityProvider).isOnline;
    final pending = await ref.read(syncRepositoryProvider).pending();
    if (!ref.mounted) return;
    state = SyncStatus(
      lastSuccessAt: DateTime.tryParse(raw ?? '')?.toUtc(),
      online: online,
      pendingCount: pending.valueOrNull?.length ?? 0,
    );
  }

  Future<void> refreshPending() async {
    final pending = await ref.read(syncRepositoryProvider).pending();
    final online = await ref.read(connectivityProvider).isOnline;
    if (!ref.mounted) return;
    state = state.copyWith(
      pendingCount: pending.valueOrNull?.length ?? 0,
      online: online,
    );
  }

  void setBusy(bool busy) {
    state = state.copyWith(busy: busy);
  }

  void setOnline(bool online) {
    state = state.copyWith(online: online);
  }

  Future<void> markSuccess() async {
    final now = DateTime.now().toUtc();
    await ref
        .read(secureStorageProvider)
        .write(SecureStorageService.lastSyncAtKey, now.toIso8601String());
    final pending = await ref.read(syncRepositoryProvider).pending();
    if (!ref.mounted) return;
    state = state.copyWith(
      lastSuccessAt: now,
      pendingCount: pending.valueOrNull?.length ?? 0,
      busy: false,
      online: true,
    );
  }
}
