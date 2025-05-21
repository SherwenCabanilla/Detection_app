import 'package:flutter/material.dart';
import '../shared/review_manager.dart';
import 'dart:io';

final List<Map<String, dynamic>> userRequests = [
  {
    'requestId': 'REQ_001',
    'userId': 'USER_001',
    'userName': 'Maria Santos',
    'submittedAt': '2024-06-10 09:15',
    'status': 'completed',
    'images': [
      {
        'path': 'assets/diseases/backterial_blackspot1.jpg',
        'detections': [
          {
            'label': 'Bacterial Blackspot',
            'confidence': 0.95,
            'boundingBox': {
              'left': 0.1,
              'top': 0.1,
              'right': 0.3,
              'bottom': 0.3,
            },
          },
          {
            'label': 'Healthy',
            'confidence': 0.90,
            'boundingBox': {
              'left': 0.4,
              'top': 0.4,
              'right': 0.6,
              'bottom': 0.6,
            },
          },
        ],
      },
      {
        'path': 'assets/diseases/healthy1.jpg',
        'detections': [
          {
            'label': 'Bacterial Blackspot',
            'confidence': 0.88,
            'boundingBox': {
              'left': 0.2,
              'top': 0.2,
              'right': 0.4,
              'bottom': 0.4,
            },
          },
          {
            'label': 'Healthy',
            'confidence': 0.85,
            'boundingBox': {
              'left': 0.5,
              'top': 0.5,
              'right': 0.7,
              'bottom': 0.7,
            },
          },
        ],
      },
      {
        'path': 'assets/diseases/healthy2.jpg',
        'detections': [
          {
            'label': 'Bacterial Blackspot',
            'confidence': 0.92,
            'boundingBox': {
              'left': 0.3,
              'top': 0.3,
              'right': 0.5,
              'bottom': 0.5,
            },
          },
        ],
      },
      {
        'path': 'assets/diseases/backterial_blackspot.jpg',
        'detections': [
          {
            'label': 'Bacterial Blackspot',
            'confidence': 0.90,
            'boundingBox': {
              'left': 0.4,
              'top': 0.4,
              'right': 0.6,
              'bottom': 0.6,
            },
          },
        ],
      },
      {
        'path': 'assets/diseases/healthy3.jpg',
        'detections': [
          {
            'label': 'Bacterial Blackspot',
            'confidence': 0.89,
            'boundingBox': {
              'left': 0.5,
              'top': 0.5,
              'right': 0.7,
              'bottom': 0.7,
            },
          },
        ],
      },
    ],
    'diseaseSummary': [
      {
        'name': 'Bacterial Blackspot',
        'count': 2,
        'averageConfidence': 0.50, // 2 out of 4 leaves = 50%
        'severity': 'high',
      },
      {
        'name': 'Healthy',
        'count': 2,
        'averageConfidence': 0.50, // 2 out of 4 leaves = 50%
        'severity': 'low',
      },
    ],
    'expertReview': {
      'expertId': 'EXP_001',
      'expertName': 'Dr. Jose Garcia',
      'reviewedAt': '2024-06-10 11:05',
      'comment':
          'Severe bacterial blackspot infection detected. Immediate treatment required.',
      'severityAssessment': {
        'level': 'high',
        'confidence': 0.50, // Updated to match the percentage
        'notes': 'Expert assessment based on image analysis',
      },
      'treatmentPlan': {
        'recommendations': [
          {
            'treatment': 'Copper-based fungicide treatment',
            'dosage': '2-3 ml per liter of water',
            'frequency': 'Every 7-10 days',
            'precautions':
                'Apply early morning or late evening. Avoid application before rain. Wear gloves and mask during application.',
          },
        ],
        'preventiveMeasures': [
          'Regular pruning',
          'Proper spacing between plants',
          'Adequate ventilation',
          'Remove infected leaves promptly',
        ],
      },
    },
  },
  {
    'requestId': 'REQ_002',
    'userId': 'USER_001',
    'userName': 'Maria Santos',
    'submittedAt': '2024-06-10 10:22',
    'status': 'pending_review',
    'images': [
      {
        'path': 'assets/diseases/powdery_mildew1.jpg',
        'detections': [
          {
            'label': 'Powdery Mildew',
            'confidence': 0.75,
            'boundingBox': {
              'left': 0.1,
              'top': 0.1,
              'right': 0.3,
              'bottom': 0.3,
            },
          },
          {
            'label': 'Healthy',
            'confidence': 0.85,
            'boundingBox': {
              'left': 0.4,
              'top': 0.4,
              'right': 0.6,
              'bottom': 0.6,
            },
          },
        ],
      },
      {
        'path': 'assets/diseases/powdery_mildew2.jpg',
        'detections': [
          {
            'label': 'Powdery Mildew',
            'confidence': 0.68,
            'boundingBox': {
              'left': 0.6,
              'top': 0.3,
              'right': 0.5,
              'bottom': 0.5,
            },
          },
          {
            'label': 'Healthy',
            'confidence': 0.92,
            'boundingBox': {
              'left': 0.7,
              'top': 0.7,
              'right': 0.9,
              'bottom': 0.9,
            },
          },
        ],
      },
      {
        'path': 'assets/diseases/powdery_mildew3.jpg',
        'detections': [
          {
            'label': 'Powdery Mildew',
            'confidence': 0.72,
            'boundingBox': {
              'left': 0.3,
              'top': 0.2,
              'right': 0.4,
              'bottom': 0.4,
            },
          },
          {
            'label': 'Healthy',
            'confidence': 0.88,
            'boundingBox': {
              'left': 0.5,
              'top': 0.5,
              'right': 0.7,
              'bottom': 0.7,
            },
          },
        ],
      },
    ],
    'diseaseSummary': [
      {
        'name': 'Powdery Mildew',
        'count': 3,
        'averageConfidence': 0.50, // 3 out of 6 leaves = 50%
        'severity': 'medium',
      },
      {
        'name': 'Healthy',
        'count': 3,
        'averageConfidence': 0.50, // 3 out of 6 leaves = 50%
        'severity': 'low',
      },
    ],
    'expertReview': null,
  },
  {
    'requestId': 'REQ_003',
    'userId': 'USER_001',
    'userName': 'Maria Santos',
    'submittedAt': '2024-06-11 08:00',
    'status': 'pending_review',
    'images': [
      {
        'path': 'assets/diseases/anthracnose1.jpg',
        'detections': [
          {
            'label': 'Anthracnose',
            'confidence': 0.82,
            'boundingBox': {
              'left': 0.1,
              'top': 0.1,
              'right': 0.3,
              'bottom': 0.3,
            },
          },
        ],
      },
      {
        'path': 'assets/diseases/anthracnose2.jpg',
        'detections': [
          {
            'label': 'Anthracnose',
            'confidence': 0.78,
            'boundingBox': {
              'left': 0.2,
              'top': 0.2,
              'right': 0.4,
              'bottom': 0.4,
            },
          },
        ],
      },
    ],
    'diseaseSummary': [
      {
        'name': 'Anthracnose',
        'count': 2,
        'averageConfidence': 0.82,
        'severity': 'low',
      },
    ],
    'expertReview': null,
  },
];

