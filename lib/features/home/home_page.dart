import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../repositories/work_repository.dart';
import '../../shared/widgets/cover_image.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/error_view.dart';
import '../../shared/widgets/journal_card.dart';
import '../../shared/widgets/loading_view.dart';
import '../../shared/widgets/rating_display.dart';
import '../../shared/widgets/recallio_page_scaffold.dart';
import '../../shared/widgets/type_badge.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(workLibraryProvider);

    return RecallioPageScaffold(
      title: AppConstants.displayName,
      titleWidget: const _BrandTitle(),
      child: itemsAsync.when(
        loading: () => const LoadingView(),
        error: (error, stackTrace) => const ErrorView(message: '首页数据加载失败'),
        data: (items) {
          final recent = items.take(6).toList();

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(workLibraryProvider);
              await ref.read(workLibraryProvider.future);
            },
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 680;
                return ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pageHorizontal,
                    AppSpacing.sm,
                    AppSpacing.pageHorizontal,
                    AppSpacing.xl,
                  ),
                  children: [
                    if (wide)
                      _WideTopSection(items: items)
                    else ...[
                      _JournalHeader(itemCount: items.length),
                      const SizedBox(height: AppSpacing.xl),
                      _ActionButtons(),
                      const SizedBox(height: AppSpacing.xl),
                      _MemoStats(items: items),
                    ],
                    const SizedBox(height: AppSpacing.xl + AppSpacing.xs),
                    // -- Recent timeline --
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('最近更新', style: Theme.of(context).textTheme.titleLarge),
                        if (items.isNotEmpty)
                          TextButton(
                            onPressed: () => context.go('/library'),
                            child: const Text('查看全部'),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (recent.isEmpty)
                      EmptyState(
                        title: '还没有记录',
                        message: '新建第一条作品后，这里会显示最近更新。',
                      )
                    else
                      _Timeline(items: recent),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// -- Brand title for AppBar --
class _BrandTitle extends StatelessWidget {
  const _BrandTitle();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.auto_stories, size: 18, color: Colors.white),
        ),
        const SizedBox(width: 10),
        Text(
          AppConstants.displayName,
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppTheme.primary,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}

// -- Desktop: header + horizontal actions + full-width memo --
class _WideTopSection extends StatelessWidget {
  const _WideTopSection({required this.items});
  final List<WorkRecordItem> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _JournalHeader(itemCount: items.length),
          const SizedBox(height: AppSpacing.xl + AppSpacing.xs),
          // Action buttons — horizontal row
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => context.push('/works/new'),
                  icon: const Icon(Icons.edit_note, size: 18),
                  label: const Text('新建记录'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.go('/library'),
                  icon: const Icon(Icons.collections_bookmark_outlined, size: 16),
                  label: const Text('作品库'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.go('/backup'),
                  icon: const Icon(Icons.archive_outlined, size: 16),
                  label: const Text('备份'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          // Memo — full-width, 1 row of 4 stats
          _MemoStats(items: items),
        ],
      ),
    );
  }
}

// -- Action buttons, stacked vertically --
class _ActionButtons extends StatelessWidget {
  const _ActionButtons();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: () => context.push('/works/new'),
          icon: const Icon(Icons.edit_note, size: 20),
          label: const Text('新建记录'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => context.go('/library'),
          icon: const Icon(Icons.collections_bookmark_outlined, size: 18),
          label: const Text('作品库'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => context.go('/backup'),
          icon: const Icon(Icons.archive_outlined, size: 18),
          label: const Text('备份与恢复'),
        ),
      ],
    );
  }
}

