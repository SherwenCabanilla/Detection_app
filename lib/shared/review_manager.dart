import 'package:uuid/uuid.dart';

class ReviewManager {
  static final ReviewManager _instance = ReviewManager._internal();
  factory ReviewManager() => _instance;
  ReviewManager._internal();

  final List<Map<String, dynamic>> _pendingReviews = [];
  final _uuid = const Uuid();

  Future<void> submitForReview({
    required String userId,
    required List<String> imagePaths,
    required List<Map<String, dynamic>> detections,
    required List<Map<String, dynamic>> diseaseCounts,
    String? notes,
  }) async {
    final review = {
      'id': _uuid.v4(),
      'userId': userId,
      'userName': userId,
      'status': 'pending',
      'submittedAt': DateTime.now().toIso8601String(),
      'images':
          imagePaths
              .map(
                (path) => {
                  'path': path,
                  'detections':
                      detections.where((d) => d['imagePath'] == path).toList(),
                },
              )
              .toList(),
      'diseaseSummary': diseaseCounts,
      'notes': notes,
    };

    _pendingReviews.insert(0, review);
  }

  Future<void> updateReview({
    required String reviewId,
    required String status,
    Map<String, dynamic>? expertReview,
  }) async {
    final index = _pendingReviews.indexWhere(
      (review) => review['id'] == reviewId,
    );
    if (index != -1) {
      _pendingReviews[index]['status'] = status;
      if (expertReview != null) {
        _pendingReviews[index]['expertReview'] = expertReview;
      }
    }
  }

  void clearReviews() {
    _pendingReviews.clear();
  }

  List<Map<String, dynamic>> get pendingReviews => _pendingReviews;
}
