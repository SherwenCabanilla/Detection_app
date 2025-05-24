import 'package:flutter/material.dart';
import 'scan_request_detail.dart';
import '../shared/review_manager.dart';
import 'dart:io';
import '../user/user_request_list.dart';

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
  final ReviewManager _reviewManager = ReviewManager();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    setState(() {
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _pendingRequests {
    return _reviewManager.pendingReviews
        .where((request) => request['status'] == 'pending')
        .toList();
  }

  List<Map<String, dynamic>> get _completedRequests {
    // Combine expert's completed requests with user's completed requests
    final expertCompleted =
        _reviewManager.pendingReviews
            .where((request) => request['status'] == 'reviewed')
            .toList();
    final userCompleted =
        userRequests
            .where((request) => request['status'] == 'completed')
            .toList();
    // Optionally, avoid duplicates by requestId
    final allCompleted = <String, Map<String, dynamic>>{};
    for (final req in expertCompleted) {
      allCompleted[req['requestId'] ?? req['id'] ?? ''] = req;
    }
    for (final req in userCompleted) {
      allCompleted[req['requestId'] ?? req['id'] ?? ''] = req;
    }
    return allCompleted.values.toList();
  }

  List<Map<String, dynamic>> _filterRequests(
    List<Map<String, dynamic>> requests,
  ) {
    if (_searchQuery.isEmpty) return requests;
    return requests.where((request) {
      final userName = request['userId'].toString().toLowerCase();
      final diseaseSummary = request['diseaseSummary']
          .map((d) => d['disease'].toString().toLowerCase())
          .join(' ');
      return userName.contains(_searchQuery.toLowerCase()) ||
          diseaseSummary.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  String _formatDiseaseName(String disease) {
    // Convert snake_case to Title Case and replace underscores with spaces
    final normalized = disease.replaceAll('_', ' ').toLowerCase();
    if (normalized == 'tip burn') {
      return 'Unknown';
    }
    return disease
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
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
    // Use 'label' if available, else 'disease', else 'name'
    final mainDiseaseKey =
        mainDisease != null
            ? (mainDisease['label'] ??
                mainDisease['disease'] ??
                mainDisease['name'] ??
                'unknown')
            : 'unknown';
    final isCompleted = request['status'] == 'reviewed';
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
              if (request['status'] == 'pending') {
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
                  child:
                      request['images']?[0]?['path'] != null
                          ? _buildImageWidget(request['images'][0]['path'])
                          : Container(
                            color: Colors.grey[200],
                            child: const Icon(Icons.image_not_supported),
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
                          ? '${_formatDiseaseName(mainDiseaseKey)} Detection'
                          : 'No Disease Detected',
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

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

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

  Widget _buildImageWidget(String path) {
    if (path.startsWith('/') || path.contains(':')) {
      // File path
      return Image.file(
        File(path),
        fit: BoxFit.cover,
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
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[200],
            child: const Icon(Icons.image_not_supported),
          );
        },
      );
    }
  }
}
