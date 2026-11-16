import 'package:read_beat/core/errors/result.dart';
import 'package:read_beat/features/library/domain/models/library_item.dart';
import 'package:read_beat/features/progress/domain/models/media_progress.dart';

abstract interface class LibraryRepository {
  Stream<List<LibraryItem>> watchAll();

  Future<Result<LibraryItem?>> getById(String id);

  Future<Result<LibraryItem>> upsert(LibraryItem item);

  Future<Result<void>> delete(String id);

  Future<Result<LibraryItem>> setFavorite(String id, bool favorite);

  Future<Result<void>> touchOpened(String id);

  Future<Result<LibraryItem?>> findByHash(String hash);

  Future<Result<LibraryItem?>> findByWorkId(String workId);

  /// Soft-key candidates (caller filters duration for audio).
  Future<Result<List<LibraryItem>>> findBySoftKey(String softKey);

  /// Point this local file at an existing work (manual link / soft merge).
  Future<Result<LibraryItem>> linkToWork({
    required String itemId,
    required String workId,
  });
}

extension LibraryItemMediaTypeX on MediaType {
  String get storageValue => name;
}
