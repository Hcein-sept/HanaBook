import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/rating_presentation_resolver.dart';
import '../../models/rating_presentation_config.dart';
import '../../services/settings_service.dart';
import '../../shared/widgets/color_picker_field.dart';
import '../../shared/widgets/error_view.dart';
import '../../shared/widgets/loading_view.dart';
import '../../shared/widgets/rating_display.dart';
import '../../shared/widgets/recallio_page_scaffold.dart';
import '../../shared/widgets/section_card.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _tmdbTokenController = TextEditingController();

  late final Future<void> _loadFuture;
  late RatingPresentationConfig _ratingConfig;
  bool _saving = false;
  bool _savingRating = false;
  bool _obscureToken = true;
  int _ruleIdSequence = 0;

  @override
  void initState() {
    super.initState();
    _loadFuture = _loadSettings();
  }

  @override
  void dispose() {
    _tmdbTokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RecallioPageScaffold(
      title: '设置',
      child: FutureBuilder<void>(
        future: _loadFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const LoadingView();
          }
          if (snapshot.hasError) {
            return const ErrorView(message: '读取设置失败');
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageHorizontal,
              AppSpacing.sm,
              AppSpacing.pageHorizontal,
              AppSpacing.xl,
            ),
            children: [
              SectionCard(
                title: '数据与隐私',
                children: const [
                  _InfoRow(
                    icon: Icons.folder_outlined,
                    title: '数据保存位置',
                    subtitle: '数据库、封面和附件会保存在应用文档目录下。',
                  ),
                  _InfoRowDivider(),
                  _InfoRow(
                    icon: Icons.shield_outlined,
                    title: '隐私',
                    subtitle: '不需要账号，不上传用户记录，不接入广告 SDK。',
                  ),
                  _InfoRowDivider(),
                  _InfoRow(
                    icon: Icons.public_off_outlined,
                    title: '网络访问',
                    subtitle: '除非主动使用外部搜索功能，否则应用不会访问网络。',
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              SectionCard(
                title: '外部搜索',
                children: [
                  TextField(
                    controller: _tmdbTokenController,
                    obscureText: _obscureToken,
                    decoration: InputDecoration(
                      labelText: 'TMDb API Token / API Key',
                      helperText: '仅保存在本机，用于电影搜索导入。',
                      suffixIcon: IconButton(
                        tooltip: _obscureToken ? '显示' : '隐藏',
                        onPressed: () =>
                            setState(() => _obscureToken = !_obscureToken),
                        icon: Icon(
                          _obscureToken
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      onPressed: _saving || _savingRating ? null : _saveSettings,
                      icon: _saving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(_saving ? '正在保存' : '保存 TMDb 设置'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              SectionCard(
                title: '基础样式',
                children: [
                  ColorPickerField(
                    label: '未匹配评分颜色（可选）',
                    helperText: '没有颜色规则匹配当前评分时使用；留空时使用主题中性色。',
                    value: _ratingConfig.style.unmatchedColorHex,
                    allowClear: true,
                    enabled: !_savingRating,
                    onChanged: _setUnmatchedRatingColor,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              _SettingsSectionHeader(
                title: '评分颜色规则',
                description: '按列表顺序匹配评分区间，决定已点亮星星和分数的纯色。未添加规则时使用主题中性色。',
                actionLabel: '添加规则',
                onAdd: _savingRating ? null : () => _editColorRule(),
              ),
              const SizedBox(height: AppSpacing.md),
              if (_ratingConfig.colorRules.isEmpty)
                const _EmptyRulesCard(message: '尚未配置评分颜色规则。')
              else
                ...List.generate(
                  _ratingConfig.colorRules.length,
                  (index) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: AnimatedSize(
                      duration: AppMotion.normal,
                      curve: AppMotion.standard,
                      alignment: Alignment.topCenter,
                      child: _ColorRuleCard(
                        key: ValueKey(_ratingConfig.colorRules[index].id),
                        rule: _ratingConfig.colorRules[index],
                        onEnabledChanged: _savingRating
                            ? null
                            : (enabled) => _setColorRuleEnabled(index, enabled),
                        onEdit:
                            _savingRating ? null : () => _editColorRule(index),
                        onDelete: _savingRating
                            ? null
                            : () => _deleteColorRule(index),
                        onMoveUp: _savingRating || index == 0
                            ? null
                            : () => _moveColorRule(index, index - 1),
                        onMoveDown: _savingRating ||
                                index == _ratingConfig.colorRules.length - 1
                            ? null
                            : () => _moveColorRule(index, index + 1),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.lg),
              _RatingColorPreview(config: _ratingConfig),
              const SizedBox(height: AppSpacing.xl),
              _SettingsSectionHeader(
                title: '评分 Tag 规则',
                description: 'Tag 的名称、颜色和触发条件完全由你定义；不配置时不会显示任何评分 Tag。',
                actionLabel: '添加 Tag',
                onAdd: _savingRating ? null : () => _editTagRule(),
              ),
              const SizedBox(height: AppSpacing.md),
              if (_ratingConfig.tags.isEmpty)
                const _EmptyRulesCard(message: '尚未配置评分 Tag 规则。')
              else
                ...List.generate(
                  _ratingConfig.tags.length,
                  (index) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: AnimatedSize(
                      duration: AppMotion.normal,
                      curve: AppMotion.standard,
                      alignment: Alignment.topCenter,
                      child: _TagRuleCard(
                        key: ValueKey(_ratingConfig.tags[index].id),
                        rule: _ratingConfig.tags[index],
                        onEnabledChanged: _savingRating
                            ? null
                            : (enabled) => _setTagRuleEnabled(index, enabled),
                        onEdit:
                            _savingRating ? null : () => _editTagRule(index),
                        onDelete:
                            _savingRating ? null : () => _deleteTagRule(index),
                        onMoveUp: _savingRating || index == 0
                            ? null
                            : () => _moveTagRule(index, index - 1),
                        onMoveDown: _savingRating ||
                                index == _ratingConfig.tags.length - 1
                            ? null
                            : () => _moveTagRule(index, index + 1),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed:
                      _saving || _savingRating ? null : _saveRatingSettings,
                  icon: _savingRating
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    _savingRating ? '正在保存' : '保存评分展示设置',
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _loadSettings() async {
    final service = ref.read(settingsServiceProvider);
    final token = await service.readTmdbToken();
    final ratingConfig = await service.readRatingPresentationConfig();
    if (!mounted) return;
    _tmdbTokenController.text = token ?? '';
    _ratingConfig = RatingPresentationConfig(
      colorRules: [...ratingConfig.colorRules]
        ..sort((a, b) => a.order.compareTo(b.order)),
      tags: [...ratingConfig.tags]..sort((a, b) => a.order.compareTo(b.order)),
      style: ratingConfig.style,
    );
  }

  Future<void> _saveSettings() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(settingsServiceProvider)
          .saveTmdbToken(_tmdbTokenController.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('TMDb 设置已保存。')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存设置失败，请稍后重试。')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveRatingSettings() async {
    final configToSave = _ratingConfig;
    setState(() => _savingRating = true);
    try {
      await ref
          .read(settingsServiceProvider)
          .saveRatingPresentationConfig(configToSave);
      if (!mounted) return;
      _ratingConfig = configToSave;
      ref.invalidate(ratingPresentationConfigProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('评分展示设置已保存。')),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存评分展示设置失败，请稍后重试。')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingRating = false);
    }
  }

  void _setUnmatchedRatingColor(String? unmatchedColorHex) {
    setState(() {
      _ratingConfig = RatingPresentationConfig(
        colorRules: _ratingConfig.colorRules,
        tags: _ratingConfig.tags,
        style: RatingPresentationStyle(
          unmatchedColorHex: unmatchedColorHex,
          // Preserve the legacy value for data compatibility. Rating colors
          // no longer style unlit stars, which always use the app theme.
          inactiveStarColorHex: _ratingConfig.style.inactiveStarColorHex,
        ),
      );
    });
  }

  Future<void> _editColorRule([int? index]) async {
    final existing = index == null ? null : _ratingConfig.colorRules[index];
    final result = await _showColorRuleDialog(existing);
    if (!mounted || result == null) return;

    final rules = [..._ratingConfig.colorRules];
    if (index == null) {
      rules.add(result);
    } else {
      rules[index] = result;
    }
    setState(() => _replaceColorRules(rules));
  }

  Future<ScoreColorRule?> _showColorRuleDialog(
    ScoreColorRule? existing,
  ) async {
    final formKey = GlobalKey<FormState>();
    final minController = TextEditingController(
      text: existing?.minScore.toString() ?? '',
    );
    final maxController = TextEditingController(
      text: existing?.maxScore.toString() ?? '',
    );
    var colorHex = existing?.colorHex;
    var enabled = existing?.enabled ?? true;

    try {
      final result = await showDialog<ScoreColorRule>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(existing == null ? '添加评分颜色规则' : '编辑评分颜色规则'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: minController,
                            autofocus: true,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: '最低评分',
                              hintText: '0.0',
                            ),
                            validator: _scoreValidator,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: maxController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: '最高评分',
                              hintText: '10.0',
                            ),
                            validator: _scoreValidator,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ColorPickerField(
                      label: '颜色',
                      helperText: '选择常用颜色，或在完整颜色选择器中精确调整。',
                      value: colorHex,
                      onChanged: (value) {
                        setDialogState(() => colorHex = value);
                      },
                    ),
                    const SizedBox(height: 4),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('启用此规则'),
                      value: enabled,
                      onChanged: (value) =>
                          setDialogState(() => enabled = value),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () {
                  if (!(formKey.currentState?.validate() ?? false)) return;
                  if (colorHex == null) {
                    _showDialogMessage(dialogContext, '请选择颜色。');
                    return;
                  }
                  final min = double.parse(minController.text.trim());
                  final max = double.parse(maxController.text.trim());
                  if (min > max) {
                    _showDialogMessage(dialogContext, '最低评分不能高于最高评分。');
                    return;
                  }
                  Navigator.of(dialogContext).pop(
                    ScoreColorRule(
                      id: existing?.id ?? _nextRuleId('color'),
                      minScore: min,
                      maxScore: max,
                      colorHex: colorHex!,
                      enabled: enabled,
                      order: existing?.order ?? _ratingConfig.colorRules.length,
                    ),
                  );
                },
                child: const Text('确定'),
              ),
            ],
          ),
        ),
      );
      // showDialog 的 Future 会在退场动画结束前完成；等待路由完成卸载后
      // 再释放输入控制器，避免动画最后几帧继续访问已释放对象。
      await Future<void>.delayed(const Duration(milliseconds: 250));
      return result;
    } finally {
      minController.dispose();
      maxController.dispose();
    }
  }

  Future<void> _editTagRule([int? index]) async {
    final existing = index == null ? null : _ratingConfig.tags[index];
    final result = await _showTagRuleDialog(existing);
    if (!mounted || result == null) return;

    final tags = [..._ratingConfig.tags];
    if (index == null) {
      tags.add(result);
    } else {
      tags[index] = result;
    }
    setState(() => _replaceTagRules(tags));
  }

  Future<ScoreTagRule?> _showTagRuleDialog(ScoreTagRule? existing) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: existing?.name ?? '');
    var colorHex = existing?.colorHex;
    final thresholdController = TextEditingController(
      text: existing?.threshold.toString() ?? '',
    );
    final upperController = TextEditingController(
      text: existing?.upperThreshold?.toString() ?? '',
    );
    var condition = existing?.condition ?? ScoreTagCondition.gte;
    var enabled = existing?.enabled ?? true;

    try {
      final result = await showDialog<ScoreTagRule>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(existing == null ? '添加评分 Tag' : '编辑评分 Tag'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      autofocus: true,
                      decoration: const InputDecoration(labelText: 'Tag 名称'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? '请输入 Tag 名称。'
                              : null,
                    ),
                    const SizedBox(height: 12),
                    ColorPickerField(
                      label: 'Tag 颜色',
                      helperText: '颜色仅用于这个用户自定义 Tag。',
                      value: colorHex,
                      onChanged: (value) {
                        setDialogState(() => colorHex = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<ScoreTagCondition>(
                      initialValue: condition,
                      decoration: const InputDecoration(labelText: '触发条件'),
                      items: ScoreTagCondition.values
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(_conditionLabel(value)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => condition = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: thresholdController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText:
                            condition == ScoreTagCondition.betweenInclusive
                                ? '区间下限'
                                : '评分阈值',
                      ),
                      validator: _scoreValidator,
                    ),
                    if (condition == ScoreTagCondition.betweenInclusive) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: upperController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(labelText: '区间上限'),
                        validator: _scoreValidator,
                      ),
                    ],
                    const SizedBox(height: 4),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('启用此规则'),
                      value: enabled,
                      onChanged: (value) =>
                          setDialogState(() => enabled = value),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () {
                  if (!(formKey.currentState?.validate() ?? false)) return;
                  if (colorHex == null) {
                    _showDialogMessage(dialogContext, '请选择 Tag 颜色。');
                    return;
                  }
                  final threshold =
                      double.parse(thresholdController.text.trim());
                  final upper = condition == ScoreTagCondition.betweenInclusive
                      ? double.parse(upperController.text.trim())
                      : null;
                  if (upper != null && threshold > upper) {
                    _showDialogMessage(dialogContext, '区间下限不能高于区间上限。');
                    return;
                  }
                  Navigator.of(dialogContext).pop(
                    ScoreTagRule(
                      id: existing?.id ?? _nextRuleId('tag'),
                      name: nameController.text.trim(),
                      colorHex: colorHex!,
                      condition: condition,
                      threshold: threshold,
                      upperThreshold: upper,
                      enabled: enabled,
                      order: existing?.order ?? _ratingConfig.tags.length,
                    ),
                  );
                },
                child: const Text('确定'),
              ),
            ],
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 250));
      return result;
    } finally {
      nameController.dispose();
      thresholdController.dispose();
      upperController.dispose();
    }
  }

  void _setColorRuleEnabled(int index, bool enabled) {
    final current = _ratingConfig.colorRules[index];
    final rules = [..._ratingConfig.colorRules];
    rules[index] = ScoreColorRule(
      id: current.id,
      minScore: current.minScore,
      maxScore: current.maxScore,
      colorHex: current.colorHex,
      enabled: enabled,
      order: current.order,
    );
    setState(() => _replaceColorRules(rules));
  }

  void _setTagRuleEnabled(int index, bool enabled) {
    final current = _ratingConfig.tags[index];
    final tags = [..._ratingConfig.tags];
    tags[index] = ScoreTagRule(
      id: current.id,
      name: current.name,
      colorHex: current.colorHex,
      condition: current.condition,
      threshold: current.threshold,
      upperThreshold: current.upperThreshold,
      enabled: enabled,
      order: current.order,
    );
    setState(() => _replaceTagRules(tags));
  }

  void _deleteColorRule(int index) {
    final rules = [..._ratingConfig.colorRules]..removeAt(index);
    setState(() => _replaceColorRules(rules));
  }

  void _deleteTagRule(int index) {
    final tags = [..._ratingConfig.tags]..removeAt(index);
    setState(() => _replaceTagRules(tags));
  }

  void _moveColorRule(int from, int to) {
    final rules = [..._ratingConfig.colorRules];
    final rule = rules.removeAt(from);
    rules.insert(to, rule);
    setState(() => _replaceColorRules(rules));
  }

  void _moveTagRule(int from, int to) {
    final tags = [..._ratingConfig.tags];
    final rule = tags.removeAt(from);
    tags.insert(to, rule);
    setState(() => _replaceTagRules(tags));
  }

  void _replaceColorRules(List<ScoreColorRule> rules) {
    _ratingConfig = RatingPresentationConfig(
      colorRules: [
        for (var index = 0; index < rules.length; index++)
          ScoreColorRule(
            id: rules[index].id,
            minScore: rules[index].minScore,
            maxScore: rules[index].maxScore,
            colorHex: rules[index].colorHex,
            enabled: rules[index].enabled,
            order: index,
          ),
      ],
      tags: _ratingConfig.tags,
      style: _ratingConfig.style,
    );
  }

  void _replaceTagRules(List<ScoreTagRule> tags) {
    _ratingConfig = RatingPresentationConfig(
      colorRules: _ratingConfig.colorRules,
      tags: [
        for (var index = 0; index < tags.length; index++)
          ScoreTagRule(
            id: tags[index].id,
            name: tags[index].name,
            colorHex: tags[index].colorHex,
            condition: tags[index].condition,
            threshold: tags[index].threshold,
            upperThreshold: tags[index].upperThreshold,
            enabled: tags[index].enabled,
            order: index,
          ),
      ],
      style: _ratingConfig.style,
    );
  }

  void _showDialogMessage(BuildContext dialogContext, String message) {
    ScaffoldMessenger.of(dialogContext).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _nextRuleId(String prefix) {
    return '$prefix-${DateTime.now().microsecondsSinceEpoch}-${_ruleIdSequence++}';
  }
}

class _SettingsSectionHeader extends StatelessWidget {
  const _SettingsSectionHeader({
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onAdd,
  });

  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.xs),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 18),
            label: Text(actionLabel),
          ),
        ),
      ],
    );
  }
}

class _RatingColorPreview extends StatelessWidget {
  const _RatingColorPreview({required this.config});

  final RatingPresentationConfig config;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: AppRadius.card,
        border: Border.all(color: colorScheme.outlineVariant, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('实时预览', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 2),
          Text(
            '示例分数仅用于查看当前配置效果。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: 20,
            runSpacing: 10,
            children: [
              RatingDisplay(
                key: const ValueKey('rating-color-preview-8.7'),
                rating: 8.7,
                size: 24,
                presentationConfig: config,
              ),
              RatingDisplay(
                key: const ValueKey('rating-color-preview-9.6'),
                rating: 9.6,
                size: 24,
                presentationConfig: config,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyRulesCard extends StatelessWidget {
  const _EmptyRulesCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.cardPadding,
        vertical: 18,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: AppRadius.card,
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 0.5,
        ),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}

class _ColorRuleCard extends StatelessWidget {
  const _ColorRuleCard({
    required this.rule,
    required this.onEnabledChanged,
    required this.onEdit,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
    super.key,
  });

  final ScoreColorRule rule;
  final ValueChanged<bool>? onEnabledChanged;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  @override
  Widget build(BuildContext context) {
    return _RuleCard(
      enabled: rule.enabled,
      color: RatingPresentationResolver.parseColor(rule.colorHex),
      title: '${_formatScore(rule.minScore)} – ${_formatScore(rule.maxScore)}',
      subtitle: rule.colorHex,
      onEnabledChanged: onEnabledChanged,
      onEdit: onEdit,
      onDelete: onDelete,
      onMoveUp: onMoveUp,
      onMoveDown: onMoveDown,
    );
  }
}

class _TagRuleCard extends StatelessWidget {
  const _TagRuleCard({
    required this.rule,
    required this.onEnabledChanged,
    required this.onEdit,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
    super.key,
  });

  final ScoreTagRule rule;
  final ValueChanged<bool>? onEnabledChanged;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  @override
  Widget build(BuildContext context) {
    return _RuleCard(
      enabled: rule.enabled,
      color: RatingPresentationResolver.parseColor(rule.colorHex),
      title: rule.name,
      subtitle: '${_conditionDescription(rule)} · ${rule.colorHex}',
      onEnabledChanged: onEnabledChanged,
      onEdit: onEdit,
      onDelete: onDelete,
      onMoveUp: onMoveUp,
      onMoveDown: onMoveDown,
    );
  }
}

class _RuleCard extends StatelessWidget {
  const _RuleCard({
    required this.enabled,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onEnabledChanged,
    required this.onEdit,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  final bool enabled;
  final Color? color;
  final String title;
  final String subtitle;
  final ValueChanged<bool>? onEnabledChanged;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 4),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final summary = Row(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: color ?? colorScheme.onSurfaceVariant,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: colorScheme.outlineVariant,
                      width: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Opacity(
                    opacity: enabled ? 1 : 0.55,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
                Switch(value: enabled, onChanged: onEnabledChanged),
              ],
            );
            final actions = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _RuleAction(
                  tooltip: '上移',
                  onPressed: onMoveUp,
                  icon: Icons.arrow_upward,
                ),
                _RuleAction(
                  tooltip: '下移',
                  onPressed: onMoveDown,
                  icon: Icons.arrow_downward,
                ),
                _RuleAction(
                  tooltip: '编辑',
                  onPressed: onEdit,
                  icon: Icons.edit_outlined,
                ),
                _RuleAction(
                  tooltip: '删除',
                  onPressed: onDelete,
                  icon: Icons.delete_outline,
                ),
              ],
            );

            if (constraints.maxWidth < 560) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  summary,
                  const SizedBox(height: AppSpacing.xs),
                  Divider(
                    height: 0.5,
                    thickness: 0.5,
                    color:
                        colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                  Align(alignment: Alignment.centerRight, child: actions),
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: summary),
                const SizedBox(width: AppSpacing.sm),
                actions,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RuleAction extends StatelessWidget {
  const _RuleAction({
    required this.tooltip,
    required this.onPressed,
    required this.icon,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 19),
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        minimumSize: const Size(44, 44),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

String? _scoreValidator(String? value) {
  final score = double.tryParse(value?.trim() ?? '');
  if (score == null || !score.isFinite) return '请输入有效评分。';
  if (score < 0 || score > 10) return '评分需在 0–10 之间。';
  return null;
}

String _formatScore(double value) {
  return value == value.roundToDouble()
      ? value.toStringAsFixed(1)
      : value.toString();
}

String _conditionLabel(ScoreTagCondition condition) {
  return switch (condition) {
    ScoreTagCondition.gte => '大于等于（≥）',
    ScoreTagCondition.gt => '大于（>）',
    ScoreTagCondition.lte => '小于等于（≤）',
    ScoreTagCondition.lt => '小于（<）',
    ScoreTagCondition.betweenInclusive => '闭区间',
  };
}

String _conditionDescription(ScoreTagRule rule) {
  final threshold = _formatScore(rule.threshold);
  return switch (rule.condition) {
    ScoreTagCondition.gte => '评分 ≥ $threshold',
    ScoreTagCondition.gt => '评分 > $threshold',
    ScoreTagCondition.lte => '评分 ≤ $threshold',
    ScoreTagCondition.lt => '评分 < $threshold',
    ScoreTagCondition.betweenInclusive =>
      '$threshold ≤ 评分 ≤ ${_formatScore(rule.upperThreshold ?? rule.threshold)}',
  };
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              icon,
              size: 20,
              color: AppTheme.primary.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
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

class _InfoRowDivider extends StatelessWidget {
  const _InfoRowDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 0.5,
      thickness: 0.5,
      indent: 34,
      color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
    );
  }
}
