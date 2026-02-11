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
  static const double confidenceThreshold =
      0.5; // Set to 50% confidence threshold
  static const double nmsThreshold =
      0.3; // Increased from 0.1 to 0.3 to allow more detections
  static const int inputSize = 640;

  // Configurable thresholds for testing
  double _currentConfidenceThreshold = confidenceThreshold;
  double _currentNmsThreshold = nmsThreshold;

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
      final labelData = await rootBundle.loadString('assets/labelsv2.txt');
      _labels =
          labelData
              .split('\n')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
      _interpreter = await Interpreter.fromAsset('assets/v43.tflite');
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
        5 +
            _labels
                .length, // 4 bbox + 1 obj + N class scores (dynamic based on labels)
        8400,
      ];

      final output = List.filled(
        outputShape.reduce((a, b) => a * b),
        0.0,
      ).reshape(outputShape);

      _interpreter!.run(input.reshape(inputShape), output);

      final results = <DetectionResult>[];
      final outputData = output[0];

      print('🔍 Detection Debug Info:');
      print('   - Image size: ${image.width}x${image.height}');
      print('   - Input size: ${inputSize}x${inputSize}');
      print('   - Labels loaded: ${_labels.length} (${_labels.join(", ")})');
      print('   - Confidence threshold: $_currentConfidenceThreshold');
      print('   - NMS threshold: $_currentNmsThreshold');

      final detections = <DetectionResult>[];
      int totalDetections = 0;
      int validDetections = 0;

      for (var i = 0; i < outputData[0].length; i++) {
        totalDetections++;
        var maxConf = 0.0;
        var maxClass = 0;

        for (var c = 5; c < 5 + _labels.length; c++) {
          final conf = outputData[c][i];
          if (conf > maxConf) {
            maxConf = conf;
            maxClass = c - 5;
          }
        }

        if (maxConf > _currentConfidenceThreshold) {
          validDetections++;
          // YOLO outputs normalized coordinates (0-1) for center point and dimensions
          final centerX = outputData[0][i];
          final centerY = outputData[1][i];
          final width = outputData[2][i];
          final height = outputData[3][i];

          // Calculate letterboxing parameters - fixed logic
          final scale = min(inputSize / image.width, inputSize / image.height);
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
          return iou > _currentNmsThreshold;
        });
      }

      print('📊 Detection Summary:');
      print('   - Total raw detections: $totalDetections');
      print('   - Valid detections (above threshold): $validDetections');
      print('   - Final detections after NMS: ${results.length}');

      if (results.isNotEmpty) {
        print('🎯 Detected objects:');
        for (var result in results) {
          print(
            '   - ${result.label}: ${(result.confidence * 100).toStringAsFixed(1)}% at ${result.boundingBox}',
          );
        }
      } else {
        print('⚠️  No objects detected! Consider:');
        print(
          '   - Lowering confidence threshold (currently $_currentConfidenceThreshold)',
        );
        print('   - Checking if model is appropriate for your images');
        print('   - Verifying image quality and lighting');
      }

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

  // Method to adjust thresholds for better detection
  void setThresholds({double? confidence, double? nms}) {
    if (confidence != null) {
      _currentConfidenceThreshold = confidence;
      print('🔧 Confidence threshold set to: $confidence');
    }
    if (nms != null) {
      _currentNmsThreshold = nms;
      print('🔧 NMS threshold set to: $nms');
    }
  }

  // Method to reset to default thresholds
  void resetThresholds() {
    _currentConfidenceThreshold = confidenceThreshold;
    _currentNmsThreshold = nmsThreshold;
    print(
      '🔄 Thresholds reset to defaults: confidence=$confidenceThreshold, nms=$nmsThreshold',
    );
  }

  // Method to test different threshold combinations
  Future<List<DetectionResult>> detectWithThresholds(
    String imagePath, {
    double? confidence,
    double? nms,
  }) async {
    final originalConfidence = _currentConfidenceThreshold;
    final originalNms = _currentNmsThreshold;

    setThresholds(confidence: confidence, nms: nms);
    final results = await detectDiseases(imagePath);

    // Restore original thresholds
    _currentConfidenceThreshold = originalConfidence;
    _currentNmsThreshold = originalNms;

    return results;
  }

  void closeModel() {
    _interpreter?.close();
    _interpreter = null;
    print('✅ TFLite interpreter closed');
  }
}
