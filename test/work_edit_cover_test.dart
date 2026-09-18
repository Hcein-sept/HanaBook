import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
import 'package:recallio/features/record_edit/cover_crop_page.dart';
import 'package:recallio/features/record_edit/work_edit_page.dart';
import 'package:recallio/shared/widgets/cover_image.dart';

const _pickerChannel = MethodChannel('miguelruivo.flutter.plugins.filepicker');

void main() {
  late Directory directory;
  late File original;
  late File replacement;
  late String croppedPath;

  setUp(() {
    directory =
        Directory.systemTemp.createTempSync('recallio_edit_cover_test_');
    final png = img.encodePng(img.Image(width: 2, height: 3));
    original = File('${directory.path}/original.png')..writeAsBytesSync(png);
    replacement = File('${directory.path}/replacement.png')
      ..writeAsBytesSync(png);
    croppedPath = '${directory.path}/cropped.png';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pickerChannel, null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pickerChannel, null);
    directory.deleteSync(recursive: true);
  });

  testWidgets('cancelled replacement preserves confirmed original for recrop', (
    tester,
  ) async {
    final observer = await _mountEditor(tester);
    _pickFile(original.path);
    await _openPicker(tester);
    expect(observer.sources, [original.path]);
    observer.finishCrop(croppedPath);
    await tester.pumpAndSettle();

    _pickFile(replacement.path);
    await _openPicker(tester);
    expect(observer.sources.last, replacement.path);
    observer.finishCrop(null);
    await tester.pumpAndSettle();
    expect(
        tester.widget<CoverImage>(find.byType(CoverImage)).path, croppedPath);

    await tester.tap(find.text('重新截取'));
    await tester.idle();
    expect(observer.sources, [original.path, replacement.path, original.path]);
    observer.finishCrop(null);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('cover thumbnail uses a full 2:3 image frame', (tester) async {
    final observer = await _mountEditor(tester);
    expect(
      tester.getSize(find.byKey(const ValueKey('work-cover-thumbnail'))),
      const Size(108, 162),
    );
    _pickFile(original.path);
    await _openPicker(tester);
    observer.finishCrop(croppedPath);
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byType(CoverImage)), const Size(108, 162));
    expect(
        tester.widget<CoverImage>(find.byType(CoverImage)).fit, BoxFit.contain);
  });

  testWidgets(
      'picker error is shown and choosing another image remains possible', (
    tester,
  ) async {
    final observer = await _mountEditor(tester);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pickerChannel, (_) async {
      throw PlatformException(code: 'permission_denied');
    });
    await _openPicker(tester);
    await tester.pumpAndSettle();
    expect(find.text('选择封面失败，请重新选择图片'), findsOneWidget);
    expect(observer.sources, isEmpty);

    _pickFile(original.path);
    await _openPicker(tester);
    expect(observer.sources, [original.path]);
    observer.finishCrop(null);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing original falls back to current cover with feedback', (
    tester,
  ) async {
    final observer = await _mountEditor(tester);
    _pickFile(original.path);
    await _openPicker(tester);
    observer.finishCrop(croppedPath);
    await tester.pumpAndSettle();

    original.copySync(croppedPath);
    original.deleteSync();
    await tester.tap(find.text('重新截取'));
    await tester.idle();
    expect(observer.sources.last, croppedPath);
    observer.finishCrop(null);
    await tester.pumpAndSettle();
    expect(find.text('原图已不可用，将使用当前封面重新截取'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing source and cover give a recoverable error',
      (tester) async {
    final observer = await _mountEditor(tester);
    _pickFile(original.path);
    await _openPicker(tester);
    observer.finishCrop(croppedPath);
    await tester.pumpAndSettle();

    original.deleteSync();
    await tester.tap(find.text('重新截取'));
    await tester.pumpAndSettle();
    expect(observer.sources.length, 1);
    expect(find.text('封面文件已不可用，请重新选择图片'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, '选择本地封面'),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('repeated requests while picker is open do not open it twice', (
    tester,
  ) async {
    final observer = await _mountEditor(tester);
    final result = Completer<List<Map<String, Object>>>();
    var calls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pickerChannel, (_) {
      calls++;
      return result.future;
    });
    final button = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, '选择本地封面'),
    );
    button.onPressed!();
    button.onPressed!();
    await tester.idle();
    expect(calls, 1);
    result.complete(_fileResult(original.path));
    await tester.idle();
    expect(observer.sources, [original.path]);
    observer.finishCrop(null);
    await tester.pumpAndSettle();
  });

  testWidgets('returning from picker after editor disposal does not navigate', (
    tester,
  ) async {
    final observer = await _mountEditor(tester);
    final result = Completer<List<Map<String, Object>>>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pickerChannel, (_) => result.future);
    await _openPicker(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    result.complete(_fileResult(original.path));
    await tester.pumpAndSettle();
    expect(observer.sources, isEmpty);
    expect(tester.takeException(), isNull);
  });
}

Future<_CropObserver> _mountEditor(WidgetTester tester) async {
  tester.view.physicalSize = const Size(900, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final observer = _CropObserver();
  final router = GoRouter(
    initialLocation: '/works/new',
    observers: [observer],
    routes: [
      GoRoute(
        path: '/works/new',
        builder: (_, __) => const WorkEditPage(),
      ),
    ],
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
  });
  await tester.pumpWidget(
    ProviderScope(child: MaterialApp.router(routerConfig: router)),
  );
  await tester.pumpAndSettle();
  return observer;
}

void _pickFile(String path) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_pickerChannel, (call) async {
    expect(call.method, 'image');
    return _fileResult(path);
  });
}

List<Map<String, Object>> _fileResult(String path) => [
      {'name': 'cover.png', 'path': path, 'size': 1},
    ];

Future<void> _openPicker(WidgetTester tester) async {
  await tester.tap(find.text('选择本地封面'));
  // Drain the plugin result without painting the crop page: entry-point tests
  // check navigation arguments/results, independently of image processing.
  await tester.idle();
}

class _CropObserver extends NavigatorObserver {
  final sources = <String>[];
  MaterialPageRoute<String>? _cropRoute;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is! MaterialPageRoute<String>) return;
    final page = route.builder(navigator!.context);
    if (page is! CoverCropPage) return;
    sources.add(page.sourcePath);
    _cropRoute = route;
  }

  void finishCrop(String? result) {
    expect(_cropRoute, isNotNull);
    navigator!.removeRoute(_cropRoute!, result);
    _cropRoute = null;
  }
}
