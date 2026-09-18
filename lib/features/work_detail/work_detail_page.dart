import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../db/app_database.dart';
import '../../repositories/work_repository.dart';
import '../../shared/widgets/cover_image.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/error_view.dart';
import '../../shared/widgets/journal_card.dart';
import '../../shared/widgets/loading_view.dart';
import '../../shared/widgets/rating_display.dart';
import '../../shared/widgets/recallio_page_scaffold.dart';
import '../../shared/widgets/type_badge.dart';

class WorkDetailPage extends ConsumerWidget {
  const WorkDetailPage({required this.workId, super.key});

  final String workId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemAsync = ref.watch(workDetailProvider(workId));

    return RecallioPageScaffold(
      title: '作品详情',
      showNavBar: false,
      actions: [
        IconButton(
          tooltip: '编辑',
          onPressed: () => context.push('/works/$workId/edit'),
          icon: const Icon(Icons.edit_outlined),
        ),
        IconButton(
          tooltip: '删除',
          onPressed: () => _confirmDelete(context, ref),
          icon: const Icon(Icons.delete_outline),
        ),
      ],
      child: itemAsync.when(
        loading: () => const LoadingView(),
        error: (error, stackTrace) => const ErrorView(message: '详情加载失败'),
        data: (item) {
          if (item == null) {
            return EmptyState(
              title: '作品不存在',
              message: '这条记录可能已经被删除。',
              action: OutlinedButton.icon(
                onPressed: () => context.go('/library'),
                icon: const Icon(Icons.arrow_back),
                label: const Text('返回作品库'),
              ),
            );
          }

          return _DetailContent(item: item);
        },
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('删除作品', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text('这会从作品库中移除这条记录，并保留可用于备份合并的删除标记。'),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                    child: const Text('删除'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !context.mounted) return;
    await ref.read(workRepositoryProvider).softDeleteWork(workId);
    if (context.mounted) context.go('/library');
  }
}

class _DetailContent extends StatelessWidget {
  const _DetailContent({required this.item});
  final WorkRecordItem item;

  @override
  Widget build(BuildContext context) {
    final work = item.work;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // -- Header with cover + gradient backdrop --
        _DetailHeader(work: work),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Type + rating
              TypeBadge(item.type.label),
              const SizedBox(height: AppSpacing.lg),

              // Rating hero
              if (item.rating != null)
                RatingDisplay.hero(item.rating)
              else
                Text('未评分', style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                )),
              const SizedBox(height: AppSpacing.xl),

              // Review card
              _ReviewCard(item: item),
              const SizedBox(height: AppSpacing.md),

              // Source info (if any)
              if (_hasSourceInfo(work))
                JournalCard(
                  onTap: () => _showSourceSheet(context, work),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.cardPadding,
                    vertical: 14,
                  ),
                  accentColor: AppTheme.primary.withValues(alpha: 0.2),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16,
                          color: AppTheme.primary.withValues(alpha: 0.5)),
                      const SizedBox(width: AppSpacing.sm),
                      Text('来源信息', style: textTheme.titleSmall),
                      const Spacer(),
                      Icon(Icons.chevron_right, size: 16,
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _showSourceSheet(BuildContext context, Work work) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('来源信息', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            _InfoField(label: '来源', value: work.sourceProvider),
            _InfoField(label: '来源 ID', value: work.sourceId),
            _InfoField(label: '来源链接', value: work.sourceUrl),
          ],
        ),
      ),
    );
  }
}

// -- Detail header: cover left, title right --
class _DetailHeader extends StatelessWidget {
  const _DetailHeader({required this.work});
  final Work work;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        AppSpacing.pageHorizontal,
        AppSpacing.pageHorizontal,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.12),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CoverImage(
            path: work.coverPath,
            width: 160,
            height: 240,
            fit: BoxFit.contain,
            borderRadius: BorderRadius.circular(10),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(work.title, style: textTheme.headlineSmall),
                const SizedBox(height: 10),
                Container(
                  width: 28,
                  height: 3,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// -- Review card: notebook-style --
class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.item});
  final WorkRecordItem item;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return JournalCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.push_pin_outlined, size: 14,
                  color: AppTheme.primary.withValues(alpha: 0.5)),
              const SizedBox(width: 6),
              Text('我的评价', style: textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 14),
          if (item.rating != null) ...[
            _InfoField(label: '评分', value: '${item.rating!.toStringAsFixed(1)} 分'),
          ],
          if (item.review?.isNotEmpty == true) ...[
            _InfoField(label: '评价', value: item.review),
          ],
          if (item.recordDate != null) ...[
            _InfoField(label: '记录日期', value: item.recordDate),
          ],
        ],
      ),
    );
  }
}

class _InfoField extends StatelessWidget {
  const _InfoField({required this.label, required this.value});
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final content = value?.trim();
    if (content == null || content.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppTheme.primary.withValues(alpha: 0.7),
              )),
          const SizedBox(height: 4),
          Text(content, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

bool _hasSourceInfo(Work work) {
  final provider = work.sourceProvider?.trim();
  final sourceId = work.sourceId?.trim();
  final sourceUrl = work.sourceUrl?.trim();
  return (provider != null && provider.isNotEmpty && provider != 'manual') ||
      (sourceId != null && sourceId.isNotEmpty) ||
      (sourceUrl != null && sourceUrl.isNotEmpty);
}
