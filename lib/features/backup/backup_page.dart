import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_tokens.dart';
import '../../services/backup_service.dart';
import '../../shared/widgets/recallio_page_scaffold.dart';
import '../../shared/widgets/section_card.dart';

class BackupPage extends ConsumerStatefulWidget {
  const BackupPage({super.key});

  @override
  ConsumerState<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends ConsumerState<BackupPage> {
  bool _exporting = false;
  bool _importing = false;

  @override
  Widget build(BuildContext context) {
    return RecallioPageScaffold(
      title: '备份与恢复',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageHorizontal,
          AppSpacing.sm,
          AppSpacing.pageHorizontal,
          AppSpacing.xl,
        ),
        children: [
          SectionCard(
            title: '数据安全',
            children: [
              const Text(
                '${AppConstants.displayName} 的记录默认保存在当前设备本地。重新安装或卸载 App 后数据会丢失，请务必在更新或卸载前先导出备份包。',
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '备份包保存在应用数据目录的 backups 文件夹中。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _exporting ? null : _startExport,
              icon: _exporting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.upload_file_outlined),
              label: Text(_exporting ? '正在导出...' : '导出备份包'),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _importing ? null : _startImport,
              icon: _importing
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_outlined),
              label: Text(_importing ? '正在导入...' : '导入备份包'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startExport() async {
    setState(() => _exporting = true);
    try {
      final service = ref.read(backupServiceProvider);
      final savePath = await service.exportToZip();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已导出：$savePath'),
            duration: const Duration(seconds: 6),
            action: SnackBarAction(label: '确定', onPressed: () {}),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('导出失败：${e.toString().replaceFirst('Exception: ', '')}'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _startImport() async {
    final result = await FilePicker.pickFiles(
      dialogTitle: '选择备份包',
      type: FileType.custom,
      allowedExtensions: const ['zip'],
    );
    if (result == null || result.files.isEmpty) return;

    final zipPath = result.files.single.path;
    if (zipPath == null) return;

    setState(() => _importing = true);
    try {
      final service = ref.read(backupServiceProvider);
      final parsed = await service.parseZipFile(zipPath);
      if (!mounted) return;

      final mode = await _showPreviewDialog(parsed);
      if (mode == null) return;

      final importResult = await service.importFromParsed(parsed, mode: mode);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '导入完成：新增 ${importResult.inserted} 条，'
              '跳过 ${importResult.skipped} 条，'
              '还原封面 ${importResult.coverFilesExtracted} 个。',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('导入失败：${e.toString().replaceFirst('Exception: ', '')}'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<ImportMode?> _showPreviewDialog(ParsedBackup parsed) async {
    final manifest = parsed.manifest;
    final entryCount = parsed.entries.length;
    final coverCount = parsed.coverFiles.length;
    ImportMode selectedMode = ImportMode.merge;

    return showDialog<ImportMode>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('导入预览'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '来源应用：${manifest.appName.isEmpty ? '旧版备份' : manifest.appName}',
                    ),
                    Text('格式版本：${manifest.formatVersion}'),
                    Text('创建时间：${_formatDateTime(manifest.createdAt)}'),
                    Text('来源：${manifest.sourceClient} / ${manifest.platform}'),
                    const SizedBox(height: 12),
                    Text('包含 $entryCount 条记录'),
                    if (coverCount > 0) Text('包含 $coverCount 个封面文件'),
                    const SizedBox(height: 16),
                    const Text('冲突处理方式：'),
                    const SizedBox(height: 8),
                    SegmentedButton<ImportMode>(
                      segments: const [
                        ButtonSegment(
                          value: ImportMode.merge,
                          label: Text('合并'),
                          tooltip: '跳过已存在的记录，仅导入新记录',
                        ),
                        ButtonSegment(
                          value: ImportMode.overwrite,
                          label: Text('覆盖'),
                          tooltip: '用备份中的记录覆盖已存在的同名记录',
                        ),
                      ],
                      selected: {selectedMode},
                      onSelectionChanged: (set) {
                        setDialogState(() => selectedMode = set.first);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(selectedMode),
                  child: const Text('确认导入'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${_pad(dt.month)}-${_pad(dt.day)} '
        '${_pad(dt.hour)}:${_pad(dt.minute)}';
  }

  String _pad(int n) => n.toString().padLeft(2, '0');
}
