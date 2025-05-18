import 'package:flutter/material.dart';

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
                    child: Image.asset(
                      request['images'][0]['path'],
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
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

class UserRequestDetail extends StatelessWidget {
  final Map<String, dynamic> request;
  const UserRequestDetail({Key? key, required this.request}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final mainDisease = request['diseaseSummary'][0]['name'];
    final status = request['status'];
    final submittedAt = request['submittedAt'];
    final reviewedAt = request['reviewedAt'];
    final expertReview = request['expertReview'];
    final expertName = request['expertName'];
    final isCompleted = status == 'completed';
    final images = request['images'] as List<dynamic>;

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
                      if (isCompleted && reviewedAt != null) ...[
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
                            childAspectRatio: 1,
                          ),
                      itemCount: images.length,
                      itemBuilder: (context, idx) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            images[idx]['path'],
                            fit: BoxFit.cover,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Disease Summary',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ...request['diseaseSummary'].map<Widget>((disease) {
                    final color = _getDiseaseColor(disease['name']);
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
                                      Icons.local_florist,
                                      size: 16,
                                      color: color,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    disease['name'],
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (disease['count'] != null)
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
                                      '${disease['count']} found',
                                      style: TextStyle(
                                        color: color,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (disease['averageConfidence'] != null)
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Average Confidence',
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
                                            value: disease['averageConfidence'],
                                            backgroundColor: color.withOpacity(
                                              0.1,
                                            ),
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
                                    '${(disease['averageConfidence'] * 100).toStringAsFixed(1)}%',
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
                          expertName ?? 'Expert',
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
                                    expertReview['severityAssessment']['level'],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  expertReview['severityAssessment']['level']
                                      .toString()
                                      .toUpperCase(),
                                  style: TextStyle(
                                    color: _getSeverityColor(
                                      expertReview['severityAssessment']['level'],
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
                              ...expertReview['treatmentPlan']['recommendations'].map<
                                Widget
                              >((treatment) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                              }).toList(),
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
                                    expertReview['treatmentPlan']['preventiveMeasures']
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

  Color _getDiseaseColor(String disease) {
    switch (disease.toLowerCase()) {
      case 'anthracnose':
        return Colors.orange;
      case 'gall midge':
        return Colors.purple;
      case 'healthy':
        return const Color.fromARGB(255, 2, 119, 252);
      case 'powdery mildew':
        return const Color.fromARGB(255, 9, 46, 2);
      case 'red rust':
        return Colors.red;
      default:
        return Colors.grey;
    }
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
    final pending = _filterRequests(
      userRequests.where((r) => r['status'] == 'pending_review').toList(),
    );
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
