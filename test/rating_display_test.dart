import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recallio/core/theme/app_theme.dart';
import 'package:recallio/models/rating_presentation_config.dart';
import 'package:recallio/services/settings_service.dart';
import 'package:recallio/shared/widgets/rating_display.dart';

Future<void> _pumpRating(
  WidgetTester tester,
  double rating,
  RatingPresentationConfig config,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ratingPresentationConfigProvider.overrideWith((ref) async => config),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: RatingDisplay(rating: rating)),
      ),
    ),
  );
  // Settle past the star color transition so assertions see the final color.
  await tester.pumpAndSettle();
}

ScoreColorRule _colorRule({
  required String id,
  required double min,
  required double max,
  required String color,
  int order = 0,
  bool enabled = true,
}) {
  return ScoreColorRule(
    id: id,
    minScore: min,
    maxScore: max,
    colorHex: color,
    enabled: enabled,
    order: order,
  );
}

ScoreTagRule _tagRule({
  required String id,
  required String name,
  required String color,
  required double threshold,
  bool enabled = true,
}) {
  return ScoreTagRule(
    id: id,
    name: name,
    colorHex: color,
    condition: ScoreTagCondition.gte,
    threshold: threshold,
    enabled: enabled,
    order: 0,
  );
}

void main() {
  testWidgets('all active stars use one matched pure color', (tester) async {
    final config = RatingPresentationConfig(
      colorRules: [
        _colorRule(id: 'custom', min: 0, max: 10, color: '#4F86C6'),
      ],
    );
    await _pumpRating(tester, 9, config);

    for (var index = 0; index < 5; index++) {
      final icon = tester.widget<Icon>(
        find.byKey(ValueKey('rating-star-$index')),
      );
      expect(icon.color, const Color(0xFF4F86C6));
    }
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('rating-number')))
          .style
          ?.color,
      const Color(0xFF4F86C6),
    );
  });

  testWidgets('score intervals come only from user configuration',
      (tester) async {
    final config = RatingPresentationConfig(
      colorRules: [
        _colorRule(id: 'first', min: 0, max: 5.9, color: '#555555'),
        _colorRule(id: 'second', min: 6, max: 10, color: '#A878C8'),
      ],
    );

    await _pumpRating(tester, 5.9, config);
    expect(
      tester.widget<Icon>(find.byKey(const ValueKey('rating-star-0'))).color,
      const Color(0xFF555555),
    );
    await _pumpRating(tester, 6, config);
    expect(
      tester.widget<Icon>(find.byKey(const ValueKey('rating-star-0'))).color,
      const Color(0xFFA878C8),
    );
  });

  testWidgets('only enabled matching user tags are rendered', (tester) async {
    final config = RatingPresentationConfig(
      tags: [
        _tagRule(
          id: 'visible',
          name: '我的标签',
          color: '#336699',
          threshold: 7.3,
        ),
        _tagRule(
          id: 'disabled',
          name: '停用标签',
          color: '#990000',
          threshold: 1,
          enabled: false,
        ),
        _tagRule(
          id: 'unmatched',
          name: '未匹配标签',
          color: '#009900',
          threshold: 9.6,
        ),
      ],
    );
    await _pumpRating(tester, 8.4, config);

    expect(find.text('我的标签'), findsOneWidget);
    expect(find.text('停用标签'), findsNothing);
    expect(find.text('未匹配标签'), findsNothing);
  });

  testWidgets('empty configuration stays neutral and renders no tags',
      (tester) async {
    await _pumpRating(tester, 10, RatingPresentationConfig.empty);

    final colors = [
      for (var index = 0; index < 5; index++)
        tester.widget<Icon>(find.byKey(ValueKey('rating-star-$index'))).color,
    ];
    expect(colors.toSet(), hasLength(1));
  });

  testWidgets('legacy inactive color does not override theme neutral stars',
      (tester) async {
    const config = RatingPresentationConfig(
      style: RatingPresentationStyle(inactiveStarColorHex: '#123456'),
    );
    await _pumpRating(tester, 2, config);

    final inactive =
        tester.widget<Icon>(find.byKey(const ValueKey('rating-star-1'))).color;
    expect(inactive, isNot(const Color(0xFF123456)));
  });
}
