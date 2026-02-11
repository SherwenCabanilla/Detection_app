import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:io';
// import 'dart:convert';
import 'package:path_provider/path_provider.dart';
// import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:mime/mime.dart';
import 'package:hive/hive.dart';
import 'package:image/image.dart' as img;
import 'tflite_detector.dart';
import 'detection_painter.dart';
import 'disease_details_page.dart';
// import 'detection_carousel_screen.dart';
// import 'detection_result_card.dart';
// import 'tracking_page.dart';
// import '../shared/user_profile.dart';
// import '../shared/review_manager.dart';

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
  // final ReviewManager _reviewManager = ReviewManager();

  // Disease information loaded from Firestore
  Map<String, Map<String, dynamic>> _diseaseInfo = {};

  @override
  void initState() {
    super.initState();
    // sync from persistent preference used across farmer screens
    Future.microtask(() async {
      final box = await Hive.openBox('userBox');
      final pref = box.get('showBoundingBoxes');
      if (pref is bool && mounted) {
        setState(() {
          showBoundingBoxes = pref;
        });
      }
    });
    // Load disease information from Firestore
    _loadDiseaseInfo();
    // Check if there are no detections and show modal
    Future.microtask(() {
      if (mounted) {
        _checkAndShowNoDetectionModal();
      }
    });
  }

  // Check if there are warnings that should prevent sending for review
  bool _hasWarnings() {
    final diseaseCounts = _getOverallDiseaseCount();
    final healthyCount = _getHealthyCount();
    final sortedDiseases = diseaseCounts.entries.toList()..sort((a, b) {
      final percentageA = _getDiseasePercentage(a.key, diseaseCounts);
      final percentageB = _getDiseasePercentage(b.key, diseaseCounts);
      return percentageB.compareTo(percentageA);
    });
    
    // Collect all detected labels
    final Set<String> allDetectedLabels = {};
    for (var results in widget.allResults.values) {
      for (var result in results) {
        allDetectedLabels.add(result.label.toLowerCase());
      }
    }
    
    // Valid mango leaf classes
    const validMangoLeafClasses = {
      'healthy',
      'anthracnose',
      'bacterial_blackspot',
      'backterial_blackspot',
      'dieback',
      'powdery_mildew',
    };
    
    // Non-mango leaf classes
    const nonMangoLeafClasses = {
      'banana',
      'eggplant',
      'moringa',
    };
    
    // Check if there are any valid mango leaf detections
    final hasValidMangoLeaf = allDetectedLabels.any(
      (label) => validMangoLeafClasses.contains(label),
    );
    
    // Check if only non-mango leaf classes are detected
    final onlyNonMangoLeaf = allDetectedLabels.isNotEmpty &&
        allDetectedLabels.every(
          (label) => nonMangoLeafClasses.contains(label),
        ) && !hasValidMangoLeaf;
    
    // Check if only tip_burn is detected
    final onlyTipBurn = allDetectedLabels.length == 1 && 
        allDetectedLabels.contains('tip_burn');
    
    // Check if no detections
    final noDetections = sortedDiseases.isEmpty && healthyCount == 0;
    
    // Return true if any warning condition is met
    return onlyNonMangoLeaf || onlyTipBurn || noDetections;
  }

  void _checkAndShowNoDetectionModal() {
    final diseaseCounts = _getOverallDiseaseCount();
    final healthyCount = _getHealthyCount();
    final sortedDiseases = diseaseCounts.entries.toList()..sort((a, b) {
      final percentageA = _getDiseasePercentage(a.key, diseaseCounts);
      final percentageB = _getDiseasePercentage(b.key, diseaseCounts);
      return percentageB.compareTo(percentageA);
    });
    
    // Collect all detected labels
    final Set<String> allDetectedLabels = {};
    for (var results in widget.allResults.values) {
      for (var result in results) {
        allDetectedLabels.add(result.label.toLowerCase());
      }
    }
    
    // Valid mango leaf classes
    const validMangoLeafClasses = {
      'healthy',
      'anthracnose',
      'bacterial_blackspot',
      'backterial_blackspot',
      'dieback',
      'powdery_mildew',
    };
    
    // Non-mango leaf classes
    const nonMangoLeafClasses = {
      'banana',
      'eggplant',
      'moringa',
    };
    
    // Check if there are any valid mango leaf detections
    final hasValidMangoLeaf = allDetectedLabels.any(
      (label) => validMangoLeafClasses.contains(label),
    );
    
    // Check if only non-mango leaf classes are detected
    final onlyNonMangoLeaf = allDetectedLabels.isNotEmpty &&
        allDetectedLabels.every(
          (label) => nonMangoLeafClasses.contains(label),
        ) && !hasValidMangoLeaf;
    
    // Check if only tip_burn is detected
    final onlyTipBurn = allDetectedLabels.length == 1 && 
        allDetectedLabels.contains('tip_burn');
    
    // Show non-mango leaf warning modal if only non-mango leaf detected
    if (onlyNonMangoLeaf) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showNonMangoLeafWarningModal();
        }
      });
      return;
    }
    
    // Show tip_burn warning modal if only tip_burn detected
    if (onlyTipBurn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showTipBurnWarningModal();
        }
      });
      return;
    }
    
    // Show modal if no diseases and no healthy leaves detected
    if (sortedDiseases.isEmpty && healthyCount == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showNoDetectionModal();
        }
      });
    }
  }

  void _showNonMangoLeafWarningModal() {
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
          'The image does not appear to be a mango leaf. Please ensure you are scanning mango leaves for accurate disease detection.',
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

  void _showTipBurnWarningModal() {
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
          'No disease symptoms detected. Please scan mango leaves that show visible signs of disease for analysis.',
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

  void _showNoDetectionModal() {
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
          'No diseases or healthy leaves were detected in the scanned images. Please ensure the photo is clear and well-lit, the mango leaf is in focus, and the entire leaf is captured in the frame.',
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

  Future<void> _loadDiseaseInfo() async {
    final diseaseBox = await Hive.openBox('diseaseBox');
    // Try to load from local storage first (for offline access)
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
      print(
        'DEBUG: Loaded disease info from cache: ${_diseaseInfo.keys.toList()}',
      );
      print('DEBUG: Cache data details:');
      _diseaseInfo.forEach((key, value) {
        print(
          '  - "$key": symptoms=${(value['symptoms'] as List).length}, treatments=${(value['treatments'] as List).length}',
        );
      });
    }

    // Try to fetch latest from Firestore (only if online)
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
        print(
          'DEBUG: Updated disease info from Firestore: ${fetched.keys.toList()}',
        );
      } else {
        print('DEBUG: No disease info found in Firestore!');
      }
    } catch (e) {
      print('DEBUG: Could not fetch from Firestore (offline?): $e');
      if (_diseaseInfo.isEmpty) {
        print('DEBUG: No cached disease info available either!');
      } else {
        print('DEBUG: Using cached disease info for offline access');
      }
    }
  }

  Map<String, int> _getOverallDiseaseCount() {
    // Non-mango leaf classes, tip_burn, and healthy should be excluded from disease counts
    const nonMangoLeafClasses = {'banana', 'eggplant', 'moringa'};
    const excludedClasses = {'healthy', 'tip_burn', 'unknown', ...nonMangoLeafClasses};
    
    final Map<String, int> counts = {};
    for (var results in widget.allResults.values) {
      for (var result in results) {
        final label = result.label.toLowerCase();
        // Only count valid mango leaf diseases (excluding healthy)
        if (!excludedClasses.contains(label)) {
          counts[result.label] = (counts[result.label] ?? 0) + 1;
        }
      }
    }
    return counts;
  }

  // Get healthy count separately
  int _getHealthyCount() {
    int count = 0;
    for (var results in widget.allResults.values) {
      for (var result in results) {
        if (result.label.toLowerCase() == 'healthy') {
          count++;
        }
      }
    }
    return count;
  }

  double _getDiseasePercentage(String disease, Map<String, int> diseaseCounts) {
    final totalLeaves = diseaseCounts.values.fold(0, (a, b) => a + b);
    if (totalLeaves == 0) return 0;
    return diseaseCounts[disease]! / totalLeaves;
  }

  // Compress image without resizing dimensions. Only re-encodes pixels.
  Future<File> _compressJpegSameSize(File original, {int quality = 85}) async {
    final bytes = await original.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return original;

    final encoded = img.encodeJpg(decoded, quality: quality);
    final tempDir = await getTemporaryDirectory();
    final out = File(
      '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}_q$quality.jpg',
    );
    await out.writeAsBytes(encoded, flush: true);
    return out;
  }

  // If file exceeds 30 MB, progressively lower quality (85→65) until under limit.
  Future<File> _compressIfOver30Mb(File original) async {
    const int limitBytes = 30 * 1024 * 1024;
    final int sizeBytes = await original.length();
    if (sizeBytes <= limitBytes) return original;

    // Try descending quality steps; always re-encode from original bytes
    for (final quality in [85, 80, 75, 70, 65]) {
      final candidate = await _compressJpegSameSize(original, quality: quality);
      if (await candidate.length() <= limitBytes) return candidate;
    }
    // Return the smallest (last) attempt if still over limit
    return await _compressJpegSameSize(original, quality: 65);
  }

  Future<void> _loadImageSizes() async {
    for (int index = 0; index < widget.imagePaths.length; index++) {
      final image = File(widget.imagePaths[index]);
      final decodedImage = await image.readAsBytes();
      final imageInfo = await img.decodeImage(decodedImage);
      if (mounted) {
        setState(() {
          imageSizes[widget.imagePaths[index]] = Size(
            imageInfo!.width.toDouble(),
            imageInfo.height.toDouble(),
          );
        });
      }
    }
  }

  void _showSendingDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(width: 24),
                  Flexible(
                    child: Text(
                      message,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Future<void> _sendForExternalReview() async {
    print('DEBUG: _sendForExternalReview called');
    setState(() {
      _isSubmitting = true;
    });
    _showSendingDialog(context, tr('sending_to_expert'));
    try {
      // final _userProfile = UserProfile();
      final user = FirebaseAuth.instance.currentUser;
      final userId = user?.uid ?? 'unknown';
      // final _reviewManager = ReviewManager();

      // --- Upload images to Firebase Storage and get URLs ---
      final List<Map<String, String>> uploadedImages = [];
      for (int i = 0; i < widget.imagePaths.length; i++) {
        final originalFile = File(widget.imagePaths[i]);
        // Compress only if over 30MB; keep dimensions unchanged
        final file = await _compressIfOver30Mb(originalFile);
        final fileName =
            '${userId}_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        final storagePath = 'leaf/$fileName';
        final ref = FirebaseStorage.instance.ref().child(storagePath);
        final detectedMime = lookupMimeType(file.path) ?? 'image/jpeg';
        await ref.putFile(file, SettableMetadata(contentType: detectedMime));
        final downloadUrl = await ref.getDownloadURL();
        uploadedImages.add({'url': downloadUrl, 'path': storagePath});
      }

      // Convert detection results to the format expected by ReviewManager
      final detections = <Map<String, dynamic>>[];
      for (var i = 0; i < widget.allResults.length; i++) {
        final results = widget.allResults[i] ?? [];
        for (var result in results) {
          detections.add({
            'disease': result.label,
            'confidence': result.confidence,
            'imageUrl': uploadedImages[i]['url'],
            'boundingBox': {
              'left': result.boundingBox.left,
              'top': result.boundingBox.top,
              'right': result.boundingBox.right,
              'bottom': result.boundingBox.bottom,
            },
          });
        }
      }

      // Convert disease counts to the format expected by ReviewManager
      // Count each unique disease type as 1 per report (not per detection)
      final Set<String> uniqueDiseases = {};
      widget.allResults.values.forEach((results) {
        for (var result in results) {
          final label = result.label.toLowerCase();
          if (label != 'tip_burn' && label != 'unknown') {
            uniqueDiseases.add(result.label);
          }
        }
      });
      print('DEBUG: All detected labels: ${uniqueDiseases.toList()}');
      final diseaseCounts =
          uniqueDiseases.map((disease) {
            return {
              'name': _formatLabel(disease),
              'label': disease,
              'count': 1, // Each disease type counts as 1 per report
            };
          }).toList();

      // --- Also add to tracking (history) ---
      final box = await Hive.openBox('trackingBox');
      final List sessions = box.get('scans', defaultValue: []);
      final now = DateTime.now().toIso8601String();
      final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
      final List<Map<String, dynamic>> images = [];
      for (int i = 0; i < widget.imagePaths.length; i++) {
        final results = widget.allResults[i] ?? [];
        List<Map<String, dynamic>> resultList = [];
        if (results.isNotEmpty) {
          for (var result in results) {
            resultList.add({
              'disease': result.label,
              'confidence': result.confidence,
              'boundingBox': {
                'left': result.boundingBox.left,
                'top': result.boundingBox.top,
                'right': result.boundingBox.right,
                'bottom': result.boundingBox.bottom,
              },
            });
          }
        } else {
          resultList.add({'disease': 'Unknown', 'confidence': null});
        }

        // Get actual image dimensions for accurate offline bounding box positioning
        final imageFile = File(widget.imagePaths[i]);
        final imageBytes = await imageFile.readAsBytes();
        final imageInfo = await img.decodeImage(imageBytes);
        final imageWidth = imageInfo!.width.toDouble();
        final imageHeight = imageInfo.height.toDouble();

        // Save network URL and dimensions for proper caching
        images.add({
          'imageUrl': uploadedImages[i]['url'],
          'storagePath': uploadedImages[i]['path'],
          'imageWidth': imageWidth, // Add actual image width
          'imageHeight': imageHeight, // Add actual image height
          'results': resultList,
        });
      }
      sessions.add({
        'sessionId': sessionId,
        'date': now,
        'images': images,
        'source': 'expert_review',
      });
      await box.put('scans', sessions);
      print('DEBUG: sessions after add (review): ' + sessions.toString());
      // --- Upload to Firestore scan_requests collection ---
      // Get full name from Hive userBox
      final userBox = await Hive.openBox('userBox');
      final userProfile = userBox.get('userProfile');
      final fullName = userProfile?['fullName'] ?? 'Unknown';
      await FirebaseFirestore.instance
          .collection('scan_requests')
          .doc(sessionId)
          .set({
            'id': sessionId,
            'userId': userId,
            'userName': fullName,
            'status': 'pending',
            'submittedAt': now,
            'images': images, // This now includes both imageUrl and imagePath
            'diseaseSummary':
                diseaseCounts
                    .map((e) => {'name': e['name'], 'count': e['count']})
                    .toList(),
            // No expertReview yet
          });
      // --- End add to tracking ---

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Dismiss dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('analysis_sent_successfully')),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 70, left: 16, right: 16),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Dismiss dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr('error_sending_for_review', namedArgs: {'error': '$e'}),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 70, left: 16, right: 16),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  // String _getSeverityLevel(String disease) {
  //   final avgConfidence = _getDiseasePercentage(
  //     disease,
  //     _getOverallDiseaseCount(),
  //   );
  //   if (avgConfidence > 0.8) return 'high';
  //   if (avgConfidence > 0.5) return 'medium';
  //   return 'low';
  // }

  String _formatLabel(String label) {
    switch (label.toLowerCase()) {
      case 'backterial_blackspot':
        return 'Bacterial black spot';
      case 'powdery_mildew':
        return 'Powdery Mildew';
      case 'tip_burn':
        return 'Non-disease related';
      case 'unknown':
        return 'Unknown';
      case 'banana':
      case 'eggplant':
      case 'moringa':
        return 'Non-mango leaf';
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

  void _showDiseaseDetails(String name, String imagePath, String diseaseKey) async {
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
    
    // If still not found, try matching using the disease key variations
    if (info == null) {
      final label = diseaseKey.toLowerCase();
      
      // Map disease keys to possible Firestore names
      final Map<String, List<String>> keyToNames = {
        'anthracnose': ['Anthracnose'],
        'bacterial_blackspot': ['Bacterial black spot', 'Bacterial Black Spot'],
        'backterial_blackspot': ['Bacterial black spot', 'Bacterial Black Spot'],
        'dieback': ['Dieback'],
        'powdery_mildew': ['Powdery mildew', 'Powdery Mildew'],
      };
      
      final possibleNames = keyToNames[label];
      if (possibleNames != null) {
        for (var possibleName in possibleNames) {
          if (_diseaseInfo.containsKey(possibleName)) {
            info = _diseaseInfo[possibleName];
            break;
          }
          // Also try case-insensitive
          for (var key in _diseaseInfo.keys) {
            if (key.toLowerCase() == possibleName.toLowerCase()) {
              info = _diseaseInfo[key];
              break;
            }
          }
          if (info != null) break;
        }
      }
      
      // If still not found, check special cases
      if (info == null && specialDiseaseInfo.containsKey(label)) {
        info = specialDiseaseInfo[label];
      }
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DiseaseDetailsPage(
          name: name,
          imagePath: imagePath.isEmpty ? 'assets/replace_disease/healthy_image.jpg' : imagePath,
          scientificName: info?['scientificName'] ?? '',
          details: {
            'Symptoms': (info?['symptoms'] as List?)?.cast<String>() ?? [],
            'Treatments': (info?['treatments'] as List?)?.cast<String>() ?? [],
          },
        ),
      ),
    );
  }

  Widget _buildHealthySection() {
    final healthyColor = DetectionPainter.diseaseColors['healthy'] ?? Colors.blue;
    
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

  Widget _buildNoDiseasesMessage() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, color: Colors.grey[600], size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              tr('no_detections'),
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getDistinctDiseaseCountLabel(Map<String, int> diseaseCounts) {
    // Non-mango leaf classes should be excluded
    const nonMangoLeafClasses = {'banana', 'eggplant', 'moringa'};
    const excludedClasses = {'healthy', 'tip_burn', 'unknown', ...nonMangoLeafClasses};
    
    final distinct =
        diseaseCounts.keys.where((d) {
          final lower = d.toLowerCase();
          return !excludedClasses.contains(lower);
        }).length;
    return '$distinct';
  }

  Widget _buildCombinedDiseaseCard(List<MapEntry<String, int>> sortedDiseases) {
    final diseaseCounts = _getOverallDiseaseCount();
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...sortedDiseases.asMap().entries.map((entry) {
            final index = entry.key;
            final diseaseEntry = entry.value;
            final disease = diseaseEntry.key;
            final color = DetectionPainter.diseaseColors[disease] ?? Colors.grey;
            final isHealthy = disease.toLowerCase() == 'healthy';
            final isUnknown =
                disease.toLowerCase() == 'tip_burn' ||
                disease.toLowerCase() == 'unknown';
            final isLast = index == sortedDiseases.length - 1;

            return Container(
              padding: EdgeInsets.fromLTRB(
                20,
                index == 0 ? 20 : 16,
                20,
                16,
              ),
              decoration: BoxDecoration(
                border: isLast ? null : Border(
                  bottom: BorderSide(color: Colors.grey[100]!, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isHealthy || isUnknown
                          ? Icons.check_circle_outline
                          : Icons.warning_rounded,
                      color: color,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatLabel(disease),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF1A1A1A),
                            letterSpacing: -0.3,
                          ),
                        ),
                        if (!isHealthy && !isUnknown) ...[
                          const SizedBox(height: 4),
                          _buildSeverityBadge(disease, diseaseCounts),
                        ],
                      ],
                    ),
                  ),
                  if (!isHealthy && !isUnknown)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: ElevatedButton(
                        onPressed: () {
                          _showDiseaseDetails(_formatLabel(disease), _getDiseaseImagePath(disease), disease);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Recommendation',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    )
                  else
                    Icon(
                      Icons.chevron_right,
                      color: Colors.grey[400],
                      size: 20,
                    ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  // Calculate severity for the 4 main diseases only
  String _getSeverityLevel(String disease, Map<String, int> diseaseCounts) {
    // Only calculate for the 4 main diseases
    const mainDiseases = ['anthracnose', 'backterial_blackspot', 'powdery_mildew', 'dieback'];
    if (!mainDiseases.contains(disease.toLowerCase())) {
      return '';
    }

    // Calculate total of only the 4 diseases (excluding healthy/unknown)
    int totalDiseaseDetections = 0;
    for (final d in mainDiseases) {
      totalDiseaseDetections += diseaseCounts[d.toLowerCase()] ?? 0;
    }

    if (totalDiseaseDetections == 0) return '';

    final diseaseCount = diseaseCounts[disease] ?? 0;
    final percentage = (diseaseCount / totalDiseaseDetections * 100);

    if (percentage >= 80) {
      return 'High';
    } else if (percentage >= 60) {
      return 'Medium';
    } else {
      return 'Low';
    }
  }

  Widget _buildSeverityBadge(String disease, Map<String, int> diseaseCounts) {
    final severity = _getSeverityLevel(disease, diseaseCounts);
    if (severity.isEmpty) return const SizedBox.shrink();

    Color severityColor;
    switch (severity) {
      case 'High':
        severityColor = Colors.red;
        break;
      case 'Medium':
        severityColor = Colors.orange;
        break;
      case 'Low':
        severityColor = Colors.green;
        break;
      default:
        severityColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: severityColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: severityColor.withOpacity(0.3), width: 1),
      ),
      child: Text(
        severity,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: severityColor,
        ),
      ),
    );
  }

  // Special cases for diseases not in Firestore (only for healthy, tip_burn, and unknown)
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

  void _showDiseaseRecommendations(BuildContext context, String disease) async {
    final label = disease.toLowerCase();

    // Check if it's a special case (healthy or tip_burn) that's not in Firestore
    Map<String, dynamic>? info;
    if (specialDiseaseInfo.containsKey(label)) {
      info = specialDiseaseInfo[label];
    } else {
      // If disease info is not loaded yet, try to load it
      if (_diseaseInfo.isEmpty) {
        await _loadDiseaseInfo();
      }

      // If still empty after loading, try to load from cache directly
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
            print(
              'DEBUG: Loaded disease info from cache in recommendations: ${_diseaseInfo.keys.toList()}',
            );
          }
        } catch (e) {
          print('DEBUG: Could not load from cache: $e');
        }
      }

      // Try to get from Firestore data with multiple matching strategies
      info = _diseaseInfo[label];

      // If not found, try with formatted label
      if (info == null) {
        final formattedLabel = _formatLabel(label).toLowerCase();
        info = _diseaseInfo[formattedLabel];
      }

      // If still not found, try common variations
      if (info == null) {
        // Handle common naming variations
        String normalizedLabel =
            label
                .replaceAll('_', ' ') // Replace underscores with spaces
                .replaceAll(
                  'blackspot',
                  'black spot',
                ) // Fix blackspot -> black spot
                .toLowerCase();
        info = _diseaseInfo[normalizedLabel];
      }

      // Special handling for bacterial black spot typo
      if (info == null &&
          (label.contains('bacterial') || label.contains('backterial'))) {
        // Try to match with the correct database key
        if (label.contains('bacterial') || label.contains('backterial')) {
          info = _diseaseInfo['Bacterial black spot'];
        }
      }

      // If still not found, try partial matching
      if (info == null) {
        for (String key in _diseaseInfo.keys) {
          final normalizedKey = key
              .toLowerCase()
              .replaceAll('_', ' ')
              .replaceAll('blackspot', 'black spot');
          final normalizedLabel = label
              .replaceAll('_', ' ')
              .replaceAll('blackspot', 'black spot')
              .replaceAll('backterial', 'bacterial'); // Fix typo

          if (normalizedKey.contains(normalizedLabel) ||
              normalizedLabel.contains(normalizedKey) ||
              key.toLowerCase().contains(label) ||
              label.contains(key.toLowerCase())) {
            info = _diseaseInfo[key];
            break;
          }
        }
      }
    }

    // Debug print to help identify the issue
    print('DEBUG: Looking for disease: "$disease" (label: "$label")');
    print(
      'DEBUG: Available specialDiseaseInfo keys: ${specialDiseaseInfo.keys}',
    );
    print('DEBUG: Available _diseaseInfo keys: ${_diseaseInfo.keys}');
    print('DEBUG: _diseaseInfo length: ${_diseaseInfo.length}');
    print('DEBUG: Found info: ${info != null}');

    // Show what disease names are actually being detected
    print(
      'DEBUG: All detected disease labels: ${widget.allResults.values.expand((results) => results.map((r) => r.label)).toSet()}',
    );

    // Special debug for bacterial black spot
    if (label.contains('bacterial') ||
        label.contains('black') ||
        label.contains('backterial')) {
      print('DEBUG: BACTERIAL BLACK SPOT DEBUG:');
      print('  - Original disease: "$disease"');
      print('  - Label: "$label"');
      print(
        '  - Looking for keys containing "bacterial": ${_diseaseInfo.keys.where((k) => k.toLowerCase().contains('bacterial')).toList()}',
      );
      print(
        '  - Looking for keys containing "backterial": ${_diseaseInfo.keys.where((k) => k.toLowerCase().contains('backterial')).toList()}',
      );
      print(
        '  - Looking for keys containing "black": ${_diseaseInfo.keys.where((k) => k.toLowerCase().contains('black')).toList()}',
      );
      print('  - All available keys: ${_diseaseInfo.keys.toList()}');
    }

    // Print all disease info for debugging
    if (_diseaseInfo.isNotEmpty) {
      print('DEBUG: _diseaseInfo contents:');
      _diseaseInfo.forEach((key, value) {
        print('  - "$key": ${value.keys}');
      });
    } else {
      print('DEBUG: _diseaseInfo is empty!');
    }

    final isHealthy = label == 'healthy' || label == 'tip_burn';
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
                          Text(
                            tr('symptoms'),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...(info['symptoms'] as List<String>).map<Widget>(
                            (s) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                '• $s',
                                style: const TextStyle(fontSize: 15),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            tr('treatment_and_recommendations'),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...(info['treatments'] as List<String>).map<Widget>(
                            (t) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                '• $t',
                                style: const TextStyle(fontSize: 15),
                              ),
                            ),
                          ),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.orange[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.orange[200]!),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      color: Colors.orange[700],
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      tr('information_not_available'),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange[700],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  tr(
                                    'detailed_info_not_available_for',
                                    namedArgs: {
                                      'disease': _formatLabel(disease),
                                    },
                                  ),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.orange[600],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  tr('contact_expert_for_more_info'),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.orange[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
          ),
    );
  }

  void _showDiseaseCards(
    BuildContext context,
    List<MapEntry<String, int>> diseases,
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
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
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
                ...diseases.map((entry) {
                  final disease = entry.key;
                  final diseaseName = _formatLabel(disease);
                  return _buildDiseaseNameCard(diseaseName, disease);
                }).toList(),
              ],
            ),
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
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
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

  void _showAllDiseaseRecommendations(
    BuildContext context,
    List<MapEntry<String, int>> diseases,
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
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
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
                  final diseaseEntry = entry.value;
                  final disease = diseaseEntry.key;
                  final color =
                      DetectionPainter.diseaseColors[disease] ?? Colors.grey;
                  final label = disease.toLowerCase();

                  // Get disease info
                  Map<String, dynamic>? info;
                  if (specialDiseaseInfo.containsKey(label)) {
                    info = specialDiseaseInfo[label];
                  } else {
                    info = _diseaseInfo[label];
                    if (info == null) {
                      final formattedLabel = _formatLabel(label).toLowerCase();
                      info = _diseaseInfo[formattedLabel];
                    }
                  }

                  return Container(
                    margin: EdgeInsets.only(bottom: index == diseases.length - 1 ? 0 : 24),
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
                                Icons.warning_rounded,
                                color: color,
                                size: 20,
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
                          ...(info['symptoms'] as List<String>).map<Widget>(
                            (s) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                      style: const TextStyle(fontSize: 14),
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
                          ...(info['treatments'] as List<String>).map<Widget>(
                            (t) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                      style: const TextStyle(fontSize: 14),
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
                              border: Border.all(color: Colors.orange[200]!),
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
                                    tr('detailed_info_not_available_for',
                                        namedArgs: {
                                          'disease': _formatLabel(disease),
                                        }),
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
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                tr('healthy_leaves'),
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
                        const SizedBox(height: 40),
                        Center(
                          child: Text(
                            tr('not_applicable'),
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            tr('no_additional_info_healthy_leaves'),
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ),
    );
  }

  void _showUnknownStatus(BuildContext context) {
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
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.help_outline,
                              color: Colors.grey,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                tr('unknown'),
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
                        const SizedBox(height: 40),
                        Center(
                          child: Text(
                            tr('not_applicable'),
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            tr('no_additional_info_unknown'),
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ),
    );
  }

  // Widget _buildStatusSection(String title, List<String> items) {
  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       Text(
  //         title,
  //         style: const TextStyle(
  //           fontSize: 16,
  //           fontWeight: FontWeight.bold,
  //           color: Colors.green,
  //         ),
  //       ),
  //       const SizedBox(height: 8),
  //       ...items.map(
  //         (item) => Padding(
  //           padding: const EdgeInsets.only(bottom: 8),
  //           child: Row(
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: [
  //               const Icon(
  //                 Icons.check_circle_outline,
  //                 size: 20,
  //                 color: Colors.green,
  //               ),
  //               const SizedBox(width: 8),
  //               Expanded(
  //                 child: Text(item, style: const TextStyle(fontSize: 14)),
  //               ),
  //             ],
  //           ),
  //         ),
  //       ),
  //     ],
  //   );
  // }

  Widget _buildImageGrid() {
    if (showBoundingBoxes && imageSizes.isEmpty) {
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
          onTap: () => _showImageCarousel(index),
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
                  if (showBoundingBoxes &&
                      results.isNotEmpty &&
                      imageSizes.isNotEmpty)
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

  void _showImageCarousel(int initialIndex) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder:
          (context) => _ImageCarouselViewer(
            imagePaths: widget.imagePaths,
            allResults: widget.allResults,
            imageSizes: imageSizes,
            initialIndex: initialIndex,
            showBoundingBoxes: showBoundingBoxes,
          ),
    );
  }

  // Add this method to handle 'Add to Tracking' logic
  Future<void> _addToTracking() async {
    print('DEBUG: _addToTracking called');
    setState(() {
      _isSubmitting = true;
    });
    _showSendingDialog(context, tr('adding_to_tracking'));
    try {
      // final _userProfile = UserProfile();
      final user = FirebaseAuth.instance.currentUser;
      final userId = user?.uid ?? 'unknown';
      final box = await Hive.openBox('trackingBox');
      final List sessions = box.get('scans', defaultValue: []);
      final now = DateTime.now().toIso8601String();
      final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
      final List<Map<String, dynamic>> images = [];
      // --- Upload images to Firebase Storage and get URLs ---
      final List<Map<String, String>> uploadedImages2 = [];
      for (int i = 0; i < widget.imagePaths.length; i++) {
        final originalFile = File(widget.imagePaths[i]);
        // Compress only if over 30MB; keep dimensions unchanged
        final file = await _compressIfOver30Mb(originalFile);
        final fileName =
            '${userId}_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        final storagePath = 'leaf/$fileName';
        final ref = FirebaseStorage.instance.ref().child(storagePath);
        final detectedMime = lookupMimeType(file.path) ?? 'image/jpeg';
        await ref.putFile(file, SettableMetadata(contentType: detectedMime));
        final downloadUrl = await ref.getDownloadURL();
        uploadedImages2.add({'url': downloadUrl, 'path': storagePath});
      }
      // Build diseaseSummary from detection results to power Recent Activity title
      // Count each unique disease type as 1 per report (not per detection)
      final Set<String> uniqueDiseases = {};
      widget.allResults.values.forEach((results) {
        for (var result in results) {
          final label = result.label.toLowerCase();
          if (label != 'tip_burn' && label != 'unknown') {
            uniqueDiseases.add(result.label);
          }
        }
      });
      final diseaseCounts =
          uniqueDiseases.map((disease) {
            return {
              'name': _formatLabel(disease),
              'label': disease,
              'count': 1, // Each disease type counts as 1 per report
            };
          }).toList();
      for (int i = 0; i < widget.imagePaths.length; i++) {
        final results = widget.allResults[i] ?? [];
        List<Map<String, dynamic>> resultList = [];
        if (results.isNotEmpty) {
          for (var result in results) {
            resultList.add({
              'disease': result.label,
              'confidence': result.confidence,
            });
          }
        } else {
          resultList.add({'disease': 'Unknown', 'confidence': null});
        }
        images.add({
          'imageUrl': uploadedImages2[i]['url'],
          'storagePath': uploadedImages2[i]['path'],
          'results': resultList,
        });
      }
      sessions.add({
        'sessionId': sessionId,
        'date': now,
        'images': images,
        'source': 'tracking',
      });
      await box.put('scans', sessions);
      print('DEBUG: sessions after add: ' + sessions.toString());
      // --- Upload to Firestore tracking collection ---
      await FirebaseFirestore.instance
          .collection('tracking')
          .doc(sessionId)
          .set({
            'sessionId': sessionId,
            'date': now,
            'images': images,
            'source': 'tracking',
            'userId': userId,
          });
      // --- End upload to Firestore ---
      // --- Also write to scan_requests so it appears under Recent Activity ---
      try {
        final userBox = await Hive.openBox('userBox');
        final userProfile = userBox.get('userProfile');
        final fullName = userProfile?['fullName'] ?? 'Unknown';
        await FirebaseFirestore.instance
            .collection('scan_requests')
            .doc(sessionId)
            .set({
              'id': sessionId,
              'userId': userId,
              'userName': fullName,
              'status': 'tracking',
              'submittedAt': now,
              'images': images,
              'diseaseSummary': diseaseCounts,
            });
      } catch (e) {
        // Non-fatal: tracking saved; recent activity write failed
        print('WARN: Failed to write tracking entry to scan_requests: $e');
      }
      // --- End recent activity write ---
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Dismiss dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('analysis_added_to_tracking')),
            backgroundColor: Colors.blue,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 70, left: 16, right: 16),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Dismiss dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr('error_adding_to_tracking', namedArgs: {'error': '$e'}),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 70, left: 16, right: 16),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final diseaseCounts = _getOverallDiseaseCount();
    // Kick off image size loading only when needed (first build), avoid blocking transition
    if (showBoundingBoxes && imageSizes.isEmpty) {
      // Defer loading sizes to next microtask to avoid layout jank
      Future.microtask(() => _loadImageSizes());
    }

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
        title: Text(tr('analysis_summary')),
        centerTitle: true,
        backgroundColor: Colors.green,
        elevation: 0,
        actions: [],
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
                                    tr('total_images'),
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
                                    tr('diseases_found'),
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _getDistinctDiseaseCountLabel(diseaseCounts),
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
                          tr('analyzed_images'),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Toggle button for bounding boxes
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(tr('show_bounding_boxes')),
                            Switch(
                              value: showBoundingBoxes,
                              onChanged: (value) async {
                                setState(() {
                                  showBoundingBoxes = value;
                                });
                                // persist same as detail page for consistency
                                final box = await Hive.openBox('userBox');
                                await box.put(
                                  'showBoundingBoxes',
                                  showBoundingBoxes,
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildImageGrid(),
                      ],
                    ),
                  ),
                  // Healthy Leaves Section
                  if (_getHealthyCount() > 0) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        tr('healthy_leaves'),
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
                      child: _buildHealthySection(),
                    ),
                    const SizedBox(height: 16),
                  ],
                  // Disease Summary Section
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      tr('disease_summary'),
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
                    child:
                        sortedDiseases.isEmpty
                            ? _buildNoDiseasesMessage()
                            : _buildCombinedDiseaseCard(sortedDiseases),
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
                  height: 50,
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _hasWarnings() ? null : _sendForExternalReview,
                    icon: const Icon(Icons.send),
                    label: Text(tr('send_for_review')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _hasWarnings() ? Colors.grey : Colors.green,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey[400],
                      disabledForegroundColor: Colors.white70,
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

class _ImageCarouselViewer extends StatefulWidget {
  final List<String> imagePaths;
  final Map<int, List<DetectionResult>> allResults;
  final Map<String, Size> imageSizes;
  final int initialIndex;
  final bool showBoundingBoxes;

  const _ImageCarouselViewer({
    required this.imagePaths,
    required this.allResults,
    required this.imageSizes,
    required this.initialIndex,
    required this.showBoundingBoxes,
  });

  @override
  State<_ImageCarouselViewer> createState() => _ImageCarouselViewerState();
}

class _ImageCarouselViewerState extends State<_ImageCarouselViewer> {
  late PageController _pageController;
  late int _currentIndex;
  bool _showControls = true;
  final Map<int, TransformationController> _transformationControllers = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    // Initialize transformation controllers for all images
    for (int i = 0; i < widget.imagePaths.length; i++) {
      _transformationControllers[i] = TransformationController();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    // Dispose all transformation controllers
    for (var controller in _transformationControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
  }


  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: EdgeInsets.zero,
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          // Full screen image carousel
          PageView.builder(
              controller: _pageController,
              physics: const PageScrollPhysics(),
              onPageChanged: (index) {
                // Reset zoom when changing pages
                final oldController = _transformationControllers[_currentIndex];
                if (oldController != null) {
                  oldController.value = Matrix4.identity();
                }
                setState(() {
                  _currentIndex = index;
                });
              },
              itemCount: widget.imagePaths.length,
              itemBuilder: (context, index) {
                final imagePath = widget.imagePaths[index];
                final results = widget.allResults[index] ?? [];
                final imageSize =
                    widget.imageSizes[imagePath] ?? const Size(1, 1);

                return Stack(
                  children: [
                    // Image layer - always centered
                    Center(
                      child: InteractiveViewer(
                        transformationController: _transformationControllers[index],
                        minScale: 0.5,
                        maxScale: 5.0,
                        panEnabled: true,
                        scaleEnabled: true,
                        child: Image.file(
                          File(imagePath),
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[800],
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      color: Colors.white,
                                      size: 64,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      tr('error_loading_image'),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    // Bounding boxes overlay - positioned absolutely (non-interactive)
                    if (widget.showBoundingBoxes &&
                        results.isNotEmpty &&
                        widget.imageSizes.isNotEmpty)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: LayoutBuilder(
                          builder: (context, constraints) {
                            // Calculate the actual displayed image size and position
                            final screenSize = MediaQuery.of(context).size;
                            final imageAspect =
                                imageSize.width / imageSize.height;
                            final screenAspect =
                                screenSize.width / screenSize.height;

                            Size displayedImageSize;
                            Offset displayedImageOffset;

                            if (screenAspect > imageAspect) {
                              // Screen is wider than image - image fits height
                              displayedImageSize = Size(
                                screenSize.height * imageAspect,
                                screenSize.height,
                              );
                              displayedImageOffset = Offset(
                                (screenSize.width - displayedImageSize.width) /
                                    2,
                                0,
                              );
                            } else {
                              // Screen is taller than image - image fits width
                              displayedImageSize = Size(
                                screenSize.width,
                                screenSize.width / imageAspect,
                              );
                              displayedImageOffset = Offset(
                                0,
                                (screenSize.height -
                                        displayedImageSize.height) /
                                    2,
                              );
                            }

                            return CustomPaint(
                              painter: DetectionPainter(
                                results: results,
                                originalImageSize: imageSize,
                                displayedImageSize: displayedImageSize,
                                displayedImageOffset: displayedImageOffset,
                              ),
                              size: screenSize,
                            );
                          },
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          // Controls overlay
          if (_showControls) ...[
            // Top controls
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                  ),
                ),
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 16,
                  left: 16,
                  right: 16,
                  bottom: 16,
                ),
                child: Row(
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_currentIndex + 1} / ${widget.imagePaths.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Detection count
                    if (widget.allResults[_currentIndex]?.isNotEmpty == true)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.visibility,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${widget.allResults[_currentIndex]!.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
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
            // Bottom controls with page indicators
            if (widget.imagePaths.length > 1)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  padding: EdgeInsets.only(
                    top: 16,
                    left: 16,
                    right: 16,
                    bottom: MediaQuery.of(context).padding.bottom + 16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      widget.imagePaths.length,
                      (index) => GestureDetector(
                        onTap: () {
                          _pageController.animateToPage(
                            index,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _currentIndex == index ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color:
                                _currentIndex == index
                                    ? Colors.white
                                    : Colors.white.withOpacity(0.5),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
