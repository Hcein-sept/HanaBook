import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../shared/widgets/recallio_page_scaffold.dart';
import '../../shared/widgets/section_card.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return RecallioPageScaffold(
      title: '关于 ${AppConstants.displayName}',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageHorizontal,
          AppSpacing.sm,
          AppSpacing.pageHorizontal,
          AppSpacing.xl,
        ),
        children: [
          // App identity
          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
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
              children: [
                Icon(
                  Icons.auto_stories,
                  size: 56,
                  color: AppTheme.primary.withValues(alpha: 0.7),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  AppConstants.displayName,
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'v0.1.0 · 个人作品记录工具',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: AppSpacing.lg),
                const Text(
                  '${AppConstants.displayName} 是一个本地优先的个人作品记录工具，适用于记录动画、漫画、小说和游戏。',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Privacy statement
          SectionCard(
            title: '隐私声明',
            children: [
              Text(
                '${AppConstants.displayName} 默认将数据保存在当前设备本地。除非你主动使用外部搜索功能，否则应用不会访问网络。请定期导出备份包，以便迁移设备或防止数据丢失。',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
