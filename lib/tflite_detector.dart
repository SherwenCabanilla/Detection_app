import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:flutter/services.dart';
import 'dart:ui' show Rect;

class DetectionResult {
  final String label;
  final double confidence;
  final Rect boundingBox;
  final Size originalImageSize;
  final Size letterboxedSize;

  DetectionResult({
    required this.label,
    required this.confidence,
    required this.boundingBox,
    required this.originalImageSize,
    required this.letterboxedSize,
  });

  // Convert letterboxed coordinates back to original image coordinates
  Rect getOriginalBoundingBox() {
    final scale = min(
      letterboxedSize.width / originalImageSize.width,
      letterboxedSize.height / originalImageSize.height,
    );

    final newWidth = originalImageSize.width * scale;
    final newHeight = originalImageSize.height * scale;

    final dx = (letterboxedSize.width - newWidth) / 2;
    final dy = (letterboxedSize.height - newHeight) / 2;

    return Rect.fromLTRB(
      (boundingBox.left - dx) / scale,
      (boundingBox.top - dy) / scale,
      (boundingBox.right - dx) / scale,
      (boundingBox.bottom - dy) / scale,
    );
  }
}

class TFLiteDetector {
  Interpreter? _interpreter;
  List<String> _labels = [];
  static const double confidenceThreshold = 0.25; // Lower threshold for YOLOv8
  static const double nmsThreshold = 0.5;
  static const int inputSize = 416;

  Future<void> loadModel() async {
    try {
      final labelData = await rootBundle.loadString('assets/labels.txt');
      _labels =
          labelData
              .split('\n')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();

      _interpreter = await Interpreter.fromAsset('assets/yolov8_416x.tflite');
      print('✅ Model loaded with ${_labels.length} labels');
    } catch (e) {
      print('❌ Failed to load model: $e');
      rethrow;
    }
  }

  // Add a letterbox function
  img.Image letterbox(img.Image src, int targetW, int targetH) {
    final srcW = src.width;
    final srcH = src.height;
    final scale = min(targetW / srcW, targetH / srcH);
    final newW = (srcW * scale).round();
    final newH = (srcH * scale).round();
    final resized = img.copyResize(src, width: newW, height: newH);
    final out = img.Image(targetW, targetH);
    // Fill with black
    img.fill(out, img.getColor(0, 0, 0));
    // Paste resized image centered
    final dx = ((targetW - newW) / 2).round();
    final dy = ((targetH - newH) / 2).round();
    img.copyInto(out, resized, dstX: dx, dstY: dy);
    return out;
  }

