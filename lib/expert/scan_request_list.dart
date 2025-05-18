import 'package:flutter/material.dart';
import 'scan_request_detail.dart';

class ScanRequestList extends StatefulWidget {
  const ScanRequestList({Key? key}) : super(key: key);

  @override
  State<ScanRequestList> createState() => _ScanRequestListState();
}

class _ScanRequestListState extends State<ScanRequestList>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Dummy data for demonstration
  final List<Map<String, dynamic>> _pendingRequests = [
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
      ],
      'diseaseSummary': [
        {
          'name': 'Powdery Mildew',
          'count': 1,
          'averageConfidence': 0.75,
          'severity': 'medium',
        },
        {
          'name': 'Healthy',
          'count': 1,
          'averageConfidence': 0.85,
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
      ],
      'diseaseSummary': [
        {
          'name': 'Anthracnose',
          'count': 2,
          'averageConfidence': 0.80,
          'severity': 'high',
        },
        {
          'name': 'Healthy',
          'count': 2,
          'averageConfidence': 0.875,
          'severity': 'low',
        },
      ],
      'expertReview': null,
    },
  ];

  final List<Map<String, dynamic>> _completedRequests = [
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
      ],
      'diseaseSummary': [
        {
          'name': 'Bacterial Blackspot',
          'count': 2,
          'averageConfidence': 0.915,
          'severity': 'high',
        },
        {
          'name': 'Healthy',
          'count': 2,
          'averageConfidence': 0.875,
          'severity': 'low',
        },
      ],
      'expertReview': {
        'expertId': 'EXP_001',
        'expertName': 'Dr. Jose Garcia',
        'reviewedAt': '2024-06-10 11:05',
        'comment':
            'Severe bacterial blackspot infection detected. Immediate treatment required. Consider using copper-based bactericides and improve field hygiene.',
        'severityAssessment': {
          'level': 'high',
          'confidence': 0.915,
          'notes': 'Expert assessment based on image analysis',
        },
        'treatmentPlan': {
          'recommendations': [
            {
              'treatment': 'Copper-based bactericide treatment',
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
  ];

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
      final userName = request['userName']?.toString().toLowerCase() ?? '';
      final submittedAt =
          request['submittedAt']?.toString().toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();

      return diseaseName.contains(query) ||
          userName.contains(query) ||
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
              'Try searching for: "Anthracnose", "John", or "2024-06-10"',
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

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final diseaseSummary = request['diseaseSummary'] as List<dynamic>;
    final mainDisease = diseaseSummary.isNotEmpty ? diseaseSummary.first : null;
    final isCompleted = request['status'] == 'completed';
    final userName = request['userName']?.toString() ?? '(No Name)';
    final submittedAt = request['submittedAt'] ?? '';
    String? reviewedAt;
    if (isCompleted) {
      final expertReview = request['expertReview'] as Map<String, dynamic>?;
      reviewedAt = expertReview?['reviewedAt'] as String? ?? '';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () async {
          final updatedRequest = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ScanRequestDetail(request: request),
            ),
          );

          if (updatedRequest != null) {
            setState(() {
              // Find and update the request in the appropriate list
              if (request['status'] == 'pending_review') {
                final index = _pendingRequests.indexOf(request);
                if (index != -1) {
                  _pendingRequests.removeAt(index);
                  _completedRequests.insert(0, updatedRequest);
                }
              } else {
                final index = _completedRequests.indexOf(request);
                if (index != -1) {
                  _completedRequests[index] = updatedRequest;
                }
              }
            });
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 80,
                  height: 80,
                  child: Image.asset(
                    request['images']?[0]?['path'] ?? 'assets/placeholder.jpg',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      mainDisease != null
                          ? '${mainDisease['name']} Detection'
                          : 'Unknown Disease',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.person, size: 16, color: Colors.green),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            userName,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.green,
                            ),
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule,
                          size: 14,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Sent: $submittedAt',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (isCompleted &&
                        reviewedAt != null &&
                        reviewedAt.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              size: 14,
                              color: Colors.green,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Reviewed: $reviewedAt',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.green,
                                ),
                                softWrap: false,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              // Status indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isCompleted ? Colors.green : Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isCompleted ? 'Completed' : 'Pending',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredPending = _filterRequests(_pendingRequests);
    final filteredCompleted = _filterRequests(_completedRequests);

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
              // Pending Requests
              filteredPending.isEmpty
                  ? _buildEmptyState(
                    _searchQuery.isNotEmpty
                        ? 'No pending requests found for "$_searchQuery"'
                        : 'No pending requests',
                  )
                  : ListView.builder(
                    itemCount: filteredPending.length,
                    itemBuilder: (context, index) {
                      return _buildRequestCard(filteredPending[index]);
                    },
                  ),
              // Completed Requests
              filteredCompleted.isEmpty
                  ? _buildEmptyState(
                    _searchQuery.isNotEmpty
                        ? 'No completed requests found for "$_searchQuery"'
                        : 'No completed requests',
                  )
                  : ListView.builder(
                    itemCount: filteredCompleted.length,
                    itemBuilder: (context, index) {
                      return _buildRequestCard(filteredCompleted[index]);
                    },
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
