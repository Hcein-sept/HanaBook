import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/utils/rating_presentation_resolver.dart';
import '../../models/rating_presentation_config.dart';
import '../../services/settings_service.dart';

class RatingDisplay extends ConsumerWidget {
  const RatingDisplay({
    required this.rating,
    this.size = 20,
    this.showNumber = true,
    this.interactive = false,
    this.onChanged,
    this.presentationConfig,
    super.key,
  });

  final double? rating;
  final double size;
  final bool showNumber;
  final bool interactive;
  final ValueChanged<double?>? onChanged;
  final RatingPresentationConfig? presentationConfig;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final RatingPresentationConfig config = presentationConfig ??
        ref.watch(ratingPresentationConfigProvider).when(
              data: (value) => value,
              loading: () => RatingPresentationConfig.empty,
              error: (_, __) => RatingPresentationConfig.empty,
            );
    final colorScheme = Theme.of(context).colorScheme;
    final activeColor = RatingPresentationResolver.parseColor(
          RatingPresentationResolver.resolveColorHex(rating, config),
        ) ??
        colorScheme.onSurfaceVariant.withValues(alpha: 0.62);
    final inactiveColor = colorScheme.onSurfaceVariant.withValues(alpha: 0.28);
    final tags = RatingPresentationResolver.matchingTags(rating, config);

    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(begin: activeColor, end: activeColor),
      duration: AppMotion.normal,
      curve: AppMotion.standard,
      builder: (context, animatedActive, _) {
        final resolvedActive = animatedActive ?? activeColor;
        final ratingRow = Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (int i = 0; i < 5; i++)
              GestureDetector(
                onTap: interactive
                    ? () {
                        final tapValue = (i + 1) * 2.0;
                        onChanged?.call(rating == tapValue ? null : tapValue);
                      }
                    : null,
                child: Padding(
                  padding: EdgeInsets.only(right: i < 4 ? 1 : 0),
                  child: Builder(
                    builder: (_) {
                      final icon = _starIcon(i);
                      return Icon(
                        icon,
                        key: ValueKey('rating-star-$i'),
                        size: size,
                        color: icon == Icons.star_border
                            ? inactiveColor
                            : resolvedActive,
                      );
                    },
                  ),
                ),
              ),
            if (showNumber && rating != null) ...[
              const SizedBox(width: 6),
              Text(
                rating!.toStringAsFixed(1),
                key: const ValueKey('rating-number'),
                style: TextStyle(
                  fontSize: size * 0.7,
                  fontWeight: FontWeight.w600,
                  color: resolvedActive,
                ),
              ),
            ],
          ],
        );

        if (tags.isEmpty) return ratingRow;
        return Wrap(
          spacing: size <= 14 ? 4 : 7,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ratingRow,
            for (final tag in tags) _RatingRuleTag(tag: tag, compact: size <= 14),
          ],
        );
      },
    );
  }

  IconData _starIcon(int index) {
    if (rating == null) return Icons.star_border;
    final starValue = (index + 1) * 2.0;
    final midValue = index * 2.0 + 1.0;

    if (rating! >= starValue) return Icons.star;
    if (rating! >= midValue) return Icons.star_half;
    return Icons.star_border;
  }

  static Widget compact(
    double? rating, {
    double size = 16,
    bool showNumber = true,
  }) {
    return RatingDisplay(
      rating: rating,
      size: size,
      showNumber: showNumber,
    );
  }

  static Widget hero(
    double? rating, {
    double size = 28,
    bool showNumber = true,
  }) {
    return RatingDisplay(
      rating: rating,
      size: size,
      showNumber: showNumber,
    );
  }
}

class RatingEmptyStar extends StatelessWidget {
  const RatingEmptyStar({this.size = 16, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.star_border,
      size: size,
      color: Theme.of(context)
          .colorScheme
          .onSurfaceVariant
          .withValues(alpha: 0.28),
    );
  }
}

class _RatingRuleTag extends StatelessWidget {
  const _RatingRuleTag({required this.tag, required this.compact});

  final ScoreTagRule tag;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = RatingPresentationResolver.parseColor(tag.colorHex)!;
    return Semantics(
      label: tag.name,
      child: Container(
        key: ValueKey('rating-tag-${tag.id}'),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 4 : 6,
          vertical: compact ? 1 : 2,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          border: Border.all(color: color.withValues(alpha: 0.34), width: 0.7),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          tag.name,
          style: TextStyle(
            color: color,
            fontSize: compact ? 9 : 10,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}
