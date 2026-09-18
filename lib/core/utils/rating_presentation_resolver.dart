import 'dart:ui';

import '../../models/rating_presentation_config.dart';

class RatingPresentationResolver {
  const RatingPresentationResolver._();

  static String? resolveColorHex(
    double? score,
    RatingPresentationConfig config,
  ) {
    if (score == null || !isValidScore(score)) {
      return config.style.unmatchedColorHex;
    }

    ScoreColorRule? firstMatch;
    for (final rule in config.colorRules) {
      if (!rule.enabled || !rule.matches(score)) {
        continue;
      }
      if (firstMatch == null || rule.order < firstMatch.order) {
        firstMatch = rule;
      }
    }
    return firstMatch?.colorHex ?? config.style.unmatchedColorHex;
  }

  static List<ScoreTagRule> matchingTags(
    double? score,
    RatingPresentationConfig config,
  ) {
    if (score == null || !isValidScore(score)) {
      return const [];
    }

    final indexedMatches = config.tags.indexed
        .where(
          (entry) => entry.$2.enabled && entry.$2.matches(score),
        )
        .toList()
      ..sort((left, right) {
        final byOrder = left.$2.order.compareTo(right.$2.order);
        return byOrder != 0 ? byOrder : left.$1.compareTo(right.$1);
      });
    return [for (final entry in indexedMatches) entry.$2];
  }

  static Color? parseColor(String? colorHex) {
    if (colorHex == null || !isValidColorHex(colorHex)) {
      return null;
    }
    final digits = colorHex.trim().substring(1);
    final value = int.parse(digits, radix: 16);
    return Color(0xFF000000 | value);
  }
}
