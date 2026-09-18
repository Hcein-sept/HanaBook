import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../models/record_status.dart';
import '../../models/work_type.dart';
import '../../repositories/work_repository.dart';
import '../../services/cover_service.dart';
import '../../shared/widgets/cover_image.dart';
import '../../shared/widgets/error_view.dart';
import '../../shared/widgets/loading_view.dart';
import '../../shared/widgets/rating_input.dart';
import '../../shared/widgets/recallio_page_scaffold.dart';
import '../../shared/widgets/section_card.dart';
import 'cover_crop_page.dart';

class WorkEditPage extends ConsumerStatefulWidget {
  const WorkEditPage({this.workId, super.key});

  final String? workId;

  @override
  ConsumerState<WorkEditPage> createState() => _WorkEditPageState();
}

class _WorkEditPageState extends ConsumerState<WorkEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _reviewController = TextEditingController();
  final _ratingController = TextEditingController();
  final _recordDateController = TextEditingController();

  late final Future<void> _loadFuture;
  WorkType _type = WorkType.anime;
  String? _coverPath;
  String? _pendingCoverSourcePath;
  String? _originalSourcePath;
  bool _notFound = false;
  bool _saving = false;
  bool _pickingCover = false;

  @override
  void initState() {
    super.initState();
    _recordDateController.text = _todayText();
    _loadFuture = widget.workId == null ? Future.value() : _loadExisting();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _reviewController.dispose();
    _ratingController.dispose();
    _recordDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.workId != null;

    return RecallioPageScaffold(
      title: isEditing ? '编辑作品' : '新建作品',
      child: FutureBuilder<void>(
        future: _loadFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const LoadingView();
          }
          if (snapshot.hasError) {
            return const ErrorView(message: '读取作品失败');
          }
          if (_notFound) {
            return const ErrorView(message: '作品不存在或已被删除');
          }

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageHorizontal,
                AppSpacing.sm,
                AppSpacing.pageHorizontal,
                AppSpacing.xl,
              ),
              children: [
                // -- Work section --
                SectionCard(
                  title: '作品',
                  children: [
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: '标题',
                        hintText: '作品标题',
                      ),
                      validator: (value) {
                        return value == null || value.trim().isEmpty
                            ? '请输入作品标题'
                            : null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    // Type selector with icon buttons
                    Text('类型', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final type in WorkType.values)
                          _TypeButton(
                            type: type,
                            isSelected: _type == type,
                            onTap: () => setState(() => _type = type),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    // Cover picker
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: _pickingCover || _saving ? null : _pickCover,
                          child: Container(
                            key: const ValueKey('work-cover-thumbnail'),
                            width: 108,
                            height: 162,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withValues(alpha: 0.3),
                            ),
                            foregroundDecoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppTheme.primary.withValues(alpha: 0.3),
                                width: 1,
                                strokeAlign: BorderSide.strokeAlignInside,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: _pendingCoverSourcePath != null ||
                                    _coverPath != null
                                ? CoverImage(
                                    path: _pendingCoverSourcePath ?? _coverPath,
                                    width: 108,
                                    height: 162,
                                    fit: BoxFit.contain,
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.add_photo_alternate_outlined,
                                        size: 28,
                                        color: AppTheme.primary
                                            .withValues(alpha: 0.5),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '添加封面',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: AppTheme.primary
                                                  .withValues(alpha: 0.6),
                                            ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 8),
                              Text(
                                '选择一张本地图片作为封面',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                onPressed: _pickingCover || _saving
                                    ? null
                                    : _pickCover,
                                icon:
                                    const Icon(Icons.image_outlined, size: 18),
                                label: const Text('选择本地封面'),
                              ),
                              if (_pendingCoverSourcePath != null ||
                                  _coverPath != null) ...[
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  onPressed:
                                      _pickingCover || _saving ? null : _reCrop,
                                  icon: const Icon(Icons.crop, size: 18),
                                  label: const Text('重新截取'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),

                // -- Review section --
                SectionCard(
                  title: '我的评价',
                  children: [
                    RatingInput(controller: _ratingController),
                    const SizedBox(height: AppSpacing.lg),
                    TextFormField(
                      controller: _reviewController,
                      minLines: 4,
                      maxLines: 12,
                      decoration: const InputDecoration(
                        labelText: '评价',
                        hintText: '你想怎么评价这部作品？',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextFormField(
                      controller: _recordDateController,
                      readOnly: true,
                      onTap: _pickRecordDate,
                      decoration: const InputDecoration(
                        labelText: '记录日期',
                        hintText: 'YYYY-MM-DD',
                        suffixIcon: Icon(Icons.calendar_today_outlined),
                      ),
                      validator: _validateRecordDate,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),

                // -- Save button --
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saving || _pickingCover ? null : _save,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(_saving ? '正在保存' : '保存'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _loadExisting() async {
    final item =
        await ref.read(workRepositoryProvider).fetchDetail(widget.workId!);
    if (!mounted) return;
    if (item == null) {
      setState(() => _notFound = true);
      return;
    }

    final work = item.work;
    final record = item.record;
    setState(() {
      _type = item.type;
      _coverPath = work.coverPath;
      _titleController.text = work.title;
      _ratingController.text = record?.rating?.toStringAsFixed(1) ?? '';
      _reviewController.text = item.review ?? '';
      _recordDateController.text =
          record?.startDate ?? _dateFromIso(record?.createdAt) ?? _todayText();
    });
  }

  Future<void> _pickCover() async {
    if (_pickingCover || _saving) return;
    setState(() => _pickingCover = true);
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (!mounted || result == null) return;
      final path = result.files.singleOrNull?.path;
      if (path == null || path.trim().isEmpty) {
        _showCoverError('未能读取所选封面路径');
        return;
      }

      await _openCoverCrop(path);
    } catch (_) {
      if (mounted) _showCoverError('选择封面失败，请重新选择图片');
    } finally {
      if (mounted) setState(() => _pickingCover = false);
    }
  }

  Future<void> _reCrop() async {
    if (_pickingCover || _saving) return;
    setState(() => _pickingCover = true);
    try {
      final sources = {
        if (_originalSourcePath != null) _originalSourcePath!,
        if (_pendingCoverSourcePath != null) _pendingCoverSourcePath!,
        if (_coverPath != null) _coverPath!,
      };
      for (final source in sources) {
        final coverFile = await CoverService().resolveCoverFile(source);
        if (!mounted) return;
        if (coverFile == null) continue;

        if (_originalSourcePath != null && source != _originalSourcePath) {
          _showCoverError('原图已不可用，将使用当前封面重新截取');
        }
        await _openCoverCrop(coverFile.path);
        return;
      }
      if (mounted) _showCoverError('封面文件已不可用，请重新选择图片');
    } catch (_) {
      if (mounted) _showCoverError('读取封面失败，请重新选择图片');
    } finally {
      if (mounted) setState(() => _pickingCover = false);
    }
  }

  Future<void> _openCoverCrop(String sourcePath) async {
    if (!mounted) return;

    final croppedPath = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => CoverCropPage(sourcePath: sourcePath),
      ),
    );

    if (croppedPath != null && mounted) {
      setState(() {
        _pendingCoverSourcePath = croppedPath;
        _originalSourcePath = sourcePath;
      });
    }
  }

  void _showCoverError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _pickRecordDate() async {
    final initialDate = _parseDate(_recordDateController.text) ??
        DateTime.tryParse(_todayText()) ??
        DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    _recordDateController.text = _formatDate(picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final rating = _parseRating(_ratingController.text);
      final workId = await ref.read(workRepositoryProvider).saveWork(
            WorkFormData(
              workId: widget.workId,
              type: _type,
              title: _titleController.text,
              coverPath: _coverPath,
              coverSourcePath: _pendingCoverSourcePath,
              status: RecordStatus.planned,
              rating: rating,
              review: _reviewController.text,
              startDate: _recordDateController.text,
              // Unused first-edition fields — pass empty defaults
              originalTitle: '',
              aliasesText: '',
              summary: '',
              releaseDate: '',
              creatorsText: '',
              shortComment: '',
              spoilerReview: '',
              finishDate: '',
              progress: '',
              platform: '',
              tagNames: const [],
            ),
          );

      if (mounted) context.go('/works/$workId');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存失败，请检查输入内容后重试')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _validateRecordDate(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return '请输入记录日期';
    if (_parseDate(trimmed) == null) return '记录日期格式应为 YYYY-MM-DD';
    return null;
  }

  double? _parseRating(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final parsed = double.tryParse(trimmed);
    if (parsed == null || parsed.isNaN || parsed.isInfinite) return null;
    return (parsed.clamp(0.0, 10.0) * 10).roundToDouble() / 10.0;
  }

  DateTime? _parseDate(String value) {
    final trimmed = value.trim();
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(trimmed);
    if (match == null) return null;
    final y = int.parse(match.group(1)!);
    final m = int.parse(match.group(2)!);
    final d = int.parse(match.group(3)!);
    final date = DateTime(y, m, d);
    return (date.year == y && date.month == m && date.day == d) ? date : null;
  }

  String _todayText() => _formatDate(DateTime.now());

  String? _dateFromIso(String? value) {
    if (value == null || value.length < 10) return null;
    return value.substring(0, 10);
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

// -- Type button --
class _TypeButton extends StatelessWidget {
  const _TypeButton({
    required this.type,
    required this.isSelected,
    required this.onTap,
  });

  final WorkType type;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.normal,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? AppTheme.primary.withValues(alpha: 0.4)
                : Theme.of(context)
                    .colorScheme
                    .outlineVariant
                    .withValues(alpha: 0.3),
            width: isSelected ? 1 : 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_typeIcon(type), size: 18, color: _typeColor(context)),
            const SizedBox(width: 6),
            Text(
              type.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: _typeColor(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _typeColor(BuildContext context) {
    if (!isSelected) return Theme.of(context).colorScheme.onSurfaceVariant;
    return AppTheme.primary;
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
}
