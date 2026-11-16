import 'dart:io';

import 'package:appwrite/appwrite.dart';
import 'package:read_beat/core/config/appwrite_config.dart';
import 'package:read_beat/core/errors/app_exception.dart';
import 'package:read_beat/core/errors/result.dart';
import 'package:read_beat/core/logger/app_logger.dart';

/// Private user file storage via Appwrite Storage.
abstract interface class CloudStorageRemoteDataSource {
  Future<Result<String>> upload({
    required String userId,
    required String fileId,
    required File file,
  });

  Future<Result<List<int>>> download({required String fileId});

  Future<Result<void>> delete({required String fileId});
}

final class AppwriteCloudStorageRemoteDataSource
    implements CloudStorageRemoteDataSource {
  AppwriteCloudStorageRemoteDataSource({
    required this._storage,
    required this.config,
    AppLogger? logger,
  }) : _logger = logger ?? AppLogger();

  final Storage _storage;
  final AppwriteConfig config;
  final AppLogger _logger;

  @override
  Future<Result<String>> upload({
    required String userId,
    required String fileId,
    required File file,
  }) async {
    try {
      final result = await _storage.createFile(
        bucketId: config.filesBucketId,
        fileId: fileId,
        file: InputFile.fromPath(path: file.path),
        permissions: [
          Permission.read(Role.user(userId)),
          Permission.update(Role.user(userId)),
          Permission.delete(Role.user(userId)),
        ],
      );
      return Success(result.$id);
    } on AppwriteException catch (e) {
      _logger.warning('upload failed', e);
      return Failure(
        StorageException(
          e.message ?? 'Upload failed',
          cause: e,
          code: '${e.code}',
        ),
      );
    } catch (e) {
      return Failure(StorageException('Upload failed', cause: e));
    }
  }

  @override
  Future<Result<List<int>>> download({required String fileId}) async {
    try {
      final bytes = await _storage.getFileDownload(
        bucketId: config.filesBucketId,
        fileId: fileId,
      );
      return Success(bytes);
    } on AppwriteException catch (e) {
      return Failure(
        StorageException(
          e.message ?? 'Download failed',
          cause: e,
          code: '${e.code}',
        ),
      );
    } catch (e) {
      return Failure(StorageException('Download failed', cause: e));
    }
  }

  @override
  Future<Result<void>> delete({required String fileId}) async {
    try {
      await _storage.deleteFile(bucketId: config.filesBucketId, fileId: fileId);
      return const Success(null);
    } on AppwriteException catch (e) {
      return Failure(
        StorageException(
          e.message ?? 'Delete failed',
          cause: e,
          code: '${e.code}',
        ),
      );
    } catch (e) {
      return Failure(StorageException('Delete failed', cause: e));
    }
  }
}
