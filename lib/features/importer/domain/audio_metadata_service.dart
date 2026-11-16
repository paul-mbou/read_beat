import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:just_audio/just_audio.dart';
import 'package:read_beat/core/logger/app_logger.dart';
import 'package:read_beat/features/library/domain/models/library_item.dart';

/// Parsed tags + artwork from an audio file.
final class AudioFileMetadata {
  const AudioFileMetadata({
    this.title,
    this.artist,
    this.album,
    this.coverBytes,
    this.durationSeconds,
  });

  final String? title;
  final String? artist;
  final String? album;
  final Uint8List? coverBytes;
  final double? durationSeconds;

  bool get hasTextTags =>
      (title != null && title!.trim().isNotEmpty) ||
      (artist != null && artist!.trim().isNotEmpty) ||
      (album != null && album!.trim().isNotEmpty);
}

/// Reads ID3 (MP3) / iTunes-style (M4A) tags and probes duration.
class AudioMetadataService {
  AudioMetadataService({AppLogger? logger}) : _logger = logger ?? AppLogger();

  final AppLogger _logger;

  /// Tags + cover only (no duration probe).
  Future<AudioFileMetadata> readTags(File source, MediaFormat format) async {
    try {
      return switch (format) {
        MediaFormat.mp3 => await _readMp3(source),
        MediaFormat.m4a => await _readM4a(source),
        _ => const AudioFileMetadata(),
      };
    } catch (e, st) {
      _logger.warning('Audio tag read failed', e, st);
      return const AudioFileMetadata();
    }
  }

  /// Tags, cover, and duration.
  Future<AudioFileMetadata> read(File source, MediaFormat format) async {
    final tags = await readTags(source, format);
    final duration = await probeDuration(source);
    return AudioFileMetadata(
      title: tags.title,
      artist: tags.artist,
      album: tags.album,
      coverBytes: tags.coverBytes,
      durationSeconds: duration,
    );
  }

  Future<double?> probeDuration(File source) async {
    final player = AudioPlayer();
    try {
      final duration = await player
          .setFilePath(source.path)
          .timeout(const Duration(seconds: 8));
      if (duration == null) return null;
      return duration.inMilliseconds / 1000.0;
    } catch (e, st) {
      _logger.warning('Audio duration probe failed', e, st);
      return null;
    } finally {
      try {
        await player.dispose();
      } catch (_) {
        // Plugin may be unavailable in unit tests / headless hosts.
      }
    }
  }

  Future<AudioFileMetadata> _readMp3(File source) async {
    final bytes = await source.readAsBytes();
    if (bytes.length < 10) return const AudioFileMetadata();
    if (bytes[0] != 0x49 || bytes[1] != 0x44 || bytes[2] != 0x33) {
      return const AudioFileMetadata();
    }

    final ver = bytes[3];
    final flags = bytes[5];
    final tagSize = _synchsafe(bytes, 6);
    var offset = 10;
    if (flags & 0x40 != 0) {
      if (offset + 4 > bytes.length) return const AudioFileMetadata();
      if (ver == 4) {
        offset += _synchsafe(bytes, offset);
      } else {
        final extSize = _u32(bytes, offset);
        offset += 4 + extSize;
      }
    }

    String? title;
    String? artist;
    String? album;
    Uint8List? cover;

    final end = math.min(bytes.length, 10 + tagSize);
    while (offset + 10 <= end) {
      final id = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      if (id == '\u0000\u0000\u0000\u0000' || id.trim().isEmpty) break;
      final frameSize = ver == 4
          ? _synchsafe(bytes, offset + 4)
          : _u32(bytes, offset + 4);
      if (frameSize <= 0) break;
      final frameStart = offset + 10;
      final frameEnd = frameStart + frameSize;
      if (frameEnd > bytes.length) break;
      final body = bytes.sublist(frameStart, frameEnd);

      switch (id) {
        case 'TIT2':
          title ??= _decodeId3Text(body);
        case 'TPE1':
          artist ??= _decodeId3Text(body);
        case 'TALB':
          album ??= _decodeId3Text(body);
        case 'APIC':
          cover ??= _parseApic(body);
      }
      offset = frameEnd;
    }

    return AudioFileMetadata(
      title: _clean(title),
      artist: _clean(artist),
      album: _clean(album),
      coverBytes: cover,
    );
  }

