import 'package:flutter/material.dart';
import 'package:flutter_gutter/flutter_gutter.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:read_beat/app/brand_widgets.dart';
import 'package:read_beat/app/icons.dart';
import 'package:read_beat/app/theme.dart';
import 'package:read_beat/core/extensions/extensions.dart';
import 'package:read_beat/features/importer/presentation/controllers/import_controller.dart';

/// Persistent top status strip while imports run (and briefly after).
class ImportStatusBanner extends ConsumerWidget {
  const ImportStatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(importStatusProvider);
    if (!status.showsBanner) return const SizedBox.shrink();

    final brand = context.brandColors;
    final isError = status.phase == ImportPhase.failed;
    final isDone = status.phase == ImportPhase.completed;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: GlassPanel(
        borderRadius: 999,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _StatusGlyph(
                    isError: isError,
                    isDone: isDone,
                    isActive: status.isActive,
                  ),
                  const GutterSmall(),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          status.statusLabel,
                          style: context.textTheme.labelLarge?.copyWith(
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (status.fileName != null &&
                            status.phase == ImportPhase.importing) ...[
                          const SizedBox(height: 2),
                          Text(
                            status.fileName!,
                            style: context.textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (!status.isActive)
                    IconButton(
                      tooltip: 'Dismiss',
                      visualDensity: VisualDensity.compact,
                      onPressed: () =>
                          ref.read(importStatusProvider.notifier).dismiss(),
                      icon: const AppIcon(AppIcons.close, size: 18),
                    ),
                ],
              ),
              if (status.isActive) ...[
                const SizedBox(height: 8),
                BeatProgressBar(
                  value: status.progress <= 0 ? 0.08 : status.progress,
                  minHeight: 3,
                ),
              ] else if (isDone) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: SizedBox(
                    height: 3,
                    child: ColoredBox(color: brand.success),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusGlyph extends StatelessWidget {
  const _StatusGlyph({
    required this.isError,
    required this.isDone,
    required this.isActive,
  });

  final bool isError;
  final bool isDone;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    if (isActive) {
      return SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2.2,
          color: context.brandColors.primary,
        ),
      );
    }
    if (isError) {
      return AppIcon(
        AppIcons.error,
        size: 20,
        color: context.colorScheme.error,
      );
    }
    return AppIcon(
      AppIcons.check,
      active: true,
      size: 20,
      color: context.brandColors.success,
    );
  }
}

/// Thin edge-to-edge progress under the system status bar while importing.
class ImportStatusHairline extends ConsumerWidget {
  const ImportStatusHairline({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(importStatusProvider);
    if (!status.isActive) return const SizedBox.shrink();

    final top = MediaQuery.paddingOf(context).top;
    return Positioned(
      top: top > 0 ? top - 2.5 : 0,
      left: 0,
      right: 0,
      child: BeatProgressBar(
        value: status.progress <= 0 ? 0.08 : status.progress,
        minHeight: 2.5,
      ),
    );
  }
}
