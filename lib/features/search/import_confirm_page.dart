import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_tokens.dart';
import '../../metadata/metadata_provider.dart';
import '../../models/metadata_search_result.dart';
import '../../models/metadata_work_detail.dart';
import '../../models/record_status.dart';
import '../../models/work_type.dart';
import '../../repositories/metadata_repository.dart';
import '../../repositories/work_repository.dart';
import '../../services/cover_service.dart';
import '../../shared/widgets/error_view.dart';
import '../../shared/widgets/loading_view.dart';
import '../../shared/widgets/recallio_page_scaffold.dart';

class ImportConfirmPage extends ConsumerStatefulWidget {
  const ImportConfirmPage({
    required this.initialResult,
    super.key,
  });

  final MetadataSearchResult initialResult;

  @override
  ConsumerState<ImportConfirmPage> createState() => _ImportConfirmPageState();
}

class _ImportConfirmPageState extends ConsumerState<ImportConfirmPage> {
  late final Future<MetadataWorkDetail> _detailFuture;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _detailFuture = ref.read(metadataRepositoryProvider).getDetail(
          providerId: widget.initialResult.providerId,
          sourceId: widget.initialResult.sourceId,
          requestedType: widget.initialResult.type,
        );
  }

  @override
  Widget build(BuildContext context) {
    return RecallioPageScaffold(
      title: '确认导入',
      child: FutureBuilder<MetadataWorkDetail>(
        future: _detailFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const LoadingView();
          }
          if (snapshot.hasError) {
            final error = snapshot.error;
            final message =
                error is MetadataException ? error.message : '读取条目详情失败，请稍后重试。';
            return ErrorView(message: message);
          }

          final detail = snapshot.data!;
          final type = widget.initialResult.type;
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageHorizontal,
              AppSpacing.sm,
              AppSpacing.pageHorizontal,
              AppSpacing.xl,
            ),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _RemoteCover(
                    url: detail.coverUrl ?? widget.initialResult.coverUrl,
                    width: 120,
                    height: 168,
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          detail.title,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        _InfoLine(label: '类型', value: type.label),
                        _InfoLine(
                          label: '来源',
                          value: _providerName(detail.providerId),
                        ),
                        if (detail.releaseDate?.trim().isNotEmpty ?? false)
                          _InfoLine(label: '日期', value: detail.releaseDate!),
                      ],
                    ),
                  ),
                ],
              ),
              if (detail.summary?.trim().isNotEmpty ?? false) ...[
                const SizedBox(height: AppSpacing.xl),
                Text('简介摘要', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                Text(detail.summary!.trim()),
              ],
              const SizedBox(height: AppSpacing.xl),
              FilledButton.icon(
                onPressed: _importing ? null : () => _import(detail, type),
                icon: _importing
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.playlist_add_check_outlined),
                label: Text(_importing ? '正在导入' : '导入并记录'),
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: _importing ? null : () => context.pop(),
                icon: const Icon(Icons.close),
                label: const Text('取消'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _import(MetadataWorkDetail detail, WorkType type) async {
    setState(() => _importing = true);
    String? coverPath;

    try {
      final coverUrl = detail.coverUrl ?? widget.initialResult.coverUrl;
      if (coverUrl != null && coverUrl.trim().isNotEmpty) {
        try {
          coverPath = await ref.read(coverServiceProvider).downloadCover(
                coverUrl: coverUrl,
                providerId: detail.providerId,
                sourceId: detail.sourceId,
              );
        } catch (_) {
          if (mounted) {
            final message =
                type == WorkType.movie ? '海报保存失败，但记录已创建。' : '封面保存失败，但记录仍可创建。';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(message)),
            );
          }
        }
      }

      final workId = await ref.read(workRepositoryProvider).saveWork(
            WorkFormData(
              workId: null,
              type: type,
              title: detail.title,
              originalTitle: detail.originalTitle ?? '',
              aliasesText: '',
              summary: detail.summary ?? '',
              coverPath: coverPath,
              coverSourcePath: null,
              releaseDate: detail.releaseDate ?? '',
              creatorsText: '',
              status: RecordStatus.planned,
              rating: null,
              shortComment: '',
              review: '',
              spoilerReview: '',
              startDate: _todayText(),
              finishDate: '',
              progress: '',
              platform: '',
              tagNames: const [],
              sourceProvider: detail.providerId,
              sourceId: detail.sourceId,
              sourceUrl: detail.sourceUrl,
            ),
          );

      if (mounted) {
        context.push('/works/$workId/edit');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('导入失败，请稍后重试或手动创建记录。')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _importing = false);
      }
    }
  }

  String _providerName(String providerId) {
    try {
      return ref
          .read(metadataRepositoryProvider)
          .providerById(providerId)
          .displayName;
    } catch (_) {
      return providerId;
    }
  }

  String _todayText() {
    final now = DateTime.now();
    final year = now.year.toString().padLeft(4, '0');
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text('$label：$value'),
    );
  }
}

class _RemoteCover extends StatelessWidget {
  const _RemoteCover({
    required this.url,
    required this.width,
    required this.height,
  });

  final String? url;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final effectiveUrl = url?.trim();
    if (effectiveUrl == null || effectiveUrl.isEmpty) {
      return _CoverPlaceholder(width: width, height: height);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: width,
        height: height,
        child: Image.network(
          effectiveUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _CoverPlaceholder(width: width, height: height);
          },
        ),
      ),
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder({
    required this.width,
    required this.height,
  });

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: width,
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          child: Icon(
            Icons.image_outlined,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
