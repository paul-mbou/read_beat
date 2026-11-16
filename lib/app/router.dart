import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:read_beat/app/brand_widgets.dart';
import 'package:read_beat/core/constants/app_constants.dart';
import 'package:read_beat/core/extensions/extensions.dart';
import 'package:read_beat/features/audio_player/presentation/screens/audio_player_screen.dart';
import 'package:read_beat/features/auth/presentation/controllers/auth_controller.dart';
import 'package:read_beat/features/auth/presentation/screens/auth_gate_screen.dart';
import 'package:read_beat/features/ebook_reader/presentation/screens/ebook_reader_screen.dart';
import 'package:read_beat/features/library/presentation/screens/library_detail_screen.dart';
import 'package:read_beat/features/library/presentation/screens/main_shell_screen.dart';
import 'package:read_beat/features/onboarding/presentation/onboarding_controller.dart';
import 'package:read_beat/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:read_beat/features/playlists/presentation/screens/playlist_detail_screen.dart';
import 'package:read_beat/features/playlists/presentation/screens/playlists_screen.dart';
import 'package:read_beat/features/search/presentation/screens/search_screen.dart';
import 'package:read_beat/features/splash/presentation/controllers/splash_gate.dart';
import 'package:read_beat/features/splash/presentation/screens/splash_screen.dart';

/// Application routes. Expand per feature as screens land.
abstract final class AppRoutes {
  static const splash = '/';
  static const home = '/home';
  static const auth = '/auth';
  static const audioPlayer = '/player';
  static const onboarding = '/onboarding';
  static const search = '/search';
  static const playlists = '/playlists';

  /// Opens auth for cross-device sync (optional — library works without it).
  static String authForSync() => '$auth?reason=sync';

  static String libraryItem(String id) => '/library/$id';

  static String ebookReader(String id) => '/reader/$id';

  static String playlist(String id) => '/playlists/$id';
}

/// Notifies [GoRouter] when auth session changes.
final class GoRouterAuthRefresh extends ChangeNotifier {
  void ping() => notifyListeners();
}

/// True when Android/iOS handed us a file URI that must not be a go_router path.
bool _isExternalMediaLocation(Uri uri) {
  final scheme = uri.scheme.toLowerCase();
  if (scheme == 'content' || scheme == 'file') return true;
  // Some engines pass the raw string as a path-only location.
  final raw = uri.toString();
  return raw.startsWith('content:') || raw.startsWith('file:');
}

GoRouter createAppRouter(Ref ref, GoRouterAuthRefresh refresh) {
  return GoRouter(
    // Ignore platform initial route (e.g. content:// from “Open with”).
    // Incoming files are imported via IncomingMediaListener instead.
    overridePlatformDefaultLocation: true,
    initialLocation: AppRoutes.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      if (_isExternalMediaLocation(state.uri)) {
        return AppRoutes.splash;
      }

      final session = ref.read(authSessionProvider);
      final loc = state.matchedLocation;
      final onSplash = loc == AppRoutes.splash;
      final onboarding = ref.read(onboardingPhaseProvider);
      final onOnboarding = loc == AppRoutes.onboarding;

      if (onSplash) {
        final splashReady = ref.read(splashGateProvider);
        if (session.isLoading || !splashReady) return null;
        if (onboarding == OnboardingPhase.unknown) return null;
        if (onboarding == OnboardingPhase.needed) return AppRoutes.onboarding;
        return AppRoutes.home;
      }

      if (onOnboarding && onboarding == OnboardingPhase.done) {
        return AppRoutes.home;
      }

      final loggedIn = session.asData?.value != null;
      final onAuth = loc == AppRoutes.auth;
      if (loggedIn && onAuth) return AppRoutes.home;

      return null;
    },
    errorBuilder: (context, state) {
      // Last-resort: never strand the user on a content:// “Page Not Found”.
      return const _UnknownRouteScreen();
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.auth,
        builder: (context, state) {
          final reason = state.uri.queryParameters['reason'];
          return AuthGateScreen(reason: reason);
        },
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const MainShellScreen(),
      ),
      GoRoute(
        path: '/library/:id',
        builder: (context, state) =>
            LibraryDetailScreen(itemId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.search,
        builder: (context, state) => const SearchScreen(),
      ),
      GoRoute(
        path: AppRoutes.playlists,
        builder: (context, state) => const PlaylistsScreen(),
      ),
      GoRoute(
        path: '/playlists/:id',
        builder: (context, state) =>
            PlaylistDetailScreen(playlistId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.audioPlayer,
        builder: (context, state) => const AudioPlayerScreen(),
      ),
      GoRoute(
        path: '/reader/:id',
        builder: (context, state) =>
            EbookReaderScreen(itemId: state.pathParameters['id']!),
      ),
    ],
  );
}

class _UnknownRouteScreen extends StatelessWidget {
  const _UnknownRouteScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DeskAtmosphere(
        child: SafeArea(
          child: Padding(
            padding: context.pagePadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppConstants.appName, style: context.textTheme.titleLarge),
                const Spacer(),
                Text(
                  'That link isn’t a screen in the app.',
                  style: context.textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'If you opened a file, ReadBeat imports it in the background. '
                  'Otherwise head back to your library.',
                  style: context.textTheme.bodyLarge?.copyWith(
                    color: context.colorScheme.onSurface.withValues(
                      alpha: 0.72,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => context.go(AppRoutes.home),
                  child: const Text('Back to library'),
                ),
                const Spacer(flex: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
