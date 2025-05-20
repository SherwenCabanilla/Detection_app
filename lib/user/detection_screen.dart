import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;

import 'tflite_detector.dart';
import 'detection_painter.dart';

/// A live camera feed running ONNX object detection on each frame.
class RealtimeDetectionScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const RealtimeDetectionScreen({Key? key, required this.cameras})
    : super(key: key);

  @override
  _RealtimeDetectionScreenState createState() =>
      _RealtimeDetectionScreenState();
}

class _RealtimeDetectionScreenState extends State<RealtimeDetectionScreen> {
  CameraController? _controller;
  bool _isDetecting = false;
  final TFLiteDetector _detector = TFLiteDetector();
  List<DetectionResult> _results = [];
  Size _imageSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _detector.loadModel().then((_) => _initCamera());
  }

  /// Initialize camera and start streaming frames.
  Future<void> _initCamera() async {
    final camera = widget.cameras.first;
    _controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
    );
    await _controller!.initialize();
    await _controller!.startImageStream(_processFrame);
    setState(() {});
  }

  /// Process each incoming camera frame.
  Future<void> _processFrame(CameraImage frame) async {
    if (_isDetecting) return;
    _isDetecting = true;

    try {
      // Convert YUV to RGB
      final rgb = _convertYUV420toImage(frame);
      // Save the frame
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/frame.jpg';
      await File(path).writeAsBytes(img.encodeJpg(rgb));

      // Run detection
      final detections = await _detector.detectDiseases(path);

      setState(() {
        _results = detections;
        _imageSize = Size(frame.width.toDouble(), frame.height.toDouble());
      });
    } catch (e) {
      print('Error processing frame: $e');
    }

    _isDetecting = false;
  }

  /// Helper to convert YUV420 camera image to rgb image.
  img.Image _convertYUV420toImage(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final imgData = img.Image(width, height);
    final yPlane = image.planes[0].bytes;
    final uPlane = image.planes[1].bytes;
    final vPlane = image.planes[2].bytes;
    final uvRowStride = image.planes[1].bytesPerRow;
    final uvPixelStride = image.planes[1].bytesPerPixel!;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final uvIndex = uvPixelStride * (x >> 1) + uvRowStride * (y >> 1);
        final yp = yPlane[y * width + x];
        final up = uPlane[uvIndex];
        final vp = vPlane[uvIndex];
        final r = (yp + vp * 1436 / 1024 - 179).clamp(0, 255).toInt();
        final g =
            (yp - up * 46549 / 131072 + 44 - vp * 93604 / 131072 + 91)
                .clamp(0, 255)
                .toInt();
        final b = (yp + up * 1814 / 1024 - 227).clamp(0, 255).toInt();
        imgData.setPixelRgba(x, y, r, g, b);
      }
    }
    return imgData;
  }

  @override
  void dispose() {
    _controller?.dispose();
    _detector.closeModel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Live Detection')),
      body: Stack(
        children: [
          CameraPreview(_controller!),
          CustomPaint(
            size: Size.infinite,
            painter: DetectionPainter(
              results: _results,
              originalImageSize: _imageSize,
              displayedImageSize: MediaQuery.of(context).size,
              displayedImageOffset: Offset.zero,
            ),
          ),
        ],
      ),
    );
  }
}

class DetectionScreen extends StatefulWidget {
  final String imagePath;
  final List<DetectionResult>? results;
  final Size? imageSize;
  final List<String>? allImagePaths;
  final int? currentIndex;
  final List<List<DetectionResult>>? allResults;
  final List<Size>? imageSizes;
  final bool showAppBar;
  final bool showBoundingBoxes;

  const DetectionScreen({
    Key? key,
    required this.imagePath,
    this.results,
    this.imageSize,
    this.allImagePaths,
    this.currentIndex,
    this.allResults,
    this.imageSizes,
    this.showAppBar = true,
    this.showBoundingBoxes = true,
  }) : super(key: key);

  @override
  State<DetectionScreen> createState() => _DetectionScreenState();
}

class _DetectionScreenState extends State<DetectionScreen> {
  List<DetectionResult>? _results;
  Size? _imageSize;
  bool _isLoading = true;
  bool _showBoxes = true;
  GlobalKey _imageKey = GlobalKey();
  Size _displaySize = Size.zero;
  Offset _displayOffset = Offset.zero;

