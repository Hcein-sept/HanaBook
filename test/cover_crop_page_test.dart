import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:recallio/core/theme/app_theme.dart';
import 'package:recallio/features/record_edit/cover_crop_page.dart';
import 'package:recallio/services/cover_crop_service.dart';

const _viewport = ValueKey('crop-viewport');
const _frame = ValueKey('crop-frame');
const _sourceImage = ValueKey('crop-source-image');
const _slider = ValueKey('crop-zoom-slider');
const _preview = ValueKey('crop-preview-button');

class _MemoryCropService extends CoverCropService {
  _MemoryCropService() {
    final image = img.Image(width: 900, height: 600);
    img.fill(image, color: img.ColorRgb8(40, 100, 200));
    final png = img.encodePng(image);
    source = PreparedCover(
      sourceBytes: png,
      previewBytes: png,
      width: 900,
      height: 600,
    );
    resultBytes = img.encodeJpg(img.Image(width: 120, height: 180));
  }

  late PreparedCover source;
  late Uint8List resultBytes;
  Completer<PreparedCover>? loading;
  Completer<Uint8List>? cropping;
  Completer<String>? saving;
  Object? loadError;
  Object? saveError;
  final rectangles = <Rect>[];
  Uint8List? savedBytes;

  @override
  Future<PreparedCover> load(String sourcePath) async {
    if (loadError != null) throw loadError!;
    return loading == null ? source : loading!.future;
  }

  @override
  Future<Uint8List> crop(PreparedCover source, Rect sourceRect) async {
    rectangles.add(sourceRect);
    return cropping == null ? resultBytes : cropping!.future;
  }

  @override
  Future<String> save(Uint8List jpegBytes) async {
    if (saveError != null) throw saveError!;
    savedBytes = jpegBytes;
    return saving == null ? 'test-output.jpg' : saving!.future;
  }
}