class UserRequestList extends StatefulWidget {
  final List<Map<String, dynamic>> requests;
  const UserRequestList({Key? key, required this.requests}) : super(key: key);

  @override
  State<UserRequestList> createState() => _UserRequestListState();
}

class _UserRequestListState extends State<UserRequestList> {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: widget.requests.length,
      itemBuilder: (context, index) {
        final request = widget.requests[index];
        return _buildRequestCard(request);
      },
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final mainDisease = request['diseaseSummary'][0]['name'];
    final status = request['status'];
    final submittedAt = request['submittedAt'];
    final reviewedAt = request['reviewedAt'];
    final isCompleted = status == 'completed';
    final totalImages = request['images']?.length ?? 0;
    final totalDetections = request['diseaseSummary']?.length ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UserRequestDetail(request: request),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _buildImageWidget(
                      request['images'][0]['path'],
                      width: 80,
                      height: 80,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$mainDisease Detection',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          submittedAt,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color:
                          status == 'completed'
                              ? Colors.green.withOpacity(0.1)
                              : Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        color:
                            status == 'completed'
                                ? Colors.green
                                : Colors.orange,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      'Images',
                      totalImages.toString(),
                      Icons.image,
                    ),
                  ),
                  Container(width: 1, height: 40, color: Colors.grey[300]),
                  Expanded(
                    child: _buildStatItem(
                      'Detections',
                      totalDetections.toString(),
                      Icons.search,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Icon(icon, color: Colors.grey[600], size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        ],
      ),
    );
  }
}

class UserRequestDetail extends StatefulWidget {
  final Map<String, dynamic> request;
  const UserRequestDetail({Key? key, required this.request}) : super(key: key);

  @override
  _UserRequestDetailState createState() => _UserRequestDetailState();
}

class _UserRequestDetailState extends State<UserRequestDetail> {
  bool _showBoundingBoxes = true;

