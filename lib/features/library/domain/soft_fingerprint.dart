import 'package:read_beat/features/progress/domain/models/media_progress.dart';

/// Soft identity for “same work, different file encoding”.
///
/// Not a cryptographic hash — title/author (+ duration match separately for audio).
abstract final class SoftFingerprint {
  /// Key without duration (duration compared with [durationClose]).
  static String? key({
    required MediaType mediaType,
    String? title,
    String? author,
  }) {
    final t = normalize(title);
    if (t == null || t.isEmpty) return null;
    final a = normalize(author) ?? '';
    return switch (mediaType) {
      MediaType.audio => 'audio:$a|$t',
      MediaType.ebook => 'ebook:$a|$t',
    };
  }

  static bool durationClose(double? a, double? b, {double toleranceSec = 2}) {
    if (a == null || b == null) return false;
    return (a - b).abs() <= toleranceSec;
  }

  /// Lowercase, strip diacritics-ish noise, collapse whitespace, drop common junk.
  static String? normalize(String? raw) {
    if (raw == null) return null;
    var s = raw.trim().toLowerCase();
    if (s.isEmpty) return null;
    s = s
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[^\w\s\|]+', unicode: true), '')
        .trim();
    // Soften “feat.” noise for matching.
    s = s.replaceAll(RegExp(r'\bfeat\.?\b'), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s.isEmpty ? null : s;
  }
}
