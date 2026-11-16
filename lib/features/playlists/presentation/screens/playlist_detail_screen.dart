import 'package:flutter/material.dart';
import 'package:flutter_gutter/flutter_gutter.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:read_beat/app/brand_widgets.dart';
import 'package:read_beat/app/di.dart';
import 'package:read_beat/app/icons.dart';
import 'package:read_beat/app/router.dart';
import 'package:read_beat/core/extensions/extensions.dart';
import 'package:read_beat/features/library/domain/models/library_item.dart';
import 'package:read_beat/features/library/presentation/providers/desk_home_providers.dart';
import 'package:read_beat/features/library/presentation/widgets/desk_home_widgets.dart';
import 'package:read_beat/features/playlists/domain/models/audio_playlist.dart';
import 'package:read_beat/features/playlists/presentation/screens/playlists_screen.dart';

class PlaylistDetailScreen extends ConsumerWidget {
  const PlaylistDetailScreen({super.key, required this.playlistId});

  final String playlistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists =
        ref.watch(playlistsProvider).asData?.value ?? const <AudioPlaylist>[];
    final playlist = playlists.where((p) => p.id == playlistId).firstOrNull;
    final library =
        ref.watch(libraryItemsProvider).asData?.value ?? const <LibraryItem>[];

    if (playlist == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Queue not found')),
      );
    }

    LibraryItem? itemFor(PlaylistTrack track) {
      return library.where((e) => e.id == track.mediaId).firstOrNull ??
          library.where((e) => e.workId == track.workId).firstOrNull;
    }

    final resolved = [
      for (final track in playlist.tracks) (track: track, item: itemFor(track)),
    ];
    final playable = resolved
        .where((e) => e.item != null && e.item!.isAudio)
        .map((e) => e.item!)
        .toList();

    Future<void> playAll() async {
      if (playable.isEmpty) {
        context.showSnackBar('Add audio that’s on this device first.');
        return;
      }
      final result = await ref
          .read(audioPlayerServiceProvider)
          .playQueue(playable);
      if (!context.mounted) return;
      result.fold(
        onSuccess: (_) => context.push(AppRoutes.audioPlayer),
        onFailure: (e) => context.showSnackBar(e.message, isError: true),
      );
    }

    Future<void> rename() async {
      final name = await promptPlaylistName(context, initial: playlist.title);
      if (name == null || !context.mounted) return;
      final result = await ref
          .read(playlistRepositoryProvider)
          .rename(id: playlist.id, title: name);
      if (!context.mounted) return;
      result.fold(
        onSuccess: (_) {},
        onFailure: (e) => context.showSnackBar(e.message, isError: true),
      );
    }

    Future<void> remove() async {
      final ok = await context.showAppDialog<bool>(
        builder: (ctx) => AlertDialog(
          title: const Text('Delete this queue?'),
          content: Text('“${playlist.title}” will be removed. Audio files stay.'),
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
      if (ok != true || !context.mounted) return;
      final result = await ref.read(playlistRepositoryProvider).delete(playlist.id);
      if (!context.mounted) return;
      result.fold(
        onSuccess: (_) => context.pop(),
        onFailure: (e) => context.showSnackBar(e.message, isError: true),
      );
    }

    Future<void> addTracks() async {
      final audio = library.where((e) => e.isAudio).toList();
      final already = playlist.tracks.map((t) => t.mediaId).toSet();
      final available = audio.where((e) => !already.contains(e.id)).toList();
      if (available.isEmpty) {
        context.showSnackBar('Every audio title is already in this queue.');
        return;
      }
      final picked = await showModalBottomSheet<LibraryItem>(
        context: context,
        showDragHandle: true,
        builder: (ctx) {
          return ListView(
            padding: ctx.pagePaddingComfortable,
            children: [
              Text('Add a track', style: ctx.textTheme.titleLarge),
              const Gutter(),
              ...available.map(
                (item) => ListTile(
                  title: Text(item.title),
                  subtitle: Text(item.author ?? item.format.name.toUpperCase()),
                  onTap: () => Navigator.pop(ctx, item),
                ),
              ),
            ],
          );
        },
      );
      if (picked == null || !context.mounted) return;
      final result = await ref
          .read(playlistRepositoryProvider)
          .addTrack(playlistId: playlist.id, item: picked);
      if (!context.mounted) return;
      result.fold(
        onSuccess: (_) => context.showSnackBar('Added “${picked.title}”'),
        onFailure: (e) => context.showSnackBar(e.message, isError: true),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(playlist.title),
        actions: [
          IconButton(
            tooltip: 'Rename',
            onPressed: rename,
            icon: const AppIcon(AppIcons.library, size: 18),
          ),
          IconButton(
            tooltip: 'Delete queue',
            onPressed: remove,
            icon: const AppIcon(AppIcons.delete, size: 18),
          ),
        ],
      ),
      body: ListView(
        padding: context.pagePaddingComfortable,
        children: [
          BrandGradientButton(
            onPressed: playAll,
            child: const Text('Play queue'),
          ),
          const GutterSmall(),
          OutlinedButton.icon(
            onPressed: addTracks,
            icon: const AppIcon(AppIcons.import, size: 16),
            label: const Text('Add audio'),
          ),
          const GutterLarge(),
          if (resolved.isEmpty)
            Text(
              'Empty queue. Add audio from this device.',
              style: context.textTheme.bodyLarge,
            )
          else
            ...resolved.map((row) {
              final item = row.item;
              final track = row.track;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ResumePulseSurface(
                  radius: 14,
                  child: ListTile(
                    title: Text(item?.title ?? 'Not on this device'),
                    subtitle: Text(
                      item == null
                          ? 'Import the matching file to play this track.'
                          : (item.author ?? item.format.name.toUpperCase()),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Move up',
                          onPressed: () => ref
                              .read(playlistRepositoryProvider)
                              .moveTrack(
                                playlistId: playlist.id,
                                trackId: track.id,
                                delta: -1,
                              ),
                          icon: const AppIcon(AppIcons.chevronUp, size: 14),
                        ),
                        IconButton(
                          tooltip: 'Move down',
                          onPressed: () => ref
                              .read(playlistRepositoryProvider)
                              .moveTrack(
                                playlistId: playlist.id,
                                trackId: track.id,
                                delta: 1,
                              ),
                          icon: const AppIcon(AppIcons.chevronDown, size: 14),
                        ),
                        IconButton(
                          tooltip: 'Remove',
                          onPressed: () => ref
                              .read(playlistRepositoryProvider)
                              .removeTrack(
                                playlistId: playlist.id,
                                trackId: track.id,
                              ),
                          icon: const AppIcon(AppIcons.delete, size: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
