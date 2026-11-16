import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gutter/flutter_gutter.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:read_beat/app/brand_widgets.dart';
import 'package:read_beat/app/icons.dart';
import 'package:read_beat/app/router.dart';
import 'package:read_beat/core/extensions/extensions.dart';
import 'package:read_beat/features/library/domain/models/library_item.dart';
import 'package:read_beat/features/library/presentation/providers/desk_home_providers.dart';
import 'package:read_beat/features/library/presentation/widgets/desk_home_widgets.dart';

class LibraryScreen extends HookConsumerWidget {
  const LibraryScreen({super.key, required this.onOpenImport});

  final VoidCallback onOpenImport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(libraryItemsProvider);
    final filter = ref.watch(shelfFilterProvider);
    final visible = ref.watch(searchedLibraryProvider);
    final query = ref.watch(librarySearchQueryProvider);
    final layout = ref.watch(libraryLayoutProvider);
    final searchController = useTextEditingController(text: query);
    final selecting = useState(false);
    final selectedIds = useState<Set<String>>(const {});
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final motion = Duration(milliseconds: reduceMotion ? 0 : 180);

    void exitSelect() {
      selecting.value = false;
      selectedIds.value = const {};
    }

    void enterSelect(String id) {
      HapticFeedback.mediumImpact();
      selecting.value = true;
      selectedIds.value = {id};
    }

    void toggleSelect(String id) {
      final next = Set<String>.from(selectedIds.value);
      if (!next.add(id)) next.remove(id);
      selectedIds.value = next;
    }

    Future<void> deleteSelected() async {
      final all = itemsAsync.asData?.value ?? const <LibraryItem>[];
      final toDelete = all
          .where((item) => selectedIds.value.contains(item.id))
          .toList(growable: false);
      if (toDelete.isEmpty) return;
      final deleted = await confirmAndDeleteLibraryItems(
        context: context,
        ref: ref,
        items: toDelete,
      );
      if (deleted) exitSelect();
    }

