import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_gutter/flutter_gutter.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:read_beat/app/brand_widgets.dart';
import 'package:read_beat/app/icons.dart';
import 'package:read_beat/app/theme.dart';
import 'package:read_beat/core/extensions/extensions.dart';
import 'package:read_beat/features/library/domain/models/media_catalog_entry.dart';
import 'package:read_beat/features/library/domain/models/shelf_item.dart';
import 'package:read_beat/features/library/presentation/providers/desk_home_providers.dart';

/// 3-column desk shelf used on Library grid.
const kShelfGridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
  crossAxisCount: 3,
  mainAxisSpacing: 16,
  crossAxisSpacing: 12,
  childAspectRatio: 0.62,
);

/// Home preview: exactly one row, three cover slots.
class HomeShelfRow extends StatelessWidget {
  const HomeShelfRow({
    super.key,
    required this.items,
    required this.onOpen,
    this.maxItems = 3,
  });

  final List<ShelfItem> items;
  final ValueChanged<ShelfItem> onOpen;
  final int maxItems;

  static const _spacing = 12.0;
  static const _aspect = 0.62;

  @override
  Widget build(BuildContext context) {
    final visible = items.take(maxItems).toList(growable: false);
    if (visible.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth =
            (constraints.maxWidth - _spacing * (maxItems - 1)) / maxItems;
        final cellHeight = cellWidth / _aspect;

        return SizedBox(
          height: cellHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < visible.length; i++) ...[
                if (i > 0) const SizedBox(width: _spacing),
                SizedBox(
                  width: cellWidth,
                  child: ShelfCover(
                    item: visible[i],
                    onTap: () => onOpen(visible[i]),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Glass surface + left Resume Pulse edge.
class ResumePulseSurface extends StatelessWidget {
  const ResumePulseSurface({
    super.key,
    required this.child,
    this.radius = 20,
    this.edgeWidth = 4,
    this.onTap,
    this.onLongPress,
    this.elevation = 0,
  });

  final Widget child;
  final double radius;
  final double edgeWidth;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double elevation;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      borderRadius: radius,
      onTap: onTap,
      onLongPress: onLongPress,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PulseEdgeBar(width: edgeWidth),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

/// Dominant Continue module with Resume Pulse edge.
class ContinueModule extends HookWidget {
  const ContinueModule({super.key, required this.item, required this.onResume});

  final ShelfItem item;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final highlight = useState(false);
    useEffect(() {
      if (reduceMotion) return null;
      highlight.value = true;
      final timer = Future<void>.delayed(const Duration(milliseconds: 420), () {
        highlight.value = false;
      });
      return () {
        // ignore: discarded_futures
        timer;
      };
    }, const []);

    return ResumePulseSurface(
      radius: 20,
      elevation: context.isLight ? 1 : 0,
      edgeWidth: highlight.value ? 5 : 4,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CoverThumb(item: item, width: 72, height: 96),
                const Gutter(),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Continue', style: context.textTheme.bodySmall),
                      const GutterTiny(),
                      Text(
                        item.title,
                        style: context.textTheme.titleLarge,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const GutterTiny(),
                      Text(
                        item.positionLabel ?? item.subtitle,
                        style: context.textTheme.bodyMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Gutter(),
            BeatProgressBar(value: item.progress),
            const Gutter(),
            BrandGradientButton(
              onPressed: onResume,
              child: Text(item.resumeLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class EmptyContinueCard extends StatelessWidget {
  const EmptyContinueCard({super.key, required this.onImport});

  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return ResumePulseSurface(
      radius: 20,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Your desk is clear', style: context.textTheme.titleLarge),
            const GutterTiny(),
            Text(
              'Import an ebook or track to start. Progress stays on this device until you sync.',
              style: context.textTheme.bodyLarge,
            ),
            const Gutter(),
            BrandGradientButton(
              onPressed: onImport,
              child: const Text('Import your first file'),
            ),
          ],
        ),
      ),
    );
  }
}

class ShelfFilterBar extends StatelessWidget {
  const ShelfFilterBar({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final ShelfFilter value;
  final ValueChanged<ShelfFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<ShelfFilter>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(value: ShelfFilter.all, label: Text('All')),
        ButtonSegment(value: ShelfFilter.reading, label: Text('Reading')),
        ButtonSegment(value: ShelfFilter.listening, label: Text('Listening')),
        ButtonSegment(value: ShelfFilter.favorites, label: Text('Favs')),
      ],
      selected: {value},
      onSelectionChanged: (set) => onChanged(set.first),
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        ),
        shape: const WidgetStatePropertyAll(StadiumBorder()),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return context.colorScheme.secondary;
          }
          return context.colorScheme.surfaceContainerHighest;
        }),
        foregroundColor: WidgetStatePropertyAll(context.colorScheme.onSurface),
        side: WidgetStatePropertyAll(
          BorderSide(color: context.colorScheme.outline),
        ),
      ),
    );
  }
}

class ShelfCover extends StatelessWidget {
  const ShelfCover({super.key, required this.item, required this.onTap});

  final ShelfItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: CoverThumb(
              item: item,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
          const GutterTiny(),
          Text(
            item.title,
            style: context.textTheme.labelLarge,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            item.isEbook ? 'Ebook' : 'Audio',
            style: context.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class CoverThumb extends StatelessWidget {
  const CoverThumb({
    super.key,
    required this.item,
    required this.width,
    required this.height,
  });

  final ShelfItem item;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final base = Color(item.coverColorValue ?? 0xFF0F766E);
    final coverFile = item.coverPath == null ? null : File(item.coverPath!);
    final hasCover = coverFile != null && coverFile.existsSync();

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: width == double.infinity ? null : width,
        height: height == double.infinity ? null : height,
        decoration: BoxDecoration(
          border: Border.all(
            color: context.colorScheme.outline.withOpacityValue(0.35),
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: context.isLight
              ? const [
                  BoxShadow(
                    color: Color(0x14121820),
                    blurRadius: 16,
                    offset: Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: hasCover
            ? Image.file(
                coverFile,
                fit: BoxFit.cover,
                width: width == double.infinity ? null : width,
                height: height == double.infinity ? null : height,
                errorBuilder: (_, _, _) => _FallbackCover(
                  base: base,
                  isEbook: item.isEbook,
                  surface: context.colorScheme.surface,
                ),
              )
            : _FallbackCover(
                base: base,
                isEbook: item.isEbook,
                surface: context.colorScheme.surface,
              ),
      ),
    );
  }
}

class _FallbackCover extends StatelessWidget {
  const _FallbackCover({
    required this.base,
    required this.isEbook,
    required this.surface,
  });

  final Color base;
  final bool isEbook;
  final Color surface;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.bottomLeft,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            base.withOpacityValue(0.92),
            base.withOpacityValue(0.55),
            surface.withOpacityValue(0.35),
          ],
        ),
      ),
      child: AppIcon(
        isEbook ? AppIcons.book : AppIcons.headphones,
        size: 22,
        color: Colors.white.withOpacityValue(0.9),
      ),
    );
  }
}

class EmptyShelfHint extends StatelessWidget {
  const EmptyShelfHint({super.key, required this.onImport});

  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Text(
            'Nothing on this shelf yet',
            style: context.textTheme.titleMedium,
          ),
          const GutterTiny(),
          Text(
            'Imported ebooks and audio will appear here.',
            style: context.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const Gutter(),
          OutlinedButton(
            onPressed: onImport,
            child: const Text('Import files'),
          ),
        ],
      ),
    );
  }
}

