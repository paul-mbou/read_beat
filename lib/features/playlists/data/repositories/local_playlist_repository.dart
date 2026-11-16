import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:read_beat/core/database/app_database.dart';
import 'package:read_beat/core/errors/app_exception.dart';
import 'package:read_beat/core/errors/result.dart';
import 'package:read_beat/core/logger/app_logger.dart';
import 'package:read_beat/features/library/domain/models/library_item.dart';
import 'package:read_beat/features/playlists/domain/models/audio_playlist.dart';
import 'package:read_beat/features/progress/domain/progress_user_ids.dart';
import 'package:read_beat/features/sync/domain/models/sync_outbox_item.dart';
import 'package:uuid/uuid.dart';

final class LocalPlaylistRepository {
  LocalPlaylistRepository(this._db, {Uuid? uuid, AppLogger? logger})
    : _uuid = uuid ?? const Uuid(),
      _logger = logger ?? AppLogger();

  final AppDatabase _db;
  final Uuid _uuid;
  final AppLogger _logger;

  Stream<List<AudioPlaylist>> watchAll(String userId) {
    return (_db.select(_db.playlistEntries)
          ..where((t) => t.userId.equals(userId))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .watch()
        .asyncMap((rows) async {
          final out = <AudioPlaylist>[];
          for (final row in rows) {
            out.add(await _hydrate(row));
          }
          return out;
        });
  }

  Future<Result<AudioPlaylist?>> getById(String id) async {
    try {
      final row = await (_db.select(
        _db.playlistEntries,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (row == null) return const Success(null);
      return Success(await _hydrate(row));
    } catch (e, st) {
      _logger.error('get playlist failed', e, st);
      return Failure(StorageException('Failed to load playlist', cause: e));
    }
  }

  Future<Result<AudioPlaylist>> create({
    required String title,
    required String userId,
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      return const Failure(ValidationException('Give this queue a name'));
    }
    try {
      final now = DateTime.now().toUtc();
      final playlist = AudioPlaylist(
        id: _uuid.v4(),
        userId: userId,
        title: trimmed,
        createdAt: now,
        updatedAt: now,
      );
      await _db.transaction(() async {
        await _db.into(_db.playlistEntries).insert(_toPlaylistCompanion(playlist));
        await _replaceOutbox(playlist, SyncOperationType.upsert);
      });
      return Success(playlist);
    } catch (e, st) {
      _logger.error('create playlist failed', e, st);
      return Failure(StorageException('Failed to create playlist', cause: e));
    }
  }

  Future<Result<AudioPlaylist>> rename({
    required String id,
    required String title,
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      return const Failure(ValidationException('Give this queue a name'));
    }
    try {
      final existing = await getById(id);
      if (existing case Failure(:final error)) return Failure(error);
      final playlist = existing.valueOrNull;
      if (playlist == null) {
        return const Failure(StorageException('Playlist not found'));
      }
      final updated = playlist.copyWith(
        title: trimmed,
        updatedAt: DateTime.now().toUtc(),
      );
      await _db.transaction(() async {
        await (_db.update(
          _db.playlistEntries,
        )..where((t) => t.id.equals(id))).write(
          PlaylistEntriesCompanion(
            title: Value(updated.title),
            updatedAt: Value(updated.updatedAt),
          ),
        );
        await _replaceOutbox(updated, SyncOperationType.upsert);
      });
      return Success(updated);
    } catch (e, st) {
      _logger.error('rename playlist failed', e, st);
      return Failure(StorageException('Failed to rename playlist', cause: e));
    }
  }

  Future<Result<void>> delete(String id) async {
    try {
      final existing = await getById(id);
      if (existing case Failure(:final error)) return Failure(error);
      final playlist = existing.valueOrNull;
      if (playlist == null) return const Success(null);

      await _db.transaction(() async {
        await (_db.delete(
          _db.playlistTrackEntries,
        )..where((t) => t.playlistId.equals(id))).go();
        await (_db.delete(
          _db.playlistEntries,
        )..where((t) => t.id.equals(id))).go();
        await _replaceOutbox(playlist, SyncOperationType.delete);
      });
      return const Success(null);
    } catch (e, st) {
      _logger.error('delete playlist failed', e, st);
      return Failure(StorageException('Failed to delete playlist', cause: e));
    }
  }

  Future<Result<AudioPlaylist>> addTrack({
    required String playlistId,
    required LibraryItem item,
  }) async {
    if (!item.isAudio) {
      return const Failure(ValidationException('Queues are for audio only'));
    }
    try {
      final existing = await getById(playlistId);
      if (existing case Failure(:final error)) return Failure(error);
      final playlist = existing.valueOrNull;
      if (playlist == null) {
        return const Failure(StorageException('Playlist not found'));
      }
      if (playlist.tracks.any((t) => t.mediaId == item.id)) {
        return Success(playlist);
      }

      final now = DateTime.now().toUtc();
      final track = PlaylistTrack(
        id: _uuid.v4(),
        playlistId: playlistId,
        mediaId: item.id,
        workId: item.workId,
        sortIndex: playlist.tracks.length,
        addedAt: now,
      );
      final updated = playlist.copyWith(
        updatedAt: now,
        tracks: [...playlist.tracks, track],
      );

      await _db.transaction(() async {
        await _db.into(_db.playlistTrackEntries).insert(_toTrackCompanion(track));
        await (_db.update(_db.playlistEntries)..where((t) => t.id.equals(playlistId)))
            .write(PlaylistEntriesCompanion(updatedAt: Value(now)));
        await _replaceOutbox(updated, SyncOperationType.upsert);
      });
      return Success(updated);
    } catch (e, st) {
      _logger.error('add track failed', e, st);
      return Failure(StorageException('Failed to add track', cause: e));
    }
  }

  Future<Result<AudioPlaylist>> removeTrack({
    required String playlistId,
    required String trackId,
  }) async {
    try {
      final existing = await getById(playlistId);
      if (existing case Failure(:final error)) return Failure(error);
      final playlist = existing.valueOrNull;
      if (playlist == null) {
        return const Failure(StorageException('Playlist not found'));
      }

      final remaining = <PlaylistTrack>[];
      var index = 0;
      for (final track in playlist.tracks) {
        if (track.id == trackId) continue;
        remaining.add(
          PlaylistTrack(
            id: track.id,
            playlistId: track.playlistId,
            mediaId: track.mediaId,
            workId: track.workId,
            sortIndex: index,
            addedAt: track.addedAt,
          ),
        );
        index++;
      }
      final now = DateTime.now().toUtc();
      final updated = playlist.copyWith(updatedAt: now, tracks: remaining);

      await _db.transaction(() async {
        await (_db.delete(
          _db.playlistTrackEntries,
        )..where((t) => t.id.equals(trackId))).go();
        for (final track in remaining) {
          await (_db.update(
            _db.playlistTrackEntries,
          )..where((t) => t.id.equals(track.id))).write(
            PlaylistTrackEntriesCompanion(sortIndex: Value(track.sortIndex)),
          );
        }
        await (_db.update(_db.playlistEntries)..where((t) => t.id.equals(playlistId)))
            .write(PlaylistEntriesCompanion(updatedAt: Value(now)));
        await _replaceOutbox(updated, SyncOperationType.upsert);
      });
      return Success(updated);
    } catch (e, st) {
      _logger.error('remove track failed', e, st);
      return Failure(StorageException('Failed to remove track', cause: e));
    }
  }

  Future<Result<AudioPlaylist>> moveTrack({
    required String playlistId,
    required String trackId,
    required int delta,
  }) async {
    try {
      final existing = await getById(playlistId);
      if (existing case Failure(:final error)) return Failure(error);
      final playlist = existing.valueOrNull;
      if (playlist == null) {
        return const Failure(StorageException('Playlist not found'));
      }
      final tracks = [...playlist.tracks]
        ..sort((a, b) => a.sortIndex.compareTo(b.sortIndex));
      final from = tracks.indexWhere((t) => t.id == trackId);
      if (from < 0) return Success(playlist);
      final to = (from + delta).clamp(0, tracks.length - 1);
      if (to == from) return Success(playlist);
      final item = tracks.removeAt(from);
      tracks.insert(to, item);

      final now = DateTime.now().toUtc();
      final reindexed = <PlaylistTrack>[];
      for (var i = 0; i < tracks.length; i++) {
        final t = tracks[i];
        reindexed.add(
          PlaylistTrack(
            id: t.id,
            playlistId: t.playlistId,
            mediaId: t.mediaId,
            workId: t.workId,
            sortIndex: i,
            addedAt: t.addedAt,
          ),
        );
      }
      final updated = playlist.copyWith(updatedAt: now, tracks: reindexed);

      await _db.transaction(() async {
        for (final track in reindexed) {
          await (_db.update(
            _db.playlistTrackEntries,
          )..where((t) => t.id.equals(track.id))).write(
            PlaylistTrackEntriesCompanion(sortIndex: Value(track.sortIndex)),
          );
        }
        await (_db.update(_db.playlistEntries)..where((t) => t.id.equals(playlistId)))
            .write(PlaylistEntriesCompanion(updatedAt: Value(now)));
        await _replaceOutbox(updated, SyncOperationType.upsert);
      });
      return Success(updated);
    } catch (e, st) {
      _logger.error('move track failed', e, st);
      return Failure(StorageException('Failed to reorder playlist', cause: e));
    }
  }

  Future<Result<void>> applyRemote(AudioPlaylist remote) async {
    try {
      final localRow = await (_db.select(
        _db.playlistEntries,
      )..where((t) => t.id.equals(remote.id))).getSingleOrNull();

      if (localRow != null && !remote.updatedAt.isAfter(localRow.updatedAt)) {
        return const Success(null);
      }

      await _db.transaction(() async {
        await _db
            .into(_db.playlistEntries)
            .insertOnConflictUpdate(_toPlaylistCompanion(remote));
        await (_db.delete(
          _db.playlistTrackEntries,
        )..where((t) => t.playlistId.equals(remote.id))).go();
        for (final track in remote.tracks) {
          final resolved = await _resolveMediaId(track);
          await _db
              .into(_db.playlistTrackEntries)
              .insert(
                _toTrackCompanion(
                  PlaylistTrack(
                    id: track.id.isEmpty ? _uuid.v4() : track.id,
                    playlistId: remote.id,
                    mediaId: resolved,
                    workId: track.workId,
                    sortIndex: track.sortIndex,
                    addedAt: track.addedAt,
                  ),
                ),
              );
        }
      });
      return const Success(null);
    } catch (e, st) {
      _logger.error('apply remote playlist failed', e, st);
      return Failure(StorageException('Failed to merge playlist', cause: e));
    }
  }

  Future<Result<void>> applyRemoteDelete(String playlistId) async {
    try {
      await _db.transaction(() async {
        await (_db.delete(
          _db.playlistTrackEntries,
        )..where((t) => t.playlistId.equals(playlistId))).go();
        await (_db.delete(
          _db.playlistEntries,
        )..where((t) => t.id.equals(playlistId))).go();
      });
      return const Success(null);
    } catch (e, st) {
      _logger.error('apply remote playlist delete failed', e, st);
      return Failure(StorageException('Failed to delete remote playlist', cause: e));
    }
  }

  Future<Result<int>> rebindLocalToUser(String authUserId) async {
    if (ProgressUserIds.isLocal(authUserId)) return const Success(0);
    try {
      var moved = 0;
      await _db.transaction(() async {
        final locals = await (_db.select(
          _db.playlistEntries,
        )..where((t) => t.userId.equals(ProgressUserIds.local))).get();
        for (final local in locals) {
          await (_db.update(
            _db.playlistEntries,
          )..where((t) => t.id.equals(local.id))).write(
            PlaylistEntriesCompanion(
              userId: Value(authUserId),
              updatedAt: Value(DateTime.now().toUtc()),
            ),
          );
          final updatedRow = await (_db.select(
            _db.playlistEntries,
          )..where((t) => t.id.equals(local.id))).getSingle();
          await _replaceOutbox(
            await _hydrate(updatedRow),
            SyncOperationType.upsert,
          );
          moved++;
        }
      });
      return Success(moved);
    } catch (e, st) {
      _logger.error('rebind playlists failed', e, st);
      return Failure(StorageException('Failed to rebind playlists', cause: e));
    }
  }

  Future<Result<void>> enqueueAllForUser(String userId) async {
    if (ProgressUserIds.isLocal(userId)) return const Success(null);
    try {
      final rows = await (_db.select(
        _db.playlistEntries,
      )..where((t) => t.userId.equals(userId))).get();
      for (final row in rows) {
        await _replaceOutbox(await _hydrate(row), SyncOperationType.upsert);
      }
      return const Success(null);
    } catch (e, st) {
      _logger.error('enqueue playlists failed', e, st);
      return Failure(StorageException('Failed to enqueue playlists', cause: e));
    }
  }

  Future<void> removeMediaEverywhere(String mediaId) async {
    final rows = await (_db.select(
      _db.playlistTrackEntries,
    )..where((t) => t.mediaId.equals(mediaId))).get();
    final playlistIds = rows.map((r) => r.playlistId).toSet();
    await (_db.delete(
      _db.playlistTrackEntries,
    )..where((t) => t.mediaId.equals(mediaId))).go();
    for (final playlistId in playlistIds) {
      final playlist = (await getById(playlistId)).valueOrNull;
      if (playlist == null) continue;
      await _replaceOutbox(playlist, SyncOperationType.upsert);
    }
  }

  Future<String> _resolveMediaId(PlaylistTrack track) async {
    if (track.mediaId.isNotEmpty) {
      final byId = await (_db.select(
        _db.mediaItems,
      )..where((t) => t.id.equals(track.mediaId))).getSingleOrNull();
      if (byId != null) return byId.id;
    }
    final byWork = await (_db.select(
      _db.mediaItems,
    )..where((t) => t.workId.equals(track.workId))).getSingleOrNull();
    return byWork?.id ?? track.mediaId;
  }

  Future<AudioPlaylist> _hydrate(PlaylistEntry row) async {
    final tracks = await (_db.select(_db.playlistTrackEntries)
          ..where((t) => t.playlistId.equals(row.id))
          ..orderBy([(t) => OrderingTerm.asc(t.sortIndex)]))
        .get();
    return AudioPlaylist(
      id: row.id,
      userId: row.userId,
      title: row.title,
      createdAt: row.createdAt.toUtc(),
      updatedAt: row.updatedAt.toUtc(),
      tracks: tracks
          .map(
            (t) => PlaylistTrack(
              id: t.id,
              playlistId: t.playlistId,
              mediaId: t.mediaId,
              workId: t.workId,
              sortIndex: t.sortIndex,
              addedAt: t.addedAt.toUtc(),
            ),
          )
          .toList(),
    );
  }

  PlaylistEntriesCompanion _toPlaylistCompanion(AudioPlaylist p) {
    return PlaylistEntriesCompanion(
      id: Value(p.id),
      userId: Value(p.userId),
      title: Value(p.title),
      createdAt: Value(p.createdAt.toUtc()),
      updatedAt: Value(p.updatedAt.toUtc()),
    );
  }

  PlaylistTrackEntriesCompanion _toTrackCompanion(PlaylistTrack t) {
    return PlaylistTrackEntriesCompanion(
      id: Value(t.id),
      playlistId: Value(t.playlistId),
      mediaId: Value(t.mediaId),
      workId: Value(t.workId),
      sortIndex: Value(t.sortIndex),
      addedAt: Value(t.addedAt.toUtc()),
    );
  }

  Future<void> _replaceOutbox(
    AudioPlaylist playlist,
    SyncOperationType operation,
  ) async {
    final now = DateTime.now().toUtc();
    await (_db.delete(_db.syncOutboxEntries)..where(
          (t) =>
              t.entityType.equals(SyncEntityType.playlist.name) &
              t.entityId.equals(playlist.id) &
              (t.status.equals(SyncOutboxStatus.pending.name) |
                  t.status.equals(SyncOutboxStatus.failed.name) |
                  t.status.equals(SyncOutboxStatus.inFlight.name)),
        ))
        .go();

    await _db
        .into(_db.syncOutboxEntries)
        .insert(
          SyncOutboxEntriesCompanion.insert(
            id: _uuid.v4(),
            entityType: SyncEntityType.playlist.name,
            entityId: playlist.id,
            operation: operation.name,
            payloadJson: jsonEncode(playlist.toJson()),
            createdAt: now,
            updatedAt: now,
            idempotencyKey: Value('playlist:${playlist.userId}:${playlist.id}'),
          ),
        );
  }
}
