import 'package:flutter/material.dart';
import 'package:flutter_gutter/flutter_gutter.dart';
import 'package:read_beat/app/icons.dart';
import 'package:read_beat/core/extensions/extensions.dart';
import 'package:read_beat/features/auth/domain/models/social_auth_provider.dart';

/// Outlined social sign-in row (Google / Apple / Facebook).
class SocialAuthButton extends StatelessWidget {
  const SocialAuthButton({
    super.key,
    required this.provider,
    required this.onPressed,
    this.enabled = true,
  });

  final SocialAuthProvider provider;
  final VoidCallback? onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final label = switch (provider) {
      SocialAuthProvider.google => 'Continue with Google',
      SocialAuthProvider.apple => 'Continue with Apple',
      SocialAuthProvider.facebook => 'Continue with Facebook',
    };

    return SizedBox(
      width: double.infinity,
      height: 36,
      child: OutlinedButton(
        onPressed: enabled ? onPressed : null,
        style: OutlinedButton.styleFrom(
          foregroundColor: context.colorScheme.onSurface,
          side: BorderSide(color: context.colorScheme.outline),
          backgroundColor: context.colorScheme.surfaceContainerHighest,
          minimumSize: const Size(64, 36),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: context.textTheme.labelLarge?.copyWith(fontSize: 13),
          shape: const StadiumBorder(),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ProviderMark(provider: provider),
            const GutterSmall(),
            Text(
              label,
              style: context.textTheme.labelLarge?.copyWith(fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProviderMark extends StatelessWidget {
  const _ProviderMark({required this.provider});

  final SocialAuthProvider provider;

  @override
  Widget build(BuildContext context) {
    final (letter, color) = switch (provider) {
      SocialAuthProvider.google => ('G', const Color(0xFF4285F4)),
      SocialAuthProvider.apple => (
        '',
        context.isDark ? Colors.white : Colors.black,
      ),
      SocialAuthProvider.facebook => ('f', const Color(0xFF1877F2)),
    };

    if (provider == SocialAuthProvider.apple) {
      return AppIcon(AppIcons.apple, active: true, size: 22, color: color);
    }

    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withOpacityValue(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        letter,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 14,
          height: 1,
        ),
      ),
    );
  }
}
