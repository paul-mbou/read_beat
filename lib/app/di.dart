import 'package:appwrite/appwrite.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:read_beat/core/config/appwrite_client.dart';
import 'package:read_beat/core/config/appwrite_config.dart';
import 'package:read_beat/core/config/feature_flags.dart';
import 'package:read_beat/core/database/app_database.dart';
import 'package:read_beat/core/logger/app_logger.dart';
import 'package:read_beat/core/services/connectivity_service.dart';
import 'package:read_beat/core/services/device_id_service.dart';
import 'package:read_beat/core/services/secure_storage_service.dart';
import 'package:read_beat/features/auth/data/repositories/appwrite_auth_repository.dart';
import 'package:read_beat/features/auth/domain/repositories/auth_repository.dart';
import 'package:read_beat/features/cloud_storage/data/datasources/appwrite_cloud_storage_remote_data_source.dart';
import 'package:read_beat/features/content_store/domain/content_store_service.dart';
import 'package:read_beat/features/favorites/data/datasources/appwrite_favorites_remote_data_source.dart';
import 'package:read_beat/features/favorites/data/repositories/local_favorite_repository.dart';
import 'package:read_beat/features/library/data/datasources/appwrite_media_catalog_remote_data_source.dart';
import 'package:read_beat/features/library/data/repositories/local_media_catalog_repository.dart';
import 'package:read_beat/features/onboarding/domain/permission_service.dart';
import 'package:read_beat/features/playlists/data/datasources/appwrite_playlists_remote_data_source.dart';
import 'package:read_beat/features/playlists/data/repositories/local_playlist_repository.dart';
import 'package:read_beat/features/progress/data/datasources/appwrite_progress_remote_data_source.dart';
import 'package:read_beat/features/progress/data/repositories/local_progress_repository.dart';
import 'package:read_beat/features/progress/domain/progress_user_resolver.dart';
import 'package:read_beat/features/progress/domain/repositories/progress_repository.dart';
import 'package:read_beat/features/recap_ai/data/local_recap_service.dart';
import 'package:read_beat/features/recap_ai/domain/recap_service.dart';
import 'package:read_beat/features/sync/data/repositories/local_sync_repository.dart';
import 'package:read_beat/features/sync/domain/repositories/sync_repository.dart';

final appLoggerProvider = Provider<AppLogger>((ref) => AppLogger());

final appwriteConfigProvider = Provider<AppwriteConfig>(
  (ref) => AppwriteConfig.fromEnvironment(),
);

final secureStorageProvider = Provider<SecureStorageService>(
  (ref) => SecureStorageService(),
);

final connectivityProvider = Provider<ConnectivityService>(
  (ref) => ConnectivityService(),
);

final deviceIdServiceProvider = Provider<DeviceIdService>(
  (ref) => DeviceIdService(ref.watch(secureStorageProvider)),
);

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final appwriteClientProvider = Provider<Client>((ref) => client);

final accountProvider = Provider<Account>(
  (ref) => Account(ref.watch(appwriteClientProvider)),
);

final tablesDbProvider = Provider<TablesDB>(
  (ref) => TablesDB(ref.watch(appwriteClientProvider)),
);

final storageProvider = Provider<Storage>(
  (ref) => Storage(ref.watch(appwriteClientProvider)),
);

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final repo = AppwriteAuthRepository(
    ref.watch(accountProvider),
    logger: ref.watch(appLoggerProvider),
  );
  ref.onDispose(repo.dispose);
  return repo;
});

final progressUserResolverProvider = Provider<ProgressUserResolver>(
  (ref) => ProgressUserResolver(ref.watch(authRepositoryProvider)),
);

final progressRepositoryProvider = Provider<ProgressRepository>(
  (ref) => LocalProgressRepository(
    ref.watch(appDatabaseProvider),
    logger: ref.watch(appLoggerProvider),
  ),
);

final syncRepositoryProvider = Provider<SyncRepository>(
  (ref) => LocalSyncRepository(
    ref.watch(appDatabaseProvider),
    logger: ref.watch(appLoggerProvider),
  ),
);

final progressRemoteDataSourceProvider = Provider<ProgressRemoteDataSource>(
  (ref) => AppwriteProgressRemoteDataSource(
    tablesDB: ref.watch(tablesDbProvider),
    config: ref.watch(appwriteConfigProvider),
    logger: ref.watch(appLoggerProvider),
  ),
);

final mediaCatalogRemoteDataSourceProvider =
    Provider<MediaCatalogRemoteDataSource>(
      (ref) => AppwriteMediaCatalogRemoteDataSource(
        tablesDB: ref.watch(tablesDbProvider),
        config: ref.watch(appwriteConfigProvider),
        logger: ref.watch(appLoggerProvider),
      ),
    );

final mediaCatalogLocalProvider = Provider<LocalMediaCatalogRepository>(
  (ref) => LocalMediaCatalogRepository(
    ref.watch(appDatabaseProvider),
    logger: ref.watch(appLoggerProvider),
  ),
);

final favoriteRepositoryProvider = Provider<LocalFavoriteRepository>(
  (ref) => LocalFavoriteRepository(
    ref.watch(appDatabaseProvider),
    logger: ref.watch(appLoggerProvider),
  ),
);

final playlistRepositoryProvider = Provider<LocalPlaylistRepository>(
  (ref) => LocalPlaylistRepository(
    ref.watch(appDatabaseProvider),
    logger: ref.watch(appLoggerProvider),
  ),
);

final favoritesRemoteDataSourceProvider = Provider<FavoritesRemoteDataSource>(
  (ref) => AppwriteFavoritesRemoteDataSource(
    tablesDB: ref.watch(tablesDbProvider),
    config: ref.watch(appwriteConfigProvider),
    logger: ref.watch(appLoggerProvider),
  ),
);

final playlistsRemoteDataSourceProvider = Provider<PlaylistsRemoteDataSource>(
  (ref) => AppwritePlaylistsRemoteDataSource(
    tablesDB: ref.watch(tablesDbProvider),
    config: ref.watch(appwriteConfigProvider),
    logger: ref.watch(appLoggerProvider),
  ),
);

final recapServiceProvider = Provider<RecapService>(
  (ref) => LocalRecapService(ref.watch(secureStorageProvider)),
);

final permissionServiceProvider = Provider<AppPermissionService>(
  (ref) => AppPermissionService(),
);

/// Binary backup for paid tier — wired only when [FeatureFlags.cloudFileBackup].
final cloudStorageRemoteDataSourceProvider =
    Provider<CloudStorageRemoteDataSource?>(
      (ref) {
        if (!FeatureFlags.cloudFileBackup) return null;
        return AppwriteCloudStorageRemoteDataSource(
          storage: ref.watch(storageProvider),
          config: ref.watch(appwriteConfigProvider),
          logger: ref.watch(appLoggerProvider),
        );
      },
    );

final contentStoreServiceProvider = Provider<ContentStoreService>(
  (ref) => DisabledContentStoreService(),
);
