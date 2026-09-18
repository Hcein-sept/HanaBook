import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:recallio/features/settings/settings_page.dart';
import 'package:recallio/models/rating_presentation_config.dart';
import 'package:recallio/services/settings_service.dart';

void main() {
  late _FakeSettingsService service;

  setUp(() {
    service = _FakeSettingsService();
  });

  testWidgets('首次配置提供五条可编辑颜色规则且不创建 Tag', (tester) async {
    await _pumpSettingsPage(tester, service);

    await _scrollTo(tester, '未匹配评分颜色（可选）');
    expect(
      find.byKey(
        const ValueKey('color-picker-field-未匹配评分颜色（可选）'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('未点亮星颜色'), findsNothing);

    await _scrollTo(tester, '评分颜色规则');
    expect(find.text('0.0 – 5.9'), findsOneWidget);
    expect(find.text('6.0 – 6.9'), findsOneWidget);
    expect(find.text('7.0 – 7.9'), findsOneWidget);
    expect(find.text('8.0 – 8.9'), findsOneWidget);
    expect(find.text('9.0 – 10.0'), findsOneWidget);

    await _scrollTo(tester, '实时预览');
    expect(find.text('8.7'), findsOneWidget);
    expect(find.text('9.6'), findsOneWidget);

    await _scrollTo(tester, '评分 Tag 规则');
    expect(find.text('尚未配置评分 Tag 规则。'), findsOneWidget);
    expect(find.textContaining('高分'), findsNothing);
    expect(service.config.tags, isEmpty);
  });

  testWidgets('可通过统一颜色选择器添加并保存颜色与 Tag 规则', (tester) async {
    service.config = RatingPresentationConfig.empty;
    await _pumpSettingsPage(tester, service);

    await _scrollTo(tester, '未匹配评分颜色（可选）');
    await _chooseHex(tester, '未匹配评分颜色（可选）', '#333333');

    await _scrollTo(tester, '添加规则');
    await tester.tap(find.widgetWithText(OutlinedButton, '添加规则'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, '最低评分'),
      '0',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '最高评分'),
      '5.9',
    );
    await _chooseHex(tester, '颜色', '#555555');
    await tester.tap(find.widgetWithText(FilledButton, '确定'));
    await tester.pumpAndSettle();
    expect(find.text('0.0 – 5.9'), findsOneWidget);

    await _scrollTo(tester, '添加 Tag');
    await tester.tap(find.widgetWithText(OutlinedButton, '添加 Tag'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Tag 名称'),
      '我的标签',
    );
    await _chooseHex(tester, 'Tag 颜色', '#4F86C6');
    await tester.enterText(
      find.widgetWithText(TextFormField, '评分阈值'),
      '8',
    );
    await tester.tap(find.widgetWithText(FilledButton, '确定'));
    await tester.pumpAndSettle();
    expect(find.text('我的标签'), findsWidgets);
    expect(find.textContaining('评分 ≥ 8.0'), findsOneWidget);

    await _scrollTo(tester, '保存评分展示设置');
    await tester.tap(
      find.widgetWithText(FilledButton, '保存评分展示设置'),
    );
    await tester.pumpAndSettle();

    final saved = service.config;
    expect(saved.colorRules, hasLength(1));
    expect(saved.colorRules.single.colorHex, '#555555');
    expect(saved.tags, hasLength(1));
    expect(saved.tags.single.name, '我的标签');
    expect(saved.tags.single.threshold, 8);
    expect(saved.style.unmatchedColorHex, '#333333');
    expect(saved.style.inactiveStarColorHex, isNull);
  });

  testWidgets('编辑规则后实时预览立即使用统一评分解析结果', (tester) async {
    service.config = const RatingPresentationConfig(
      colorRules: [
        ScoreColorRule(
          id: 'preview-rule',
          minScore: 8,
          maxScore: 8.9,
          colorHex: '#111111',
          enabled: true,
          order: 0,
        ),
      ],
    );
    await _pumpSettingsPage(tester, service);

    await _scrollTo(tester, '实时预览');
    expect(_previewStar(tester, '8.7').color, const Color(0xFF111111));

    await _scrollTo(tester, '8.0 – 8.9');
    await tester.tap(find.byTooltip('编辑'));
    await tester.pumpAndSettle();
    await _chooseHex(tester, '颜色', '#ABCDEF');
    await tester.tap(find.widgetWithText(FilledButton, '确定'));
    await tester.pumpAndSettle();

    await _scrollTo(tester, '实时预览');
    expect(_previewStar(tester, '8.7').color, const Color(0xFFABCDEF));
    expect(service.config.colorRules.single.colorHex, '#111111');
  });

  testWidgets('颜色规则可重排并全部删除后保存为空配置', (tester) async {
    service.config = const RatingPresentationConfig(
      colorRules: [
        ScoreColorRule(
          id: 'first',
          minScore: 0,
          maxScore: 10,
          colorHex: '#111111',
          enabled: true,
          order: 0,
        ),
        ScoreColorRule(
          id: 'second',
          minScore: 8,
          maxScore: 9,
          colorHex: '#222222',
          enabled: true,
          order: 1,
        ),
      ],
    );
    await _pumpSettingsPage(tester, service);

    await _scrollTo(tester, '0.0 – 10.0');
    final firstCard = find.ancestor(
      of: find.text('0.0 – 10.0'),
      matching: find.byType(Card),
    );
    await tester.tap(
      find.descendant(of: firstCard, matching: find.byTooltip('下移')),
    );
    await tester.pumpAndSettle();

    await _scrollTo(tester, '实时预览');
    expect(_previewStar(tester, '8.7').color, const Color(0xFF222222));

    await _scrollTo(tester, '0.0 – 10.0');
    await tester.tap(
      find.descendant(
        of: find.ancestor(
          of: find.text('0.0 – 10.0'),
          matching: find.byType(Card),
        ),
        matching: find.byTooltip('删除'),
      ),
    );
    await tester.pumpAndSettle();

    await _scrollTo(tester, '8.0 – 9.0');
    await tester.tap(
      find.descendant(
        of: find.ancestor(
          of: find.text('8.0 – 9.0'),
          matching: find.byType(Card),
        ),
        matching: find.byTooltip('删除'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('尚未配置评分颜色规则。'), findsOneWidget);
    await _scrollTo(tester, '保存评分展示设置');
    await tester.tap(
      find.widgetWithText(FilledButton, '保存评分展示设置'),
    );
    await tester.pumpAndSettle();

    expect(service.config.colorRules, isEmpty);
  });
}

Future<void> _pumpSettingsPage(
  WidgetTester tester,
  _FakeSettingsService service,
) async {
  await tester.binding.setSurfaceSize(const Size(900, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final router = GoRouter(
    initialLocation: '/settings',
    routes: [
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsPage(),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [settingsServiceProvider.overrideWithValue(service)],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeSettingsService extends SettingsService {
  RatingPresentationConfig config = RatingPresentationConfig.hanaBookDefaults;

  @override
  Future<String?> readTmdbToken() async => null;

  @override
  Future<RatingPresentationConfig> readRatingPresentationConfig() async =>
      config;

  @override
  Future<void> saveRatingPresentationConfig(
    RatingPresentationConfig config,
  ) async {
    this.config = config;
  }
}

Future<void> _chooseHex(
  WidgetTester tester,
  String fieldLabel,
  String colorHex,
) async {
  await tester.tap(find.byKey(ValueKey('color-picker-field-$fieldLabel')));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const ValueKey('color-picker-hex-input')),
    colorHex,
  );
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('color-picker-confirm')));
  await tester.pumpAndSettle();
}

Icon _previewStar(WidgetTester tester, String score) {
  final preview = find.byKey(ValueKey('rating-color-preview-$score'));
  return tester.widget<Icon>(
    find.descendant(
      of: preview,
      matching: find.byKey(const ValueKey('rating-star-0')),
    ),
  );
}

Future<void> _scrollTo(WidgetTester tester, String text) async {
  await tester.scrollUntilVisible(
    find.text(text),
    240,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}
