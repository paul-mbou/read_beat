import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:read_beat/core/database/app_database.dart';
import 'package:read_beat/core/errors/result.dart';
import 'package:read_beat/features/importer/domain/audio_metadata_service.dart';
import 'package:read_beat/features/importer/domain/cover_art_service.dart';
import 'package:read_beat/features/importer/domain/media_import_service.dart';
import 'package:read_beat/features/library/data/repositories/local_library_repository.dart';
import 'package:read_beat/features/library/domain/models/library_item.dart';
import 'package:read_beat/features/progress/domain/models/media_progress.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late LocalLibraryRepository library;
  late MediaImportService importer;
  late Directory tempDir;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    library = LocalLibraryRepository(db);
    tempDir = await Directory.systemTemp.createTemp('readbeat_import_');
    importer = MediaImportService(
      library,
      CoverArtService(documentsDirectory: () async => tempDir),
      audioMetadata: _StubAudioMetadata(),
      documentsDirectory: () async => tempDir,
    );
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('importFile copies, hashes, cover, and upserts audio', () async {
    final source = File(p.join(tempDir.path, 'Sample Track.mp3'));
    // Minimal non-ID3 payload — cover falls back to brand default.
    await source.writeAsBytes(List<int>.generate(64, (i) => i));

    final result = await importer.importFile(source);
    expect(result, isA<Success<LibraryItem>>());
    final item = result.valueOrNull!;
    expect(item.title, 'Sample Track');
    expect(item.format, MediaFormat.mp3);
    expect(item.mediaType, MediaType.audio);
    expect(File(item.filePath).existsSync(), isTrue);
    expect(item.coverPath, isNotNull);
    expect(File(item.coverPath!).existsSync(), isTrue);

    final again = await importer.importFile(source);
    expect(again.valueOrNull?.id, item.id);
  });

  test('upsert and watchAll join progress percent', () async {
    final now = DateTime.utc(2026, 8, 12);
    final item = LibraryItem(
      id: 'm1',
      workId: 'm1',
      title: 'Track',
      mediaType: MediaType.audio,
      format: MediaFormat.mp3,
      filePath: '/tmp/a.mp3',
      fileHash: 'abc',
      fileSizeBytes: 10,
      createdAt: now,
      updatedAt: now,
    );
    await library.upsert(item);

    await db
        .into(db.progressEntries)
        .insert(
          ProgressEntriesCompanion.insert(
            id: 'p1',
            userId: 'local',
            mediaId: 'm1',
            mediaType: MediaType.audio.name,
            position: 30,
            percent: const Value(0.25),
            chapterOrPage: const Value('0:30 / 2:00'),
            deviceId: 'd1',
            updatedAt: now,
            createdAt: now,
          ),
        );

    final watched = await library.watchAll().first;
    expect(watched, hasLength(1));
    expect(watched.first.progressPercent, 0.25);
    expect(watched.first.progressLabel, '0:30 / 2:00');
  });
}

class _StubAudioMetadata extends AudioMetadataService {
  @override
  Future<AudioFileMetadata> read(File source, MediaFormat format) async {
    return const AudioFileMetadata();
  }
}