  Future<AudioFileMetadata> _readM4a(File source) async {
    final bytes = await source.readAsBytes();
    String? title;
    String? artist;
    String? album;
    Uint8List? cover;

    void walk(int start, int end) {
      var offset = start;
      while (offset + 8 <= end) {
        final size = _u32(bytes, offset);
        if (size < 8 || offset + size > end) break;
        final type = ascii.decode(
          bytes.sublist(offset + 4, offset + 8),
          allowInvalid: true,
        );
        final contentStart = offset + 8;
        final contentEnd = offset + size;

        if (type == 'moov' ||
            type == 'udta' ||
            type == 'meta' ||
            type == 'ilst' ||
            type == 'trak' ||
            type == 'mdia' ||
            type == 'minf' ||
            type == 'stbl') {
          var nested = contentStart;
          // `meta` has a 4-byte version/flags preamble.
          if (type == 'meta' && nested + 4 <= contentEnd) nested += 4;
          walk(nested, contentEnd);
        } else if (type == '©nam' ||
            type == '©ART' ||
            type == 'aART' ||
            type == '©alb' ||
            type == 'covr') {
          final data = _m4aDataPayload(bytes, contentStart, contentEnd);
          if (data != null) {
            switch (type) {
              case '©nam':
                title ??= _decodeM4aText(data);
              case '©ART':
              case 'aART':
                artist ??= _decodeM4aText(data);
              case '©alb':
                album ??= _decodeM4aText(data);
              case 'covr':
                cover ??= data;
            }
          }
        }
        offset = contentEnd;
      }
    }

    walk(0, bytes.length);

    return AudioFileMetadata(
      title: _clean(title),
      artist: _clean(artist),
      album: _clean(album),
      coverBytes: cover,
    );
  }

  /// Returns the payload of the first `data` child box.
  Uint8List? _m4aDataPayload(Uint8List bytes, int start, int end) {
    var offset = start;
    while (offset + 8 <= end) {
      final size = _u32(bytes, offset);
      if (size < 8 || offset + size > end) break;
      final type = ascii.decode(
        bytes.sublist(offset + 4, offset + 8),
        allowInvalid: true,
      );
      if (type == 'data' && size > 16) {
        return Uint8List.fromList(bytes.sublist(offset + 16, offset + size));
      }
      // Some writers put type then nested data.
      if (size > 8) {
        final nested = _m4aDataPayload(bytes, offset + 8, offset + size);
        if (nested != null) return nested;
      }
      offset += size;
    }
    return null;
  }

  String? _decodeId3Text(Uint8List body) {
    if (body.isEmpty) return null;
    final encoding = body[0];
    final data = body.sublist(1);
    try {
      switch (encoding) {
        case 0: // ISO-8859-1
          return latin1.decode(data).split('\u0000').first.trim();
        case 1: // UTF-16 with BOM
        case 2: // UTF-16BE
          return _decodeUtf16(
            data,
            bigEndian: encoding == 2,
          ).split('\u0000').first.trim();
        case 3: // UTF-8
          return utf8
              .decode(data, allowMalformed: true)
              .split('\u0000')
              .first
              .trim();
        default:
          return utf8
              .decode(data, allowMalformed: true)
              .split('\u0000')
              .first
              .trim();
      }
    } catch (_) {
      return null;
    }
  }

  String _decodeUtf16(Uint8List data, {required bool bigEndian}) {
    var offset = 0;
    var be = bigEndian;
    if (data.length >= 2) {
      if (data[0] == 0xFF && data[1] == 0xFE) {
        be = false;
        offset = 2;
      } else if (data[0] == 0xFE && data[1] == 0xFF) {
        be = true;
        offset = 2;
      }
    }
    final codeUnits = <int>[];
    for (var i = offset; i + 1 < data.length; i += 2) {
      final unit = be
          ? (data[i] << 8) | data[i + 1]
          : (data[i + 1] << 8) | data[i];
      if (unit == 0) break;
      codeUnits.add(unit);
    }
    return String.fromCharCodes(codeUnits);
  }

  String? _decodeM4aText(Uint8List data) {
    try {
      final text = utf8.decode(data, allowMalformed: true).trim();
      if (text.isNotEmpty) return text;
    } catch (_) {}
    try {
      return latin1.decode(data).trim();
    } catch (_) {
      return null;
    }
  }

  Uint8List? _parseApic(Uint8List data) {
    if (data.isEmpty) return null;
    var i = 1; // skip text encoding
    while (i < data.length && data[i] != 0) {
      i++;
    }
    i++; // skip MIME null
    if (i >= data.length) return null;
    i++; // picture type
    final encoding = data[0];
    if (encoding == 1 || encoding == 2) {
      while (i + 1 < data.length && !(data[i] == 0 && data[i + 1] == 0)) {
        i += 2;
      }
      i += 2;
    } else {
      while (i < data.length && data[i] != 0) {
        i++;
      }
      i++;
    }
    if (i >= data.length) return null;
    return Uint8List.fromList(data.sublist(i));
  }

  String? _clean(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return trimmed;
  }

  int _synchsafe(Uint8List b, int i) =>
      ((b[i] & 0x7f) << 21) |
      ((b[i + 1] & 0x7f) << 14) |
      ((b[i + 2] & 0x7f) << 7) |
      (b[i + 3] & 0x7f);

  int _u32(Uint8List b, int i) =>
      (b[i] << 24) | (b[i + 1] << 16) | (b[i + 2] << 8) | b[i + 3];
}
