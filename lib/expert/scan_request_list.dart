import 'package:flutter/material.dart';
import 'scan_request_detail.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:hive/hive.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';

class ScanRequestList extends StatefulWidget {
  final int initialTabIndex;

  const ScanRequestList({Key? key, this.initialTabIndex = 0}) : super(key: key);

  @override
  State<ScanRequestList> createState() => _ScanRequestListState();
}

class _ScanRequestListState extends State<ScanRequestList>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<Map<String, dynamic>> _pendingRequests = [];
  List<Map<String, dynamic>> _completedRequests = [];
  // Track which pending requests have been opened (to hide "New" badge)
  Set<String> _seenPendingIds = <String>{};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Set initial tab based on parameter
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialTabIndex < _tabController.length) {
        _tabController.animateTo(widget.initialTabIndex);
      }
    });
    _fetchRequests();
    _loadSeenPending();
  }

  Future<void> _loadSeenPending() async {
    try {
      final box = await Hive.openBox('expertRequestsSeenBox');
      final saved = box.get('seenPendingIds', defaultValue: []);
      if (saved is List) {
        setState(() {
          _seenPendingIds = saved.map((e) => e.toString()).toSet();
        });
      }
    } catch (_) {}
  }

  Future<void> _markPendingSeen(String id) async {
    if (id.isEmpty || _seenPendingIds.contains(id)) return;
    setState(() {
      _seenPendingIds.add(id);
    });
    try {
      final box = await Hive.openBox('expertRequestsSeenBox');
      await box.put('seenPendingIds', _seenPendingIds.toList());
    } catch (_) {}
  }

  Future<void> _fetchRequests() async {
    // Get current expert's UID from Firebase Auth
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }
    final currentExpertUid = user.uid;

    final pendingQuery =
        await FirebaseFirestore.instance
            .collection('scan_requests')
            .where('status', whereIn: ['pending', 'pending_review'])
            .get();
    final completedQuery =
        await FirebaseFirestore.instance
            .collection('scan_requests')
            .where('status', whereIn: ['reviewed', 'completed'])
            .get();

    setState(() {
      _pendingRequests = pendingQuery.docs.map((doc) => doc.data()).toList();
      // Filter completed requests to only show those reviewed by current expert
      _completedRequests =
          completedQuery.docs.map((doc) => doc.data()).where((request) {
            final expertUid = request['expertUid'] ?? '';
            return expertUid == currentExpertUid;
          }).toList();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _filterRequests(
    List<Map<String, dynamic>> requests,
  ) {
    if (_searchQuery.isEmpty) return requests;
    final query = _searchQuery.trim().toLowerCase();
    return requests.where((request) {
      final userName =
          (request['userName'] ?? request['userId'] ?? '')
              .toString()
              .toLowerCase();
      final email = (request['email'] ?? '').toString().toLowerCase();

      String diseases = '';
      final summary = request['diseaseSummary'];
      if (summary is List) {
        diseases = summary
            .map((d) {
              if (d is Map) {
                final raw =
                    (d['label'] ?? d['disease'] ?? d['name'] ?? '').toString();
                return raw.replaceAll('_', ' ').toLowerCase();
              }
              return '';
            })
            .where((s) => s.isNotEmpty)
            .join(' ');
      }

      final submittedAt =
          (request['submittedAt'] ?? '').toString().toLowerCase();
      final reviewedAt = (request['reviewedAt'] ?? '').toString().toLowerCase();
      final status = (request['status'] ?? '').toString().toLowerCase();
      final id =
          (request['id'] ?? request['requestId'] ?? '')
              .toString()
              .toLowerCase();

      return userName.contains(query) ||
          email.contains(query) ||
          diseases.contains(query) ||
          submittedAt.contains(query) ||
          reviewedAt.contains(query) ||
          status.contains(query) ||
          id.contains(query);
    }).toList();
  }

  String _formatDiseaseName(String disease) {
    // Convert snake_case to Title Case and replace underscores with spaces
    final normalized = disease.replaceAll('_', ' ').toLowerCase();
    if (normalized == 'tip burn' || normalized == 'unknown') {
      return 'Unknown';
    }
    if (normalized == 'healthy') {
      return 'Healthy';
    }
    if (normalized == 'backterial blackspot' || normalized == 'bacterial blackspot') {
      return 'Bacterial black spot';
    }
    if (normalized == 'powdery mildew') {
      return 'Powdery Mildew';
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

    // Find the dominant disease/status to display (same logic as farmer side)
    String dominantDiseaseKey = 'unknown';
    
    if (diseaseSummary.isNotEmpty) {
      // Define valid diseases
      const validDiseases = {
        'anthracnose',
        'bacterial blackspot',
        'bacterial_blackspot',
        'backterial_blackspot',
        'powdery mildew',
        'powdery_mildew',
        'dieback',
      };
      
      // First, try to find actual diseases
      final diseaseItems = diseaseSummary.where((d) {
        final rawDiseaseName = (d['disease'] ?? d['name'] ?? d['label'] ?? '').toString();
        final normalizedName = rawDiseaseName.toLowerCase().replaceAll('_', ' ').trim();
        return validDiseases.contains(normalizedName) || 
               validDiseases.contains(rawDiseaseName.toLowerCase());
      }).toList();
      
      if (diseaseItems.isNotEmpty) {
        // If diseases found, show the one with highest count
        diseaseItems.sort((a, b) {
          final countA = a['count'] as int? ?? 0;
          final countB = b['count'] as int? ?? 0;
          return countB.compareTo(countA);
        });
        dominantDiseaseKey = (diseaseItems.first['name'] ??
                diseaseItems.first['disease'] ??
                diseaseItems.first['label'] ??
                'unknown')
            .toString();
      } else {
        // No diseases found, check for healthy
        final healthyItems = diseaseSummary.where((d) {
          final rawDiseaseName = (d['disease'] ?? d['name'] ?? d['label'] ?? '').toString();
          final normalizedName = rawDiseaseName.toLowerCase().replaceAll('_', ' ').trim();
          return normalizedName == 'healthy';
        }).toList();
        
        if (healthyItems.isNotEmpty) {
          // Show "healthy" if healthy leaves detected
          dominantDiseaseKey = 'healthy';
        } else {
          // No diseases and no healthy - show unknown
          dominantDiseaseKey = 'unknown';
        }
      }
    }
    final isCompleted =
        request['status'] == 'reviewed' || request['status'] == 'completed';
    final userName = request['userName']?.toString() ?? '(No Name)';
    final submittedAt = request['submittedAt'] ?? '';
    // Format date
    final formattedDate =
        submittedAt.toString().isNotEmpty &&
                DateTime.tryParse(submittedAt.toString()) != null
            ? DateFormat(
              'MMM d, yyyy – h:mma',
            ).format(DateTime.parse(submittedAt.toString()))
            : submittedAt.toString();
    String? reviewedAt;
    if (isCompleted) {
      // reviewedAt is saved at document level, not inside expertReview
      reviewedAt = request['reviewedAt'] as String? ?? '';
    }

    // Format review date for completed requests
    final formattedReviewDate =
        reviewedAt != null &&
                reviewedAt.isNotEmpty &&
                DateTime.tryParse(reviewedAt) != null
            ? DateFormat(
              'MMM d, yyyy – h:mma',
            ).format(DateTime.parse(reviewedAt))
            : reviewedAt ?? '';

    // Use imageUrl if present and not empty, else path if not empty
    String? imageUrl = request['images']?[0]?['imageUrl'];
    String? imagePath = request['images']?[0]?['path'];
    String? displayPath =
        (imageUrl != null && imageUrl.isNotEmpty)
            ? imageUrl
            : (imagePath != null && imagePath.isNotEmpty)
            ? imagePath
            : null;

    // Check if report is being reviewed by someone else
    final reviewingByUid = request['reviewingByUid'];
    final reviewingBy = request['reviewingBy'];
    final reviewingAt = request['reviewingAt'];
    final currentUser = FirebaseAuth.instance.currentUser;
    final currentUserUid = currentUser?.uid;

    bool isLockedByOther = false;
    if (reviewingByUid != null &&
        reviewingByUid != currentUserUid &&
        reviewingAt != null) {
      // Check if lock hasn't expired (15 minutes)
      try {
        final lockTime = DateTime.parse(reviewingAt);
        final now = DateTime.now();
        final difference = now.difference(lockTime).inMinutes;
        isLockedByOther = difference < 15;
      } catch (e) {
        isLockedByOther = false;
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap:
            isLockedByOther
                ? () {
                  // Show feedback when trying to tap a locked report
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.lock, color: Colors.white, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'This report is currently being reviewed by ${reviewingBy ?? "another expert"}',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: Colors.blue.shade700,
                      duration: const Duration(seconds: 3),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                }
                : () async {
                  // Mark pending as seen when expert opens it
                  final id =
                      (request['id'] ?? request['requestId'] ?? '').toString();
                  if ((request['status'] == 'pending' ||
                          request['status'] == 'pending_review') &&
                      id.isNotEmpty) {
                    await _markPendingSeen(id);
                  }
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
          padding: const EdgeInsets.all(20),
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
                      displayPath != null && displayPath.isNotEmpty
                          ? _buildImageWidget(displayPath)
                          : Container(
                            color: Colors.grey[200],
                            child: const Icon(Icons.image_not_supported),
                          ),
                ),
              ),
              const SizedBox(width: 12),
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      dominantDiseaseKey != 'unknown'
                          ? _formatDiseaseName(dominantDiseaseKey)
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
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
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
                            'Sent: $formattedDate',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                    if (isCompleted && formattedReviewDate.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            size: 14,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Reviewed: $formattedReviewDate',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.green,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // Status indicator
              SizedBox(
                width: 80, // Reduced width for status section
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isCompleted
                                ? Colors.green
                                : (isLockedByOther
                                    ? Colors.grey
                                    : Colors.orange),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isCompleted
                            ? 'Completed'
                            : (isLockedByOther ? 'Locked' : 'Pending'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    if ((request['status'] == 'pending' ||
                        request['status'] == 'pending_review')) ...[
                      const SizedBox(height: 4),
                      // Show locked badge if being reviewed by someone else
                      if (isLockedByOther)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.blue.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.lock,
                                size: 12,
                                color: Colors.blue,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  'By ${reviewingBy ?? "Expert"}',
                                  style: const TextStyle(
                                    color: Colors.blue,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Builder(
                          builder: (context) {
                            final id =
                                (request['id'] ?? request['requestId'] ?? '')
                                    .toString();
                            final isNew =
                                id.isNotEmpty && !_seenPendingIds.contains(id);
                            return isNew
                                ? Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.red.withOpacity(0.3),
                                    ),
                                  ),
                                  child: const Text(
                                    'New',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                    ),
                                  ),
                                )
                                : const SizedBox.shrink();
                          },
                        ),
                      const SizedBox(height: 8),
                      // Delete button for pending cards
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          tooltip: 'Delete request',
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.redAccent,
                          ),
                          onPressed: () async {
                            // Block deletion if another expert has an active lock
                            if (isLockedByOther) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: const [
                                      Icon(Icons.lock, color: Colors.white),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'This report is being reviewed. Deletion is disabled until it is unlocked.',
                                        ),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: Colors.blue.shade700,
                                  duration: const Duration(seconds: 3),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              return;
                            }
                            final docId = (request['_docId'] ?? '').toString();
                            if (docId.isEmpty) {
                              await showDialog<void>(
                                context: context,
                                builder:
                                    (ctx) => Dialog(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(24),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: Colors.orange.shade50,
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                Icons.warning_amber_rounded,
                                                size: 48,
                                                color: Colors.orange.shade700,
                                              ),
                                            ),
                                            const SizedBox(height: 20),
                                            Text(
                                              tr('cannot_delete') ??
                                                  'Cannot Delete',
                                              style: const TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            Text(
                                              tr('cannot_delete_missing_id') ??
                                                  'Unable to delete: missing document ID.',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey[700],
                                              ),
                                            ),
                                            const SizedBox(height: 24),
                                            SizedBox(
                                              width: double.infinity,
                                              child: ElevatedButton(
                                                onPressed:
                                                    () => Navigator.pop(ctx),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      Colors.orange.shade700,
                                                  foregroundColor: Colors.white,
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 14,
                                                      ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                  elevation: 0,
                                                ),
                                                child: const Text(
                                                  'OK',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                              );
                              return;
                            }
                            // Re-check current lock from Firestore to avoid races
                            try {
                              final docSnap =
                                  await FirebaseFirestore.instance
                                      .collection('scan_requests')
                                      .doc(docId)
                                      .get();
                              if (docSnap.exists) {
                                final data =
                                    docSnap.data() as Map<String, dynamic>;
                                final reviewingByUid = data['reviewingByUid'];
                                final reviewingAt = data['reviewingAt'];
                                final currentUserUid =
                                    FirebaseAuth.instance.currentUser?.uid;
                                bool lockedNow = false;
                                if (reviewingByUid != null &&
                                    reviewingByUid != currentUserUid &&
                                    reviewingAt != null) {
                                  try {
                                    final lockTime = DateTime.parse(
                                      reviewingAt.toString(),
                                    );
                                    final diff =
                                        DateTime.now()
                                            .difference(lockTime)
                                            .inMinutes;
                                    lockedNow = diff < 15;
                                  } catch (_) {
                                    lockedNow = false;
                                  }
                                }
                                if (lockedNow) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Row(
                                          children: [
                                            const Icon(
                                              Icons.lock,
                                              color: Colors.white,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                'This report is currently being reviewed and cannot be deleted.',
                                              ),
                                            ),
                                          ],
                                        ),
                                        backgroundColor: Colors.blue.shade700,
                                        duration: const Duration(seconds: 3),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                  return;
                                }
                              }
                            } catch (_) {
                              // If re-check fails, fall through to confirmation
                            }

                            final confirm = await showDialog<bool>(
                              context: context,
                              builder:
                                  (ctx) => Dialog(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(24),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Colors.red.shade50,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.delete_outline_rounded,
                                              size: 48,
                                              color: Colors.red.shade700,
                                            ),
                                          ),
                                          const SizedBox(height: 20),
                                          const Text(
                                            'Delete Request?',
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            'This action cannot be undone. The pending request will be permanently deleted.',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                          const SizedBox(height: 24),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: OutlinedButton(
                                                  onPressed:
                                                      () => Navigator.pop(
                                                        ctx,
                                                        false,
                                                      ),
                                                  style: OutlinedButton.styleFrom(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          vertical: 14,
                                                        ),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                    ),
                                                    side: BorderSide(
                                                      color:
                                                          Colors.grey.shade300,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    'Cancel',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Colors.grey[700],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: ElevatedButton(
                                                  onPressed:
                                                      () => Navigator.pop(
                                                        ctx,
                                                        true,
                                                      ),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        Colors.red.shade700,
                                                    foregroundColor:
                                                        Colors.white,
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          vertical: 14,
                                                        ),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                    ),
                                                    elevation: 0,
                                                  ),
                                                  child: const Text(
                                                    'Delete',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w600,
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
                            );
                            if (confirm != true) return;
                            try {
                              await FirebaseFirestore.instance
                                  .collection('scan_requests')
                                  .doc(docId)
                                  .delete();
                              if (context.mounted) {
                                await showDialog<void>(
                                  context: context,
                                  builder:
                                      (ctx) => Dialog(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(24),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(
                                                  12,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.green.shade50,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(
                                                  Icons
                                                      .check_circle_outline_rounded,
                                                  size: 48,
                                                  color: Colors.green.shade700,
                                                ),
                                              ),
                                              const SizedBox(height: 20),
                                              Text(
                                                tr('session_deleted') ??
                                                    'Successfully Deleted',
                                                style: const TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              Text(
                                                tr('request_deleted_permanently') ??
                                                    'The request has been permanently deleted from the system.',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.grey[700],
                                                ),
                                              ),
                                              const SizedBox(height: 24),
                                              SizedBox(
                                                width: double.infinity,
                                                child: ElevatedButton(
                                                  onPressed:
                                                      () => Navigator.pop(ctx),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        Colors.green.shade700,
                                                    foregroundColor:
                                                        Colors.white,
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          vertical: 14,
                                                        ),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                    ),
                                                    elevation: 0,
                                                  ),
                                                  child: const Text(
                                                    'OK',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                await showDialog<void>(
                                  context: context,
                                  builder:
                                      (ctx) => Dialog(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(24),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(
                                                  12,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.red.shade50,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(
                                                  Icons.error_outline_rounded,
                                                  size: 48,
                                                  color: Colors.red.shade700,
                                                ),
                                              ),
                                              const SizedBox(height: 20),
                                              const Text(
                                                'Delete Failed',
                                                style: TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              Text(
                                                'An error occurred while deleting the request:\n${e.toString()}',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.grey[700],
                                                ),
                                              ),
                                              const SizedBox(height: 24),
                                              SizedBox(
                                                width: double.infinity,
                                                child: ElevatedButton(
                                                  onPressed:
                                                      () => Navigator.pop(ctx),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        Colors.red.shade700,
                                                    foregroundColor:
                                                        Colors.white,
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          vertical: 14,
                                                        ),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                    ),
                                                    elevation: 0,
                                                  ),
                                                  child: const Text(
                                                    'OK',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                );
                              }
                            }
                          },
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ],
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
    // Get current expert's UID from Firebase Auth
    final user = FirebaseAuth.instance.currentUser;
    final currentExpertUid = user?.uid ?? '';

    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance.collection('scan_requests').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final allRequests =
            snapshot.data!.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              // Attach Firestore document ID for actions like delete
              return {...data, '_docId': doc.id};
            }).toList();
        // Sort by submittedAt descending
        allRequests.sort((a, b) {
          final dateA =
              a['submittedAt'] != null && a['submittedAt'].toString().isNotEmpty
                  ? DateTime.tryParse(a['submittedAt'].toString())
                  : null;
          final dateB =
              b['submittedAt'] != null && b['submittedAt'].toString().isNotEmpty
                  ? DateTime.tryParse(b['submittedAt'].toString())
                  : null;
          if (dateA == null && dateB == null) return 0;
          if (dateA == null) return 1;
          if (dateB == null) return -1;
          return dateB.compareTo(dateA); // Descending
        });
        final filteredPending = _filterRequests(
          allRequests
              .where(
                (r) =>
                    r['status'] == 'pending' || r['status'] == 'pending_review',
              )
              .toList(),
        );
        // Filter completed requests to only show those reviewed by current expert
        final filteredCompleted = _filterRequests(
          allRequests
              .where(
                (r) =>
                    (r['status'] == 'reviewed' || r['status'] == 'completed') &&
                    (r['expertUid'] == currentExpertUid),
              )
              .toList(),
        );
        return Scaffold(
          backgroundColor: Colors.grey[50],
          body: Column(
            children: [
              _buildSearchBar(),
              Container(
                color: Colors.green,
                child: Row(
                  children: [
                    Expanded(
                      child: TabBar(
                        controller: _tabController,
                        indicatorColor: Colors.white,
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.white70,
                        tabs: [
                          Tab(text: 'Pending (${filteredPending.length})'),
                          Tab(text: 'Completed (${filteredCompleted.length})'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Removed separate totals row; counts are shown in tab labels
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
          ),
        );
      },
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
    if (path.startsWith('http')) {
      // Supabase public URL - use cached network image with memory optimization
      return CachedNetworkImage(
        imageUrl: path,
        fit: BoxFit.cover,
        memCacheWidth: 200, // Limit memory usage
        memCacheHeight: 200,
        maxWidthDiskCache: 400,
        maxHeightDiskCache: 400,
        placeholder:
            (context, url) => Container(
              color: Colors.grey[200],
              child: const Center(child: CircularProgressIndicator()),
            ),
        errorWidget: (context, url, error) {
          return Container(
            color: Colors.grey[200],
            child: const Icon(Icons.image_not_supported),
          );
        },
      );
    } else if (path.startsWith('/') || path.contains(':')) {
      // File path - optimize file loading
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
      // Asset image - use optimized loading
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
