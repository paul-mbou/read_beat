import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:read_beat/app/di.dart';

/// Persisted appearance: system / light / dark.
final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

final class ThemeModeController extends Notifier<ThemeMode> {
  static const _storageKey = 'readbeat_theme_mode';

  @override
  ThemeMode build() {
    Future<void>.microtask(_hydrate);
    return ThemeMode.system;
  }

  Future<void> _hydrate() async {
    final raw = await ref.read(secureStorageProvider).read(_storageKey);
    if (raw == null || !ref.mounted) return;
    final mode = ThemeMode.values.where((m) => m.name == raw).firstOrNull;
    if (mode != null) state = mode;
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    await ref.read(secureStorageProvider).write(_storageKey, mode.name);
  }
}
