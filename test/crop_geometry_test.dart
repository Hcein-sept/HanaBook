import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:recallio/features/record_edit/crop_geometry.dart';

void main() {
  const frame = Rect.fromLTWH(70, 95, 240, 360);

  group('initial framing', () {
    const sizes = [
      Size(1200, 700),
      Size(700, 1400),
      Size(901, 901),
      Size(8000, 31),
      Size(29, 6000),
    ];

    for (final size in sizes) {
      test('centers and fills the frame for $size', () {
        final geometry = CropGeometry(imageSize: size, cropRect: frame);

        expect(geometry.zoom, 1);
        _expectOffset(geometry.sourceCenter, size.center(Offset.zero));
        _expectCovered(geometry);
        expect(
          geometry.sourceRect.width / geometry.sourceRect.height,
          closeTo(2 / 3, 1e-9),
        );
        expect(
          geometry.imageRect.width / geometry.imageRect.height,
          closeTo(size.aspectRatio, 1e-9),
        );
        final fillsWidth =
            (geometry.imageRect.width - frame.width).abs() < 1e-7;
        final fillsHeight =
            (geometry.imageRect.height - frame.height).abs() < 1e-7;
        expect(fillsWidth || fillsHeight, isTrue);
      });
    }

    test('display coordinates invert to the exact source crop corners', () {
      final geometry = CropGeometry(
        imageSize: const Size(1700, 1100),
        cropRect: frame,
        zoom: 1.7,
        sourceCenter: const Offset(980, 420),
      );

      _expectOffset(
        geometry.sourcePointAt(frame.topLeft),
        geometry.sourceRect.topLeft,
      );
      _expectOffset(
        geometry.sourcePointAt(frame.bottomRight),
        geometry.sourceRect.bottomRight,
      );
      _expectOffset(
        geometry.sourcePointAt(geometry.imageRect.topLeft),
        Offset.zero,
      );
    });
  });

  group('zoom and pan', () {
    late CropGeometry geometry;

    setUp(() {
      geometry = CropGeometry(
        imageSize: const Size(1800, 1500),
        cropRect: frame,
      );
    });

    test('clamps zoom to 100%-300% including construction', () {
      for (final zoom in [-100.0, 0.0, 0.99, 1.0, 2.4, 3.0, 100.0]) {
        final expected = zoom.clamp(1.0, 3.0);
        final next = geometry.zoomAt(zoom, frame.center);
        expect(next.zoom, expected);
        _expectCovered(next);
        expect(
          CropGeometry(
            imageSize: geometry.imageSize,
            cropRect: frame,
            zoom: zoom,
          ).zoom,
          expected,
        );
      }
    });

    test('zoom preserves the source point under an off-center cursor', () {
      final focalPoint = frame.center + const Offset(30, -40);
      final anchor = geometry.sourcePointAt(focalPoint);

      final next = geometry.zoomAt(2.2, focalPoint);

      _expectOffset(next.sourcePointAt(focalPoint), anchor);
      _expectCovered(next);
    });

    test('gesture scale updates use the start zoom without compounding', () {
      final start = geometry.zoomAt(1.5, frame.center);
      final anchor = start.sourcePointAt(frame.center);
      var next = start;

      for (final gestureScale in [1.1, 1.2, 1.3]) {
        next = next.gestureAt(
          zoom: start.zoom * gestureScale,
          sourceAnchor: anchor,
          localFocalPoint: frame.center,
        );
        expect(next.zoom, closeTo(start.zoom * gestureScale, 1e-9));
      }

      expect(next.zoom, closeTo(1.95, 1e-9));
      _expectCovered(next);
    });

    test('two-finger movement pans even when gesture scale stays at one', () {
      final start = geometry.zoomAt(2, frame.center);
      final next = start.gestureAt(
        zoom: start.zoom,
        sourceAnchor: start.sourcePointAt(frame.center),
        localFocalPoint: frame.center + const Offset(24, -36),
      );

      _expectOffset(
        next.sourceCenter,
        start.sourceCenter - const Offset(24, -36) / start.scale,
      );
      expect(next.zoom, start.zoom);
      _expectCovered(next);
    });

    test('combined zoom and pan holds the gesture-start source anchor', () {
      final startFocal = frame.center + const Offset(-20, 35);
      final nextFocal = startFocal + const Offset(18, -21);
      final anchor = geometry.sourcePointAt(startFocal);
      final next = geometry.gestureAt(
        zoom: 1.8,
        sourceAnchor: anchor,
        localFocalPoint: nextFocal,
      );

      _expectOffset(next.sourcePointAt(nextFocal), anchor);
      _expectCovered(next);
    });

    test('all four edges clamp instead of exposing the background', () {
      final start = geometry.zoomAt(2, frame.center);
      const dragOffsets = [
        Offset(100000, 0),
        Offset(-100000, 0),
        Offset(0, 100000),
        Offset(0, -100000),
        Offset(100000, 100000),
        Offset(-100000, -100000),
      ];

      for (final offset in dragOffsets) {
        final next = start.gestureAt(
          zoom: start.zoom,
          sourceAnchor: start.sourceCenter,
          localFocalPoint: frame.center + offset,
        );

        _expectCovered(next);
        if (offset.dx > 0) expect(next.sourceRect.left, closeTo(0, 1e-7));
        if (offset.dx < 0) {
          expect(next.sourceRect.right, closeTo(start.imageSize.width, 1e-7));
        }
        if (offset.dy > 0) expect(next.sourceRect.top, closeTo(0, 1e-7));
        if (offset.dy < 0) {
          expect(next.sourceRect.bottom, closeTo(start.imageSize.height, 1e-7));
        }
      }
    });

    test('zooming out at an edge still guarantees complete coverage', () {
      final edge = CropGeometry(
        imageSize: geometry.imageSize,
        cropRect: frame,
        zoom: 3,
        sourceCenter: const Offset(-10000, 10000),
      );
      final next = edge.zoomAt(1, frame.topRight);

      _expectCovered(next);
      expect(next.zoom, 1);
    });
  });

  group('viewport changes', () {
    test('resizing and rotating preserve the original selected region', () {
      var geometry = CropGeometry(
        imageSize: const Size(2100, 1600),
        cropRect: frame,
        zoom: 1.9,
        sourceCenter: const Offset(1400, 650),
      );
      final selected = geometry.sourceRect;

      for (final viewport in [
        const Size(1200, 800),
        const Size(380, 700),
        const Size(700, 380),
        const Size(220, 240),
      ]) {
        geometry = geometry.withCropRect(CropGeometry.fitCropRect(viewport));
        _expectRect(geometry.sourceRect, selected);
        expect(geometry.zoom, 1.9);
        _expectCovered(geometry);
      }
    });

    test('scaling viewport units does not change the source region', () {
      final geometry = CropGeometry(
        imageSize: const Size(1400, 1800),
        cropRect: frame,
        zoom: 2.1,
        sourceCenter: const Offset(740, 720),
      );

      for (final pixelRatio in [1.0, 1.25, 2.0, 3.0]) {
        final next = geometry.withCropRect(Rect.fromLTWH(
          frame.left * pixelRatio,
          frame.top * pixelRatio,
          frame.width * pixelRatio,
          frame.height * pixelRatio,
        ));
        _expectRect(next.sourceRect, geometry.sourceRect);
        _expectOffset(
          next.sourcePointAt(frame.center * pixelRatio),
          geometry.sourceCenter,
        );
      }
    });

    test('fit frame stays centered and within width and height limits', () {
      for (final viewport in [
        const Size(1920, 1080),
        const Size(320, 300),
        const Size(150, 1000),
        const Size(2000, 100),
        const Size(20, 10),
      ]) {
        final rect = CropGeometry.fitCropRect(viewport);
        expect(rect.isEmpty, isFalse);
        expect(rect.width, lessThanOrEqualTo(400));
        expect(rect.width / rect.height, closeTo(2 / 3, 1e-9));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(viewport.width));
        expect(rect.bottom, lessThanOrEqualTo(viewport.height));
        _expectOffset(rect.center, viewport.center(Offset.zero));
      }
    });

    test('empty or invalid viewports have no crop frame', () {
      for (final viewport in [
        Size.zero,
        const Size(0, 400),
        const Size(400, 0),
        const Size(-20, 400),
        const Size(double.infinity, 400),
        const Size(double.nan, 400),
      ]) {
        expect(CropGeometry.fitCropRect(viewport), Rect.zero);
      }
    });
  });
}

void _expectCovered(CropGeometry geometry) {
  const epsilon = 1e-7;
  final source = geometry.sourceRect;
  final display = geometry.imageRect;
  final frame = geometry.cropRect;
  expect(source.left, greaterThanOrEqualTo(-epsilon));
  expect(source.top, greaterThanOrEqualTo(-epsilon));
  expect(source.right, lessThanOrEqualTo(geometry.imageSize.width + epsilon));
  expect(source.bottom, lessThanOrEqualTo(geometry.imageSize.height + epsilon));
  expect(display.left, lessThanOrEqualTo(frame.left + epsilon));
  expect(display.top, lessThanOrEqualTo(frame.top + epsilon));
  expect(display.right, greaterThanOrEqualTo(frame.right - epsilon));
  expect(display.bottom, greaterThanOrEqualTo(frame.bottom - epsilon));
}

void _expectOffset(Offset actual, Offset expected) {
  expect(actual.dx, closeTo(expected.dx, 1e-7));
  expect(actual.dy, closeTo(expected.dy, 1e-7));
}

void _expectRect(Rect actual, Rect expected) {
  _expectOffset(actual.topLeft, expected.topLeft);
  _expectOffset(actual.bottomRight, expected.bottomRight);
}
