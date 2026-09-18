import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:recallio/services/cover_crop_service.dart';

void main() {
  late Directory temp;
  late CoverCropService service;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('recallio_crop_service_test_');
    service = CoverCropService(temporaryDirectory: temp);
  });

  tearDown(() async {
    await temp.delete(recursive: true);
  });

  Future<String> writeBytes(Uint8List bytes,
      [String name = 'source.png']) async {
    final file = File(p.join(temp.path, name));
    await file.writeAsBytes(bytes);
    return file.path;
  }

  Future<PreparedCover> prepare(img.Image image) async =>
      service.load(await writeBytes(img.encodePng(image)));

  group('source coordinate crop', () {
    for (final size in [(360, 240), (240, 360), (300, 300)]) {
      test('centers a ${size.$1} by ${size.$2} coordinate image', () async {
        final original = _coordinateImage(size.$1, size.$2);
        final source = await prepare(original);
        final width =
            size.$1 / size.$2 > 2 / 3 ? size.$2 * 2 / 3 : size.$1.toDouble();
        final height = width * 3 / 2;
        final rect = Rect.fromLTWH(
          (size.$1 - width) / 2,
          (size.$2 - height) / 2,
          width,
          height,
        );
        final result = img.decodeJpg(await service.crop(source, rect))!;

        expect(result.width * 3, result.height * 2);
        expect(result.width, lessThanOrEqualTo(width));
        expect(result.height, lessThanOrEqualTo(height));
        _expectSelectedPixels(result, original, rect);
      });
    }

    test('exports translated, zoomed and boundary selections from source',
        () async {
      final original = _coordinateImage(360, 480);
      final source = await prepare(original);
      for (final rect in [
        const Rect.fromLTWH(80, 90, 120, 180),
        const Rect.fromLTWH(101, 152, 40, 60),
        const Rect.fromLTWH(0, 0, 120, 180),
        const Rect.fromLTWH(240, 300, 120, 180),
        const Rect.fromLTWH(20.4, 30.6, 60.4, 90.6),
      ]) {
        final result = img.decodeJpg(await service.crop(source, rect))!;
        expect(result.width * 3, result.height * 2);
        _expectSelectedPixels(result, original, rect);
      }
    });

    test('rounds each selected boundary within half a source pixel', () {
      for (var index = 0; index < 100; index++) {
        final rect = Rect.fromLTWH(
          index / 100,
          22 + index / 137,
          63 + index / 75,
          (63 + index / 75) * 1.5,
        );
        final rounded = roundedCoverCropRect(
          rect,
          imageWidth: 200,
          imageHeight: 300,
        );
        expect((rect.left - rounded.left).abs(), lessThanOrEqualTo(0.5));
        expect((rect.top - rounded.top).abs(), lessThanOrEqualTo(0.5));
        expect((rect.right - rounded.right).abs(), lessThanOrEqualTo(0.5));
        expect((rect.bottom - rounded.bottom).abs(), lessThanOrEqualTo(0.5));
      }
    });

    test('does not upscale small images and keeps an exact 2:3 ratio',
        () async {
      for (final size in [(2, 3), (20, 30), (21, 32)]) {
        final source = await prepare(_solid(size.$1, size.$2, 25, 100, 200));
        final selection = Rect.fromLTWH(
          0,
          0,
          size.$1.toDouble(),
          size.$1 * 1.5,
        );
        final result = img.decodeJpg(await service.crop(source, selection))!;
        expect(result.width * 3, result.height * 2);
        expect(result.width, lessThanOrEqualTo(selection.width));
        expect(result.height, lessThanOrEqualTo(selection.height));
      }
    });

    test('caps preview at 1600 and JPEG at 1200 by 1800', () async {
      final source = await prepare(_solid(1300, 1950, 25, 100, 200));
      expect(source.width, 1300);
      expect(source.height, 1950);
      final preview = img.decodePng(source.previewBytes)!;
      expect(preview.height, 1600);
      expect(preview.width, 1067);

      final result = img.decodeJpg(
        await service.crop(source, const Rect.fromLTWH(0, 0, 1300, 1950)),
      )!;
      expect((result.width, result.height), (1200, 1800));
      _expectRgb(result.getPixel(100, 100), [25, 100, 200]);
    });

    test('rejects invalid and subpixel selections with a readable error',
        () async {
      final source = await prepare(_solid(20, 30, 25, 100, 200));
      for (final rect in [
        Rect.zero,
        const Rect.fromLTWH(0, 0, 1, 1.5),
        const Rect.fromLTWH(-1, 0, 20, 30),
        const Rect.fromLTWH(1, 0, 20, 30),
        const Rect.fromLTWH(0, 0, 20, 20),
        const Rect.fromLTWH(double.nan, 0, 20, 30),
      ]) {
        await expectLater(
          service.crop(source, rect),
          throwsA(isA<CoverCropException>()),
        );
      }
    });
  });

  group('normalized preview and export', () {
    test('composites transparent and semitransparent PNG pixels over white',
        () async {
      final original = img.Image(width: 60, height: 90, numChannels: 4);
      for (final pixel in original) {
        pixel.setRgba(255, 0, 0, pixel.x < 30 ? 0 : 128);
      }
      final source = await prepare(original);
      final preview = img.decodePng(source.previewBytes)!;
      final result = img.decodeJpg(
        await service.crop(source, const Rect.fromLTWH(0, 0, 60, 90)),
      )!;
      expect(preview.hasAlpha, isFalse);
      _expectRgb(preview.getPixel(10, 30), [255, 255, 255], tolerance: 0);
      _expectRgb(preview.getPixel(50, 30), [255, 127, 127], tolerance: 1);
      _expectRgb(result.getPixel(10, 30), [255, 255, 255]);
      _expectRgb(result.getPixel(50, 30), [255, 127, 127]);
    });

    for (final orientation in [6, 2]) {
      test('applies EXIF orientation $orientation exactly once', () async {
        final original = _coordinateImage(90, 60);
        // Encode the unrotated source pixels together with real EXIF metadata.
        // image 4.3.0's injectJpgExif omits APP1's marker when adding a block.
        final fixture = img.Image.from(original)
          ..exif.imageIfd.orientation = orientation;
        final withOrientation = img.encodeJpg(fixture, quality: 100);
        expect(img.decodeJpgExif(withOrientation)!.imageIfd.orientation,
            orientation);

        final source = await service.load(
          await writeBytes(withOrientation, 'oriented.jpg'),
        );
        final preview = img.decodePng(source.previewBytes)!;
        final expected = orientation == 6
            ? img.copyRotate(original, angle: 90)
            : img.flipHorizontal(img.Image.from(original));
        expect(
            (source.width, source.height), (expected.width, expected.height));
        for (final point in [(10, 10), (40, 40)]) {
          final reference = expected.getPixel(point.$1, point.$2);
          _expectRgb(preview.getPixel(point.$1, point.$2),
              [reference.r, reference.g, reference.b]);
        }
        final selection = orientation == 6
            ? const Rect.fromLTWH(0, 0, 60, 90)
            : const Rect.fromLTWH(25, 0, 40, 60);
        final result = img.decodeJpg(await service.crop(source, selection))!;
        _expectSelectedPixels(result, expected, selection);
        expect(result.exif.imageIfd.hasOrientation, isFalse);
      });
    }

    test('uses the first animation frame for both preview and final crop',
        () async {
      final animation = _solid(40, 60, 220, 20, 20)
        ..addFrame(_solid(40, 60, 20, 20, 220));
      final bytes = img.encodeGif(animation);
      expect(img.decodeGif(bytes)!.numFrames, 2);
      final source =
          await service.load(await writeBytes(bytes, 'animated.gif'));
      final preview = img.decodePng(source.previewBytes)!;
      final result = img.decodeJpg(
        await service.crop(source, const Rect.fromLTWH(0, 0, 40, 60)),
      )!;
      expect(preview.numFrames, 1);
      _expectRgb(preview.getPixel(20, 30), [220, 20, 20], tolerance: 10);
      _expectRgb(result.getPixel(20, 30), [220, 20, 20], tolerance: 10);
    });
  });

  group('file operations', () {
    test('missing and damaged files return Chinese errors', () async {
      await expectLater(
        service.load(p.join(temp.path, 'missing.png')),
        throwsA(isA<CoverCropException>().having(
          (error) => error.message,
          'message',
          contains('不存在'),
        )),
      );
      await expectLater(
        service.load(await writeBytes(Uint8List.fromList([1, 2, 3, 4]))),
        throwsA(isA<CoverCropException>().having(
          (error) => error.message,
          'message',
          contains('无法解析'),
        )),
      );
    });

    test('saved JPEG is byte-identical to preview and saves are unique',
        () async {
      final source = await prepare(_coordinateImage(60, 90));
      final jpeg = await service.crop(
        source,
        const Rect.fromLTWH(0, 0, 60, 90),
      );
      final paths = await Future.wait([service.save(jpeg), service.save(jpeg)]);
      expect(paths[0], isNot(paths[1]));
      for (final path in paths) {
        expect(p.extension(path), '.jpg');
        expect(await File(path).readAsBytes(), orderedEquals(jpeg));
      }
    });

    test('save failure has a readable Chinese error', () async {
      final occupied =
          await writeBytes(Uint8List.fromList([1]), 'not_a_folder');
      final failingService = CoverCropService(
        temporaryDirectory: Directory(occupied),
      );
      await expectLater(
        failingService.save(Uint8List.fromList([1, 2, 3])),
        throwsA(isA<CoverCropException>().having(
          (error) => error.message,
          'message',
          contains('无法保存'),
        )),
      );
    });
  });
}

