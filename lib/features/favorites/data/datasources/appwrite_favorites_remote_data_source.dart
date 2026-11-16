import 'package:appwrite/appwrite.dart';
import 'package:read_beat/core/config/appwrite_config.dart';
import 'package:read_beat/core/errors/app_exception.dart';
import 'package:read_beat/core/errors/result.dart';
import 'package:read_beat/core/logger/app_logger.dart';
import 'package:read_beat/features/favorites/domain/models/favorite_record.dart';

abstract interface class FavoritesRemoteDataSource {
  Future<Result<List<FavoriteRecord>>> listForUser(String userId);

  Future<Result<FavoriteRecord>> upsert(FavoriteRecord record);

  Future<Result<void>> delete(FavoriteRecord record);
}

final class AppwriteFavoritesRemoteDataSource
    implements FavoritesRemoteDataSource {
  AppwriteFavoritesRemoteDataSource({
    required this._tablesDB,
    required this.config,
    AppLogger? logger,
  }) : _logger = logger ?? AppLogger();

  final TablesDB _tablesDB;
  final AppwriteConfig config;
  final AppLogger _logger;

  String get _databaseId => config.databaseId;
  String get _tableId => config.favoritesCollectionId;

  @override
  Future<Result<List<FavoriteRecord>>> listForUser(String userId) async {
    try {
      final rows = await _tablesDB.listRows(
        databaseId: _databaseId,
        tableId: _tableId,
        queries: [Query.equal('userId', userId)],
      );
      final items = rows.rows
          .map((row) => FavoriteRecord.fromJson({...row.data, 'id': row.$id}))
          .toList();
      return Success(items);
    } on AppwriteException catch (e) {
      _logger.warning('favorites list failed', e);
      return Failure(
        NetworkException(e.message ?? 'Favorites list failed', cause: e),
      );
    } catch (e) {
      return Failure(NetworkException('Favorites list failed', cause: e));
    }
  }

  @override
  Future<Result<FavoriteRecord>> upsert(FavoriteRecord record) async {
    try {
      final existingId = await _resolveRowId(record);
      if (existingId != null) {
        final updated = await _tablesDB.updateRow(
          databaseId: _databaseId,
          tableId: _tableId,
          rowId: existingId,
          data: _payload(record),
        );
        return Success(
          FavoriteRecord.fromJson({...updated.data, 'id': updated.$id}),
        );
      }
      final created = await _tablesDB.createRow(
        databaseId: _databaseId,
        tableId: _tableId,
        rowId: record.id,
        data: _payload(record),
        permissions: [
          Permission.read(Role.user(record.userId)),
          Permission.update(Role.user(record.userId)),
          Permission.delete(Role.user(record.userId)),
        ],
      );
      return Success(
        FavoriteRecord.fromJson({...created.data, 'id': created.$id}),
      );
    } on AppwriteException catch (e) {
      return Failure(
        NetworkException(e.message ?? 'Favorite upsert failed', cause: e),
      );
    } catch (e) {
      return Failure(NetworkException('Favorite upsert failed', cause: e));
    }
  }

  @override
  Future<Result<void>> delete(FavoriteRecord record) async {
    try {
      final existingId = await _resolveRowId(record);
      if (existingId == null) return const Success(null);
      await _tablesDB.deleteRow(
        databaseId: _databaseId,
        tableId: _tableId,
        rowId: existingId,
      );
      return const Success(null);
    } on AppwriteException catch (e) {
      if (e.code == 404) return const Success(null);
      return Failure(
        NetworkException(e.message ?? 'Favorite delete failed', cause: e),
      );
    } catch (e) {
      return Failure(NetworkException('Favorite delete failed', cause: e));
    }
  }

  Future<String?> _resolveRowId(FavoriteRecord record) async {
    try {
      await _tablesDB.getRow(
        databaseId: _databaseId,
        tableId: _tableId,
        rowId: record.id,
      );
      return record.id;
    } on AppwriteException catch (e) {
      if (e.code != 404) rethrow;
    }
    final rows = await _tablesDB.listRows(
      databaseId: _databaseId,
      tableId: _tableId,
      queries: [
        Query.equal('userId', record.userId),
        Query.equal('workId', record.workId),
        Query.limit(1),
      ],
    );
    if (rows.rows.isEmpty) return null;
    return rows.rows.first.$id;
  }

  Map<String, dynamic> _payload(FavoriteRecord r) => {
    'userId': r.userId,
    'workId': r.workId,
    'isFavorite': r.isFavorite,
    'updatedAt': r.updatedAt.toUtc().toIso8601String(),
  };
}
