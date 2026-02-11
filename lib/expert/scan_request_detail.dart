import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'dart:math' as math;
import '../user/detection_painter.dart';
import '../user/tflite_detector.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ScanRequestDetail extends StatefulWidget {
  final Map<String, dynamic> request;

  const ScanRequestDetail({Key? key, required this.request}) : super(key: key);

  @override
  _ScanRequestDetailState createState() => _ScanRequestDetailState();
}

class _ScanRequestDetailState extends State<ScanRequestDetail> {
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;
  bool _showBoundingBoxes = true;
  String? _selectedHealthStatus; // 'healthy' or 'not_healthy'
  Timer? _heartbeatTimer;

  // Disease information loaded from Firestore (kept for potential future use)
  Map<String, Map<String, dynamic>> _diseaseInfo = {};

  @override
  void initState() {
    super.initState();
    _loadBoundingBoxPreference();
    _claimReportForReview();
    _loadDiseaseInfo();
  }

  Future<void> _loadBoundingBoxPreference() async {
    final box = await Hive.openBox('userBox');
    final savedPreference = box.get('expertShowBoundingBoxes');
    if (savedPreference != null) {
      setState(() {
        _showBoundingBoxes = savedPreference as bool;
      });
    }
  }

  Future<void> _saveBoundingBoxPreference(bool value) async {
    final box = await Hive.openBox('userBox');
    await box.put('expertShowBoundingBoxes', value);
  }

  Future<void> _loadDiseaseInfo() async {
    final diseaseBox = await Hive.openBox('diseaseBox');
    // Try to load from local storage first
    final localDiseaseInfo = diseaseBox.get('diseaseInfo');
    if (localDiseaseInfo != null && localDiseaseInfo is Map) {
      setState(() {
        _diseaseInfo = Map<String, Map<String, dynamic>>.from(
          localDiseaseInfo.map(
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

  bool _isEditing = false;

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    // Release claim synchronously (fire and forget)
    _releaseReportClaimSync();
    _commentController.dispose();
    super.dispose();
  }

  // Claim the report when expert opens it (only for pending reports)
  Future<void> _claimReportForReview() async {
    // Only claim if this is a pending report
    final status = widget.request['status'];
    if (status != 'pending' && status != 'pending_review') {
      return; // Don't claim completed reports
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userBox = Hive.box('userBox');
    final userProfile = userBox.get('userProfile');
    final expertName = userProfile?['fullName'] ?? 'Expert';

    final docId = widget.request['id'] ?? widget.request['requestId'];
    if (docId == null) return;

    try {
      final docRef = FirebaseFirestore.instance
          .collection('scan_requests')
          .doc(docId);

      // Use transaction to claim the report
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);

        if (!snapshot.exists) return;

        final currentData = snapshot.data()!;
        final currentStatus = currentData['status'];

        // Only claim if it's pending
        if (currentStatus != 'pending' && currentStatus != 'pending_review') {
          return;
        }

        // Check if already claimed by someone else
        final reviewingByUid = currentData['reviewingByUid'];
        final reviewingAt = currentData['reviewingAt'];

        if (reviewingByUid != null && reviewingByUid != user.uid) {
          // Check if the claim has expired (15 minutes)
          if (reviewingAt != null) {
            final claimTime = DateTime.parse(reviewingAt);
            final now = DateTime.now();
            final difference = now.difference(claimTime).inMinutes;

            if (difference < 15) {
              // Still claimed by someone else
              return;
            }
          }
        }

        // Claim the report
        transaction.update(docRef, {
          'reviewingBy': expertName,
          'reviewingByUid': user.uid,
          'reviewingAt': DateTime.now().toIso8601String(),
        });
      });

      // Start heartbeat to keep the claim alive
      _startHeartbeat();
    } catch (e) {
      print('Error claiming report: $e');
    }
  }

  // Release the claim when expert leaves (synchronous for dispose)
  void _releaseReportClaimSync() {
    // Only release if this was a pending report
    final status = widget.request['status'];
    if (status != 'pending' && status != 'pending_review') {
      return; // Don't try to release if it wasn't claimed
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final docId = widget.request['id'] ?? widget.request['requestId'];
    if (docId == null) return;

    // Use unawaited to ensure this fires even as page is closing
    FirebaseFirestore.instance
        .collection('scan_requests')
        .doc(docId)
        .update({
          'reviewingBy': FieldValue.delete(),
          'reviewingByUid': FieldValue.delete(),
          'reviewingAt': FieldValue.delete(),
        })
        .then((_) {
          print('✅ Released claim for report: $docId');
        })
        .catchError((error) {
          print('❌ Error releasing claim: $error');
        });
  }

  // Update heartbeat every 5 minutes to keep claim alive
  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        timer.cancel();
        return;
      }

      final docId = widget.request['id'] ?? widget.request['requestId'];
      if (docId == null) {
        timer.cancel();
        return;
      }

      FirebaseFirestore.instance
          .collection('scan_requests')
          .doc(docId)
          .update({'reviewingAt': DateTime.now().toIso8601String()})
          .catchError((error) {
            timer.cancel();
          });
    });
  }

