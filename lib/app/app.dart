import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:read_beat/app/router.dart';
import 'package:read_beat/app/theme.dart';
import 'package:read_beat/app/theme_mode_controller.dart';
import 'package:read_beat/core/constants/app_constants.dart';
import 'package:read_beat/features/auth/presentation/controllers/auth_controller.dart';
import 'package:read_beat/features/importer/presentation/widgets/incoming_media_listener.dart';
import 'package:read_beat/features/onboarding/presentation/onboarding_controller.dart';
import 'package:read_beat/features/splash/presentation/controllers/splash_gate.dart';
import 'package:read_beat/features/sync/presentation/sync_lifecycle.dart';

final goRouterAuthRefreshProvider = Provider<GoRouterAuthRefresh>((ref) {
  final refresh = GoRouterAuthRefresh();
  ref.listen(authSessionProvider, (_, _) => refresh.ping());
  ref.listen(splashGateProvider, (_, _) => refresh.ping());
  ref.listen(onboardingPhaseProvider, (_, _) => refresh.ping());
  ref.onDispose(refresh.dispose);
  return refresh;
});

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ref.watch(goRouterAuthRefreshProvider);
  return createAppRouter(ref, refresh);
});

class ReadBeatApp extends ConsumerWidget {
  const ReadBeatApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final router = ref.watch(appRouterProvider);
    return SyncLifecycleHost(
      child: IncomingMediaListener(
        child: MaterialApp.router(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: ReadBeatTheme.light(),
          darkTheme: ReadBeatTheme.dark(),
          themeMode: themeMode,
          routerConfig: router,
        ),
      ),
    );
  }
}
