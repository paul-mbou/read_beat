import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gutter/flutter_gutter.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:read_beat/app/icons.dart';
import 'package:read_beat/app/router.dart';
import 'package:read_beat/core/constants/app_constants.dart';
import 'package:read_beat/core/errors/app_exception.dart';
import 'package:read_beat/core/extensions/extensions.dart';
import 'package:read_beat/features/auth/presentation/controllers/auth_controller.dart';
import 'package:read_beat/features/library/domain/models/library_item.dart';
import 'package:read_beat/features/library/domain/models/shelf_item.dart';
import 'package:read_beat/features/library/presentation/providers/desk_home_providers.dart';
import 'package:read_beat/features/library/presentation/widgets/desk_home_widgets.dart';
import 'package:read_beat/features/sync/presentation/sync_providers.dart';

/// Desk Shelf — primary home: Continue → in progress → shelf.
class DeskHomeScreen extends HookConsumerWidget {
  const DeskHomeScreen({
    super.key,
    required this.onOpenImport,
    required this.onOpenLibrary,
  });

  final VoidCallback onOpenImport;
  final VoidCallback onOpenLibrary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentAuthUserProvider);
    final continueItem = ref.watch(continueItemProvider);
    final alsoInProgress = ref.watch(alsoInProgressProvider);
    final shelf = ref.watch(recentShelfProvider);
    final activeAudio = ref.watch(activeAudioProvider);
    final syncBusy = useState(false);
    final signedIn = user != null;

    String greeting() {
      final hour = DateTime.now().hour;
      if (hour < 12) return 'Good morning';
      if (hour < 18) return 'Good afternoon';
      return 'Good evening';
    }

    Future<void> requestSync() async {
      if (!signedIn) {
        context.push(AppRoutes.authForSync());
        return;
      }
      if (syncBusy.value) return;
      syncBusy.value = true;
      final result = await ref.read(syncEngineProvider).syncNow();
      if (!context.mounted) return;
      syncBusy.value = false;
      if (result.isFailure) {
        final error = result.errorOrNull;
        if (error is AuthException) {
          context.push(AppRoutes.authForSync());
          return;
        }
        context.showSnackBar(error?.message ?? 'Sync failed', isError: true);
        return;
      }
      context.showSnackBar('Progress synced');
    }

    Future<void> resume(ShelfItem item) async {
      HapticFeedback.lightImpact();
      final id = item.libraryId ?? item.id;
      final cached =
          ref.read(libraryItemsProvider).asData?.value ?? const <LibraryItem>[];
      var libraryItem = cached.where((e) => e.id == id).firstOrNull;
      libraryItem ??=
          (await ref.read(libraryRepositoryProvider).getById(id)).valueOrNull;
      if (!context.mounted) return;
      if (libraryItem == null) {
        context.showSnackBar('Item not found', isError: true);
        return;
      }

      if (libraryItem.isAudio) {
        final result = await ref
            .read(audioPlayerServiceProvider)
            .playItem(libraryItem);
        if (!context.mounted) return;
        result.fold(
          onSuccess: (_) => context.push(AppRoutes.audioPlayer),
          onFailure: (e) => context.showSnackBar(e.message, isError: true),
        );
      } else {
        context.push(AppRoutes.ebookReader(libraryItem.id));
      }
    }

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: context.pagePaddingComfortable,
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppConstants.appName,
                          style: context.textTheme.displayMedium?.copyWith(
                            color: context.brandColors.primary,
                          ),
                        ),
                        const GutterTiny(),
                        Text(greeting(), style: context.textTheme.bodyLarge),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Search',
                    onPressed: () => context.push(AppRoutes.search),
                    icon: const AppIcon(AppIcons.search),
                  ),
                  IconButton(
                    tooltip: signedIn ? 'Account' : 'Sign in to sync',
                    onPressed: () {
                      if (signedIn) {
                        context.showSnackBar(
                          'Signed in as ${user.name ?? user.email}',
                        );
                      } else {
                        context.push(AppRoutes.authForSync());
                      }
                    },
                    icon: AppIcon(AppIcons.account, active: signedIn),
                  ),
                ],
              ),
              const GutterSmall(),
              _QuietSyncLine(
                signedIn: signedIn,
                busy: syncBusy.value,
                onTap: requestSync,
              ),
              const Gutter(),
              if (continueItem == null)
                EmptyContinueCard(onImport: onOpenImport)
              else
                ContinueModule(
                  item: continueItem,
                  onResume: () => resume(continueItem),
                ),
              if (alsoInProgress.isNotEmpty) ...[
                const GutterLarge(),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Also in progress',
                        style: context.textTheme.titleMedium,
                      ),
                    ),
                    if (alsoInProgress.length > 3)
                      TextButton(
                        onPressed: onOpenLibrary,
                        child: const Text('See all'),
                      ),
                  ],
                ),
                const GutterSmall(),
                HomeShelfRow(items: alsoInProgress, onOpen: resume),
              ],
              ref
                  .watch(orphanResumesProvider)
                  .when(
                    data: (orphans) {
                      if (orphans.isEmpty) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const GutterLarge(),
                          OrphanResumesSection(
                            orphans: orphans,
                            onImport: onOpenImport,
                          ),
                        ],
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
              const GutterLarge(),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Your shelf',
                      style: context.textTheme.titleMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: onOpenLibrary,
                    child: const Text('See all'),
                  ),
                ],
              ),
              const GutterSmall(),
              if (shelf.isEmpty)
                EmptyShelfHint(onImport: onOpenImport)
              else
                Padding(
                  padding: EdgeInsets.only(
                    bottom: activeAudio == null ? 16 : 24,
                  ),
                  child: HomeShelfRow(items: shelf, onOpen: resume),
                ),
            ]),
          ),
        ),
      ],
    );
  }
}

class _QuietSyncLine extends StatelessWidget {
  const _QuietSyncLine({
    required this.signedIn,
    required this.busy,
    required this.onTap,
  });

  final bool signedIn;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = busy
        ? 'Syncing…'
        : signedIn
        ? 'Synced · Sync now'
        : 'On this device · Sign in to sync';
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: const Size(0, 36),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: busy ? null : onTap,
        child: Text(label, style: context.textTheme.bodyMedium),
      ),
    );
  }
}
