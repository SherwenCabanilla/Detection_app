import 'package:uuid/uuid.dart';
import 'package:hive/hive.dart';

class ReviewManager {
  static final ReviewManager _instance = ReviewManager._internal();
  factory ReviewManager() => _instance;
  ReviewManager._internal() {
    _loadFromHive();
  }

  final List<Map<String, dynamic>> _pendingReviews = [
    // Pending review sample
    {
      'id': 'review_001',
      'userId': 'user_001',
      'userName': 'John Doe',
      'status': 'pending',
      'submittedAt': '2024-06-20T10:00:00',
      'images': [
        {'path': 'assets/sample1.jpg', 'detections': []},
      ],
      'diseaseSummary': [
        {'disease': 'Anthracnose', 'averageConfidence': 0.92},
      ],
      'notes': 'Leaf spots observed.',
    },
    // Completed review sample
    {
      'id': 'review_002',
      'userId': 'user_002',
      'userName': 'Jane Smith',
      'status': 'reviewed',
      'submittedAt': '2024-06-19T14:30:00',
      'images': [
        {'path': 'assets/sample2.jpg', 'detections': []},
      ],
      'diseaseSummary': [
        {'disease': 'Powdery Mildew', 'averageConfidence': 0.85},
      ],
      'notes': 'White powdery spots.',
      'expertReview': {
        'comment': 'Confirmed Powdery Mildew. Recommend fungicide treatment.',
        'severityAssessment': {
          'level': 'medium',
          'confidence': 0.85,
          'notes': 'Expert assessment based on image analysis',
        },
        'treatmentPlan': {
          'recommendations': [
            {
              'treatment': 'Apply sulfur-based fungicide',
              'dosage': '2g/L',
              'frequency': 'Every 7 days',
              'precautions': 'Avoid during rain',
            },
          ],
          'preventiveMeasures': [
            'Regular pruning',
            'Proper spacing between plants',
          ],
        },
        'reviewedAt': '2024-06-20T12:00:00',
      },
    },
  ];
  final _uuid = const Uuid();
  final String _boxName = 'reviews';

  Future<void> _loadFromHive() async {
    final box = Hive.box(_boxName);
    _pendingReviews.clear();
    for (var review in box.values) {
      _pendingReviews.add(Map<String, dynamic>.from(review));
    }
  }

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
    final box = Hive.box(_boxName);
    await box.put(review['id'], review);
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
      final box = Hive.box(_boxName);
      await box.put(_pendingReviews[index]['id'], _pendingReviews[index]);
    }
  }

  Future<void> clearReviews() async {
    _pendingReviews.clear();
    final box = Hive.box(_boxName);
    await box.clear();
  }

  List<Map<String, dynamic>> get pendingReviews => _pendingReviews;
}
