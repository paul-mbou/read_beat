import 'dart:async';
import 'dart:convert';

import 'package:read_beat/core/config/feature_flags.dart';
import 'package:read_beat/core/errors/app_exception.dart';
import 'package:read_beat/core/errors/result.dart';
import 'package:read_beat/core/logger/app_logger.dart';
import 'package:read_beat/core/services/connectivity_service.dart';
import 'package:read_beat/features/auth/domain/repositories/auth_repository.dart';
import 'package:read_beat/features/favorites/data/datasources/appwrite_favorites_remote_data_source.dart';
import 'package:read_beat/features/favorites/data/repositories/local_favorite_repository.dart';
import 'package:read_beat/features/favorites/domain/models/favorite_record.dart';
import 'package:read_beat/features/library/data/datasources/appwrite_media_catalog_remote_data_source.dart';
import 'package:read_beat/features/library/data/repositories/local_media_catalog_repository.dart';
import 'package:read_beat/features/library/domain/models/media_catalog_entry.dart';
import 'package:read_beat/features/library/domain/repositories/library_repository.dart';
import 'package:read_beat/features/playlists/data/datasources/appwrite_playlists_remote_data_source.dart';
import 'package:read_beat/features/playlists/data/repositories/local_playlist_repository.dart';
import 'package:read_beat/features/playlists/domain/models/audio_playlist.dart';
import 'package:read_beat/features/progress/data/datasources/appwrite_progress_remote_data_source.dart';
import 'package:read_beat/features/progress/domain/models/media_progress.dart';
import 'package:read_beat/features/progress/domain/progress_user_ids.dart';
import 'package:read_beat/features/progress/domain/repositories/progress_repository.dart';
import 'package:read_beat/features/sync/domain/models/sync_outbox_item.dart';
import 'package:read_beat/features/sync/domain/repositories/sync_repository.dart';

/// SyncEngine v1+: progress, catalog, favorites, playlists (no file binaries).
final class AppSyncEngine implements SyncEngine {
  AppSyncEngine({
    required this.syncRepository,
    required this.progressRepository,
    required this.remoteProgress,
    required this.mediaCatalogRemote,
    required this.mediaCatalogLocal,
    required this.libraryRepository,
    required this.favoritesLocal,
    required this.favoritesRemote,
    required this.playlistsLocal,
    required this.playlistsRemote,
    required this.connectivity,
    required this.authRepository,
    AppLogger? logger,
  }) : _logger = logger ?? AppLogger();

  final SyncRepository syncRepository;
  final ProgressRepository progressRepository;
  final ProgressRemoteDataSource remoteProgress;
  final MediaCatalogRemoteDataSource mediaCatalogRemote;
  final LocalMediaCatalogRepository mediaCatalogLocal;
  final LibraryRepository libraryRepository;
  final LocalFavoriteRepository favoritesLocal;
  final FavoritesRemoteDataSource favoritesRemote;
  final LocalPlaylistRepository playlistsLocal;
  final PlaylistsRemoteDataSource playlistsRemote;
  final ConnectivityGateway connectivity;
  final AuthRepository authRepository;
  final AppLogger _logger;

  bool _busy = false;

  Future<Result<AuthUser>> _requireSignedIn() async {
    final current = await authRepository.currentUser();
    if (current is Failure<AuthUser?>) {
      return Failure(current.error);
    }
    final user = current.valueOrNull;
    if (user == null) {
      return const Failure(
        AuthException(
          'Sign in to sync progress across devices. '
          'Your library still works on this device without an account.',
        ),
      );
    }
    return Success(user);
  }

  @override
  Future<Result<void>> syncNow() async {
    final auth = await _requireSignedIn();
    if (auth is Failure<AuthUser>) {
      return Failure(auth.error);
    }
    final user = auth.valueOrNull!;

    final rebound = await progressRepository.rebindLocalToUser(user.id);
    if (rebound is Failure<int>) {
      _logger.warning('Progress rebind failed', rebound.error);
    }
    final favRebind = await favoritesLocal.rebindLocalToUser(user.id);
    if (favRebind is Failure<int>) {
      _logger.warning('Favorites rebind failed', favRebind.error);
    }
    final playlistRebind = await playlistsLocal.rebindLocalToUser(user.id);
    if (playlistRebind is Failure<int>) {
      _logger.warning('Playlists rebind failed', playlistRebind.error);
    }

    final items = await libraryRepository.watchAll().first;
    for (final item in items) {
      await mediaCatalogLocal.enqueueFromLibraryItem(
        item: item,
        userId: user.id,
      );
    }
    await favoritesLocal.enqueueAllForUser(user.id);
    await playlistsLocal.enqueueAllForUser(user.id);

    final pull = await pullRemoteProgress(userId: user.id);
    if (pull is Failure<void>) return pull;
    return flush();
  }

  @override
  Future<Result<void>> flush() async {
    if (_busy) {
      _logger.info('Sync flush skipped — already running');
      return const Success(null);
    }
    _busy = true;
    try {
      final auth = await _requireSignedIn();
      if (auth is Failure<AuthUser>) {
        _logger.info('Sync flush skipped — not signed in');
        return Failure(auth.error);
      }
      final user = auth.valueOrNull!;

      final online = await connectivity.isOnline;
      if (!online) {
        _logger.info('Sync flush skipped — offline');
        return const Success(null);
      }

      if (FeatureFlags.cloudFileBackup) {
        _logger.info('cloudFileBackup flag on — binary backup not wired yet');
      }

      final pending = await syncRepository.pending();
      if (pending is Failure<List<SyncOutboxItem>>) {
        return Failure(pending.error);
      }

      for (final item in pending.valueOrNull ?? const <SyncOutboxItem>[]) {
        await syncRepository.markInFlight(item.id);
        try {
          final ok = await _flushItem(item, user.id);
          if (!ok) continue;
          await syncRepository.markCompleted(item.id);
        } catch (e, st) {
          _logger.error('Sync item crashed', e, st);
          await syncRepository.markFailed(item.id, e.toString());
        }
      }
      return const Success(null);
    } finally {
      _busy = false;
    }
  }

