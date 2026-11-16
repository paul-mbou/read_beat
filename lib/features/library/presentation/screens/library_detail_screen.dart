import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_gutter/flutter_gutter.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:read_beat/app/icons.dart';
import 'package:read_beat/app/router.dart';
import 'package:read_beat/core/extensions/extensions.dart';
import 'package:read_beat/features/library/domain/models/media_catalog_entry.dart';
import 'package:read_beat/features/library/presentation/providers/desk_home_providers.dart';

class LibraryDetailScreen extends ConsumerWidget {
  const LibraryDetailScreen({super.key, required this.itemId});

  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(libraryItemsProvider);
    final linkCandidates = ref.watch(linkCandidatesProvider(itemId));

    return async.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (items) {
        final item = items.where((e) => e.id == itemId).firstOrNull;
        if (item == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Item not found')),
          );
        }

        Future<void> open() async {
          if (item.isAudio) {
            final result = await ref
                .read(audioPlayerServiceProvider)
                .playItem(item);
            if (!context.mounted) return;
            result.fold(
              onSuccess: (_) => context.push(AppRoutes.audioPlayer),
              onFailure: (e) => context.showSnackBar(e.message, isError: true),
            );
          } else {
            context.push(AppRoutes.ebookReader(item.id));
          }
        }

        Future<void> remove() async {
          final deleted = await confirmAndDeleteLibraryItem(
            context: context,
            ref: ref,
            item: item,
          );
          if (deleted && context.mounted) context.pop();
        }

        Future<void> link(MediaCatalogEntry orphan) async {
          final result = await ref
              .read(libraryRepositoryProvider)
              .linkToWork(itemId: item.id, workId: orphan.workId);
          if (!context.mounted) return;
          result.fold(
            onSuccess: (_) {
              ref.invalidate(orphanResumesProvider);
              ref.invalidate(libraryItemsProvider);
              context.showSnackBar('Linked to “${orphan.title}” resume');
            },
            onFailure: (e) => context.showSnackBar(e.message, isError: true),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(item.title),
            actions: [
              IconButton(
                tooltip: item.isFavorite ? 'Unfavorite' : 'Favorite',
                onPressed: () => toggleFavorite(ref, item),
                icon: AppIcon(
                  AppIcons.favorite,
                  active: item.isFavorite,
                  color: item.isFavorite ? context.brandColors.accent : null,
                ),
              ),
              IconButton(
                tooltip: 'Delete',
                onPressed: remove,
                icon: const AppIcon(AppIcons.delete),
              ),
            ],
          ),
          body: ListView(
            padding: context.pagePaddingComfortable,
            children: [
              if (item.coverPath != null &&
                  File(item.coverPath!).existsSync()) ...[
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(
                      File(item.coverPath!),
                      width: 180,
                      height: 270,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const GutterLarge(),
              ],
              Text(item.title, style: context.textTheme.displayMedium),
              if (item.author != null) ...[
                const GutterTiny(),
                Text(item.author!, style: context.textTheme.bodyLarge),
              ],
              const Gutter(),
              Text(
                [
                  item.format.name.toUpperCase(),
                  item.cloudStatus.name,
                  if (item.progressLabel != null) item.progressLabel!,
                ].join(' · '),
                style: context.textTheme.bodyMedium,
              ),
              const GutterLarge(),
              FilledButton(onPressed: open, child: Text(item.resumeLabel)),
              if (item.isAudio) ...[
                const GutterSmall(),
                OutlinedButton.icon(
                  onPressed: () => context.push(AppRoutes.playlists),
                  icon: const AppIcon(AppIcons.playlist, size: 16),
                  label: const Text('Add to a listening queue'),
                ),
              ],
              const GutterSmall(),
              OutlinedButton.icon(
                onPressed: remove,
                icon: const AppIcon(AppIcons.delete, size: 16),
                label: const Text('Remove from library'),
              ),
              if (linkCandidates.isNotEmpty) ...[
                const GutterLarge(),
                Text(
                  'Link to a synced resume',
                  style: context.textTheme.titleMedium,
                ),
                const GutterTiny(),
                Text(
                  'This file looks like a resume waiting on another device. '
                  'Linking merges progress without uploading the file.',
                  style: context.textTheme.bodyMedium,
                ),
                const GutterSmall(),
                ...linkCandidates.map(
                  (o) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(o.title),
                    subtitle: Text(
                      [
                        o.author,
                        o.format.name.toUpperCase(),
                      ].whereType<String>().join(' · '),
                    ),
                    trailing: TextButton(
                      onPressed: () => link(o),
                      child: const Text('Link'),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
