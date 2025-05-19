import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class ReviewService {
  static const String _fileName = 'pending_reviews.json';

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

  Future<void> updateReview({
    required String reviewId,
    required String status,
    required Map<String, dynamic> expertReview,
  }) async {
    try {
      final file = await _localFile;
      final List<Map<String, dynamic>> reviews = await getPendingReviews();

      final index = reviews.indexWhere((review) => review['id'] == reviewId);
      if (index != -1) {
        reviews[index]['status'] = status;
        reviews[index]['expertReview'] = expertReview;
        reviews[index]['reviewedAt'] = DateTime.now().toIso8601String();
        await file.writeAsString(json.encode(reviews));
      }
    } catch (e) {
      print('Error updating review: $e');
      rethrow;
    }
  }
}