/// Cloud resumes whose files are not on this device yet.
class OrphanResumesSection extends StatelessWidget {
  const OrphanResumesSection({
    super.key,
    required this.orphans,
    required this.onImport,
  });

  final List<MediaCatalogEntry> orphans;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    if (orphans.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Resumes waiting for a file',
          style: context.textTheme.titleMedium,
        ),
        const GutterTiny(),
        Text(
          'Your position is synced. Import the matching file, '
          'or open a library item to link a close match.',
          style: context.textTheme.bodyMedium,
        ),
        const GutterSmall(),
        ...orphans.take(5).map((o) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GlassPanel(
              borderRadius: 14,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                title: Text(
                  o.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  [
                    o.author,
                    o.format.name.toUpperCase(),
                    'not on this device',
                  ].whereType<String>().join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: TextButton(
                  onPressed: onImport,
                  child: const Text('Import'),
                ),
              ),
            ),
          );
        }),
        if (orphans.length > 5)
          Text(
            '+${orphans.length - 5} more',
            style: context.textTheme.bodySmall,
          ),
      ],
    );
  }
}

/// Floating glass mini-player pill with Resume Pulse edge (audio only).
class MiniPlayerBar extends StatelessWidget {
  const MiniPlayerBar({
    super.key,
    required this.item,
    required this.onPause,
    required this.onOpen,
  });

  final ShelfItem item;
  final VoidCallback onPause;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      borderRadius: 999,
      onTap: onOpen,
      child: IntrinsicHeight(
        child: Row(
          children: [
            const PulseEdgeBar(width: 4),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    CoverThumb(item: item, width: 40, height: 40),
                    const GutterSmall(),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            item.title,
                            style: context.textTheme.labelLarge,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            item.positionLabel ?? 'Now playing',
                            style: context.textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Pause',
                      onPressed: onPause,
                      icon: const AppIcon(AppIcons.pause, active: true),
                    ),
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
