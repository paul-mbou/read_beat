import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:read_beat/core/errors/app_exception.dart';
import 'package:read_beat/core/errors/result.dart';
import 'package:read_beat/core/logger/app_logger.dart';
import 'package:read_beat/features/importer/domain/audio_metadata_service.dart';
import 'package:read_beat/features/importer/domain/cover_art_service.dart';
import 'package:read_beat/features/library/domain/models/library_item.dart';
import 'package:read_beat/features/library/domain/repositories/library_repository.dart';
import 'package:read_beat/features/library/domain/soft_fingerprint.dart';
import 'package:read_beat/features/progress/domain/models/media_progress.dart';
import 'package:uuid/uuid.dart';

/// Picks, validates, copies, hashes, and registers local media files.
final class MediaImportService {
  MediaImportService(
    this._library,
    this._covers, {
    AudioMetadataService? audioMetadata,
    AppLogger? logger,
    Uuid? uuid,
    Future<Directory> Function()? documentsDirectory,
  }) : _audioMetadata = audioMetadata ?? AudioMetadataService(logger: logger),
       _logger = logger ?? AppLogger(),
       _uuid = uuid ?? const Uuid(),
       _documentsDirectory =
           documentsDirectory ?? getApplicationDocumentsDirectory;

  final LibraryRepository _library;
  final CoverArtService _covers;
  final AudioMetadataService _audioMetadata;
  final AppLogger _logger;
  final Uuid _uuid;
  final Future<Directory> Function() _documentsDirectory;

  static const allowedExtensions = ['epub', 'pdf', 'mp3', 'm4a'];

  static const _mediaTypeGroup = XTypeGroup(
    label: 'ebooks & audio',
    extensions: allowedExtensions,
    mimeTypes: [
      'application/epub+zip',
      'application/pdf',
      'audio/mpeg',
      'audio/mp4',
      'audio/x-m4a',
      'audio/m4a',
    ],
    uniformTypeIdentifiers: [
      'org.idpf.epub-container',
      'com.adobe.pdf',
      'public.mp3',
      'public.mpeg-4-audio',
    ],
  );

  Future<Result<List<LibraryItem>>> importFromPicker({
    void Function(int index, int total, String fileName)? onProgress,
  }) async {
    try {
      final files = await openFiles(
        acceptedTypeGroups: const [_mediaTypeGroup],
        confirmButtonText: 'Import',
      );
      if (files.isEmpty) {
        return const Success([]);
      }

      return await importPaths(
        files
            .where((f) => f.path.isNotEmpty)
            .map((f) => (path: f.path, name: f.name))
            .toList(),
        onProgress: onProgress,
      );
    } catch (e, st) {
      _logger.error('importFromPicker failed', e, st);
      return Failure(StorageException('Could not import files', cause: e));
    }
  }

  /// Imports files that were opened/shared into the app from outside.
  Future<Result<List<LibraryItem>>> importPaths(
    List<({String path, String name})> sources, {
    void Function(int index, int total, String fileName)? onProgress,
  }) async {
    try {
      if (sources.isEmpty) return const Success([]);

      final imported = <LibraryItem>[];
      final total = sources.length;
      for (var i = 0; i < sources.length; i++) {
        final source = sources[i];
        onProgress?.call(i + 1, total, source.name);
        final one = await importFile(File(source.path));
        if (one case Success(:final value)) {
          imported.add(value);
        } else if (one case Failure(:final error)) {
          _logger.warning('Import failed for ${source.name}', error);
        }
      }
      return Success(imported);
    } catch (e, st) {
      _logger.error('importPaths failed', e, st);
      return Failure(StorageException('Could not import files', cause: e));
    }
  }

