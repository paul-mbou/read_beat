import 'package:read_beat/core/errors/app_exception.dart';
import 'package:read_beat/core/errors/result.dart';
import 'package:read_beat/core/config/feature_flags.dart';
import 'package:read_beat/features/library/domain/models/library_item.dart';

/// Future in-app store (free/paid audio & ebooks). Disabled unless
/// [FeatureFlags.contentStore] is on.
abstract interface class ContentStoreService {
  bool get isEnabled;

  Future<Result<List<ContentStoreListing>>> browse({String? query});

  /// Download/acquire into the local library (not implemented in MVP).
  Future<Result<LibraryItem>> acquire(String listingId);
}

final class ContentStoreListing {
  const ContentStoreListing({
    required this.id,
    required this.title,
    required this.mediaTypeLabel,
    this.author,
    this.priceLabel,
    this.isFree = true,
  });

  final String id;
  final String title;
  final String? author;
  final String mediaTypeLabel;
  final String? priceLabel;
  final bool isFree;
}

/// Stub used while the store product is off.
final class DisabledContentStoreService implements ContentStoreService {
  @override
  bool get isEnabled => FeatureFlags.contentStore;

  @override
  Future<Result<List<ContentStoreListing>>> browse({String? query}) async {
    if (!isEnabled) {
      return const Failure(
        ValidationException('Content store is not available yet'),
      );
    }
    return const Success([]);
  }

  @override
  Future<Result<LibraryItem>> acquire(String listingId) async {
    return const Failure(
      ValidationException('Content store acquisitions are not available yet'),
    );
  }
}