img.Image _solid(int width, int height, int r, int g, int b) =>
    img.Image(width: width, height: height, numChannels: 3)
      ..clear(img.ColorRgb8(r, g, b));

img.Image _coordinateImage(int width, int height) {
  final result = img.Image(width: width, height: height, numChannels: 3);
  for (final pixel in result) {
    pixel.setRgb(
      (pixel.x * 230 / width).round(),
      (pixel.y * 230 / height).round(),
      (pixel.x ~/ 30 + pixel.y ~/ 30).isEven ? 80 : 180,
    );
  }
  return result;
}

void _expectSelectedPixels(img.Image actual, img.Image original, Rect rect) {
  final rounded = roundedCoverCropRect(
    rect,
    imageWidth: original.width,
    imageHeight: original.height,
  );
  for (final point in [(0.15, 0.18), (0.45, 0.54), (0.84, 0.81)]) {
    final x = (actual.width * point.$1).floor();
    final y = (actual.height * point.$2).floor();
    final expected = original.getPixel(
      rounded.left.toInt() + (x * rounded.width / actual.width).floor(),
      rounded.top.toInt() + (y * rounded.height / actual.height).floor(),
    );
    final pixel = actual.getPixel(x, y);
    // R and G encode source X and Y. The checkerboard B channel deliberately
    // creates visible landmarks, but JPEG ringing around those edges is lossy.
    expect(pixel.r, closeTo(expected.r, 6));
    expect(pixel.g, closeTo(expected.g, 6));
  }
}

void _expectRgb(img.Pixel pixel, List<num> rgb, {num tolerance = 6}) {
  expect(pixel.r, closeTo(rgb[0], tolerance));
  expect(pixel.g, closeTo(rgb[1], tolerance));
  expect(pixel.b, closeTo(rgb[2], tolerance));
}
