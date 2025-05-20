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

      // Calculate the aspect ratio of the original image
      final imageAspect = originalImageSize.width / originalImageSize.height;
      final displayAspect =
          displayedImageSize!.width / displayedImageSize!.height;

      // Calculate scaling factors while maintaining aspect ratio
      double scaleX, scaleY;
      if (imageAspect > displayAspect) {
        // Image is wider than display
        scaleX = displayedImageSize!.width / originalImageSize.width;
        scaleY = scaleX;
      } else {
        // Image is taller than display
        scaleY = displayedImageSize!.height / originalImageSize.height;
        scaleX = scaleY;
      }

      // Scale the box from YOLO space to the displayed image size
      final rect = Rect.fromLTRB(
        box.left * scaleX + displayedImageOffset!.dx,
        box.top * scaleY + displayedImageOffset!.dy,
        box.right * scaleX + displayedImageOffset!.dx,
        box.bottom * scaleY + displayedImageOffset!.dy,
      );

      print('📦 Scaled rect on screen: $rect');

      // Draw very visible boxes
      final paint =
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0; // Thinner line for better appearance

      // Draw the rectangle
      canvas.drawRect(rect, paint);

      // Add a very subtle fill for visibility
      if (debugMode) {
        final fillPaint =
            Paint()
              ..color = color.withOpacity(0.1) // More transparent fill
              ..style = PaintingStyle.fill;
        canvas.drawRect(rect, fillPaint);
      }

      // Draw corner dots and disease label when in debug mode
      if (debugMode) {
        // Corner dots - smaller and more subtle
        final dotPaint = Paint()..color = Colors.yellow.withOpacity(0.7);
        canvas.drawCircle(Offset(rect.left, rect.top), 3, dotPaint);
        canvas.drawCircle(
          Offset(rect.right, rect.top),
          3,
          dotPaint..color = Colors.red.withOpacity(0.7),
        );
        canvas.drawCircle(
          Offset(rect.left, rect.bottom),
          3,
          dotPaint..color = Colors.green.withOpacity(0.7),
        );
        canvas.drawCircle(
          Offset(rect.right, rect.bottom),
          3,
          dotPaint..color = Colors.blue.withOpacity(0.7),
        );

        // Draw label with confidence - more compact
        final textPainter = TextPainter(
          text: TextSpan(
            text: '${result.label} (${(result.confidence * 100).toInt()}%)',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12, // Smaller font
              fontWeight: FontWeight.w500, // Less bold
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();

        // Background for text - more compact
        canvas.drawRect(
          Rect.fromLTWH(
            rect.left,
            rect.top - 18, // Reduced height
            textPainter.width + 6, // Reduced padding
            textPainter.height + 2, // Reduced padding
          ),
          Paint()..color = Colors.black.withOpacity(0.6), // More transparent
        );

        // Text
        textPainter.paint(canvas, Offset(rect.left + 3, rect.top - 16));
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
