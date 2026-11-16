import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:read_beat/core/constants/app_constants.dart';
import 'package:read_beat/core/database/app_database.dart';
import 'package:read_beat/core/errors/app_exception.dart';
import 'package:read_beat/core/errors/result.dart';
import 'package:read_beat/core/services/connectivity_service.dart';
import 'package:read_beat/features/auth/domain/models/social_auth_provider.dart';
import 'package:read_beat/features/auth/domain/repositories/auth_repository.dart';
import 'package:read_beat/features/favorites/data/datasources/appwrite_favorites_remote_data_source.dart';
import 'package:read_beat/features/favorites/data/repositories/local_favorite_repository.dart';
import 'package:read_beat/features/favorites/domain/models/favorite_record.dart';
import 'package:read_beat/features/library/data/datasources/appwrite_media_catalog_remote_data_source.dart';
import 'package:read_beat/features/library/data/repositories/local_media_catalog_repository.dart';
import 'package:read_beat/features/library/domain/models/library_item.dart';
import 'package:read_beat/features/library/domain/models/media_catalog_entry.dart';
import 'package:read_beat/features/library/domain/repositories/library_repository.dart';
import 'package:read_beat/features/playlists/data/datasources/appwrite_playlists_remote_data_source.dart';
import 'package:read_beat/features/playlists/data/repositories/local_playlist_repository.dart';
import 'package:read_beat/features/playlists/domain/models/audio_playlist.dart';
import 'package:read_beat/features/progress/data/datasources/appwrite_progress_remote_data_source.dart';
import 'package:read_beat/features/progress/data/repositories/local_progress_repository.dart';
import 'package:read_beat/features/progress/domain/models/media_progress.dart';
import 'package:read_beat/features/progress/domain/progress_user_ids.dart';
import 'package:read_beat/features/sync/data/app_sync_engine.dart';
import 'package:read_beat/features/sync/data/repositories/local_sync_repository.dart';
import 'package:read_beat/features/sync/domain/models/sync_outbox_item.dart';