Future<void> _open(
  WidgetTester tester,
  _MemoryCropService service, {
  ValueChanged<String?>? onResult,
}) async {
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light(),
    home: Builder(builder: (context) {
      return Scaffold(
        body: TextButton(
          onPressed: () async {
            final result = await Navigator.of(context).push<String>(
              MaterialPageRoute(
                builder: (_) => CoverCropPage(
                  sourcePath: 'fixture.png',
                  service: service,
                ),
              ),
            );
            onResult?.call(result);
          },
          child: const Text('打开裁剪'),
        ),
      );
    }),
  ));
  await tester.tap(find.text('打开裁剪'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void _expectRectClose(Rect actual, Rect expected) {
  expect(actual.left, closeTo(expected.left, 1e-6));
  expect(actual.top, closeTo(expected.top, 1e-6));
  expect(actual.right, closeTo(expected.right, 1e-6));
  expect(actual.bottom, closeTo(expected.bottom, 1e-6));
}

// Derive the visible selection from actual widget bounds, independently of the
// geometry implementation and the page/AppBar coordinate origin.
Rect _visibleSourceRect(WidgetTester tester, PreparedCover source) {
  final image = tester.getRect(find.byKey(_sourceImage));
  final frame = tester.getRect(find.byKey(_frame));
  return Rect.fromLTRB(
    (frame.left - image.left) / image.width * source.width,
    (frame.top - image.top) / image.height * source.height,
    (frame.right - image.left) / image.width * source.width,
    (frame.bottom - image.top) / image.height * source.height,
  );
}

void main() {
  testWidgets('dragging back from a clamped edge responds immediately',
      (tester) async {
    final service = _MemoryCropService();
    await _open(tester, service);
    await tester.pumpAndSettle();
    tester.widget<Slider>(find.byKey(_slider)).onChanged!(2);
    await tester.pump();
    final center = tester.getSize(find.byKey(_viewport)).center(Offset.zero);
    final detector = tester.widget<GestureDetector>(find.byKey(_viewport));
    detector.onScaleStart!(ScaleStartDetails(localFocalPoint: center));
    detector.onScaleUpdate!(ScaleUpdateDetails(
      localFocalPoint: center + const Offset(4000, 0),
      focalPointDelta: const Offset(4000, 0),
      pointerCount: 1,
    ));
    await tester.pump();
    expect(_visibleSourceRect(tester, service.source).left, closeTo(0, 1e-6));
    detector.onScaleUpdate!(ScaleUpdateDetails(
      localFocalPoint: center + const Offset(3990, 0),
      focalPointDelta: const Offset(-10, 0),
      pointerCount: 1,
    ));
    await tester.pump();
    expect(_visibleSourceRect(tester, service.source).left, greaterThan(1));
  });

  testWidgets('single fast mouse move preserves the entire drag distance',
      (tester) async {
    final service = _MemoryCropService();
    await _open(tester, service);
    await tester.pumpAndSettle();
    tester.widget<Slider>(find.byKey(_slider)).onChanged!(1.5);
    await tester.pump();
    final before = _visibleSourceRect(tester, service.source);
    final imageScale =
        tester.getSize(find.byKey(_sourceImage)).width / service.source.width;
    final mouse = await tester.startGesture(
      tester.getCenter(find.byKey(_frame)),
      kind: PointerDeviceKind.mouse,
    );
    await mouse.moveBy(const Offset(60, 30));
    await mouse.up();
    await tester.pumpAndSettle();
    _expectRectClose(
      _visibleSourceRect(tester, service.source),
      before.shift(const Offset(-60, -30) / imageScale),
    );
  });

  testWidgets('mouse drag and two-touch pinch work through pointer events',
      (tester) async {
    final service = _MemoryCropService();
    await _open(tester, service);
    await tester.pumpAndSettle();
    tester.widget<Slider>(find.byKey(_slider)).onChanged!(1.5);
    await tester.pump();
    final center = tester.getCenter(find.byKey(_frame));
    final before = _visibleSourceRect(tester, service.source);
    final mouse = await tester.startGesture(center,
        kind: PointerDeviceKind.mouse, pointer: 7);
    for (var i = 0; i < 6; i++) {
      await mouse.moveBy(const Offset(10, 5));
      await tester.pump(const Duration(milliseconds: 20));
    }
    await mouse.up();
    await tester.pumpAndSettle();
    final after = _visibleSourceRect(tester, service.source);
    expect(after.center.dx, lessThan(before.center.dx - 20));
    expect(after.center.dy, lessThan(before.center.dy - 10));

    await tester.tap(find.byKey(const ValueKey('crop-reset')));
    await tester.pumpAndSettle();
    final first =
        await tester.startGesture(center - const Offset(40, 0), pointer: 11);
    final second =
        await tester.startGesture(center + const Offset(40, 0), pointer: 12);
    for (var i = 1; i <= 5; i++) {
      await first.moveTo(center - Offset(40 + i * 8, 0));
      await second.moveTo(center + Offset(40 + i * 8, 0));
      await tester.pump(const Duration(milliseconds: 20));
    }
    final zoom = tester.widget<Slider>(find.byKey(_slider)).value;
    expect(zoom, inExclusiveRange(1.2, 2.5));
    await first.up();
    await second.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('pinch uses start zoom and follows two-finger translation',
      (tester) async {
    final service = _MemoryCropService();
    await _open(tester, service);
    await tester.pumpAndSettle();
    final center = tester.getSize(find.byKey(_viewport)).center(Offset.zero);
    final detector = tester.widget<GestureDetector>(find.byKey(_viewport));
    detector.onScaleStart!(ScaleStartDetails(localFocalPoint: center));
    for (final scale in [1.1, 1.2, 1.3]) {
      detector.onScaleUpdate!(ScaleUpdateDetails(
        localFocalPoint: center,
        scale: scale,
        pointerCount: 2,
      ));
      await tester.pump();
    }
    expect(
        tester.widget<Slider>(find.byKey(_slider)).value, closeTo(1.3, 1e-9));

    final before = _visibleSourceRect(tester, service.source);
    final current = tester.widget<GestureDetector>(find.byKey(_viewport));
    current.onScaleStart!(ScaleStartDetails(localFocalPoint: center));
    current.onScaleUpdate!(ScaleUpdateDetails(
      localFocalPoint: center + const Offset(20, 15),
      focalPointDelta: const Offset(20, 15),
      pointerCount: 2,
    ));
    await tester.pump();
    final after = _visibleSourceRect(tester, service.source);
    expect(after.left, lessThan(before.left));
    expect(after.top, lessThan(before.top));
    expect(after.width, closeTo(before.width, 1e-6));
    expect(after.height, closeTo(before.height, 1e-6));
  });

  testWidgets('wheel anchors image, slider clamps, reset restores coverage',
      (tester) async {
    final service = _MemoryCropService();
    await _open(tester, service);
    await tester.pumpAndSettle();
    final initial = _visibleSourceRect(tester, service.source);
    final frame = tester.getRect(find.byKey(_frame));
    final focal = frame.center + const Offset(20, 10);
    final imageBefore = tester.getRect(find.byKey(_sourceImage));
    final pointBefore = Offset(
      (focal.dx - imageBefore.left) / imageBefore.width * 900,
      (focal.dy - imageBefore.top) / imageBefore.height * 600,
    );
    await tester.sendEventToBinding(PointerScrollEvent(
      position: focal,
      scrollDelta: const Offset(0, -120),
    ));
    await tester.pump();
    final imageAfter = tester.getRect(find.byKey(_sourceImage));
    final pointAfter = Offset(
      (focal.dx - imageAfter.left) / imageAfter.width * 900,
      (focal.dy - imageAfter.top) / imageAfter.height * 600,
    );
    expect((pointAfter - pointBefore).distance, lessThan(1e-6));
    expect(tester.widget<Slider>(find.byKey(_slider)).value,
        inExclusiveRange(1, 1.2));

    tester.widget<Slider>(find.byKey(_slider)).onChanged!(3);
    await tester.pump();
    await tester.drag(find.byKey(_viewport), const Offset(2000, 2000));
    await tester.pumpAndSettle();
    final selected = _visibleSourceRect(tester, service.source);
    expect(selected.left, greaterThanOrEqualTo(-1e-6));
    expect(selected.top, greaterThanOrEqualTo(-1e-6));
    expect(selected.right, lessThanOrEqualTo(900 + 1e-6));
    expect(selected.bottom, lessThanOrEqualTo(600 + 1e-6));
    await tester.tap(find.byKey(const ValueKey('crop-reset')));
    await tester.pump();
    _expectRectClose(_visibleSourceRect(tester, service.source), initial);
    expect(find.text('100%'), findsOneWidget);
  });

  testWidgets('export matches visible frame across resize and device density',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 760);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final service = _MemoryCropService();
    await _open(tester, service);
    await tester.pumpAndSettle();
    tester.widget<Slider>(find.byKey(_slider)).onChanged!(1.8);
    await tester.pump();
    await tester.drag(find.byKey(_viewport), const Offset(-35, 25));
    await tester.pumpAndSettle();
    final expected = _visibleSourceRect(tester, service.source);
    for (final size in [const Size(390, 760), const Size(760, 390)]) {
      tester.view.physicalSize = size * 2;
      tester.view.devicePixelRatio = 2;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      _expectRectClose(_visibleSourceRect(tester, service.source), expected);
      final bounds = tester.getRect(find.byKey(_viewport));
      final frame = tester.getRect(find.byKey(_frame));
      expect(bounds.contains(frame.topLeft), isTrue);
      expect(bounds.contains(frame.bottomRight), isTrue);
      expect(frame.width / frame.height, closeTo(2 / 3, 1e-9));
      await tester.tap(find.byKey(_preview));
      await tester.pumpAndSettle();
      _expectRectClose(service.rectangles.last, expected);
      await tester.tap(find.text('重新截取'));
      await tester.pumpAndSettle();
      _expectRectClose(_visibleSourceRect(tester, service.source), expected);
    }
  });

  testWidgets('confirm saves exactly the preview bytes and returns its path',
      (tester) async {
    final service = _MemoryCropService();
    String? result;
    await _open(tester, service, onResult: (value) => result = value);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_preview));
    await tester.pumpAndSettle();
    final preview = tester.widget<Image>(
      find.byKey(const ValueKey('crop-result-image')),
    );
    final previewBytes = (preview.image as MemoryImage).bytes;
    expect(tester.widget<Slider>(find.byKey(_slider)).onChanged, isNull);
    await tester.tap(find.text('确认使用'));
    await tester.pumpAndSettle();
    expect(service.savedBytes, same(previewBytes));
    expect(result, 'test-output.jpg');
  });

  testWidgets('preview disabled while loading and late load after pop is safe',
      (tester) async {
    final service = _MemoryCropService()..loading = Completer<PreparedCover>();
    await _open(tester, service);
    expect(tester.widget<TextButton>(find.byKey(_preview)).onPressed, isNull);
    await tester.pageBack();
    await tester.pumpAndSettle();
    service.loading!.complete(service.source);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('打开裁剪'), findsOneWidget);
  });

  testWidgets('late crop after back cannot open a dialog or save',
      (tester) async {
    final service = _MemoryCropService()..cropping = Completer<Uint8List>();
    await _open(tester, service);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_preview));
    await tester.pump();
    expect(tester.widget<TextButton>(find.byKey(_preview)).onPressed, isNull);
    expect(tester.widget<Slider>(find.byKey(_slider)).onChanged, isNull);
    await tester.pageBack();
    await tester.pumpAndSettle();
    service.cropping!.complete(service.resultBytes);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(AlertDialog), findsNothing);
    expect(service.savedBytes, isNull);
  });

  testWidgets('load failure is visible and can be retried', (tester) async {
    final service = _MemoryCropService()
      ..loadError = const FormatException('无法解析封面图片');
    await _open(tester, service);
    await tester.pumpAndSettle();
    expect(find.text('无法解析封面图片'), findsOneWidget);
    expect(tester.widget<TextButton>(find.byKey(_preview)).onPressed, isNull);
    service.loadError = null;
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(find.byKey(_viewport), findsOneWidget);
  });

  testWidgets('save failure retains crop and enables retry', (tester) async {
    final service = _MemoryCropService()..saveError = Exception('disk full');
    await _open(tester, service);
    await tester.pumpAndSettle();
    tester.widget<Slider>(find.byKey(_slider)).onChanged!(1.5);
    await tester.pump();
    final before = _visibleSourceRect(tester, service.source);
    await tester.tap(find.byKey(_preview));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认使用'));
    await tester.pumpAndSettle();
    expect(find.text('裁剪或保存失败，请检查文件和存储空间后重试。'), findsOneWidget);
    expect(
        tester.widget<TextButton>(find.byKey(_preview)).onPressed, isNotNull);
    _expectRectClose(_visibleSourceRect(tester, service.source), before);
    expect(tester.takeException(), isNull);
  });
}
