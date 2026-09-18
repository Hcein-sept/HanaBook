import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../metadata/metadata_provider.dart';
import '../../models/metadata_search_result.dart';
import '../../models/work_type.dart';
import '../../repositories/metadata_repository.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/pressable.dart';
import '../../shared/widgets/recallio_page_scaffold.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _keywordController = TextEditingController();

  WorkType _type = WorkType.anime;
  String? _providerId;
  List<MetadataSearchResult> _results = const [];
  String? _message;
  bool _searching = false;
  bool _searched = false;

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(metadataRepositoryProvider);
    final providers = repository.providersForType(_type);
    final selectedProviderId = _selectedProviderId(providers);

    return RecallioPageScaffold(
      title: '搜索导入',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageHorizontal,
          AppSpacing.sm,
          AppSpacing.pageHorizontal,
          AppSpacing.xl,
        ),
        children: [
          _SectionTitle('查找作品'),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<WorkType>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: '类型'),
            items: [
              for (final type in WorkType.values)
                DropdownMenuItem(value: type, child: Text(type.label)),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _type = value;
                _providerId = null;
                _results = const [];
                _message = null;
                _searched = false;
              });
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: selectedProviderId,
            decoration: const InputDecoration(labelText: '数据源'),
            items: [
              for (final provider in providers)
                DropdownMenuItem(
                  value: provider.id,
                  child: Text(provider.displayName),
                ),
            ],
            onChanged: (value) {
              setState(() {
                _providerId = value;
                _results = const [];
                _message = null;
                _searched = false;
              });
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _keywordController,
            decoration: const InputDecoration(
              labelText: '关键词',
              hintText: '输入作品标题',
            ),
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(selectedProviderId),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: _searching ? null : () => _search(selectedProviderId),
                icon: _searching
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.search),
                label: Text(_searching ? '搜索中' : '搜索'),
              ),
              OutlinedButton.icon(
                onPressed: () => context.push('/works/new'),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('手动创建'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_message != null) ...[
            _MessageCard(message: _message!),
            const SizedBox(height: 16),
          ],
          if (_results.isNotEmpty) ...[
            _SectionTitle('搜索结果'),
            const SizedBox(height: 12),
            for (final result in _results) ...[
              _SearchResultCard(
                result: result,
                providerName: _providerName(repository, result.providerId),
                onTap: () => context.push('/search/confirm', extra: result),
              ),
              const SizedBox(height: 10),
            ],
          ] else if (_searched && !_searching && _message == null)
            EmptyState(
              title: '没有找到结果',
              message: '你可以换个关键词，或直接手动创建记录。',
              action: OutlinedButton.icon(
                onPressed: () => context.push('/works/new'),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('手动创建'),
              ),
            ),
        ],
      ),
    );
  }

  String _selectedProviderId(List<MetadataProvider> providers) {
    if (providers.isEmpty) return '';
    if (_providerId != null &&
        providers.any((provider) => provider.id == _providerId)) {
      return _providerId!;
    }

    final preferredId = switch (_type) {
      WorkType.game => 'steam',
      WorkType.movie => 'tmdb',
      _ => 'bangumi',
    };
    final preferred =
        providers.where((provider) => provider.id == preferredId);
    if (preferred.isNotEmpty) return preferred.first.id;
    return providers.first.id;
  }

  Future<void> _search(String providerId) async {
    final keyword = _keywordController.text.trim();
    if (keyword.isEmpty) {
      setState(() {
        _message = '请输入搜索关键词。';
        _searched = false;
        _results = const [];
      });
      return;
    }
    if (providerId.isEmpty) {
      setState(() {
        _message = '该类型暂时没有可用数据源。';
        _searched = false;
        _results = const [];
      });
      return;
    }

    setState(() {
      _searching = true;
      _message = null;
      _searched = true;
      _results = const [];
      _providerId = providerId;
    });

    try {
      final results = await ref.read(metadataRepositoryProvider).search(
            providerId: providerId,
            keyword: keyword,
            type: _type,
          );
      if (!mounted) return;
      setState(() {
        _results = results;
        _message = results.isEmpty ? '没有找到结果，你可以手动创建记录。' : null;
      });
    } on MetadataException catch (error) {
      if (!mounted) return;
      setState(() => _message = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _message = '搜索失败，请检查网络后重试。');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  String _providerName(MetadataRepository repository, String providerId) {
    try {
      return repository.providerById(providerId).displayName;
    } catch (_) {
      return providerId;
    }
  }
}

class _SearchResultCard extends StatelessWidget {
  const _SearchResultCard({
    required this.result,
    required this.providerName,
    required this.onTap,
  });

  final MetadataSearchResult result;
  final String providerName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Pressable(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.brightness == Brightness.light
              ? AppTheme.cardLight
              : AppTheme.cardDark,
          borderRadius: AppRadius.card,
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.15),
            width: 0.5,
          ),
        ),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _RemoteCover(url: result.coverUrl, width: 72, height: 100),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [providerName, result.type.label].join(' · '),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                  if (result.summary?.trim().isNotEmpty ?? false) ...[
                    const SizedBox(height: 8),
                    Text(
                      result.summary!.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

class _RemoteCover extends StatelessWidget {
  const _RemoteCover({required this.url, required this.width, required this.height});

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
          errorBuilder: (_, __, ___) => _CoverPlaceholder(width: width, height: height),
        ),
      ),
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.image_outlined,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: colorScheme.brightness == Brightness.light
            ? AppTheme.cardLight
            : AppTheme.cardDark,
        borderRadius: AppRadius.card,
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.15),
          width: 0.5,
        ),
      ),
      child: Text(message),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.titleLarge);
  }
}