  void _submitReview() async {
    // Validate required fields
    if (_selectedHealthStatus == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a health status'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    // Get current expert's UID and name
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isSubmitting = false);
      return;
    }

    final userBox = Hive.box('userBox');
    final userProfile = userBox.get('userProfile');
    final expertName = userProfile?['fullName'] ?? 'Expert';

    final expertReview = {
      'comment': _commentController.text,
      'healthStatus': _selectedHealthStatus,
      'expertName': expertName,
      'expertUid': user.uid,
    };

    try {
      final docId = widget.request['id'] ?? widget.request['requestId'];

      // Cancel heartbeat timer before submitting
      _heartbeatTimer?.cancel();

      await FirebaseFirestore.instance
          .collection('scan_requests')
          .doc(docId)
          .update({
            'status': 'completed',
            'expertReview': expertReview,
            'expertName': expertName,
            'expertUid': user.uid,
            'reviewedAt': DateTime.now().toIso8601String(),
            // Remove the claim fields
            'reviewingBy': FieldValue.delete(),
            'reviewingByUid': FieldValue.delete(),
            'reviewingAt': FieldValue.delete(),
          });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Review submitted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, {
          ...widget.request,
          'status': 'completed',
          'expertReview': expertReview,
          'expertName': expertName,
          'expertUid': user.uid,
          'reviewedAt': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit review: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted)
        setState(() {
          _isSubmitting = false;
        });
    }
  }

  void _startEditing() {
    setState(() {
      _isEditing = true;
      // Initialize form with existing review data
      final review = widget.request['expertReview'];
      if (review != null) {
        _selectedHealthStatus = review['healthStatus'] ?? null;
        _commentController.text = review['comment'] ?? '';
      }
    });
  }

  void _cancelEditing() {
    setState(() {
      _isEditing = false;
      // Reset form to original values
      final review = widget.request['expertReview'];
      if (review != null) {
        _selectedHealthStatus = review['healthStatus'] ?? null;
        _commentController.text = review['comment'] ?? '';
      }
    });
  }

  Widget _buildImageGrid() {
    final images = widget.request['images'] as List<dynamic>;
    return Column(
      children: [
        // Toggle button for bounding boxes
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const Text('Show Bounding Boxes'),
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
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: images.length,
          itemBuilder: (context, index) {
            final image = images[index];
            final imageUrl = image['imageUrl'];
            final imagePath = image['path'];
            final detections =
                (image['results'] as List<dynamic>?)
                    ?.where(
                      (d) =>
                          d != null &&
                          d['disease'] != null &&
                          d['confidence'] != null,
                    )
                    .toList() ??
                [];

            print('🔍 Raw results: ${image['results']}');
            print('✅ Filtered detections: $detections');
            print('📊 Total detections for image $index: ${detections.length}');
            print('🖼️ Image URL: $imageUrl, Image Path: $imagePath');

            return GestureDetector(
              onTap: () {
                _openImageViewer(index);
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _buildImageWidget(
                      imageUrl ?? imagePath,
                      fit: BoxFit.cover,
                    ),
                  ),
                  if (_showBoundingBoxes && detections.isNotEmpty)
                    Builder(
                      builder: (context) {
                        // Try to get stored image dimensions for fast loading
                        final storedImageWidth = image['imageWidth'] as num?;
                        final storedImageHeight = image['imageHeight'] as num?;

                        if (storedImageWidth != null &&
                            storedImageHeight != null) {
                          // Use stored dimensions for instant loading
                          final imageSize = Size(
                            storedImageWidth.toDouble(),
                            storedImageHeight.toDouble(),
                          );
                          print(
                            '🔍 Expert Grid Fast mode: Using stored dimensions ${imageSize.width}x${imageSize.height}',
                          );

                          return LayoutBuilder(
                            builder: (context, constraints) {
                              // Calculate the actual displayed image size
                              final imgW = imageSize.width;
                              final imgH = imageSize.height;
                              final widgetW = constraints.maxWidth;
                              final widgetH = constraints.maxHeight;

                              // Calculate scale and offset for BoxFit.cover
                              // For cover, we need the LARGER scale to fill the container
                              final scaleX = widgetW / imgW;
                              final scaleY = widgetH / imgH;
                              final scale = scaleX > scaleY ? scaleX : scaleY;

                              final scaledW = imgW * scale;
                              final scaledH = imgH * scale;
                              final dx = (widgetW - scaledW) / 2;
                              final dy = (widgetH - scaledH) / 2;

                              return CustomPaint(
                                painter: DetectionPainter(
                                  results:
                                      detections
                                          .where(
                                            (d) => d['boundingBox'] != null,
                                          )
                                          .map(
                                            (d) => DetectionResult(
                                              label: d['disease'],
                                              confidence: d['confidence'],
                                              boundingBox: Rect.fromLTRB(
                                                d['boundingBox']['left'],
                                                d['boundingBox']['top'],
                                                d['boundingBox']['right'],
                                                d['boundingBox']['bottom'],
                                              ),
                                            ),
                                          )
                                          .toList(),
                                  originalImageSize: imageSize,
                                  displayedImageSize: Size(scaledW, scaledH),
                                  displayedImageOffset: Offset(dx, dy),
                                ),
                                size: Size(widgetW, widgetH),
                              );
                            },
                          );
                        } else {
                          // Fallback to slow method for old data
                          return FutureBuilder<Size>(
                            future: _getImageSize(
                              imageUrl != null && imageUrl.isNotEmpty
                                  ? NetworkImage(imageUrl)
                                  : FileImage(File(imagePath)),
                            ),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                print(
                                  '🔍 Expert Grid: No image size data, hiding bounding boxes',
                                );
                                return const SizedBox.shrink();
                              }
                              final imageSize = snapshot.data!;
                              print(
                                '🔍 Expert Grid Slow mode: Image size loaded from network ${imageSize.width}x${imageSize.height}',
                              );

                              return LayoutBuilder(
                                builder: (context, constraints) {
                                  // Calculate the actual displayed image size
                                  final imgW = imageSize.width;
                                  final imgH = imageSize.height;
                                  final widgetW = constraints.maxWidth;
                                  final widgetH = constraints.maxHeight;

                                  // Calculate scale and offset for BoxFit.cover
                                  // For cover, we need the LARGER scale to fill the container
                                  final scaleX = widgetW / imgW;
                                  final scaleY = widgetH / imgH;
                                  final scale =
                                      scaleX > scaleY ? scaleX : scaleY;

                                  final scaledW = imgW * scale;
                                  final scaledH = imgH * scale;
                                  final dx = (widgetW - scaledW) / 2;
                                  final dy = (widgetH - scaledH) / 2;

                                  return CustomPaint(
                                    painter: DetectionPainter(
                                      results:
                                          detections
                                              .where(
                                                (d) => d['boundingBox'] != null,
                                              )
                                              .map(
                                                (d) => DetectionResult(
                                                  label: d['disease'],
                                                  confidence: d['confidence'],
                                                  boundingBox: Rect.fromLTRB(
                                                    d['boundingBox']['left'],
                                                    d['boundingBox']['top'],
                                                    d['boundingBox']['right'],
                                                    d['boundingBox']['bottom'],
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                      originalImageSize: imageSize,
                                      displayedImageSize: Size(
                                        scaledW,
                                        scaledH,
                                      ),
                                      displayedImageOffset: Offset(dx, dy),
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
                        detections.isNotEmpty
                            ? '${detections.length} Detections'
                            : 'No Detections',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
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
    );
  }

  void _openImageViewer(int initialIndex) {
    final images = widget.request['images'] as List<dynamic>;
    int currentIndex = initialIndex;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.8),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final image = images[currentIndex];
            final imageUrl = image['imageUrl'];
            final imagePath = image['path'];

            // Get detections for this image
            final detections =
                (image['results'] as List<dynamic>?)
                    ?.where(
                      (d) =>
                          d != null &&
                          d['disease'] != null &&
                          d['confidence'] != null,
                    )
                    .toList() ??
                [];

            return Dialog(
              backgroundColor: Colors.black,
              insetPadding: const EdgeInsets.all(12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: [
                      // InteractiveViewer for pinch-to-zoom
                      Positioned.fill(
                        child: InteractiveViewer(
                          key: ValueKey(
                            currentIndex,
                          ), // Force rebuild on image change
                          minScale: 0.5,
                          maxScale: 5.0,
                          panEnabled: true,
                          scaleEnabled: true,
                          boundaryMargin: const EdgeInsets.all(double.infinity),
                          child: Center(
                            child: _buildImageWidget(
                              imageUrl ?? imagePath,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                      // Bounding boxes overlay (with IgnorePointer for zoom interaction)
                      if (_showBoundingBoxes && detections.isNotEmpty)
                        IgnorePointer(
                          child: Builder(
                            builder: (context) {
                              final storedImageWidth =
                                  image['imageWidth'] as num?;
                              final storedImageHeight =
                                  image['imageHeight'] as num?;

                              final widgetW = constraints.maxWidth;
                              final widgetH = constraints.maxHeight;

                              if (storedImageWidth != null &&
                                  storedImageHeight != null) {
                                final originalSize = Size(
                                  storedImageWidth.toDouble(),
                                  storedImageHeight.toDouble(),
                                );
                                // BoxFit.contain scale
                                final scale = math.min(
                                  widgetW / originalSize.width,
                                  widgetH / originalSize.height,
                                );
                                final scaledW = originalSize.width * scale;
                                final scaledH = originalSize.height * scale;
                                final dx = (widgetW - scaledW) / 2;
                                final dy = (widgetH - scaledH) / 2;

                                return CustomPaint(
                                  painter: DetectionPainter(
                                    results:
                                        detections
                                            .where(
                                              (d) => d['boundingBox'] != null,
                                            )
                                            .map(
                                              (d) => DetectionResult(
                                                label: d['disease'],
                                                confidence: d['confidence'],
                                                boundingBox: Rect.fromLTRB(
                                                  d['boundingBox']['left'],
                                                  d['boundingBox']['top'],
                                                  d['boundingBox']['right'],
                                                  d['boundingBox']['bottom'],
                                                ),
                                              ),
                                            )
                                            .toList(),
                                    originalImageSize: originalSize,
                                    displayedImageSize: Size(scaledW, scaledH),
                                    displayedImageOffset: Offset(dx, dy),
                                  ),
                                  size: Size(widgetW, widgetH),
                                );
                              } else {
                                return FutureBuilder<Size>(
                                  future: _getImageSize(
                                    imageUrl != null && imageUrl.isNotEmpty
                                        ? NetworkImage(imageUrl)
                                        : FileImage(File(imagePath)),
                                  ),
                                  builder: (context, snapshot) {
                                    if (!snapshot.hasData) {
                                      return const SizedBox.shrink();
                                    }
                                    final originalSize = snapshot.data!;
                                    // BoxFit.contain scale
                                    final scale = math.min(
                                      widgetW / originalSize.width,
                                      widgetH / originalSize.height,
                                    );
                                    final scaledW = originalSize.width * scale;
                                    final scaledH = originalSize.height * scale;
                                    final dx = (widgetW - scaledW) / 2;
                                    final dy = (widgetH - scaledH) / 2;

                                    return CustomPaint(
                                      painter: DetectionPainter(
                                        results:
                                            detections
                                                .where(
                                                  (d) =>
                                                      d['boundingBox'] != null,
                                                )
                                                .map(
                                                  (d) => DetectionResult(
                                                    label: d['disease'],
                                                    confidence: d['confidence'],
                                                    boundingBox: Rect.fromLTRB(
                                                      d['boundingBox']['left'],
                                                      d['boundingBox']['top'],
                                                      d['boundingBox']['right'],
                                                      d['boundingBox']['bottom'],
                                                    ),
                                                  ),
                                                )
                                                .toList(),
                                        originalImageSize: originalSize,
                                        displayedImageSize: Size(
                                          scaledW,
                                          scaledH,
                                        ),
                                        displayedImageOffset: Offset(dx, dy),
                                      ),
                                      size: Size(widgetW, widgetH),
                                    );
                                  },
                                );
                              }
                            },
                          ),
                        ),
                      // Close button
                      Positioned(
                        top: 8,
                        right: 8,
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      // Previous button
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
                      // Next button
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
                      // Index indicator
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

  Widget _buildImageWidget(dynamic path, {BoxFit fit = BoxFit.cover}) {
    if (path is String && path.isNotEmpty) {
      if (path.startsWith('http')) {
        // Supabase public URL
        return CachedNetworkImage(
          imageUrl: path,
          fit: fit,
          placeholder:
              (context, url) =>
                  const Center(child: CircularProgressIndicator()),
          errorWidget: (context, url, error) {
            return Container(
              color: Colors.grey[200],
              child: const Icon(Icons.image_not_supported),
            );
          },
        );
      } else if (path.startsWith('/') || path.contains(':')) {
        // File path
        return Image.file(
          File(path),
          fit: fit,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.grey[200],
              child: const Icon(Icons.image_not_supported),
            );
          },
        );
      } else {
        // Asset path
        return Image.asset(
          path,
          fit: fit,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.grey[200],
              child: const Icon(Icons.image_not_supported),
            );
          },
        );
      }
    } else {
      // Null or not a string
      return Container(
        color: Colors.grey[200],
        child: const Icon(Icons.image_not_supported),
      );
    }
  }

  // Helper to merge disease summary entries with the same disease
  List<Map<String, dynamic>> _mergeDiseaseSummary(List<dynamic> summary) {
    final Map<String, Map<String, dynamic>> merged = {};
    for (final entry in summary) {
      final disease = entry['label'] ?? entry['disease'] ?? entry['name'];
      final count = entry['count'] ?? 0;
      final percentage = entry['percentage'] ?? 0.0;
      if (!merged.containsKey(disease)) {
        merged[disease] = {
          'disease': disease,
          'count': count,
          'percentage': percentage,
        };
      } else {
        merged[disease]!['count'] += count;
        merged[disease]!['percentage'] += percentage;
      }
    }
    return merged.values.toList();
  }

  Widget _buildDiseaseSummary() {
    final rawSummary = widget.request['diseaseSummary'] as List<dynamic>? ?? [];
    final diseaseSummary = _mergeDiseaseSummary(rawSummary);

    // Check if there's healthy
    final hasHealthy = diseaseSummary.any((d) {
      final diseaseName =
          (d['disease'] ?? d['name'] ?? '').toString().toLowerCase();
      return diseaseName == 'healthy';
    });

    // Filter out healthy, tip_burn, unknown, and non-mango leaf classes
    final filteredSummary =
        diseaseSummary.where((d) {
          final rawDiseaseName = (d['disease'] ?? d['name'] ?? '').toString();
          final normalizedName =
              rawDiseaseName.toLowerCase().replaceAll('_', ' ').trim();

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
              validDiseases.contains(rawDiseaseName.toLowerCase());
          final isNonMangoLeaf =
              normalizedName == 'banana' ||
              normalizedName == 'eggplant' ||
              normalizedName == 'moringa';
          final isTipBurn =
              normalizedName == 'tip burn' || normalizedName == 'tip_burn';
          final isUnknown = normalizedName == 'unknown';
          final isHealthy = normalizedName == 'healthy';

          return isValidDisease &&
              !isNonMangoLeaf &&
              !isTipBurn &&
              !isUnknown &&
              !isHealthy;
        }).toList();

    // Sort by count
    final sortedDiseases = [...filteredSummary]..sort((a, b) {
      final countA = a['count'] as int? ?? 0;
      final countB = b['count'] as int? ?? 0;
      return countB.compareTo(countA);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with stats
        Row(
          children: [
            Text(
              'Disease Summary',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${sortedDiseases.length} ${sortedDiseases.length == 1 ? 'Disease' : 'Diseases'}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Compact disease list
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            children: [
              // Healthy (if any)
              if (hasHealthy)
                _buildCompactDiseaseRow(
                  'Healthy',
                  DetectionPainter.diseaseColors['healthy'] ?? Colors.blue,
                  Icons.check_circle_outline,
                  isLast: sortedDiseases.isEmpty,
                ),
              // Diseases
              if (sortedDiseases.isEmpty && !hasHealthy)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        color: Colors.grey[400],
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'No diseases detected',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              else
                ...sortedDiseases.asMap().entries.map((entry) {
                  final index = entry.key;
                  final disease = entry.value;
                  final rawDiseaseName =
                      (disease['disease'] ?? disease['name'] ?? 'Unknown')
                          .toString();
                  final color = _getDiseaseColor(rawDiseaseName);
                  final isLast = index == sortedDiseases.length - 1;

                  return _buildCompactDiseaseRow(
                    _formatExpertLabel(rawDiseaseName),
                    color,
                    Icons.warning_rounded,
                    isLast: isLast,
                  );
                }).toList(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompactDiseaseRow(
    String name,
    Color color,
    IconData icon, {
    bool isLast = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border:
            isLast
                ? null
                : Border(
                  bottom: BorderSide(color: Colors.grey[100]!, width: 1),
                ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showHealthyStatus(BuildContext context) {
    final images = widget.request['images'] as List<dynamic>? ?? [];
    final healthyDetections = <Map<String, dynamic>>[];

    // Collect all healthy detections
    for (int i = 0; i < images.length; i++) {
      final image = images[i];
      final results = image['results'] as List<dynamic>? ?? [];
      for (final result in results) {
        if (result != null &&
            result['disease']?.toString().toLowerCase() == 'healthy') {
          healthyDetections.add({
            'imageIndex': i,
            'imageUrl': image['imageUrl'],
            'imagePath': image['path'],
            'confidence': result['confidence'],
            'boundingBox': result['boundingBox'],
          });
        }
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
                        // Healthy detection statistics
                        Row(
                          children: [
                            Expanded(
                              child: _buildDetectionStatCard(
                                'Healthy Detections',
                                '${healthyDetections.length}',
                                Icons.check_circle,
                                Colors.green,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildDetectionStatCard(
                                'Avg Confidence',
                                healthyDetections.isNotEmpty
                                    ? '${(healthyDetections.map((d) => d['confidence'] as num).reduce((a, b) => a + b) / healthyDetections.length * 100).toStringAsFixed(1)}%'
                                    : 'N/A',
                                Icons.trending_up,
                                Colors.green,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Healthy Leaf Detections',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (healthyDetections.isNotEmpty)
                          ...healthyDetections.map((detection) {
                            final confidence = detection['confidence'] as num;
                            final imageIndex = detection['imageIndex'] as int;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.green.withOpacity(
                                    0.2,
                                  ),
                                  child: Text(
                                    '${(confidence * 100).toStringAsFixed(0)}%',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                ),
                                title: Text('Image ${imageIndex + 1}'),
                                subtitle: Text(
                                  'Confidence: ${(confidence * 100).toStringAsFixed(1)}%',
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.visibility, size: 20),
                                  onPressed: () => _openImageViewer(imageIndex),
                                  tooltip: 'View image',
                                ),
                              ),
                            );
                          }).toList()
                        else
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: Text(
                                'No healthy leaf detections found.',
                                style: TextStyle(color: Colors.grey),
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

  void _showDetectionDetails(
    BuildContext context,
    String diseaseName,
    int count,
  ) {
    final images = widget.request['images'] as List<dynamic>? ?? [];
    final detections = <Map<String, dynamic>>[];

    // Collect all detections for this disease
    for (int i = 0; i < images.length; i++) {
      final image = images[i];
      final results = image['results'] as List<dynamic>? ?? [];
      for (final result in results) {
        if (result != null && result['disease']?.toString() == diseaseName) {
          detections.add({
            'imageIndex': i,
            'imageUrl': image['imageUrl'],
            'imagePath': image['path'],
            'confidence': result['confidence'],
            'boundingBox': result['boundingBox'],
          });
        }
      }
    }

    // Sort by image index for easier review
    detections.sort(
      (a, b) => (a['imageIndex'] as int).compareTo(b['imageIndex'] as int),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.8,
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
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: _getDiseaseColor(
                                  diseaseName,
                                ).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.analytics,
                                  size: 16,
                                  color: _getDiseaseColor(diseaseName),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '${_isUnknownDetection(diseaseName) ? 'Unknown' : _formatExpertLabel(diseaseName)} Detections',
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
                        // Detection statistics
                        Row(
                          children: [
                            Expanded(
                              child: _buildDetectionStatCard(
                                'Total Detections',
                                '$count',
                                Icons.analytics,
                                Colors.blue,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildDetectionStatCard(
                                'Images Affected',
                                '${detections.map((d) => d['imageIndex']).toSet().length}',
                                Icons.image,
                                Colors.blue,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildDetectionStatCard(
                                'Detection Quality',
                                detections.length > 1 ? 'Multiple' : 'Single',
                                Icons.analytics,
                                detections.length > 1
                                    ? Colors.orange
                                    : Colors.green,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Individual Detections',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // List of detections
                        ...detections.map((detection) {
                          final imageIndex = detection['imageIndex'] as int;
                          final color = _getDiseaseColor(diseaseName);

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: color.withOpacity(0.2),
                                child: Text(
                                  '${imageIndex + 1}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: color,
                                  ),
                                ),
                              ),
                              title: Text('Image ${imageIndex + 1}'),
                              subtitle: Text(
                                'Detection found',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.visibility,
                                      size: 20,
                                    ),
                                    onPressed:
                                        () => _openImageViewer(imageIndex),
                                    tooltip: 'View image',
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                        if (detections.isEmpty)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: Text(
                                'No detections found for this disease.',
                                style: TextStyle(color: Colors.grey),
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

  Widget _buildDetectionStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Expert Review',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        // Health Status Selection
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Choose health Status *',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _selectedHealthStatus = 'healthy';
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color:
                                _selectedHealthStatus == 'healthy'
                                    ? Colors.green.withOpacity(0.1)
                                    : Colors.grey[100],
                            border: Border.all(
                              color:
                                  _selectedHealthStatus == 'healthy'
                                      ? Colors.green
                                      : Colors.grey[300]!,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_circle,
                                color:
                                    _selectedHealthStatus == 'healthy'
                                        ? Colors.green
                                        : Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Healthy',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      _selectedHealthStatus == 'healthy'
                                          ? Colors.green
                                          : Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _selectedHealthStatus = 'not_healthy';
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color:
                                _selectedHealthStatus == 'not_healthy'
                                    ? Colors.orange.withOpacity(0.1)
                                    : Colors.grey[100],
                            border: Border.all(
                              color:
                                  _selectedHealthStatus == 'not_healthy'
                                      ? Colors.orange
                                      : Colors.grey[300]!,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.warning,
                                color:
                                    _selectedHealthStatus == 'not_healthy'
                                        ? Colors.orange
                                        : Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Not Healthy',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      _selectedHealthStatus == 'not_healthy'
                                          ? Colors.orange
                                          : Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Additional Treatment Plan
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Additional Treatment Plan',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _commentController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Additional Treatment Plan (Optional)',
                    hintText:
                        'Enter additional treatment recommendations... (Optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Submit Button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _submitReview,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child:
                _isSubmitting
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                    : const Text(
                      'Submit Review',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompletedReview() {
    final review = widget.request['expertReview'];
    if (review == null) {
      return const Center(child: Text('No review data available'));
    }

    if (_isEditing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Edit Expert Review',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              TextButton.icon(
                onPressed: _cancelEditing,
                icon: const Icon(Icons.close),
                label: const Text('Cancel'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildReviewForm(),
        ],
      );
    }

    final healthStatus = review['healthStatus'] ?? null;
    final comment = review['comment'] ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Expert Review',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            TextButton.icon(
              onPressed: _startEditing,
              icon: const Icon(Icons.edit),
              label: const Text('Edit Review'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Health Status
        if (healthStatus != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Health Status',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        healthStatus == 'healthy'
                            ? Icons.check_circle
                            : Icons.warning,
                        color:
                            healthStatus == 'healthy'
                                ? Colors.green
                                : Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        healthStatus == 'healthy' ? 'Healthy' : 'Not Healthy',
                        style: TextStyle(
                          color:
                              healthStatus == 'healthy'
                                  ? Colors.green
                                  : Colors.orange,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        if (healthStatus != null) const SizedBox(height: 16),
        // Additional Treatment Plan
        if (comment.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Additional Treatment Plan',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    comment,
                    style: const TextStyle(fontSize: 15, color: Colors.black87),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  bool _isUnknownDetection(String diseaseName) {
    final lowerName = diseaseName.toLowerCase();
    return lowerName == 'tip_burn' ||
        lowerName == 'tip burn' ||
        lowerName == 'unknown' ||
        lowerName.contains('unknown') ||
        lowerName.contains('tip_burn') ||
        lowerName.contains('tip burn');
  }

  Color _getDiseaseColor(String diseaseName) {
    final Map<String, Color> diseaseColors = {
      'anthracnose': Colors.orange,
      'bacterial_blackspot': Colors.purple,
      'bacterial blackspot': Colors.purple,
      'bacterial black spot': Colors.purple,
      'backterial_blackspot': Colors.purple,
      'dieback': Colors.red,
      'healthy': Color.fromARGB(255, 2, 119, 252),
      'powdery_mildew': Color.fromARGB(255, 9, 46, 2),
      'powdery mildew': Color.fromARGB(255, 9, 46, 2),
      'tip_burn': Colors.brown,
      'tip burn': Colors.brown,
      'unknown': Colors.brown,
    };
    return diseaseColors[diseaseName.toLowerCase()] ?? Colors.grey;
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

  @override
  Widget build(BuildContext context) {
    final userName = widget.request['userName']?.toString() ?? 'Asif';
    final submittedAt = widget.request['submittedAt']?.toString() ?? '';
    final reviewedAt = widget.request['reviewedAt']?.toString() ?? '';

    // Format dates for better readability
    final formattedSubmittedDate =
        submittedAt.isNotEmpty && DateTime.tryParse(submittedAt) != null
            ? DateFormat(
              'MMM d, yyyy – h:mma',
            ).format(DateTime.parse(submittedAt))
            : submittedAt;
    final formattedReviewedDate =
        reviewedAt.isNotEmpty && DateTime.tryParse(reviewedAt) != null
            ? DateFormat(
              'MMM d, yyyy – h:mma',
            ).format(DateTime.parse(reviewedAt))
            : reviewedAt;

    final isCompleted =
        widget.request['status']?.toString() == 'reviewed' ||
        widget.request['status']?.toString() == 'completed';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: const Text(
          'Analysis Review',
          style: TextStyle(color: Colors.white),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User and timestamp info
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Card(
                color: Colors.grey[50],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.person,
                            size: 18,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              userName,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.green,
                              ),
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.schedule,
                            size: 16,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'Submitted:',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            formattedSubmittedDate.isNotEmpty
                                ? formattedSubmittedDate
                                : '-',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      if (isCompleted && reviewedAt.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              size: 16,
                              color: Colors.green,
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'Reviewed:',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              formattedReviewedDate,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            // Analyzed Images
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
            // Disease Summary
            Padding(
              padding: const EdgeInsets.all(16),
              child: _buildDiseaseSummary(),
            ),
            // Review Section
            Padding(
              padding: const EdgeInsets.all(16),
              child:
                  widget.request['status']?.toString() == 'pending'
                      ? _buildReviewForm()
                      : _buildCompletedReview(),
            ),
          ],
        ),
      ),
    );
  }

  String _formatExpertLabel(String label) {
    switch (label.toLowerCase()) {
      case 'backterial_blackspot':
      case 'bacterial blackspot':
      case 'bacterial black spot':
        return 'Bacterial black spot';
      case 'powdery_mildew':
      case 'powdery mildew':
        return 'Powdery Mildew';
      case 'tip_burn':
      case 'tip burn':
        return 'Burnt leaf';
      default:
        return label
            .replaceAll('_', ' ')
            .split(' ')
            .map(
              (word) =>
                  word.isNotEmpty
                      ? word[0].toUpperCase() + word.substring(1)
                      : '',
            )
            .join(' ');
    }
  }
}
