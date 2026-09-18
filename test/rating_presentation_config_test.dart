import 'package:flutter_test/flutter_test.dart';
import 'package:recallio/core/utils/rating_presentation_resolver.dart';
import 'package:recallio/models/rating_presentation_config.dart';

void main() {
  const colorRule = ScoreColorRule(
    id: 'color-a',
    minScore: 2.5,
    maxScore: 7.5,
    colorHex: '#123456',
    enabled: true,
    order: 3,
  );
  const tagRule = ScoreTagRule(
    id: 'tag-a',
    name: '用户文字',
    colorHex: '#445566',
    condition: ScoreTagCondition.betweenInclusive,
    threshold: 4,
    upperThreshold: 8,
    enabled: true,
    order: 2,
  );

  group('RatingPresentationConfig JSON', () {
    test('empty contains no built-in color or semantic rule', () {
      expect(RatingPresentationConfig.empty.colorRules, isEmpty);
      expect(RatingPresentationConfig.empty.tags, isEmpty);
      expect(RatingPresentationConfig.empty.style.unmatchedColorHex, isNull);
      expect(
        RatingPresentationConfig.empty.style.inactiveStarColorHex,
        isNull,
      );
    });

    test('HanaBook defaults are ordinary color rules without tags', () {
      final defaults = RatingPresentationConfig.hanaBookDefaults;

      expect(defaults.tags, isEmpty);
      expect(defaults.style.isEmpty, isTrue);
      expect(defaults.colorRules, hasLength(5));
      expect(
        defaults.colorRules
            .map(
              (rule) => (
                rule.minScore,
                rule.maxScore,
                rule.colorHex,
                rule.enabled,
                rule.order,
              ),
            )
            .toList(),
        [
          (0, 5.9, '#7B737D', true, 0),
          (6, 6.9, '#75879A', true, 1),
          (7, 7.9, '#70968E', true, 2),
          (8, 8.9, '#9477A5', true, 3),
          (9, 10, '#D0A64B', true, 4),
        ],
      );
      expect(defaults.colorRules.every((rule) => rule.isValid), isTrue);
    });

    test('round trips all user-defined fields', () {
      const original = RatingPresentationConfig(
        colorRules: [colorRule],
        tags: [tagRule],
        style: RatingPresentationStyle(
          unmatchedColorHex: '#ABCDEF',
          inactiveStarColorHex: '#102030',
        ),
      );

      final decoded = RatingPresentationConfig.fromJson(original.toJson());

      expect(decoded.colorRules.single.id, colorRule.id);
      expect(decoded.colorRules.single.minScore, colorRule.minScore);
      expect(decoded.colorRules.single.maxScore, colorRule.maxScore);
      expect(decoded.colorRules.single.colorHex, colorRule.colorHex);
      expect(decoded.colorRules.single.enabled, isTrue);
      expect(decoded.colorRules.single.order, colorRule.order);
      expect(decoded.tags.single.id, tagRule.id);
      expect(decoded.tags.single.name, tagRule.name);
      expect(decoded.tags.single.condition, tagRule.condition);
      expect(decoded.tags.single.threshold, tagRule.threshold);
      expect(decoded.tags.single.upperThreshold, tagRule.upperThreshold);
      expect(decoded.style.unmatchedColorHex, '#ABCDEF');
      expect(decoded.style.inactiveStarColorHex, '#102030');
    });

    test('drops malformed rules and invalid style values independently', () {
      final decoded = RatingPresentationConfig.fromJson({
        'colorRules': [
          colorRule.toJson(),
          {
            ...colorRule.toJson(),
            'id': 'outside-range',
            'maxScore': 10.1,
          },
          {
            ...colorRule.toJson(),
            'id': 'bad-color',
            'colorHex': 'blue',
          },
          'not-a-rule',
        ],
        'tags': [
          tagRule.toJson(),
          {
            ...tagRule.toJson(),
            'id': 'bad-between',
            'upperThreshold': 3,
          },
          {
            ...tagRule.toJson(),
            'id': 'unknown-condition',
            'condition': 'equal',
          },
        ],
        'style': {
          'unmatchedColorHex': '#112233',
          'inactiveStarColorHex': '#xyzxyz',
        },
      });

      expect(decoded.colorRules.map((rule) => rule.id), ['color-a']);
      expect(decoded.tags.map((rule) => rule.id), ['tag-a']);
      expect(decoded.style.unmatchedColorHex, '#112233');
      expect(decoded.style.inactiveStarColorHex, isNull);
    });

    test('wrong top-level types safely produce an empty config', () {
      expect(RatingPresentationConfig.fromJson(null).isEmpty, isTrue);
      expect(RatingPresentationConfig.fromJson('invalid').isEmpty, isTrue);
      expect(
        RatingPresentationConfig.fromJson({
          'colorRules': 'invalid',
          'tags': 1,
          'style': false,
        }).isEmpty,
        isTrue,
      );
    });

    test('validates score bounds and full hex values', () {
      expect(isValidScore(0), isTrue);
      expect(isValidScore(10), isTrue);
      expect(isValidScore(-0.01), isFalse);
      expect(isValidScore(10.01), isFalse);
      expect(isValidScore(double.nan), isFalse);
      expect(isValidScore(double.infinity), isFalse);
      expect(isValidColorHex('#aBc123'), isTrue);
      expect(isValidColorHex('#80aBc123'), isFalse);
      expect(isValidColorHex('#abc'), isFalse);
      expect(isValidColorHex('aBc123'), isFalse);
    });
  });

  group('RatingPresentationResolver', () {
    test('uses the first matching enabled color rule by order', () {
      const config = RatingPresentationConfig(
        colorRules: [
          ScoreColorRule(
            id: 'later',
            minScore: 0,
            maxScore: 10,
            colorHex: '#AAAAAA',
            enabled: true,
            order: 20,
          ),
          ScoreColorRule(
            id: 'disabled',
            minScore: 0,
            maxScore: 10,
            colorHex: '#BBBBBB',
            enabled: false,
            order: 0,
          ),
          ScoreColorRule(
            id: 'first',
            minScore: 5,
            maxScore: 8,
            colorHex: '#CCCCCC',
            enabled: true,
            order: 10,
          ),
        ],
        style: RatingPresentationStyle(unmatchedColorHex: '#DDDDDD'),
      );

      expect(
        RatingPresentationResolver.resolveColorHex(6, config),
        '#CCCCCC',
      );
      expect(
        RatingPresentationResolver.resolveColorHex(null, config),
        '#DDDDDD',
      );
      expect(
        RatingPresentationResolver.resolveColorHex(11, config),
        '#DDDDDD',
      );
    });

    test('returns null when no color rule or fallback was configured', () {
      expect(
        RatingPresentationResolver.resolveColorHex(
          7,
          RatingPresentationConfig.empty,
        ),
        isNull,
      );
    });

    test('returns every enabled matching tag in user order', () {
      const config = RatingPresentationConfig(
        tags: [
          ScoreTagRule(
            id: 'gte',
            name: 'A',
            colorHex: '#111111',
            condition: ScoreTagCondition.gte,
            threshold: 5,
            enabled: true,
            order: 2,
          ),
          ScoreTagRule(
            id: 'between',
            name: 'B',
            colorHex: '#222222',
            condition: ScoreTagCondition.betweenInclusive,
            threshold: 5,
            upperThreshold: 7,
            enabled: true,
            order: 1,
          ),
          ScoreTagRule(
            id: 'disabled',
            name: 'C',
            colorHex: '#333333',
            condition: ScoreTagCondition.lt,
            threshold: 8,
            enabled: false,
            order: 0,
          ),
          ScoreTagRule(
            id: 'gt',
            name: 'D',
            colorHex: '#444444',
            condition: ScoreTagCondition.gt,
            threshold: 6,
            enabled: true,
            order: 3,
          ),
        ],
      );

      expect(
        RatingPresentationResolver.matchingTags(6, config).map((tag) => tag.id),
        ['between', 'gte'],
      );
      expect(RatingPresentationResolver.matchingTags(null, config), isEmpty);
    });

    test('supports each tag comparison without adding semantics', () {
      const base = {
        'id': 'rule',
        'name': 'user value',
        'colorHex': '#123456',
        'threshold': 5.0,
        'enabled': true,
        'order': 0,
      };
      ScoreTagRule rule(ScoreTagCondition condition) =>
          ScoreTagRule.tryFromJson({...base, 'condition': condition.name})!;

      expect(rule(ScoreTagCondition.gte).matches(5), isTrue);
      expect(rule(ScoreTagCondition.gt).matches(5), isFalse);
      expect(rule(ScoreTagCondition.lte).matches(5), isTrue);
      expect(rule(ScoreTagCondition.lt).matches(5), isFalse);
    });

    test('parses six digit colors and rejects invalid input', () {
      expect(
        RatingPresentationResolver.parseColor('#123456')?.toARGB32(),
        0xFF123456,
      );
      expect(
        RatingPresentationResolver.parseColor('#80123456')?.toARGB32(),
        isNull,
      );
      expect(RatingPresentationResolver.parseColor('#123'), isNull);
      expect(RatingPresentationResolver.parseColor(null), isNull);
    });
  });
}
