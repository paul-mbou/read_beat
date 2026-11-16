import 'package:flutter/material.dart';
import 'package:flutter_gutter/flutter_gutter.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:read_beat/app/brand_widgets.dart';
import 'package:read_beat/core/extensions/extensions.dart';
import 'package:read_beat/features/importer/presentation/controllers/import_controller.dart';

class ImportScreen extends ConsumerWidget {
  const ImportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(importStatusProvider);
    final busy = status.isActive;

    Future<void> pick() async {
      if (busy) return;
      final result = await ref.read(importStatusProvider.notifier).startImport();
      if (!context.mounted) return;
      result.fold(
        onSuccess: (items) {
          if (items.isEmpty) {
            // Cancelled picker — silent.
            return;
          }
          context.showSnackBar(
            items.length == 1
                ? 'Imported “${items.first.title}”'
                : 'Imported ${items.length} files',
          );
        },
        onFailure: (e) => context.showSnackBar(e.message, isError: true),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: ListView(
          padding: context.pagePaddingComfortable,
          children: [
            Text('Import', style: context.textTheme.displayMedium),
            const GutterTiny(),
            Text(
              'Bring EPUB, PDF, MP3, or M4A into your local library. '
              'Files are copied into the app and hashed so duplicates are skipped. '
              'You can keep browsing while import runs — watch the status strip at the top.',
              style: context.textTheme.bodyLarge,
            ),
            const GutterLarge(),
            BrandGradientButton(
              onPressed: busy ? null : pick,
              child: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Choose files'),
            ),
            const Gutter(),
            Text(
              'Supported: .epub · .pdf · .mp3 · .m4a',
              style: context.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
