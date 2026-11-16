import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ReadBeat dual theme bound to design-system/MASTER.md.
/// Darker forest seed + orange accent; glass surfaces (no neon).
abstract final class ReadBeatTheme {
  // Light — cool bright white desk
  static const _lightBg = Color(0xFFF7FAFC);
  static const _lightAtmosphereTo = Color(0xFFF2F7F5);
  static const _lightSurface = Color(0xFFF1F5F7);
  static const _lightElevated = Color(0xFFFFFFFF);
  static const _lightText = Color(0xFF07110C);
  static const _lightSecondary = Color(0xFF5A6562);
  static const _lightBorder = Color(0xFFD7E0E3);
  static const _lightPrimary = Color(0xFF045C38);
  static const _lightPrimaryBright = Color(0xFF0A7A4A);
  static const _lightPrimaryMuted = Color(0xFFE6F1EC);
  static const _lightAccent = Color(0xFFFF6B00);
  static const _lightOnPrimary = Color(0xFFFFFFFF);

  // Dark — night desk: ocean blue → forest green atmosphere
  static const _darkBg = Color(0xFF08141C);
  static const _darkOcean = Color(0xFF071525);
  static const _darkForest = Color(0xFF071A12);
  static const _darkSurface = Color(0xFF0E1719);
  static const _darkElevated = Color(0xFF152022);
  static const _darkText = Color(0xFFF4FBF7);
  static const _darkSecondary = Color(0xFF9AADA3);
  static const _darkBorder = Color(0xFF243038);
  static const _darkPrimary = Color(0xFF1A8F5C);
  static const _darkPrimaryBright = Color(0xFF2AA86C);
  static const _darkPrimaryMuted = Color(0xFF123226);
  static const _darkAccent = Color(0xFFFF6B00);
  static const _darkOnPrimary = Color(0xFF07110C);

  static ThemeData light() => _build(
    brightness: Brightness.light,
    bg: _lightBg,
    atmosphereFrom: _lightBg,
    atmosphereTo: _lightAtmosphereTo,
    surface: _lightSurface,
    elevated: _lightElevated,
    text: _lightText,
    secondary: _lightSecondary,
    border: _lightBorder,
    primary: _lightPrimary,
    primaryBright: _lightPrimaryBright,
    primaryMuted: _lightPrimaryMuted,
    onPrimary: _lightOnPrimary,
    accent: _lightAccent,
    success: const Color(0xFF0B6B3F),
    warning: const Color(0xFFB45309),
    danger: const Color(0xFFB91C1C),
  );

  static ThemeData dark() => _build(
    brightness: Brightness.dark,
    bg: _darkBg,
    atmosphereFrom: _darkOcean,
    atmosphereTo: _darkForest,
    surface: _darkSurface,
    elevated: _darkElevated,
    text: _darkText,
    secondary: _darkSecondary,
    border: _darkBorder,
    primary: _darkPrimary,
    primaryBright: _darkPrimaryBright,
    primaryMuted: _darkPrimaryMuted,
    onPrimary: _darkOnPrimary,
    accent: _darkAccent,
    success: const Color(0xFF2AA86C),
    warning: const Color(0xFFFBBF24),
    danger: const Color(0xFFFF6B6B),
  );

  static ThemeData _build({
    required Brightness brightness,
    required Color bg,
    required Color atmosphereFrom,
    required Color atmosphereTo,
    required Color surface,
    required Color elevated,
    required Color text,
    required Color secondary,
    required Color border,
    required Color primary,
    required Color primaryBright,
    required Color primaryMuted,
    required Color onPrimary,
    required Color accent,
    required Color success,
    required Color warning,
    required Color danger,
  }) {
    final base = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: onPrimary,
      secondary: primaryMuted,
      onSecondary: text,
      tertiary: accent,
      onTertiary: Colors.white,
      error: danger,
      onError: Colors.white,
      surface: surface,
      onSurface: text,
    );

