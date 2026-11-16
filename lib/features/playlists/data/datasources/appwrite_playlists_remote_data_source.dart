import 'dart:convert';

import 'package:appwrite/appwrite.dart';
import 'package:read_beat/core/config/appwrite_config.dart';
import 'package:read_beat/core/errors/app_exception.dart';
import 'package:read_beat/core/errors/result.dart';
import 'package:read_beat/core/logger/app_logger.dart';
import 'package:read_beat/features/playlists/domain/models/audio_playlist.dart';

abstract interface class PlaylistsRemoteDataSource {
  Future<Result<List<AudioPlaylist>>> listForUser(String userId);

  Future<Result<AudioPlaylist>> upsert(AudioPlaylist playlist);

  Future<Result<void>> delete(String playlistId);
}

final class AppwritePlaylistsRemoteDataSource
    implements PlaylistsRemoteDataSource {
  AppwritePlaylistsRemoteDataSource({
    required this._tablesDB,
    required this.config,
    AppLogger? logger,
  }) : _logger = logger ?? AppLogger();

  final TablesDB _tablesDB;
  final AppwriteConfig config;
  final AppLogger _logger;

  String get _databaseId => config.databaseId;
  String get _tableId => config.playlistsCollectionId;

  @override
  Future<Result<List<AudioPlaylist>>> listForUser(String userId) async {
    try {
      final rows = await _tablesDB.listRows(
        databaseId: _databaseId,
        tableId: _tableId,
        queries: [Query.equal('userId', userId)],
      );
      return Success(
        rows.rows.map((row) => _fromRowData(row.$id, row.data)).toList(),
      );
    } on AppwriteException catch (e) {
      _logger.warning('playlists list failed', e);
      return Failure(
        NetworkException(e.message ?? 'Playlists list failed', cause: e),
      );
    } catch (e) {
      return Failure(NetworkException('Playlists list failed', cause: e));
    }
  }

  @override
  Future<Result<AudioPlaylist>> upsert(AudioPlaylist playlist) async {
    try {
      final existingId = await _resolveRowId(playlist);
      if (existingId != null) {
        final updated = await _tablesDB.updateRow(
          databaseId: _databaseId,
          tableId: _tableId,
          rowId: existingId,
          data: _payload(playlist),
        );
        return Success(_fromRowData(updated.$id, updated.data));
      }
      final created = await _tablesDB.createRow(
        databaseId: _databaseId,
        tableId: _tableId,
        rowId: playlist.id,
        data: _payload(playlist),
        permissions: [
          Permission.read(Role.user(playlist.userId)),
          Permission.update(Role.user(playlist.userId)),
          Permission.delete(Role.user(playlist.userId)),
        ],
      );
      return Success(_fromRowData(created.$id, created.data));
    } on AppwriteException catch (e) {
      return Failure(
        NetworkException(e.message ?? 'Playlist upsert failed', cause: e),
      );
    } catch (e) {
      return Failure(NetworkException('Playlist upsert failed', cause: e));
    }
  }

  @override
  Future<Result<void>> delete(String playlistId) async {
    try {
      await _tablesDB.deleteRow(
        databaseId: _databaseId,
        tableId: _tableId,
        rowId: playlistId,
      );
      return const Success(null);
    } on AppwriteException catch (e) {
      if (e.code == 404) return const Success(null);
      return Failure(
        NetworkException(e.message ?? 'Playlist delete failed', cause: e),
      );
    } catch (e) {
      return Failure(NetworkException('Playlist delete failed', cause: e));
    }
  }

  Future<String?> _resolveRowId(AudioPlaylist playlist) async {
    try {
      await _tablesDB.getRow(
        databaseId: _databaseId,
        tableId: _tableId,
        rowId: playlist.id,
      );
      return playlist.id;
    } on AppwriteException catch (e) {
      if (e.code != 404) rethrow;
    }
    return null;
  }

  Map<String, dynamic> _payload(AudioPlaylist p) => {
    'userId': p.userId,
    'title': p.title,
    'updatedAt': p.updatedAt.toUtc().toIso8601String(),
    'createdAt': p.createdAt.toUtc().toIso8601String(),
    'tracksJson': jsonEncode(p.tracks.map((t) => t.toJson()).toList()),
  };

  AudioPlaylist _fromRowData(String id, Map<String, dynamic> data) {
    final tracksRaw = data['tracksJson'];
    List<dynamic> tracks = const [];
    if (tracksRaw is String && tracksRaw.isNotEmpty) {
      tracks = jsonDecode(tracksRaw) as List<dynamic>;
    } else if (data['tracks'] is List) {
      tracks = data['tracks'] as List<dynamic>;
    }
    return AudioPlaylist.fromJson({
      ...data,
      'id': id,
      'tracks': tracks,
    });
  }
}
