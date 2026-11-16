import 'package:flutter/painting.dart';

/// Convenience helpers on [String].
extension StringX on String {
  bool get isBlank => trim().isEmpty;

  bool get isNotBlank => !isBlank;

  String get capitalized {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}

/// Nullable string helpers.
extension NullableStringX on String? {
  bool get isNullOrBlank => this == null || this!.trim().isEmpty;

  String orEmpty() => this ?? '';
}

/// [DateTime] helpers used by progress / sync.
extension DateTimeX on DateTime {
  DateTime get asUtc => isUtc ? this : toUtc();

  bool isAfterOrEqual(DateTime other) => !isBefore(other);
}

/// Collection helpers.
extension IterableX<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;

  T? get lastOrNull => isEmpty ? null : last;
}

/// Color alpha helper without deprecated withOpacity.
extension ColorX on Color {
  Color withOpacityValue(double opacity) =>
      withValues(alpha: opacity.clamp(0.0, 1.0));
}
