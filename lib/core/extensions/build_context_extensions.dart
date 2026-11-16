import 'package:flutter/material.dart';
import 'package:flutter_gutter/flutter_gutter.dart';
import 'package:read_beat/app/theme.dart';

/// BuildContext helpers for theme, layout, and feedback.
extension BuildContextX on BuildContext {
  ThemeData get theme => Theme.of(this);

  TextTheme get textTheme => theme.textTheme;

  ColorScheme get colorScheme => theme.colorScheme;

  ReadBeatColors get brandColors =>
      theme.extension<ReadBeatColors>() ??
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

  MediaQueryData get mediaQuery => MediaQuery.of(this);

  Size get screenSize => mediaQuery.size;

  double get screenWidth => screenSize.width;

  double get screenHeight => screenSize.height;

  EdgeInsets get viewPadding => mediaQuery.viewPadding;

  EdgeInsets get viewInsets => mediaQuery.viewInsets;

  bool get isDark => theme.brightness == Brightness.dark;

  bool get isLight => theme.brightness == Brightness.light;

  /// Standard page inset using Material gutter margin.
  EdgeInsets get pagePadding => EdgeInsets.all(margin);

  /// Horizontal page inset with vertical breathing room.
  EdgeInsets get pagePaddingComfortable =>
      EdgeInsets.fromLTRB(margin, gutterSmall, margin, gutterLarge);

  /// Compact content padding (cards, list tiles).
  EdgeInsets get contentPadding =>
      EdgeInsets.symmetric(horizontal: gutterSmall, vertical: gutterSmall);

  void showSnackBar(
    String message, {
    bool isError = false,
    SnackBarAction? action,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(this);
    if (messenger == null) return;

    final snackTheme = theme.snackBarTheme;
    final bg = isError
        ? colorScheme.error
        : snackTheme.backgroundColor ?? colorScheme.inverseSurface;
    final fg = isError
        ? colorScheme.onError
        : snackTheme.contentTextStyle?.color ?? colorScheme.onInverseSurface;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: (snackTheme.contentTextStyle ?? textTheme.bodyMedium)
                ?.copyWith(color: fg),
          ),
          backgroundColor: bg,
          action: action,
        ),
      );
  }

  void hideCurrentSnackBar() {
    ScaffoldMessenger.maybeOf(this)?.hideCurrentSnackBar();
  }

  Future<T?> showAppDialog<T>({
    required WidgetBuilder builder,
    bool barrierDismissible = true,
  }) {
    return showDialog<T>(
      context: this,
      barrierDismissible: barrierDismissible,
      builder: builder,
    );
  }
}
