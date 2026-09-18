import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recallio/models/rating_presentation_config.dart';
import 'package:recallio/services/settings_service.dart';
import 'package:recallio/shared/widgets/rating_input.dart';

void main() {
  testWidgets('manual input refreshes color tags preview and slider value',
      (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    const config = RatingPresentationConfig(
      colorRules: [
        ScoreColorRule(
          id: 'lower',
          minScore: 0,
          maxScore: 5.9,
          colorHex: '#334455',
          enabled: true,
          order: 0,
        ),
        ScoreColorRule(
          id: 'upper',
          minScore: 6,
          maxScore: 10,
          colorHex: '#AABBCC',
          enabled: true,
          order: 1,
        ),
      ],
      tags: [
        ScoreTagRule(
          id: 'custom-tag',
          name: '用户标签',
          colorHex: '#123456',
          condition: ScoreTagCondition.gte,
          threshold: 8,
          enabled: true,
          order: 0,
        ),
      ],
    );
    await _pumpRatingInput(tester, controller, config);

    final input = find.widgetWithText(
      TextFormField,
      '或手动输入（0-10，支持一位小数）',
    );
    await tester.enterText(input, '8.5');
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.byKey(const ValueKey('rating-number'))).data,
      '8.5',
    );
    expect(find.text('用户标签'), findsOneWidget);
    expect(tester.widget<Slider>(find.byType(Slider)).value, 8.5);
    expect(
      tester.widget<Icon>(find.byKey(const ValueKey('rating-star-0'))).color,
      const Color(0xFFAABBCC),
    );

    await tester.enterText(input, '4.0');
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.byKey(const ValueKey('rating-number'))).data,
      '4.0',
    );
    expect(find.text('用户标签'), findsNothing);
    expect(tester.widget<Slider>(find.byType(Slider)).value, 4);
    expect(
      tester.widget<Icon>(find.byKey(const ValueKey('rating-star-0'))).color,
      const Color(0xFF334455),
    );
  });

  testWidgets('zero is a valid rating and long tags wrap on narrow layouts',
      (tester) async {
    final controller = TextEditingController(text: '0.0');
    addTearDown(controller.dispose);
    const config = RatingPresentationConfig(
      tags: [
        ScoreTagRule(
          id: 'long-a',
          name: '用户自定义的较长标签一',
          colorHex: '#123456',
          condition: ScoreTagCondition.gte,
          threshold: 0,
          enabled: true,
          order: 0,
        ),
        ScoreTagRule(
          id: 'long-b',
          name: '用户自定义的较长标签二',
          colorHex: '#654321',
          condition: ScoreTagCondition.gte,
          threshold: 0,
          enabled: true,
          order: 1,
        ),
      ],
    );
    await _pumpRatingInput(tester, controller, config, width: 220);

    expect(
      tester.widget<Text>(find.byKey(const ValueKey('rating-number'))).data,
      '0.0',
    );
    expect(find.text('用户自定义的较长标签一'), findsOneWidget);
    expect(find.text('用户自定义的较长标签二'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpRatingInput(
  WidgetTester tester,
  TextEditingController controller,
  RatingPresentationConfig config, {
  double width = 500,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ratingPresentationConfigProvider.overrideWith((ref) async => config),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: RatingInput(controller: controller),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}
