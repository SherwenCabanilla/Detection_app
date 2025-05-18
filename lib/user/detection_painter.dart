import 'dart:ui';
import 'package:flutter/material.dart';
import 'tflite_detector.dart';

class DetectionPainter extends CustomPainter {
  final List<DetectionResult> results;
  final Size originalImageSize;
  final Size? displayedImageSize;
  final Offset? displayedImageOffset;
  final bool debugMode;

  // Disease color map
  static const Map<String, Color> diseaseColors = {
    'anthracnose': Colors.orange,
    'backterial_blackspot': Colors.purple,
    'dieback': Colors.red,
    'healthy': Color.fromARGB(255, 2, 119, 252),
    'powdery_mildew': Color.fromARGB(255, 9, 46, 2),
    'tip_burn': Colors.brown,
    // fallback color
    'Unknown': Colors.grey,
  };

  DetectionPainter({
    required this.results,
    required this.originalImageSize,
    this.displayedImageSize,
    this.displayedImageOffset,
    this.debugMode = true, // Enable debug mode by default for visibility
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (displayedImageSize == null || displayedImageOffset == null) {
      print('❌ DisplayedImageSize or offset is null - cannot draw boxes');
      return;
    }

    print('📦 Drawing ${results.length} boxes');
    print('📏 Original size: $originalImageSize');
    print('📏 Display size: $displayedImageSize');
    print('📏 Display offset: $displayedImageOffset');

    if (results.isEmpty) {
      print('❌ No results to draw');
      return;
    }

    for (var result in results) {
      // Get the bounding box in YOLO 416x416 space
      final box = result.boundingBox;
      final color = diseaseColors[result.label] ?? diseaseColors['Unknown']!;

      print(
        '📦 Original box in YOLO space: $box for ${result.label} (${result.confidence})',
      );

      // The boxes are in 416x416 YOLO space, scale to the displayed image size
      final scaleX = displayedImageSize!.width / 416.0;
      final scaleY = displayedImageSize!.height / 416.0;
      final offset = displayedImageOffset!;

      // Scale the box from 416x416 to the displayed image size
      final rect = Rect.fromLTRB(
        box.left * scaleX + offset.dx,
        box.top * scaleY + offset.dy,
        box.right * scaleX + offset.dx,
        box.bottom * scaleY + offset.dy,
      );

      print('📦 Scaled rect on screen: $rect');

      // Draw very visible boxes
      final paint =
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = debugMode ? 5.0 : 3.0; // Thicker when debugging

      // Draw the rectangle
      canvas.drawRect(rect, paint);

      // Add a slightly transparent fill for visibility
      if (debugMode) {
        final fillPaint =
            Paint()
              ..color = color.withOpacity(0.3)
              ..style = PaintingStyle.fill;
        canvas.drawRect(rect, fillPaint);
      }

      // Draw corner dots and disease label when in debug mode
      if (debugMode) {
        // Corner dots
        final dotPaint = Paint()..color = Colors.yellow;
        canvas.drawCircle(Offset(rect.left, rect.top), 5, dotPaint);
        canvas.drawCircle(
          Offset(rect.right, rect.top),
          5,
          dotPaint..color = Colors.red,
        );
        canvas.drawCircle(
          Offset(rect.left, rect.bottom),
          5,
          dotPaint..color = Colors.green,
        );
        canvas.drawCircle(
          Offset(rect.right, rect.bottom),
          5,
          dotPaint..color = Colors.blue,
        );

        // Draw label with confidence
        final textPainter = TextPainter(
          text: TextSpan(
            text: '${result.label} (${(result.confidence * 100).toInt()}%)',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();

        // Background for text
        canvas.drawRect(
          Rect.fromLTWH(
            rect.left,
            rect.top - 22,
            textPainter.width + 8,
            textPainter.height + 4,
          ),
          Paint()..color = Colors.black.withOpacity(0.7),
        );

        // Text
        textPainter.paint(canvas, Offset(rect.left + 4, rect.top - 20));
      }
    }
  }

  @override
  bool shouldRepaint(covariant DetectionPainter oldDelegate) =>
      oldDelegate.results != results ||
      oldDelegate.originalImageSize != originalImageSize ||
      oldDelegate.displayedImageSize != displayedImageSize ||
      oldDelegate.displayedImageOffset != displayedImageOffset;
}
