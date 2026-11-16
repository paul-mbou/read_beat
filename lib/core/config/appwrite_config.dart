import 'package:read_beat/core/config/environment.dart';

/// Appwrite environment configuration.
final class AppwriteConfig {
  const AppwriteConfig({
    required this.endpoint,
    required this.projectId,
    this.projectName = Environment.appwriteProjectName,
    this.selfSigned = false,
    this.databaseId = 'readbeat',
    this.progressCollectionId = 'progress',
    this.mediaCatalogCollectionId = 'media_catalog',
    this.favoritesCollectionId = 'favorites',
    this.playlistsCollectionId = 'playlists',
    this.filesBucketId = 'media',
  });

  final String endpoint;
  final String projectId;
  final String projectName;
  final bool selfSigned;
  final String databaseId;
  final String progressCollectionId;
  final String mediaCatalogCollectionId;
  final String favoritesCollectionId;
  final String playlistsCollectionId;
  final String filesBucketId;

  bool get isConfigured =>
      endpoint.isNotEmpty &&
      projectId.isNotEmpty &&
      projectId != 'YOUR_PROJECT_ID';

  /// Defaults to the hardcoded [Environment] project (override via dart-define).
  factory AppwriteConfig.fromEnvironment() {
    return AppwriteConfig(
      endpoint: const String.fromEnvironment(
        'APPWRITE_ENDPOINT',
        defaultValue: Environment.appwritePublicEndpoint,
      ),
      projectId: const String.fromEnvironment(
        'APPWRITE_PROJECT_ID',
        defaultValue: Environment.appwriteProjectId,
      ),
      projectName: const String.fromEnvironment(
        'APPWRITE_PROJECT_NAME',
        defaultValue: Environment.appwriteProjectName,
      ),
      selfSigned: const bool.fromEnvironment(
        'APPWRITE_SELF_SIGNED',
        defaultValue: false,
      ),
      databaseId: const String.fromEnvironment(
        'APPWRITE_DATABASE_ID',
        defaultValue: 'readbeat',
      ),
      progressCollectionId: const String.fromEnvironment(
        'APPWRITE_PROGRESS_COLLECTION_ID',
        defaultValue: 'progress',
      ),
      mediaCatalogCollectionId: const String.fromEnvironment(
        'APPWRITE_MEDIA_CATALOG_COLLECTION_ID',
        defaultValue: 'media_catalog',
      ),
      favoritesCollectionId: const String.fromEnvironment(
        'APPWRITE_FAVORITES_COLLECTION_ID',
        defaultValue: 'favorites',
      ),
      playlistsCollectionId: const String.fromEnvironment(
        'APPWRITE_PLAYLISTS_COLLECTION_ID',
        defaultValue: 'playlists',
      ),
      filesBucketId: const String.fromEnvironment(
        'APPWRITE_FILES_BUCKET_ID',
        defaultValue: 'media',
      ),
    );
  }
}
