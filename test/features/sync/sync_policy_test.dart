import 'package:flutter_test/flutter_test.dart';
import 'package:read_beat/features/progress/domain/models/media_progress.dart';
import 'package:read_beat/features/sync/domain/sync_policy.dart';

void main() {
  group('SyncPolicy.pickWinner', () {
    MediaProgress progress({
      required String id,
      required DateTime updatedAt,
      required String deviceId,
      double position = 10,
    }) {
      return MediaProgress(
        id: id,
        userId: 'user-1',
        mediaId: 'media-1',
        workId: 'media-1',
        mediaType: MediaType.audio,
        position: position,
        updatedAt: updatedAt,
        deviceId: deviceId,
      );
    }

    test('newer updatedAt wins', () {
      final older = progress(
        id: 'a',
        updatedAt: DateTime.utc(2026, 1, 1, 10),
        deviceId: 'device-a',
        position: 30,
      );
      final newer = progress(
        id: 'b',
        updatedAt: DateTime.utc(2026, 1, 1, 11),
        deviceId: 'device-b',
        position: 90,
      );

      expect(SyncPolicy.pickWinner(older, newer), newer);
      expect(SyncPolicy.pickWinner(newer, older), newer);
      expect(
        SyncPolicy.shouldReplace(existing: older, incoming: newer),
        isTrue,
      );
      expect(
        SyncPolicy.shouldReplace(existing: newer, incoming: older),
        isFalse,
      );
    });

    test('equal timestamps prefer greater deviceId', () {
      final ts = DateTime.utc(2026, 1, 1, 12);
      final a = progress(id: 'a', updatedAt: ts, deviceId: 'device-a');
      final b = progress(id: 'b', updatedAt: ts, deviceId: 'device-b');

      expect(SyncPolicy.pickWinner(a, b), b);
      expect(SyncPolicy.pickWinner(b, a), b);
    });
  });

  group('SyncPolicy.backoffForAttempt', () {
    test('grows exponentially and caps', () {
      expect(SyncPolicy.backoffForAttempt(0), const Duration(seconds: 2));
      expect(SyncPolicy.backoffForAttempt(1), const Duration(seconds: 4));
      expect(SyncPolicy.backoffForAttempt(2), const Duration(seconds: 8));
      expect(
        SyncPolicy.backoffForAttempt(20).inSeconds,
        lessThanOrEqualTo(300),
      );
    });
  });

  group('MediaProgress serialization', () {
    test('round-trips through JSON', () {
      final original = MediaProgress(
        id: 'p1',
        userId: 'u1',
        mediaId: 'm1',
        workId: 'm1',
        mediaType: MediaType.ebook,
        position: 42,
        duration: 100,
        percent: 0.42,
        chapterOrPage: 'ch-3',
        cfi: 'epubcfi(/6/4)',
        deviceId: 'd1',
        updatedAt: DateTime.utc(2026, 8, 12, 10, 0, 0),
      );

      final restored = MediaProgress.fromJson(original.toJson());
      expect(restored, original);
    });
  });
}
