import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import 'pressable.dart';

/// Notebook-style card with the signature 3px accent bar on the leading edge.
class JournalCard extends StatelessWidget {
  const JournalCard({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.cardPadding),
    this.onTap,
    this.accentColor,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accent = accentColor ??
        AppTheme.primary.withValues(alpha: 0.35);

    final card = Container(
      decoration: BoxDecoration(
        color: colorScheme.brightness == Brightness.light
            ? AppTheme.cardLight
            : AppTheme.cardDark,
        borderRadius: AppRadius.card,
        border: Border(left: BorderSide(color: accent, width: 3)),
      ),
      padding: padding,
      child: child,
    );

    if (onTap == null) return card;
    return Pressable(
      onTap: onTap,
      borderRadius: AppRadius.card,
      child: card,
    );
  }
}