    return PopScope(
      canPop: !selecting.value,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && selecting.value) exitSelect();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: context.pagePaddingComfortable.copyWith(bottom: 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AnimatedSwitcher(
                      duration: motion,
                      child: selecting.value
                          ? Row(
                              key: const ValueKey('library-select-bar'),
                              children: [
                                IconButton(
                                  tooltip: 'Cancel',
                                  onPressed: exitSelect,
                                  icon: const AppIcon(AppIcons.close, size: 20),
                                ),
                                Expanded(
                                  child: Text(
                                    selectedIds.value.isEmpty
                                        ? 'Select titles'
                                        : '${selectedIds.value.length} selected',
                                    style: context.textTheme.displayMedium,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Remove',
                                  onPressed: selectedIds.value.isEmpty
                                      ? null
                                      : deleteSelected,
                                  icon: AppIcon(
                                    AppIcons.delete,
                                    size: 20,
                                    color: selectedIds.value.isEmpty
                                        ? null
                                        : context.colorScheme.error,
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              key: const ValueKey('library-title-bar'),
                              children: [
                                Expanded(
                                  child: Text(
                                    'Library',
                                    style: context.textTheme.displayMedium,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Listening queues',
                                  onPressed: () =>
                                      context.push(AppRoutes.playlists),
                                  icon: const AppIcon(
                                    AppIcons.playlist,
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                    ),
                    const GutterTiny(),
                    Text(
                      selecting.value
                          ? 'Tap more titles, then delete. Files leave this device.'
                          : 'All ebooks and audio on this device. '
                                'Long-press a title to remove it.',
                      style: context.textTheme.bodyLarge,
                    ),
                    const Gutter(),
                    TextField(
                      controller: searchController,
                      onChanged: (v) => ref
                          .read(librarySearchQueryProvider.notifier)
                          .setQuery(v),
                      decoration: DeskSearchDecoration.of(
                        hintText: 'Search titles or authors',
                        suffixIcon: query.isEmpty
                            ? null
                            : DeskSearchDecoration.clearButton(
                                onPressed: () {
                                  searchController.clear();
                                  ref
                                      .read(librarySearchQueryProvider.notifier)
                                      .setQuery('');
                                },
                              ),
                      ),
                    ),
                    const GutterSmall(),
                    Row(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ShelfFilterBar(
                              value: filter,
                              onChanged: (v) => ref
                                  .read(shelfFilterProvider.notifier)
                                  .setFilter(v),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _LibraryLayoutToggle(
                          value: layout,
                          onChanged: (next) {
                            HapticFeedback.lightImpact();
                            ref
                                .read(libraryLayoutProvider.notifier)
                                .setLayout(next);
                          },
                        ),
                      ],
                    ),
                    const Gutter(),
                  ],
                ),
              ),
              Expanded(
                child: itemsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                  data: (_) {
                    if (visible.isEmpty) {
                      if (query.trim().isNotEmpty) {
                        return Padding(
                          padding: context.pagePaddingComfortable,
                          child: Text(
                            'No titles match “${query.trim()}”.',
                            style: context.textTheme.bodyLarge,
                          ),
                        );
                      }
                      return EmptyShelfHint(onImport: onOpenImport);
                    }
                    return AnimatedSwitcher(
                      duration: motion,
                      child: layout == LibraryLayout.grid
                          ? GridView.builder(
                              key: const ValueKey('library-grid'),
                              padding: EdgeInsets.fromLTRB(
                                context.margin,
                                0,
                                context.margin,
                                24,
                              ),
                              gridDelegate: kShelfGridDelegate,
                              itemCount: visible.length,
                              itemBuilder: (context, index) {
                                final item = visible[index];
                                return _LibraryGridCell(
                                  item: item,
                                  selecting: selecting.value,
                                  selected: selectedIds.value.contains(item.id),
                                  onOpen: () => context.push(
                                    AppRoutes.libraryItem(item.id),
                                  ),
                                  onLongPress: () => enterSelect(item.id),
                                  onToggleSelect: () => toggleSelect(item.id),
                                );
                              },
                            )
                          : ListView.separated(
                              key: const ValueKey('library-list'),
                              padding: EdgeInsets.fromLTRB(
                                context.margin,
                                0,
                                context.margin,
                                24,
                              ),
                              itemCount: visible.length,
                              separatorBuilder: (_, _) => const GutterSmall(),
                              itemBuilder: (context, index) {
                                final item = visible[index];
                                final selected = selectedIds.value.contains(
                                  item.id,
                                );
                                return _LibraryTile(
                                  item: item,
                                  selecting: selecting.value,
                                  selected: selected,
                                  onOpen: () => context.push(
                                    AppRoutes.libraryItem(item.id),
                                  ),
                                  onFavorite: () => toggleFavorite(ref, item),
                                  onLongPress: () => enterSelect(item.id),
                                  onToggleSelect: () => toggleSelect(item.id),
                                );
                              },
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

class _LibraryTile extends StatelessWidget {
  const _LibraryTile({
    required this.item,
    required this.selecting,
    required this.selected,
    required this.onOpen,
    required this.onFavorite,
    required this.onLongPress,
    required this.onToggleSelect,
  });

  final LibraryItem item;
  final bool selecting;
  final bool selected;
  final VoidCallback onOpen;
  final VoidCallback onFavorite;
  final VoidCallback onLongPress;
  final VoidCallback onToggleSelect;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final motion = Duration(milliseconds: reduceMotion ? 0 : 180);

    return Semantics(
      selected: selecting ? selected : null,
      button: true,
      label:
          '${item.title}, ${_LibraryBeatMark.caption(percent: item.progressPercent, label: item.progressLabel)}',
      child: ResumePulseSurface(
        radius: 16,
        onTap: selecting ? onToggleSelect : onOpen,
        onLongPress: selecting ? null : onLongPress,
        child: AnimatedContainer(
          duration: motion,
          color: selected
              ? context.brandColors.primaryMuted.withOpacityValue(0.7)
              : Colors.transparent,
          child: Padding(
            padding: context.contentPadding,
            child: Row(
              children: [
                AnimatedSize(
                  duration: motion,
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.centerLeft,
                  child: selecting
                      ? Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: _ShelfSelectMark(selected: selected),
                        )
                      : const SizedBox.shrink(),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 48,
                    height: 64,
                    child:
                        item.coverPath != null &&
                            File(item.coverPath!).existsSync()
                        ? Image.file(
                            File(item.coverPath!),
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => ColoredBox(
                              color: context.colorScheme.primary.withValues(
                                alpha: 0.2,
                              ),
                              child: Center(
                                child: AppIcon(
                                  item.isEbook
                                      ? AppIcons.book
                                      : AppIcons.headphones,
                                  color: context.colorScheme.primary,
                                  size: 20,
                                ),
                              ),
                            ),
                          )
                        : ColoredBox(
                            color: context.colorScheme.primary.withValues(
                              alpha: 0.2,
                            ),
                            child: Center(
                              child: AppIcon(
                                item.isEbook
                                    ? AppIcons.book
                                    : AppIcons.headphones,
                                color: context.colorScheme.primary,
                                size: 20,
                              ),
                            ),
                          ),
                  ),
                ),
                const GutterSmall(),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: context.textTheme.titleMedium?.copyWith(
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        [
                          item.format.name.toUpperCase(),
                          if (item.author != null) item.author!,
                          if (item.isFavorite) 'Favorite',
                        ].join(' · '),
                        style: context.textTheme.bodyMedium,
                      ),
                      const GutterTiny(),
                      _LibraryBeatMark(
                        percent: item.progressPercent,
                        label: item.progressLabel,
                      ),
                    ],
                  ),
                ),
                if (!selecting)
                  IconButton(
                    tooltip: item.isFavorite ? 'Unfavorite' : 'Favorite',
                    visualDensity: VisualDensity.compact,
                    onPressed: onFavorite,
                    icon: AppIcon(
                      AppIcons.favorite,
                      size: 18,
                      color: item.isFavorite
                          ? context.brandColors.accent
                          : context.colorScheme.onSurface.withOpacityValue(
                              0.45,
                            ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LibraryLayoutToggle extends StatelessWidget {
  const _LibraryLayoutToggle({required this.value, required this.onChanged});

  final LibraryLayout value;
  final ValueChanged<LibraryLayout> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: context.colorScheme.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LayoutChoice(
            icon: AppIcons.listView,
            tooltip: 'List',
            selected: value == LibraryLayout.list,
            onTap: () => onChanged(LibraryLayout.list),
          ),
          _LayoutChoice(
            icon: AppIcons.gridView,
            tooltip: 'Grid',
            selected: value == LibraryLayout.grid,
            onTap: () => onChanged(LibraryLayout.grid),
          ),
        ],
      ),
    );
  }
}

class _LayoutChoice extends StatelessWidget {
  const _LayoutChoice({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  final AppIconPair icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Tooltip(
      message: tooltip,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: AnimatedContainer(
            duration: Duration(milliseconds: reduceMotion ? 0 : 180),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected
                  ? context.colorScheme.secondary
                  : Colors.transparent,
            ),
            alignment: Alignment.center,
            child: AppIcon(
              icon,
              size: 15,
              color: context.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _LibraryGridCell extends StatelessWidget {
  const _LibraryGridCell({
    required this.item,
    required this.selecting,
    required this.selected,
    required this.onOpen,
    required this.onLongPress,
    required this.onToggleSelect,
  });

  final LibraryItem item;
  final bool selecting;
  final bool selected;
  final VoidCallback onOpen;
  final VoidCallback onLongPress;
  final VoidCallback onToggleSelect;

  @override
  Widget build(BuildContext context) {
    final shelf = item.toShelfItem();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final motion = Duration(milliseconds: reduceMotion ? 0 : 180);

    return Semantics(
      selected: selecting ? selected : null,
      button: true,
      label:
          '${item.title}, ${_LibraryBeatMark.caption(percent: item.progressPercent, label: item.progressLabel)}',
      child: InkWell(
        onTap: selecting ? onToggleSelect : onOpen,
        onLongPress: selecting ? null : onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CoverThumb(
                      item: shelf,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedOpacity(
                        duration: motion,
                        opacity: selected ? 1 : 0,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: context.brandColors.primaryMuted
                                .withOpacityValue(0.55),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(12),
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.58),
                            ],
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(8, 18, 8, 8),
                          child: _LibraryBeatMark(
                            percent: item.progressPercent,
                            label: item.progressLabel,
                            compact: true,
                            onCover: true,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (item.isFavorite && !selecting)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: AppIcon(
                        AppIcons.favorite,
                        size: 14,
                        color: context.brandColors.accent,
                      ),
                    ),
                  AnimatedOpacity(
                    duration: motion,
                    opacity: selecting ? 1 : 0,
                    child: Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: _ShelfSelectMark(selected: selected),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const GutterTiny(),
            Text(
              item.title,
              style: context.textTheme.labelLarge?.copyWith(fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              item.author ?? item.format.name.toUpperCase(),
              style: context.textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _LibraryBeatMark extends StatelessWidget {
  const _LibraryBeatMark({
    required this.percent,
    this.label,
    this.compact = false,
    this.onCover = false,
  });

  final double? percent;
  final String? label;
  final bool compact;
  final bool onCover;

  static String caption({required double? percent, String? label}) {
    final p = (percent ?? 0).clamp(0.0, 1.0);
    if (p <= 0) return 'Not started';
    if (p >= 0.995) return 'Finished';
    final pct = '${(p * 100).round()}%';
    final loc = label?.trim();
    if (loc == null || loc.isEmpty || loc == pct) return pct;
    return '$loc · $pct';
  }

  @override
  Widget build(BuildContext context) {
    final p = (percent ?? 0).clamp(0.0, 1.0);
    final text = onCover && p > 0 && p < 0.995
        ? '${(p * 100).round()}%'
        : caption(percent: percent, label: onCover ? null : label);
    final style = onCover
        ? context.textTheme.labelSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          )
        : context.textTheme.bodySmall;

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          BeatProgressBar(value: p, minHeight: 3),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: BeatProgressBar(value: p, minHeight: 4)),
        const SizedBox(width: 8),
        Text(text, style: style),
      ],
    );
  }
}

class _ShelfSelectMark extends StatelessWidget {
  const _ShelfSelectMark({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final brand = context.brandColors;
    final scheme = context.colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return AnimatedContainer(
      duration: Duration(milliseconds: reduceMotion ? 0 : 180),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? brand.primary : Colors.transparent,
        border: Border.all(
          color: selected ? brand.primary : scheme.outline,
          width: 2,
        ),
      ),
      alignment: Alignment.center,
      child: selected
          ? AppIcon(AppIcons.tick, size: 10, color: scheme.onPrimary)
          : null,
    );
  }
}
