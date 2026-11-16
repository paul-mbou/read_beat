import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gutter/flutter_gutter.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:read_beat/app/brand_widgets.dart';
import 'package:read_beat/app/icons.dart';
import 'package:read_beat/app/router.dart';
import 'package:read_beat/core/constants/app_constants.dart';
import 'package:read_beat/core/extensions/extensions.dart';
import 'package:read_beat/features/auth/domain/models/social_auth_provider.dart';
import 'package:read_beat/features/auth/presentation/controllers/auth_controller.dart';
import 'package:read_beat/features/auth/presentation/widgets/social_auth_button.dart';

/// Optional OAuth sync gate — Google / Apple / Facebook only.
class AuthGateScreen extends HookConsumerWidget {
  const AuthGateScreen({super.key, this.reason});

  /// When `sync`, copy explains sign-in is only for cross-device resume.
  final String? reason;

  bool get _forSync => reason == 'sync';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = useState(false);

    Future<void> submitSocial(SocialAuthProvider provider) async {
      if (busy.value) return;
      busy.value = true;
      final result = await ref
          .read(authControllerProvider)
          .signInWithProvider(provider);
      if (!context.mounted) return;
      busy.value = false;
      result.fold(
        onSuccess: (_) {
          HapticFeedback.lightImpact();
          context.go(AppRoutes.home);
        },
        onFailure: (error) {
          if (error.message.toLowerCase().contains('cancel')) return;
          context.showSnackBar(error.message, isError: true);
        },
      );
    }

    final headline = _forSync ? 'Sign in to sync' : 'Sign in';
    final support = _forSync
        ? 'Reading and listening work on this device without an account. '
              'Continue with Google, Apple, or Facebook only when you want your place '
              'to follow you to another phone or tablet.'
        : 'Optional. Your ebooks and music stay on this device either way — '
              'a provider account unlocks cross-device sync.';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DeskAtmosphere(
        child: SafeArea(
          child: Column(
            children: [
              AppBar(
                leading: IconButton(
                  tooltip: 'Back to library',
                  icon: const AppIcon(AppIcons.close),
                  onPressed: busy.value
                      ? null
                      : () => context.go(AppRoutes.home),
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      padding: context.pagePaddingComfortable,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: IntrinsicHeight(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ShaderMask(
                                blendMode: BlendMode.srcIn,
                                shaderCallback: (bounds) => context
                                    .brandColors
                                    .brandFill
                                    .createShader(bounds),
                                child: Text(
                                  AppConstants.appName,
                                  style: context.textTheme.displayMedium
                                      ?.copyWith(color: Colors.white),
                                ),
                              ),
                              const GutterTiny(),
                              Text(
                                headline,
                                style: context.textTheme.titleLarge,
                              ),
                              const GutterTiny(),
                              Text(support, style: context.textTheme.bodyLarge),
                              const GutterLarge(),
                              if (busy.value) ...[
                                const Center(
                                  child: SizedBox(
                                    width: 28,
                                    height: 28,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                    ),
                                  ),
                                ),
                                const GutterLarge(),
                              ],
                              SocialAuthButton(
                                provider: SocialAuthProvider.google,
                                enabled: !busy.value,
                                onPressed: () =>
                                    submitSocial(SocialAuthProvider.google),
                              ),
                              const GutterSmall(),
                              SocialAuthButton(
                                provider: SocialAuthProvider.apple,
                                enabled: !busy.value,
                                onPressed: () =>
                                    submitSocial(SocialAuthProvider.apple),
                              ),
                              const GutterSmall(),
                              SocialAuthButton(
                                provider: SocialAuthProvider.facebook,
                                enabled: !busy.value,
                                onPressed: () =>
                                    submitSocial(SocialAuthProvider.facebook),
                              ),
                              const Spacer(),
                              const Gutter(),
                              TextButton(
                                onPressed: busy.value
                                    ? null
                                    : () => context.go(AppRoutes.home),
                                child: const Text(
                                  'Continue without an account',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
