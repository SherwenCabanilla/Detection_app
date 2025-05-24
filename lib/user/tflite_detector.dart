import 'package:image/image.dart' as img;
import 'dart:typed_data';
import 'dart:math';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:io';
import 'dart:ui' show Rect;
import 'package:flutter/services.dart';

class DetectionResult {
  final String label;
  final double confidence;
  final Rect boundingBox;

  DetectionResult({
    required this.label,
    required this.confidence,
    required this.boundingBox,
  });
}

class TFLiteDetector {
  Interpreter? _interpreter;
  List<String> _labels = [];
  static const double confidenceThreshold = 0.5;
  static const double nmsThreshold = 0.5;
  static const int inputSize = 416;

  img.Image letterbox(img.Image src, int targetW, int targetH) {
    final srcW = src.width;
    final srcH = src.height;
    final scale =
        srcW / srcH > targetW / targetH ? targetW / srcW : targetH / srcH;
    final newW = (srcW * scale).round();
    final newH = (srcH * scale).round();
    final resized = img.copyResize(src, width: newW, height: newH);
    final out = img.Image(targetW, targetH);
    img.fill(out, 0);
    final dx = ((targetW - newW) / 2).round();
    final dy = ((targetH - newH) / 2).round();
    img.copyInto(out, resized, dstX: dx, dstY: dy);
    return out;
  }

  Future<void> loadModel() async {
    try {
      final labelData = await rootBundle.loadString('assets/labels.txt');
      _labels =
          labelData
              .split('\n')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
      _interpreter = await Interpreter.fromAsset('assets/v19.tflite');
      print('✅ Model loaded with ${_labels.length} labels');
    } catch (e) {
      print('❌ Failed to load model: $e');
      rethrow;
    }
  }

  Future<List<DetectionResult>> detectDiseases(String imagePath) async {
    if (_interpreter == null) {
      await loadModel();
    }

    try {
      final image = img.decodeImage(File(imagePath).readAsBytesSync());
      if (image == null) throw Exception('Image decoding failed');

      final resized = letterbox(image, inputSize, inputSize);
      final input = Float32List(inputSize * inputSize * 3);
      final pixels = resized.getBytes();
      for (
        int i = 0, j = 0;
        i < pixels.length && j < input.length;
        i += 4, j += 3
      ) {
        input[j] = pixels[i] / 255.0;
        input[j + 1] = pixels[i + 1] / 255.0;
        input[j + 2] = pixels[i + 2] / 255.0;
      }

      final inputShape = [1, inputSize, inputSize, 3];
      final outputShape = [
        1,
        10, // 4 bbox + 1 obj + 6 class scores
        3549,
      ];

      final output = List.filled(
        outputShape.reduce((a, b) => a * b),
        0.0,
      ).reshape(outputShape);

      _interpreter!.run(input.reshape(inputShape), output);

      final results = <DetectionResult>[];
      final outputData = output[0];

      final detections = <DetectionResult>[];
      for (var i = 0; i < outputData[0].length; i++) {
        var maxConf = 0.0;
        var maxClass = 0;

        for (var c = 5; c < 10; c++) {
          final conf = outputData[c][i];
          if (conf > maxConf) {
            maxConf = conf;
            maxClass = c - 5;
          }
        }

        if (maxConf > confidenceThreshold) {
          // YOLO outputs normalized coordinates (0-1) for center point and dimensions
          final centerX = outputData[0][i];
          final centerY = outputData[1][i];
          final width = outputData[2][i];
          final height = outputData[3][i];

          // Calculate letterboxing parameters
          final scale = inputSize / max(image.width, image.height);
          final newUnpaddedW = image.width * scale;
          final newUnpaddedH = image.height * scale;
          final padX = (inputSize - newUnpaddedW) / 2;
          final padY = (inputSize - newUnpaddedH) / 2;

          // Convert from YOLO normalized coordinates to original image coordinates
          // First convert center point and dimensions to absolute coordinates in YOLO space
          final yoloCenterX = centerX * inputSize;
          final yoloCenterY = centerY * inputSize;
          final yoloWidth = width * inputSize;
          final yoloHeight = height * inputSize;

          // Remove padding and scale back to original image space
          final originalCenterX = (yoloCenterX - padX) / scale;
          final originalCenterY = (yoloCenterY - padY) / scale;
          final originalWidth = yoloWidth / scale;
          final originalHeight = yoloHeight / scale;

          // Convert center point and dimensions to LTRB format
          final left = originalCenterX - (originalWidth / 2);
          final top = originalCenterY - (originalHeight / 2);
          final right = originalCenterX + (originalWidth / 2);
          final bottom = originalCenterY + (originalHeight / 2);

          detections.add(
            DetectionResult(
              label: _getDiseaseLabel(maxClass),
              confidence: maxConf,
              boundingBox: Rect.fromLTRB(left, top, right, bottom),
            ),
          );
        }
      }

      detections.sort((a, b) => b.confidence.compareTo(a.confidence));

      while (detections.isNotEmpty) {
        final detection = detections.removeAt(0);
        results.add(detection);
        detections.removeWhere((other) {
          final intersection = detection.boundingBox.intersect(
            other.boundingBox,
          );
          final intersectionArea = intersection.width * intersection.height;
          final otherArea = other.boundingBox.width * other.boundingBox.height;
          final iou = intersectionArea / otherArea;
          return iou > nmsThreshold;
        });
      }

      print('Detected ${results.length} objects after NMS');
      return results;
    } catch (e) {
      print('❌ Error during detection: $e');
      return [];
    }
  }

  String _getDiseaseLabel(int classId) {
    if (classId >= 0 && classId < _labels.length) {
      return _labels[classId];
    }
    return 'Unknown($classId)';
  }

  void closeModel() {
    _interpreter?.close();
    _interpreter = null;
    print('✅ TFLite interpreter closed');
  }
}
