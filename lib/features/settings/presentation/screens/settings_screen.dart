import 'package:flutter/material.dart';
import 'package:flutter_gutter/flutter_gutter.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:read_beat/app/brand_widgets.dart';
import 'package:read_beat/app/di.dart';
import 'package:read_beat/app/icons.dart';
import 'package:read_beat/app/router.dart';
import 'package:read_beat/app/theme.dart';
import 'package:read_beat/app/theme_mode_controller.dart';
import 'package:read_beat/core/constants/app_constants.dart';
import 'package:read_beat/core/extensions/extensions.dart';
import 'package:read_beat/features/auth/presentation/controllers/auth_controller.dart';
import 'package:read_beat/features/library/presentation/providers/desk_home_providers.dart';
import 'package:read_beat/features/recap_ai/presentation/recap_consent_controller.dart';
import 'package:read_beat/features/sync/presentation/sync_providers.dart';

class SettingsScreen extends HookConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentAuthUserProvider);
    final themeMode = ref.watch(themeModeProvider);
    final sync = ref.watch(syncStatusProvider);
    final stats = ref.watch(storageStatsProvider);
    final recapConsent = ref.watch(recapConsentProvider);
    final accountBusy = useState(false);

    Future<void> signOut() async {
      accountBusy.value = true;
      final result = await ref.read(authControllerProvider).signOut();
      if (!context.mounted) return;
      accountBusy.value = false;
      result.fold(
        onSuccess: (_) => context.showSnackBar(
          'Signed out. Your library stays on this device.',
        ),
        onFailure: (e) => context.showSnackBar(e.message, isError: true),
      );
    }

    Future<void> deleteAccount() async {
      final confirmed = await context.showAppDialog<bool>(
        builder: (ctx) => AlertDialog(
          title: const Text('Delete account?'),
          content: const Text(
            'This blocks your ReadBeat account and signs you out on this device. '
            'Local library files stay until you clear app data.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: ctx.colorScheme.error,
              ),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
      accountBusy.value = true;
      final result = await ref.read(authControllerProvider).deleteAccount();
      if (!context.mounted) return;
      accountBusy.value = false;
      result.fold(
        onSuccess: (_) => context.showSnackBar(
          'Account deleted. Your local library is unchanged.',
        ),
        onFailure: (e) => context.showSnackBar(e.message, isError: true),
      );
    }

    Future<void> syncNow() async {
      if (user == null) {
        context.push(AppRoutes.authForSync());
        return;
      }
      if (sync.busy) return;
      ref.read(syncStatusProvider.notifier).setBusy(true);
      final result = await ref.read(syncEngineProvider).syncNow();
      if (!context.mounted) return;
      if (result.isFailure) {
        await ref.read(syncStatusProvider.notifier).refreshPending();
        if (!context.mounted) return;
        ref.read(syncStatusProvider.notifier).setBusy(false);
        context.showSnackBar(
          result.errorOrNull?.message ?? 'Sync failed',
          isError: true,
        );
        return;
      }
      await ref.read(syncStatusProvider.notifier).markSuccess();
      if (!context.mounted) return;
      context.showSnackBar('Progress, favorites, and queues synced');
    }

    Future<void> requestNotifications() async {
      final granted = await ref
          .read(permissionServiceProvider)
          .requestNotifications();
      if (!context.mounted) return;
      context.showSnackBar(
        granted
            ? 'Lock-screen controls can follow your audio.'
            : 'Notifications stay off. You can enable them in system settings.',
      );
    }

    final lastSync = sync.lastSuccessAt;
    final lastSyncLabel = lastSync == null
        ? 'Not synced yet'
        : 'Last sync ${DateFormat.MMMd().add_jm().format(lastSync.toLocal())}';

    return ListView(
      padding: context.pagePaddingComfortable,
      children: [
        Text('Settings', style: context.textTheme.displayMedium),
        const GutterTiny(),
        Text(
          'Account, sync, storage, and privacy — all in service of resume.',
          style: context.textTheme.bodyLarge,
        ),
        const GutterLarge(),
        _SectionLabel(icon: AppIcons.sync, label: 'Sync'),
        const GutterSmall(),
        GlassPanel(
          borderRadius: 16,
          child: Padding(
            padding: context.contentPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  sync.online
                      ? (user == null
                            ? 'On this device only'
                            : sync.busy
                            ? 'Syncing…'
                            : lastSyncLabel)
                      : 'Offline — changes wait in the outbox',
                  style: context.textTheme.titleMedium,
                ),
                const GutterTiny(),
                Text(
                  user == null
                      ? 'We sync reading and listening position, favorites, and '
                            'queues — not your files.'
                      : sync.pendingCount > 0
                      ? '${sync.pendingCount} change${sync.pendingCount == 1 ? '' : 's'} waiting to upload.'
                      : 'Progress, favorites, and listening queues stay aligned when you’re online.',
                  style: context.textTheme.bodyMedium,
                ),
                const Gutter(),
                BrandGradientButton(
                  onPressed: sync.busy ? null : syncNow,
                  child: Text(
                    user == null
                        ? 'Sign in to sync'
                        : sync.busy
                        ? 'Syncing…'
                        : 'Sync now',
                  ),
                ),
              ],
            ),
          ),
        ),
        const GutterLarge(),
        _SectionLabel(icon: AppIcons.storage, label: 'Storage'),
        const GutterSmall(),
        GlassPanel(
          borderRadius: 16,
          child: Padding(
            padding: context.contentPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(stats.readableSize, style: context.textTheme.titleLarge),
                const GutterTiny(),
                Text(
                  '${stats.itemCount} titles · ${stats.ebookCount} ebooks · '
                  '${stats.audioCount} audio · ${stats.playlistCount} queues',
                  style: context.textTheme.bodyMedium,
                ),
                const GutterTiny(),
                Text(
                  '${stats.favoriteCount} favorites. Files live in app storage '
                  'on this device. Remove a title from the library to free space.',
                  style: context.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
        const GutterLarge(),
        _SectionLabel(icon: AppIcons.sun, label: 'Appearance'),
        const GutterSmall(),
        Text(
          'Choose light, dark, or follow your device.',
          style: context.textTheme.bodyMedium,
        ),
        const GutterSmall(),
        SegmentedButton<ThemeMode>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: ThemeMode.system,
              label: const Text('System'),
              icon: AppIcon(
                AppIcons.themeAuto,
                active: themeMode == ThemeMode.system,
                size: 16,
              ),
            ),
            ButtonSegment(
              value: ThemeMode.light,
              label: const Text('Light'),
              icon: AppIcon(
                AppIcons.sun,
                active: themeMode == ThemeMode.light,
                size: 16,
              ),
            ),
            ButtonSegment(
              value: ThemeMode.dark,
              label: const Text('Dark'),
              icon: AppIcon(
                AppIcons.moon,
                active: themeMode == ThemeMode.dark,
                size: 16,
              ),
            ),
          ],
          selected: {themeMode},
          onSelectionChanged: (set) {
            ref.read(themeModeProvider.notifier).setMode(set.first);
          },
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
            shape: const WidgetStatePropertyAll(StadiumBorder()),
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return context.colorScheme.secondary;
              }
              return context.colorScheme.surfaceContainerHighest;
            }),
            foregroundColor: WidgetStatePropertyAll(
              context.colorScheme.onSurface,
            ),
            side: WidgetStatePropertyAll(
              BorderSide(color: context.colorScheme.outline),
            ),
          ),
        ),
        const GutterLarge(),
        _SectionLabel(icon: AppIcons.privacy, label: 'Privacy'),
        const GutterSmall(),
        GlassPanel(
          borderRadius: 16,
          child: Padding(
            padding: context.contentPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('AI recap consent'),
                  subtitle: const Text(
                    'Off by default. ReadBeat will not send chapter text until '
                    'you opt in. Recap itself is not live yet.',
                  ),
                  value: recapConsent,
                  onChanged: (v) =>
                      ref.read(recapConsentProvider.notifier).setConsent(v),
                ),
                const Divider(height: 24),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const AppIcon(AppIcons.bell, size: 18),
                  title: const Text('Lock-screen audio'),
                  subtitle: const Text(
                    'Notifications only exist so pause/skip can appear while locked.',
                  ),
                  trailing: TextButton(
                    onPressed: requestNotifications,
                    child: const Text('Allow'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const GutterLarge(),
        _SectionLabel(icon: AppIcons.account, label: 'Account'),
        const GutterSmall(),
        if (user == null) ...[
          Text(
            'You’re using ReadBeat on this device only. Sign in when you want '
            'position, favorites, and queues to sync — files still stay local.',
            style: context.textTheme.bodyMedium,
          ),
          const Gutter(),
          BrandGradientButton(
            onPressed: accountBusy.value
                ? null
                : () => context.push(AppRoutes.authForSync()),
            child: const Text('Sign in to sync'),
          ),
        ] else ...[
          Text(
            user.name ?? user.email,
            style: context.textTheme.titleMedium,
          ),
          if (user.name != null)
            Text(user.email, style: context.textTheme.bodyMedium),
          const Gutter(),
          OutlinedButton(
            onPressed: accountBusy.value ? null : signOut,
            child: const Text('Sign out'),
          ),
          const GutterSmall(),
          TextButton(
            onPressed: accountBusy.value ? null : deleteAccount,
            child: Text(
              'Delete account',
              style: TextStyle(color: context.colorScheme.error),
            ),
          ),
        ],
        const GutterLarge(),
        Text(AppConstants.appName, style: context.textTheme.bodySmall),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.label});

  final AppIconPair icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AppIcon(icon, size: 16, color: context.brandColors.primary),
        const SizedBox(width: 8),
        Text(label, style: context.textTheme.titleMedium),
      ],
    );
  }
}
