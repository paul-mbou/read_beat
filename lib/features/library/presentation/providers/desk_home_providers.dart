import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:read_beat/app/di.dart';
import 'package:read_beat/core/errors/result.dart';
import 'package:read_beat/core/extensions/extensions.dart';
import 'package:read_beat/core/services/secure_storage_service.dart';
import 'package:read_beat/features/audio_player/data/app_audio_player_service.dart';
import 'package:read_beat/features/auth/presentation/controllers/auth_controller.dart';
import 'package:read_beat/features/ebook_reader/domain/ebook_reader_service.dart';
import 'package:read_beat/features/importer/domain/audio_metadata_service.dart';
import 'package:read_beat/features/importer/domain/cover_art_service.dart';
import 'package:read_beat/features/importer/domain/media_import_service.dart';
import 'package:read_beat/features/library/data/repositories/local_library_repository.dart';
import 'package:read_beat/features/library/domain/models/library_item.dart';
import 'package:read_beat/features/library/domain/models/media_catalog_entry.dart';
import 'package:read_beat/features/library/domain/models/shelf_item.dart';
import 'package:read_beat/features/library/domain/repositories/library_repository.dart';
import 'package:read_beat/features/library/domain/soft_fingerprint.dart';
import 'package:read_beat/features/playlists/domain/models/audio_playlist.dart';
import 'package:read_beat/features/progress/domain/progress_user_ids.dart';
import 'package:read_beat/features/search/domain/local_search.dart';
import 'package:read_beat/features/settings/domain/library_storage_stats.dart';

final libraryRepositoryProvider = Provider<LibraryRepository>(
  (ref) => LocalLibraryRepository(
    ref.watch(appDatabaseProvider),
    preferredProgressUserId: () =>
        ref.read(currentAuthUserProvider)?.id ?? ProgressUserIds.local,
    logger: ref.watch(appLoggerProvider),
  ),
);

final mediaImportServiceProvider = Provider<MediaImportService>((ref) {
  final logger = ref.watch(appLoggerProvider);
  final audioMeta = AudioMetadataService(logger: logger);
  return MediaImportService(
    ref.watch(libraryRepositoryProvider),
    CoverArtService(logger: logger, audioMetadata: audioMeta),
    audioMetadata: audioMeta,
    logger: logger,
  );
});

