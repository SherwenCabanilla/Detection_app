import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'camera_page.dart';
import 'analysis_summary_screen.dart';
import 'tflite_detector.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:async';
import 'package:flutter/scheduler.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({Key? key}) : super(key: key);

  @override
  _ScanPageState createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
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
          tr('processing_images'),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }

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

  // Analysis method with UI yielding to keep it responsive
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

  Future<void> _takePicture(BuildContext context) async {
    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
    );

    if (photo != null) {
      // Navigate to camera page with the first photo
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CameraPage(initialPhoto: photo.path),
        ),
      );
    }
  }

  Future<void> _selectFromGallery(BuildContext context) async {
    final ImagePicker picker = ImagePicker();
    final List<XFile>? images = await picker.pickMultiImage();
    if (images != null && images.isNotEmpty) {
      if (images.length > 5) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('maximum_images')),
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      }

      // Show loading dialog IMMEDIATELY after image selection
      print('DEBUG: Showing loading dialog for analysis...');
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
                      if (!isAnalysisComplete) {
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
                        tr('processing_please_wait'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
      );
      print('DEBUG: Loading dialog should be visible now');

      // Add a delay to ensure dialog is rendered and visible
      await Future.delayed(const Duration(milliseconds: 300));

      try {
        // Perform analysis on all images with UI yielding
        print('DEBUG: Starting analysis with UI yielding...');
        final List<String> imagePaths = images.map((img) => img.path).toList();

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
    }
  }

  void _showImageTipsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
            maxWidth: MediaQuery.of(context).size.width * 0.9,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb_outline, color: Colors.amber[700], size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        tr('tips_for_best_results'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Image Quality Tips
                      _buildTipSection(
                        icon: Icons.camera_alt,
                        iconColor: Colors.blue,
                        title: tr('image_quality_tips'),
                        tips: [
                          tr('tip_distance'),
                          tr('tip_lighting'),
                          tr('tip_focus'),
                          tr('tip_clean_lens'),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Important Notice
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.orange.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.warning_amber_rounded, color: Colors.orange[700], size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    tr('important_notice'),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Colors.orange[900],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              tr('accuracy_disclaimer'),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[800],
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              // Actions
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        tr('got_it'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTipSection({
    required IconData icon,
    required Color iconColor,
    required String title,
    required List<String> tips,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...tips.map((tip) => Padding(
          padding: const EdgeInsets.only(left: 28, bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '• ',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
              Expanded(
                child: Text(
                  tip,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        )).toList(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Header Section with Scanning Effect
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.green.withOpacity(0.3),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.1),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Scanning frame effect around the icon
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.green.withOpacity(0.4),
                            width: 3,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          color: Colors.green.withOpacity(0.05),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Icon(Icons.eco, size: 60, color: Colors.green[700]),
                            // Scanning corner indicators
                            Positioned(
                              top: 0,
                              left: 0,
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  border: Border(
                                    top: BorderSide(
                                      color: Colors.green,
                                      width: 3,
                                    ),
                                    left: BorderSide(
                                      color: Colors.green,
                                      width: 3,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 0,
                              right: 0,
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  border: Border(
                                    top: BorderSide(
                                      color: Colors.green,
                                      width: 3,
                                    ),
                                    right: BorderSide(
                                      color: Colors.green,
                                      width: 3,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              left: 0,
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: Colors.green,
                                      width: 3,
                                    ),
                                    left: BorderSide(
                                      color: Colors.green,
                                      width: 3,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: Colors.green,
                                      width: 3,
                                    ),
                                    right: BorderSide(
                                      color: Colors.green,
                                      width: 3,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        tr('scan'),
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        tr('choose_analysis_method'),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 16),
                      // Tips Button
                      OutlinedButton.icon(
                        onPressed: () => _showImageTipsDialog(context),
                        icon: const Icon(Icons.info_outline, size: 20),
                        label: Text(tr('image_tips')),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green[700],
                          side: BorderSide(color: Colors.green.withOpacity(0.5)),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                // Action Buttons
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _takePicture(context),
                    icon: const Icon(Icons.camera_alt, size: 24),
                    label: Text(
                      tr('take_photo'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 20,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _selectFromGallery(context),
                    icon: const Icon(Icons.photo_library, size: 24),
                    label: Text(
                      tr('select_from_gallery'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 20,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
