import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:read_beat/app/brand_widgets.dart';
import 'package:read_beat/app/theme.dart';
import 'package:read_beat/core/constants/app_constants.dart';
import 'package:read_beat/core/extensions/extensions.dart';
import 'package:read_beat/features/auth/presentation/controllers/auth_controller.dart';
import 'package:read_beat/features/splash/presentation/controllers/splash_gate.dart';

/// Brand-forward launch screen — atmosphere, mark, Resume Pulse edge.
class SplashScreen extends HookConsumerWidget {
  const SplashScreen({super.key});

  static const _asset = 'assets/branding/app_icon.png';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(authSessionProvider);

    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final brand = context.brandColors;

    final entrance = useAnimationController(
      duration: Duration(milliseconds: reduceMotion ? 1 : 1100),
    );
    final pulse = useAnimationController(
      duration: const Duration(milliseconds: 1600),
    );

    useEffect(() {
      var cancelled = false;

      Future<void> run() async {
        await entrance.forward();
        if (cancelled) return;
        if (!reduceMotion) {
          pulse.repeat();
        }
        await Future<void>.delayed(
          Duration(milliseconds: reduceMotion ? 120 : 420),
        );
        if (cancelled) return;
        ref.read(splashGateProvider.notifier).markReady();
      }

      run();
      return () {
        cancelled = true;
      };
    }, [reduceMotion]);

    final iconFade = CurvedAnimation(
      parent: entrance,
      curve: const Interval(0.0, 0.45, curve: Curves.easeOutCubic),
    );
    final iconScale = Tween<double>(begin: reduceMotion ? 1 : 0.86, end: 1)
        .animate(
          CurvedAnimation(
            parent: entrance,
            curve: const Interval(0.0, 0.55, curve: Curves.easeOutCubic),
          ),
        );
    final titleFade = CurvedAnimation(
      parent: entrance,
      curve: const Interval(0.32, 0.72, curve: Curves.easeOutCubic),
    );
    final titleSlide =
        Tween<Offset>(
          begin: Offset(0, reduceMotion ? 0 : 0.16),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: entrance,
            curve: const Interval(0.32, 0.78, curve: Curves.easeOutCubic),
          ),
        );
    final lineFade = CurvedAnimation(
      parent: entrance,
      curve: const Interval(0.48, 0.9, curve: Curves.easeOutCubic),
    );
    final pulseFade = CurvedAnimation(
      parent: entrance,
      curve: const Interval(0.55, 1.0, curve: Curves.easeOutCubic),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DeskAtmosphere(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              top: -80,
              left: -40,
              child: _AtmosphereOrb(
                diameter: 220,
                color: brand.primary.withValues(
                  alpha: brand.isDark ? 0.18 : 0.10,
                ),
              ),
            ),
            Positioned(
              bottom: -60,
              right: -30,
              child: _AtmosphereOrb(
                diameter: 180,
                color: brand.accent.withValues(
                  alpha: brand.isDark ? 0.12 : 0.07,
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: context.pagePadding,
                child: Column(
                  children: [
                    const Spacer(flex: 5),
                    FadeTransition(
                      opacity: iconFade,
                      child: ScaleTransition(
                        scale: iconScale,
                        child: _BrandMark(asset: _asset, brand: brand),
                      ),
                    ),
                    const SizedBox(height: 28),
                    FadeTransition(
                      opacity: titleFade,
                      child: SlideTransition(
                        position: titleSlide,
                        child: Text(
                          AppConstants.appName,
                          textAlign: TextAlign.center,
                          style: context.textTheme.displayMedium?.copyWith(
                            letterSpacing: -0.6,
                            height: 1.05,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FadeTransition(
                      opacity: lineFade,
                      child: Text(
                        'Pick up exactly where you left the page — or the beat.',
                        textAlign: TextAlign.center,
                        style: context.textTheme.bodyLarge?.copyWith(
                          color: context.colorScheme.onSurface.withValues(
                            alpha: 0.72,
                          ),
                          height: 1.35,
                        ),
                      ),
                    ),
                    const SizedBox(height: 36),
                    FadeTransition(
                      opacity: pulseFade,
                      child: _ResumePulseBar(
                        animation: reduceMotion ? null : pulse,
                        staticProgress: reduceMotion ? 0.62 : null,
                        brand: brand,
                      ),
                    ),
                    const Spacer(flex: 6),
                    FadeTransition(
                      opacity: lineFade,
                      child: Text(
                        'Local library first',
                        style: context.textTheme.labelMedium?.copyWith(
                          color: context.colorScheme.onSurface.withValues(
                            alpha: 0.45,
                          ),
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.asset, required this.brand});

  final String asset;
  final ReadBeatColors brand;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 112,
      height: 112,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.14),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: brand.primary.withValues(alpha: isDark ? 0.22 : 0.12),
            blurRadius: 36,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Image.asset(
          asset,
          width: 112,
          height: 112,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}

/// Thin Resume Pulse edge — forest → bright → orange tip.
class _ResumePulseBar extends StatelessWidget {
  const _ResumePulseBar({
    required this.brand,
    this.animation,
    this.staticProgress,
  });

  final AnimationController? animation;
  final double? staticProgress;
  final ReadBeatColors brand;

  @override
  Widget build(BuildContext context) {
    final track = brand.primaryMuted;
    final colors = [brand.primary, brand.primaryBright, brand.accent];

    Widget bar(double t) {
      final widthFactor =
          0.28 + (0.52 * (0.5 - 0.5 * math.cos(t * math.pi * 2)));
      return SizedBox(
        width: 168,
        height: 3,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: track.withValues(alpha: 0.85)),
              Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: widthFactor.clamp(0.28, 0.9),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(99),
                      gradient: LinearGradient(colors: colors),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final staticValue = staticProgress;
    if (staticValue != null || animation == null) {
      return bar(staticValue ?? 0.62);
    }

    return AnimatedBuilder(
      animation: animation!,
      builder: (context, _) => bar(animation!.value),
    );
  }
}

class _AtmosphereOrb extends StatelessWidget {
  const _AtmosphereOrb({required this.diameter, required this.color});

  final double diameter;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 48, sigmaY: 48),
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}
