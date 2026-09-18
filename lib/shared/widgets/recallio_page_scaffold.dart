import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';

class RecallioPageScaffold extends StatelessWidget {
  const RecallioPageScaffold({
    required this.title,
    required this.child,
    this.actions,
    this.titleWidget,
    this.showNavBar = true,
    super.key,
  });

  final String title;
  final Widget child;
  final List<Widget>? actions;
  final Widget? titleWidget;
  final bool showNavBar;

  @override
  Widget build(BuildContext context) {
    final isRoot = _isRootPage(context);
    final canPop = context.canPop();

    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (!isRoot) {
          context.go('/');
        } else {
          _handleRootBack(context);
        }
      },
      child: CallbackShortcuts(
        bindings: _buildBindings(context, isRoot),
        child: Focus(
          autofocus: true,
          child: Scaffold(
            appBar: AppBar(
              leading: !isRoot
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                      onPressed: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/');
                        }
                      },
                    )
                  : null,
              title: titleWidget ?? Text(title),
              actions: actions,
            ),
            body: SafeArea(child: child),
            bottomNavigationBar:
                showNavBar ? const _RecallioBottomNav() : null,
          ),
        ),
      ),
    );
  }

  Map<ShortcutActivator, VoidCallback> _buildBindings(
    BuildContext context,
    bool isRoot,
  ) {
    final router = GoRouter.of(context);
    return {
      // Navigation shortcuts
      const SingleActivator(LogicalKeyboardKey.keyN, control: true): () {
        router.push('/works/new');
      },
      const SingleActivator(LogicalKeyboardKey.keyF, control: true): () {
        router.go('/search');
      },
      const SingleActivator(LogicalKeyboardKey.keyB, control: true): () {
        router.go('/backup');
      },
      const SingleActivator(LogicalKeyboardKey.digit1, control: true): () {
        router.go('/');
      },
      const SingleActivator(LogicalKeyboardKey.digit2, control: true): () {
        router.go('/library');
      },
      const SingleActivator(LogicalKeyboardKey.digit3, control: true): () {
        router.go('/search');
      },
      const SingleActivator(LogicalKeyboardKey.digit4, control: true): () {
        router.go('/backup');
      },
      const SingleActivator(LogicalKeyboardKey.digit5, control: true): () {
        router.go('/settings');
      },
      // Escape — go back or to home
      const SingleActivator(LogicalKeyboardKey.escape): () {
        if (isRoot) {
          _handleRootBack(context);
        } else if (router.canPop()) {
          router.pop();
        } else {
          router.go('/');
        }
      },
      // Delete — no global binding, handled per-page
      // Enter on focused buttons handled by Flutter
    };
  }

  bool _isRootPage(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    return path == '/' || path == '/library';
  }

  void _handleRootBack(BuildContext context) {
    final now = DateTime.now();
    if (_lastBackPress != null &&
        now.difference(_lastBackPress!) < const Duration(seconds: 3)) {
      SystemNavigator.pop();
    } else {
      _lastBackPress = now;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('再按一次退出 ${AppConstants.displayName}'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  static DateTime? _lastBackPress;
}

class _RecallioBottomNav extends StatelessWidget {
  const _RecallioBottomNav();

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.15),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (final item in _navItems)
                _NavItem(
                  item: item,
                  isSelected: location == item.path,
                  onTap: () => context.go(item.path),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final _NavData item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: AppMotion.normal,
        curve: AppMotion.enter,
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? item.filledIcon : item.icon,
              size: 22,
              color:
                  isSelected ? AppTheme.primary : colorScheme.onSurfaceVariant,
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                item.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NavData {
  const _NavData(this.label, this.icon, this.filledIcon, this.path);
  final String label;
  final IconData icon;
  final IconData filledIcon;
  final String path;
}

const _navItems = [
  _NavData('首页', Icons.home_outlined, Icons.home_rounded, '/'),
  _NavData(
    '作品库',
    Icons.collections_bookmark_outlined,
    Icons.collections_bookmark_rounded,
    '/library',
  ),
  _NavData('搜索', Icons.search_outlined, Icons.search, '/search'),
  _NavData('备份', Icons.archive_outlined, Icons.archive_rounded, '/backup'),
  _NavData(
    '设置',
    Icons.settings_outlined,
    Icons.settings_rounded,
    '/settings',
  ),
];
