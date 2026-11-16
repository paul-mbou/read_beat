import 'dart:async';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:read_beat/core/constants/app_constants.dart';
import 'package:read_beat/core/errors/app_exception.dart';
import 'package:read_beat/core/errors/result.dart';
import 'package:read_beat/core/logger/app_logger.dart';
import 'package:read_beat/core/services/device_id_service.dart';
import 'package:read_beat/features/library/domain/models/library_item.dart';
import 'package:read_beat/features/library/domain/repositories/library_repository.dart';
import 'package:read_beat/features/progress/domain/models/media_progress.dart';
import 'package:read_beat/features/progress/domain/progress_user_resolver.dart';
import 'package:read_beat/features/progress/domain/repositories/progress_repository.dart';
import 'package:uuid/uuid.dart';
import 'package:xml/xml.dart';

/// Abstract ebook reader API — PDF and EPUB implement the same progress contract.
abstract interface class EbookReaderService {
  Future<Result<EbookOpenResult>> open(LibraryItem item);

  Future<Result<void>> saveProgress({
    required LibraryItem item,
    required double position,
    required double? percent,
    String? chapterOrPage,
    bool immediate = false,
  });

  /// Writes any debounced progress immediately (call when leaving the reader).
  Future<void> flushProgress();
}

final class EbookOpenResult {
  const EbookOpenResult({
    required this.item,
    required this.kind,
    this.pdfPath,
    this.epubHtmlPath,
    this.initialPage = 0,
    this.initialScrollPercent = 0,
    this.pageCount,
  });

  final LibraryItem item;
  final MediaFormat kind;
  final String? pdfPath;
  final String? epubHtmlPath;

  /// PDF page index (0-based).
  final int initialPage;

  /// EPUB vertical scroll fraction (0–1).
  final double initialScrollPercent;
  final int? pageCount;
}

final class AppEbookReaderService implements EbookReaderService {
  AppEbookReaderService({
    required ProgressRepository progressRepository,
    required LibraryRepository libraryRepository,
    required DeviceIdService deviceIdService,
    required ProgressUserResolver progressUserResolver,
    AppLogger? logger,
    Uuid? uuid,
  }) : _progress = progressRepository,
       _library = libraryRepository,
       _deviceId = deviceIdService,
       _progressUser = progressUserResolver,
       _logger = logger ?? AppLogger(),
       _uuid = uuid ?? const Uuid();

  final ProgressRepository _progress;
  final LibraryRepository _library;
  final DeviceIdService _deviceId;
  final ProgressUserResolver _progressUser;
  final AppLogger _logger;
  final Uuid _uuid;

  Timer? _debounce;
  _PendingEbookProgress? _pending;

  @override
  Future<Result<EbookOpenResult>> open(LibraryItem item) async {
    try {
      if (!File(item.filePath).existsSync()) {
        return const Failure(StorageException('Ebook file missing on disk'));
      }
      await _library.touchOpened(item.id);

      final userId = await _progressUser.currentUserId();
      final existing = await _progress.getBestLocal(
        preferredUserId: userId,
        mediaId: item.id,
      );
      final progress = existing.valueOrNull;

      if (item.format == MediaFormat.pdf) {
        final initialPage = (progress?.position ?? 0).round().clamp(0, 999999);
        return Success(
          EbookOpenResult(
            item: item,
            kind: MediaFormat.pdf,
            pdfPath: item.filePath,
            initialPage: initialPage,
            pageCount: item.pageCount,
          ),
        );
      }

      if (item.format == MediaFormat.epub) {
        final htmlPath = await _extractEpubToHtml(item);
        return Success(
          EbookOpenResult(
            item: item,
            kind: MediaFormat.epub,
            epubHtmlPath: htmlPath,
            initialScrollPercent: _epubScrollFromProgress(progress),
          ),
        );
      }

      return const Failure(ValidationException('Unsupported ebook format'));
    } catch (e, st) {
      _logger.error('ebook open failed', e, st);
      return Failure(UnexpectedException('Could not open ebook', cause: e));
    }
  }

  /// Prefer [MediaProgress.percent]; fall back to legacy position encodings.
  static double _epubScrollFromProgress(MediaProgress? progress) {
    if (progress == null) return 0;
    final percent = progress.percent;
    if (percent != null && percent >= 0 && percent <= 1) {
      return percent;
    }
    final position = progress.position;
    if (position <= 1) return position.clamp(0.0, 1.0);
    // Legacy: scroll fraction stored as 0–100 “fake pages”.
    if (position <= 100) return (position / 100).clamp(0.0, 1.0);
    return 0;
  }

  @override
  Future<Result<void>> saveProgress({
    required LibraryItem item,
    required double position,
    required double? percent,
    String? chapterOrPage,
    bool immediate = false,
  }) async {
    _pending = _PendingEbookProgress(
      item: item,
      position: position,
      percent: percent,
      chapterOrPage: chapterOrPage,
    );
    _debounce?.cancel();
    if (immediate) {
      _debounce = null;
      await _commitPending();
      return const Success(null);
    }
    _debounce = Timer(AppConstants.ebookProgressDebounce, () {
      unawaited(_commitPending());
    });
    return const Success(null);
  }

