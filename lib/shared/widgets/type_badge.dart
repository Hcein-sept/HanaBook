import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';

/// Unified work-type badge. Use [TypeBadge.onImage] over cover art.
class TypeBadge extends StatelessWidget {
  const TypeBadge(this.label, {super.key}) : onImage = false;

  const TypeBadge.onImage(this.label, {super.key}) : onImage = true;

  final String label;
  final bool onImage;

  @override
  Widget build(BuildContext context) {
    if (onImage) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          color: Colors.white.withValues(alpha: 0.2),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            height: 1.3,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(
          color: AppTheme.primary.withValues(alpha: 0.25),
          width: 0.5,
        ),
        borderRadius: AppRadius.badge,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: AppTheme.primary.withValues(alpha: 0.8),
          height: 1.3,
        ),
      ),
    );
  }
}
