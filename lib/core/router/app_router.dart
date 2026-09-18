import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/about/about_page.dart';
import '../../features/backup/backup_page.dart';
import '../../features/home/home_page.dart';
import '../../features/library/library_page.dart';
import '../../features/record_edit/work_edit_page.dart';
import '../../features/search/import_confirm_page.dart';
import '../../features/search/search_page.dart';
import '../../features/settings/settings_page.dart';
import '../../features/work_detail/work_detail_page.dart';
import '../../models/metadata_search_result.dart';
import '../theme/app_tokens.dart';

/// Tabs switch instantly; pushed pages fade in with a subtle 8px rise.
Page<void> _tabPage(Widget child) {
  return NoTransitionPage(child: child);
}

Page<void> _pushPage(Widget child, GoRouterState state) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 250),
    reverseTransitionDuration: AppMotion.normal,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: AppMotion.enter,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.02),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      pageBuilder: (context, state) => _tabPage(const HomePage()),
    ),
    GoRoute(
      path: '/library',
      pageBuilder: (context, state) => _tabPage(const LibraryPage()),
    ),
    GoRoute(
      path: '/search',
      pageBuilder: (context, state) => _tabPage(const SearchPage()),
    ),
    GoRoute(
      path: '/search/confirm',
      pageBuilder: (context, state) {
        final result = state.extra;
        if (result is! MetadataSearchResult) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.maybeOf(context)?.showSnackBar(
              const SnackBar(
                content: Text('无法确认导入：缺少搜索数据，请重新搜索。'),
              ),
            );
          });
          return _pushPage(const SearchPage(), state);
        }
        return _pushPage(ImportConfirmPage(initialResult: result), state);
      },
    ),
    GoRoute(
      path: '/works/new',
      pageBuilder: (context, state) => _pushPage(const WorkEditPage(), state),
    ),
    GoRoute(
      path: '/works/:id',
      pageBuilder: (context, state) {
        final workId = state.pathParameters['id'] ?? '';
        return _pushPage(WorkDetailPage(workId: workId), state);
      },
    ),
    GoRoute(
      path: '/works/:id/edit',
      pageBuilder: (context, state) {
        final workId = state.pathParameters['id'] ?? '';
        return _pushPage(WorkEditPage(workId: workId), state);
      },
    ),
    GoRoute(
      path: '/backup',
      pageBuilder: (context, state) => _tabPage(const BackupPage()),
    ),
    GoRoute(
      path: '/settings',
      pageBuilder: (context, state) => _tabPage(const SettingsPage()),
    ),
    GoRoute(
      path: '/about',
      pageBuilder: (context, state) => _pushPage(const AboutPage(), state),
    ),
  ],
);
