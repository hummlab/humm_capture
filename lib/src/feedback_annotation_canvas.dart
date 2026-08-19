import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'feedback_models.dart';

/// Renders a captured image and receives freehand marker input over it.
class FeedbackAnnotationCanvas extends StatelessWidget {
  /// Creates an annotation canvas for a captured feedback image.
  const FeedbackAnnotationCanvas({
    required this.image,
    required this.imageSize,
    required this.strokes,
    required this.isEnabled,
    required this.onPointerDown,
    required this.onPointerMove,
    required this.onPointerFinished,
    super.key,
  });

  /// Image being annotated.
  final FeedbackImage image;

  /// Decoded image size used for the aspect ratio.
  final Size imageSize;

  /// Current normalized marker strokes.
  final List<FeedbackStroke> strokes;

  /// Whether pointer input should create strokes.
  final bool isEnabled;

  /// Starts a stroke at a pointer position in the rendered canvas.
  final void Function(PointerDownEvent event, Size size) onPointerDown;

  /// Adds a point to the active stroke.
  final void Function(PointerMoveEvent event, Size size) onPointerMove;

  /// Finishes the active pointer input.
  final void Function(PointerEvent event) onPointerFinished;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(6),
          boxShadow: const <BoxShadow>[BoxShadow(color: Color(0x1F000000), blurRadius: 12, offset: Offset(0, 4))],
        ),
        child: AspectRatio(
          aspectRatio: imageSize.aspectRatio,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final canvasSize = constraints.biggest;
                return Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    Image.memory(image.bytes, fit: BoxFit.fill),
                    CustomPaint(painter: FeedbackStrokePainter(strokes)),
                    Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: isEnabled ? (event) => onPointerDown(event, canvasSize) : null,
                      onPointerMove: isEnabled ? (event) => onPointerMove(event, canvasSize) : null,
                      onPointerUp: onPointerFinished,
                      onPointerCancel: onPointerFinished,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints normalized feedback marker strokes at a given canvas size.
class FeedbackStrokePainter extends CustomPainter {
  /// Creates a painter for [strokes].
  const FeedbackStrokePainter(this.strokes);

  /// Strokes to render in drawing order.
  final List<FeedbackStroke> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      final paint = Paint()
        ..color = Color(stroke.color)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = _strokeWidth(stroke, size);
      final points = stroke.points
          .map((point) => Offset(point.dx * size.width, point.dy * size.height))
          .toList(growable: false);
      if (points.length == 1) {
        canvas.drawCircle(points.single, _strokeWidth(stroke, size) / 2, paint..style = PaintingStyle.fill);
        continue;
      }
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant FeedbackStrokePainter oldDelegate) => oldDelegate.strokes != strokes;

  double _strokeWidth(FeedbackStroke stroke, Size size) {
    // Ratios keep the exported PNG visually identical to the editor even
    // though the captured source image is usually much larger than its view.
    // Values above one are retained for reports created before ratios existed.
    return stroke.width <= 1 ? stroke.width * size.shortestSide : stroke.width;
  }
}

/// Renders [strokes] into a PNG while retaining the original image metadata.
Future<FeedbackImage> renderAnnotatedImage({
  required FeedbackImage image,
  required List<FeedbackStroke> strokes,
}) async {
  if (strokes.isEmpty) {
    return image;
  }

  final codec = await ui.instantiateImageCodec(image.bytes);
  try {
    final frame = await codec.getNextFrame();
    final sourceImage = frame.image;
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawImage(sourceImage, Offset.zero, Paint());
      FeedbackStrokePainter(strokes).paint(canvas, Size(sourceImage.width.toDouble(), sourceImage.height.toDouble()));
      final picture = recorder.endRecording();
      try {
        final rendered = await picture.toImage(sourceImage.width, sourceImage.height);
        try {
          final renderedBytes = await rendered.toByteData(format: ui.ImageByteFormat.png);
          if (renderedBytes == null) {
            throw StateError('Could not encode the annotated feedback screenshot.');
          }

          return FeedbackImage(
            bytes: Uint8List.view(renderedBytes.buffer, renderedBytes.offsetInBytes, renderedBytes.lengthInBytes),
            source: image.source,
            fileName: image.fileName,
            mimeType: 'image/png',
          );
        } finally {
          rendered.dispose();
        }
      } finally {
        picture.dispose();
      }
    } finally {
      sourceImage.dispose();
    }
  } finally {
    codec.dispose();
  }
}