    final textTheme = _textTheme(text, secondary);
    final brand = ReadBeatColors(
      warning: warning,
      accent: accent,
      success: success,
      primary: primary,
      primaryBright: primaryBright,
      primaryMuted: primaryMuted,
      bg: bg,
      atmosphereFrom: atmosphereFrom,
      atmosphereTo: atmosphereTo,
      isDark: brightness == Brightness.dark,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: base.copyWith(
        surfaceContainerHighest: elevated,
        outline: border,
        tertiaryContainer: success,
      ),
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      cardColor: elevated,
      dividerColor: border,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: text,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
        height: 56,
        indicatorColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: onPrimary, size: 24);
          }
          return IconThemeData(color: text.withValues(alpha: 0.62), size: 22);
        }),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        shape: const StadiumBorder(),
        extendedPadding: const EdgeInsets.symmetric(horizontal: 16),
        extendedIconLabelSpacing: 8,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          minimumSize: const Size(64, 36),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 13),
          shape: const StadiumBorder(),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: text,
          minimumSize: const Size(64, 36),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 13),
          side: BorderSide(color: border),
          shape: const StadiumBorder(),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size(40, 32),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 13),
          shape: const StadiumBorder(),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          minimumSize: const Size(64, 36),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 13),
          elevation: 0,
          shape: const StadiumBorder(),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: elevated,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide(color: danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide(color: danger, width: 1.5),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: brightness == Brightness.light
            ? const Color(0xFF0E1714)
            : const Color(0xFFF4FBF7),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: brightness == Brightness.light
              ? const Color(0xFFF4FBF7)
              : const Color(0xFF07110C),
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        actionTextColor: accent,
        disabledActionTextColor: secondary,
        behavior: SnackBarBehavior.floating,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          ),
          textStyle: WidgetStatePropertyAll(
            textTheme.labelLarge?.copyWith(fontSize: 12),
          ),
          shape: const WidgetStatePropertyAll(StadiumBorder()),
        ),
      ),
      extensions: <ThemeExtension<dynamic>>[brand],
    );
  }

  static TextTheme _textTheme(Color primary, Color secondary) {
    final display = GoogleFonts.fraunces(color: primary);
    final body = GoogleFonts.manrope(color: primary);
    return TextTheme(
      displayLarge: display.copyWith(
        fontSize: 40,
        fontWeight: FontWeight.w600,
        height: 1.1,
      ),
      displayMedium: display.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        height: 1.15,
      ),
      titleLarge: body.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 1.25,
      ),
      titleMedium: body.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
      bodyLarge: body.copyWith(fontSize: 16, height: 1.5),
      bodyMedium: body.copyWith(fontSize: 14, height: 1.45, color: secondary),
      bodySmall: body.copyWith(fontSize: 13, height: 1.4, color: secondary),
      labelLarge: body.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
    );
  }
}

/// Extra brand colors + glass / gradient helpers beyond [ColorScheme].
@immutable
final class ReadBeatColors extends ThemeExtension<ReadBeatColors> {
  const ReadBeatColors({
    required this.warning,
    required this.accent,
    required this.success,
    required this.primary,
    required this.primaryBright,
    required this.primaryMuted,
    required this.bg,
    required this.atmosphereFrom,
    required this.atmosphereTo,
    required this.isDark,
  });

  final Color warning;
  final Color accent;
  final Color success;
  final Color primary;
  final Color primaryBright;
  final Color primaryMuted;
  final Color bg;
  final Color atmosphereFrom;
  final Color atmosphereTo;
  final bool isDark;

