import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recallio/shared/widgets/color_picker_field.dart';

void main() {
  testWidgets('常用色板可即时预览并在确认后回传颜色', (tester) async {
    String? selected;
    var changeCount = 0;
    await _pumpField(
      tester,
      value: '#7B737D',
      onChanged: (value) {
        selected = value;
        changeCount++;
      },
    );

    await _openPicker(tester);
    await tester.tap(find.byKey(const ValueKey('color-preset-#9477A5')));
    await tester.pump();

    expect(find.text('#9477A5'), findsWidgets);
    expect(changeCount, 0);

    await tester.tap(find.byKey(const ValueKey('color-picker-confirm')));
    await tester.pumpAndSettle();

    expect(selected, '#9477A5');
    expect(changeCount, 1);
  });

  testWidgets('可精确输入 HEX 并规范为大写后确认', (tester) async {
    String? selected;
    await _pumpField(
      tester,
      value: '#7B737D',
      onChanged: (value) => selected = value,
    );

    await _openPicker(tester);
    await tester.enterText(
      find.byKey(const ValueKey('color-picker-hex-input')),
      '#abcdef',
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('color-picker-preview-value')),
      findsOneWidget,
    );
    expect(find.text('#ABCDEF'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('color-picker-confirm')));
    await tester.pumpAndSettle();

    expect(selected, '#ABCDEF');
  });

  testWidgets('取消会丢弃弹窗中的颜色修改', (tester) async {
    String? selected;
    var changeCount = 0;
    await _pumpField(
      tester,
      value: '#75879A',
      onChanged: (value) {
        selected = value;
        changeCount++;
      },
    );

    await _openPicker(tester);
    await tester.tap(find.byKey(const ValueKey('color-preset-#D0A64B')));
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();

    expect(selected, isNull);
    expect(changeCount, 0);
    expect(find.text('#75879A'), findsOneWidget);
  });

  testWidgets('可选颜色可清空并在确认后回传 null', (tester) async {
    String? selected = '#9477A5';
    var changeCount = 0;
    await _pumpField(
      tester,
      value: selected,
      allowClear: true,
      onChanged: (value) {
        selected = value;
        changeCount++;
      },
    );

    await _openPicker(tester);
    await tester.tap(find.byKey(const ValueKey('color-picker-clear')));
    await tester.pump();

    expect(find.text('未设置'), findsOneWidget);
    expect(changeCount, 0);

    await tester.tap(find.byKey(const ValueKey('color-picker-confirm')));
    await tester.pumpAndSettle();

    expect(selected, isNull);
    expect(changeCount, 1);
  });

  testWidgets('HSV 控件提供完整颜色调节入口', (tester) async {
    await _pumpField(
      tester,
      value: '#70968E',
      onChanged: (_) {},
    );

    await _openPicker(tester);

    expect(find.byKey(const ValueKey('color-picker-hue')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('color-picker-saturation')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('color-picker-value')), findsOneWidget);
  });
}

Future<void> _pumpField(
  WidgetTester tester, {
  required String? value,
  required ValueChanged<String?> onChanged,
  bool allowClear = false,
}) async {
  await tester.binding.setSurfaceSize(const Size(800, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 380,
            child: ColorPickerField(
              label: '评分颜色',
              helperText: '选择用于评分展示的颜色',
              value: value,
              allowClear: allowClear,
              onChanged: onChanged,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openPicker(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('color-picker-field-评分颜色')));
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('color-picker-dialog')), findsOneWidget);
}
