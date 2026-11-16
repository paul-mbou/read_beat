import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:read_beat/core/logger/app_logger.dart';
import 'package:read_beat/features/importer/domain/audio_metadata_service.dart';
import 'package:read_beat/features/library/domain/models/library_item.dart';
import 'package:xml/xml.dart';

/// Derives a feature/cover image from imported media, or paints a brand default.
final class CoverArtService {
  CoverArtService({
    AppLogger? logger,
    Future<Directory> Function()? documentsDirectory,
    AudioMetadataService? audioMetadata,
  }) : _logger = logger ?? AppLogger(),
       _documentsDirectory =
           documentsDirectory ?? getApplicationDocumentsDirectory,
       _audioMetadata = audioMetadata ?? AudioMetadataService(logger: logger);

  final AppLogger _logger;
  final Future<Directory> Function() _documentsDirectory;
  final AudioMetadataService _audioMetadata;

  static const coverWidth = 480;
  static const coverHeight = 720;

  /// Always returns a local cover path (extracted art or generated default).
  Future<String> resolveCover({
    required String mediaId,
    required File source,
    required MediaFormat format,
    required String title,
    String? author,
    Uint8List? preferredBytes,
  }) async {
    try {
      final extracted = preferredBytes ?? await _extract(source, format);
      if (extracted != null && extracted.isNotEmpty) {
        return await writeCover(mediaId, extracted);
      }
    } catch (e, st) {
      _logger.warning('Cover extraction failed for $mediaId', e, st);
    }
    return writeCover(
      mediaId,
      _paintDefault(title: title, format: format, author: author),
    );
  }

  Future<void> deleteCover(String? coverPath) async {
    if (coverPath == null || coverPath.isEmpty) return;
    try {
      final file = File(coverPath);
      if (await file.exists()) await file.delete();
    } catch (e, st) {
      _logger.warning('Failed to delete cover $coverPath', e, st);
    }
  }

  Future<Uint8List?> _extract(File source, MediaFormat format) async {
    return switch (format) {
      MediaFormat.epub => _extractEpubCover(source),
      MediaFormat.pdf => _extractPdfCover(
        source,
      ).timeout(const Duration(seconds: 12), onTimeout: () => null),
      MediaFormat.mp3 || MediaFormat.m4a => (await _audioMetadata.readTags(
        source,
        format,
      )).coverBytes,
    };
  }

  Future<Uint8List?> _extractEpubCover(File source) async {
    final bytes = await source.readAsBytes();
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
    if (opfPath == null) return _firstImageInArchive(archive);

    final opfFile = archive.findFile(opfPath);
    if (opfFile == null || !opfFile.isFile) {
      return _firstImageInArchive(archive);
    }

    final opf = XmlDocument.parse(
      String.fromCharCodes(opfFile.content as List<int>),
    );
    final base = p.dirname(opfPath);

    String? coverHref;
    for (final meta in opf.findAllElements('meta')) {
      final name = meta.getAttribute('name')?.toLowerCase();
      if (name == 'cover') {
        final content = meta.getAttribute('content');
        if (content != null) {
          for (final item in opf.findAllElements('item')) {
            if (item.getAttribute('id') == content) {
              coverHref = item.getAttribute('href');
              break;
            }
          }
        }
      }
    }
    coverHref ??= opf
        .findAllElements('item')
        .where((item) {
          final props = item.getAttribute('properties') ?? '';
          final id = item.getAttribute('id')?.toLowerCase() ?? '';
          final href = item.getAttribute('href')?.toLowerCase() ?? '';
          return props.contains('cover-image') ||
              id.contains('cover') ||
              href.contains('cover');
        })
        .map((e) => e.getAttribute('href'))
        .whereType<String>()
        .firstOrNull;

    if (coverHref != null) {
      final path = p.normalize(p.join(base, coverHref));
      final file = archive.findFile(path) ?? archive.findFile(coverHref);
      if (file != null && file.isFile) {
        return Uint8List.fromList(file.content as List<int>);
      }
    }
    return _firstImageInArchive(archive);
  }

  Uint8List? _firstImageInArchive(Archive archive) {
    const exts = {'.jpg', '.jpeg', '.png', '.webp', '.gif'};
    for (final file in archive) {
      if (!file.isFile) continue;
      final lower = file.name.toLowerCase();
      if (exts.any(lower.endsWith)) {
        return Uint8List.fromList(file.content as List<int>);
      }
    }
    return null;
  }

