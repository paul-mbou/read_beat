import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:read_beat/core/constants/app_constants.dart';

part 'app_database.g.dart';

class ProgressEntries extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get mediaId => text()();
  TextColumn get workId => text().withDefault(const Constant(''))();
  TextColumn get mediaType => text()();
  RealColumn get position => real()();
  RealColumn get duration => real().nullable()();
  RealColumn get percent => real().nullable()();
  TextColumn get chapterOrPage => text().nullable()();
  TextColumn get cfi => text().nullable()();
  TextColumn get title => text().nullable()();
  TextColumn get deviceId => text()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {userId, mediaId},
  ];
}

class SyncOutboxEntries extends Table {
  TextColumn get id => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get operation => text()();
  TextColumn get payloadJson => text()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  TextColumn get idempotencyKey => text().nullable()();
  DateTimeColumn get nextAttemptAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Local library catalog (ebooks + audio).
class MediaItems extends Table {
  TextColumn get id => text()();
  TextColumn get workId => text().withDefault(const Constant(''))();
  TextColumn get title => text()();
  TextColumn get author => text().nullable()();
  TextColumn get softKey => text().nullable()();
  TextColumn get mediaType => text()(); // ebook | audio
  TextColumn get format => text()(); // epub | pdf | mp3 | m4a
  TextColumn get filePath => text()();
  TextColumn get fileHash => text()();
  IntColumn get fileSizeBytes => integer()();
  TextColumn get coverPath => text().nullable()();
  RealColumn get durationSeconds => real().nullable()();
  IntColumn get pageCount => integer().nullable()();
  BoolColumn get isFavorite =>
      boolean().withDefault(const Constant(false))();
  TextColumn get cloudStatus =>
      text().withDefault(const Constant('localOnly'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get lastOpenedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {fileHash},
  ];
}

/// Favorite tombstones + live flags, independent of media lastOpenedAt.
class FavoriteEntries extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get workId => text()();
  BoolColumn get isFavorite => boolean()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {userId, workId},
  ];
}

/// Simple audio listening queues (local-first).
class PlaylistEntries extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get title => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class PlaylistTrackEntries extends Table {
  TextColumn get id => text()();
  TextColumn get playlistId => text()();
  TextColumn get mediaId => text()();
  TextColumn get workId => text()();
  IntColumn get sortIndex => integer()();
  DateTimeColumn get addedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {playlistId, mediaId},
  ];
}

/// Cached cloud catalog cards (no binaries) for orphan-resume UX.
class MediaCatalogCacheEntries extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get workId => text()();
  TextColumn get title => text()();
  TextColumn get author => text().nullable()();
  TextColumn get mediaType => text()();
  TextColumn get format => text()();
  TextColumn get exactHash => text()();
  TextColumn get softKey => text().nullable()();
  RealColumn get durationSeconds => real().nullable()();
  TextColumn get source => text().withDefault(const Constant('userLibrary'))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {userId, workId},
  ];
}

@DriftDatabase(
  tables: [
    ProgressEntries,
    SyncOutboxEntries,
    MediaItems,
    MediaCatalogCacheEntries,
    FavoriteEntries,
    PlaylistEntries,
    PlaylistTrackEntries,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(mediaItems);
      }
      if (from < 3) {
        await m.addColumn(mediaItems, mediaItems.coverPath);
      }
      if (from < 4) {
        await m.addColumn(syncOutboxEntries, syncOutboxEntries.nextAttemptAt);
      }
      if (from < 5) {
        await m.addColumn(mediaItems, mediaItems.workId);
        await m.addColumn(mediaItems, mediaItems.softKey);
        await m.addColumn(progressEntries, progressEntries.workId);
        await m.addColumn(progressEntries, progressEntries.title);
        await m.createTable(mediaCatalogCacheEntries);
        // Backfill workId = id for existing media / progress rows.
        await customStatement(
          'UPDATE media_items SET work_id = id WHERE work_id = \'\' OR work_id IS NULL',
        );
        await customStatement(
          'UPDATE progress_entries SET work_id = media_id WHERE work_id = \'\' OR work_id IS NULL',
        );
      }
      if (from < 6) {
        await m.createTable(favoriteEntries);
        await m.createTable(playlistEntries);
        await m.createTable(playlistTrackEntries);
        await customStatement('''
INSERT OR IGNORE INTO favorite_entries (id, user_id, work_id, is_favorite, updated_at)
SELECT id, 'local',
  CASE WHEN work_id IS NULL OR work_id = '' THEN id ELSE work_id END,
  1, updated_at
FROM media_items
WHERE is_favorite = 1
''');
      }
    },
  );

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: AppConstants.databaseName,
      native: const DriftNativeOptions(
        databaseDirectory: getApplicationSupportDirectory,
      ),
    );
  }
}
