import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'analysis_summary_screen.dart';
import 'tflite_detector.dart';
import 'disease_details_page.dart';
import 'profile_page.dart';
import 'user_request_tabbed_list.dart';
import 'user_request_detail.dart';
import 'scan_page.dart';
import '../shared/review_manager.dart';
import 'package:hive/hive.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:lottie/lottie.dart';
import 'dart:async';
import 'tracking_page.dart';
import 'tracking_models.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ImagePicker _picker = ImagePicker();
  int _selectedIndex = 0;
  final ReviewManager _reviewManager = ReviewManager();

  // User data variables
  String _userName = 'Loading...';
  bool _isLoading = true;

  // Disease information (now loaded from Firestore and cached in Hive)
  Map<String, Map<String, dynamic>> _diseaseInfo = {};

  // Quick overview state
  int _pendingRequests = 0;
  int _completedRequests = 0;
  bool _loadingRequests = true;
  // Live subscription for request counts
  StreamSubscription<QuerySnapshot>? _requestCountsSub;
  StreamSubscription? _seenBoxSub;
  int _unseenCompleted = 0;
  Set<String> _lastCompletedIds = <String>{};

  // Cache request counts to Hive for offline access
  Future<void> _cacheRequestCounts(int pending, int completed) async {
    try {
      final box = await Hive.openBox('requestCountsBox');
      await box.put('pendingCount', pending);
      await box.put('completedCount', completed);
      await box.put('lastUpdated', DateTime.now().toIso8601String());
    } catch (e) {
      print('Error caching request counts to Hive: $e');
    }
  }

  // Load cached request counts from Hive for offline access
  Future<Map<String, int>> _loadCachedRequestCounts() async {
    try {
      final box = await Hive.openBox('requestCountsBox');
      final pending = box.get('pendingCount', defaultValue: 0);
      final completed = box.get('completedCount', defaultValue: 0);
      return {'pending': pending, 'completed': completed};
    } catch (e) {
      print('Error loading cached request counts: $e');
    }
    return {'pending': 0, 'completed': 0};
  }

  Future<void> _loadRequestCounts() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final query =
          await FirebaseFirestore.instance
              .collection('scan_requests')
              .where('userId', isEqualTo: user.uid)
              .get();

      int pending = 0;
      int completed = 0;
      for (var doc in query.docs) {
        final status = doc['status'];
        if (status == 'pending' || status == 'pending_review') pending++;
        if (status == 'completed' || status == 'reviewed') completed++;
      }

      // Cache the counts for offline access
      await _cacheRequestCounts(pending, completed);

      setState(() {
        _pendingRequests = pending;
        _completedRequests = completed;
        _loadingRequests = false;
      });
    } catch (e) {
      print('Error loading from Firestore: $e');
      // Fallback to cached data
      final cachedCounts = await _loadCachedRequestCounts();
      setState(() {
        _pendingRequests = cachedCounts['pending'] ?? 0;
        _completedRequests = cachedCounts['completed'] ?? 0;
        _loadingRequests = false;
      });
    }
  }

  List<Widget> _pages = [];

  int get _pendingCount =>
      _reviewManager.pendingReviews
          .where((r) => r['status'] == 'pending')
          .length;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadDiseaseInfo();
    _loadRequestCounts();
    _subscribeToRequestCounts();
    _pages = [
      Container(),
      const ScanPage(),
      const UserRequestTabbedList(),
      const TrackingPage(),
    ];
  }

  void _subscribeToRequestCounts() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      _requestCountsSub?.cancel();
      _requestCountsSub = FirebaseFirestore.instance
          .collection('scan_requests')
          .where('userId', isEqualTo: user.uid)
          .snapshots()
          .listen((snapshot) async {
            int pending = 0;
            int completed = 0;
            final currentCompletedIds = <String>{};
            for (final doc in snapshot.docs) {
              final data = doc.data() as Map<String, dynamic>;
              final status = data['status'];
              if (status == 'pending' || status == 'pending_review') {
                pending++;
              } else if (status == 'completed' || status == 'reviewed') {
                completed++;
                final id =
                    (data['id'] ?? data['requestId'] ?? doc.id).toString();
                if (id.isNotEmpty) currentCompletedIds.add(id);
              }
            }
            _lastCompletedIds = currentCompletedIds;
            // One-time baseline: on fresh install, mark existing completed as seen
            try {
              final box = await Hive.openBox('userRequestsSeenBox');
              final bool baselineSet =
                  box.get('completedBaselineSet', defaultValue: false) as bool;
              final savedList = box.get('seenCompletedIds', defaultValue: []);
              final bool noSaved = savedList is List ? savedList.isEmpty : true;
              if (!baselineSet && noSaved) {
                await box.put('seenCompletedIds', currentCompletedIds.toList());
                await box.put('completedBaselineSet', true);
              }
            } catch (_) {}
            int unseen = 0;
            try {
              final box = await Hive.openBox('userRequestsSeenBox');
              final saved = box.get('seenCompletedIds', defaultValue: []);
              final seen =
                  saved is List
                      ? saved.map((e) => e.toString()).toSet()
                      : <String>{};
              unseen =
                  currentCompletedIds.where((id) => !seen.contains(id)).length;
            } catch (_) {}
            if (mounted) {
              setState(() {
                _pendingRequests = pending;
                _completedRequests = completed;
                _loadingRequests = false;
                _unseenCompleted = unseen;
              });
            }
            await _cacheRequestCounts(pending, completed);
          });
      // watch Hive for local seen updates to clear badge instantly
      try {
        final box = await Hive.openBox('userRequestsSeenBox');
        _seenBoxSub?.cancel();
        _seenBoxSub = box.watch(key: 'seenCompletedIds').listen((_) async {
          int unseen = 0;
          try {
            final saved = box.get('seenCompletedIds', defaultValue: []);
            final seen =
                saved is List
                    ? saved.map((e) => e.toString()).toSet()
                    : <String>{};
            unseen = _lastCompletedIds.where((id) => !seen.contains(id)).length;
          } catch (_) {}
          if (mounted) {
            setState(() {
              _unseenCompleted = unseen;
            });
          }
        });
      } catch (_) {}
    } catch (_) {}
  }

  @override
  void dispose() {
    _requestCountsSub?.cancel();
    _seenBoxSub?.cancel();
    super.dispose();
  }

  Widget _buildProcessingIndicator() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // GIF Animation (smooth in release builds)
        SizedBox(
          width: 120,
          height: 120,
          child: Image.asset('assets/animation.gif', fit: BoxFit.contain),
        ),
        const SizedBox(height: 16),
        // Processing text
        Text(
          'Processing...',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }

  // Show validation error as modal dialog
  void _showValidationErrorDialog(BuildContext context, String message) {
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
          message,
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

  // Validate detection results - returns error message if validation fails, null if OK
  String? _validateDetectionResults(Map<int, List<DetectionResult>> allResults) {
    // All detections are now allowed to proceed to analysis summary
    // Warnings will be shown in the analysis summary screen instead
    return null;
  }

  // Analysis method with progress updates
  Future<Map<int, List<DetectionResult>>> _performAnalysisWithUIYielding(
    List<String> imagePaths,
    Function(int current, int total) onProgress,
  ) async {
    final TFLiteDetector detector = TFLiteDetector();
    await detector.loadModel();
    print('DEBUG: Model loaded, starting detection...');

    final Map<int, List<DetectionResult>> allResults = {};

    for (int i = 0; i < imagePaths.length; i++) {
      print('DEBUG: Analyzing image ${i + 1}/${imagePaths.length}');

      // Update progress before analysis
      onProgress(i, imagePaths.length);

      // Multiple UI yielding attempts
      await Future.delayed(const Duration(milliseconds: 100));
      await SchedulerBinding.instance.endOfFrame;
      await Future.delayed(const Duration(milliseconds: 50));

      // Process image (this will block UI, but progress is already shown)
      final results = await detector.detectDiseases(imagePaths[i]);
      allResults[i] = results;

      // Additional UI yielding after each detection
      await Future.delayed(const Duration(milliseconds: 30));
      await SchedulerBinding.instance.endOfFrame;
    }

    // Final progress update
    onProgress(imagePaths.length, imagePaths.length);

    detector.closeModel();
    return allResults;
  }

  Future<void> _loadUserData() async {
    try {
      final userBox = await Hive.openBox('userBox');
      final localProfile = userBox.get('userProfile');
      if (localProfile != null) {
        setState(() {
          _userName = localProfile['fullName'] ?? 'Farmer';
          _isLoading = false;
        });
        return;
      }
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get();
        if (userDoc.exists) {
          final data = userDoc.data() as Map<String, dynamic>;
          setState(() {
            _userName = data['fullName'] ?? 'Farmer';
            _isLoading = false;
          });
        } else {
          setState(() {
            _userName = 'Farmer';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _userName = 'Farmer';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _userName = 'Farmer';
        _isLoading = false;
      });
    }
  }

  Future<Map<String, dynamic>?> _loadUserProfileForHeader() async {
    try {
      final userBox = await Hive.openBox('userBox');
      final localProfile = userBox.get('userProfile');
      if (localProfile != null) {
        return Map<String, dynamic>.from(localProfile);
      }
    } catch (e) {
      print('Error loading user profile for header: $e');
    }
    return null;
  }

  Future<void> _loadDiseaseInfo() async {
    final diseaseBox = await Hive.openBox('diseaseBox');
    // Try to load from local storage first
    final localDiseaseInfo = diseaseBox.get('diseaseInfo');
    if (localDiseaseInfo != null && localDiseaseInfo is Map) {
      setState(() {
        _diseaseInfo = Map<String, Map<String, dynamic>>.from(
          (localDiseaseInfo as Map).map(
            (k, v) =>
                MapEntry(k as String, Map<String, dynamic>.from(v as Map)),
          ),
        );
      });
    }
    // Always try to fetch latest from Firestore
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
      }
    } catch (e) {
      print('Error fetching disease info: $e');
    }
  }

  Widget _buildQuickOverviewCard() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('scan_requests')
              .where('userId', isEqualTo: user.uid)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          // Fallback to cached data when offline
          return FutureBuilder<Map<String, int>>(
            future: _loadCachedRequestCounts(),
            builder: (context, cachedSnapshot) {
              if (cachedSnapshot.hasData) {
                final cachedCounts = cachedSnapshot.data!;
                return _buildOverviewCardContent(
                  cachedCounts['pending'] ?? 0,
                  cachedCounts['completed'] ?? 0,
                  isOffline: true,
                );
              }
              return _buildOverviewCardContent(0, 0, isOffline: true);
            },
          );
        }

        final docs = snapshot.data?.docs ?? [];
        int pending = 0;
        int completed = 0;
        for (var doc in docs) {
          final status = doc['status'];
          if (status == 'pending') pending++;
          if (status == 'completed') completed++;
        }

        // Cache the counts for offline access
        _cacheRequestCounts(pending, completed);

        return _buildOverviewCardContent(pending, completed, isOffline: false);
      },
    );
  }

  Widget _buildOverviewCardContent(
    int pending,
    int completed, {
    bool isOffline = false,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (isOffline)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.wifi_off, color: Colors.orange, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      'Offline - Cached data',
                      style: TextStyle(
                        color: Colors.orange[700],
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Icon(Icons.pending, color: Colors.orange, size: 32),
                      const SizedBox(height: 4),
                      Text(
                        tr('pending'),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '$pending',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 32),
                      const SizedBox(height: 4),
                      Text(
                        tr('completed'),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '$completed',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectFromGallery(BuildContext context) async {
    final List<XFile>? images = await _picker.pickMultiImage();
    if (images != null && images.isNotEmpty) {
      if (images.length > 5) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Maximum 5 images can be selected'),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      if (!mounted) return;

      // Show Lottie loading dialog IMMEDIATELY after image selection
      print('DEBUG: Showing Lottie loading dialog for analysis...');
      int currentImage = 0;
      int totalImages = images.length;
      Timer? animationTimer;
      bool isAnalysisComplete = false;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => StatefulBuilder(
              builder: (context, setDialogState) {
                // Start a timer to force UI updates during analysis
                if (animationTimer == null) {
                  animationTimer = Timer.periodic(
                    const Duration(milliseconds: 16),
                    (timer) {
                      if (!isAnalysisComplete && mounted) {
                        setDialogState(() {
                          // Force a rebuild to keep animation running
                        });
                      } else {
                        timer.cancel();
                      }
                    },
                  );
                }

                return AlertDialog(
                  title: Text(tr('analyzing_images')),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Simple processing indicator
                      _buildProcessingIndicator(),
                      const SizedBox(height: 16),
                      LinearProgressIndicator(
                        value: currentImage / totalImages,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Analyzing image ${currentImage + 1} of $totalImages...',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please wait, this may take a moment...',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[500], fontSize: 14),
                      ),
                    ],
                  ),
                );
              },
            ),
      );
      print('DEBUG: Lottie loading dialog should be visible now');

      // Add a delay to ensure dialog is rendered and visible
      await Future.delayed(const Duration(milliseconds: 300));

      try {
        // Perform analysis on all images with UI yielding
        print('DEBUG: Starting analysis with UI yielding...');
        final List<String> imagePaths = images.map((img) => img.path).toList();

        // Run analysis with progress updates
        final Map<int, List<DetectionResult>> allResults =
            await _performAnalysisWithUIYielding(imagePaths, (current, total) {
              // Update progress in dialog
              if (mounted) {
                setState(() {
                  currentImage = current;
                });
              }
            });

        print('DEBUG: Analysis completed, ensuring smooth transition...');

        // Stop the animation timer
        isAnalysisComplete = true;
        animationTimer?.cancel();

        // Add a longer delay for smooth user experience
        await Future.delayed(const Duration(milliseconds: 800));

        // Close loading dialog smoothly
        if (mounted) {
          Navigator.pop(context);
          print('DEBUG: Dialog closed smoothly');
        }

        // Validate detection results before navigating
        final validationResult = _validateDetectionResults(allResults);
        if (validationResult != null) {
          // Show error message as modal dialog and don't proceed
          if (mounted) {
            _showValidationErrorDialog(context, validationResult);
          }
          return;
        }

        // Navigate directly to analysis summary
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => AnalysisSummaryScreen(
                    allResults: allResults,
                    imagePaths: imagePaths,
                  ),
            ),
          );
        }
      } catch (e) {
        // Stop the animation timer
        isAnalysisComplete = true;
        animationTimer?.cancel();

        // Close loading dialog
        if (mounted) Navigator.pop(context);

        // Show error
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error analyzing images: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showDiseaseDetails(String name, String imagePath) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => DiseaseDetailsPage(
              name: name,
              imagePath: imagePath,
              scientificName: _diseaseInfo[name]?['scientificName'] ?? '',
              details: {
                'Symptoms': _diseaseInfo[name]?['symptoms'] ?? [],
                'Treatments': _diseaseInfo[name]?['treatments'] ?? [],
              },
            ),
      ),
    );
  }

  String _formatTimeAgo(DateTime submittedDate) {
    final difference = DateTime.now().difference(submittedDate);
    if (difference.inDays > 0) {
      return tr('time_ago_days', namedArgs: {'count': '${difference.inDays}'});
    } else if (difference.inHours > 0) {
      return tr(
        'time_ago_hours',
        namedArgs: {'count': '${difference.inHours}'},
      );
    } else if (difference.inMinutes > 0) {
      return tr(
        'time_ago_minutes',
        namedArgs: {'count': '${difference.inMinutes}'},
      );
    }
    return tr('just_now');
  }

  Widget _buildRecentActivitySection() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('scan_requests')
              .where('userId', isEqualTo: user.uid)
              .orderBy('submittedAt', descending: true)
              .limit(3)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Try to load from cache while waiting
          return FutureBuilder<List<Map<String, dynamic>>>(
            future: _loadCachedRecentActivity(),
            builder: (context, cacheSnapshot) {
              if (cacheSnapshot.hasData && cacheSnapshot.data!.isNotEmpty) {
                return _buildRecentActivityContent(
                  cacheSnapshot.data!,
                  isOffline: true,
                );
              }
              return const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Center(child: CircularProgressIndicator()),
              );
            },
          );
        }

        // Handle errors - show cached data if available
        if (snapshot.hasError) {
          // Fallback: Try without orderBy if index is missing
          return StreamBuilder<QuerySnapshot>(
            stream:
                FirebaseFirestore.instance
                    .collection('scan_requests')
                    .where('userId', isEqualTo: user.uid)
                    .limit(3)
                    .snapshots(),
            builder: (context, fallbackSnapshot) {
              if (!fallbackSnapshot.hasData ||
                  fallbackSnapshot.data!.docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Icon(
                            Icons.history,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            tr('no_recent_activity'),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tr('start_scanning_recent_activity'),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }
              // Manually sort by submittedAt since orderBy is not available
              final recentScans = fallbackSnapshot.data!.docs;
              recentScans.sort((a, b) {
                final aData = a.data() as Map<String, dynamic>;
                final bData = b.data() as Map<String, dynamic>;

                // Handle both Timestamp and String (milliseconds)
                DateTime? aTime;
                DateTime? bTime;

                if (aData['submittedAt'] is Timestamp) {
                  aTime = (aData['submittedAt'] as Timestamp).toDate();
                } else if (aData['submittedAt'] is int) {
                  aTime = DateTime.fromMillisecondsSinceEpoch(
                    aData['submittedAt'],
                  );
                } else if (aData['submittedAt'] is String) {
                  try {
                    aTime = DateTime.fromMillisecondsSinceEpoch(
                      int.parse(aData['submittedAt']),
                    );
                  } catch (e) {
                    // Try parsing as ISO date string
                    try {
                      aTime = DateTime.parse(aData['submittedAt']);
                    } catch (e2) {
                      print(
                        'Cannot parse submittedAt: ${aData['submittedAt']}',
                      );
                    }
                  }
                } else if (aData['submittedAt'] is Map) {
                  // Handle Firestore Timestamp as Map with _seconds field
                  final map = aData['submittedAt'] as Map<String, dynamic>;
                  if (map.containsKey('_seconds')) {
                    aTime = DateTime.fromMillisecondsSinceEpoch(
                      (map['_seconds'] as int) * 1000,
                    );
                  }
                }

                if (bData['submittedAt'] is Timestamp) {
                  bTime = (bData['submittedAt'] as Timestamp).toDate();
                } else if (bData['submittedAt'] is int) {
                  bTime = DateTime.fromMillisecondsSinceEpoch(
                    bData['submittedAt'],
                  );
                } else if (bData['submittedAt'] is String) {
                  try {
                    bTime = DateTime.fromMillisecondsSinceEpoch(
                      int.parse(bData['submittedAt']),
                    );
                  } catch (e) {
                    // Try parsing as ISO date string
                    try {
                      bTime = DateTime.parse(bData['submittedAt']);
                    } catch (e2) {
                      print(
                        'Cannot parse submittedAt: ${bData['submittedAt']}',
                      );
                    }
                  }
                } else if (bData['submittedAt'] is Map) {
                  // Handle Firestore Timestamp as Map with _seconds field
                  final map = bData['submittedAt'] as Map<String, dynamic>;
                  if (map.containsKey('_seconds')) {
                    bTime = DateTime.fromMillisecondsSinceEpoch(
                      (map['_seconds'] as int) * 1000,
                    );
                  }
                }

                if (aTime == null || bTime == null) return 0;
                return bTime.compareTo(
                  aTime,
                ); // Descending order (newest first)
              });

              // Take only first 3 after sorting
              final topThree = recentScans.take(3).toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          tr('recent_activity'),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _selectedIndex = 2;
                            });
                          },
                          child: Text(
                            tr('view_all'),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...topThree.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return _buildRecentActivityCard(doc.id, data);
                  }).toList(),
                ],
              );
            },
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          // Try to show cached data
          return FutureBuilder<List<Map<String, dynamic>>>(
            future: _loadCachedRecentActivity(),
            builder: (context, cacheSnapshot) {
              if (cacheSnapshot.hasData && cacheSnapshot.data!.isNotEmpty) {
                return _buildRecentActivityContent(
                  cacheSnapshot.data!,
                  isOffline: true,
                );
              }
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(Icons.history, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        Text(
                          tr('no_recent_activity'),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tr('start_scanning_recent_activity'),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        }

        // Cache the data and build UI
        final recentScans = snapshot.data!.docs;
        final recentData =
            recentScans.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              data['id'] = doc.id; // Add document ID
              return data;
            }).toList();

        // Save to cache
        _cacheRecentActivity(recentData);

        return _buildRecentActivityContent(recentData);
      },
    );
  }

  Future<void> _cacheRecentActivity(List<Map<String, dynamic>> data) async {
    try {
      final box = await Hive.openBox('recentActivityBox');
      await box.put('recentScans', data);
      await box.put('lastUpdated', DateTime.now().toIso8601String());
    } catch (e) {
      print('Error caching recent activity: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _loadCachedRecentActivity() async {
    try {
      final box = await Hive.openBox('recentActivityBox');
      final cached = box.get('recentScans');
      if (cached != null && cached is List) {
        return cached
            .map((item) {
              try {
                if (item is Map) {
                  return Map<String, dynamic>.from(
                    item.map((key, value) => MapEntry(key.toString(), value)),
                  );
                }
              } catch (e) {
                print('Error parsing cached item: $e');
              }
              return <String, dynamic>{};
            })
            .where((item) => item.isNotEmpty)
            .toList();
      }
    } catch (e) {
      print('Error loading cached recent activity: $e');
      // Clear corrupted cache
      try {
        final box = await Hive.openBox('recentActivityBox');
        await box.clear();
      } catch (_) {}
    }
    return [];
  }

  Widget _buildRecentActivityContent(
    List<Map<String, dynamic>> recentData, {
    bool isOffline = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    tr('recent_activity'),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                  if (isOffline) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.wifi_off, size: 16, color: Colors.orange[700]),
                  ],
                ],
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedIndex = 2; // Navigate to Requests tab
                  });
                },
                child: Text(
                  tr('view_all'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ...recentData.map((data) {
          try {
            // Ensure data is Map<String, dynamic>
            final safeData =
                data is Map<String, dynamic>
                    ? data
                    : Map<String, dynamic>.from(
                      (data as Map).map(
                        (key, value) => MapEntry(key.toString(), value),
                      ),
                    );
            final docId = safeData['id']?.toString() ?? '';
            return _buildRecentActivityCard(docId, safeData);
          } catch (e) {
            print('Error building activity card: $e');
            return const SizedBox.shrink();
          }
        }).toList(),
      ],
    );
  }

  Widget _buildRecentActivityCard(String docId, Map<String, dynamic> data) {
    final status = data['status'] ?? 'pending';

    // Handle submittedAt as either Timestamp, int, String, or Map
    DateTime? submittedDate;
    if (data['submittedAt'] is Timestamp) {
      submittedDate = (data['submittedAt'] as Timestamp).toDate();
    } else if (data['submittedAt'] is int) {
      submittedDate = DateTime.fromMillisecondsSinceEpoch(data['submittedAt']);
    } else if (data['submittedAt'] is String) {
      try {
        submittedDate = DateTime.fromMillisecondsSinceEpoch(
          int.parse(data['submittedAt']),
        );
      } catch (e) {
        // Try parsing as ISO date string (e.g., "2024-01-06T12:30:00.000")
        try {
          submittedDate = DateTime.parse(data['submittedAt']);
        } catch (e2) {
          print('Error parsing submittedAt: ${data['submittedAt']}');
        }
      }
    } else if (data['submittedAt'] is Map) {
      // Handle Firestore Timestamp as Map with _seconds field
      final map = data['submittedAt'] as Map<String, dynamic>;
      if (map.containsKey('_seconds')) {
        submittedDate = DateTime.fromMillisecondsSinceEpoch(
          (map['_seconds'] as int) * 1000,
        );
      }
    }

    // Handle images field - it's a List of Maps with 'imageUrl' key
    List<String> imageUrls = [];
    if (data['images'] is List) {
      final imagesList = data['images'] as List<dynamic>;
      for (var item in imagesList) {
        if (item is Map && item.containsKey('imageUrl')) {
          final url = item['imageUrl']?.toString() ?? '';
          if (url.isNotEmpty) {
            imageUrls.add(url);
          }
        }
      }
    }

    final diseaseSummary =
        (data['diseaseSummary'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ??
        [];

    // Determine status color and icon
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (status) {
      case 'completed':
      case 'reviewed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = tr('completed');
        break;
      case 'tracking':
        statusColor = Colors.blue;
        statusIcon = Icons.track_changes;
        statusText = tr('tracking');
        break;
      case 'pending_review':
        statusColor = Colors.blue;
        statusIcon = Icons.rate_review;
        statusText = tr('pending_review');
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        statusText = tr('pending');
    }

    // Get primary disease name and normalize Tip Burn to Unknown
    String diseaseName = 'Analyzing...';
    Map<String, dynamic>? topDisease;
    if (diseaseSummary.isNotEmpty) {
      // Choose the dominant disease by highest count (matches My Requests logic)
      final List<Map<String, dynamic>> list =
          diseaseSummary.whereType<Map<String, dynamic>>().toList();
      if (list.isNotEmpty) {
        list.sort((a, b) {
          final num countA = (a['count'] is num) ? a['count'] as num : 0;
          final num countB = (b['count'] is num) ? b['count'] as num : 0;
          return countB.compareTo(countA);
        });
        topDisease = list.first;
      }
    } else {
      // Fallback: compute dominant disease from images[].results if present
      if (data['images'] is List) {
        final Map<String, int> counts = {};
        for (final img in (data['images'] as List)) {
          if (img is Map && img['results'] is List) {
            for (final r in (img['results'] as List)) {
              if (r is Map && r['disease'] != null) {
                final label = r['disease'].toString();
                counts[label] = (counts[label] ?? 0) + 1;
              }
            }
          }
        }
        if (counts.isNotEmpty) {
          final sorted =
              counts.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value));
          final best = sorted.first;
          topDisease = {
            'name': best.key,
            'label': best.key,
            'count': best.value,
          };
        }
      }
    }
    if (topDisease != null) {
      final rawName = (topDisease['name'] ?? '').toString();
      final lower = rawName.toLowerCase();
      if (lower == 'tip_burn' || lower == 'tip burn') {
        diseaseName = 'Unknown';
      } else if (lower == 'backterial_blackspot') {
        diseaseName = 'Bacterial black spot';
      } else if (lower == 'powdery_mildew') {
        diseaseName = 'Powdery Mildew';
      } else if (rawName.isEmpty) {
        diseaseName = 'Unknown';
      } else {
        diseaseName = rawName
            .split('_')
            .map(
              (word) =>
                  word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1),
            )
            .join(' ');
      }
    }

    // Format date
    String timeAgo = tr('just_now');
    if (submittedDate != null) {
      timeAgo = _formatTimeAgo(submittedDate);
    }

    void _showTrackingModalFromRecent(Map<String, dynamic> sourceData) {
      // Build a lightweight session object compatible with tracking modal content
      final String dateStr = sourceData['submittedAt']?.toString() ?? '';
      final String formattedDate =
          dateStr.isNotEmpty && DateTime.tryParse(dateStr) != null
              ? DateFormat(
                'MMM d, yyyy – h:mma',
              ).format(DateTime.parse(dateStr))
              : tr('unknown');
      final List images = (sourceData['images'] as List?) ?? [];

      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      tr('session_details'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      tr('tracking'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${tr('date')} $formattedDate',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tr(
                          'image_count',
                          namedArgs: {'count': images.length.toString()},
                        ),
                        style: const TextStyle(fontSize: 14),
                      ),
                      const Divider(height: 24),
                      for (int idx = 0; idx < images.length; idx++) ...[
                        Card(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (images[idx]['imageUrl'] != null &&
                                    (images[idx]['imageUrl'] as String)
                                        .isNotEmpty)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: CachedNetworkImage(
                                      imageUrl: images[idx]['imageUrl'],
                                      width: 320,
                                      height: 180,
                                      fit: BoxFit.cover,
                                      placeholder:
                                          (context, url) => const Center(
                                            child: CircularProgressIndicator(),
                                          ),
                                      errorWidget:
                                          (context, url, error) => const Icon(
                                            Icons.broken_image,
                                            size: 40,
                                            color: Colors.grey,
                                          ),
                                    ),
                                  ),
                                const SizedBox(height: 8),
                                Text(
                                  tr('results'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                ...((images[idx]['results'] as List?) ?? []).map((
                                  res,
                                ) {
                                  final disease =
                                      res['disease']?.toString() ?? 'Unknown';
                                  final confidence = res['confidence'];
                                  final label = TrackingModels.formatLabel(
                                    disease,
                                  );
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 2,
                                    ),
                                    child: Text(
                                      confidence != null
                                          ? '$label (${(confidence * 100).toStringAsFixed(1)}%)'
                                          : label,
                                      style: const TextStyle(fontSize: 15),
                                    ),
                                  );
                                }).toList(),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(tr('close')),
                ),
              ],
            ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            if (status == 'tracking') {
              _showTrackingModalFromRecent(data);
              return;
            }
            // Navigate to request detail page
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UserRequestDetail(request: data),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Image thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child:
                      imageUrls.isNotEmpty
                          ? CachedNetworkImage(
                            imageUrl: imageUrls[0],
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            placeholder:
                                (context, url) => Container(
                                  width: 60,
                                  height: 60,
                                  color: Colors.grey[200],
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                            errorWidget: (context, url, error) {
                              return Container(
                                width: 60,
                                height: 60,
                                color: Colors.grey[300],
                                child: const Icon(
                                  Icons.image,
                                  color: Colors.grey,
                                ),
                              );
                            },
                          )
                          : Container(
                            width: 60,
                            height: 60,
                            color: Colors.grey[300],
                            child: const Icon(Icons.image, color: Colors.grey),
                          ),
                ),
                const SizedBox(width: 12),
                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        diseaseName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(statusIcon, size: 14, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 13,
                              color: statusColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('•', style: TextStyle(color: Colors.grey[400])),
                          const SizedBox(width: 8),
                          Text(
                            timeAgo,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Arrow icon
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDiseaseCard(String name, String imagePath) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: Colors.green.shade200),
      ),
      child: InkWell(
        onTap: () => _showDiseaseDetails(name, imagePath),
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

  // Normalize Firestore disease names to image map keys
  String _normalizeDiseaseKey(String name) {
    final lower = name.toLowerCase().trim();
    final underscored = lower.replaceAll(' ', '_');
    if (underscored == 'bacterial_black_spot' ||
        underscored == 'bacterial_blackspot' ||
        underscored == 'backterial_blackspot') {
      // Keep asset key consistent with existing filename map
      return 'backterial_blackspot';
    }
    if (underscored == 'powdery_mildew') {
      return 'powdery_mildew';
    }
    return underscored;
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: Column(
            children: [
              // Green header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            if (mounted) {
                              setState(() {
                                _selectedIndex = 0; // go to Home tab
                              });
                            }
                          },
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(2),
                            child: Image.asset(
                              'assets/applogo_header.png',
                              width: 37,
                              height: 37,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            if (mounted) {
                              setState(() {
                                _selectedIndex = 0; // go Home on title tap
                              });
                            }
                          },
                          child: Row(
                            children: const [
                              Text(
                                'Mango',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black26,
                                      offset: Offset(0, 2),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                'Sense',
                                style: TextStyle(
                                  color: Colors.yellow,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black26,
                                      offset: Offset(0, 2),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ProfilePage(),
                          ),
                        );
                      },
                      child: FutureBuilder<Map<String, dynamic>?>(
                        future: _loadUserProfileForHeader(),
                        builder: (context, snapshot) {
                          final profileImageUrl =
                              snapshot.data?['imageProfile'] as String?;

                          return Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child:
                                  profileImageUrl != null &&
                                          profileImageUrl.isNotEmpty
                                      ? CachedNetworkImage(
                                        imageUrl: profileImageUrl,
                                        width: 40,
                                        height: 40,
                                        fit: BoxFit.cover,
                                        placeholder:
                                            (context, url) => Container(
                                              width: 40,
                                              height: 40,
                                              color: Colors.white,
                                              child: const Center(
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              ),
                                            ),
                                        errorWidget:
                                            (context, url, error) => Container(
                                              width: 40,
                                              height: 40,
                                              color: Colors.white,
                                              child: const Icon(
                                                Icons.person,
                                                color: Colors.green,
                                                size: 22,
                                              ),
                                            ),
                                      )
                                      : Container(
                                        width: 40,
                                        height: 40,
                                        color: Colors.white,
                                        child: const Icon(
                                          Icons.person,
                                          color: Colors.green,
                                          size: 22,
                                        ),
                                      ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              // Main content
              Expanded(
                child:
                    _selectedIndex == 0
                        ? StreamBuilder<QuerySnapshot>(
                          stream:
                              FirebaseFirestore.instance
                                  .collection('diseases')
                                  .snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            final diseaseDocs = snapshot.data!.docs;
                            final diseaseNames =
                                diseaseDocs
                                    .map((doc) => doc['name'] as String)
                                    .toList()
                                  ..sort(
                                    (a, b) => a.toLowerCase().compareTo(
                                      b.toLowerCase(),
                                    ),
                                  );
                            final Map<String, String> diseaseImageMap = {
                              'anthracnose':
                                  'assets/replace_disease/anthracnose_image.jpg',
                              'backterial_blackspot':
                                  'assets/replace_disease/bacterial_image.jpg',
                              'dieback':
                                  'assets/replace_disease/dieback_image.jpg',
                              'powdery_mildew':
                                  'assets/replace_disease/powdery_image.jpg',
                              'healthy':
                                  'assets/replace_disease/healthy_image.jpg',
                            };
                            return SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: Column(
                                children: [
                                  const SizedBox(height: 16),
                                  // Welcome text
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            tr(
                                              'good_day',
                                              namedArgs: {'name': _userName},
                                            ),
                                            style: TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green[700],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  // Quick Overview Card
                                  _buildQuickOverviewCard(),
                                  const SizedBox(height: 16),
                                  // Recent Activity Section
                                  _buildRecentActivitySection(),
                                  const SizedBox(height: 16),
                                  // Diseases section
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        tr('diseases'),
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey[800],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  // Disease cards (from Firestore) - match image by normalized name
                                  for (final name in diseaseNames)
                                    _buildDiseaseCard(
                                      name,
                                      diseaseImageMap[_normalizeDiseaseKey(
                                            name,
                                          )] ??
                                          'assets/replace_disease/healthy_image.jpg',
                                    ),
                                  const SizedBox(height: 16),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        tr('none_disease'),
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  _buildDiseaseCard(
                                    'Healthy',
                                    'assets/replace_disease/healthy_image.jpg',
                                  ),
                                  const SizedBox(height: 16),
                                ],
                              ),
                            );
                          },
                        )
                        : _pages[_selectedIndex],
              ),
              // Bottom navigation bar
              Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 12,
                      offset: const Offset(0, -4),
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: BottomNavigationBar(
                  currentIndex: _selectedIndex,
                  onTap: (index) {
                    setState(() {
                      _selectedIndex = index;
                    });
                  },
                  type: BottomNavigationBarType.fixed,
                  selectedItemColor: Colors.green,
                  unselectedItemColor: Colors.grey,
                  elevation: 0,
                  items: [
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.home),
                      label: tr('home'),
                    ),
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.camera_alt),
                      label: tr('scan'),
                    ),
                    BottomNavigationBarItem(
                      icon: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const Icon(Icons.list_alt, size: 28),
                          if (_unseenCompleted > 0)
                            Positioned(
                              right: -8,
                              top: -8,
                              child: Container(
                                padding: const EdgeInsets.all(0),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 22,
                                  minHeight: 22,
                                ),
                                child: Center(
                                  child: Text(
                                    _unseenCompleted > 9
                                        ? '9+'
                                        : '$_unseenCompleted',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      label: tr('my_requests'),
                    ),
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.show_chart),
                      label: tr('tracking'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
