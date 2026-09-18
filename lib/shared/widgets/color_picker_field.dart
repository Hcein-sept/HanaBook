import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// A controlled color field for editing opaque `#RRGGBB` values.
///
/// Changes made inside the picker stay local until the user confirms them.
/// When [allowClear] is true, confirming an empty selection calls [onChanged]
/// with `null`.
class ColorPickerField extends StatelessWidget {
  const ColorPickerField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.helperText,
    this.allowClear = false,
    this.enabled = true,
    super.key,
  });

  final String label;
  final String? helperText;
  final String? value;
  final ValueChanged<String?> onChanged;
  final bool allowClear;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final normalizedValue = _normalizeHex(value);
    final color = _parseHex(normalizedValue);
    final displayValue = normalizedValue ?? '未设置（使用主题中性色）';
    final colorScheme = Theme.of(context).colorScheme;

    // Custom three-part layout instead of InputDecorator: the floating-label
    // mechanics of InputDecorator draw the label inside the field when empty,
    // overlapping the current-value text.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: enabled
                    ? null
                    : colorScheme.onSurface.withValues(alpha: 0.38),
              ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Semantics(
          button: enabled,
          label: '$label，$displayValue',
          child: InkWell(
            key: ValueKey('color-picker-field-$label'),
            onTap: enabled ? () => _openPicker(context) : null,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: AnimatedOpacity(
              opacity: enabled ? 1 : 0.55,
              duration: AppMotion.fast,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).inputDecorationTheme.fillColor,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                  ),
                ),
                child: Row(
                  children: [
                    _ColorSwatch(
                      key: const ValueKey('color-picker-field-swatch'),
                      color: color,
                      size: 28,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        displayValue,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: normalizedValue == null
                              ? colorScheme.onSurfaceVariant
                              : null,
                          fontFeatures: const [
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Icon(
                      Icons.expand_more,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (helperText != null) ...[
          const SizedBox(height: 6),
          Text(
            helperText!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ],
    );
  }

  Future<void> _openPicker(BuildContext context) async {
    final result = await showDialog<_ColorPickerResult>(
      context: context,
      builder: (context) => _ColorPickerDialog(
        initialValue: _normalizeHex(value),
        allowClear: allowClear,
      ),
    );
    if (result != null) {
      onChanged(result.value);
    }
  }
}

class _ColorPickerDialog extends StatefulWidget {
  const _ColorPickerDialog({
    required this.initialValue,
    required this.allowClear,
  });

  final String? initialValue;
  final bool allowClear;

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  static const _pickerSeed = '#7B737D';

  late final TextEditingController _hexController;
  late HSVColor _hsvColor;
  late bool _isCleared;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    final initialValue = widget.initialValue;
    _isCleared = initialValue == null && widget.allowClear;
    final initialColor = _parseHex(initialValue ?? _pickerSeed)!;
    _hsvColor = HSVColor.fromColor(initialColor);
    _hexController = TextEditingController(
      text: initialValue ?? (widget.allowClear ? '' : _pickerSeed),
    );
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  Color get _previewColor => _hsvColor.toColor();

  bool get _canConfirm => _isCleared || _errorText == null;

  void _handleHexChanged(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty && widget.allowClear) {
      setState(() {
        _isCleared = true;
        _errorText = null;
      });
      return;
    }

    final normalized = _normalizeHex(trimmed);
    if (normalized == null) {
      setState(() {
        _isCleared = false;
        _errorText = '请输入 #RRGGBB 格式的颜色';
      });
      return;
    }

    setState(() {
      _isCleared = false;
      _errorText = null;
      _hsvColor = HSVColor.fromColor(_parseHex(normalized)!);
    });
  }

  void _selectHex(String hex) {
    final normalized = _normalizeHex(hex)!;
    setState(() {
      _isCleared = false;
      _errorText = null;
      _hsvColor = HSVColor.fromColor(_parseHex(normalized)!);
      _hexController.value = TextEditingValue(
        text: normalized,
        selection: TextSelection.collapsed(offset: normalized.length),
      );
    });
  }

  void _setHsv(HSVColor value) {
    final normalized = _hexFromColor(value.toColor());
    setState(() {
      _isCleared = false;
      _errorText = null;
      _hsvColor = value;
      _hexController.value = TextEditingValue(
        text: normalized,
        selection: TextSelection.collapsed(offset: normalized.length),
      );
    });
  }

  void _clearSelection() {
    setState(() {
      _isCleared = true;
      _errorText = null;
      _hexController.clear();
    });
  }

  void _confirm() {
    if (!_canConfirm) return;
    Navigator.of(context).pop(
      _ColorPickerResult(_isCleared ? null : _hexFromColor(_previewColor)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentHex = _isCleared ? null : _hexFromColor(_previewColor);

    return AlertDialog(
      key: const ValueKey('color-picker-dialog'),
      title: const Text('选择颜色'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PickerPreview(
                color: _isCleared ? null : _previewColor,
                value: currentHex,
              ),
              const SizedBox(height: 16),
              TextField(
                key: const ValueKey('color-picker-hex-input'),
                controller: _hexController,
                onChanged: _handleHexChanged,
                autocorrect: false,
                enableSuggestions: false,
                textCapitalization: TextCapitalization.characters,
                maxLength: 7,
                decoration: InputDecoration(
                  labelText: 'HEX 颜色',
                  hintText: '#9477A5',
                  errorText: _errorText,
                  counterText: '',
                ),
              ),
              const SizedBox(height: 18),
              Text('常用颜色', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final preset in _colorPresets)
                    _PresetSwatch(
                      preset: preset,
                      selected: currentHex == preset.hex,
                      onTap: () => _selectHex(preset.hex),
                    ),
                ],
              ),
              const SizedBox(height: 22),
              Text('完整颜色选择', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              _HsvSlider(
                key: const ValueKey('color-picker-hue'),
                label: '色相',
                valueLabel: '${_hsvColor.hue.round()}°',
                value: _hsvColor.hue,
                max: 360,
                color: _previewColor,
                onChanged: (value) => _setHsv(_hsvColor.withHue(value)),
              ),
              _HsvSlider(
                key: const ValueKey('color-picker-saturation'),
                label: '饱和度',
                valueLabel: '${(_hsvColor.saturation * 100).round()}%',
                value: _hsvColor.saturation,
                max: 1,
                color: _previewColor,
                onChanged: (value) => _setHsv(_hsvColor.withSaturation(value)),
              ),
              _HsvSlider(
                key: const ValueKey('color-picker-value'),
                label: '明度',
                valueLabel: '${(_hsvColor.value * 100).round()}%',
                value: _hsvColor.value,
                max: 1,
                color: _previewColor,
                onChanged: (value) => _setHsv(_hsvColor.withValue(value)),
              ),
              if (widget.allowClear) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const ValueKey('color-picker-clear'),
                    onPressed: _clearSelection,
                    icon: const Icon(Icons.colorize_outlined, size: 18),
                    label: const Text('清空颜色'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const ValueKey('color-picker-confirm'),
          onPressed: _canConfirm ? _confirm : null,
          style: FilledButton.styleFrom(minimumSize: const Size(88, 44)),
          child: const Text('确认'),
        ),
      ],
    );
  }
}

class _PickerPreview extends StatelessWidget {
  const _PickerPreview({required this.color, required this.value});

  final Color? color;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            _ColorSwatch(
              key: const ValueKey('color-picker-preview'),
              color: color,
              size: 42,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('当前预览', style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 2),
                Text(
                  value ?? '未设置',
                  key: const ValueKey('color-picker-preview-value'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({required this.color, required this.size, super.key});

  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final borderColor = Theme.of(context).colorScheme.outlineVariant;
    return AnimatedContainer(
      duration: AppMotion.fast,
      curve: AppMotion.standard,
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color ?? Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(size <= 30 ? 7 : 10),
        border: Border.all(color: borderColor),
      ),
      alignment: Alignment.center,
      child: color == null
          ? Icon(
              Icons.format_color_reset_outlined,
              size: size * 0.5,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            )
          : null,
    );
  }
}

class _PresetSwatch extends StatelessWidget {
  const _PresetSwatch({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  final _ColorPreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _parseHex(preset.hex)!;
    return Tooltip(
      message: '${preset.label} ${preset.hex}',
      child: Semantics(
        button: true,
        selected: selected,
        label: '${preset.label} ${preset.hex}',
        child: InkWell(
          key: ValueKey('color-preset-${preset.hex}'),
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context).colorScheme.outlineVariant,
                width: selected ? 2.5 : 1,
              ),
            ),
            alignment: Alignment.center,
            child: selected
                ? Icon(
                    Icons.check,
                    size: 19,
                    color: ThemeData.estimateBrightnessForColor(color) ==
                            Brightness.dark
                        ? Colors.white
                        : Colors.black87,
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

class _HsvSlider extends StatelessWidget {
  const _HsvSlider({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.max,
    required this.color,
    required this.onChanged,
    super.key,
  });

  final String label;
  final String valueLabel;
  final double value;
  final double max;
  final Color color;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
            const Spacer(),
            Text(
              valueLabel,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        Slider(
          value: value.clamp(0, max),
          min: 0,
          max: max,
          activeColor: color,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _ColorPickerResult {
  const _ColorPickerResult(this.value);

  final String? value;
}

class _ColorPreset {
  const _ColorPreset(this.label, this.hex);

  final String label;
  final String hex;
}

const _colorPresets = <_ColorPreset>[
  _ColorPreset('灰紫', '#7B737D'),
  _ColorPreset('蓝灰', '#75879A'),
  _ColorPreset('青灰', '#70968E'),
  _ColorPreset('绿色', '#7F9A78'),
  _ColorPreset('紫色', '#9477A5'),
  _ColorPreset('粉色', '#B78496'),
  _ColorPreset('橙色', '#C4885B'),
  _ColorPreset('金色', '#D0A64B'),
  _ColorPreset('红色', '#B96B6B'),
  _ColorPreset('深灰', '#555159'),
];

String? _normalizeHex(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  if (!RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(trimmed)) return null;
  return trimmed.toUpperCase();
}

Color? _parseHex(String? value) {
  final normalized = _normalizeHex(value);
  if (normalized == null) return null;
  return Color(0xFF000000 | int.parse(normalized.substring(1), radix: 16));
}

String _hexFromColor(Color color) {
  final rgb = color.toARGB32() & 0x00FFFFFF;
  return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}
