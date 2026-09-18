import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';

/// Section header: 3px accent bar + title, used above section content.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    this.trailing,
    super.key,
  });

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final heading = Row(
      children: [
        Container(
          width: 3,
          height: 18,
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child:
              Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
      ],
    );

    if (trailing == null) return heading;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: heading),
        const SizedBox(width: AppSpacing.md),
        trailing!,
      ],
    );
  }
}

/// Standard section container: card + [SectionHeader] + content.
class SectionCard extends StatelessWidget {
  const SectionCard({
    required this.title,
    required this.children,
    this.headerTrailing,
    super.key,
  });

  final String title;
  final List<Widget> children;
  final Widget? headerTrailing;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.brightness == Brightness.light
            ? AppTheme.cardLight
            : AppTheme.cardDark,
        borderRadius: AppRadius.card,
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.15),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: title, trailing: headerTrailing),
          const SizedBox(height: AppSpacing.lg),
          ...children,
        ],
      ),
    );
  }
}
