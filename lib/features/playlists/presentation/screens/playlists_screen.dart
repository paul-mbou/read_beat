import 'package:flutter/material.dart';
import 'package:flutter_gutter/flutter_gutter.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:read_beat/app/brand_widgets.dart';
import 'package:read_beat/app/di.dart';
import 'package:read_beat/app/icons.dart';
import 'package:read_beat/app/router.dart';
import 'package:read_beat/core/extensions/extensions.dart';
import 'package:read_beat/features/auth/presentation/controllers/auth_controller.dart';
import 'package:read_beat/features/library/presentation/providers/desk_home_providers.dart';
import 'package:read_beat/features/library/presentation/widgets/desk_home_widgets.dart';
import 'package:read_beat/features/progress/domain/progress_user_ids.dart';

class PlaylistsScreen extends ConsumerWidget {
  const PlaylistsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(playlistsProvider);

    Future<void> create() async {
      final name = await promptPlaylistName(context);
      if (name == null || !context.mounted) return;
      final userId =
          ref.read(currentAuthUserProvider)?.id ?? ProgressUserIds.local;
      final result = await ref
          .read(playlistRepositoryProvider)
          .create(title: name, userId: userId);
      if (!context.mounted) return;
      result.fold(
        onSuccess: (playlist) => context.push(AppRoutes.playlist(playlist.id)),
        onFailure: (e) => context.showSnackBar(e.message, isError: true),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Listening queues')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (playlists) {
          if (playlists.isEmpty) {
            return Padding(
              padding: context.pagePaddingComfortable,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Queue a listening stretch',
                    style: context.textTheme.titleLarge,
                  ),
                  const GutterTiny(),
                  Text(
                    'Group audio titles for a commute or evening. Queues stay '
                    'on this device until you sign in to sync.',
                    style: context.textTheme.bodyLarge,
                  ),
                  const Gutter(),
                  BrandGradientButton(
                    onPressed: create,
                    child: const Text('New queue'),
                  ),
                ],
              ),
            );
          }
          return ListView(
            padding: context.pagePaddingComfortable,
            children: [
              BrandGradientButton(
                onPressed: create,
                child: const Text('New queue'),
              ),
              const Gutter(),
              ...playlists.map(
                (playlist) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ResumePulseSurface(
                    radius: 16,
                    onTap: () => context.push(AppRoutes.playlist(playlist.id)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      leading: AppIcon(
                        AppIcons.playlist,
                        color: context.brandColors.primary,
                      ),
                      title: Text(playlist.title),
                      subtitle: Text(
                        playlist.trackCount == 1
                            ? '1 track'
                            : '${playlist.trackCount} tracks',
                      ),
                      trailing: const AppIcon(AppIcons.chevronRight, size: 16),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

Future<String?> promptPlaylistName(
  BuildContext context, {
  String? initial,
}) async {
  final controller = TextEditingController(text: initial ?? '');
  final name = await context.showAppDialog<String>(
    builder: (ctx) => AlertDialog(
      title: Text(initial == null ? 'New queue' : 'Rename queue'),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(labelText: 'Name'),
        onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  controller.dispose();
  if (name == null || name.isEmpty) return null;
  return name;
}