  /// Soft desk wash — multi-stop lerp for a very smooth transition.
  LinearGradient get atmosphere {
    const steps = 6;
    final colors = <Color>[
      for (var i = 0; i <= steps; i++)
        Color.lerp(atmosphereFrom, atmosphereTo, i / steps)!,
    ];
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: colors,
    );
  }

  /// Primary CTA fill: forest → brighter forest (no neon).
  LinearGradient get brandFill => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryBright],
  );

  /// Resume Pulse strip: forest → bright → orange tip.
  LinearGradient get pulseEdge => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [primary, primaryBright, accent],
    stops: const [0.0, 0.72, 1.0],
  );

  /// Progress bar along the reading direction.
  LinearGradient get progressTrail => LinearGradient(
    colors: [primary, primaryBright, accent],
    stops: const [0.0, 0.78, 1.0],
  );

  /// Translucent glass fill.
  Color get glassFill => isDark
      ? const Color(0xFFFFFFFF).withValues(alpha: 0.08)
      : const Color(0xFFFFFFFF).withValues(alpha: 0.58);

  /// Frosted highlight edge.
  Color get glassBorder => isDark
      ? const Color(0xFFFFFFFF).withValues(alpha: 0.16)
      : const Color(0xFFFFFFFF).withValues(alpha: 0.78);

  /// Soft lift under glass panels (no neon).
  List<BoxShadow> get glassShadow => [
    BoxShadow(
      color: isDark ? const Color(0x66000000) : const Color(0x1A07110C),
      blurRadius: isDark ? 20 : 24,
      offset: const Offset(0, 10),
    ),
  ];

  double get glassBlurSigma => 22;

  @override
  ReadBeatColors copyWith({
    Color? warning,
    Color? accent,
    Color? success,
    Color? primary,
    Color? primaryBright,
    Color? primaryMuted,
    Color? bg,
    Color? atmosphereFrom,
    Color? atmosphereTo,
    bool? isDark,
  }) {
    return ReadBeatColors(
      warning: warning ?? this.warning,
      accent: accent ?? this.accent,
      success: success ?? this.success,
      primary: primary ?? this.primary,
      primaryBright: primaryBright ?? this.primaryBright,
      primaryMuted: primaryMuted ?? this.primaryMuted,
      bg: bg ?? this.bg,
      atmosphereFrom: atmosphereFrom ?? this.atmosphereFrom,
      atmosphereTo: atmosphereTo ?? this.atmosphereTo,
      isDark: isDark ?? this.isDark,
    );
  }

  @override
  ReadBeatColors lerp(ThemeExtension<ReadBeatColors>? other, double t) {
    if (other is! ReadBeatColors) return this;
    return ReadBeatColors(
      warning: Color.lerp(warning, other.warning, t) ?? warning,
      accent: Color.lerp(accent, other.accent, t) ?? accent,
      success: Color.lerp(success, other.success, t) ?? success,
      primary: Color.lerp(primary, other.primary, t) ?? primary,
      primaryBright:
          Color.lerp(primaryBright, other.primaryBright, t) ?? primaryBright,
      primaryMuted:
          Color.lerp(primaryMuted, other.primaryMuted, t) ?? primaryMuted,
      bg: Color.lerp(bg, other.bg, t) ?? bg,
      atmosphereFrom:
          Color.lerp(atmosphereFrom, other.atmosphereFrom, t) ?? atmosphereFrom,
      atmosphereTo:
          Color.lerp(atmosphereTo, other.atmosphereTo, t) ?? atmosphereTo,
      isDark: t < 0.5 ? isDark : other.isDark,
    );
  }
}

/// Frosted glass panel (blur + translucent fill + highlight border).
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.borderRadius = 20,
    this.padding,
    this.onTap,
    this.onLongPress,
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final brand =
        Theme.of(context).extension<ReadBeatColors>() ??
        const ReadBeatColors(
          warning: Color(0xFFB45309),
          accent: Color(0xFFFF6B00),
          success: Color(0xFF0B6B3F),
          primary: Color(0xFF045C38),
          primaryBright: Color(0xFF0A7A4A),
          primaryMuted: Color(0xFFE6F1EC),
          bg: Color(0xFFF7FAFC),
          atmosphereFrom: Color(0xFFF7FAFC),
          atmosphereTo: Color(0xFFF2F7F5),
          isDark: false,
        );
    final radius = BorderRadius.circular(borderRadius);

    final content = padding == null
        ? child
        : Padding(padding: padding!, child: child);

    // Material must sit *inside* the glass fill. Otherwise ListTile/SwitchListTile
    // ink paints on a Material behind the DecoratedBox and Flutter asserts.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: brand.glassShadow,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: brand.glassBlurSigma,
            sigmaY: brand.glassBlurSigma,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              color: brand.glassFill,
              border: Border.all(color: brand.glassBorder),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  brand.glassFill,
                  brand.glassFill.withValues(alpha: brand.glassFill.a * 0.72),
                ],
              ),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: onTap == null && onLongPress == null
                  ? content
                  : InkWell(
                      onTap: onTap,
                      onLongPress: onLongPress,
                      borderRadius: radius,
                      child: content,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