  @override
  Future<void> flushProgress() async {
    _debounce?.cancel();
    _debounce = null;
    await _commitPending();
  }

  Future<void> _commitPending() async {
    final pending = _pending;
    if (pending == null) return;
    _pending = null;
    try {
      final deviceId = await _deviceId.getDeviceId();
      final userId = await _progressUser.currentUserId();
      final existing = await _progress.getBestLocal(
        preferredUserId: userId,
        mediaId: pending.item.id,
      );
      final id = existing.valueOrNull?.id ?? _uuid.v4();
      await _progress.saveLocal(
        MediaProgress(
          id: id,
          userId: userId,
          mediaId: pending.item.id,
          workId: pending.item.workId,
          mediaType: MediaType.ebook,
          position: pending.position,
          percent: pending.percent,
          chapterOrPage: pending.chapterOrPage,
          title: pending.item.title,
          deviceId: deviceId,
          updatedAt: DateTime.now().toUtc(),
        ),
      );
    } catch (e, st) {
      _logger.error('ebook progress save failed', e, st);
    }
  }

  /// Minimal EPUB → single HTML for WebView (fallback reader).
  Future<String> _extractEpubToHtml(LibraryItem item) async {
    final support = await getTemporaryDirectory();
    final outDir = Directory(p.join(support.path, 'epub_${item.id}'));
    if (!await outDir.exists()) {
      await outDir.create(recursive: true);
    }

    final bytes = await File(item.filePath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    String? opfPath;
    for (final file in archive) {
      if (file.isFile && file.name.endsWith('container.xml')) {
        final xml = XmlDocument.parse(
          String.fromCharCodes(file.content as List<int>),
        );
        opfPath = xml
            .findAllElements('rootfile')
            .firstOrNull
            ?.getAttribute('full-path');
        break;
      }
    }
    opfPath ??= archive
        .where((f) => f.name.endsWith('.opf'))
        .map((f) => f.name)
        .firstOrNull;

    final spineHrefs = <String>[];
    if (opfPath != null) {
      final opfFile = archive.findFile(opfPath);
      if (opfFile != null && opfFile.isFile) {
        final opf = XmlDocument.parse(
          String.fromCharCodes(opfFile.content as List<int>),
        );
        final manifest = <String, String>{};
        for (final itemEl in opf.findAllElements('item')) {
          final id = itemEl.getAttribute('id');
          final href = itemEl.getAttribute('href');
          if (id != null && href != null) manifest[id] = href;
        }
        final base = p.dirname(opfPath);
        for (final itemRef in opf.findAllElements('itemref')) {
          final idref = itemRef.getAttribute('idref');
          final href = idref == null ? null : manifest[idref];
          if (href != null) {
            spineHrefs.add(p.normalize(p.join(base, href)));
          }
        }
      }
    }

    final buffer = StringBuffer()
      ..writeln('<!DOCTYPE html><html><head><meta charset="utf-8">')
      ..writeln(
        '<meta name="viewport" content="width=device-width, initial-scale=1">',
      )
      ..writeln(
        '<style>body{font-family:Georgia,serif;padding:20px;line-height:1.6;'
        'max-width:40rem;margin:0 auto;background:#111;color:#eee;} '
        'img{max-width:100%;}</style></head><body>',
      )
      ..writeln('<h1>${_escape(item.title)}</h1>');

    final chapters = spineHrefs.isEmpty
        ? archive
              .where(
                (f) =>
                    f.isFile &&
                    (f.name.endsWith('.xhtml') ||
                        f.name.endsWith('.html') ||
                        f.name.endsWith('.htm')),
              )
              .map((f) => f.name)
              .toList()
        : spineHrefs;

    for (final href in chapters.take(40)) {
      final file = archive.findFile(href);
      if (file == null || !file.isFile) continue;
      var html = String.fromCharCodes(file.content as List<int>);
      final bodyMatch = RegExp(
        r'<body[^>]*>([\s\S]*)</body>',
        caseSensitive: false,
      ).firstMatch(html);
      if (bodyMatch != null) html = bodyMatch.group(1) ?? html;
      buffer.writeln('<section>');
      buffer.writeln(html);
      buffer.writeln('</section><hr/>');
    }

    buffer.writeln('</body></html>');
    final outFile = File(p.join(outDir.path, 'book.html'));
    await outFile.writeAsString(buffer.toString());
    return outFile.path;
  }

  String _escape(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}

final class _PendingEbookProgress {
  const _PendingEbookProgress({
    required this.item,
    required this.position,
    required this.percent,
    required this.chapterOrPage,
  });

  final LibraryItem item;
  final double position;
  final double? percent;
  final String? chapterOrPage;
}