final audioPlayerServiceProvider = Provider<AppAudioPlayerService>((ref) {
  final service = AppAudioPlayerService(
    progressRepository: ref.watch(progressRepositoryProvider),
    libraryRepository: ref.watch(libraryRepositoryProvider),
    deviceIdService: ref.watch(deviceIdServiceProvider),
    progressUserResolver: ref.watch(progressUserResolverProvider),
    logger: ref.watch(appLoggerProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

final ebookReaderServiceProvider = Provider<EbookReaderService>(
  (ref) => AppEbookReaderService(
    progressRepository: ref.watch(progressRepositoryProvider),
    libraryRepository: ref.watch(libraryRepositoryProvider),
    deviceIdService: ref.watch(deviceIdServiceProvider),
    progressUserResolver: ref.watch(progressUserResolverProvider),
    logger: ref.watch(appLoggerProvider),
  ),
);

final libraryItemsProvider = StreamProvider<List<LibraryItem>>((ref) {
  return ref.watch(libraryRepositoryProvider).watchAll();
});

enum ShelfFilter { all, reading, listening, favorites }

enum LibraryLayout { list, grid }

final libraryLayoutProvider =
    NotifierProvider<LibraryLayoutController, LibraryLayout>(
      LibraryLayoutController.new,
    );

final class LibraryLayoutController extends Notifier<LibraryLayout> {
  @override
  LibraryLayout build() {
    Future<void>.microtask(_hydrate);
    return LibraryLayout.list;
  }

  Future<void> _hydrate() async {
    final raw = await ref
        .read(secureStorageProvider)
        .read(SecureStorageService.libraryLayoutKey);
    if (raw == null || !ref.mounted) return;
    final layout = LibraryLayout.values.where((e) => e.name == raw).firstOrNull;
    if (layout != null) state = layout;
  }

  Future<void> setLayout(LibraryLayout layout) async {
    state = layout;
    await ref
        .read(secureStorageProvider)
        .write(SecureStorageService.libraryLayoutKey, layout.name);
  }
}

final shelfFilterProvider = NotifierProvider<ShelfFilterNotifier, ShelfFilter>(
  ShelfFilterNotifier.new,
);

final class ShelfFilterNotifier extends Notifier<ShelfFilter> {
  @override
  ShelfFilter build() => ShelfFilter.all;

  void setFilter(ShelfFilter filter) => state = filter;
}

final filteredLibraryProvider = Provider<List<LibraryItem>>((ref) {
  final items =
      ref.watch(libraryItemsProvider).asData?.value ?? const <LibraryItem>[];
  final filter = ref.watch(shelfFilterProvider);
  return switch (filter) {
    ShelfFilter.all => items,
    ShelfFilter.reading => items.where((e) => e.isEbook).toList(),
    ShelfFilter.listening => items.where((e) => e.isAudio).toList(),
    ShelfFilter.favorites => items.where((e) => e.isFavorite).toList(),
  };
});

final librarySearchQueryProvider = NotifierProvider<LibrarySearchQuery, String>(
  LibrarySearchQuery.new,
);

final class LibrarySearchQuery extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String value) => state = value;
}

final searchedLibraryProvider = Provider<List<LibraryItem>>((ref) {
  final items = ref.watch(filteredLibraryProvider);
  return LocalSearch.query(items, ref.watch(librarySearchQueryProvider));
});

final audioLibraryProvider = Provider<List<LibraryItem>>((ref) {
  return (ref.watch(libraryItemsProvider).asData?.value ??
          const <LibraryItem>[])
      .where((e) => e.isAudio)
      .toList();
});

final playlistsProvider = StreamProvider<List<AudioPlaylist>>((ref) {
  final userId =
      ref.watch(currentAuthUserProvider)?.id ?? ProgressUserIds.local;
  return ref.watch(playlistRepositoryProvider).watchAll(userId);
});

final storageStatsProvider = Provider<LibraryStorageStats>((ref) {
  return LibraryStorageStats.from(
    items:
        ref.watch(libraryItemsProvider).asData?.value ?? const <LibraryItem>[],
    playlists:
        ref.watch(playlistsProvider).asData?.value ?? const <AudioPlaylist>[],
  );
});

/// Maps library + progress into Desk Shelf continue tiles.
final continueItemProvider = Provider<ShelfItem?>((ref) {
  final items =
      ref.watch(libraryItemsProvider).asData?.value ?? const <LibraryItem>[];
  if (items.isEmpty) return null;
  LibraryItem? best;
  for (final item in items) {
    final p = item.progressPercent ?? 0;
    if (p <= 0) continue;
    if (best == null ||
        (item.lastOpenedAt ?? item.updatedAt).isAfter(
          best.lastOpenedAt ?? best.updatedAt,
        )) {
      best = item;
    }
  }
  best ??= items.first;
  return best.toShelfItem();
});

final alsoInProgressProvider = Provider<List<ShelfItem>>((ref) {
  final items =
      ref.watch(libraryItemsProvider).asData?.value ?? const <LibraryItem>[];
  final current = ref.watch(continueItemProvider);
  return items
      .where(
        (e) =>
            e.id != current?.id &&
            (e.progressPercent ?? 0) > 0 &&
            (e.progressPercent ?? 0) < 1,
      )
      .map((e) => e.toShelfItem())
      .toList();
});

/// Home Your shelf: three most recently opened titles.
final recentShelfProvider = Provider<List<ShelfItem>>((ref) {
  final items = [
    ...ref.watch(libraryItemsProvider).asData?.value ?? const <LibraryItem>[],
  ]..sort((a, b) {
    final aAt = a.lastOpenedAt ?? a.updatedAt;
    final bAt = b.lastOpenedAt ?? b.updatedAt;
    return bAt.compareTo(aAt);
  });
  return items.take(3).map((e) => e.toShelfItem()).toList();
});

final activeAudioItemProvider = StreamProvider<LibraryItem?>((ref) {
  return ref.watch(audioPlayerServiceProvider).currentItemStream;
});

/// Mini-player / home padding — watches the player stream and current item.
final activeAudioProvider = Provider<ShelfItem?>((ref) {
  ref.watch(activeAudioItemProvider);
  return ref.watch(audioPlayerServiceProvider).currentItem?.toShelfItem();
});

/// Cloud catalog cards with no matching local file (need import or link).
final orphanResumesProvider = FutureProvider<List<MediaCatalogEntry>>((
  ref,
) async {
  final user = ref.watch(currentAuthUserProvider);
  if (user == null) return const [];
  final cached = await ref
      .read(mediaCatalogLocalProvider)
      .listCached(userId: user.id);
  final entries = cached.valueOrNull ?? const <MediaCatalogEntry>[];
  final local =
      ref.watch(libraryItemsProvider).asData?.value ?? const <LibraryItem>[];
  final workIds = local.map((e) => e.workId).toSet();
  return entries.where((e) => !workIds.contains(e.workId)).toList();
});

/// Soft-match orphans that might belong to [item] (for link UI).
final linkCandidatesProvider = Provider.family<List<MediaCatalogEntry>, String>(
  (ref, itemId) {
    final items =
        ref.watch(libraryItemsProvider).asData?.value ?? const <LibraryItem>[];
    final item = items.where((e) => e.id == itemId).firstOrNull;
    final orphans =
        ref.watch(orphanResumesProvider).asData?.value ??
        const <MediaCatalogEntry>[];
    if (item == null) return const [];
    return orphans.where((o) {
      if (o.exactHash == item.fileHash) return true;
      if (item.softKey != null && o.softKey == item.softKey) {
        if (item.isAudio) {
          return SoftFingerprint.durationClose(
            item.durationSeconds,
            o.durationSeconds,
          );
        }
        return true;
      }
      return false;
    }).toList();
  },
);

extension LibraryItemShelfX on LibraryItem {
  ShelfItem toShelfItem() {
    return ShelfItem(
      id: id,
      title: title,
      subtitle: author ?? format.name.toUpperCase(),
      author: author,
      kind: isEbook ? MediaKind.ebook : MediaKind.audio,
      progress: (progressPercent ?? 0).clamp(0.0, 1.0),
      positionLabel: progressLabel,
      coverColorValue: isEbook ? 0xFF045C38 : 0xFF123226,
      coverPath: coverPath,
      libraryId: id,
    );
  }
}

/// Confirms, then removes the library row + media file + cover + progress.
Future<bool> confirmAndDeleteLibraryItem({
  required BuildContext context,
  required WidgetRef ref,
  required LibraryItem item,
}) {
  return confirmAndDeleteLibraryItems(
    context: context,
    ref: ref,
    items: [item],
  );
}

/// Confirms, then removes one or more library rows + files + covers + progress.
Future<bool> confirmAndDeleteLibraryItems({
  required BuildContext context,
  required WidgetRef ref,
  required List<LibraryItem> items,
}) async {
  if (items.isEmpty) return false;

  final single = items.length == 1 ? items.first : null;
  final ok = await context.showAppDialog<bool>(
    builder: (ctx) => AlertDialog(
      title: Text(
        single == null
            ? 'Remove ${items.length} titles?'
            : 'Remove from library?',
      ),
      content: Text(
        single == null
            ? '${items.length} files will be deleted from this device, '
                  'including their progress.'
            : '“${single.title}” will be deleted from this device, '
                  'including its progress.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (ok != true) return false;
  if (!context.mounted) return false;

  var failures = 0;
  for (final item in items) {
    final result = await deleteLibraryItem(ref, item);
    if (result.isFailure) failures++;
  }
  if (!context.mounted) return failures == 0;

  if (failures == 0) {
    context.showSnackBar(
      single == null
          ? 'Removed ${items.length} titles'
          : 'Removed “${single.title}”',
    );
  } else {
    context.showSnackBar(
      'Couldn’t remove $failures of ${items.length} titles',
      isError: true,
    );
  }
  return failures == 0;
}

Future<Result<void>> toggleFavorite(WidgetRef ref, LibraryItem item) async {
  final userId = ref.read(currentAuthUserProvider)?.id ?? ProgressUserIds.local;
  final result = await ref
      .read(favoriteRepositoryProvider)
      .setFavorite(
        mediaId: item.id,
        workId: item.workId,
        favorite: !item.isFavorite,
        userId: userId,
      );
  return result.fold(
    onSuccess: (_) => const Success(null),
    onFailure: Failure.new,
  );
}

Future<Result<void>> deleteLibraryItem(WidgetRef ref, LibraryItem item) async {
  final player = ref.read(audioPlayerServiceProvider);
  if (player.currentItem?.id == item.id) {
    await player.stop();
  }
  return ref.read(libraryRepositoryProvider).delete(item.id);
}
