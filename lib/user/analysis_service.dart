import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class AnalysisService {
  static const String _fileName = 'pending_reviews.json';
  final _uuid = Uuid();

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/$_fileName');
  }

  Future<List<Map<String, dynamic>>> getPendingReviews() async {
    try {
      final file = await _localFile;
      if (!await file.exists()) {
        return [];
      }
      final contents = await file.readAsString();
      return List<Map<String, dynamic>>.from(json.decode(contents));
    } catch (e) {
      print('Error reading pending reviews: $e');
      return [];
    }
  }

  Future<void> submitForReview({
    required String userId,
    required List<String> imagePaths,
    required List<Map<String, dynamic>> detections,
    required Map<String, int> diseaseCounts,
    String? notes,
  }) async {
    try {
      final file = await _localFile;
      final List<Map<String, dynamic>> pendingReviews =
          await getPendingReviews();

      // Verify all images exist
      for (final path in imagePaths) {
        if (!await File(path).exists()) {
          throw Exception('Image not found: $path');
        }
      }

      final review = {
        'id': _uuid.v4(),
        'userId': userId,
        'status': 'pending',
        'submittedAt': DateTime.now().toIso8601String(),
        'images':
            imagePaths
                .map(
                  (path) => {
                    'path': path,
                    'detections':
                        detections
                            .where((d) => d['imagePath'] == path)
                            .toList(),
                  },
                )
                .toList(),
        'diseaseSummary':
            diseaseCounts.entries
                .map((e) => {'disease': e.key, 'count': e.value})
                .toList(),
        'notes': notes,
        'expertReview': null,
      };

      pendingReviews.add(review);
      await file.writeAsString(json.encode(pendingReviews));
    } catch (e) {
      print('Error submitting for review: $e');
      rethrow;
    }
  }

  Future<void> updateReviewStatus(
    String reviewId,
    String status, {
    Map<String, dynamic>? expertReview,
  }) async {
    try {
      final file = await _localFile;
      final List<Map<String, dynamic>> pendingReviews =
          await getPendingReviews();

      final index = pendingReviews.indexWhere(
        (review) => review['id'] == reviewId,
      );
      if (index != -1) {
        pendingReviews[index]['status'] = status;
        if (expertReview != null) {
          pendingReviews[index]['expertReview'] = expertReview;
        }
        await file.writeAsString(json.encode(pendingReviews));
      }
    } catch (e) {
      print('Error updating review status: $e');
      rethrow;
    }
  }

  // Helper method to get image file
  Future<File?> getImageFile(String imagePath) async {
    try {
      final file = File(imagePath);
      if (await file.exists()) {
        return file;
      }
      return null;
    } catch (e) {
      print('Error getting image file: $e');
      return null;
    }
  }
}
