import 'package:flutter_test/flutter_test.dart';
import 'package:read_beat/features/library/domain/soft_fingerprint.dart';
import 'package:read_beat/features/progress/domain/models/media_progress.dart';

void main() {
  group('SoftFingerprint', () {
    test('normalize collapses case and punctuation', () {
      expect(
        SoftFingerprint.normalize('  Dena Mwana — Feat. X  '),
        'dena mwana x',
      );
    });

    test('audio key uses author|title', () {
      expect(
        SoftFingerprint.key(
          mediaType: MediaType.audio,
          title: 'Gloria',
          author: 'Dena Mwana',
        ),
        'audio:dena mwana|gloria',
      );
    });

    test('durationClose within 2 seconds', () {
      expect(SoftFingerprint.durationClose(180, 181.5), isTrue);
      expect(SoftFingerprint.durationClose(180, 183), isFalse);
      expect(SoftFingerprint.durationClose(null, 180), isFalse);
    });
  });
}
