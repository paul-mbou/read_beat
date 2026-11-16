import 'package:flutter/material.dart';
import 'package:flutter_gutter/flutter_gutter.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:read_beat/app/brand_widgets.dart';
import 'package:read_beat/app/di.dart';
import 'package:read_beat/app/icons.dart';
import 'package:read_beat/app/router.dart';
import 'package:read_beat/core/constants/app_constants.dart';
import 'package:read_beat/core/extensions/extensions.dart';
import 'package:read_beat/features/library/presentation/widgets/desk_home_widgets.dart';
import 'package:read_beat/features/onboarding/presentation/onboarding_controller.dart';

/// First-run desk tour: ritual, local library, lock-screen audio, optional sync.
class OnboardingScreen extends HookConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = useState(0);
    final busy = useState(false);

    Future<void> finish() async {
      await ref.read(onboardingPhaseProvider.notifier).complete();
      if (!context.mounted) return;
      context.go(AppRoutes.home);
    }

    Future<void> requestNotifications() async {
      busy.value = true;
      final granted = await ref
          .read(permissionServiceProvider)
          .requestNotifications();
      busy.value = false;
      if (!context.mounted) return;
      context.showSnackBar(
        granted
            ? 'Lock-screen controls can follow your audio.'
            : 'You can enable notifications later in Settings.',
      );
      page.value = 3;
    }

    final pages = [
      _OnboardingPage(
        kicker: AppConstants.appName,
        title: 'Pick up the exact beat.',
        body:
            'Open ReadBeat and Resume answers “where was I?” — page or track, '
            'on this device first.',
        icon: AppIcons.book,
        child: const _PulsePreview(),
      ),
      _OnboardingPage(
        kicker: 'Your shelf',
        title: 'Files stay on this desk.',
        body:
            'Import EPUB, PDF, MP3, or M4A. ReadBeat copies them into app storage '
            'and never uploads a file unless you later choose cloud backup.',
        icon: AppIcons.library,
      ),
      _OnboardingPage(
        kicker: 'Listening',
        title: 'Lock-screen audio needs a quiet yes.',
        body:
            'Notifications let pause and skip show while the phone is locked. '
            'Skip if you only read for now — you can allow this in Settings.',
        icon: AppIcons.bell,
      ),
      _OnboardingPage(
        kicker: 'Sync',
        title: 'Sign in only when you switch devices.',
        body:
            'Progress, favorites, and listening queues can follow your account. '
            'The library itself stays local until you want backup.',
        icon: AppIcons.sync,
      ),
    ];

    final isLast = page.value == pages.length - 1;
    final isNotify = page.value == 2;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DeskAtmosphere(
        child: SafeArea(
          child: Padding(
            padding: context.pagePadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: busy.value ? null : finish,
                    child: const Text('Skip'),
                  ),
                ),
                const Spacer(),
                pages[page.value],
                const Spacer(),
                Row(
                  children: [
                    for (var i = 0; i < pages.length; i++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            height: 3,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(99),
                              color: i <= page.value
                                  ? context.brandColors.primary
                                  : context.colorScheme.outline.withOpacityValue(
                                      0.45,
                                    ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const Gutter(),
                if (isNotify) ...[
                  BrandGradientButton(
                    onPressed: busy.value ? null : requestNotifications,
                    child: Text(busy.value ? 'Asking…' : 'Allow notifications'),
                  ),
                  const GutterSmall(),
                  OutlinedButton(
                    onPressed: busy.value ? null : () => page.value = 3,
                    child: const Text('Not now'),
                  ),
                ] else
                  BrandGradientButton(
                    onPressed: isLast ? finish : () => page.value++,
                    child: Text(isLast ? 'Open my desk' : 'Continue'),
                  ),
                const GutterSmall(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.kicker,
    required this.title,
    required this.body,
    required this.icon,
    this.child,
  });

  final String kicker;
  final String title;
  final String body;
  final AppIconPair icon;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppIcon(icon, color: context.brandColors.primary, size: 28),
        const Gutter(),
        Text(
          kicker,
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.brandColors.primary,
          ),
        ),
        const GutterTiny(),
        Text(title, style: context.textTheme.displayMedium),
        const GutterSmall(),
        Text(body, style: context.textTheme.bodyLarge),
        if (child != null) ...[const GutterLarge(), child!],
      ],
    );
  }
}

class _PulsePreview extends StatelessWidget {
  const _PulsePreview();

  @override
  Widget build(BuildContext context) {
    return ResumePulseSurface(
      radius: 16,
      child: Padding(
        padding: context.contentPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Continue', style: context.textTheme.bodySmall),
            const GutterTiny(),
            Text('Your next page or beat', style: context.textTheme.titleMedium),
            const GutterSmall(),
            const BeatProgressBar(value: 0.42),
          ],
        ),
      ),
    );
  }
}
