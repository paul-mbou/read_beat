import 'package:read_beat/features/library/domain/models/library_item.dart';

/// In-memory library search — title > author > format, tokenized.
abstract final class LocalSearch {
  static List<LibraryItem> query(List<LibraryItem> items, String raw) {
    final tokens = tokenize(raw);
    if (tokens.isEmpty) return List<LibraryItem>.of(items);

    final scored = <({LibraryItem item, int score})>[];
    for (final item in items) {
      final score = scoreItem(item, tokens);
      if (score > 0) scored.add((item: item, score: score));
    }
    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.item.title.toLowerCase().compareTo(b.item.title.toLowerCase());
    });
    return scored.map((e) => e.item).toList();
  }

  static List<String> tokenize(String raw) {
    return normalize(raw)
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
  }

  static String normalize(String value) {
    return value.trim().toLowerCase();
  }

  static int scoreItem(LibraryItem item, List<String> tokens) {
    if (tokens.isEmpty) return 0;
    final title = normalize(item.title);
    final author = normalize(item.author ?? '');
    final format = item.format.name.toLowerCase();
    final kind = item.mediaType.name.toLowerCase();

    var score = 0;
    for (final token in tokens) {
      var tokenScore = 0;
      if (title == token) {
        tokenScore = 20;
      } else if (title.startsWith(token)) {
        tokenScore = 14;
      } else if (title.contains(token)) {
        tokenScore = 10;
      } else if (author.isNotEmpty && author.contains(token)) {
        tokenScore = 6;
      } else if (format.contains(token) || kind.contains(token)) {
        tokenScore = 4;
      }
      if (tokenScore == 0) return 0;
      score += tokenScore;
    }
    return score;
  }
}
