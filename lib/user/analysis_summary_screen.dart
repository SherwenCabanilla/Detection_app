import 'package:flutter/material.dart';
import 'dart:io';
import 'tflite_detector.dart';
import 'detection_painter.dart';
import 'detection_screen.dart';
import 'detection_carousel_screen.dart';

class AnalysisSummaryScreen extends StatefulWidget {
  final Map<int, List<DetectionResult>> allResults;
  final List<String> imagePaths;

  const AnalysisSummaryScreen({
    Key? key,
    required this.allResults,
    required this.imagePaths,
  }) : super(key: key);

  @override
  State<AnalysisSummaryScreen> createState() => _AnalysisSummaryScreenState();
}

class _AnalysisSummaryScreenState extends State<AnalysisSummaryScreen> {
  final Map<String, Size> imageSizes = {};
  bool showBoundingBoxes = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadImageSizes();
  }

  Map<String, int> _getOverallDiseaseCount() {
    final Map<String, int> counts = {};
    for (var results in widget.allResults.values) {
      for (var result in results) {
        counts[result.label] = (counts[result.label] ?? 0) + 1;
      }
    }
    return counts;
  }

  double _getDiseasePercentage(String disease, Map<String, int> diseaseCounts) {
    final totalLeaves = diseaseCounts.values.fold(0, (a, b) => a + b);
    if (totalLeaves == 0) return 0;
    return diseaseCounts[disease]! / totalLeaves;
  }

  Future<void> _loadImageSizes() async {
    for (int index = 0; index < widget.imagePaths.length; index++) {
      final image = File(widget.imagePaths[index]);
      final decodedImage = await image.readAsBytes();
      final imageInfo = await decodeImageFromList(decodedImage);
      if (mounted) {
        setState(() {
          imageSizes[widget.imagePaths[index]] = Size(
            imageInfo.width.toDouble(),
            imageInfo.height.toDouble(),
          );
        });
      }
    }
  }

  Future<void> _sendForExternalReview() async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      // Prepare the data in Firebase-friendly format
      final summaryData = {
        'metadata': {
          'timestamp': DateTime.now().toIso8601String(),
          'totalImages': widget.imagePaths.length,
          'totalDetections': _getOverallDiseaseCount().values.fold(
            0,
            (a, b) => a + b,
          ),
        },
        'images':
            widget.imagePaths.asMap().entries.map((entry) {
              final index = entry.key;
              final imagePath = entry.value;
              final results = widget.allResults[index] ?? [];
              final imageSize = imageSizes[imagePath] ?? const Size(1, 1);

              return {
                'imageId': 'image_$index', // Firebase-friendly ID
                'path': imagePath,
                'dimensions': {
                  'width': imageSize.width,
                  'height': imageSize.height,
                },
                'detections':
                    results.asMap().entries.map((detectionEntry) {
                      final detectionIndex = detectionEntry.key;
                      final result = detectionEntry.value;
                      return {
                        'detectionId':
                            'detection_${index}_$detectionIndex', // Firebase-friendly ID
                        'label': result.label,
                        'confidence': result.confidence,
                        'boundingBox': {
                          'left': result.boundingBox.left,
                          'top': result.boundingBox.top,
                          'right': result.boundingBox.right,
                          'bottom': result.boundingBox.bottom,
                        },
                        'timestamp': DateTime.now().toIso8601String(),
                      };
                    }).toList(),
              };
            }).toList(),
        'diseaseSummary':
            _getOverallDiseaseCount().entries
                .map(
                  (entry) => {
                    'diseaseId': entry.key.toLowerCase().replaceAll(
                      ' ',
                      '_',
                    ), // Firebase-friendly ID
                    'name': entry.key,
                    'count': entry.value,
                    'percentage': _getDiseasePercentage(
                      entry.key,
                      _getOverallDiseaseCount(),
                    ),
                    'severity': _getSeverityLevel(entry.key),
                  },
                )
                .toList(),
        'status': 'pending_review', // For tracking review status
      };

      // TODO: Replace with Firebase integration
      // Simulate network delay
      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Summary sent for external review'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send summary: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _getSeverityLevel(String disease) {
    final avgConfidence = _getDiseasePercentage(
      disease,
      _getOverallDiseaseCount(),
    );
    if (avgConfidence > 0.8) return 'high';
    if (avgConfidence > 0.5) return 'medium';
    return 'low';
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

  Widget _buildDiseaseSummaryCard(
    String disease,
    int count,
    Map<String, int> diseaseCounts,
  ) {
    final color = DetectionPainter.diseaseColors[disease] ?? Colors.grey;
    final percentage = _getDiseasePercentage(disease, diseaseCounts);
    final isHealthy = disease.toLowerCase() == 'healthy';

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          if (!isHealthy) {
            _showDiseaseRecommendations(context, disease);
          } else {
            _showHealthyStatus(context);
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Icon(
                        isHealthy ? Icons.check_circle : Icons.local_florist,
                        size: 16,
                        color: color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _formatLabel(disease),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$count found',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Percentage of Total Leaves',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: percentage,
                            backgroundColor: color.withOpacity(0.1),
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                            minHeight: 8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${(percentage * 100).toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isHealthy
                          ? Icons.info_outline
                          : Icons.medical_services_outlined,
                      color: color,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isHealthy ? 'View Status' : 'See Recommendation',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
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

  // Disease information (copied from homepage)
  static const Map<String, Map<String, dynamic>> diseaseInfo = {
    'anthracnose': {
      'symptoms': [
        'Irregular black or brown spots that expand and merge, leading to necrosis and leaf drop (Li et al., 2024).',
      ],
      'treatments': [
        'Apply copper-based fungicides like copper oxychloride or Mancozeb during wet and humid conditions to prevent spore germination.',
        'Prune mango trees regularly to improve air circulation and reduce humidity around foliage.',
        'Remove and burn infected leaves to limit reinfection cycles.',
      ],
    },
    'powdery_mildew': {
      'symptoms': [
        'A white, powdery fungal coating forms on young mango leaves, leading to distortion, yellowing, and reduced photosynthesis (Nasir, 2016).',
      ],
      'treatments': [
        'Use sulfur-based or systemic fungicides like tebuconazole at the first sign of infection and repeat at 10–14-day intervals.',
        'Avoid overhead irrigation which increases humidity and spore spread on leaf surfaces.',
        'Remove heavily infected leaves to reduce fungal load.',
      ],
    },
    'dieback': {
      'symptoms': [
        'Browning of leaf tips, followed by downward necrosis and eventual branch dieback (Ploetz, 2003).',
      ],
      'treatments': [
        'Prune affected twigs at least 10 cm below the last symptom to halt pathogen progression.',
        'Apply systemic fungicides such as carbendazim to protect surrounding healthy leaves.',
        'Maintain plant vigor through balanced nutrition and irrigation to resist infection.',
      ],
    },
    'backterial_blackspot': {
      'symptoms': [
        'Angular black lesions with yellow halos often appear along veins and can lead to early leaf drop (Ploetz, 2003).',
      ],
      'treatments': [
        'Apply copper hydroxide or copper oxychloride sprays to suppress bacterial activity on the leaf surface.',
        'Remove and properly dispose of infected leaves to reduce inoculum sources.',
        'Avoid causing wounds on leaves during handling, as these can be entry points for bacteria.',
      ],
    },
    'healthy': {
      'symptoms': [
        'Vibrant green leaves without spots or lesions',
        'Normal growth pattern',
        'No visible signs of disease or pest damage',
      ],
      'treatments': [
        'Regular monitoring for early detection of problems',
        'Maintain proper irrigation and fertilization',
        'Practice good orchard sanitation',
      ],
    },
    'tip_burn': {
      'symptoms': [
        'The tips and edges of leaves turn brown and dry, often due to non-pathogenic causes such as nutrient imbalance or salt injury (Gardening Know How, n.d.).',
      ],
      'treatments': [
        'Ensure consistent, deep watering to avoid drought stress that can worsen tip burn symptoms.',
        'Avoid excessive use of nitrogen-rich or saline fertilizers which may lead to root toxicity and leaf damage.',
        'Supplement calcium or potassium via foliar feeding if nutrient deficiency is suspected.',
        'Conduct regular soil testing to detect salinity or imbalance that might affect leaf health.',
      ],
    },
  };

  void _showDiseaseRecommendations(BuildContext context, String disease) {
    final label = disease.toLowerCase();
    final info = diseaseInfo[label];
    final isHealthy = label == 'healthy';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder:
                (context, scrollController) => SingleChildScrollView(
                  controller: scrollController,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isHealthy
                                  ? Icons.check_circle
                                  : Icons.medical_services_outlined,
                              color:
                                  isHealthy
                                      ? Colors.green
                                      : DetectionPainter
                                              .diseaseColors[disease] ??
                                          Colors.grey,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _formatLabel(disease),
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        if (info != null) ...[
                          const Text(
                            'Symptoms',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...info['symptoms'].map<Widget>(
                            (s) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                '• $s',
                                style: const TextStyle(fontSize: 15),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Treatment & Recommendations',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...info['treatments'].map<Widget>(
                            (t) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                '• $t',
                                style: const TextStyle(fontSize: 15),
                              ),
                            ),
                          ),
                        ] else ...[
                          const Text('No detailed information available.'),
                        ],
                      ],
                    ),
                  ),
                ),
          ),
    );
  }

  void _showHealthyStatus(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder:
                (context, scrollController) => SingleChildScrollView(
                  controller: scrollController,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Healthy Leaves',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Plant Health Status',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildStatusSection('Current Status', [
                          'Leaves show no signs of disease',
                          'Normal leaf color and texture',
                          'Proper leaf development',
                          'No visible damage or discoloration',
                        ]),
                        const SizedBox(height: 16),
                        _buildStatusSection('Maintenance Tips', [
                          'Continue regular watering schedule',
                          'Maintain proper fertilization',
                          'Monitor for any changes in leaf appearance',
                          'Keep up with regular pruning',
                          'Ensure adequate sunlight exposure',
                        ]),
                        const SizedBox(height: 16),
                        _buildStatusSection('Preventive Care', [
                          'Regular plant inspection',
                          'Maintain optimal growing conditions',
                          'Proper spacing between plants',
                          'Good air circulation',
                          'Regular soil testing',
                        ]),
                      ],
                    ),
                  ),
                ),
          ),
    );
  }

  Widget _buildStatusSection(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
        const SizedBox(height: 8),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  size: 20,
                  color: Colors.green,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(item, style: const TextStyle(fontSize: 14)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageGrid() {
    if (imageSizes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: widget.imagePaths.length,
      itemBuilder: (context, index) {
        final imagePath = widget.imagePaths[index];
        final results = widget.allResults[index] ?? [];
        final imageSize = imageSizes[imagePath] ?? const Size(1, 1);

        return GestureDetector(
          onTap: () {
            showDialog(
              context: context,
              barrierDismissible: true,
              builder:
                  (context) => Dialog(
                    insetPadding: EdgeInsets.zero,
                    backgroundColor: Colors.black,
                    child: Stack(
                      children: [
                        DetectionScreen(
                          imagePath: imagePath,
                          results: results,
                          imageSize: imageSize,
                          allImagePaths: widget.imagePaths,
                          currentIndex: index,
                          allResults: widget.allResults.values.toList(),
                          imageSizes:
                              widget.imagePaths
                                  .map(
                                    (path) =>
                                        imageSizes[path] ?? const Size(1, 1),
                                  )
                                  .toList(),
                          showAppBar: false,
                        ),
                        Positioned(
                          top: 24,
                          left: 16,
                          child: Material(
                            color: Colors.transparent,
                            child: Ink(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.arrow_back,
                                  color: Colors.white,
                                  size: 32,
                                ),
                                onPressed: () => Navigator.of(context).pop(),
                                tooltip: 'Back',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
            );
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              final widgetW = constraints.maxWidth;
              final widgetH = constraints.maxHeight;
              final imgW = imageSize.width;
              final imgH = imageSize.height;
              if (imgW == 0 || imgH == 0) {
                return const Center(child: CircularProgressIndicator());
              }
              // Calculate scale and offset for BoxFit.cover
              final widgetAspect = widgetW / widgetH;
              final imageAspect = imgW / imgH;
              double displayW, displayH, dx = 0, dy = 0;
              if (widgetAspect > imageAspect) {
                // Widget is wider than image
                displayW = widgetW;
                displayH = widgetW / imageAspect;
                dy = (widgetH - displayH) / 2;
              } else {
                // Widget is taller than image
                displayH = widgetH;
                displayW = widgetH * imageAspect;
                dx = (widgetW - displayW) / 2;
              }
              final displayedImageSize = Size(displayW, displayH);
              final displayedImageOffset = Offset(dx, dy);
              return Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(File(imagePath), fit: BoxFit.cover),
                  ),
                  if (showBoundingBoxes && results.isNotEmpty)
                    CustomPaint(
                      painter: DetectionPainter(
                        results: results,
                        originalImageSize: imageSize,
                        displayedImageSize: displayedImageSize,
                        displayedImageOffset: displayedImageOffset,
                      ),
                      size: Size(widgetW, widgetH),
                    ),
                  if (results.isNotEmpty)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${results.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final diseaseCounts = _getOverallDiseaseCount();
    final totalDetections = diseaseCounts.values.fold(0, (a, b) => a + b);

    // Sort diseases by percentage in descending order
    final sortedDiseases =
        diseaseCounts.entries.toList()..sort((a, b) {
          final percentageA = _getDiseasePercentage(a.key, diseaseCounts);
          final percentageB = _getDiseasePercentage(b.key, diseaseCounts);
          return percentageB.compareTo(percentageA);
        });

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Analysis Summary'),
        centerTitle: true,
        backgroundColor: Colors.green,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Ink(
              decoration: BoxDecoration(
                color: showBoundingBoxes ? Colors.green[700] : Colors.grey[300],
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: () {
                  setState(() {
                    showBoundingBoxes = !showBoundingBoxes;
                  });
                },
                icon: Icon(Icons.visibility, color: Colors.white),
                tooltip:
                    showBoundingBoxes
                        ? 'Hide Bounding Boxes'
                        : 'Show Bounding Boxes',
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.white,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Total Images',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${widget.imagePaths.length}',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 40,
                              color: Colors.grey[300],
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Total Leaves',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$totalDetections',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Analyzed Images',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildImageGrid(),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Disease Summary',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.white,
                    child: Column(
                      children: [
                        ...sortedDiseases.map((entry) {
                          return _buildDiseaseSummaryCard(
                            entry.key,
                            entry.value,
                            diseaseCounts,
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar:
          !_isSubmitting
              ? Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _sendForExternalReview,
                    icon: const Icon(Icons.send),
                    label: const Text('Send for Review'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              )
              : null,
    );
  }
}