void main() {
  late AppDatabase db;
  late LocalProgressRepository progressRepo;
  late LocalSyncRepository syncRepo;
  late LocalMediaCatalogRepository catalogLocal;
  late LocalFavoriteRepository favoritesLocal;
  late LocalPlaylistRepository playlistsLocal;
  late _FakeRemote remote;
  late _FakeCatalogRemote catalogRemote;
  late _FakeFavoritesRemote favoritesRemote;
  late _FakePlaylistsRemote playlistsRemote;
  late _FakeLibrary library;
  late _FakeAuth auth;
  late _FakeConnectivity connectivity;
  late AppSyncEngine engine;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    progressRepo = LocalProgressRepository(db);
    syncRepo = LocalSyncRepository(db);
    catalogLocal = LocalMediaCatalogRepository(db);
    favoritesLocal = LocalFavoriteRepository(db);
    playlistsLocal = LocalPlaylistRepository(db);
    remote = _FakeRemote();
    catalogRemote = _FakeCatalogRemote();
    favoritesRemote = _FakeFavoritesRemote();
    playlistsRemote = _FakePlaylistsRemote();
    library = _FakeLibrary();
    auth = _FakeAuth(AuthUser(id: 'auth-1', email: 'a@b.c', name: 'A'));
    connectivity = _FakeConnectivity(true);
    engine = AppSyncEngine(
      syncRepository: syncRepo,
      progressRepository: progressRepo,
      remoteProgress: remote,
      mediaCatalogRemote: catalogRemote,
      mediaCatalogLocal: catalogLocal,
      libraryRepository: library,
      favoritesLocal: favoritesLocal,
      favoritesRemote: favoritesRemote,
      playlistsLocal: playlistsLocal,
      playlistsRemote: playlistsRemote,
      connectivity: connectivity,
      authRepository: auth,
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('pending respects nextAttemptAt backoff', () async {
    final now = DateTime.now().toUtc();
    await syncRepo.enqueue(
      SyncOutboxItem(
        id: 'o1',
        entityType: SyncEntityType.progress,
        entityId: 'p1',
        operation: SyncOperationType.upsert,
        payloadJson: '{}',
        status: SyncOutboxStatus.failed,
        attempts: 1,
        nextAttemptAt: now.add(const Duration(hours: 1)),
        createdAt: now,
        updatedAt: now,
      ),
    );

    final pending = await syncRepo.pending();
    expect(pending.valueOrNull, isEmpty);
  });

  test('markFailed schedules backoff and eventually dead-letters', () async {
    final now = DateTime.now().toUtc();
    await syncRepo.enqueue(
      SyncOutboxItem(
        id: 'o1',
        entityType: SyncEntityType.progress,
        entityId: 'p1',
        operation: SyncOperationType.upsert,
        payloadJson: '{}',
        createdAt: now,
        updatedAt: now,
      ),
    );

    await syncRepo.markFailed('o1', 'boom');
    var row = (await db.select(db.syncOutboxEntries).get()).single;
    expect(row.status, SyncOutboxStatus.failed.name);
    expect(row.attempts, 1);
    expect(row.nextAttemptAt, isNotNull);

    while (row.status != SyncOutboxStatus.deadLetter.name) {
      await syncRepo.markFailed('o1', 'boom');
      row = (await db.select(db.syncOutboxEntries).get()).single;
    }
    expect(row.attempts, AppConstants.syncMaxAttempts);
  });

  test('flush pushes progress and marks completed', () async {
    await progressRepo.saveLocal(
      MediaProgress(
        id: 'p1',
        userId: 'auth-1',
        mediaId: 'm1',
        workId: 'm1',
        mediaType: MediaType.audio,
        position: 12,
        deviceId: 'd1',
        updatedAt: DateTime.utc(2026, 8, 12),
      ),
    );

    final result = await engine.flush();
    expect(result.isSuccess, isTrue);
    expect(remote.upserts, hasLength(1));
    expect(remote.upserts.first.userId, 'auth-1');

    final outbox = await db.select(db.syncOutboxEntries).get();
    expect(outbox.single.status, SyncOutboxStatus.completed.name);
  });

  test('flush rewrites guest userId to auth user', () async {
    await progressRepo.saveLocal(
      MediaProgress(
        id: 'p1',
        userId: ProgressUserIds.local,
        mediaId: 'm1',
        workId: 'm1',
        mediaType: MediaType.ebook,
        position: 3,
        deviceId: 'd1',
        updatedAt: DateTime.utc(2026, 8, 12),
      ),
    );

    final result = await engine.flush();
    expect(result.isSuccess, isTrue);
    expect(remote.upserts.single.userId, 'auth-1');
  });

  test('flush skips when offline', () async {
    connectivity.online = false;
    await progressRepo.saveLocal(
      MediaProgress(
        id: 'p1',
        userId: 'auth-1',
        mediaId: 'm1',
        workId: 'm1',
        mediaType: MediaType.audio,
        position: 1,
        deviceId: 'd1',
        updatedAt: DateTime.utc(2026, 8, 12),
      ),
    );
    final result = await engine.flush();
    expect(result.isSuccess, isTrue);
    expect(remote.upserts, isEmpty);
  });

  test('syncNow rebinds, pulls, then flushes', () async {
    await progressRepo.saveLocal(
      MediaProgress(
        id: 'local-p',
        userId: ProgressUserIds.local,
        mediaId: 'm1',
        workId: 'm1',
        mediaType: MediaType.audio,
        position: 5,
        deviceId: 'd1',
        updatedAt: DateTime.utc(2026, 8, 12, 8),
      ),
    );
    remote.remoteRows = [
      MediaProgress(
        id: 'remote-p',
        userId: 'auth-1',
        mediaId: 'm2',
        workId: 'm2',
        mediaType: MediaType.ebook,
        position: 2,
        deviceId: 'tablet',
        updatedAt: DateTime.utc(2026, 8, 12, 9),
      ),
    ];

    final result = await engine.syncNow();
    expect(result.isSuccess, isTrue);

    final rebound = await progressRepo.getLocal(
      userId: 'auth-1',
      mediaId: 'm1',
    );
    expect(rebound.valueOrNull?.position, 5);

    final pulled = await progressRepo.getLocal(
      userId: 'auth-1',
      mediaId: 'm2',
    );
    expect(pulled.valueOrNull?.position, 2);
    expect(remote.upserts, isNotEmpty);
  });

  test('flush pushes favorite upsert then unfavorite delete', () async {
    final now = DateTime.utc(2026, 8, 13);
    await library.upsert(
      LibraryItem(
        id: 'm1',
        workId: 'w1',
        title: 'Track',
        mediaType: MediaType.audio,
        format: MediaFormat.mp3,
        filePath: '/tmp/a.mp3',
        fileHash: 'h',
        fileSizeBytes: 1,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await favoritesLocal.setFavorite(
      mediaId: 'm1',
      workId: 'w1',
      favorite: true,
      userId: 'auth-1',
    );
    var result = await engine.flush();
    expect(result.isSuccess, isTrue);
    expect(favoritesRemote.upserts, hasLength(1));

    await favoritesLocal.setFavorite(
      mediaId: 'm1',
      workId: 'w1',
      favorite: false,
      userId: 'auth-1',
    );
    result = await engine.flush();
    expect(result.isSuccess, isTrue);
    expect(favoritesRemote.deletes, hasLength(1));
  });

  test('flush skips favorites when offline', () async {
    connectivity.online = false;
    await favoritesLocal.setFavorite(
      mediaId: 'm1',
      workId: 'w1',
      favorite: true,
      userId: 'auth-1',
    );
    final result = await engine.flush();
    expect(result.isSuccess, isTrue);
    expect(favoritesRemote.upserts, isEmpty);
  });
}

final class _FakeRemote implements ProgressRemoteDataSource {
  final upserts = <MediaProgress>[];
  List<MediaProgress> remoteRows = const [];

  @override
  Future<Result<List<MediaProgress>>> listForUser(String userId) async =>
      Success(remoteRows);

  @override
  Future<Result<MediaProgress>> upsert(MediaProgress progress) async {
    upserts.add(progress);
    return Success(progress);
  }
}

final class _FakeCatalogRemote implements MediaCatalogRemoteDataSource {
  @override
  Future<Result<List<MediaCatalogEntry>>> listForUser(String userId) async =>
      const Success([]);

  @override
  Future<Result<MediaCatalogEntry>> upsert(MediaCatalogEntry entry) async =>
      Success(entry);
}

final class _FakeFavoritesRemote implements FavoritesRemoteDataSource {
  final upserts = <FavoriteRecord>[];
  final deletes = <FavoriteRecord>[];

  @override
  Future<Result<List<FavoriteRecord>>> listForUser(String userId) async =>
      const Success([]);

  @override
  Future<Result<FavoriteRecord>> upsert(FavoriteRecord record) async {
    upserts.add(record);
    return Success(record);
  }

  @override
  Future<Result<void>> delete(FavoriteRecord record) async {
    deletes.add(record);
    return const Success(null);
  }
}

final class _FakePlaylistsRemote implements PlaylistsRemoteDataSource {
  @override
  Future<Result<List<AudioPlaylist>>> listForUser(String userId) async =>
      const Success([]);

  @override
  Future<Result<AudioPlaylist>> upsert(AudioPlaylist playlist) async =>
      Success(playlist);

  @override
  Future<Result<void>> delete(String playlistId) async => const Success(null);
}

final class _FakeLibrary implements LibraryRepository {
  final items = <LibraryItem>[];

  @override
  Stream<List<LibraryItem>> watchAll() => Stream.value(List.of(items));

  @override
  Future<Result<LibraryItem?>> getById(String id) async =>
      Success(items.where((e) => e.id == id).firstOrNull);

  @override
  Future<Result<LibraryItem>> upsert(LibraryItem item) async {
    items.removeWhere((e) => e.id == item.id);
    items.add(item);
    return Success(item);
  }

  @override
  Future<Result<void>> delete(String id) async => const Success(null);

  @override
  Future<Result<LibraryItem>> setFavorite(String id, bool favorite) async =>
      const Failure(StorageException('n/a'));

  @override
  Future<Result<void>> touchOpened(String id) async => const Success(null);

  @override
  Future<Result<LibraryItem?>> findByHash(String hash) async =>
      const Success(null);

  @override
  Future<Result<LibraryItem?>> findByWorkId(String workId) async =>
      const Success(null);

  @override
  Future<Result<List<LibraryItem>>> findBySoftKey(String softKey) async =>
      const Success([]);

  @override
  Future<Result<LibraryItem>> linkToWork({
    required String itemId,
    required String workId,
  }) async => const Failure(StorageException('n/a'));
}

final class _FakeAuth implements AuthRepository {
  _FakeAuth(this.user);

  AuthUser? user;

  @override
  Future<Result<AuthUser?>> currentUser() async => Success(user);

  @override
  Stream<AuthUser?> watchSession() => Stream.value(user);

  @override
  Future<Result<AuthUser>> signInWithProvider(
    SocialAuthProvider provider,
  ) async => Failure(AuthException('n/a'));

  @override
  Future<Result<void>> signOut() async => const Success(null);

  @override
  Future<Result<void>> deleteAccount() async => const Success(null);
}

final class _FakeConnectivity implements ConnectivityGateway {
  _FakeConnectivity(this.online);

  bool online;

  @override
  Future<bool> get isOnline async => online;

  @override
  Stream<bool> get onConnectivityChanged => const Stream.empty();
}
