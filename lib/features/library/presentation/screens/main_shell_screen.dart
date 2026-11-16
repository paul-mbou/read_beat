import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:read_beat/app/brand_widgets.dart';
import 'package:read_beat/app/theme.dart';
import 'package:read_beat/app/icons.dart';
import 'package:read_beat/app/router.dart';
import 'package:read_beat/core/extensions/extensions.dart';
import 'package:read_beat/features/auth/presentation/controllers/auth_controller.dart';
import 'package:read_beat/features/importer/presentation/controllers/import_controller.dart';
import 'package:read_beat/features/importer/presentation/screens/import_screen.dart';
import 'package:read_beat/features/importer/presentation/widgets/import_status_banner.dart';
import 'package:read_beat/features/library/presentation/providers/desk_home_providers.dart';
import 'package:read_beat/features/library/presentation/screens/desk_home_screen.dart';
import 'package:read_beat/features/library/presentation/screens/library_screen.dart';
import 'package:read_beat/features/library/presentation/widgets/desk_home_widgets.dart';
import 'package:read_beat/features/settings/presentation/screens/settings_screen.dart';
import 'package:read_beat/features/sync/presentation/sync_providers.dart';

/// App shell: Desk Shelf home + Library / Import / Settings tabs.
class MainShellScreen extends HookConsumerWidget {
  const MainShellScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = useState(0);
    final activeAudio = ref.watch(activeAudioProvider);
    final user = ref.watch(currentAuthUserProvider);
    final sync = ref.watch(syncStatusProvider);

    final pages = [
      DeskHomeScreen(
        onOpenImport: () => tab.value = 2,
        onOpenLibrary: () => tab.value = 1,
      ),
      LibraryScreen(onOpenImport: () => tab.value = 2),
      const ImportScreen(),
      const SettingsScreen(),
    ];

    final importing = ref.watch(importStatusProvider).isActive;

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: DeskAtmosphere(
        child: Stack(
          children: [
            SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const ImportStatusBanner(),
                  if (user != null && !sync.online)
                    const _OfflineSyncBanner(),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        bottom: activeAudio != null ? 152 : 88,
                      ),
                      child: IndexedStack(index: tab.value, children: pages),
                    ),
                  ),
                ],
              ),
            ),
            if (importing) const ImportStatusHairline(),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (activeAudio != null) ...[
              MiniPlayerBar(
                item: activeAudio,
                onPause: () {
                  // ignore: discarded_futures
                  ref.read(audioPlayerServiceProvider).pause();
                },
                onOpen: () => context.push(AppRoutes.audioPlayer),
              ),
              const SizedBox(height: 10),
            ],
            FloatingDeskNavShell(
              child: DeskIconNav(
                selectedIndex: tab.value,
                onDestinationSelected: (i) => tab.value = i,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfflineSyncBanner extends StatelessWidget {
  const _OfflineSyncBanner();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: GlassPanel(
        borderRadius: 999,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              AppIcon(
                AppIcons.offline,
                size: 14,
                color: context.brandColors.warning,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Offline. Resume stays on this device; sync waits.',
                  style: context.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
