import 'package:appwrite/appwrite.dart';
import 'package:read_beat/core/config/appwrite_config.dart';
import 'package:read_beat/core/errors/app_exception.dart';
import 'package:read_beat/core/errors/result.dart';
import 'package:read_beat/core/logger/app_logger.dart';
import 'package:read_beat/features/progress/domain/models/media_progress.dart';
import 'package:read_beat/features/sync/domain/sync_policy.dart';

/// Remote progress CRUD against Appwrite TablesDB.
abstract interface class ProgressRemoteDataSource {
  Future<Result<List<MediaProgress>>> listForUser(String userId);

  Future<Result<MediaProgress>> upsert(MediaProgress progress);
}

final class AppwriteProgressRemoteDataSource
    implements ProgressRemoteDataSource {
  AppwriteProgressRemoteDataSource({
    required this._tablesDB,
    required this.config,
    AppLogger? logger,
  }) : _logger = logger ?? AppLogger();

  final TablesDB _tablesDB;
  final AppwriteConfig config;
  final AppLogger _logger;

  String get _databaseId => config.databaseId;
  String get _tableId => config.progressCollectionId;

  @override
  Future<Result<List<MediaProgress>>> listForUser(String userId) async {
    try {
      final rows = await _tablesDB.listRows(
        databaseId: _databaseId,
        tableId: _tableId,
        queries: [Query.equal('userId', userId)],
      );
      final items = rows.rows
          .map((row) => MediaProgress.fromJson({...row.data, 'id': row.$id}))
          .toList();
      return Success(items);
    } on AppwriteException catch (e) {
      _logger.warning('listForUser failed', e);
      return Failure(
        NetworkException(e.message ?? 'Remote progress list failed', cause: e),
      );
    } catch (e) {
      return Failure(NetworkException('Remote progress list failed', cause: e));
    }
  }

  @override
  Future<Result<MediaProgress>> upsert(MediaProgress progress) async {
    try {
      final existingId = await _resolveRowId(progress);
      if (existingId != null) {
        final existing = await _tablesDB.getRow(
          databaseId: _databaseId,
          tableId: _tableId,
          rowId: existingId,
        );
        final remote = MediaProgress.fromJson({
          ...existing.data,
          'id': existing.$id,
        });
        final winner = SyncPolicy.pickWinner(remote, progress);
        final updated = await _tablesDB.updateRow(
          databaseId: _databaseId,
          tableId: _tableId,
          rowId: existingId,
          data: _payload(winner),
        );
        return Success(
          MediaProgress.fromJson({...updated.data, 'id': updated.$id}),
        );
      }

      final created = await _tablesDB.createRow(
        databaseId: _databaseId,
        tableId: _tableId,
        rowId: progress.id,
        data: _payload(progress),
        permissions: [
          Permission.read(Role.user(progress.userId)),
          Permission.update(Role.user(progress.userId)),
          Permission.delete(Role.user(progress.userId)),
        ],
      );
      return Success(
        MediaProgress.fromJson({...created.data, 'id': created.$id}),
      );
    } on AppwriteException catch (e) {
      return Failure(
        NetworkException(
          e.message ?? 'Remote progress upsert failed',
          cause: e,
        ),
      );
    } catch (e) {
      return Failure(
        NetworkException('Remote progress upsert failed', cause: e),
      );
    }
  }

  /// Prefer document id; else (userId, workId); else legacy (userId, mediaId).
  Future<String?> _resolveRowId(MediaProgress progress) async {
    try {
      await _tablesDB.getRow(
        databaseId: _databaseId,
        tableId: _tableId,
        rowId: progress.id,
      );
      return progress.id;
    } on AppwriteException catch (e) {
      if (e.code != 404) rethrow;
    }

    final byWork = await _tablesDB.listRows(
      databaseId: _databaseId,
      tableId: _tableId,
      queries: [
        Query.equal('userId', progress.userId),
        Query.equal('workId', progress.workId),
        Query.limit(1),
      ],
    );
    if (byWork.rows.isNotEmpty) return byWork.rows.first.$id;

    final rows = await _tablesDB.listRows(
      databaseId: _databaseId,
      tableId: _tableId,
      queries: [
        Query.equal('userId', progress.userId),
        Query.equal('mediaId', progress.mediaId),
        Query.limit(1),
      ],
    );
    if (rows.rows.isEmpty) return null;
    return rows.rows.first.$id;
  }

  Map<String, dynamic> _payload(MediaProgress p) => {
    'userId': p.userId,
    'mediaId': p.mediaId,
    'workId': p.workId,
    'mediaType': p.mediaType.name,
    'position': p.position,
    'duration': p.duration,
    'percent': p.percent,
    'chapterOrPage': p.chapterOrPage,
    'cfi': p.cfi,
    'title': p.title,
    'deviceId': p.deviceId,
    'updatedAt': p.updatedAt.toUtc().toIso8601String(),
  };
}
