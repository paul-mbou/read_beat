import 'dart:io';

import 'package:flutter/material.dart';
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
import 'package:read_beat/features/search/domain/local_search.dart';

class SearchScreen extends HookConsumerWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = useTextEditingController();
    final query = useState('');
    final items =
        ref.watch(libraryItemsProvider).asData?.value ?? const <LibraryItem>[];
    final hits = LocalSearch.query(items, query.value);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Search')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: context.pagePaddingComfortable.copyWith(top: 8, bottom: 0),
            child: TextField(
              controller: controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: (v) => query.value = v,
              decoration: DeskSearchDecoration.of(
                hintText: 'Title, author, or format',
                suffixIcon: query.value.isEmpty
                    ? null
                    : DeskSearchDecoration.clearButton(
                        onPressed: () {
                          controller.clear();
                          query.value = '';
                        },
                      ),
              ),
            ),
          ),
          const GutterSmall(),
          Expanded(
            child: items.isEmpty
                ? EmptyShelfHint(onImport: () => context.go(AppRoutes.home))
                : hits.isEmpty
                ? Padding(
                    padding: context.pagePaddingComfortable,
                    child: Text(
                      query.value.trim().isEmpty
                          ? 'Type a title, author, or format like EPUB or MP3.'
                          : 'No titles match “${query.value.trim()}”.',
                      style: context.textTheme.bodyLarge,
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.fromLTRB(
                      context.margin,
                      0,
                      context.margin,
                      24,
                    ),
                    itemCount: hits.length,
                    separatorBuilder: (_, _) => const GutterSmall(),
                    itemBuilder: (context, index) {
                      final item = hits[index];
                      return ResumePulseSurface(
                        radius: 16,
                        onTap: () =>
                            context.push(AppRoutes.libraryItem(item.id)),
                        child: Padding(
                          padding: context.contentPadding,
                          child: Row(
                            children: [
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
                                        )
                                      : ColoredBox(
                                          color: context.colorScheme.primary
                                              .withValues(alpha: 0.2),
                                          child: Center(
                                            child: AppIcon(
                                              item.isEbook
                                                  ? AppIcons.book
                                                  : AppIcons.headphones,
                                              color:
                                                  context.colorScheme.primary,
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
                                      style: context.textTheme.titleMedium,
                                    ),
                                    Text(
                                      [
                                        item.format.name.toUpperCase(),
                                        if (item.author != null) item.author!,
                                        if (item.isFavorite) 'Favorite',
                                      ].join(' · '),
                                      style: context.textTheme.bodyMedium,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
