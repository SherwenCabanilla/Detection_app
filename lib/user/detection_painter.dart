import 'dart:ui';
import 'dart:math';
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
    'backterial_blackspot':
        Colors.purple, // Keep original label for model compatibility
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

  String _formatLabel(String label) {
    switch (label.toLowerCase()) {
      case 'backterial_blackspot':
        return 'Bacterial black spot';
      case 'powdery_mildew':
        return 'Powdery Mildew';
      case 'tip_burn':
        return 'Unknown';
      default:
        return label
            .split('_')
            .map((word) => word[0].toUpperCase() + word.substring(1))
            .join(' ');
    }
  }

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
      // Get the bounding box in original image space
      final box = result.boundingBox;
      final color = diseaseColors[result.label] ?? diseaseColors['Unknown']!;

      print('📦 Original box: $box for ${result.label} (${result.confidence})');

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

      // Scale the box from original image space to the displayed image size
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
            ..strokeWidth = 2.0;

      // Draw the rectangle
      canvas.drawRect(rect, paint);

      // Add a very subtle fill for visibility
      if (debugMode) {
        final fillPaint =
            Paint()
              ..color = color.withOpacity(0.1)
              ..style = PaintingStyle.fill;
        canvas.drawRect(rect, fillPaint);

        // Draw label with confidence
        final textPainter = TextPainter(
          text: TextSpan(
            text:
                '${_formatLabel(result.label)} (${(result.confidence * 100).toInt()}%)',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();

        // Background for text
        canvas.drawRect(
          Rect.fromLTWH(
            rect.left,
            rect.top - 18,
            textPainter.width + 6,
            textPainter.height + 2,
          ),
          Paint()..color = Colors.black.withOpacity(0.6),
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
