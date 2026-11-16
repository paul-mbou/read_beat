import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:read_beat/core/database/app_database.dart';
import 'package:read_beat/core/errors/app_exception.dart';
import 'package:read_beat/core/errors/result.dart';
import 'package:read_beat/core/logger/app_logger.dart';
import 'package:read_beat/features/library/domain/models/library_item.dart';
import 'package:read_beat/features/library/domain/repositories/library_repository.dart';
import 'package:read_beat/features/progress/domain/models/media_progress.dart';
import 'package:read_beat/features/progress/domain/progress_user_ids.dart';

final class LocalLibraryRepository implements LibraryRepository {
  LocalLibraryRepository(
    this._db, {
    this._preferredProgressUserId,
    AppLogger? logger,
  }) : _logger = logger ?? AppLogger();

  final AppDatabase _db;
  final String Function()? _preferredProgressUserId;
  final AppLogger _logger;

  String get _preferredUser =>
      _preferredProgressUserId?.call() ?? ProgressUserIds.local;

  @override
  Stream<List<LibraryItem>> watchAll() {
    final mediaQuery = _db.select(_db.mediaItems)
      ..orderBy([
        (t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc),
      ]);

    // Re-emit when either media or progress changes.
    return Stream.multi((controller) {
      Future<void> emit() async {
        try {
          final rows = await mediaQuery.get();
          controller.add(await _mapRowsWithProgress(rows));
        } catch (e, st) {
          controller.addError(e, st);
        }
      }

      final mediaSub = mediaQuery.watch().listen((_) => emit());
      final progressSub = _db
          .select(_db.progressEntries)
          .watch()
          .listen((_) => emit());
      unawaited(emit());

      controller.onCancel = () async {
        await mediaSub.cancel();
        await progressSub.cancel();
      };
    });
  }

  Future<List<LibraryItem>> _mapRowsWithProgress(List<MediaItem> rows) async {
    final progressRows = await _db.select(_db.progressEntries).get();
    final preferred = _preferredUser;
    final byMedia = <String, ProgressEntry>{};
    for (final p in progressRows) {
      final prev = byMedia[p.mediaId];
      if (prev == null) {
        byMedia[p.mediaId] = p;
        continue;
      }
      byMedia[p.mediaId] = _preferProgress(prev, p, preferred);
    }

    return rows
        .map(
          (row) => _map(
            row,
            progressPercent: byMedia[row.id]?.percent,
            progressLabel: byMedia[row.id]?.chapterOrPage,
          ),
        )
        .toList();
  }

  ProgressEntry _preferProgress(
    ProgressEntry a,
    ProgressEntry b,
    String preferredUserId,
  ) {
    if (a.userId == preferredUserId && b.userId != preferredUserId) return a;
    if (b.userId == preferredUserId && a.userId != preferredUserId) return b;
    if (a.userId == ProgressUserIds.local &&
        b.userId != ProgressUserIds.local) {
      return b;
    }
    if (b.userId == ProgressUserIds.local &&
        a.userId != ProgressUserIds.local) {
      return a;
    }
    return a.updatedAt.isAfter(b.updatedAt) ? a : b;
  }

