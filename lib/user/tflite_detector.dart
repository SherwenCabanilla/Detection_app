import 'package:image/image.dart' as img;
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:onnxruntime_v2/onnxruntime_v2.dart' as ort;
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
  // YOLO model for box detection (1 class: mango_leaf)
  Interpreter? _yoloInterpreter;

  // MobileNetV3 ONNX model for classification (9 classes)
  ort.OrtSession? _mobilenetSession;

  // Classification labels (9 classes)
  List<String> _classificationLabels = [];

  static const double confidenceThreshold =
      0.20; // YOLO confidence threshold (higher = fewer, more reliable boxes)
  static const double nmsThreshold =
      0.9; // NMS IoU: balances merging overlaps vs keeping neighbors
  static const double mobilenetConfidenceThreshold =
      0.75; // Minimum confidence threshold
  static const int yoloInputSize = 640;
  static const int mobilenetInputSize = 224; // input size
  static const double defaultTemperature =
      1.0; // Default temperature for softmax (1.0 = no scaling, higher = less overconfident)

  // Configurable thresholds
  double _currentConfidenceThreshold = confidenceThreshold;
  double _currentNmsThreshold = nmsThreshold;
  double _currentMobilenetConfidenceThreshold = mobilenetConfidenceThreshold;
  double _currentTemperature =
      defaultTemperature; // Temperature for softmax scaling

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
      // Initialize ONNX Runtime environment
      ort.OrtEnv.instance.init();

      // Load classification labels (9 classes)
      final labelData = await rootBundle.loadString('assets/labelsv2.txt');
      _classificationLabels =
          labelData
              .split('\n')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();

      // Load YOLO model (1 class detection)
      _yoloInterpreter = await Interpreter.fromAsset('assets/v2trash.tflite');

      // Load MobileNetV3 ONNX model (9 class classification)
      final onnxBytes = await rootBundle.load('assets/extension_model.onnx');
      final sessionOptions = ort.OrtSessionOptions();
      sessionOptions.appendCPUProvider(ort.CPUFlags.useArena);
      _mobilenetSession = ort.OrtSession.fromBuffer(
        onnxBytes.buffer.asUint8List(),
        sessionOptions,
      );

      // Print ONNX model info for debugging
      print('📊 ONNX Model loaded successfully');

      print('✅ YOLO model loaded (1 class detection)');
      print('✅ MobileNetV3 ONNX model loaded');
      print(
        '✅ Classification labels loaded: ${_classificationLabels.length} (${_classificationLabels.join(", ")})',
      );
    } catch (e) {
      print('❌ Failed to load models: $e');
      rethrow;
    }
  }

  // Crop and resize image region for MobileNetV3
  Float32List _prepareCropForMobileNet(img.Image originalImage, Rect box) {
    // Ensure box is within image bounds
    final left = math.max(0, box.left.toInt());
    final top = math.max(0, box.top.toInt());
    final right = math.min(originalImage.width, box.right.toInt());
    final bottom = math.min(originalImage.height, box.bottom.toInt());

    final width = right - left;
    final height = bottom - top;

    if (width <= 0 || height <= 0) {
      throw Exception('Invalid crop dimensions');
    }

    // Crop the region (copyCrop takes: src, x, y, width, height)
    final cropped = img.copyCrop(originalImage, left, top, width, height);

    // Resize to MobileNetV3 input size (224x224)
    final resized = img.copyResize(
      cropped,
      width: mobilenetInputSize,
      height: mobilenetInputSize,
    );

    // Convert to Float32List in NCHW format (channels first) with ImageNet normalization
    // Format: [R values..., G values..., B values...]
    // ImageNet normalization: (pixel/255.0 - mean) / std
    // mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]
    final input = Float32List(mobilenetInputSize * mobilenetInputSize * 3);
    final pixels = resized.getBytes();

    final size = mobilenetInputSize * mobilenetInputSize;

    // ImageNet normalization constants
    const meanR = 0.485;
    const meanG = 0.456;
    const meanB = 0.406;
    const stdR = 0.229;
    const stdG = 0.224;
    const stdB = 0.225;

    // Extract R, G, B channels separately for NCHW format with ImageNet normalization
    for (int y = 0; y < mobilenetInputSize; y++) {
      for (int x = 0; x < mobilenetInputSize; x++) {
        final pixelIndex = (y * mobilenetInputSize + x) * 4;

        // Normalize to [0,1] then apply ImageNet normalization
        final r = (pixels[pixelIndex] / 255.0 - meanR) / stdR;
        final g = (pixels[pixelIndex + 1] / 255.0 - meanG) / stdG;
        final b = (pixels[pixelIndex + 2] / 255.0 - meanB) / stdB;

        // NCHW format: all R values first, then all G, then all B
        final idx = y * mobilenetInputSize + x;
        input[idx] = r; // R channel
        input[idx + size] = g; // G channel
        input[idx + size * 2] = b; // B channel
      }
    }

    return input;
  }

  // Classify a cropped region using MobileNetV3
  Future<Map<String, dynamic>> _classifyWithMobileNet(
    img.Image originalImage,
    Rect box,
  ) async {
    ort.OrtValueTensor? inputTensor;
    ort.OrtRunOptions? runOptions;
    List<ort.OrtValue?>? outputs;

    try {
      // 1️⃣ Prepare input (Float32List)
      final Float32List inputData = _prepareCropForMobileNet(
        originalImage,
        box,
      );

      // 2️⃣ Create tensor using TYPED DATA (THIS IS THE FIX)
      inputTensor = ort.OrtValueTensor.createTensorWithDataList(
        inputData,
        [1, 3, mobilenetInputSize, mobilenetInputSize], // NCHW
      );

      // 3️⃣ Run inference
      runOptions = ort.OrtRunOptions();
      outputs = await _mobilenetSession!.runAsync(runOptions, {
        'input': inputTensor,
      });

      if (outputs == null || outputs.isEmpty) {
        return {'label': 'Unknown', 'confidence': 0.0};
      }

      // 4️⃣ Extract logits
      final ort.OrtValueTensor outputTensor =
          outputs.first as ort.OrtValueTensor;

      // Handle nested list structure (output shape is [1, 9] for batch_size=1, num_classes=9)
      final dynamic outputValue = outputTensor.value;
      List<double> logits;

      if (outputValue is List) {
        // Check if it's nested (e.g., [[...]])
        if (outputValue.isNotEmpty && outputValue.first is List) {
          // Flatten nested structure: take first batch element
          logits =
              (outputValue.first as List)
                  .map<double>((e) => e.toDouble())
                  .toList();
        } else {
          // Already flat list
          logits = outputValue.map<double>((e) => e.toDouble()).toList();
        }
      } else {
        throw Exception(
          'Unexpected output tensor value type: ${outputValue.runtimeType}',
        );
      }

      // 5️⃣ Softmax with optional temperature scaling
      // Temperature = 1.0 means no scaling (use raw softmax) - best for training data
      // Temperature > 1 makes distribution softer (less overconfident) - use for overfitted models
      final maxLogit = logits.reduce(math.max);

      // Calculate raw softmax (temperature = 1.0) for comparison
      final rawScaledLogits = logits.map((e) => (e - maxLogit) / 1.0).toList();
      final rawExpVals = rawScaledLogits.map((e) => math.exp(e)).toList();
      final rawSumExp = rawExpVals.reduce((a, b) => a + b);
      final rawProbs = rawExpVals.map((e) => e / rawSumExp).toList();

      // Calculate temperature-scaled softmax
      final scaledLogits =
          logits.map((e) => (e - maxLogit) / _currentTemperature).toList();
      final expVals = scaledLogits.map((e) => math.exp(e)).toList();
      final sumExp = expVals.reduce((a, b) => a + b);
      final probs = expVals.map((e) => e / sumExp).toList();

      // 6️⃣ Argmax
      int bestIdx = 0;
      double bestConf = probs[0];
      double rawBestConf = rawProbs[0];

      for (int i = 1; i < probs.length; i++) {
        if (probs[i] > bestConf) {
          bestConf = probs[i];
          bestIdx = i;
        }
        if (rawProbs[i] > rawBestConf) {
          rawBestConf = rawProbs[i];
        }
      }

      final label =
          bestIdx < _classificationLabels.length
              ? _classificationLabels[bestIdx]
              : 'Unknown';

      // Use temperature-scaled confidence (or raw if temperature = 1.0)
      double adjustedConfidence = bestConf;

      // Debug: Show raw confidence vs adjusted confidence
      if (_currentTemperature != 1.0) {
        print(
          '📊 Confidence: Raw=${(rawBestConf * 100).toStringAsFixed(2)}%, Adjusted (T=${_currentTemperature})=${(adjustedConfidence * 100).toStringAsFixed(2)}%',
        );
      }

      // Apply minimum confidence threshold (75%) using adjusted confidence
      if (adjustedConfidence < _currentMobilenetConfidenceThreshold) {
        print(
          '⚠️  Classification confidence too low: $label (${(adjustedConfidence * 100).toStringAsFixed(2)}%) < ${(_currentMobilenetConfidenceThreshold * 100).toStringAsFixed(0)}%',
        );
        return {'label': 'Unknown', 'confidence': 0.0};
      }

      print(
        '✅ Classification: $label (${(adjustedConfidence * 100).toStringAsFixed(2)}%)',
      );

      return {'label': label, 'confidence': adjustedConfidence};
    } catch (e, s) {
      print('❌ MobileNetV3 error: $e');
      print(s);
      return {'label': 'Unknown', 'confidence': 0.0};
    } finally {
      inputTensor?.release();
      runOptions?.release();
      outputs?.forEach((o) => o?.release());
    }
  }

  Future<List<DetectionResult>> detectDiseases(String imagePath) async {
    if (_yoloInterpreter == null || _mobilenetSession == null) {
      await loadModel();
    }

    try {
      final image = img.decodeImage(File(imagePath).readAsBytesSync());
      if (image == null) throw Exception('Image decoding failed');

      // Stage 1: YOLO detects bounding boxes
      final resized = letterbox(image, yoloInputSize, yoloInputSize);
      final input = Float32List(yoloInputSize * yoloInputSize * 3);
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

      // YOLO26 output shape: (1, 300, 6)
      // Post-processed detections: [x, y, w, h, confidence, class_id]
      // Using this format avoids the shape mismatch you see in the logs: [1, 300, 6]
      final inputShape = [1, yoloInputSize, yoloInputSize, 3];
      final outputShape = [1, 300, 6];

      final output = List.filled(
        outputShape.reduce((a, b) => a * b),
        0.0,
      ).reshape(outputShape);

      _yoloInterpreter!.run(input.reshape(inputShape), output);

      final outputData = output[0]; // Shape: (300, 6)

      print('🔍 Detection Debug Info:');
      print('   - Image size: ${image.width}x${image.height}');
      print('   - YOLO input size: ${yoloInputSize}x${yoloInputSize}');
      print(
        '   - MobileNetV3 input size: ${mobilenetInputSize}x${mobilenetInputSize}',
      );
      print('   - Classification labels: ${_classificationLabels.length}');
      print('   - Confidence threshold: $_currentConfidenceThreshold');

      // Extract bounding boxes from YOLO26 output (post-processed [1, 300, 6])
      // For Ultralytics TFLite exports, the detection head typically returns
      // [x1, y1, x2, y2, confidence, class_id] NORMALIZED to the network
      // input size (640x640) after letterboxing. So we:
      //  - treat [x1, y1, x2, y2] as corner-format, normalized 0–1 wrt 640x640
      //  - map from 640x640 letterboxed space back to the ORIGINAL image.
      final detections = <Map<String, dynamic>>[];

      // Letterboxing parameters (how we resized the original image into 640x640)
      final scale = math.min(
        yoloInputSize / image.width,
        yoloInputSize / image.height,
      );
      final newUnpaddedW = image.width * scale;
      final newUnpaddedH = image.height * scale;
      final padX = (yoloInputSize - newUnpaddedW) / 2;
      final padY = (yoloInputSize - newUnpaddedH) / 2;

      // Minimum box size (as percentage of image) to filter out tiny noise.
      // We deliberately DO NOT cap the maximum size so that a single large
      // leaf filling most of the image is still allowed as a valid detection.
      const minBoxSizePercent = 0.01; // 1% of image size
      final minBoxWidth = image.width * minBoxSizePercent;
      final minBoxHeight = image.height * minBoxSizePercent;

      for (var i = 0; i < 300; i++) {
        // YOLO26 output format (TFLite): [x1, y1, x2, y2, confidence, class_id]
        final detection = outputData[i];

        final x1n =
            (detection[0] as num).toDouble(); // Normalized 0-1 (640 space)
        final y1n =
            (detection[1] as num).toDouble(); // Normalized 0-1 (640 space)
        final x2n =
            (detection[2] as num).toDouble(); // Normalized 0-1 (640 space)
        final y2n =
            (detection[3] as num).toDouble(); // Normalized 0-1 (640 space)
        final confidence = (detection[4] as num).toDouble(); // Confidence score
        // detection[5] is class_id (not used here, MobileNet handles class)

        // Skip invalid / low-confidence detections
        if (confidence <= 0 || confidence < _currentConfidenceThreshold) {
          continue;
        }

        // Validate coordinates
        if (x1n < 0 ||
            x1n > 1 ||
            y1n < 0 ||
            y1n > 1 ||
            x2n < 0 ||
            x2n > 1 ||
            y2n < 0 ||
            y2n > 1 ||
            x2n <= x1n ||
            y2n <= y1n) {
          continue;
        }

        // Convert normalized 0–1 coords into 640x640 letterboxed pixels
        final yoloLeft = x1n * yoloInputSize;
        final yoloTop = y1n * yoloInputSize;
        final yoloRight = x2n * yoloInputSize;
        final yoloBottom = y2n * yoloInputSize;

        // Remove padding and scale back to original image space
        final originalLeft = (yoloLeft - padX) / scale;
        final originalTop = (yoloTop - padY) / scale;
        final originalRight = (yoloRight - padX) / scale;
        final originalBottom = (yoloBottom - padY) / scale;

        // Clamp to image bounds
        final clampedLeft = math.max(
          0.0,
          math.min(originalLeft, image.width.toDouble()),
        );
        final clampedTop = math.max(
          0.0,
          math.min(originalTop, image.height.toDouble()),
        );
        final clampedRight = math.max(
          0.0,
          math.min(originalRight, image.width.toDouble()),
        );
        final clampedBottom = math.max(
          0.0,
          math.min(originalBottom, image.height.toDouble()),
        );

        final boxWidth = clampedRight - clampedLeft;
        final boxHeight = clampedBottom - clampedTop;

        // Filter out boxes that are too small (likely noise). Large boxes
        // are now allowed so that single-object close-up images are kept.
        if (boxWidth < minBoxWidth || boxHeight < minBoxHeight) {
          continue;
        }

        if (boxWidth <= 0 || boxHeight <= 0) {
          continue;
        }

        final box = Rect.fromLTRB(
          clampedLeft,
          clampedTop,
          clampedRight,
          clampedBottom,
        );

        detections.add({'box': box, 'objectness': confidence});
      }

      // Sort by objectness (highest confidence first)
      detections.sort(
        (a, b) =>
            (b['objectness'] as double).compareTo(a['objectness'] as double),
      );

      // Apply NMS to reduce overlapping boxes from YOLO26
      final nmsResults = <Map<String, dynamic>>[];
      while (detections.isNotEmpty) {
        final detection = detections.removeAt(0);
        nmsResults.add(detection);

        final detectionBox = detection['box'] as Rect;
        final detectionArea = detectionBox.width * detectionBox.height;

        detections.removeWhere((other) {
          final otherBox = other['box'] as Rect;
          final otherArea = otherBox.width * otherBox.height;

          final intersection = detectionBox.intersect(otherBox);
          final intersectionArea = intersection.width * intersection.height;
          final unionArea = detectionArea + otherArea - intersectionArea;
          final iou = unionArea > 0 ? intersectionArea / unionArea : 0.0;

          // Use configurable NMS threshold (now moderate, not ultra-high)
          return iou > _currentNmsThreshold;
        });
      }

      // Limit how many boxes go to classification to avoid many overlapping crops
      const maxDetectionsForClassification = 10;
      final limitedNmsResults =
          nmsResults.length > maxDetectionsForClassification
              ? nmsResults.sublist(0, maxDetectionsForClassification)
              : nmsResults;

      print('📊 YOLO Detection Summary:');
      print('   - Valid detections (above threshold): ${nmsResults.length}');
      print(
        '   - Detections sent to classification (capped): ${limitedNmsResults.length}',
      );
      // Log YOLO objectness scores
      for (var i = 0; i < limitedNmsResults.length; i++) {
        final objectness = limitedNmsResults[i]['objectness'] as double;
        print(
          '   - Detection ${i + 1}: YOLO objectness = ${(objectness * 100).toStringAsFixed(2)}%',
        );
      }

      // Stage 2: Classify each detected box with MobileNetV3
      final results = <DetectionResult>[];

      for (var detection in limitedNmsResults) {
        final box = detection['box'] as Rect;
        final yoloObjectness = detection['objectness'] as double;

        // Classify with MobileNetV3
        final classification = await _classifyWithMobileNet(image, box);

        final label = classification['label'] as String;
        final classConfidence = classification['confidence'] as double;

        // Skip if MobileNet confidence is below minimum threshold (returns 'Unknown' with 0.0)
        // This hides boxes that don't meet the 75% confidence requirement
        if (label == 'Unknown' || classConfidence == 0.0) {
          print(
            '   - Skipped: YOLO=${(yoloObjectness * 100).toStringAsFixed(2)}%, MobileNet confidence below ${(_currentMobilenetConfidenceThreshold * 100).toStringAsFixed(0)}% threshold',
          );
          continue; // Skip this detection, don't show the box
        }

        // Combine objectness and classification confidence
        // You can use just classConfidence or combine both
        final combinedConfidence =
            classConfidence; // Using MobileNetV3 confidence only

        results.add(
          DetectionResult(
            label: label,
            confidence: combinedConfidence,
            boundingBox: box,
          ),
        );

        print(
          '   - ${label}: YOLO=${(yoloObjectness * 100).toStringAsFixed(2)}%, MobileNet=${(combinedConfidence * 100).toStringAsFixed(2)}% at $box',
        );
      }

      print('📊 Final Results:');
      print('   - Total detections: ${results.length}');

      if (results.isEmpty) {
        print('⚠️  No objects detected! Consider:');
        print(
          '   - Lowering confidence threshold (currently $_currentConfidenceThreshold)',
        );
      }

      return results;
    } catch (e) {
      print('❌ Error during detection: $e');
      return [];
    }
  }

  // Method to adjust thresholds for better detection
  void setThresholds({
    double? confidence,
    double? nms,
    double? mobilenetConfidence,
    double? temperature,
  }) {
    if (confidence != null) {
      _currentConfidenceThreshold = confidence;
      print('🔧 YOLO confidence threshold set to: $confidence');
    }
    if (nms != null) {
      _currentNmsThreshold = nms;
      print('🔧 NMS threshold set to: $nms');
    }
    if (mobilenetConfidence != null) {
      _currentMobilenetConfidenceThreshold = mobilenetConfidence;
      print('🔧 MobileNet confidence threshold set to: $mobilenetConfidence');
    }
    if (temperature != null) {
      _currentTemperature = temperature;
      print(
        '🔧 Temperature scaling set to: $temperature (1.0 = no scaling, higher = less confident)',
      );
    }
  }

  // Method to reset to default thresholds
  void resetThresholds() {
    _currentConfidenceThreshold = confidenceThreshold;
    _currentNmsThreshold = nmsThreshold;
    _currentMobilenetConfidenceThreshold = mobilenetConfidenceThreshold;
    _currentTemperature = defaultTemperature;
    print(
      '🔄 Thresholds reset to defaults: YOLO=$confidenceThreshold, NMS=$nmsThreshold, MobileNet=$mobilenetConfidenceThreshold, Temperature=$defaultTemperature',
    );
  }

  // Method to test different threshold combinations
  Future<List<DetectionResult>> detectWithThresholds(
    String imagePath, {
    double? confidence,
    double? nms,
    double? mobilenetConfidence,
    double? temperature,
  }) async {
    final originalConfidence = _currentConfidenceThreshold;
    final originalNms = _currentNmsThreshold;
    final originalMobilenetConfidence = _currentMobilenetConfidenceThreshold;
    final originalTemperature = _currentTemperature;

    setThresholds(
      confidence: confidence,
      nms: nms,
      mobilenetConfidence: mobilenetConfidence,
      temperature: temperature,
    );
    final results = await detectDiseases(imagePath);

    // Restore original thresholds
    _currentConfidenceThreshold = originalConfidence;
    _currentNmsThreshold = originalNms;
    _currentMobilenetConfidenceThreshold = originalMobilenetConfidence;
    _currentTemperature = originalTemperature;

    return results;
  }

  /// Configure detector for a model trained with less duplication/overfitting.
  /// Default temperature is now 1.0 (no scaling) which works well for properly trained models.
  ///
  /// Temperature guide:
  /// - 1.0 = No scaling (default, best for training data and well-trained models)
  /// - 1.2-1.5 = Minimal scaling (for slightly overconfident models)
  /// - 2.0+ = More aggressive scaling (for overfitted models)
  void configureForLessDuplicationModel({
    double temperature =
        1.0, // No scaling by default for properly trained models
  }) {
    setThresholds(temperature: temperature);
    print(
      '✅ Configured for model with less duplication: temperature=$temperature',
    );
  }

  void closeModel() {
    _yoloInterpreter?.close();
    _yoloInterpreter = null;
    _mobilenetSession?.release();
    _mobilenetSession = null;
    ort.OrtEnv.instance.release();
    print('✅ Models closed');
  }
}
