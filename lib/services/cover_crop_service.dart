import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

/// Dimensions and preview pixels use the same, EXIF-normalized coordinates.
class PreparedCover {
  const PreparedCover({
    required this.sourceBytes,
    required this.previewBytes,
    required this.width,
    required this.height,
  });

  final Uint8List sourceBytes;
  final Uint8List previewBytes;
  final int width;
  final int height;
}

class CoverCropException implements Exception {
  const CoverCropException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// CPU-heavy decoding, preview generation and JPEG encoding run off the UI
/// isolate. The original encoded bytes stay available for full-quality export.
class CoverCropService {
  const CoverCropService({this.temporaryDirectory});

  final Directory? temporaryDirectory;

  Future<PreparedCover> load(String sourcePath) async {
    final file = File(sourcePath);
    Uint8List bytes;
    try {
      if (!await file.exists()) {
        throw const CoverCropException('封面文件不存在，请重新选择图片');
      }
      bytes = await file.readAsBytes();
    } on CoverCropException {
      rethrow;
    } catch (_) {
      throw const CoverCropException('无法读取封面文件，请检查文件权限后重试');
    }

    try {
      return await compute(_prepareCover, bytes);
    } on CoverCropException {
      rethrow;
    } catch (_) {
      throw const CoverCropException('无法解析封面图片，请选择有效的图片文件');
    }
  }

  Future<Uint8List> crop(PreparedCover source, Rect sourceRect) async {
    // Transfer only bytes and numbers; do not send UI or decoded native images
    // into the worker isolate.
    final request = (
      bytes: source.sourceBytes,
      left: sourceRect.left,
      top: sourceRect.top,
      right: sourceRect.right,
      bottom: sourceRect.bottom,
    );
    try {
      return await compute(_cropCover, request);
    } on CoverCropException {
      rethrow;
    } catch (_) {
      throw const CoverCropException('无法截取封面图片，请重新选择图片后重试');
    }
  }

  Future<String> save(Uint8List jpegBytes) async {
    Directory? outputDirectory;
    try {
      // createTemp allocates a fresh directory atomically, so even simultaneous
      // confirmations never overwrite another crop or a user-owned image.
      outputDirectory = await (temporaryDirectory ?? Directory.systemTemp)
          .createTemp('recallio_crop_');
      final file = File(p.join(outputDirectory.path, 'cover.jpg'));
      await file.writeAsBytes(jpegBytes, flush: true);
      return file.path;
    } catch (_) {
      if (outputDirectory != null) {
        try {
          await outputDirectory.delete(recursive: true);
        } catch (_) {
          // Preserve the original save failure if cleanup also fails.
        }
      }
      throw const CoverCropException('无法保存裁剪结果，请检查可用空间后重试');
    }
  }
}

PreparedCover _prepareCover(Uint8List bytes) {
  final source = _decodeNormalized(bytes);
  var preview = source;
  const maxPreviewEdge = 1600;
  if (math.max(source.width, source.height) > maxPreviewEdge) {
    final ratio = maxPreviewEdge / math.max(source.width, source.height);
    preview = img.copyResize(
      source,
      width: math.max(1, (source.width * ratio).round()),
      height: math.max(1, (source.height * ratio).round()),
      interpolation: img.Interpolation.average,
    );
  }
  return PreparedCover(
    sourceBytes: bytes,
    previewBytes: img.encodePng(preview, singleFrame: true),
    width: source.width,
    height: source.height,
  );
}

img.Image _decodeNormalized(Uint8List bytes) {
  final decoded = img.decodeImage(bytes, frame: 0);
  if (decoded == null) {
    throw const CoverCropException('无法解析封面图片，请选择有效的图片文件');
  }

  // image 4.3.0 already bakes JPEG EXIF during decoding and clears orientation.
  // Other decoders may retain it; only bake an orientation still present here.
  final oriented = decoded.exif.imageIfd.hasOrientation &&
          decoded.exif.imageIfd.orientation != 1
      ? img.bakeOrientation(decoded)
      : decoded;
  final pixels = oriented.convert(
    format: img.Format.uint8,
    numChannels: oriented.hasAlpha ? 4 : 3,
    noAnimation: true,
  );
  if (!pixels.hasAlpha) {
    pixels.exif = img.ExifData();
    pixels.iccProfile = null;
    return pixels;
  }

  // Flatten before resizing so transparent color channels cannot produce dark
  // fringes and the editing preview has the same white background as the JPEG.
  final white = img.Image(
    width: pixels.width,
    height: pixels.height,
    numChannels: 3,
  )..clear(img.ColorRgb8(255, 255, 255));
  return img.compositeImage(white, pixels);
}

typedef _CropRequest = ({
  Uint8List bytes,
  double left,
  double top,
  double right,
  double bottom,
});

Uint8List _cropCover(_CropRequest request) {
  final source = _decodeNormalized(request.bytes);
  final selection = Rect.fromLTRB(
    request.left,
    request.top,
    request.right,
    request.bottom,
  );
  final cropRect = roundedCoverCropRect(
    selection,
    imageWidth: source.width,
    imageHeight: source.height,
  );
  final cropped = img.copyCrop(
    source,
    x: cropRect.left.toInt(),
    y: cropRect.top.toInt(),
    width: cropRect.width.toInt(),
    height: cropRect.height.toInt(),
  );

  // Round only the four source boundaries (at most half a source pixel each).
  // Then resample the whole selection to an exact 2:3 output. Rounding the
  // source width/height to multiples of 2/3 instead would shift its boundaries.
  final units = math.min(
    600,
    math
        .min(
          math.min(selection.width, cropRect.width) / 2,
          math.min(selection.height, cropRect.height) / 3,
        )
        .floor(),
  );
  if (units < 1) {
    throw const CoverCropException('裁剪范围太小，请缩小倍率或选择更大的图片');
  }
  final output = img.copyResize(
    cropped,
    width: units * 2,
    height: units * 3,
    interpolation: img.Interpolation.average,
  );
  return img.encodeJpg(output, quality: 92);
}

/// The cropper supplies EXIF-normalized source coordinates, not screen pixels.
/// Exposed for testing the only rounding applied to source selection edges.
@visibleForTesting
Rect roundedCoverCropRect(
  Rect selection, {
  required int imageWidth,
  required int imageHeight,
}) {
  const tolerance = 0.000001;
  if (!selection.isFinite ||
      selection.isEmpty ||
      selection.left < -tolerance ||
      selection.top < -tolerance ||
      selection.right > imageWidth + tolerance ||
      selection.bottom > imageHeight + tolerance ||
      (selection.width * 3 - selection.height * 2).abs() > tolerance) {
    throw const CoverCropException('裁剪范围无效，请重置后重试');
  }
  final result = Rect.fromLTRB(
    selection.left.round().clamp(0, imageWidth).toDouble(),
    selection.top.round().clamp(0, imageHeight).toDouble(),
    selection.right.round().clamp(0, imageWidth).toDouble(),
    selection.bottom.round().clamp(0, imageHeight).toDouble(),
  );
  if (result.width < 2 || result.height < 3) {
    throw const CoverCropException('裁剪范围太小，请缩小倍率或选择更大的图片');
  }
  return result;
}