  Future<Result<LibraryItem>> importFile(File source) async {
    try {
      if (!await source.exists()) {
        return const Failure(ValidationException('File does not exist'));
      }

      final ext = p.extension(source.path).toLowerCase().replaceFirst('.', '');
      final format = _formatFor(ext);
      if (format == null) {
        return Failure(
          ValidationException(
            'Unsupported format .$ext — use EPUB, PDF, MP3, or M4A',
          ),
        );
      }

      final hash = await _sha256(source);
      final existing = await _library.findByHash(hash);
      if (existing case Failure(:final error)) return Failure(error);
      final prior = existing.valueOrNull;
      if (prior != null) {
        return await _enrichExisting(prior, File(prior.filePath), format);
      }

      final docs = await _documentsDirectory();
      final mediaDir = Directory(p.join(docs.path, 'media'));
      if (!await mediaDir.exists()) {
        await mediaDir.create(recursive: true);
      }

      final id = _uuid.v4();
      final destName = '$id.$ext';
      final dest = File(p.join(mediaDir.path, destName));
      await source.copy(dest.path);

      final fallbackTitle = p.basenameWithoutExtension(source.path);
      final isAudio = format == MediaFormat.mp3 || format == MediaFormat.m4a;
      final mediaType = format == MediaFormat.epub || format == MediaFormat.pdf
          ? MediaType.ebook
          : MediaType.audio;

      AudioFileMetadata? audioMeta;
      if (isAudio) {
        audioMeta = await _audioMetadata.read(dest, format);
      }

      final title = (audioMeta?.title?.trim().isNotEmpty ?? false)
          ? audioMeta!.title!.trim()
          : fallbackTitle;
      final author = audioMeta?.artist;
      final durationSeconds = audioMeta?.durationSeconds;
      final softKey = SoftFingerprint.key(
        mediaType: mediaType,
        title: title,
        author: author,
      );

      final workId = await _resolveWorkId(
        mediaType: mediaType,
        softKey: softKey,
        durationSeconds: durationSeconds,
      );

      final coverPath = await _covers.resolveCover(
        mediaId: id,
        source: dest,
        format: format,
        title: title,
        author: author,
        preferredBytes: audioMeta?.coverBytes,
      );

      final now = DateTime.now().toUtc();
      final item = LibraryItem(
        id: id,
        workId: workId,
        title: title,
        author: author,
        softKey: softKey,
        mediaType: mediaType,
        format: format,
        filePath: dest.path,
        fileHash: hash,
        fileSizeBytes: await dest.length(),
        coverPath: coverPath,
        durationSeconds: durationSeconds,
        createdAt: now,
        updatedAt: now,
      );

      return await _library.upsert(item);
    } catch (e, st) {
      _logger.error('importFile failed', e, st);
      return Failure(StorageException('Import failed', cause: e));
    }
  }

  /// Fills missing cover / tags / duration on a duplicate import.
  Future<Result<LibraryItem>> _enrichExisting(
    LibraryItem prior,
    File source,
    MediaFormat format,
  ) async {
    final isAudio = format == MediaFormat.mp3 || format == MediaFormat.m4a;
    var updated = prior;
    var dirty = false;

    AudioFileMetadata? audioMeta;
    if (isAudio) {
      audioMeta = await _audioMetadata.read(source, format);
    }

    final needsCover =
        prior.coverPath == null || !File(prior.coverPath!).existsSync();
    if (needsCover) {
      final title = (audioMeta?.title?.trim().isNotEmpty ?? false)
          ? audioMeta!.title!.trim()
          : prior.title;
      final coverPath = await _covers.resolveCover(
        mediaId: prior.id,
        source: source,
        format: format,
        title: title,
        author: audioMeta?.artist ?? prior.author,
        preferredBytes: audioMeta?.coverBytes,
      );
      updated = updated.copyWith(
        coverPath: coverPath,
        title: title,
        author: audioMeta?.artist ?? prior.author,
      );
      dirty = true;
    } else if (isAudio && audioMeta != null) {
      final title = audioMeta.title?.trim();
      final artist = audioMeta.artist?.trim();
      if (title != null &&
          title.isNotEmpty &&
          _looksLikeFilenameTitle(prior.title, source.path)) {
        updated = updated.copyWith(title: title);
        dirty = true;
      }
      if ((prior.author == null || prior.author!.trim().isEmpty) &&
          artist != null &&
          artist.isNotEmpty) {
        updated = updated.copyWith(author: artist);
        dirty = true;
      }
    }

    if (isAudio &&
        (prior.durationSeconds == null || prior.durationSeconds! <= 0) &&
        audioMeta?.durationSeconds != null) {
      updated = updated.copyWith(durationSeconds: audioMeta!.durationSeconds);
      dirty = true;
    }

    if (!dirty) return Success(prior);
    return _library.upsert(updated.copyWith(updatedAt: DateTime.now().toUtc()));
  }

  /// exactHash already handled; soft match only when unique + strong.
  Future<String> _resolveWorkId({
    required MediaType mediaType,
    required String? softKey,
    required double? durationSeconds,
  }) async {
    if (softKey == null) return _uuid.v4();
    final found = await _library.findBySoftKey(softKey);
    final candidates = found.valueOrNull ?? const <LibraryItem>[];
    if (candidates.isEmpty) return _uuid.v4();

    final strong = <LibraryItem>[];
    for (final c in candidates) {
      if (mediaType == MediaType.audio) {
        if (SoftFingerprint.durationClose(
          c.durationSeconds,
          durationSeconds,
        )) {
          strong.add(c);
        }
      } else {
        strong.add(c);
      }
    }
    // Auto-link only when exactly one strong candidate.
    if (strong.length == 1) return strong.first.workId;
    return _uuid.v4();
  }

  bool _looksLikeFilenameTitle(String title, String path) {
    final base = p.basenameWithoutExtension(path);
    return title.trim().toLowerCase() == base.trim().toLowerCase();
  }

  MediaFormat? _formatFor(String ext) => switch (ext) {
    'epub' => MediaFormat.epub,
    'pdf' => MediaFormat.pdf,
    'mp3' => MediaFormat.mp3,
    'm4a' => MediaFormat.m4a,
    _ => null,
  };

  Future<String> _sha256(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }
}