  Future<bool> _flushItem(SyncOutboxItem item, String userId) async {
    final map = jsonDecode(item.payloadJson) as Map<String, dynamic>;
    switch (item.entityType) {
      case SyncEntityType.progress:
        var payload = MediaProgress.fromJson(map);
        if (ProgressUserIds.isLocal(payload.userId)) {
          payload = payload.copyWith(userId: userId);
        }
        final remote = await remoteProgress.upsert(payload);
        if (remote is Failure<MediaProgress>) {
          await syncRepository.markFailed(item.id, remote.error.message);
          return false;
        }
        return true;
      case SyncEntityType.mediaCatalog:
        var entry = MediaCatalogEntry.fromJson(map);
        if (ProgressUserIds.isLocal(entry.userId)) {
          entry = MediaCatalogEntry(
            id: entry.id,
            userId: userId,
            workId: entry.workId,
            title: entry.title,
            author: entry.author,
            mediaType: entry.mediaType,
            format: entry.format,
            exactHash: entry.exactHash,
            softKey: entry.softKey,
            durationSeconds: entry.durationSeconds,
            updatedAt: entry.updatedAt,
            source: entry.source,
          );
        }
        final remote = await mediaCatalogRemote.upsert(entry);
        if (remote is Failure<MediaCatalogEntry>) {
          await syncRepository.markFailed(item.id, remote.error.message);
          return false;
        }
        return true;
      case SyncEntityType.favorite:
        var record = FavoriteRecord.fromJson(map);
        if (ProgressUserIds.isLocal(record.userId)) {
          record = record.copyWith(userId: userId);
        }
        if (item.operation == SyncOperationType.delete || !record.isFavorite) {
          final deleted = await favoritesRemote.delete(record);
          if (deleted is Failure<void>) {
            await syncRepository.markFailed(item.id, deleted.error.message);
            return false;
          }
          return true;
        }
        final remote = await favoritesRemote.upsert(record);
        if (remote is Failure<FavoriteRecord>) {
          await syncRepository.markFailed(item.id, remote.error.message);
          return false;
        }
        return true;
      case SyncEntityType.playlist:
        var playlist = AudioPlaylist.fromJson(map);
        if (ProgressUserIds.isLocal(playlist.userId)) {
          playlist = playlist.copyWith(userId: userId);
        }
        if (item.operation == SyncOperationType.delete) {
          final deleted = await playlistsRemote.delete(playlist.id);
          if (deleted is Failure<void>) {
            await syncRepository.markFailed(item.id, deleted.error.message);
            return false;
          }
          return true;
        }
        final remote = await playlistsRemote.upsert(playlist);
        if (remote is Failure<AudioPlaylist>) {
          await syncRepository.markFailed(item.id, remote.error.message);
          return false;
        }
        return true;
    }
  }

  @override
  Future<Result<void>> pullRemoteProgress({required String userId}) async {
    final auth = await _requireSignedIn();
    if (auth is Failure<AuthUser>) {
      return Failure(auth.error);
    }

    final online = await connectivity.isOnline;
    if (!online) return const Success(null);

    final catalog = await mediaCatalogRemote.listForUser(userId);
    if (catalog is Success<List<MediaCatalogEntry>>) {
      await mediaCatalogLocal.cacheAll(catalog.value);
    } else if (catalog is Failure<List<MediaCatalogEntry>>) {
      _logger.warning('Catalog pull failed', catalog.error);
    }

    final favorites = await favoritesRemote.listForUser(userId);
    if (favorites is Success<List<FavoriteRecord>>) {
      for (final record in favorites.value) {
        await favoritesLocal.applyRemote(record);
      }
    } else if (favorites is Failure<List<FavoriteRecord>>) {
      _logger.warning('Favorites pull failed', favorites.error);
    }

    final playlists = await playlistsRemote.listForUser(userId);
    if (playlists is Success<List<AudioPlaylist>>) {
      for (final playlist in playlists.value) {
        await playlistsLocal.applyRemote(playlist);
      }
    } else if (playlists is Failure<List<AudioPlaylist>>) {
      _logger.warning('Playlists pull failed', playlists.error);
    }

    final remote = await remoteProgress.listForUser(userId);
    if (remote is Failure<List<MediaProgress>>) {
      return Failure(remote.error);
    }
    for (final item in remote.valueOrNull ?? const <MediaProgress>[]) {
      var toMerge = item;
      final local = await libraryRepository.findByWorkId(item.workId);
      final localItem = local.valueOrNull;
      if (localItem != null) {
        toMerge = item.copyWith(mediaId: localItem.id, workId: localItem.workId);
      }
      final merged = await progressRepository.upsertFromRemote(toMerge);
      if (merged is Failure<MediaProgress>) {
        _logger.warning('Merge remote progress failed', merged.error);
      }
    }
    return const Success(null);
  }
}
