import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

/// Maps the viewport crop frame to the orientation-corrected source image.
///
/// [zoom] is relative to the smallest scale that covers [cropRect]. Keeping
/// this state in source coordinates makes it independent of pixel density and
/// lets a resized viewport preserve the selected source region.
@immutable
class CropGeometry {
  factory CropGeometry({
    required Size imageSize,
    required Rect cropRect,
    double zoom = minZoom,
    Offset? sourceCenter,
  }) {
    if (!imageSize.isFinite || imageSize.isEmpty) {
      throw ArgumentError.value(imageSize, 'imageSize', 'Must be positive');
    }
    if (!cropRect.isFinite || cropRect.isEmpty) {
      throw ArgumentError.value(cropRect, 'cropRect', 'Must be positive');
    }
    final clampedZoom = _clampZoom(zoom);
    final scale = _baseScale(imageSize, cropRect) * clampedZoom;
    final halfWidth = math.min(imageSize.width / 2, cropRect.width / scale / 2);
    final halfHeight =
        math.min(imageSize.height / 2, cropRect.height / scale / 2);
    final center = sourceCenter ?? imageSize.center(Offset.zero);
    if (!center.isFinite) {
      throw ArgumentError.value(center, 'sourceCenter', 'Must be finite');
    }
    return CropGeometry._(
      imageSize: imageSize,
      cropRect: cropRect,
      zoom: clampedZoom,
      sourceCenter: Offset(
        center.dx.clamp(halfWidth, imageSize.width - halfWidth),
        center.dy.clamp(halfHeight, imageSize.height - halfHeight),
      ),
    );
  }

  const CropGeometry._({
    required this.imageSize,
    required this.cropRect,
    required this.zoom,
    required this.sourceCenter,
  });

  static const minZoom = 1.0;
  static const maxZoom = 3.0;
  static const _aspectRatio = 2.0 / 3.0;

  final Size imageSize;
  final Rect cropRect;
  final double zoom;
  final Offset sourceCenter;

  /// Viewport logical pixels per original image pixel.
  double get scale => _baseScale(imageSize, cropRect) * zoom;

  Rect get sourceRect => Rect.fromCenter(
        center: sourceCenter,
        width: math.min(imageSize.width, cropRect.width / scale),
        height: math.min(imageSize.height, cropRect.height / scale),
      );

  /// The exact viewport rectangle to use for displaying the source image.
  Rect get imageRect => Rect.fromLTWH(
        cropRect.center.dx - sourceCenter.dx * scale,
        cropRect.center.dy - sourceCenter.dy * scale,
        imageSize.width * scale,
        imageSize.height * scale,
      );

  Offset sourcePointAt(Offset localPoint) =>
      sourceCenter + (localPoint - cropRect.center) / scale;

  CropGeometry withCropRect(Rect rect) => CropGeometry(
        imageSize: imageSize,
        cropRect: rect,
        zoom: zoom,
        sourceCenter: sourceCenter,
      );

  CropGeometry zoomAt(double zoom, Offset localFocalPoint) => gestureAt(
        zoom: zoom,
        sourceAnchor: sourcePointAt(localFocalPoint),
        localFocalPoint: localFocalPoint,
      );

  /// Keeps the source point captured at gesture start under the current focus.
  ///
  /// The caller supplies startZoom * gesture.scale, not the previous frame's
  /// zoom * gesture.scale; gesture.scale is already relative to gesture start.
  CropGeometry gestureAt({
    required double zoom,
    required Offset sourceAnchor,
    required Offset localFocalPoint,
  }) {
    final nextZoom = _clampZoom(zoom);
    final nextScale = _baseScale(imageSize, cropRect) * nextZoom;
    return CropGeometry(
      imageSize: imageSize,
      cropRect: cropRect,
      zoom: nextZoom,
      sourceCenter:
          sourceAnchor - (localFocalPoint - cropRect.center) / nextScale,
    );
  }

  static Rect fitCropRect(Size viewport) {
    if (!viewport.isFinite || viewport.isEmpty) return Rect.zero;
    final margin =
        math.min(24.0, math.min(viewport.width, viewport.height) * 0.1);
    final width = math.min(
      400.0,
      math.min(
        viewport.width - margin * 2,
        (viewport.height - margin * 2) * _aspectRatio,
      ),
    );
    return Rect.fromCenter(
      center: viewport.center(Offset.zero),
      width: width,
      height: width / _aspectRatio,
    );
  }

  static double _baseScale(Size imageSize, Rect cropRect) => math.max(
        cropRect.width / imageSize.width,
        cropRect.height / imageSize.height,
      );

  static double _clampZoom(double zoom) {
    if (!zoom.isFinite) {
      throw ArgumentError.value(zoom, 'zoom', 'Must be finite');
    }
    return zoom.clamp(minZoom, maxZoom);
  }
}
