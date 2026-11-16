import 'package:appwrite/appwrite.dart';
import 'package:read_beat/core/config/appwrite_config.dart';
import 'package:read_beat/core/errors/app_exception.dart';
import 'package:read_beat/core/errors/result.dart';
import 'package:read_beat/core/logger/app_logger.dart';
import 'package:read_beat/features/library/domain/models/media_catalog_entry.dart';

abstract interface class MediaCatalogRemoteDataSource {
  Future<Result<List<MediaCatalogEntry>>> listForUser(String userId);

  Future<Result<MediaCatalogEntry>> upsert(MediaCatalogEntry entry);
}

final class AppwriteMediaCatalogRemoteDataSource
    implements MediaCatalogRemoteDataSource {
  AppwriteMediaCatalogRemoteDataSource({
    required this._tablesDB,
    required this.config,
    AppLogger? logger,
  }) : _logger = logger ?? AppLogger();

  final TablesDB _tablesDB;
  final AppwriteConfig config;
  final AppLogger _logger;

  String get _databaseId => config.databaseId;
  String get _tableId => config.mediaCatalogCollectionId;

  @override
  Future<Result<List<MediaCatalogEntry>>> listForUser(String userId) async {
    try {
      final rows = await _tablesDB.listRows(
        databaseId: _databaseId,
        tableId: _tableId,
        queries: [Query.equal('userId', userId)],
      );
      final items = rows.rows
          .map(
            (row) => MediaCatalogEntry.fromJson({...row.data, 'id': row.$id}),
          )
          .toList();
      return Success(items);
    } on AppwriteException catch (e) {
      _logger.warning('media catalog list failed', e);
      return Failure(
        NetworkException(e.message ?? 'Catalog list failed', cause: e),
      );
    } catch (e) {
      return Failure(NetworkException('Catalog list failed', cause: e));
    }
  }

  @override
  Future<Result<MediaCatalogEntry>> upsert(MediaCatalogEntry entry) async {
    try {
      final existingId = await _resolveRowId(entry);
      if (existingId != null) {
        final updated = await _tablesDB.updateRow(
          databaseId: _databaseId,
          tableId: _tableId,
          rowId: existingId,
          data: _payload(entry),
        );
        return Success(
          MediaCatalogEntry.fromJson({...updated.data, 'id': updated.$id}),
        );
      }
      final created = await _tablesDB.createRow(
        databaseId: _databaseId,
        tableId: _tableId,
        rowId: entry.id,
        data: _payload(entry),
        permissions: [
          Permission.read(Role.user(entry.userId)),
          Permission.update(Role.user(entry.userId)),
          Permission.delete(Role.user(entry.userId)),
        ],
      );
      return Success(
        MediaCatalogEntry.fromJson({...created.data, 'id': created.$id}),
      );
    } on AppwriteException catch (e) {
      return Failure(
        NetworkException(e.message ?? 'Catalog upsert failed', cause: e),
      );
    } catch (e) {
      return Failure(NetworkException('Catalog upsert failed', cause: e));
    }
  }

  Future<String?> _resolveRowId(MediaCatalogEntry entry) async {
    try {
      await _tablesDB.getRow(
        databaseId: _databaseId,
        tableId: _tableId,
        rowId: entry.id,
      );
      return entry.id;
    } on AppwriteException catch (e) {
      if (e.code != 404) rethrow;
    }
    final rows = await _tablesDB.listRows(
      databaseId: _databaseId,
      tableId: _tableId,
      queries: [
        Query.equal('userId', entry.userId),
        Query.equal('workId', entry.workId),
        Query.limit(1),
      ],
    );
    if (rows.rows.isEmpty) return null;
    return rows.rows.first.$id;
  }

  Map<String, dynamic> _payload(MediaCatalogEntry e) => {
    'userId': e.userId,
    'workId': e.workId,
    'title': e.title,
    'author': e.author,
    'mediaType': e.mediaType.name,
    'format': e.format.name,
    'exactHash': e.exactHash,
    'softKey': e.softKey,
    'durationSeconds': e.durationSeconds,
    'updatedAt': e.updatedAt.toUtc().toIso8601String(),
    'source': e.source.name,
  };
}