  Future<Uint8List?> _extractPdfCover(File source) async {
    final doc = await PdfDocument.openFile(source.path);
    try {
      if (doc.pages.isEmpty) return null;
      final page = await doc.pages.first.ensureLoaded();
      final targetW = coverWidth.toDouble();
      final scale = targetW / page.width;
      final targetH = page.height * scale;
      final rendered = await page.render(
        fullWidth: targetW,
        fullHeight: targetH,
      );
      if (rendered == null) return null;
      try {
        final image = img.Image.fromBytes(
          width: rendered.width,
          height: rendered.height,
          bytes: rendered.pixels.buffer,
          order: img.ChannelOrder.bgra,
          numChannels: 4,
        );
        return Uint8List.fromList(img.encodeJpg(image, quality: 85));
      } finally {
        rendered.dispose();
      }
    } finally {
      await doc.dispose();
    }
  }

  Uint8List _paintDefault({
    required String title,
    required MediaFormat format,
    String? author,
  }) {
    final image = img.Image(width: coverWidth, height: coverHeight);
    final isEbook = format == MediaFormat.epub || format == MediaFormat.pdf;
    final top = isEbook ? img.ColorRgb8(4, 92, 56) : img.ColorRgb8(7, 21, 37);
    final mid = isEbook
        ? img.ColorRgb8(26, 143, 92)
        : img.ColorRgb8(18, 50, 38);
    final bot = img.ColorRgb8(255, 107, 0);

    for (var y = 0; y < coverHeight; y++) {
      final t = y / (coverHeight - 1);
      final c = t < 0.72
          ? _lerpColor(top, mid, t / 0.72)
          : _lerpColor(mid, bot, (t - 0.72) / 0.28);
      for (var x = 0; x < coverWidth; x++) {
        final nx = (x / coverWidth - 0.5).abs() * 2;
        final shade = (1 - nx * 0.18).clamp(0.75, 1.0);
        image.setPixelRgba(
          x,
          y,
          (c.r * shade).round(),
          (c.g * shade).round(),
          (c.b * shade).round(),
          255,
        );
      }
    }

    img.fillRect(
      image,
      x1: 36,
      y1: 56,
      x2: 96,
      y2: 64,
      color: img.ColorRgb8(255, 107, 0),
    );

    final letter = title.trim().isEmpty
        ? (isEbook ? 'R' : 'B')
        : String.fromCharCode(title.trim().runes.first).toUpperCase();

    final cx = coverWidth ~/ 2;
    final cy = coverHeight ~/ 2 - 40;
    img.fillCircle(
      image,
      x: cx,
      y: cy,
      radius: 92,
      color: img.ColorRgba8(255, 255, 255, 28),
    );
    img.drawCircle(
      image,
      x: cx,
      y: cy,
      radius: 92,
      color: img.ColorRgba8(255, 255, 255, 90),
    );
    img.drawString(
      image,
      letter,
      font: img.arial48,
      x: cx - 16,
      y: cy - 24,
      color: img.ColorRgba8(255, 255, 255, 230),
    );

    final label = format.name.toUpperCase();
    _drawLabel(
      image,
      label,
      coverWidth - 36 - label.length * 11,
      coverHeight - 72,
    );
    _drawLabel(image, _clip(title, 22), 36, coverHeight - 120);
    if (author != null && author.trim().isNotEmpty) {
      _drawLabel(image, _clip(author, 28), 36, coverHeight - 92, dim: true);
    }

    return Uint8List.fromList(img.encodeJpg(image, quality: 88));
  }

  void _drawLabel(
    img.Image image,
    String text,
    int x,
    int y, {
    bool dim = false,
  }) {
    img.drawString(
      image,
      text,
      font: img.arial24,
      x: x,
      y: y,
      color: dim
          ? img.ColorRgba8(255, 255, 255, 170)
          : img.ColorRgba8(255, 255, 255, 235),
    );
  }

  String _clip(String s, int max) {
    final t = s.trim();
    if (t.length <= max) return t;
    return '${t.substring(0, max - 1)}…';
  }

  img.ColorRgb8 _lerpColor(img.ColorRgb8 a, img.ColorRgb8 b, double t) {
    final x = t.clamp(0.0, 1.0);
    return img.ColorRgb8(
      (a.r + (b.r - a.r) * x).round(),
      (a.g + (b.g - a.g) * x).round(),
      (a.b + (b.b - a.b) * x).round(),
    );
  }

  Future<String> writeCover(String mediaId, Uint8List bytes) async {
    final docs = await _documentsDirectory();
    final dir = Directory(p.join(docs.path, 'covers'));
    if (!await dir.exists()) await dir.create(recursive: true);

    var out = bytes;
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded != null) {
        out = Uint8List.fromList(img.encodeJpg(decoded, quality: 88));
      }
    } catch (_) {}

    final path = p.join(dir.path, '$mediaId.jpg');
    await File(path).writeAsBytes(out, flush: true);
    return path;
  }
}