// -- Journal header --
class _JournalHeader extends StatelessWidget {
  const _JournalHeader({required this.itemCount});
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    final dateStr = '${now.month}月${now.day}日 · 星期${weekdays[now.weekday - 1]}';
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date
          Text(
            dateStr,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              letterSpacing: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          // Main title
          Text('我的记录', style: textTheme.displayMedium),
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 3,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          // Count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '收录 $itemCount 部作品',
              style: textTheme.labelMedium?.copyWith(
                color: AppTheme.primary.withValues(alpha: 0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -- Memo-style stats --
class _MemoStats extends StatelessWidget {
  const _MemoStats({required this.items});
  final List<WorkRecordItem> items;

  @override
  Widget build(BuildContext context) {
    final ratedCount = items.where((item) => item.rating != null).length;
    final reviewedCount =
        items.where((item) => item.review?.isNotEmpty == true).length;
    final unratedCount = items.where((item) => item.rating == null).length;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: colorScheme.brightness == Brightness.light
            ? const Color(0xFFFFF9F0)
            : const Color(0xFF28232A),
        borderRadius: AppRadius.card,
        border: Border(
          left: BorderSide(
            color: AppTheme.primary.withValues(alpha: 0.5),
            width: 3,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.push_pin_outlined, size: 14,
              color: AppTheme.primary.withValues(alpha: 0.5)),
          const SizedBox(width: 8),
          Expanded(child: _MemoCell(value: '${items.length}', label: '全部')),
          Expanded(child: _MemoCell(value: '$ratedCount', label: '已评分')),
          Expanded(child: _MemoCell(value: '$reviewedCount', label: '有评价')),
          Expanded(child: _MemoCell(value: '$unratedCount', label: '未评分')),
        ],
      ),
    );
  }
}

class _MemoCell extends StatelessWidget {
  const _MemoCell({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

// -- Timeline --
class _Timeline extends StatelessWidget {
  const _Timeline({required this.items});
  final List<WorkRecordItem> items;

  @override
  Widget build(BuildContext context) {
    final groups = <_DateGroup>[];
    for (final item in items) {
      final date = item.lastModifiedDate ?? '';
      if (groups.isNotEmpty && groups.last.date == date) {
        groups.last.items.add(item);
      } else {
        groups.add(_DateGroup(date: date, items: [item]));
      }
    }

    return Column(
      children: [
        for (int g = 0; g < groups.length; g++)
          ...groups[g].buildEntries(context, isLastGroup: g == groups.length - 1),
      ],
    );
  }
}

class _DateGroup {
  _DateGroup({required this.date, required this.items});
  final String date;
  final List<WorkRecordItem> items;

  List<Widget> buildEntries(BuildContext context, {required bool isLastGroup}) {
    final result = <Widget>[];
    for (int i = 0; i < items.length; i++) {
      final isLast = isLastGroup && i == items.length - 1;
      final showDate = i == 0;
      final showDot = i == 0;
      result.add(_TimelineEntry(
        item: items[i],
        showDate: showDate,
        showDot: showDot,
        isLast: isLast,
        date: showDate ? date : null,
      ));
    }
    return result;
  }
}

class _TimelineEntry extends StatelessWidget {
  const _TimelineEntry({
    required this.item,
    required this.showDate,
    required this.showDot,
    required this.isLast,
    required this.date,
  });
  final WorkRecordItem item;
  final bool showDate;
  final bool showDot;
  final bool isLast;
  final String? date;

  @override
  Widget build(BuildContext context) {
    final dateLabel = date ?? '';
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Date column
          SizedBox(
            width: 56,
            child: Column(
              children: [
                if (showDate) ...[
                  Text(
                    _shortDate(dateLabel),
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 4),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Card
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.lg),
              child: JournalCard(
                onTap: () => context.push('/works/${item.work.id}'),
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    CoverImage(
                      path: item.work.coverPath,
                      width: 56,
                      height: 84,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.work.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              TypeBadge(item.type.label),
                              if (item.rating != null)
                                RatingDisplay.compact(item.rating, showNumber: true),
                            ],
                          ),
                          if (item.review?.isNotEmpty == true) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              item.review!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, size: 16, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _shortDate(String date) {
    // "2026-07-29" → "07/29"
    if (date.length >= 10) {
      return date.substring(5, 10).replaceAll('-', '/');
    }
    return date;
  }
}
