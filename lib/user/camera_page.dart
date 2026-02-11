import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'analysis_summary_screen.dart';
import 'tflite_detector.dart';
import 'package:path_provider/path_provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:lottie/lottie.dart';
import 'dart:async';
import 'package:flutter/scheduler.dart';

class CameraPage extends StatefulWidget {
  final String? initialPhoto;
  const CameraPage({Key? key, this.initialPhoto}) : super(key: key);

  @override
  _CameraPageState createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  final ImagePicker _picker = ImagePicker();
  late List<String> _capturedImages;
  bool _isProcessing = false;
  int _processedImages = 0;

  @override
  void initState() {
    super.initState();
    _capturedImages = widget.initialPhoto != null ? [widget.initialPhoto!] : [];
  }

  Widget _buildProcessingIndicator() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // GIF Animation (smooth in release builds)
        SizedBox(
          width: 120,
          height: 120,
          child: Image.asset('assets/animation.gif', fit: BoxFit.contain),
        ),
        const SizedBox(height: 16),
        // Processing text
        Text(
          'Processing...',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }

  Future<String> saveImagePermanently(
    String originalPath,
    String filename,
  ) async {
    final directory = await getApplicationDocumentsDirectory();
    final newPath = '${directory.path}/$filename';
    final newFile = await File(originalPath).copy(newPath);
    return newFile.path;
  }

  Future<void> _takePicture() async {
    if (_capturedImages.length >= 5) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Maximum 5 photos allowed')));
      return;
    }

    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (photo != null) {
        // Save to persistent directory
        final filename = 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final persistentPath = await saveImagePermanently(photo.path, filename);
        setState(() {
          _capturedImages.add(persistentPath);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Photo ${_capturedImages.length}/5 saved - ${_capturedImages.length < 5 ? "Take ${5 - _capturedImages.length} more or " : ""}press Process',
            ),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(bottom: 80, left: 16, right: 16),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error taking picture: $e');
    }
  }