  Future<List<DetectionResult>> detectDiseases(String imagePath) async {
    print('Starting detection for image: $imagePath');

    if (_interpreter == null) {
      print('Interpreter is null, loading model...');
      await loadModel();
    }

    try {
      print('Reading image file...');
      final imageBytes = File(imagePath).readAsBytesSync();
      print('Image bytes read: ${imageBytes.length} bytes');

      print('Decoding image...');
      final image = img.decodeImage(imageBytes);
      if (image == null) {
        print('❌ Image decoding failed');
        throw Exception('Image decoding failed');
      }
      print('✅ Image decoded successfully: ${image.width}x${image.height}');

      // final resized = img.copyResize(
      //   image,
      //   width: inputSize,
      //   height: inputSize,
      // );
      final resized = letterbox(image, inputSize, inputSize);
      print('✅ Image letterboxed to: ${resized.width}x${resized.height}');

      // Prepare input data
      final input = Float32List(inputSize * inputSize * 3);
      final pixels = resized.getBytes();
      print('✅ Got pixel data, length: ${pixels.length}');

      for (
        int i = 0, j = 0;
        i < pixels.length && j < input.length;
        i += 4, j += 3
      ) {
        input[j] = pixels[i] / 255.0;
        input[j + 1] = pixels[i + 1] / 255.0;
        input[j + 2] = pixels[i + 2] / 255.0;
      }
      print(
        '✅ Input data prepared, first few values: ${input.take(10).toList()}',
      );

      // Create input tensor
      final inputShape = [1, inputSize, inputSize, 3];
      final outputShape = [
        1,
        9,
        3549,
      ]; // YOLOv8 output format: [batch, channels, boxes]
      print('✅ Input shape: $inputShape, Output shape: $outputShape');

      // Run inference
      final output = List.filled(
        outputShape.reduce((a, b) => a * b),
        0.0,
      ).reshape(outputShape);
      print('✅ Output tensor created, running inference...');

      _interpreter!.run(input.reshape(inputShape), output);
      print('✅ Inference completed');

      // Process output
      final outputData = output[0]; // Get first batch
      print('Output data shape: ${outputData.length}x${outputData[0].length}');

      // Process detections
      final List<DetectionResult> results = [];
      for (int i = 0; i < outputData[0].length; i++) {
        // Get objectness score (channel 4)
        final objectness = outputData[4][i];
        print('Objectness score at index $i: $objectness');

        if (objectness > confidenceThreshold) {
          // Find class with highest confidence (classes are in channels 5-8)
          double maxClassScore = 0;
          int classIndex = 0;
          for (int c = 5; c < 9; c++) {
            final score = outputData[c][i];
            if (score > maxClassScore) {
              maxClassScore = score;
              classIndex = c - 5;
            }
          }

          // Calculate final confidence
          final confidence = objectness * maxClassScore;
          print(
            'Detection $i - Class: $classIndex, Score: $maxClassScore, Final Conf: $confidence',
          );

          if (confidence > confidenceThreshold) {
            // Print raw output for this detection
            print('RAW OUTPUT for detection $i:');
            print('outputData[0][i]: [33m${outputData[0][i]}[0m');
            print('outputData[1][i]: [33m${outputData[1][i]}[0m');
            print('outputData[2][i]: [33m${outputData[2][i]}[0m');
            print('outputData[3][i]: [33m${outputData[3][i]}[0m');
            print(
              'Full output vector: [${outputData.map((c) => c[i]).toList()}]',
            );

            // Use (y, x, h, w) as the correct bounding box order
            final y = outputData[0][i];
            final x = outputData[1][i];
            final h = outputData[2][i];
            final w = outputData[3][i];

            // Convert normalized coordinates (0-1) to pixel coordinates (0-416)
            final left = (x - w / 2) * inputSize;
            final top = (y - h / 2) * inputSize;
            final right = (x + w / 2) * inputSize;
            final bottom = (y + h / 2) * inputSize;

            results.add(
              DetectionResult(
                label: _getDiseaseLabel(classIndex),
                confidence: confidence,
                boundingBox: Rect.fromLTRB(left, top, right, bottom),
                originalImageSize: Size(
                  image.width.toDouble(),
                  image.height.toDouble(),
                ),
                letterboxedSize: Size(
                  inputSize.toDouble(),
                  inputSize.toDouble(),
                ),
              ),
            );
          }
        }
      }

      print('Found ${results.length} detections before NMS');

      // Second pass: apply non-maximum suppression
      results.sort(
        (a, b) => b.confidence.compareTo(a.confidence),
      ); // Sort by confidence

      final filteredResults = <DetectionResult>[];
      while (results.isNotEmpty) {
        final detection = results.removeAt(0);
        filteredResults.add(detection);

        // Remove overlapping detections
        results.removeWhere((other) {
          final intersection = detection.boundingBox.intersect(
            other.boundingBox,
          );
          final intersectionArea = intersection.width * intersection.height;
          final otherArea = other.boundingBox.width * other.boundingBox.height;
          final iou = intersectionArea / otherArea;
          return iou > nmsThreshold;
        });
      }

      print('Detected ${filteredResults.length} objects after NMS');
      return filteredResults;
    } catch (e, stackTrace) {
      print('❌ Error during detection: $e');
      print('Stack trace: $stackTrace');
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