  @override
  void initState() {
    super.initState();
    _showBoxes = widget.showBoundingBoxes;

    if (widget.results != null && widget.imageSize != null) {
      _results = widget.results;
      _imageSize = widget.imageSize;
      _isLoading = false;
      print('✅ Received ${_results?.length ?? 0} results from widget');
      if (_results != null) {
        for (var result in _results!) {
          print(
            '📊 Result: ${result.label} (${result.confidence}) at ${result.boundingBox}',
          );
        }
      }
    } else {
      print('⚠️ No results provided, loading model to detect');
      _loadModelAndDetect();
    }

    // Update display size after layout
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateDisplaySize();
    });
  }

  void _updateDisplaySize() {
    try {
      final RenderBox? box =
          _imageKey.currentContext?.findRenderObject() as RenderBox?;
      if (box != null) {
        setState(() {
          _displaySize = box.size;
          _displayOffset = box.localToGlobal(Offset.zero);
          print(
            '✅ Updated display size: $_displaySize, offset: $_displayOffset',
          );
        });
      }
    } catch (e) {
      print('❌ Error updating display size: $e');
    }
  }

  Future<void> _loadModelAndDetect() async {
    try {
      final detector = TFLiteDetector();
      await detector.loadModel();
      print('✅ Model loaded, detecting diseases in ${widget.imagePath}');
      final results = await detector.detectDiseases(widget.imagePath);
      print('✅ Detection complete, found ${results.length} results');
      final image = File(widget.imagePath);
      final decodedImage = await image.readAsBytes();
      final imageInfo = await decodeImageFromList(decodedImage);

      if (mounted) {
        setState(() {
          _results = results;
          _imageSize = Size(
            imageInfo.width.toDouble(),
            imageInfo.height.toDouble(),
          );
          _isLoading = false;
          print(
            '✅ State updated with ${_results?.length ?? 0} results and image size $_imageSize',
          );
          for (var result in _results!) {
            print(
              '📊 Result: ${result.label} (${result.confidence}) at ${result.boundingBox}',
            );
          }
        });
      }
      detector.closeModel();
    } catch (e) {
      print('❌ Error during detection: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatLabel(String label) {
    switch (label.toLowerCase()) {
      case 'backterial_blackspot':
        return 'Bacterial black spot';
      case 'powdery_mildew':
        return 'Powdery Mildew';
      case 'tip_burn':
        return 'Tip Burn';
      default:
        return label
            .split('_')
            .map((word) => word[0].toUpperCase() + word.substring(1))
            .join(' ');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Get the screen size
    final screenSize = MediaQuery.of(context).size;
    // Determine the size of the container to display the image
    final displayWidth = screenSize.width;
    final displayHeight = screenSize.height * 0.7; // Use 70% of screen height

    return Scaffold(
      appBar:
          widget.showAppBar
              ? AppBar(
                title: const Text('Detection Results'),
                backgroundColor: Colors.green,
                actions: [
                  IconButton(
                    icon: Icon(
                      _showBoxes ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _showBoxes = !_showBoxes;
                      });
                    },
                  ),
                ],
              )
              : null,
      body: Column(
        children: [
          Center(
            child: Container(
              key: _imageKey,
              width: displayWidth,
              height: displayHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Display the image with BoxFit.contain to maintain aspect ratio
                  Image.file(
                    File(widget.imagePath),
                    width: displayWidth,
                    height: displayHeight,
                    fit: BoxFit.contain,
                  ),
                  if (_results != null && _showBoxes)
                    LayoutBuilder(
                      builder: (context, constraints) {
                        // Calculate the actual displayed image size
                        final imgW = _imageSize?.width ?? 1;
                        final imgH = _imageSize?.height ?? 1;
                        final widgetW = constraints.maxWidth;
                        final widgetH = constraints.maxHeight;

                        // Calculate scale and offset for BoxFit.contain
                        final scale =
                            imgW / imgH > widgetW / widgetH
                                ? widgetW /
                                    imgW // Width constrained
                                : widgetH / imgH; // Height constrained

                        final scaledW = imgW * scale;
                        final scaledH = imgH * scale;
                        final dx = (widgetW - scaledW) / 2;
                        final dy = (widgetH - scaledH) / 2;

                        print('📏 Widget dimensions: ${widgetW}x${widgetH}');
                        print('📏 Image dimensions: ${imgW}x${imgH}');
                        print('📏 Scale factor: $scale');
                        print('📏 Scaled image: ${scaledW}x${scaledH}');
                        print('📏 Offset: ($dx, $dy)');

                        return CustomPaint(
                          painter: DetectionPainter(
                            results: _results!,
                            originalImageSize: _imageSize!,
                            displayedImageSize: Size(scaledW, scaledH),
                            displayedImageOffset: Offset(dx, dy),
                            debugMode: true,
                          ),
                          size: Size(widgetW, widgetH),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),

          if (_results != null && _results!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Found ${_results!.length} detection${_results!.length > 1 ? 's' : ''}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[800],
                ),
              ),
            ),

          // Display detection details
          if (_results != null && _results!.isNotEmpty)
            Expanded(
              child: ListView.builder(
                itemCount: _results!.length,
                padding: EdgeInsets.symmetric(horizontal: 16),
                itemBuilder: (context, index) {
                  final result = _results![index];
                  return Card(
                    margin: EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            DetectionPainter.diseaseColors[result.label] ??
                            Colors.grey,
                        child: Text('${index + 1}'),
                      ),
                      title: Text(_formatLabel(result.label)),
                      subtitle: Text(
                        'Confidence: ${(result.confidence * 100).toStringAsFixed(1)}%',
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