  @override
  Future<Result<LibraryItem?>> getById(String id) async {
    try {
      final row = await (_db.select(
        _db.mediaItems,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (row == null) return const Success(null);
      final progress = await (_db.select(
        _db.progressEntries,
      )..where((t) => t.mediaId.equals(id))).get();
      ProgressEntry? p;
      final preferred = _preferredUser;
      for (final entry in progress) {
        if (entry.userId == preferred) {
          p = entry;
          break;
        }
      }
      p ??= progress
          .where((e) => e.userId == ProgressUserIds.local)
          .firstOrNull;
      p ??= progress.isEmpty ? null : progress.first;
      return Success(
        _map(row, progressPercent: p?.percent, progressLabel: p?.chapterOrPage),
      );
    } catch (e, st) {
      _logger.error('getById failed', e, st);
      return Failure(StorageException('Failed to load item', cause: e));
    }
  }

  @override
  Future<Result<LibraryItem>> upsert(LibraryItem item) async {
    try {
      await _db.into(_db.mediaItems).insertOnConflictUpdate(_toCompanion(item));
      return Success(item);
    } catch (e, st) {
      _logger.error('upsert failed', e, st);
      return Failure(StorageException('Failed to save item', cause: e));
    }
  }

  @override
  Future<Result<void>> delete(String id) async {
    try {
      final existing = await getById(id);
      if (existing case Failure(:final error)) return Failure(error);
      final item = existing.valueOrNull;
      if (item == null) {
        return const Failure(StorageException('Item not found'));
      }

      await (_db.delete(_db.mediaItems)..where((t) => t.id.equals(id))).go();
      await (_db.delete(
        _db.progressEntries,
      )..where((t) => t.mediaId.equals(id))).go();
      await (_db.delete(
        _db.playlistTrackEntries,
      )..where((t) => t.mediaId.equals(id))).go();

      for (final path in [item.filePath, item.coverPath]) {
        if (path == null || path.isEmpty) continue;
        try {
          final file = File(path);
          if (await file.exists()) await file.delete();
        } catch (_) {}
      }
      return const Success(null);
    } catch (e, st) {
      _logger.error('delete failed', e, st);
      return Failure(StorageException('Failed to delete item', cause: e));
    }
  }

  @override
  Future<Result<LibraryItem>> setFavorite(String id, bool favorite) async {
    try {
      final existing = await getById(id);
      if (existing case Failure(:final error)) return Failure(error);
      final item = existing.valueOrNull;
      if (item == null) {
        return const Failure(StorageException('Item not found'));
      }
      final updated = item.copyWith(
        isFavorite: favorite,
        updatedAt: DateTime.now().toUtc(),
      );
      return await upsert(updated);
    } catch (e, st) {
      _logger.error('setFavorite failed', e, st);
      return Failure(StorageException('Failed to update favorite', cause: e));
    }
  }

  @override
  Future<Result<void>> touchOpened(String id) async {
    try {
      final now = DateTime.now().toUtc();
      await (_db.update(_db.mediaItems)..where((t) => t.id.equals(id))).write(
        MediaItemsCompanion(lastOpenedAt: Value(now), updatedAt: Value(now)),
      );
      return const Success(null);
    } catch (e, st) {
      _logger.error('touchOpened failed', e, st);
      return Failure(
        StorageException('Failed to update opened time', cause: e),
      );
    }
  }

  @override
  Future<Result<LibraryItem?>> findByHash(String hash) async {
    try {
      final row = await (_db.select(
        _db.mediaItems,
      )..where((t) => t.fileHash.equals(hash))).getSingleOrNull();
      return Success(row == null ? null : _map(row));
    } catch (e, st) {
      _logger.error('findByHash failed', e, st);
      return Failure(StorageException('Failed to look up hash', cause: e));
    }
  }

  @override
  Future<Result<LibraryItem?>> findByWorkId(String workId) async {
    try {
      final row = await (_db.select(
        _db.mediaItems,
      )..where((t) => t.workId.equals(workId))).getSingleOrNull();
      return Success(row == null ? null : _map(row));
    } catch (e, st) {
      _logger.error('findByWorkId failed', e, st);
      return Failure(StorageException('Failed to look up work', cause: e));
    }
  }

  @override
  Future<Result<List<LibraryItem>>> findBySoftKey(String softKey) async {
    try {
      final rows = await (_db.select(
        _db.mediaItems,
      )..where((t) => t.softKey.equals(softKey))).get();
      return Success(rows.map(_map).toList());
    } catch (e, st) {
      _logger.error('findBySoftKey failed', e, st);
      return Failure(StorageException('Failed to look up soft key', cause: e));
    }
  }

  @override
  Future<Result<LibraryItem>> linkToWork({
    required String itemId,
    required String workId,
  }) async {
    try {
      final existing = await getById(itemId);
      if (existing case Failure(:final error)) return Failure(error);
      final item = existing.valueOrNull;
      if (item == null) {
        return const Failure(StorageException('Item not found'));
      }
      final updated = item.copyWith(
        workId: workId,
        cloudStatus: CloudStatus.synced,
        updatedAt: DateTime.now().toUtc(),
      );
      final saved = await upsert(updated);
      if (saved case Failure(:final error)) return Failure(error);

      // Point local progress rows for this media at the linked work.
      await (_db.update(_db.progressEntries)
            ..where((t) => t.mediaId.equals(itemId)))
          .write(ProgressEntriesCompanion(workId: Value(workId)));

      return saved;
    } catch (e, st) {
      _logger.error('linkToWork failed', e, st);
      return Failure(StorageException('Failed to link work', cause: e));
    }
  }

  MediaItemsCompanion _toCompanion(LibraryItem item) {
    return MediaItemsCompanion(
      id: Value(item.id),
      workId: Value(item.workId),
      title: Value(item.title),
      author: Value(item.author),
      softKey: Value(item.softKey),
      mediaType: Value(item.mediaType.name),
      format: Value(item.format.name),
      filePath: Value(item.filePath),
      fileHash: Value(item.fileHash),
      fileSizeBytes: Value(item.fileSizeBytes),
      coverPath: Value(item.coverPath),
      durationSeconds: Value(item.durationSeconds),
      pageCount: Value(item.pageCount),
      isFavorite: Value(item.isFavorite),
      cloudStatus: Value(item.cloudStatus.name),
      createdAt: Value(item.createdAt),
      updatedAt: Value(item.updatedAt),
      lastOpenedAt: Value(item.lastOpenedAt),
    );
  }

  LibraryItem _map(
    MediaItem row, {
    double? progressPercent,
    String? progressLabel,
  }) {
    final workId = row.workId.isEmpty ? row.id : row.workId;
    return LibraryItem(
      id: row.id,
      workId: workId,
      title: row.title,
      author: row.author,
      softKey: row.softKey,
      mediaType: MediaType.values.byName(row.mediaType),
      format: MediaFormat.values.byName(row.format),
      filePath: row.filePath,
      fileHash: row.fileHash,
      fileSizeBytes: row.fileSizeBytes,
      coverPath: row.coverPath,
      durationSeconds: row.durationSeconds,
      pageCount: row.pageCount,
      isFavorite: row.isFavorite,
      cloudStatus: CloudStatus.values.byName(row.cloudStatus),
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      lastOpenedAt: row.lastOpenedAt,
      progressPercent: progressPercent,
      progressLabel: progressLabel,
    );
  }
}
