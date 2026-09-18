import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_tokens.dart';
import '../../models/work_type.dart';
import '../../repositories/work_repository.dart';
import '../../shared/widgets/cover_image.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/error_view.dart';
import '../../shared/widgets/journal_card.dart';
import '../../shared/widgets/loading_view.dart';
import '../../shared/widgets/pressable.dart';
import '../../shared/widgets/rating_display.dart';
import '../../shared/widgets/recallio_page_scaffold.dart';
import '../../shared/widgets/type_badge.dart';

class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  final _searchController = TextEditingController();
  WorkType? _typeFilter;
  bool _gridView = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(workLibraryProvider);

    return RecallioPageScaffold(
      title: '作品库',
      actions: [
        IconButton(
          tooltip: _gridView ? '列表视图' : '网格视图',
          onPressed: () => setState(() => _gridView = !_gridView),
          icon: Icon(
              _gridView ? Icons.view_list_rounded : Icons.grid_view_rounded),
        ),
        IconButton(
          tooltip: '新建作品',
          onPressed: () => context.push('/works/new'),
          icon: const Icon(Icons.add),
        ),
      ],
      child: itemsAsync.when(
        loading: () => const LoadingView(),
        error: (error, stackTrace) => const ErrorView(message: '作品库加载失败'),
        data: (items) {
          final filtered = _filterItems(items);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pageHorizontal,
                  AppSpacing.sm,
                  AppSpacing.pageHorizontal,
                  0,
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    hintText: '搜索标题或评价...',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md,
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _FilterBar(
                typeFilter: _typeFilter,
                onTypeChanged: (value) => setState(() => _typeFilter = value),
              ),
              const SizedBox(height: AppSpacing.xs),
              Expanded(
                child: items.isEmpty
                    ? EmptyState(
                        title: '还没有作品记录',
                        message: '先手动新建一条记录，之后就能在这里搜索和继续编辑。',
                        action: FilledButton.icon(
                          onPressed: () => context.push('/works/new'),
                          icon: const Icon(Icons.add),
                          label: const Text('手动新建作品'),
                        ),
                      )
                    : filtered.isEmpty
                        ? const EmptyState(
                            title: '没有匹配的作品',
                            message: '换一个关键词或清除筛选条件后再试。',
                          )
                        : _gridView
                            ? _StaggeredGrid(items: filtered)
                            : _buildList(filtered),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildList(List<WorkRecordItem> items) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        AppSpacing.xs,
        AppSpacing.pageHorizontal,
        AppSpacing.xl,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) => _ListItem(
        item: items[index],
        onTap: () => context.push('/works/${items[index].work.id}'),
      ),
    );
  }

  List<WorkRecordItem> _filterItems(List<WorkRecordItem> items) {
    final keyword = _searchController.text.trim().toLowerCase();
    return items.where((item) {
      if (_typeFilter != null && item.type != _typeFilter) {
        return false;
      }
      if (keyword.isEmpty) return true;
      final haystack = [
        item.work.title,
        item.review,
      ].whereType<String>().join(' ').toLowerCase();
      return haystack.contains(keyword);
    }).toList();
  }
}

// -- Staggered grid (masonry) --
class _StaggeredGrid extends StatelessWidget {
  const _StaggeredGrid({required this.items});
  final List<WorkRecordItem> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 4
            : constraints.maxWidth >= 600
                ? 3
                : 2;
        final cols = List.generate(columns, (_) => <WorkRecordItem>[]);
        for (int i = 0; i < items.length; i++) {
          cols[i % columns].add(items[i]);
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.md,
            AppSpacing.xl,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final col in cols)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      children: [
                        for (final item in col)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _StaggeredCard(
                              item: item,
                              onTap: () =>
                                  context.push('/works/${item.work.id}'),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _StaggeredCard extends StatefulWidget {
  const _StaggeredCard({
    required this.item,
    required this.onTap,
  });

  final WorkRecordItem item;
  final VoidCallback onTap;

  @override
  State<_StaggeredCard> createState() => _StaggeredCardState();
}

class _StaggeredCardState extends State<_StaggeredCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final textTheme = Theme.of(context).textTheme;
    final hasReview = item.review?.isNotEmpty == true;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Pressable(
        onTap: widget.onTap,
        child: AspectRatio(
          aspectRatio: 2 / 3,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: AppRadius.card,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _StaggeredCover(path: item.work.coverPath),
                // Gradient overlay
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                        ],
                        stops: const [0.55, 1.0],
                      ),
                    ),
                  ),
                ),
                // Hover review overlay
                if (hasReview)
                  AnimatedOpacity(
                    opacity: _hovered ? 1.0 : 0.0,
                    duration: AppMotion.normal,
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.75),
                      padding: const EdgeInsets.all(AppSpacing.md),
                      alignment: Alignment.center,
                      child: Text(
                        item.review!,
                        maxLines: 6,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                // Title + meta at bottom
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 10,
                  child: AnimatedOpacity(
                    opacity: _hovered && hasReview ? 0.0 : 1.0,
                    duration: AppMotion.fast,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.work.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Wrap(
                          spacing: 6,
                          runSpacing: 2,
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            TypeBadge.onImage(item.type.label),
                            item.rating != null
                                ? RatingDisplay.compact(
                                    item.rating,
                                    showNumber: true,
                                    size: 12,
                                  )
                                : const RatingEmptyStar(size: 12),
                          ],
                        ),
                      ],
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

class _StaggeredCover extends StatelessWidget {
  const _StaggeredCover({required this.path});
  final String? path;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (path == null || path!.isEmpty) {
      return Container(
        color: colorScheme.surfaceContainerHighest,
        child: Center(
          child: Icon(Icons.image_outlined,
              size: 32,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.25)),
        ),
      );
    }

    return CoverImage(
      path: path,
      width: double.infinity,
      height: double.infinity,
      borderRadius: BorderRadius.zero,
    );
  }
}

// -- List item --
class _ListItem extends StatelessWidget {
  const _ListItem({required this.item, required this.onTap});
  final WorkRecordItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: JournalCard(
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CoverImage(path: item.work.coverPath, width: 90, height: 135),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.work.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      TypeBadge(item.type.label),
                      if (item.rating != null)
                        RatingDisplay.compact(item.rating),
                      if (item.recordDate != null)
                        Text(item.recordDate!,
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            )),
                    ],
                  ),
                  if (item.review?.isNotEmpty == true) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(item.review!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        )),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -- Filter bar --
class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.typeFilter, required this.onTypeChanged});

  final WorkType? typeFilter;
  final ValueChanged<WorkType?> onTypeChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pageHorizontal,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              avatar: const Icon(Icons.grid_view, size: 16),
              label: const Text('全部'),
              selected: typeFilter == null,
              onSelected: (_) => onTypeChanged(null),
              showCheckmark: false,
            ),
          ),
          for (final type in WorkType.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                avatar: Icon(_typeIcon(type), size: 16),
                label: Text(type.label),
                selected: typeFilter == type,
                onSelected: (_) => onTypeChanged(type),
                showCheckmark: false,
              ),
            ),
        ],
      ),
    );
  }
}

IconData _typeIcon(WorkType type) {
  return switch (type) {
    WorkType.anime => Icons.animation,
    WorkType.manga => Icons.menu_book,
    WorkType.novel => Icons.auto_stories,
    WorkType.game => Icons.sports_esports,
    WorkType.movie => Icons.movie,
  };
}
