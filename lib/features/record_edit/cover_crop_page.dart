import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../services/cover_crop_service.dart';
import 'crop_geometry.dart';

class CoverCropPage extends StatefulWidget {
  const CoverCropPage({
    required this.sourcePath,
    this.service,
    super.key,
  });

  final String sourcePath;

  /// Allows image I/O to be substituted in lifecycle and interaction tests.
  final CoverCropService? service;

  @override
  State<CoverCropPage> createState() => _CoverCropPageState();
}

class _CoverCropPageState extends State<CoverCropPage> {
  late final CoverCropService _service;
  PreparedCover? _source;
  CropGeometry? _geometry;
  String? _loadError;
  bool _processing = false;
  double _gestureStartZoom = 1;
  bool _gestureActive = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? CoverCropService();
    _loadImage();
  }

  Future<void> _loadImage() async {
    setState(() => _loadError = null);
    try {
      final source = await _service.load(widget.sourcePath);
      if (!mounted) return;
      setState(() => _source = source);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = switch (error) {
          CoverCropException(:final message) => message,
          FormatException(:final message) => message,
          _ => '读取图片失败，请检查文件是否存在，或重新选择图片。',
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = _source != null && !_processing;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: Theme.of(context)
            .textTheme
            .titleLarge
            ?.copyWith(color: Colors.white),
        title: const Text('截取封面'),
        actions: [
          TextButton(
            key: const ValueKey('crop-preview-button'),
            onPressed: ready ? _previewCrop : null,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              disabledForegroundColor: Colors.white38,
            ),
            child: Text(_processing ? '处理中…' : '预览'),
          ),
        ],
      ),
      body: SafeArea(
        child: _loadError != null
            ? _buildLoadError()
            : _source == null
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : Column(
                    children: [
                      Expanded(child: _buildViewport()),
                      _buildControls(),
                    ],
                  ),
      ),
    );
  }

  Widget _buildLoadError() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _loadError!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _loadImage, child: const Text('重试')),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: const Text('返回选图'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewport() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cropRect = CropGeometry.fitCropRect(constraints.biggest);
        if (cropRect.isEmpty) return const SizedBox.shrink();
        final source = _source!;
        final previous = _geometry;
        if (previous == null) {
          _geometry = CropGeometry(
            imageSize: Size(source.width.toDouble(), source.height.toDouble()),
            cropRect: cropRect,
          );
        } else if (previous.cropRect != cropRect) {
          _geometry = previous.withCropRect(cropRect);
          // A layout change invalidates the old screen-space gesture.
          _gestureActive = false;
        }
        final geometry = _geometry!;
        return MouseRegion(
          cursor: _processing
              ? SystemMouseCursors.progress
              : SystemMouseCursors.grab,
          child: Listener(
            onPointerSignal: _onPointerSignal,
            child: GestureDetector(
              key: const ValueKey('crop-viewport'),
              behavior: HitTestBehavior.opaque,
              onScaleStart: _onScaleStart,
              onScaleUpdate: _onScaleUpdate,
              onScaleEnd: (_) => _gestureActive = false,
              onDoubleTap: _reset,
              child: ClipRect(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned.fromRect(
                      rect: geometry.imageRect,
                      child: Image.memory(
                        source.previewBytes,
                        key: const ValueKey('crop-source-image'),
                        semanticLabel: '待裁剪的封面图片',
                        fit: BoxFit.fill,
                        gaplessPlayback: true,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _MaskPainter(cropRect: cropRect),
                        ),
                      ),
                    ),
                    Positioned.fromRect(
                      rect: cropRect,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          key: const ValueKey('crop-frame'),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white, width: 1),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              SizedBox(
                width: 52,
                child: Text(
                  '${((_geometry?.zoom ?? 1) * 100).round()}%',
                  key: const ValueKey('crop-zoom-label'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              Expanded(
                // Keep the disabled slider accessible without reparenting its
                // focused semantics subtree during the dialog transition.
                child: KeyedSubtree(
                  key: ValueKey(_processing),
                  child: Slider(
                    key: const ValueKey('crop-zoom-slider'),
                    min: CropGeometry.minZoom,
                    max: CropGeometry.maxZoom,
                    divisions: 200,
                    activeColor: Colors.white,
                    inactiveColor: Colors.white24,
                    value: _geometry?.zoom ?? 1,
                    onChanged: _processing ? null : _onSliderChanged,
                    semanticFormatterCallback: (value) =>
                        '缩放 ${(value * 100).round()}%',
                  ),
                ),
              ),
              TextButton(
                key: const ValueKey('crop-reset'),
                onPressed: _processing ? null : _reset,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white38,
                ),
                child: const Text('重置'),
              ),
            ],
          ),
          const Text(
            '拖动调整位置 · 双指或滚轮缩放 · 双击重置',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  void _onScaleStart(ScaleStartDetails details) {
    final geometry = _geometry;
    if (geometry == null || _processing) return;
    _gestureStartZoom = geometry.zoom;
    _gestureActive = true;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final geometry = _geometry;
    if (geometry == null || !_gestureActive || _processing) return;
    // ScaleStart is delivered at the first move's destination. Use the actual
    // event delta so fast/coalesced drags do not lose that first movement.
    // Recompute from clamped geometry so reversing at an edge is immediate.
    final anchor = geometry.sourcePointAt(
      details.localFocalPoint - details.focalPointDelta,
    );
    setState(() {
      _geometry = geometry.gestureAt(
        zoom: _gestureStartZoom * details.scale,
        sourceAnchor: anchor,
        localFocalPoint: details.localFocalPoint,
      );
    });
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (_processing ||
        event is! PointerScrollEvent ||
        event.scrollDelta.dy == 0) {
      return;
    }
    GestureBinding.instance.pointerSignalResolver.register(event, (_) {
      if (!mounted || _processing || _geometry == null) return;
      final delta = event.scrollDelta.dy.clamp(-240.0, 240.0);
      final zoom = _geometry!.zoom * math.exp(-delta / 1200);
      setState(() {
        _gestureActive = false;
        _geometry = _geometry!.zoomAt(zoom, event.localPosition);
      });
    });
  }

  void _onSliderChanged(double zoom) {
    if (_processing || _geometry == null) return;
    setState(() {
      _gestureActive = false;
      _geometry = _geometry!.zoomAt(zoom, _geometry!.cropRect.center);
    });
  }

  void _reset() {
    if (_processing || _geometry == null) return;
    setState(() {
      _gestureActive = false;
      _geometry = CropGeometry(
        imageSize: _geometry!.imageSize,
        cropRect: _geometry!.cropRect,
      );
    });
  }

  Future<void> _previewCrop() async {
    final source = _source;
    final geometry = _geometry;
    if (source == null || geometry == null || _processing) return;
    setState(() {
      _gestureActive = false;
      _processing = true;
    });

    try {
      final bytes = await _service.crop(source, geometry.sourceRect);
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          scrollable: true,
          title: const Text('预览裁剪结果'),
          content: SizedBox(
            width: 320,
            height: math.min(
              480,
              MediaQuery.sizeOf(dialogContext).height * 0.5,
            ),
            child: Image.memory(
              bytes,
              key: const ValueKey('crop-result-image'),
              semanticLabel: '裁剪结果预览',
              fit: BoxFit.contain,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('重新截取'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('确认使用'),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true) return;
      // Write exactly the bytes shown in the confirmation dialog.
      final path = await _service.save(bytes);
      if (!mounted) return;
      Navigator.of(context).pop(path);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            switch (error) {
              CoverCropException(:final message) => message,
              FormatException(:final message) => message,
              _ => '裁剪或保存失败，请检查文件和存储空间后重试。',
            },
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }
}

class _MaskPainter extends CustomPainter {
  const _MaskPainter({required this.cropRect});
  final Rect cropRect;

  @override
  void paint(Canvas canvas, Size size) {
    final mask = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRect(cropRect);
    canvas.drawPath(
      mask,
      Paint()..color = Colors.black.withValues(alpha: 0.6),
    );
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..strokeWidth = 0.5;
    for (var i = 1; i < 3; i++) {
      canvas.drawLine(
        Offset(cropRect.left + cropRect.width * i / 3, cropRect.top),
        Offset(cropRect.left + cropRect.width * i / 3, cropRect.bottom),
        grid,
      );
      canvas.drawLine(
        Offset(cropRect.left, cropRect.top + cropRect.height * i / 3),
        Offset(cropRect.right, cropRect.top + cropRect.height * i / 3),
        grid,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MaskPainter oldDelegate) =>
      oldDelegate.cropRect != cropRect;
}
