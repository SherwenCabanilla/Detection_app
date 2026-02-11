import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'tflite_detector.dart';
import 'detection_painter.dart';
import 'disease_details_page.dart';
import 'disease_treatments_i18n.dart';

class UserRequestDetail extends StatefulWidget {
  final Map<String, dynamic> request;
  const UserRequestDetail({Key? key, required this.request}) : super(key: key);

  @override
  _UserRequestDetailState createState() => _UserRequestDetailState();
}

class _UserRequestDetailState extends State<UserRequestDetail> {
  bool _showBoundingBoxes = true;

  String _translatePreventiveMeasure(String english) {
    // Map known expert defaults to localization keys
    final Map<String, String> map = {
      'Regular pruning': 'pm_regular_pruning',
      'Proper spacing between plants': 'pm_proper_spacing',
      'Adequate ventilation': 'pm_adequate_ventilation',
      'Regular watering': 'pm_regular_watering',
      'Proper fertilization': 'pm_proper_fertilization',
      'Pest monitoring': 'pm_pest_monitoring',
      'Soil testing': 'pm_soil_testing',
      'Crop rotation': 'pm_crop_rotation',
      'Remove infected leaves': 'pm_remove_infected_leaves',
      'Improve air circulation': 'pm_improve_air_circulation',
    };

    final key = map[english];
    if (key != null) {
      return tr(key);
    }
    // Fallback: return original text if we don't recognize it
    return english;
  }

  // Check if treatment plan has any content
  bool _hasTreatmentContent(Map<String, dynamic>? treatmentPlan) {
    if (treatmentPlan == null) return false;

    final recommendations = treatmentPlan['recommendations'] as List?;
    if (recommendations == null || recommendations.isEmpty) return false;

    // Check if any recommendation has actual content
    for (var rec in recommendations) {
      if (rec == null) continue;
      final treatment = rec['treatment']?.toString().trim() ?? '';
      final dosage = rec['dosage']?.toString().trim() ?? '';
      final frequency = rec['frequency']?.toString().trim() ?? '';
      final precautions = rec['precautions']?.toString().trim() ?? '';

      if (treatment.isNotEmpty ||
          dosage.isNotEmpty ||
          frequency.isNotEmpty ||
          precautions.isNotEmpty) {
        return true;
      }
    }

    return false;
  }

  // Check if preventive measures has any content
  bool _hasPreventiveMeasures(Map<String, dynamic>? treatmentPlan) {
    if (treatmentPlan == null) return false;

    final measures = treatmentPlan['preventiveMeasures'] as List?;
    if (measures == null || measures.isEmpty) return false;

    // Check if any measure has actual content
    for (var measure in measures) {
      if (measure?.toString().trim().isNotEmpty ?? false) {
        return true;
      }
    }

    return false;
  }

  @override
  void initState() {
    super.initState();
    _loadBoundingBoxPreference();
  }

