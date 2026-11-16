import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:read_beat/app/di.dart';
import 'package:read_beat/core/logger/app_logger.dart';
import 'package:read_beat/features/auth/domain/repositories/auth_repository.dart';
import 'package:read_beat/features/auth/presentation/controllers/auth_controller.dart';
import 'package:read_beat/features/sync/domain/repositories/sync_repository.dart';
import 'package:read_beat/features/sync/presentation/sync_providers.dart';

/// Runs pull+flush on sign-in and when connectivity returns.
final syncLifecycleProvider = Provider<void>((ref) {
  final engine = ref.watch(syncEngineProvider);
  final connectivity = ref.watch(connectivityProvider);
  final logger = ref.watch(appLoggerProvider);

  var lastUserId = ref.read(currentAuthUserProvider)?.id;

  ref.listen<AsyncValue<AuthUser?>>(authSessionProvider, (prev, next) {
    final user = next.asData?.value;
    final userId = user?.id;
    if (userId == null || userId == lastUserId) return;
    lastUserId = userId;
    unawaited(_runSync(ref, engine, logger, reason: 'auth'));
  });

  final sub = connectivity.onConnectivityChanged.listen((online) {
    ref.read(syncStatusProvider.notifier).setOnline(online);
    if (!online) return;
    if (ref.read(currentAuthUserProvider) == null) return;
    unawaited(_runSync(ref, engine, logger, reason: 'connectivity'));
  });
  ref.onDispose(sub.cancel);

  // Cold start: if already signed in, sync once after first frame.
  final existing = ref.read(currentAuthUserProvider);
  if (existing != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_runSync(ref, engine, logger, reason: 'startup'));
    });
  }
});

Future<void> _runSync(
  Ref ref,
  SyncEngine engine,
  AppLogger logger, {
  required String reason,
}) async {
  logger.info('Sync trigger: $reason');
  ref.read(syncStatusProvider.notifier).setBusy(true);
  final result = await engine.syncNow();
  if (result.isFailure) {
    logger.info('Sync ($reason) skipped/failed: ${result.errorOrNull?.message}');
    await ref.read(syncStatusProvider.notifier).refreshPending();
    ref.read(syncStatusProvider.notifier).setBusy(false);
    return;
  }
  await ref.read(syncStatusProvider.notifier).markSuccess();
}

/// Widget that keeps [syncLifecycleProvider] alive for the app session.
class SyncLifecycleHost extends ConsumerWidget {
  const SyncLifecycleHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(syncLifecycleProvider);
    return child;
  }
}