  @override
  Widget build(BuildContext context) {
    final diseaseSummary = (widget.request['diseaseSummary'] as List?) ?? [];
    final mainDisease =
        (diseaseSummary.isNotEmpty && diseaseSummary[0]['name'] != null)
            ? diseaseSummary[0]['name']
            : 'Unknown';
    final status = widget.request['status'] ?? '';
    final submittedAt = widget.request['submittedAt'] ?? '';
    final reviewedAt = widget.request['reviewedAt'] ?? '';
    final expertReview = widget.request['expertReview'];
    final expertName = widget.request['expertName'] ?? '';
    final isCompleted = status == 'completed';
    final images = (widget.request['images'] as List?) ?? [];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: const Text(
          'Request Details',
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
                              'Your Request',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.green,
                              ),
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
                            submittedAt,
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
                              reviewedAt,
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
            // Add bounding box toggle like expert view
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text('Show Bounding Boxes'),
                Switch(
                  value: _showBoundingBoxes,
                  onChanged: (value) {
                    setState(() {
                      _showBoundingBoxes = value;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
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
                    const Text(
                      'Submitted Images',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
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
                        final imgPath = img['path'] ?? '';
                        final detections = (img['detections'] as List?) ?? [];
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
                                                imgPath,
                                                width: imageWidth,
                                                height: imageHeight,
                                                fit: BoxFit.contain,
                                              ),
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
                                  imgPath,
                                  fit: BoxFit.cover,
                                ),
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
                                        ? '${detections.length} Detection${detections.length > 1 ? 's' : ''}'
                                        : 'No Detections',
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
            // Disease Summary
            Padding(
              padding: const EdgeInsets.all(16),
              child: Builder(
                builder: (context) {
                  final mergedSummary = _mergeDiseaseSummary(diseaseSummary);
                  final totalLeaves = mergedSummary.fold<int>(
                    0,
                    (sum, d) => sum + (d['count'] as int? ?? 0),
                  );
                  final sortedSummary = [...mergedSummary]..sort((a, b) {
                    final percA =
                        totalLeaves == 0
                            ? 0.0
                            : (a['count'] as int? ?? 0) / totalLeaves;
                    final percB =
                        totalLeaves == 0
                            ? 0.0
                            : (b['count'] as int? ?? 0) / totalLeaves;
                    return percB.compareTo(percA);
                  });
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Disease Summary',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...sortedSummary.map<Widget>((disease) {
                        final diseaseName =
                            (disease['disease'] ?? disease['name'] ?? 'Unknown')
                                .toString();
                        final count = disease['count'] ?? 0;
                        final percentage =
                            totalLeaves == 0 ? 0.0 : count / totalLeaves;
                        final color = _getExpertDiseaseColor(diseaseName);
                        final isHealthy =
                            diseaseName.toLowerCase() == 'healthy';
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
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
                                          isHealthy
                                              ? Icons.check_circle
                                              : Icons.local_florist,
                                          size: 16,
                                          color: color,
                                        ),
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
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
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            child: LinearProgressIndicator(
                                              value: percentage,
                                              backgroundColor: color
                                                  .withOpacity(0.1),
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                    color,
                                                  ),
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
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  );
                },
              ),
            ),
            // Expert Review Section
            if (isCompleted && expertReview != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person, color: Colors.green, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          expertName.isNotEmpty ? expertName : 'Expert',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.green,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Expert Review',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Severity Assessment
                    if (expertReview['severityAssessment'] != null)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Severity Assessment',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.warning,
                                    color: _getSeverityColor(
                                      expertReview['severityAssessment']['level'] ??
                                          'low',
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    (expertReview['severityAssessment']['level'] ??
                                            'low')
                                        .toString()
                                        .toUpperCase(),
                                    style: TextStyle(
                                      color: _getSeverityColor(
                                        expertReview['severityAssessment']['level'] ??
                                            'low',
                                      ),
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
                    const SizedBox(height: 16),
                    // Treatment Plan
                    if (expertReview['treatmentPlan'] != null)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Treatment Plan',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...((expertReview['treatmentPlan']['recommendations']
                                          as List?) ??
                                      [])
                                  .map<Widget>((treatment) {
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (treatment['treatment'] != null)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 4,
                                            ),
                                            child: Text(
                                              'Treatment: ${treatment['treatment']}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        if (treatment['dosage'] != null)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 4,
                                            ),
                                            child: Text(
                                              'Dosage: ${treatment['dosage']}',
                                            ),
                                          ),
                                        if (treatment['frequency'] != null)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 4,
                                            ),
                                            child: Text(
                                              'Frequency: ${treatment['frequency']}',
                                            ),
                                          ),
                                        if (treatment['precautions'] != null)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 4,
                                            ),
                                            child: Text(
                                              'Precautions: ${treatment['precautions']}',
                                            ),
                                          ),
                                        const SizedBox(height: 8),
                                      ],
                                    );
                                  })
                                  .toList(),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    // Preventive Measures
                    if (expertReview['treatmentPlan']?['preventiveMeasures'] !=
                        null)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Preventive Measures',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children:
                                    ((expertReview['treatmentPlan']['preventiveMeasures']
                                                as List?) ??
                                            [])
                                        .map<Widget>((measure) {
                                          return Chip(
                                            label: Text(measure.toString()),
                                            backgroundColor: Colors.green
                                                .withOpacity(0.1),
                                          );
                                        })
                                        .toList(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    // Expert Comment
                    if (expertReview['comment'] != null)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Expert Comment',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                expertReview['comment'],
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              )
            else if (!isCompleted)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    'Awaiting expert review...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.orange,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
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
        return 'Tip Burn';
      default:
        return label
            .split('_')
            .map((word) => word[0].toUpperCase() + word.substring(1))
            .join(' ');
    }
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
}