  void _openImageViewer(int initialIndex) {
    final images = (widget.request['images'] as List?) ?? [];
    if (images.isEmpty) return;
    int currentIndex = initialIndex;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final img = images[currentIndex] as Map<String, dynamic>;
            final imageUrl = (img['imageUrl'] ?? '').toString();
            final imagePath =
                (img['path'] ?? img['imagePath'] ?? '').toString();
            final displayPath = imageUrl.isNotEmpty ? imageUrl : imagePath;

            return Dialog(
              backgroundColor: Colors.black,
              insetPadding: const EdgeInsets.all(12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final detections =
                      (img['results'] as List?)
                          ?.where(
                            (d) =>
                                d is Map &&
                                d['disease'] != null &&
                                d['confidence'] != null &&
                                d['boundingBox'] != null,
                          )
                          .cast<Map>()
                          .toList() ??
                      [];

                  final widgetW = constraints.maxWidth;
                  final widgetH = constraints.maxHeight;

                  return Stack(
                    children: [
                      Positioned.fill(
                        child: InteractiveViewer(
                          key: ValueKey(currentIndex),
                          minScale: 0.5,
                          maxScale: 5.0,
                          panEnabled: true,
                          scaleEnabled: true,
                          boundaryMargin: const EdgeInsets.all(double.infinity),
                          child: Center(
                            child: _buildImageWidget(
                              displayPath,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                      // Bounding boxes overlay (ignore pointer so zoom still works)
                      if (_showBoundingBoxes && detections.isNotEmpty)
                        IgnorePointer(
                          child: Builder(
                            builder: (context) {
                              final storedImageWidth =
                                  img['imageWidth'] as num?;
                              final storedImageHeight =
                                  img['imageHeight'] as num?;

                              Future<Size> _sizeFuture() async {
                                if (storedImageWidth != null &&
                                    storedImageHeight != null) {
                                  return Size(
                                    storedImageWidth.toDouble(),
                                    storedImageHeight.toDouble(),
                                  );
                                }
                                return await _getImageSize(
                                  displayPath.startsWith('http') &&
                                          displayPath.isNotEmpty
                                      ? NetworkImage(displayPath)
                                      : FileImage(File(displayPath)),
                                );
                              }

                              return FutureBuilder<Size>(
                                future: _sizeFuture(),
                                builder: (context, snapshot) {
                                  if (!snapshot.hasData) {
                                    return const SizedBox.shrink();
                                  }
                                  final originalSize = snapshot.data!;
                                  // BoxFit.contain math (no crop; natural look)
                                  final scaleX = widgetW / originalSize.width;
                                  final scaleY = widgetH / originalSize.height;
                                  final scale =
                                      scaleX < scaleY ? scaleX : scaleY;
                                  final scaledW = originalSize.width * scale;
                                  final scaledH = originalSize.height * scale;
                                  final dx = (widgetW - scaledW) / 2;
                                  final dy = (widgetH - scaledH) / 2;

                                  return CustomPaint(
                                    painter: DetectionPainter(
                                      results:
                                          detections.map((d) {
                                            final bb = d['boundingBox'] as Map;
                                            return DetectionResult(
                                              label: d['disease'],
                                              confidence: d['confidence'],
                                              boundingBox: Rect.fromLTRB(
                                                (bb['left'] as num).toDouble(),
                                                (bb['top'] as num).toDouble(),
                                                (bb['right'] as num).toDouble(),
                                                (bb['bottom'] as num)
                                                    .toDouble(),
                                              ),
                                            );
                                          }).toList(),
                                      originalImageSize: originalSize,
                                      displayedImageSize: Size(
                                        scaledW,
                                        scaledH,
                                      ),
                                      displayedImageOffset: Offset(dx, dy),
                                      debugMode: false,
                                    ),
                                    size: Size(widgetW, widgetH),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      if (images.length > 1)
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          width: 60,
                          child: Center(
                            child: IconButton(
                              iconSize: 36,
                              color: Colors.white,
                              icon: const Icon(Icons.chevron_left),
                              onPressed:
                                  currentIndex > 0
                                      ? () {
                                        setStateDialog(() {
                                          currentIndex -= 1;
                                        });
                                      }
                                      : null,
                            ),
                          ),
                        ),
                      if (images.length > 1)
                        Positioned(
                          right: 0,
                          top: 0,
                          bottom: 0,
                          width: 60,
                          child: Center(
                            child: IconButton(
                              iconSize: 36,
                              color: Colors.white,
                              icon: const Icon(Icons.chevron_right),
                              onPressed:
                                  currentIndex < images.length - 1
                                      ? () {
                                        setStateDialog(() {
                                          currentIndex += 1;
                                        });
                                      }
                                      : null,
                            ),
                          ),
                        ),
                      Positioned(
                        bottom: 8,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${currentIndex + 1} / ${images.length}',
                              style: const TextStyle(color: Colors.white),
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
      },
    );
  }

  Future<void> _loadBoundingBoxPreference() async {
    final box = await Hive.openBox('userBox');
    final savedPreference = box.get('showBoundingBoxes');
    if (savedPreference != null) {
      setState(() {
        _showBoundingBoxes = savedPreference as bool;
      });
    }
  }

  Future<void> _saveBoundingBoxPreference(bool value) async {
    final box = await Hive.openBox('userBox');
    await box.put('showBoundingBoxes', value);
  }

  Widget build(BuildContext context) {
    final diseaseSummary = (widget.request['diseaseSummary'] as List?) ?? [];
    // Removed unused mainDisease variable
    final status = widget.request['status'] ?? '';
    final submittedAt = widget.request['submittedAt'] ?? '';
    // Format date
    final formattedDate =
        submittedAt.isNotEmpty && DateTime.tryParse(submittedAt) != null
            ? DateFormat(
              'MMM d, yyyy – h:mma',
            ).format(DateTime.parse(submittedAt))
            : submittedAt;
    final reviewedAt = widget.request['reviewedAt'] ?? '';
    // Format reviewed date
    final formattedReviewedDate =
        reviewedAt.isNotEmpty && DateTime.tryParse(reviewedAt) != null
            ? DateFormat(
              'MMM d, yyyy – h:mma',
            ).format(DateTime.parse(reviewedAt))
            : reviewedAt;
    final expertReview = widget.request['expertReview'];
    final expertName = widget.request['expertName'] ?? '';
    final isCompleted = status == 'completed';
    final images = (widget.request['images'] as List?) ?? [];

    // Debug: Print the entire request structure
    print('🔍 Request Debug:');
    print('🔍 Status: $status');
    print('🔍 Images count: ${images.length}');
    for (var i = 0; i < images.length; i++) {
      final img = images[i];
      print('🔍 Image $i:');
      print('🔍   - imageUrl: ${img['imageUrl']}');
      print('🔍   - imagePath: ${img['imagePath']}');
      print('🔍   - path: ${img['path']}');
      print('🔍   - imageWidth: ${img['imageWidth']}');
      print('🔍   - imageHeight: ${img['imageHeight']}');
      print('🔍   - results: ${img['results']}');
      if (img['results'] != null) {
        final results = img['results'] as List;
        print('🔍   - results count: ${results.length}');
        for (var j = 0; j < results.length; j++) {
          final result = results[j];
          print(
            '🔍   - Result $j: ${result['disease']} (${result['confidence']})',
          );
          print('🔍   - Bounding box: ${result['boundingBox']}');
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: Text(
          tr('request_details'),
          style: const TextStyle(color: Colors.white),
        ),
        elevation: 0,
        actions: [],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Consolidated Request Card
            Padding(
              padding: const EdgeInsets.all(16),
              child: Builder(
                builder: (context) {
                  final mergedSummary = _mergeDiseaseSummary(diseaseSummary);
                  final hasHealthy = mergedSummary.any((d) {
                    final diseaseName =
                        (d['disease'] ?? d['name'] ?? '')
                            .toString()
                            .toLowerCase();
                    return diseaseName == 'healthy';
                  });

                  // Filter diseases
                  final filteredSummary =
                      mergedSummary.where((d) {
                        final rawDiseaseName =
                            (d['disease'] ?? d['name'] ?? '').toString();
                        final normalizedName =
                            rawDiseaseName
                                .toLowerCase()
                                .replaceAll('_', ' ')
                                .trim();
                        const validDiseases = {
                          'anthracnose',
                          'bacterial blackspot',
                          'bacterial_blackspot',
                          'backterial_blackspot',
                          'powdery mildew',
                          'powdery_mildew',
                          'dieback',
                        };
                        final isValidDisease =
                            validDiseases.contains(normalizedName) ||
                            validDiseases.contains(
                              rawDiseaseName.toLowerCase(),
                            );
                        final isNonMangoLeaf =
                            normalizedName == 'banana' ||
                            normalizedName == 'eggplant' ||
                            normalizedName == 'moringa';
                        final isTipBurn =
                            normalizedName == 'tip burn' ||
                            normalizedName == 'tip_burn';
                        final isUnknown = normalizedName == 'unknown';
                        final isHealthy = normalizedName == 'healthy';
                        return isValidDisease &&
                            !isNonMangoLeaf &&
                            !isTipBurn &&
                            !isUnknown &&
                            !isHealthy;
                      }).toList();

                  final sortedSummary = [...filteredSummary]..sort((a, b) {
                    final countA = a['count'] as int? ?? 0;
                    final countB = b['count'] as int? ?? 0;
                    return countB.compareTo(countA);
                  });

                  return Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Your Request Section
                          Row(
                            children: [
                              Icon(Icons.person, color: Colors.green, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Your Request',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Submission date and status badge
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 18,
                                color: Colors.grey[700],
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  formattedDate,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      isCompleted
                                          ? Colors.green.withOpacity(0.1)
                                          : Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  isCompleted
                                      ? tr('completed')
                                      : (status == 'tracking'
                                          ? tr('tracking')
                                          : (status == 'pending_review'
                                              ? tr('pending_review')
                                              : tr('pending'))),
                                  style: TextStyle(
                                    color:
                                        isCompleted
                                            ? Colors.green
                                            : Colors.orange,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (isCompleted && reviewedAt.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  size: 18,
                                  color: Colors.green,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Reviewed: $formattedReviewedDate',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (isCompleted) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.verified,
                                  size: 16,
                                  color: Colors.green[700],
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    tr(
                                      'confirmed_by',
                                      namedArgs: {
                                        'office': tr('office_of_carmen'),
                                      },
                                    ),
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[700],
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          // Divider
                          if (hasHealthy ||
                              sortedSummary.isNotEmpty ||
                              (isCompleted &&
                                  expertReview != null &&
                                  (expertReview['healthStatus'] != null ||
                                      (expertReview['comment'] != null &&
                                          expertReview['comment']
                                              .toString()
                                              .trim()
                                              .isNotEmpty))))
                            const Divider(height: 24),
                          // Healthy (if any)
                          if (hasHealthy) ...[
                            Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: (DetectionPainter
                                                .diseaseColors['healthy'] ??
                                            Colors.blue)
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.check_circle_outline,
                                    color:
                                        DetectionPainter
                                            .diseaseColors['healthy'] ??
                                        Colors.blue,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    tr('healthy'),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF1A1A1A),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (sortedSummary.isNotEmpty)
                              const Divider(height: 16),
                          ],
                          // Diseases
                          ...sortedSummary.asMap().entries.map((entry) {
                            final index = entry.key;
                            final disease = entry.value;
                            final rawDiseaseName =
                                (disease['disease'] ??
                                        disease['name'] ??
                                        'Unknown')
                                    .toString();
                            final color = _getExpertDiseaseColor(
                              rawDiseaseName,
                            );
                            final isLast = index == sortedSummary.length - 1;

                            return Column(
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: color.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        Icons.warning_rounded,
                                        color: color,
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Text(
                                        _formatExpertLabel(rawDiseaseName),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF1A1A1A),
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        _showDiseaseDetails(
                                          _formatExpertLabel(rawDiseaseName),
                                          _getDiseaseImagePath(rawDiseaseName),
                                          rawDiseaseName,
                                        );
                                      },
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.green,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 4,
                                        ),
                                      ),
                                      child: const Text(
                                        'Recommendation',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (!isLast) const Divider(height: 16),
                              ],
                            );
                          }).toList(),
                          // Divider before reviewer info
                          if (isCompleted &&
                              expertReview != null &&
                              (expertReview['healthStatus'] != null ||
                                  (expertReview['comment'] != null &&
                                      expertReview['comment']
                                          .toString()
                                          .trim()
                                          .isNotEmpty)))
                            const Divider(height: 24),
                          // Reviewed by and Health Status
                          if (isCompleted &&
                              expertReview != null &&
                              expertName.isNotEmpty) ...[
                            Row(
                              children: [
                                Icon(
                                  Icons.person,
                                  size: 18,
                                  color: Colors.green,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    tr(
                                      'reviewed_by',
                                      namedArgs: {
                                        'name':
                                            expertName.isNotEmpty
                                                ? expertName
                                                : 'Expert',
                                      },
                                    ),
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.green,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (isCompleted &&
                              expertReview != null &&
                              expertReview['healthStatus'] != null) ...[
                            if (isCompleted &&
                                expertReview != null &&
                                expertName.isNotEmpty)
                              const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  expertReview['healthStatus'] == 'healthy'
                                      ? Icons.check_circle
                                      : Icons.warning,
                                  size: 18,
                                  color:
                                      expertReview['healthStatus'] == 'healthy'
                                          ? Colors.green
                                          : Colors.orange,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${tr('health_status')}: ${expertReview['healthStatus'] == 'healthy' ? tr('healthy') : tr('not_healthy')}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color:
                                          expertReview['healthStatus'] ==
                                                  'healthy'
                                              ? Colors.green
                                              : Colors.orange,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            // Additional Treatment Plan (if completed and has comment)
            if (isCompleted &&
                expertReview != null &&
                expertReview['comment'] != null &&
                expertReview['comment'].toString().trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Additional Treatment Plan',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF424242),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          expertReview['comment'],
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.black87,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else if (!isCompleted)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  color: Colors.orange[50],
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          color: Colors.orange[700],
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            tr('awaiting_expert_review'),
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.orange[800],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            // Images Grid
            if (images.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('submitted_images'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tr('confidence_note'),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Toggle button for bounding boxes
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(tr('show_bounding_boxes')),
                        Switch(
                          value: _showBoundingBoxes,
                          onChanged: (value) async {
                            setState(() {
                              _showBoundingBoxes = value;
                            });
                            await _saveBoundingBoxPreference(value);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                      itemCount: images.length,
                      itemBuilder: (context, idx) {
                        final img = images[idx];
                        final imageUrl = img['imageUrl'] ?? '';
                        final detections = (img['results'] as List?) ?? [];
                        final int detectionCount =
                            detections
                                .where(
                                  (d) => d is Map && d['boundingBox'] != null,
                                )
                                .length;

                        // Debug: Print image path information
                        print('🖼️ Image $idx debug:');
                        print('🖼️   - imageUrl: $imageUrl');
                        print('🖼️   - detections count: ${detections.length}');

                        return GestureDetector(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder:
                                  (context) => Dialog(
                                    backgroundColor: Colors.transparent,
                                    insetPadding: const EdgeInsets.all(16),
                                    child: LayoutBuilder(
                                      builder: (context, constraints) {
                                        final imageWidth = constraints.maxWidth;
                                        final imageHeight =
                                            constraints.maxHeight;
                                        return Stack(
                                          children: [
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              child: _buildImageWidget(
                                                imageUrl,
                                                width: imageWidth,
                                                height: imageHeight,
                                                fit: BoxFit.contain,
                                              ),
                                            ),
                                            if (_showBoundingBoxes &&
                                                detections.isNotEmpty)
                                              Builder(
                                                builder: (context) {
                                                  // Try to get stored image dimensions for fast loading
                                                  final storedImageWidth =
                                                      img['imageWidth'] as num?;
                                                  final storedImageHeight =
                                                      img['imageHeight']
                                                          as num?;

                                                  if (storedImageWidth !=
                                                          null &&
                                                      storedImageHeight !=
                                                          null) {
                                                    // Use stored dimensions for instant loading
                                                    final imageSize = Size(
                                                      storedImageWidth
                                                          .toDouble(),
                                                      storedImageHeight
                                                          .toDouble(),
                                                    );
                                                    print(
                                                      '🔍 Dialog Fast mode: Using stored dimensions ${imageSize.width}x${imageSize.height}',
                                                    );

                                                    return LayoutBuilder(
                                                      builder: (
                                                        context,
                                                        constraints,
                                                      ) {
                                                        // Calculate the actual displayed image size for BoxFit.contain
                                                        final imgW =
                                                            imageSize.width;
                                                        final imgH =
                                                            imageSize.height;
                                                        final widgetW =
                                                            constraints
                                                                .maxWidth;
                                                        final widgetH =
                                                            constraints
                                                                .maxHeight;

                                                        // Calculate scale and offset for BoxFit.contain (not cover)
                                                        final widgetAspect =
                                                            widgetW / widgetH;
                                                        final imageAspect =
                                                            imgW / imgH;
                                                        double displayW,
                                                            displayH,
                                                            dx = 0,
                                                            dy = 0;

                                                        if (widgetAspect >
                                                            imageAspect) {
                                                          // Widget is wider than image - height constrained
                                                          displayH = widgetH;
                                                          displayW =
                                                              widgetH *
                                                              imageAspect;
                                                          dx =
                                                              (widgetW -
                                                                  displayW) /
                                                              2;
                                                        } else {
                                                          // Widget is taller than image - width constrained
                                                          displayW = widgetW;
                                                          displayH =
                                                              widgetW /
                                                              imageAspect;
                                                          dy =
                                                              (widgetH -
                                                                  displayH) /
                                                              2;
                                                        }

                                                        print(
                                                          '🔍 Dialog: Widget dimensions: ${widgetW}x${widgetH}',
                                                        );
                                                        print(
                                                          '🔍 Dialog: Image dimensions: ${imgW}x${imgH}',
                                                        );
                                                        print(
                                                          '🔍 Dialog: Displayed dimensions: ${displayW}x${displayH}',
                                                        );
                                                        print(
                                                          '🔍 Dialog: Offset: ($dx, $dy)',
                                                        );

                                                        return CustomPaint(
                                                          painter: DetectionPainter(
                                                            results:
                                                                detections
                                                                    .where(
                                                                      (d) =>
                                                                          d['boundingBox'] !=
                                                                          null,
                                                                    )
                                                                    .map((d) {
                                                                      final left =
                                                                          (d['boundingBox']['left']
                                                                                  as num)
                                                                              .toDouble();
                                                                      final top =
                                                                          (d['boundingBox']['top']
                                                                                  as num)
                                                                              .toDouble();
                                                                      final right =
                                                                          (d['boundingBox']['right']
                                                                                  as num)
                                                                              .toDouble();
                                                                      final bottom =
                                                                          (d['boundingBox']['bottom']
                                                                                  as num)
                                                                              .toDouble();

                                                                      return DetectionResult(
                                                                        label:
                                                                            d['disease'],
                                                                        confidence:
                                                                            d['confidence'],
                                                                        boundingBox: Rect.fromLTRB(
                                                                          left,
                                                                          top,
                                                                          right,
                                                                          bottom,
                                                                        ),
                                                                      );
                                                                    })
                                                                    .toList(),
                                                            originalImageSize:
                                                                imageSize,
                                                            displayedImageSize:
                                                                Size(
                                                                  displayW,
                                                                  displayH,
                                                                ),
                                                            displayedImageOffset:
                                                                Offset(dx, dy),
                                                          ),
                                                          size: Size(
                                                            widgetW,
                                                            widgetH,
                                                          ),
                                                        );
                                                      },
                                                    );
                                                  } else {
                                                    // Fallback to slow method for old data
                                                    return FutureBuilder<Size>(
                                                      future: _getImageSize(
                                                        imageUrl.isNotEmpty
                                                            ? NetworkImage(
                                                              imageUrl,
                                                            )
                                                            : FileImage(
                                                              File(imageUrl),
                                                            ),
                                                      ),
                                                      builder: (
                                                        context,
                                                        snapshot,
                                                      ) {
                                                        // Only show bounding boxes if we have image size data (online mode)
                                                        if (!snapshot.hasData) {
                                                          print(
                                                            '🔍 Dialog: Offline mode - No image size data, hiding bounding boxes',
                                                          );
                                                          return const SizedBox.shrink();
                                                        }

                                                        final imageSize =
                                                            snapshot.data!;
                                                        print(
                                                          '🔍 Dialog Slow mode: Image size loaded from network ${imageSize.width}x${imageSize.height}',
                                                        );

                                                        return LayoutBuilder(
                                                          builder: (
                                                            context,
                                                            constraints,
                                                          ) {
                                                            // Calculate the actual displayed image size for BoxFit.contain
                                                            final imgW =
                                                                imageSize.width;
                                                            final imgH =
                                                                imageSize
                                                                    .height;
                                                            final widgetW =
                                                                constraints
                                                                    .maxWidth;
                                                            final widgetH =
                                                                constraints
                                                                    .maxHeight;

                                                            // Calculate scale and offset for BoxFit.contain (not cover)
                                                            final widgetAspect =
                                                                widgetW /
                                                                widgetH;
                                                            final imageAspect =
                                                                imgW / imgH;
                                                            double displayW,
                                                                displayH,
                                                                dx = 0,
                                                                dy = 0;

                                                            if (widgetAspect >
                                                                imageAspect) {
                                                              // Widget is wider than image - height constrained
                                                              displayH =
                                                                  widgetH;
                                                              displayW =
                                                                  widgetH *
                                                                  imageAspect;
                                                              dx =
                                                                  (widgetW -
                                                                      displayW) /
                                                                  2;
                                                            } else {
                                                              // Widget is taller than image - width constrained
                                                              displayW =
                                                                  widgetW;
                                                              displayH =
                                                                  widgetW /
                                                                  imageAspect;
                                                              dy =
                                                                  (widgetH -
                                                                      displayH) /
                                                                  2;
                                                            }

                                                            print(
                                                              '🔍 Dialog: Widget dimensions: ${widgetW}x${widgetH}',
                                                            );
                                                            print(
                                                              '🔍 Dialog: Image dimensions: ${imgW}x${imgH}',
                                                            );
                                                            print(
                                                              '🔍 Dialog: Displayed dimensions: ${displayW}x${displayH}',
                                                            );
                                                            print(
                                                              '🔍 Dialog: Offset: ($dx, $dy)',
                                                            );

                                                            return CustomPaint(
                                                              painter: DetectionPainter(
                                                                results:
                                                                    detections
                                                                        .where(
                                                                          (d) =>
                                                                              d['boundingBox'] !=
                                                                              null,
                                                                        )
                                                                        .map((
                                                                          d,
                                                                        ) {
                                                                          final left =
                                                                              (d['boundingBox']['left']
                                                                                      as num)
                                                                                  .toDouble();
                                                                          final top =
                                                                              (d['boundingBox']['top']
                                                                                      as num)
                                                                                  .toDouble();
                                                                          final right =
                                                                              (d['boundingBox']['right']
                                                                                      as num)
                                                                                  .toDouble();
                                                                          final bottom =
                                                                              (d['boundingBox']['bottom']
                                                                                      as num)
                                                                                  .toDouble();

                                                                          return DetectionResult(
                                                                            label:
                                                                                d['disease'],
                                                                            confidence:
                                                                                d['confidence'],
                                                                            boundingBox: Rect.fromLTRB(
                                                                              left,
                                                                              top,
                                                                              right,
                                                                              bottom,
                                                                            ),
                                                                          );
                                                                        })
                                                                        .toList(),
                                                                originalImageSize:
                                                                    imageSize,
                                                                displayedImageSize:
                                                                    Size(
                                                                      displayW,
                                                                      displayH,
                                                                    ),
                                                                displayedImageOffset:
                                                                    Offset(
                                                                      dx,
                                                                      dy,
                                                                    ),
                                                              ),
                                                              size: Size(
                                                                widgetW,
                                                                widgetH,
                                                              ),
                                                            );
                                                          },
                                                        );
                                                      },
                                                    );
                                                  }
                                                },
                                              ),
                                            Positioned(
                                              top: 8,
                                              right: 8,
                                              child: IconButton(
                                                icon: const Icon(
                                                  Icons.close,
                                                  color: Colors.white,
                                                ),
                                                onPressed:
                                                    () =>
                                                        Navigator.pop(context),
                                              ),
                                            ),
                                            // Navigation: Previous
                                            Positioned(
                                              left: 0,
                                              top: 0,
                                              bottom: 0,
                                              child: Center(
                                                child: IconButton(
                                                  iconSize: 36,
                                                  color: Colors.white,
                                                  icon: const Icon(
                                                    Icons.chevron_left,
                                                  ),
                                                  onPressed:
                                                      idx > 0
                                                          ? () {
                                                            Navigator.pop(
                                                              context,
                                                            );
                                                            Future.microtask(
                                                              () =>
                                                                  _openImageViewer(
                                                                    idx - 1,
                                                                  ),
                                                            );
                                                          }
                                                          : null,
                                                ),
                                              ),
                                            ),
                                            // Navigation: Next
                                            Positioned(
                                              right: 0,
                                              top: 0,
                                              bottom: 0,
                                              child: Center(
                                                child: IconButton(
                                                  iconSize: 36,
                                                  color: Colors.white,
                                                  icon: const Icon(
                                                    Icons.chevron_right,
                                                  ),
                                                  onPressed:
                                                      idx < images.length - 1
                                                          ? () {
                                                            Navigator.pop(
                                                              context,
                                                            );
                                                            Future.microtask(
                                                              () =>
                                                                  _openImageViewer(
                                                                    idx + 1,
                                                                  ),
                                                            );
                                                          }
                                                          : null,
                                                ),
                                              ),
                                            ),
                                            // Index indicator
                                            Positioned(
                                              bottom: 8,
                                              left: 0,
                                              right: 0,
                                              child: Center(
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 6,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black
                                                        .withOpacity(0.6),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    '${idx + 1} / ${images.length}',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                            );
                          },
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: _buildImageWidget(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              if (_showBoundingBoxes && detections.isNotEmpty)
                                Builder(
                                  builder: (context) {
                                    // Try to get stored image dimensions for fast loading
                                    final storedImageWidth =
                                        img['imageWidth'] as num?;
                                    final storedImageHeight =
                                        img['imageHeight'] as num?;

                                    if (storedImageWidth != null &&
                                        storedImageHeight != null) {
                                      // Use stored dimensions for instant loading
                                      final imageSize = Size(
                                        storedImageWidth.toDouble(),
                                        storedImageHeight.toDouble(),
                                      );
                                      print(
                                        '🔍 Fast mode: Using stored dimensions ${imageSize.width}x${imageSize.height}',
                                      );

                                      return LayoutBuilder(
                                        builder: (context, constraints) {
                                          // Calculate the actual displayed image size
                                          final imgW = imageSize.width;
                                          final imgH = imageSize.height;
                                          final widgetW = constraints.maxWidth;
                                          final widgetH = constraints.maxHeight;

                                          // Calculate scale and offset for BoxFit.cover
                                          final scale =
                                              imgW / imgH > widgetW / widgetH
                                                  ? widgetH /
                                                      imgH // Height constrained
                                                  : widgetW /
                                                      imgW; // Width constrained

                                          final scaledW = imgW * scale;
                                          final scaledH = imgH * scale;
                                          final dx = (widgetW - scaledW) / 2;
                                          final dy = (widgetH - scaledH) / 2;

                                          return CustomPaint(
                                            painter: DetectionPainter(
                                              results:
                                                  detections
                                                      .map((d) {
                                                        if (d == null ||
                                                            d['disease'] ==
                                                                null ||
                                                            d['confidence'] ==
                                                                null ||
                                                            d['boundingBox'] ==
                                                                null ||
                                                            d['boundingBox']['left'] ==
                                                                null ||
                                                            d['boundingBox']['top'] ==
                                                                null ||
                                                            d['boundingBox']['right'] ==
                                                                null ||
                                                            d['boundingBox']['bottom'] ==
                                                                null) {
                                                          print(
                                                            '❌ Invalid detection data: $d',
                                                          );
                                                          return null;
                                                        }

                                                        final left =
                                                            (d['boundingBox']['left']
                                                                    as num)
                                                                .toDouble();
                                                        final top =
                                                            (d['boundingBox']['top']
                                                                    as num)
                                                                .toDouble();
                                                        final right =
                                                            (d['boundingBox']['right']
                                                                    as num)
                                                                .toDouble();
                                                        final bottom =
                                                            (d['boundingBox']['bottom']
                                                                    as num)
                                                                .toDouble();

                                                        return DetectionResult(
                                                          label:
                                                              d['disease']
                                                                  .toString(),
                                                          confidence:
                                                              (d['confidence']
                                                                      as num)
                                                                  .toDouble(),
                                                          boundingBox:
                                                              Rect.fromLTRB(
                                                                left,
                                                                top,
                                                                right,
                                                                bottom,
                                                              ),
                                                        );
                                                      })
                                                      .whereType<
                                                        DetectionResult
                                                      >()
                                                      .toList(),
                                              originalImageSize: imageSize,
                                              displayedImageSize: Size(
                                                scaledW,
                                                scaledH,
                                              ),
                                              displayedImageOffset: Offset(
                                                dx,
                                                dy,
                                              ),
                                            ),
                                            size: Size(widgetW, widgetH),
                                          );
                                        },
                                      );
                                    } else {
                                      // Fallback to slow method for old data
                                      return FutureBuilder<Size>(
                                        future: _getImageSize(
                                          imageUrl.isNotEmpty
                                              ? NetworkImage(imageUrl)
                                              : FileImage(File(imageUrl)),
                                        ),
                                        builder: (context, snapshot) {
                                          if (!snapshot.hasData) {
                                            print(
                                              '🔍 Offline mode: No image size data, hiding bounding boxes',
                                            );
                                            return const SizedBox.shrink();
                                          }

                                          final imageSize = snapshot.data!;
                                          print(
                                            '🔍 Slow mode: Image size loaded from network ${imageSize.width}x${imageSize.height}',
                                          );

                                          return LayoutBuilder(
                                            builder: (context, constraints) {
                                              // Calculate the actual displayed image size
                                              final imgW = imageSize.width;
                                              final imgH = imageSize.height;
                                              final widgetW =
                                                  constraints.maxWidth;
                                              final widgetH =
                                                  constraints.maxHeight;

                                              // Calculate scale and offset for BoxFit.cover
                                              final scale =
                                                  imgW / imgH >
                                                          widgetW / widgetH
                                                      ? widgetH /
                                                          imgH // Height constrained
                                                      : widgetW /
                                                          imgW; // Width constrained

                                              final scaledW = imgW * scale;
                                              final scaledH = imgH * scale;
                                              final dx =
                                                  (widgetW - scaledW) / 2;
                                              final dy =
                                                  (widgetH - scaledH) / 2;

                                              return CustomPaint(
                                                painter: DetectionPainter(
                                                  results:
                                                      detections
                                                          .map((d) {
                                                            if (d == null ||
                                                                d['disease'] ==
                                                                    null ||
                                                                d['confidence'] ==
                                                                    null ||
                                                                d['boundingBox'] ==
                                                                    null ||
                                                                d['boundingBox']['left'] ==
                                                                    null ||
                                                                d['boundingBox']['top'] ==
                                                                    null ||
                                                                d['boundingBox']['right'] ==
                                                                    null ||
                                                                d['boundingBox']['bottom'] ==
                                                                    null) {
                                                              print(
                                                                '❌ Invalid detection data: $d',
                                                              );
                                                              return null;
                                                            }

                                                            final left =
                                                                (d['boundingBox']['left']
                                                                        as num)
                                                                    .toDouble();
                                                            final top =
                                                                (d['boundingBox']['top']
                                                                        as num)
                                                                    .toDouble();
                                                            final right =
                                                                (d['boundingBox']['right']
                                                                        as num)
                                                                    .toDouble();
                                                            final bottom =
                                                                (d['boundingBox']['bottom']
                                                                        as num)
                                                                    .toDouble();

                                                            return DetectionResult(
                                                              label:
                                                                  d['disease']
                                                                      .toString(),
                                                              confidence:
                                                                  (d['confidence']
                                                                          as num)
                                                                      .toDouble(),
                                                              boundingBox:
                                                                  Rect.fromLTRB(
                                                                    left,
                                                                    top,
                                                                    right,
                                                                    bottom,
                                                                  ),
                                                            );
                                                          })
                                                          .whereType<
                                                            DetectionResult
                                                          >()
                                                          .toList(),
                                                  originalImageSize: imageSize,
                                                  displayedImageSize: Size(
                                                    scaledW,
                                                    scaledH,
                                                  ),
                                                  displayedImageOffset: Offset(
                                                    dx,
                                                    dy,
                                                  ),
                                                ),
                                                size: Size(widgetW, widgetH),
                                              );
                                            },
                                          );
                                        },
                                      );
                                    }
                                  },
                                ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.7),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    detectionCount > 0
                                        ? (detectionCount == 1
                                            ? tr(
                                              'detections_one',
                                              namedArgs: {'count': '1'},
                                            )
                                            : tr(
                                              'detections_other',
                                              namedArgs: {
                                                'count': '$detectionCount',
                                              },
                                            ))
                                        : tr('no_detections'),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _formatSeverityLevel(String severity) {
    switch (severity.toLowerCase()) {
      case 'high':
        return tr('severity_high');
      case 'medium':
        return tr('severity_medium');
      case 'low':
        return tr('severity_low');
      default:
        return severity.toUpperCase();
    }
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, {
    Color? color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color ?? Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value.isEmpty ? label : '$label $value',
            style: TextStyle(
              fontSize: 14,
              color: color ?? Colors.grey[800],
              fontWeight: value.isEmpty ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }

  Color _getExpertDiseaseColor(String diseaseName) {
    switch (diseaseName.toLowerCase()) {
      case 'anthracnose':
        return Colors.orange;
      case 'backterial_blackspot':
      case 'bacterial blackspot':
      case 'bacterial black spot':
        return Colors.purple;
      case 'dieback':
        return Colors.red;
      case 'healthy':
        return const Color.fromARGB(255, 2, 119, 252);
      case 'powdery_mildew':
      case 'powdery mildew':
        return const Color.fromARGB(255, 9, 46, 2);
      case 'tip_burn':
      case 'tip burn':
        return Colors.brown;
      default:
        return Colors.grey;
    }
  }

  Widget _buildHealthySection() {
    final healthyColor =
        DetectionPainter.diseaseColors['healthy'] ?? Colors.blue;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: healthyColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.check_circle_outline,
                color: healthyColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                tr('healthy'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1A1A1A),
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _mergeDiseaseSummary(List<dynamic> summary) {
    final Map<String, Map<String, dynamic>> merged = {};
    for (final entry in summary) {
      final rawName = entry['disease'] ?? entry['name'] ?? 'Unknown';
      final disease =
          rawName.toString().toLowerCase().replaceAll('_', ' ').trim();
      final count = entry['count'] ?? 0;
      if (!merged.containsKey(disease)) {
        merged[disease] = {'disease': rawName, 'count': count};
      } else {
        merged[disease]!['count'] += count;
      }
    }
    return merged.values.toList();
  }

  Future<Size> _getImageSize(ImageProvider provider) async {
    final Completer<Size> completer = Completer();
    final ImageStreamListener listener = ImageStreamListener((
      ImageInfo info,
      bool _,
    ) {
      final myImage = info.image;
      completer.complete(
        Size(myImage.width.toDouble(), myImage.height.toDouble()),
      );
    });
    provider.resolve(const ImageConfiguration()).addListener(listener);
    final size = await completer.future;
    return size;
  }

  Widget _buildImageWidget(
    String path, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
  }) {
    print('🖼️ _buildImageWidget called with path: $path');

    if (path.isEmpty) {
      print('🖼️ Path is empty, showing placeholder');
      return Container(
        width: width,
        height: height,
        color: Colors.grey[200],
        child: const Icon(Icons.broken_image, size: 40, color: Colors.grey),
      );
    }
    if (path.startsWith('http')) {
      print('🖼️ Loading network image: $path');
      return CachedNetworkImage(
        imageUrl: path,
        width: width,
        height: height,
        fit: fit,
        placeholder:
            (context, url) => const Center(child: CircularProgressIndicator()),
        errorWidget: (context, url, error) {
          print('🖼️ Network image error: $error');
          return const Icon(Icons.broken_image, size: 40, color: Colors.grey);
        },
      );
    } else if (_isFilePath(path)) {
      print('🖼️ Loading file image: $path');
      final file = File(path);
      if (!file.existsSync()) {
        print('🖼️ File does not exist: $path');
        return Container(
          width: width,
          height: height,
          color: Colors.grey[200],
          child: const Icon(Icons.broken_image, size: 40, color: Colors.grey),
        );
      }
      return Image.file(
        file,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          print('🖼️ File image error: $error');
          return const Icon(Icons.broken_image, size: 40, color: Colors.grey);
        },
      );
    } else {
      print('🖼️ Loading asset image: $path');
      return Image.asset(
        path,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          print('🖼️ Asset image error: $error');
          return const Icon(Icons.broken_image, size: 40, color: Colors.grey);
        },
      );
    }
  }

  bool _isFilePath(String path) {
    // Heuristic: treat as file path if it is absolute or starts with /data/ or C:/ or similar
    return path.startsWith('/') || path.contains(':');
  }

  String _formatExpertLabel(String label) {
    switch (label.toLowerCase()) {
      case 'backterial_blackspot':
      case 'bacterial blackspot':
        return 'Bacterial black spot';
      case 'powdery_mildew':
      case 'powdery mildew':
        return 'Powdery Mildew';
      case 'tip_burn':
      case 'tip burn':
        return 'Burnt leaf';
      default:
        return label
            .split('_')
            .map((word) => word[0].toUpperCase() + word.substring(1))
            .join(' ');
    }
  }

  String _getDiseaseImagePath(String disease) {
    final lower = disease.toLowerCase();
    if (lower.contains('anthracnose')) {
      return 'assets/replace_disease/anthracnose_image.jpg';
    } else if (lower.contains('bacterial') || lower.contains('backterial')) {
      return 'assets/replace_disease/bacterial_image.jpg';
    } else if (lower.contains('dieback')) {
      return 'assets/replace_disease/dieback_image.jpg';
    } else if (lower.contains('powdery')) {
      return 'assets/replace_disease/powdery_image.jpg';
    } else {
      return 'assets/replace_disease/healthy_image.jpg';
    }
  }

  Widget _buildDiseaseCard(String name, String imagePath, String diseaseKey) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: Colors.green.shade200),
      ),
      child: InkWell(
        onTap: () => _showDiseaseDetails(name, imagePath, diseaseKey),
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  imagePath,
                  width: 100,
                  height: 80,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDiseaseNameCard(String name, String diseaseKey) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close bottom sheet first
              _showDiseaseDetails(name, '', diseaseKey);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: const Text('Show More'),
          ),
        ],
      ),
    );
  }

  void _showDiseaseDetails(
    String name,
    String imagePath,
    String diseaseKey,
  ) async {
    // Load disease info if not already loaded
    if (_diseaseInfo.isEmpty) {
      await _loadDiseaseInfo();
    }

    // Try to find disease info by matching the formatted name (like home page)
    Map<String, dynamic>? info;

    // First try exact match with formatted name
    info = _diseaseInfo[name];

    // If not found, try case-insensitive match
    if (info == null) {
      for (var key in _diseaseInfo.keys) {
        if (key.toLowerCase() == name.toLowerCase()) {
          info = _diseaseInfo[key];
          break;
        }
      }
    }

    // If still not found, check special cases
    if (info == null) {
      final label = diseaseKey.toLowerCase();
      if (specialDiseaseInfo.containsKey(label)) {
        info = specialDiseaseInfo[label];
      }
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => DiseaseDetailsPage(
              name: name,
              imagePath:
                  imagePath.isNotEmpty
                      ? imagePath
                      : _getDiseaseImagePath(diseaseKey),
              scientificName: info?['scientificName'] ?? '',
              confirmedBy: info?['confirmedBy'] ?? 'Agricultural Office',
              details: {
                tr('treatments'):
                    (getLocalizedTreatments(context, diseaseKey) ??
                        ((info?['treatments'] as List?)?.cast<String>() ?? [])),
                tr('preventive_measures'):
                    (getLocalizedPreventiveMeasures(context, diseaseKey) ??
                            const <String>[])
                        .isNotEmpty
                        ? (getLocalizedPreventiveMeasures(context, diseaseKey) ??
                            const <String>[])
                        : <String>[tr('not_applicable')],
              },
            ),
      ),
    );
  }

  // Special cases for diseases not in Firestore
  static const Map<String, Map<String, dynamic>> specialDiseaseInfo = {
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
      'symptoms': ['N/A.'],
      'treatments': ['N/A.'],
    },
    'unknown': {
      'symptoms': ['N/A.'],
      'treatments': ['N/A.'],
    },
  };

  Map<String, Map<String, dynamic>> _diseaseInfo = {};

  Future<void> _loadDiseaseInfo() async {
    final diseaseBox = await Hive.openBox('diseaseBox');
    // Try to load from local storage first
    final localDiseaseInfo = diseaseBox.get('diseaseInfo');
    if (localDiseaseInfo != null && localDiseaseInfo is Map) {
      setState(() {
        _diseaseInfo = Map<String, Map<String, dynamic>>.from(
          (localDiseaseInfo as Map).map(
            (k, v) =>
                MapEntry(k as String, Map<String, dynamic>.from(v as Map)),
          ),
        );
      });
    }
    // Always try to fetch latest from Firestore
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('diseases').get();
      final Map<String, Map<String, dynamic>> fetched = {};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final name = data['name'] ?? '';
        if (name.isNotEmpty) {
          fetched[name] = {
            'scientificName': data['scientificName'] ?? '',
            'symptoms': List<String>.from(data['symptoms'] ?? []),
            'treatments': List<String>.from(data['treatments'] ?? []),
            'confirmedBy': data['confirmedBy'] ?? 'Agricultural Office',
          };
        }
      }
      if (fetched.isNotEmpty) {
        setState(() {
          _diseaseInfo = fetched;
        });
        await diseaseBox.put('diseaseInfo', fetched);
      }
    } catch (e) {
      print('Error fetching disease info: $e');
    }
  }

  void _showDiseaseCards(
    BuildContext context,
    List<Map<String, dynamic>> diseases,
  ) async {
    // Load disease info if not already loaded
    if (_diseaseInfo.isEmpty) {
      await _loadDiseaseInfo();
    }

    // If still empty, try loading from cache
    if (_diseaseInfo.isEmpty) {
      try {
        final diseaseBox = await Hive.openBox('diseaseBox');
        final localDiseaseInfo = diseaseBox.get('diseaseInfo');
        if (localDiseaseInfo != null && localDiseaseInfo is Map) {
          _diseaseInfo = Map<String, Map<String, dynamic>>.from(
            localDiseaseInfo.map(
              (k, v) =>
                  MapEntry(k as String, Map<String, dynamic>.from(v as Map)),
            ),
          );
        }
      } catch (e) {
        print('DEBUG: Could not load from cache: $e');
      }
    }

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
                            const Icon(
                              Icons.medical_services_outlined,
                              color: Colors.green,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                tr('diseases'),
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
                        ...diseases.map((disease) {
                          final diseaseName =
                              (disease['disease'] ??
                                      disease['name'] ??
                                      'Unknown')
                                  .toString();
                          final formattedName = _formatExpertLabel(diseaseName);
                          return _buildDiseaseNameCard(
                            formattedName,
                            diseaseName,
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                ),
          ),
    );
  }

  void _showAllDiseaseRecommendations(
    BuildContext context,
    List<Map<String, dynamic>> diseases,
  ) async {
    // Load disease info if not already loaded
    if (_diseaseInfo.isEmpty) {
      await _loadDiseaseInfo();
    }

    // If still empty, try loading from cache
    if (_diseaseInfo.isEmpty) {
      try {
        final diseaseBox = await Hive.openBox('diseaseBox');
        final localDiseaseInfo = diseaseBox.get('diseaseInfo');
        if (localDiseaseInfo != null && localDiseaseInfo is Map) {
          _diseaseInfo = Map<String, Map<String, dynamic>>.from(
            localDiseaseInfo.map(
              (k, v) =>
                  MapEntry(k as String, Map<String, dynamic>.from(v as Map)),
            ),
          );
        }
      } catch (e) {
        print('DEBUG: Could not load from cache: $e');
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.85,
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
                            const Icon(
                              Icons.medical_services_outlined,
                              color: Colors.green,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                tr('treatment_and_recommendations'),
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
                        const SizedBox(height: 8),
                        Text(
                          '${tr('diseases_detected')}: ${diseases.length}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 24),
                        ...diseases.asMap().entries.map((entry) {
                          final index = entry.key;
                          final disease = entry.value;
                          final diseaseName =
                              (disease['disease'] ??
                                      disease['name'] ??
                                      'Unknown')
                                  .toString();
                          final color = _getExpertDiseaseColor(diseaseName);
                          final label = diseaseName.toLowerCase();

                          // Get disease info
                          Map<String, dynamic>? info;
                          if (specialDiseaseInfo.containsKey(label)) {
                            info = specialDiseaseInfo[label];
                          } else {
                            info = _diseaseInfo[label];
                            if (info == null) {
                              final formattedLabel =
                                  _formatExpertLabel(label).toLowerCase();
                              info = _diseaseInfo[formattedLabel];
                            }
                          }

                          return Container(
                            margin: EdgeInsets.only(
                              bottom: index == diseases.length - 1 ? 0 : 24,
                            ),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: color.withOpacity(0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: color.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.local_florist,
                                        color: color,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        _formatExpertLabel(diseaseName),
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                if (info != null) ...[
                                  Text(
                                    tr('symptoms'),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1A1A1A),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ...(info['symptoms'] as List<String>)
                                      .map<Widget>(
                                        (s) => Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 6,
                                          ),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '• ',
                                                style: TextStyle(
                                                  color: color,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Expanded(
                                                child: Text(
                                                  s,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  const SizedBox(height: 16),
                                  Text(
                                    tr('treatment_and_recommendations'),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1A1A1A),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ...((getLocalizedTreatments(
                                            context,
                                            diseaseName,
                                          ) ??
                                          (info['treatments'] as List<String>)))
                                      .map<Widget>(
                                        (t) => Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 6,
                                          ),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '• ',
                                                style: TextStyle(
                                                  color: color,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Expanded(
                                                child: Text(
                                                  t,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                ] else ...[
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.orange[50],
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.orange[200]!,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.info_outline,
                                          color: Colors.orange[700],
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            tr(
                                              'detailed_info_not_available_for',
                                              namedArgs: {
                                                'disease': _formatExpertLabel(
                                                  diseaseName,
                                                ),
                                              },
                                            ),
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.orange[700],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                ),
          ),
    );
  }
}