  Future<void> _processPhotos() async {
    if (_capturedImages.isEmpty) return;

    setState(() {
      _isProcessing = true;
      _processedImages = 0;
    });

    // Show Lottie loading dialog IMMEDIATELY when analyze button is pressed
    print('DEBUG: Showing Lottie loading dialog for analysis...');
    Timer? animationTimer;
    bool isAnalysisComplete = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setDialogState) {
              // Start a timer to force UI updates during analysis
              if (animationTimer == null) {
                animationTimer = Timer.periodic(
                  const Duration(milliseconds: 16),
                  (timer) {
                    if (!isAnalysisComplete && mounted) {
                      setDialogState(() {
                        // Force a rebuild to keep animation running
                      });
                    } else {
                      timer.cancel();
                    }
                  },
                );
              }

              return AlertDialog(
                title: Text(tr('analyzing_images')),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Simple processing indicator
                    _buildProcessingIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      'Analyzing ${_capturedImages.length} image${_capturedImages.length > 1 ? 's' : ''}...',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please wait, this may take a moment...',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[500], fontSize: 14),
                    ),
                  ],
                ),
              );
            },
          ),
    );
    print('DEBUG: Lottie loading dialog should be visible now');

    // Add a delay to ensure dialog is rendered and visible
    await Future.delayed(const Duration(milliseconds: 300));

    try {
      // Perform analysis on all images with UI yielding
      print('DEBUG: Starting analysis with UI yielding...');
      final List<String> imagePaths = List.from(_capturedImages);

      // Run analysis with UI yielding to keep it responsive
      final Map<int, List<DetectionResult>> allResults =
          await _performAnalysisWithUIYielding(imagePaths);

      print('DEBUG: Analysis completed, ensuring smooth transition...');

      // Stop the animation timer
      isAnalysisComplete = true;
      animationTimer?.cancel();

      // Add a longer delay for smooth user experience
      await Future.delayed(const Duration(milliseconds: 800));

      // Close loading dialog smoothly
      Navigator.pop(context);
      print('DEBUG: Dialog closed smoothly');

      // Validate detection results before navigating
      final validationResult = _validateDetectionResults(allResults);
      if (validationResult != null) {
        // Show error message as modal dialog and don't proceed
        _showValidationErrorDialog(context, validationResult);
        return;
      }

      // Navigate directly to analysis summary
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => AnalysisSummaryScreen(
                allResults: allResults,
                imagePaths: imagePaths,
              ),
        ),
      );
    } catch (e) {
      // Stop the animation timer
      isAnalysisComplete = true;
      animationTimer?.cancel();

      // Close loading dialog
      Navigator.pop(context);

      // Show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error analyzing images: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }

    setState(() {
      _capturedImages.clear();
      _isProcessing = false;
    });
  }

  Future<void> _selectFromGallery() async {
    final List<XFile>? images = await _picker.pickMultiImage();
    if (images != null && images.isNotEmpty) {
      if (images.length > 5) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Maximum 5 images can be selected'),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }
      // Save all selected images to persistent directory
      List<String> persistentPaths = [];
      for (var img in images) {
        final filename =
            'gallery_${DateTime.now().millisecondsSinceEpoch}_${img.name}';
        final persistentPath = await saveImagePermanently(img.path, filename);
        persistentPaths.add(persistentPath);
      }
      setState(() {
        _capturedImages.addAll(persistentPaths);
      });
      // Show Lottie loading dialog IMMEDIATELY after gallery selection
      print('DEBUG: Showing Lottie loading dialog for gallery analysis...');
      Timer? animationTimer2;
      bool isAnalysisComplete2 = false;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => StatefulBuilder(
              builder: (context, setDialogState) {
                // Start a timer to force UI updates during analysis
                if (animationTimer2 == null) {
                  animationTimer2 = Timer.periodic(
                    const Duration(milliseconds: 16),
                    (timer) {
                      if (!isAnalysisComplete2 && mounted) {
                        setDialogState(() {
                          // Force a rebuild to keep animation running
                        });
                      } else {
                        timer.cancel();
                      }
                    },
                  );
                }

                return AlertDialog(
                  title: Text(tr('analyzing_images')),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // GIF Animation (smoother than custom Flutter animation)
                      SizedBox(
                        width: 120,
                        height: 120,
                        child: Image.asset(
                          'assets/ani.gif',
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Analyzing ${persistentPaths.length} image${persistentPaths.length > 1 ? 's' : ''}...',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please wait, this may take a moment...',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[500], fontSize: 14),
                      ),
                    ],
                  ),
                );
              },
            ),
      );
      print('DEBUG: Lottie loading dialog should be visible now');

      // Add a delay to ensure dialog is rendered and visible
      await Future.delayed(const Duration(milliseconds: 300));

      try {
        // Perform analysis on all images with UI yielding
        print('DEBUG: Starting gallery analysis with UI yielding...');

        // Run analysis with UI yielding to keep it responsive
        final Map<int, List<DetectionResult>> allResults =
            await _performAnalysisWithUIYielding(persistentPaths);

        print(
          'DEBUG: Gallery analysis completed, ensuring smooth transition...',
        );

        // Stop the animation timer
        isAnalysisComplete2 = true;
        animationTimer2?.cancel();

        // Add a longer delay for smooth user experience
        await Future.delayed(const Duration(milliseconds: 800));

        // Close loading dialog smoothly
        Navigator.pop(context);
        print('DEBUG: Gallery dialog closed smoothly');

        // Validate detection results before navigating
        final validationResult = _validateDetectionResults(allResults);
        if (validationResult != null) {
          // Show error message as modal dialog and don't proceed
          _showValidationErrorDialog(context, validationResult);
          return;
        }

        // Navigate directly to analysis summary
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => AnalysisSummaryScreen(
                  allResults: allResults,
                  imagePaths: persistentPaths,
                ),
          ),
        );
      } catch (e) {
        // Stop the animation timer
        isAnalysisComplete2 = true;
        animationTimer2?.cancel();

        // Close loading dialog
        Navigator.pop(context);

        // Show error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error analyzing images: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildPhotoGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _capturedImages.length,
      itemBuilder: (context, index) {
        // Photo preview
        return Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(_capturedImages[index]),
                fit: BoxFit.cover,
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () {
                    setState(() {
                      _capturedImages.removeAt(index);
                    });
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Take photos',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green,
        actions: [
          if (_capturedImages.length < 5)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextButton.icon(
                onPressed: _takePicture,
                icon: const Icon(Icons.add_a_photo, color: Colors.green),
                label: Text(
                  'Add Photo (${_capturedImages.length}/5)',
                  style: const TextStyle(color: Colors.green),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child:
                _capturedImages.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.camera_alt,
                            size: 64,
                            color: Colors.green[300],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No photos taken yet',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.green[700],
                            ),
                          ),
                        ],
                      ),
                    )
                    : _buildPhotoGrid(),
          ),
          if (_capturedImages.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: _processPhotos,
                icon: const Icon(Icons.analytics),
                label: Text(
                  'Analyze ${_capturedImages.length} Photo${_capturedImages.length > 1 ? 's' : ''}',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Analysis method with UI yielding to keep it responsive
  // Show validation error as modal dialog
  void _showValidationErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange[700],
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Warning',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[700],
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(
              'OK',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.orange[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Validate detection results - returns error message if validation fails, null if OK
  String? _validateDetectionResults(Map<int, List<DetectionResult>> allResults) {
    // All detections are now allowed to proceed to analysis summary
    // Warnings will be shown in the analysis summary screen instead
    return null;
  }

  Future<Map<int, List<DetectionResult>>> _performAnalysisWithUIYielding(
    List<String> imagePaths,
  ) async {
    final TFLiteDetector detector = TFLiteDetector();
    await detector.loadModel();
    print('DEBUG: Model loaded, starting detection...');

    final Map<int, List<DetectionResult>> allResults = {};

    for (int i = 0; i < imagePaths.length; i++) {
      print('DEBUG: Analyzing image ${i + 1}/${imagePaths.length}');

      // Multiple UI yielding attempts
      await Future.delayed(const Duration(milliseconds: 100));
      await SchedulerBinding.instance.endOfFrame;
      await Future.delayed(const Duration(milliseconds: 50));

      final results = await detector.detectDiseases(imagePaths[i]);
      allResults[i] = results;

      // Additional UI yielding after each detection
      await Future.delayed(const Duration(milliseconds: 30));
      await SchedulerBinding.instance.endOfFrame;
    }

    detector.closeModel();
    return allResults;
  }
}