class UserRequestTabbedList extends StatefulWidget {
  const UserRequestTabbedList({Key? key}) : super(key: key);

  @override
  State<UserRequestTabbedList> createState() => _UserRequestTabbedListState();
}

class _UserRequestTabbedListState extends State<UserRequestTabbedList>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final ReviewManager _reviewManager = ReviewManager();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _filterRequests(
    List<Map<String, dynamic>> requests,
  ) {
    if (_searchQuery.isEmpty) return requests;

    return requests.where((request) {
      final diseaseName =
          request['diseaseSummary'][0]['name']?.toString().toLowerCase() ?? '';
      final status = request['status']?.toString().toLowerCase() ?? '';
      final submittedAt =
          request['submittedAt']?.toString().toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();

      return diseaseName.contains(query) ||
          status.contains(query) ||
          submittedAt.contains(query);
    }).toList();
  }

  List<Map<String, dynamic>> _getPendingRequests() {
    // Get in-memory pending reviews from ReviewManager
    final pending =
        _reviewManager.pendingReviews
            .where((r) => r['status'] == 'pending')
            .map((review) => _mapReviewToRequest(review))
            .toList();
    return pending;
  }

  Map<String, dynamic> _mapReviewToRequest(Map<String, dynamic> review) {
    // Map ReviewManager review to the format expected by the card UI
    return {
      'requestId': review['id'],
      'userId': review['userId'],
      'userName': review['userName'],
      'submittedAt': review['submittedAt'],
      'status':
          review['status'] == 'pending' ? 'pending_review' : review['status'],
      'images': review['images'],
      'diseaseSummary': review['diseaseSummary'],
      'expertReview': review['expertReview'],
      'notes': review['notes'],
    };
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search',
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              suffixIcon:
                  _searchQuery.isNotEmpty
                      ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                      : null,
              filled: true,
              fillColor: Colors.grey[50],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Try searching for: "Anthracnose", "2024-06-10"',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pending = _filterRequests(_getPendingRequests());
    final completed = _filterRequests(
      userRequests.where((r) => r['status'] == 'completed').toList(),
    );

    return Column(
      children: [
        _buildSearchBar(),
        Container(
          color: Colors.green,
          child: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: const [Tab(text: 'Pending'), Tab(text: 'Completed')],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              pending.isEmpty
                  ? _buildEmptyState(
                    _searchQuery.isNotEmpty
                        ? 'No pending requests found for "$_searchQuery"'
                        : 'No pending requests',
                  )
                  : Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: UserRequestList(requests: pending),
                  ),
              completed.isEmpty
                  ? _buildEmptyState(
                    _searchQuery.isNotEmpty
                        ? 'No completed requests found for "$_searchQuery"'
                        : 'No completed requests',
                  )
                  : Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: UserRequestList(requests: completed),
                  ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchQuery.isNotEmpty ? Icons.search_off : Icons.inbox,
              size: 64,
              color: Colors.green[200],
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(fontSize: 18, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

Widget _buildImageWidget(
  String path, {
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
}) {
  if (_isFilePath(path)) {
    return Image.file(
      File(path),
      width: width,
      height: height,
      fit: fit,
      errorBuilder:
          (context, error, stackTrace) =>
              const Icon(Icons.broken_image, size: 40, color: Colors.grey),
    );
  } else {
    return Image.asset(
      path,
      width: width,
      height: height,
      fit: fit,
      errorBuilder:
          (context, error, stackTrace) =>
              const Icon(Icons.broken_image, size: 40, color: Colors.grey),
    );
  }
}

bool _isFilePath(String path) {
  // Heuristic: treat as file path if it is absolute or starts with /data/ or C:/ or similar
  return path.startsWith('/') || path.contains(':');
}
