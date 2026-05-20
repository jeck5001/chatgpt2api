import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../app/tokens.dart';
import '../app/typography.dart';
import 'composer_bar.dart';
import 'studio_controller.dart';
import 'studio_image_saver.dart';
import 'studio_models.dart';
import 'studio_repository.dart';

class StudioInpaintScreen extends StatefulWidget {
  StudioInpaintScreen({
    super.key,
    required this.controller,
    required this.conversationId,
    required this.sourceImage,
    required this.prompt,
    required this.model,
    this.size,
    StudioImageSaver? imageSaver,
  }) : imageSaver = imageSaver ?? StudioImageSaver();

  final StudioController controller;
  final String conversationId;
  final StudioResultImage sourceImage;
  final String prompt;
  final String model;
  final String? size;
  final StudioImageSaver imageSaver;

  @override
  State<StudioInpaintScreen> createState() => _StudioInpaintScreenState();
}

enum _InpaintTool { brush, eraser }

class _StudioInpaintScreenState extends State<StudioInpaintScreen> {
  final _promptController = TextEditingController();
  final GlobalKey _canvasKey = GlobalKey();
  final List<_Stroke> _strokes = [];
  _Stroke? _activeStroke;
  late final Future<Uint8List> _sourceBytesFuture;
  late final Future<Size> _sourceSizeFuture;
  _InpaintTool _tool = _InpaintTool.brush;
  double _brushSize = 28;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _promptController.text = widget.prompt;
    _promptController.addListener(_onPromptChanged);
    _sourceBytesFuture = widget.imageSaver.loadImageBytes(
      widget.sourceImage.url,
    );
    _sourceSizeFuture = _sourceBytesFuture.then(_decodeSize);
  }

  @override
  void dispose() {
    _promptController.removeListener(_onPromptChanged);
    _promptController.dispose();
    super.dispose();
  }

  void _onPromptChanged() {
    if (mounted) setState(() {});
  }

  Future<Size> _decodeSize(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return Size(frame.image.width.toDouble(), frame.image.height.toDouble());
  }

  void _startStroke(Offset localPosition) {
    setState(() {
      _activeStroke = _Stroke(
        points: [localPosition],
        size: _brushSize,
        erasing: _tool == _InpaintTool.eraser,
      );
    });
  }

  void _updateStroke(Offset localPosition) {
    final activeStroke = _activeStroke;
    if (activeStroke == null) return;
    setState(() {
      activeStroke.points.add(localPosition);
    });
  }

  void _finishStroke() {
    final activeStroke = _activeStroke;
    if (activeStroke == null) return;
    setState(() {
      if (activeStroke.points.isNotEmpty) {
        _strokes.add(activeStroke);
      }
      _activeStroke = null;
    });
  }

  bool get _hasMask {
    return _strokes.any(
          (stroke) => !stroke.erasing && stroke.points.isNotEmpty,
        ) ||
        (_activeStroke != null &&
            !_activeStroke!.erasing &&
            _activeStroke!.points.isNotEmpty);
  }

  Future<Uint8List> _captureMask(Size sourceSize) async {
    final boundary =
        _canvasKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      throw StateError('mask canvas is not ready');
    }
    final canvasSize = boundary.size;
    if (canvasSize.width <= 0 || canvasSize.height <= 0) {
      throw StateError('mask canvas has invalid size');
    }
    final pixelRatio = sourceSize.width / canvasSize.width;
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw StateError('failed to encode mask image');
    }
    return byteData.buffer.asUint8List();
  }

  Future<void> _submit() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) {
      _showSnack('请先填写修改说明');
      return;
    }
    if (!_hasMask) {
      _showSnack('请先涂抹要修改的区域');
      return;
    }
    setState(() => _submitting = true);
    try {
      final sourceBytes = await _sourceBytesFuture;
      final sourceName = widget.sourceImage.path.isNotEmpty
          ? widget.sourceImage.path.split('/').last
          : 'source.png';
      final sourceImage = StudioEditImage(
        bytes: sourceBytes,
        filename: sourceName.isEmpty ? 'source.png' : sourceName,
        contentType: 'image/png',
      );
      final sourceSize = await _sourceSizeFuture;
      final maskBytes = await _captureMask(sourceSize);
      final maskImage = StudioEditImage(
        bytes: maskBytes,
        filename: 'mask.png',
        contentType: 'image/png',
      );
      await widget.controller.submitInpaint(
        conversationId: widget.conversationId,
        prompt: prompt,
        image: sourceImage,
        mask: maskImage,
        model: widget.model,
        size: widget.size,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      _showSnack('局部重绘失败：$error');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  void _clearMask() {
    setState(() {
      _strokes.clear();
      _activeStroke = null;
    });
  }

  void _undoStroke() {
    setState(() {
      if (_activeStroke != null) {
        _activeStroke = null;
      } else if (_strokes.isNotEmpty) {
        _strokes.removeLast();
      }
    });
  }

  void _showSnack(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final prompt = _promptController.text.trim();
    final canSubmit = prompt.isNotEmpty && _hasMask && !_submitting;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _InpaintTopBar(
              prompt: widget.prompt,
              onBack: () => Navigator.of(context).maybePop(),
              onClear: _strokes.isEmpty && _activeStroke == null
                  ? null
                  : _clearMask,
            ),
            Expanded(
              child: FutureBuilder<Size>(
                future: _sourceSizeFuture,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final size = snapshot.data!;
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(
                      KilnSpacing.md,
                      0,
                      KilnSpacing.md,
                      KilnSpacing.md,
                    ),
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: size.width / size.height,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(KilnRadii.card),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.network(
                                widget.sourceImage.url.toString(),
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stack) {
                                  return Container(
                                    color: KilnColors.ink900,
                                    alignment: Alignment.center,
                                    child: Text(
                                      widget.sourceImage.path.isEmpty
                                          ? widget.sourceImage.url.toString()
                                          : widget.sourceImage.path,
                                      style: KilnTypography.mono(
                                        size: 12,
                                        color: KilnColors.ink300,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  );
                                },
                              ),
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onPanStart: (details) =>
                                    _startStroke(details.localPosition),
                                onPanUpdate: (details) =>
                                    _updateStroke(details.localPosition),
                                onPanEnd: (_) => _finishStroke(),
                                child: RepaintBoundary(
                                  key: _canvasKey,
                                  child: CustomPaint(
                                    painter: _MaskPainter(
                                      strokes: _strokes,
                                      activeStroke: _activeStroke,
                                    ),
                                    child: Container(color: Colors.transparent),
                                  ),
                                ),
                              ),
                              if (!_hasMask)
                                IgnorePointer(
                                  child: Container(
                                    alignment: Alignment.center,
                                    color: Colors.black.withValues(alpha: 0.12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: KilnSpacing.md,
                                        vertical: KilnSpacing.sm,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(
                                          alpha: 0.36,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          KilnRadii.chip,
                                        ),
                                      ),
                                      child: Text(
                                        '涂抹要重绘的区域',
                                        style: KilnTypography.ui(
                                          size: 12,
                                          color: Colors.white,
                                        ),
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
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                KilnSpacing.md,
                0,
                KilnSpacing.md,
                KilnSpacing.xs,
              ),
              child: Column(
                children: [
                  Wrap(
                    spacing: KilnSpacing.xs,
                    runSpacing: KilnSpacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      TextButton.icon(
                        onPressed: () => setState(() {
                          _tool = _InpaintTool.brush;
                        }),
                        icon: const Icon(Icons.brush_outlined),
                        label: Text('画笔 ${_brushSize.round()}'),
                        style: TextButton.styleFrom(
                          foregroundColor: _tool == _InpaintTool.brush
                              ? KilnColors.ember300
                              : KilnColors.ink300,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => setState(() {
                          _tool = _InpaintTool.eraser;
                        }),
                        icon: const Icon(Icons.auto_fix_off_outlined),
                        label: const Text('橡皮擦'),
                        style: TextButton.styleFrom(
                          foregroundColor: _tool == _InpaintTool.eraser
                              ? KilnColors.ember300
                              : KilnColors.ink300,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _strokes.isEmpty && _activeStroke == null
                            ? null
                            : _undoStroke,
                        icon: const Icon(Icons.undo_rounded),
                        label: const Text('撤销'),
                      ),
                      IconButton(
                        onPressed: _clearMask,
                        icon: const Icon(Icons.clear_all_rounded),
                        tooltip: '清空涂抹',
                      ),
                      Text(
                        _hasMask ? '已标记区域' : '未标记',
                        style: KilnTypography.chipMono.copyWith(
                          color: _hasMask
                              ? KilnColors.ember300
                              : KilnColors.ink500,
                        ),
                      ),
                    ],
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: KilnColors.ember400,
                      inactiveTrackColor: KilnColors.ink700,
                      thumbColor: KilnColors.ember300,
                    ),
                    child: Slider(
                      value: _brushSize,
                      min: 8,
                      max: 72,
                      divisions: 16,
                      label: '画笔 ${_brushSize.round()}',
                      onChanged: (value) => setState(() {
                        _brushSize = value;
                      }),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                KilnSpacing.md,
                0,
                KilnSpacing.md,
                KilnSpacing.lg,
              ),
              child: SafeArea(
                top: false,
                child: ComposerBar(
                  controller: _promptController,
                  canSubmit: canSubmit,
                  submitting: _submitting,
                  onSubmit: _submit,
                  hint: '输入要对涂抹区域做什么',
                  params: [
                    ComposerChipData(label: widget.model, active: true),
                    if (widget.size != null && widget.size!.isNotEmpty)
                      ComposerChipData(
                        label: widget.size!.replaceAll('x', '×'),
                      ),
                    ComposerChipData(
                      label: _submitting ? '处理中...' : '局部重绘',
                      active: _submitting,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stroke {
  _Stroke({required this.points, required this.size, required this.erasing});

  final List<Offset> points;
  final double size;
  final bool erasing;
}

class _MaskPainter extends CustomPainter {
  _MaskPainter({required this.strokes, required this.activeStroke});

  final List<_Stroke> strokes;
  final _Stroke? activeStroke;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(Offset.zero & size, Paint());
    for (final stroke in [...strokes, ?activeStroke]) {
      if (stroke.points.isEmpty) continue;
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: 0.95)
        ..strokeWidth = stroke.size
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..blendMode = stroke.erasing ? BlendMode.clear : BlendMode.srcOver;
      if (stroke.points.length == 1) {
        canvas.drawCircle(stroke.points.single, paint.strokeWidth / 2, paint);
        continue;
      }
      for (var i = 0; i < stroke.points.length - 1; i++) {
        canvas.drawLine(stroke.points[i], stroke.points[i + 1], paint);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MaskPainter oldDelegate) {
    return true;
  }
}

class _InpaintTopBar extends StatelessWidget {
  const _InpaintTopBar({required this.prompt, this.onBack, this.onClear});

  final String prompt;
  final VoidCallback? onBack;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        KilnSpacing.md,
        KilnSpacing.md,
        KilnSpacing.md,
        KilnSpacing.sm,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withValues(alpha: 0.9), Colors.transparent],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
          ),
          const SizedBox(width: KilnSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '局部重绘',
                  style: KilnTypography.display(
                    size: 16,
                    weight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  prompt,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: KilnTypography.ui(size: 12, color: Colors.white70),
                ),
              ],
            ),
          ),
          TextButton(onPressed: onClear, child: const Text('清空')),
        ],
      ),
    );
  }
}
