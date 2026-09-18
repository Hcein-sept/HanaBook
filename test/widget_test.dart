import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:recallio/app.dart';
import 'package:recallio/db/app_database.dart';
import 'package:recallio/features/record_edit/work_edit_page.dart';
import 'package:recallio/features/search/search_page.dart';
import 'package:recallio/features/work_detail/work_detail_page.dart';
import 'package:recallio/models/rating_presentation_config.dart';
import 'package:recallio/repositories/work_repository.dart';
import 'package:recallio/services/settings_service.dart';
import 'package:recallio/shared/widgets/work_card.dart';

void main() {
  final simplifiedItem = WorkRecordItem(
    work: const Work(
      id: 'work-1',
      type: 'anime',
      title: '蜂蜜与四叶草',
      originalTitle: 'ハチミツとクローバー',
      aliases: '["Honey and Clover"]',
      summary: '青春群像剧。',
      sourceProvider: 'manual',
      releaseDate: '2005',
      creators: '["J.C.STAFF"]',
      createdAt: '2026-06-19T10:00:00',
      updatedAt: '2026-06-19T10:00:00',
    ),
    record: const RecordEntry(
      id: 'record-1',
      workId: 'work-1',
      status: 'finished',
      rating: 9.5,
      shortComment: '旧短评',
      review: '我的评价',
      spoilerReview: '旧剧透',
      startDate: '2026-06-19',
      finishDate: '2026-06-20',
      progress: '全 24 话',
      platform: '本地',
      createdAt: '2026-06-19T10:00:00',
      updatedAt: '2026-06-19T10:00:00',
    ),
    tags: const [
      Tag(
        id: 'tag-1',
        name: '青春',
        createdAt: '2026-06-19T10:00:00',
        updatedAt: '2026-06-19T10:00:00',
      ),
    ],
  );

  testWidgets('HanaBook app shows home page', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workLibraryProvider.overrideWith((ref) => Stream.value(const [])),
          ratingPresentationConfigProvider.overrideWith(
            (ref) async => RatingPresentationConfig.empty,
          ),
        ],
        child: const RecallioApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('HanaBook'), findsOneWidget);
    expect(find.text('我的记录'), findsOneWidget);
    expect(find.text('新建记录'), findsOneWidget);
  });

  testWidgets('new record page shows simplified phase one fields', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workLibraryProvider.overrideWith((ref) => Stream.value(const [])),
        ],
        child: const RecallioApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('新建记录'));
    await tester.pumpAndSettle();

    expect(find.text('新建作品'), findsOneWidget);
    expect(find.text('作品'), findsOneWidget);
    expect(find.text('标题'), findsOneWidget);
    expect(find.text('类型'), findsOneWidget);
    expect(find.text('选择本地封面'), findsOneWidget);

    // Scroll down to rating section
    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pumpAndSettle();

    expect(find.text('我的评价'), findsOneWidget);
    expect(find.text('评分'), findsOneWidget);
    expect(find.text('评价'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pumpAndSettle();

    expect(find.text('记录日期'), findsOneWidget);

    for (final removedLabel in [
      '原名',
      '别名',
      '发售 / 放送 / 出版日期',
      '作者 / 制作组 / 开发商',
      '简介',
      '状态',
      '短评',
      '长评',
      '进度',
      '平台',
      '开始日期',
      '完成日期',
      '标签',
      '剧透笔记',
    ]) {
      expect(find.text(removedLabel), findsNothing);
    }
  });

  testWidgets('new record page validates record date', (tester) async {
    final router = GoRouter(
      initialLocation: '/works/new',
      routes: [
        GoRoute(
          path: '/works/new',
          builder: (context, state) => const WorkEditPage(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, '标题'),
      '测试作品',
    );
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    final dateField = tester.widget<TextFormField>(
      find.widgetWithText(TextFormField, '记录日期'),
    );
    dateField.controller?.text = '2026-02-31';

    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('记录日期格式应为 YYYY-MM-DD'), findsOneWidget);
  });

  testWidgets('work card only shows phase one summary fields', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workLibraryProvider.overrideWith((ref) => Stream.value(const [])),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: WorkCard(item: simplifiedItem, onTap: () {}),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('蜂蜜与四叶草'), findsOneWidget);
    expect(find.text('动画'), findsOneWidget);
    expect(find.text('9.5'), findsOneWidget);
    expect(find.text('我的评价'), findsOneWidget);
    expect(find.text('2026-06-19'), findsOneWidget);

    for (final hiddenText in [
      '想看',
      '看过',
      '旧短评',
      '全 24 话',
      '本地',
      '#青春',
      '旧剧透',
    ]) {
      expect(find.text(hiddenText), findsNothing);
    }
  });

  testWidgets('work detail page only shows phase one record fields', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/works/work-1',
      routes: [
        GoRoute(
          path: '/works/:id',
          builder: (context, state) {
            return WorkDetailPage(workId: state.pathParameters['id']!);
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workDetailProvider(
            'work-1',
          ).overrideWith((ref) => Stream.value(simplifiedItem)),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('蜂蜜与四叶草'), findsOneWidget);
    expect(find.text('动画'), findsOneWidget);
    expect(find.text('9.5'), findsOneWidget);
    expect(find.text('我的评价'), findsAtLeast(1));
    expect(find.text('评价'), findsOneWidget);
    expect(find.text('记录日期'), findsOneWidget);
    expect(find.text('2026-06-19'), findsOneWidget);

    for (final hiddenText in [
      '作品信息',
      'ハチミツとクローバー',
      'Honey and Clover',
      '青春群像剧。',
      '2005',
      'J.C.STAFF',
      '旧短评',
      '全 24 话',
      '本地',
      '青春',
      '旧剧透',
    ]) {
      expect(find.text(hiddenText), findsNothing);
    }
  });

  testWidgets('search page shows type dropdown with all five work types', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/search',
      routes: [
        GoRoute(
          path: '/search',
          builder: (context, state) => const SearchPage(),
        ),
        GoRoute(
          path: '/works/new',
          builder: (context, state) => const WorkEditPage(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('搜索导入'), findsOneWidget);
    expect(find.text('查找作品'), findsOneWidget);

    await tester.tap(find.text('动画'));
    await tester.pumpAndSettle();

    for (final label in ['动画', '漫画', '小说', '游戏', '电影']) {
      expect(find.text(label).last, findsOneWidget);
    }
  });

  testWidgets(
    'search page auto-selects correct default provider per type',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/search',
        routes: [
          GoRoute(
            path: '/search',
            builder: (context, state) => const SearchPage(),
          ),
          GoRoute(
            path: '/works/new',
            builder: (context, state) => const WorkEditPage(),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bangumi'), findsOneWidget);

      await tester.tap(find.text('动画'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('游戏').last);
      await tester.pumpAndSettle();
      expect(find.text('Steam'), findsOneWidget);

      await tester.tap(find.text('游戏'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('电影').last);
      await tester.pumpAndSettle();
      expect(find.text('TMDb'), findsOneWidget);
    },
  );

  testWidgets('search page shows error when searching with empty keyword', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/search',
      routes: [
        GoRoute(
          path: '/search',
          builder: (context, state) => const SearchPage(),
        ),
        GoRoute(
          path: '/works/new',
          builder: (context, state) => const WorkEditPage(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    // Scroll down to make the search button visible
    await tester.drag(find.byType(ListView), const Offset(0, -150));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, '搜索'));
    await tester.pumpAndSettle();

    expect(find.text('请输入搜索关键词。'), findsOneWidget);
  });

  testWidgets('search page shows manual create button', (tester) async {
    final router = GoRouter(
      initialLocation: '/search',
      routes: [
        GoRoute(
          path: '/search',
          builder: (context, state) => const SearchPage(),
        ),
        GoRoute(
          path: '/works/new',
          builder: (context, state) => const WorkEditPage(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('手动创建'), findsOneWidget);
  });
}
