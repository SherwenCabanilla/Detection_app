import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:fl_chart/fl_chart.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:easy_localization/easy_localization.dart';
import 'tracking_models.dart';
import 'tracking_chart.dart';
// Bounding boxes for tracking modal will be drawn with a lightweight painter below

class TrackingPage extends StatefulWidget {
  const TrackingPage({Key? key}) : super(key: key);

  @override
  State<TrackingPage> createState() => _TrackingPageState();
}

class _TrackingPageState extends State<TrackingPage> {
  int _selectedRangeIndex = 0; // 0: Last 7 Days, 1: Monthly, 2: Custom
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  int? _monthlyYear;
  int? _monthlyMonth; // 1-12

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadSelectedRangeIndex();
  }

  Future<void> _loadSelectedRangeIndex() async {
    final box = await Hive.openBox('trackingBox');
    final idx = box.get('selectedRangeIndex');
    if (idx is int && idx >= 0 && idx < TrackingModels.timeRanges.length) {
      setState(() {
        _selectedRangeIndex = idx;
      });
    }
    final startStr = box.get('customStartDate') as String?;
    final endStr = box.get('customEndDate') as String?;
    if (startStr != null) {
      _customStartDate = DateTime.tryParse(startStr);
    }
    if (endStr != null) {
      _customEndDate = DateTime.tryParse(endStr);
    }
    final y = box.get('monthlyYear');
    final m = box.get('monthlyMonth');
    if (y is int && m is int) {
      _monthlyYear = y;
      _monthlyMonth = m;
    }
  }

  Future<void> _saveSelectedRangeIndex(int idx) async {
    final box = await Hive.openBox('trackingBox');
    await box.put('selectedRangeIndex', idx);
  }

  Future<void> _saveCustomRange(DateTime start, DateTime end) async {
    final box = await Hive.openBox('trackingBox');
    await box.put(
      'customStartDate',
      DateTime(start.year, start.month, start.day).toIso8601String(),
    );
    await box.put(
      'customEndDate',
      DateTime(end.year, end.month, end.day).toIso8601String(),
    );
  }

  Future<void> _saveMonthly(int year, int month) async {
    final box = await Hive.openBox('trackingBox');
    await box.put('monthlyYear', year);
    await box.put('monthlyMonth', month);
  }

  Future<DateTime?> _showMonthYearPicker({
    required BuildContext context,
    required DateTime initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
  }) async {
    DateTime selectedDate = initialDate;

    return await showDialog<DateTime>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(tr('select_month_year')),
              content: SizedBox(
                width: 300,
                height: 400,
                child: Column(
                  children: [
                    // Year selector
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios),
                          onPressed:
                              selectedDate.year > firstDate.year
                                  ? () {
                                    setState(() {
                                      selectedDate = DateTime(
                                        selectedDate.year - 1,
                                        selectedDate.month,
                                      );
                                    });
                                  }
                                  : null,
                        ),
                        Text(
                          '${selectedDate.year}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.arrow_forward_ios),
                          onPressed:
                              selectedDate.year < lastDate.year
                                  ? () {
                                    setState(() {
                                      selectedDate = DateTime(
                                        selectedDate.year + 1,
                                        selectedDate.month,
                                      );
                                    });
                                  }
                                  : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Month grid
                    Expanded(
                      child: GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                              childAspectRatio: 2,
                            ),
                        itemCount: 12,
                        itemBuilder: (context, index) {
                          final month = index + 1;
                          final isSelected = selectedDate.month == month;
                          final monthDate = DateTime(selectedDate.year, month);
                          final isDisabled =
                              monthDate.isBefore(
                                DateTime(firstDate.year, firstDate.month),
                              ) ||
                              monthDate.isAfter(
                                DateTime(lastDate.year, lastDate.month),
                              );

                          const monthNames = [
                            'Jan',
                            'Feb',
                            'Mar',
                            'Apr',
                            'May',
                            'Jun',
                            'Jul',
                            'Aug',
                            'Sep',
                            'Oct',
                            'Nov',
                            'Dec',
                          ];

                          return InkWell(
                            onTap:
                                isDisabled
                                    ? null
                                    : () {
                                      setState(() {
                                        selectedDate = DateTime(
                                          selectedDate.year,
                                          month,
                                        );
                                      });
                                    },
                            child: Container(
                              decoration: BoxDecoration(
                                color:
                                    isSelected
                                        ? const Color(0xFF2D7204)
                                        : isDisabled
                                        ? Colors.grey.shade200
                                        : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color:
                                      isSelected
                                          ? const Color(0xFF2D7204)
                                          : Colors.grey.shade300,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                monthNames[index],
                                style: TextStyle(
                                  color:
                                      isDisabled
                                          ? Colors.grey.shade400
                                          : isSelected
                                          ? Colors.white
                                          : Colors.black87,
                                  fontWeight:
                                      isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
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
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: Text(tr('cancel')),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, selectedDate),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D7204),
                    foregroundColor: Colors.white,
                  ),
                  child: Text(tr('ok')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _pickCustomRange() async {
    final initialRange =
        _customStartDate != null && _customEndDate != null
            ? DateTimeRange(start: _customStartDate!, end: _customEndDate!)
            : DateTimeRange(
              start: DateTime.now().subtract(const Duration(days: 6)),
              end: DateTime.now(),
            );
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1970),
      lastDate: DateTime.now(),
      initialDateRange: initialRange,
    );
    if (picked != null) {
      setState(() {
        _customStartDate = picked.start;
        _customEndDate = picked.end;
        _selectedRangeIndex = 2; // Custom
      });
      await _saveSelectedRangeIndex(2);
      await _saveCustomRange(picked.start, picked.end);
    }
  }

  String _getTimeRangeLabel(int index) {
    switch (index) {
      case 0:
        return tr('last_7_days');
      case 1:
        if (_monthlyYear != null && _monthlyMonth != null) {
          final dt = DateTime(_monthlyYear!, _monthlyMonth!, 1);
          return DateFormat('MMMM yyyy').format(dt);
        }
        return tr('monthly');
      case 2:
        if (_customStartDate != null && _customEndDate != null) {
          final s = DateFormat('MMM d').format(_customStartDate!);
          final e = DateFormat('MMM d').format(_customEndDate!);
          return '${tr('custom')}: $s – $e';
        }
        return tr('custom');
      default:
        return tr('last_7_days');
    }
  }

  Future<List<Map<String, dynamic>>> _loadSessionsWithFallback(
    String userId,
  ) async {
    try {
      // Try to load from Firestore first
      final trackingQuery =
          await FirebaseFirestore.instance
              .collection('tracking')
              .where('userId', isEqualTo: userId)
              .orderBy('date', descending: true)
              .get();

      final scanRequestsQuery =
          await FirebaseFirestore.instance
              .collection('scan_requests')
              .where('userId', isEqualTo: userId)
              .get();

      final cloudSessions =
          trackingQuery.docs
              .map((doc) => Map<String, dynamic>.from(doc.data()))
              .toList();

      // Build scan requests list but skip those with status 'tracking' to avoid duplicates
      final List<Map<String, dynamic>> scanRequests = [];
      for (final doc in scanRequestsQuery.docs) {
        final data = Map<String, dynamic>.from(doc.data());
        final status = (data['status'] ?? 'pending').toString();
        if (status == 'tracking') {
          // This entry is also present in 'tracking' collection; skip to prevent duplicates
          continue;
        }
        scanRequests.add({
          'sessionId': data['id'] ?? data['sessionId'] ?? doc.id,
          'date': data['submittedAt'] ?? '',
          'images': data['images'] ?? [],
          'source': status,
          'diseaseSummary': data['diseaseSummary'] ?? [],
          'status': status,
          'userName': data['userName'] ?? '',
          'expertReview': data['expertReview'],
          'expertName': data['expertName'],
        });
      }

      // Merge and de-duplicate by sessionId, preferring entries from 'tracking' collection
      final Map<String, Map<String, dynamic>> byId = {};
      for (final s in scanRequests) {
        final id = (s['sessionId'] ?? '').toString();
        if (id.isNotEmpty) byId[id] = s;
      }
      for (final s in cloudSessions) {
        final id = (s['sessionId'] ?? s['id'] ?? '').toString();
        if (id.isNotEmpty) byId[id] = s; // overwrite with tracking
      }
      final sessions = byId.values.toList();

      // Save to Hive for offline use
      final box = await Hive.openBox('trackingBox');
      await box.put('scans', sessions);

      return sessions;
    } catch (e) {
      print('Error loading from Firestore: $e');
      // Fallback to local Hive data
      try {
        final box = await Hive.openBox('trackingBox');
        final sessions = box.get('scans', defaultValue: []);
        if (sessions is List) {
          return sessions
              .whereType<Map>()
              .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
              .toList();
        }
        return [];
      } catch (e2) {
        print('Error loading local data: $e2');
        return [];
      }
    }
  }

  Widget _buildStatusCard(String label, int count, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildHealthInsights(
    int healthy,
    int diseased,
    int total,
    Map<String, int> overallCounts,
    List<Map<String, dynamic>> chartData,
  ) {
    final healthPercentage = (healthy / total * 100).round();

    // Determine health status
    String statusKey;
    Color statusColor;
    IconData statusIcon;

    if (healthPercentage >= 80) {
      statusKey = 'farm_health_excellent';
      statusColor = Colors.green;
      statusIcon = Icons.sentiment_very_satisfied;
    } else if (healthPercentage >= 60) {
      statusKey = 'farm_health_good';
      statusColor = Colors.lightGreen;
      statusIcon = Icons.sentiment_satisfied;
    } else if (healthPercentage >= 40) {
      statusKey = 'farm_health_moderate';
      statusColor = Colors.orange;
      statusIcon = Icons.sentiment_neutral;
    } else if (healthPercentage >= 20) {
      statusKey = 'farm_health_poor';
      statusColor = Colors.deepOrange;
      statusIcon = Icons.sentiment_dissatisfied;
    } else {
      statusKey = 'farm_health_critical';
      statusColor = Colors.red;
      statusIcon = Icons.sentiment_very_dissatisfied;
    }

    // Find most prevalent disease
    String? topDisease;
    int topDiseaseCount = 0;
    for (final disease in TrackingModels.diseaseLabels) {
      final count = overallCounts[disease] ?? 0;
      if (count > topDiseaseCount) {
        topDiseaseCount = count;
        topDisease = disease;
      }
    }

    // Calculate trend if chart data is available
    double? overallChange;
    String? trendKey;
    Color? trendColor;
    IconData? trendIcon;
    String? changeValue;

    if (chartData.length >= 2) {
      final halfPoint = (chartData.length / 2).ceil();
      double firstHalfTotal = 0;
      double secondHalfTotal = 0;

      for (int i = 0; i < halfPoint; i++) {
        firstHalfTotal += (chartData[i]['healthy'] as num?)?.toDouble() ?? 0;
      }
      for (int i = halfPoint; i < chartData.length; i++) {
        secondHalfTotal += (chartData[i]['healthy'] as num?)?.toDouble() ?? 0;
      }

      final firstHalfAvg = firstHalfTotal / halfPoint;
      final secondHalfAvg = secondHalfTotal / (chartData.length - halfPoint);
      overallChange = secondHalfAvg - firstHalfAvg;

      changeValue =
          '${overallChange >= 0 ? '+' : ''}${overallChange.toStringAsFixed(1)}%';

      if (overallChange > 5) {
        trendKey = 'trend_improving';
        trendColor = Colors.green;
        trendIcon = Icons.trending_up;
      } else if (overallChange < -5) {
        trendKey = 'trend_declining';
        trendColor = Colors.red;
        trendIcon = Icons.trending_down;
      } else {
        trendKey = 'trend_stable';
        trendColor = Colors.blue;
        trendIcon = Icons.trending_flat;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [statusColor.withOpacity(0.1), statusColor.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Health Status Section
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(statusIcon, color: statusColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('farm_health_status'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      tr(statusKey),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$healthPercentage%',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          // Overall Health Trend Section (if available)
          if (chartData.length >= 2 && trendKey != null && trendColor != null && trendIcon != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: trendColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(trendIcon, color: trendColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('overall_health_trend'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          tr(trendKey),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: trendColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: trendColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      changeValue!,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: trendColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      color: Colors.amber[700],
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      tr('recommendations'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (healthPercentage >= 80) ...[
                  _buildRecommendationItem(tr('rec_excellent_maintain')),
                  _buildRecommendationItem(tr('rec_excellent_monitor')),
                ] else if (healthPercentage >= 60) ...[
                  _buildRecommendationItem(tr('rec_good_continue')),
                  if (topDisease != null)
                    _buildRecommendationItem(
                      tr(
                        'rec_good_watch',
                        namedArgs: {
                          'disease': TrackingModels.formatLabel(topDisease),
                        },
                      ),
                    ),
                ] else if (healthPercentage >= 40) ...[
                  _buildRecommendationItem(tr('rec_moderate_action')),
                  if (topDisease != null)
                    _buildRecommendationItem(
                      tr(
                        'rec_moderate_treat',
                        namedArgs: {
                          'disease': TrackingModels.formatLabel(topDisease),
                        },
                      ),
                    ),
                  _buildRecommendationItem(tr('rec_moderate_expert')),
                ] else if (healthPercentage >= 20) ...[
                  _buildRecommendationItem(tr('rec_poor_urgent')),
                  if (topDisease != null)
                    _buildRecommendationItem(
                      tr(
                        'rec_poor_focus',
                        namedArgs: {
                          'disease': TrackingModels.formatLabel(topDisease),
                        },
                      ),
                    ),
                  _buildRecommendationItem(tr('rec_poor_consult')),
                ] else ...[
                  _buildRecommendationItem(tr('rec_critical_immediate')),
                  _buildRecommendationItem(tr('rec_critical_expert')),
                  _buildRecommendationItem(tr('rec_critical_isolate')),
                ],
                // Add trend recommendation if available
                if (chartData.length >= 2 && overallChange != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        overallChange < -5
                            ? Icons.warning_amber_rounded
                            : Icons.check_circle_outline,
                        color:
                            overallChange < -5
                                ? Colors.orange[700]
                                : Colors.green[700],
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          overallChange > 5
                              ? tr('trend_rec_improving')
                              : overallChange < -5
                              ? tr('trend_rec_declining')
                              : tr('trend_rec_stable'),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• ',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCombinedTrendAnalysis(
    List<Map<String, dynamic>> chartData,
    Map<String, int> overallCounts,
  ) {
    if (chartData.length < 2) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Disease-Specific Section
          _buildDiseaseSpecificSection(chartData, overallCounts),
        ],
      ),
    );
  }


  Widget _buildDiseaseSpecificSection(
    List<Map<String, dynamic>> chartData,
    Map<String, int> overallCounts,
  ) {
    if (chartData.length < 2) return const SizedBox.shrink();

    // Analyze each disease trend
    Map<String, Map<String, dynamic>> diseaseAnalysis = {};

    for (final disease in TrackingModels.diseaseLabels) {
      final count = overallCounts[disease] ?? 0;
      if (count == 0) continue; // Skip diseases with no occurrences

      // Calculate first half vs second half average for this disease
      final halfPoint = (chartData.length / 2).ceil();
      double firstHalfTotal = 0;
      double secondHalfTotal = 0;

      for (int i = 0; i < halfPoint; i++) {
        firstHalfTotal += (chartData[i][disease] as num?)?.toDouble() ?? 0;
      }
      for (int i = halfPoint; i < chartData.length; i++) {
        secondHalfTotal += (chartData[i][disease] as num?)?.toDouble() ?? 0;
      }

      final firstHalfAvg = firstHalfTotal / halfPoint;
      final secondHalfAvg = secondHalfTotal / (chartData.length - halfPoint);
      final change = secondHalfAvg - firstHalfAvg;

      diseaseAnalysis[disease] = {
        'change': change,
        'firstHalf': firstHalfAvg,
        'secondHalf': secondHalfAvg,
        'count': count,
      };
    }

    if (diseaseAnalysis.isEmpty) return const SizedBox.shrink();

    // Sort diseases by absolute change (most significant changes first)
    final sortedDiseases =
        diseaseAnalysis.entries.toList()..sort(
          (a, b) => b.value['change'].abs().compareTo(a.value['change'].abs()),
        );

    // Get top concerning diseases (increasing or high presence)
    List<MapEntry<String, Map<String, dynamic>>> concerningDiseases = [];
    List<MapEntry<String, Map<String, dynamic>>> improvingDiseases = [];

    for (final entry in sortedDiseases) {
      final change = entry.value['change'] as double;
      if (change > 3) {
        concerningDiseases.add(entry);
      } else if (change < -3) {
        improvingDiseases.add(entry);
      }
    }

    // If no significant changes, don't show this section
    if (concerningDiseases.isEmpty && improvingDiseases.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.purple[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.coronavirus_outlined,
                color: Colors.purple[700],
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('disease_specific_trends'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  Text(
                    tr('disease_specific_trends_subtitle'),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Concerning diseases (increasing)
        if (concerningDiseases.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.red[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.trending_up, color: Colors.red[700], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      tr('diseases_increasing'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.red[900],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...concerningDiseases.take(3).map((entry) {
                  final diseaseName = TrackingModels.formatLabel(entry.key);
                  final change = entry.value['change'] as double;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: TrackingModels.diseaseColors[entry.key],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            diseaseName,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[800],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Text(
                          '+${change.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.red[700],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.orange[700],
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          concerningDiseases.length == 1
                              ? tr(
                                'disease_trend_rec_single',
                                namedArgs: {
                                  'disease': TrackingModels.formatLabel(
                                    concerningDiseases[0].key,
                                  ),
                                },
                              )
                              : tr('disease_trend_rec_multiple'),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[800],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],

        // Improving diseases (decreasing)
        if (improvingDiseases.isNotEmpty) ...[
          if (concerningDiseases.isNotEmpty) const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.green[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.trending_down,
                      color: Colors.green[700],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      tr('diseases_decreasing'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[900],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...improvingDiseases.take(3).map((entry) {
                  final diseaseName = TrackingModels.formatLabel(entry.key);
                  final change = entry.value['change'] as double;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: TrackingModels.diseaseColors[entry.key],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            diseaseName,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[800],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Text(
                          '${change.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        color: Colors.green[700],
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          tr('disease_trend_rec_decreasing'),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[800],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDiseaseRow(
    String name,
    int count,
    int total,
    Color color,
    IconData icon,
  ) {
    final percentage = total > 0 ? (count / total * 100) : 0.0;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 4),
              Stack(
                children: [
                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: percentage / 100,
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              '${percentage.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showSessionDetails(Map<String, dynamic> session) {
    final images = session['images'] as List? ?? [];
    final source = TrackingModels.getSourceDisplayText(session['source']);
    final sourceColor = TrackingModels.getSourceColor(session['source']);
    final expertReview = session['expertReview'] as Map<String, dynamic>?;
    final expertName = session['expertName'] as String?;

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
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
                          color: sourceColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          source,
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
                          // Bounding boxes toggle removed per request
                          Text(
                            '${tr('date')} ${session['date'] != null ? DateFormat('MMM d, yyyy – h:mma').format(DateTime.parse(session['date'])) : tr('unknown')}',
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
                          // Show expert review if available
                          if (expertReview != null &&
                              (session['source'] == 'completed' ||
                                  session['source'] == 'reviewed'))
                            Container(
                              margin: const EdgeInsets.only(top: 16),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.green.withOpacity(0.3),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.check_circle,
                                        color: Colors.green,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        tr('expert_review'),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (expertName != null &&
                                      expertName.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      tr(
                                        'reviewed_by',
                                        namedArgs: {'name': expertName},
                                      ),
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                  if (expertReview['comment'] != null) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      tr('comment'),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      expertReview['comment'],
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ],
                                  if (expertReview['treatmentPlan'] !=
                                      null) ...[
                                    const SizedBox(height: 12),
                                    Text(
                                      tr('treatment_plan'),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    if (expertReview['treatmentPlan']['recommendations'] !=
                                        null) ...[
                                      for (var rec
                                          in expertReview['treatmentPlan']['recommendations']) ...[
                                        Text(
                                          '• ${rec['treatment'] ?? tr('no_treatment_specified')}',
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ],
                                    ],
                                    if (expertReview['treatmentPlan']['precautions'] !=
                                        null) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        '${tr('precautions')} ${expertReview['treatmentPlan']['precautions']}',
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ],
                                  ],
                                ],
                              ),
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
                                    SizedBox(
                                      width: 320,
                                      height: 180,
                                      child: Stack(
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            child:
                                                images[idx]['imageUrl'] !=
                                                            null &&
                                                        (images[idx]['imageUrl']
                                                                    as String?)
                                                                ?.isNotEmpty ==
                                                            true
                                                    ? CachedNetworkImage(
                                                      imageUrl:
                                                          images[idx]['imageUrl'],
                                                      width: 320,
                                                      height: 180,
                                                      fit: BoxFit.cover,
                                                      placeholder:
                                                          (
                                                            context,
                                                            url,
                                                          ) => const Center(
                                                            child:
                                                                CircularProgressIndicator(),
                                                          ),
                                                      errorWidget:
                                                          (
                                                            context,
                                                            url,
                                                            error,
                                                          ) => const Icon(
                                                            Icons.broken_image,
                                                            size: 40,
                                                            color: Colors.grey,
                                                          ),
                                                    )
                                                    : images[idx]['imagePath'] !=
                                                        null
                                                    ? Image.file(
                                                      File(
                                                        images[idx]['imagePath'],
                                                      ),
                                                      width: 320,
                                                      height: 180,
                                                      fit: BoxFit.cover,
                                                    )
                                                    : Container(
                                                      width: 320,
                                                      height: 180,
                                                      color: Colors.grey[300],
                                                      child: const Icon(
                                                        Icons.image,
                                                        color: Colors.grey,
                                                      ),
                                                    ),
                                          ),
                                          // Bounding boxes overlay removed
                                          /* if (showBoundingBoxes)
                                             Builder(
                                              builder: (context) {
                                                final imgMap =
                                                    images[idx] as Map;
                                                final double? originalW =
                                                    (imgMap['imageWidth']
                                                            is num)
                                                        ? (imgMap['imageWidth']
                                                                as num)
                                                            .toDouble()
                                                        : null;
                                                final double? originalH =
                                                    (imgMap['imageHeight']
                                                            is num)
                                                        ? (imgMap['imageHeight']
                                                                as num)
                                                            .toDouble()
                                                        : null;
                                                final List results =
                                                    (imgMap['results']
                                                        as List?) ??
                                                    [];
                                                if (originalW == null ||
                                                    originalH == null ||
                                                    results.isEmpty) {
                                                  return const SizedBox.shrink();
                                                }
                                                // Compute displayed size and offset for BoxFit.cover on 320x180
                                                const double widgetW = 320;
                                                const double widgetH = 180;
                                                final double widgetAspect =
                                                    widgetW / widgetH;
                                                final double imageAspect =
                                                    originalW / originalH;
                                                double displayW,
                                                    displayH,
                                                    dx = 0,
                                                    dy = 0;
                                                if (widgetAspect >
                                                    imageAspect) {
                                                  displayW = widgetW;
                                                  displayH =
                                                      widgetW / imageAspect;
                                                  dy = (widgetH - displayH) / 2;
                                                } else {
                                                  displayH = widgetH;
                                                  displayW =
                                                      widgetH * imageAspect;
                                                  dx = (widgetW - displayW) / 2;
                                                }
                                                final boxes =
                                                    results
                                                        .whereType<Map>()
                                                        .where(
                                                          (r) =>
                                                              r['boundingBox']
                                                                  is Map,
                                                        )
                                                        .cast<
                                                          Map<String, dynamic>
                                                        >()
                                                        .toList();
                                                return CustomPaint(
                                                  painter: _MapBoxPainter(
                                                    boxes: boxes,
                                                    originalImageSize: Size(
                                                      originalW,
                                                      originalH,
                                                    ),
                                                    displayedImageSize: Size(
                                                      displayW,
                                                      displayH,
                                                    ),
                                                    displayedImageOffset:
                                                        Offset(dx, dy),
                                                  ),
                                                  size: const Size(
                                                    widgetW,
                                                    widgetH,
                                                  ),
                                                );
                                               },
                                             ), */
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      tr('results'),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    ...((images[idx]['results'] as List?) ?? [])
                                        .map((res) {
                                          final disease =
                                              res['disease'] ?? 'Unknown';
                                          final confidence = res['confidence'];
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 2,
                                            ),
                                            child: Text(
                                              confidence != null
                                                  ? '${TrackingModels.formatLabel(disease)} (${(confidence * 100).toStringAsFixed(1)}%)'
                                                  : TrackingModels.formatLabel(
                                                    disease,
                                                  ),
                                              style: const TextStyle(
                                                fontSize: 15,
                                              ),
                                            ),
                                          );
                                        })
                                        .toList(),
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
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userBox = Hive.box('userBox');
    final userProfile = userBox.get('userProfile');
    final userId = userProfile?['userId'];
    if (userId == null) {
      return Center(child: Text(tr('not_logged_in')));
    }

    // Note: Real-time streams removed; we use a one-time load with offline cache.

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _loadSessionsWithFallback(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.wifi_off, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    tr('offline_mode'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr('showing_cached_data'),
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  ),
                ],
              ),
            ),
          );
        }

        final sessions = snapshot.data ?? [];
        // Note: Do not early-return on empty sessions; allow selector to show

        // Sort sessions by date descending (most recent first)
        sessions.sort((a, b) {
          final dateA =
              a['date'] != null && a['date'].toString().isNotEmpty
                  ? DateTime.tryParse(a['date'].toString())
                  : null;
          final dateB =
              b['date'] != null && b['date'].toString().isNotEmpty
                  ? DateTime.tryParse(b['date'].toString())
                  : null;
          if (dateA == null && dateB == null) return 0;
          if (dateA == null) return 1;
          if (dateB == null) return -1;
          return dateB.compareTo(dateA); // Descending
        });

        // Save to Hive for offline use
        Hive.openBox('trackingBox').then((box) => box.put('scans', sessions));

        final filteredSessions = TrackingModels.filterSessions(
          sessions,
          _selectedRangeIndex,
          customStart: _customStartDate,
          customEnd: _customEndDate,
          monthlyYear: _monthlyYear,
          monthlyMonth: _monthlyMonth,
        );
        final flatScans = TrackingModels.flattenScans(filteredSessions);
        final chartData = TrackingChart.chartDataPercentBinned(
          flatScans,
          _selectedRangeIndex,
          customStart: _customStartDate,
          customEnd: _customEndDate,
          monthlyYear: _monthlyYear,
          monthlyMonth: _monthlyMonth,
          bins: 6,
        );
        final overallCounts = TrackingModels.overallHealthyAndDiseases(
          flatScans,
        );
        final healthy = overallCounts['healthy'] ?? 0;
        final totalDiseased = TrackingModels.diseaseLabels.fold(
          0,
          (sum, d) => sum + (overallCounts[d] ?? 0),
        );
        final total = healthy + totalDiseased;

        return Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Time range selector
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 20,
                          color: Colors.green[700],
                        ),
                        const SizedBox(width: 12),
                        Text(
                          tr('time_range'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButton<int>(
                            value: _selectedRangeIndex,
                            isExpanded: true,
                            underline: const SizedBox.shrink(),
                            items: [
                              DropdownMenuItem(
                                value: 0,
                                child: Text(
                                  _getTimeRangeLabel(0),
                                  style: const TextStyle(fontSize: 15),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 1,
                                child: Text(
                                  _getTimeRangeLabel(1),
                                  style: const TextStyle(fontSize: 15),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 2,
                                child: Text(
                                  _getTimeRangeLabel(2),
                                  style: const TextStyle(fontSize: 15),
                                ),
                              ),
                            ],
                            onChanged: (i) async {
                              if (i == null) return;
                              if (i == 1) {
                                // Show custom month-year picker
                                final now = DateTime.now();
                                final picked = await _showMonthYearPicker(
                                  context: context,
                                  initialDate: DateTime(
                                    _monthlyYear ?? now.year,
                                    _monthlyMonth ?? now.month,
                                    1,
                                  ),
                                  firstDate: DateTime(2020, 1),
                                  lastDate: DateTime(now.year, now.month),
                                );
                                if (picked != null) {
                                  setState(() {
                                    _monthlyYear = picked.year;
                                    _monthlyMonth = picked.month;
                                    _selectedRangeIndex = 1;
                                  });
                                  await _saveSelectedRangeIndex(1);
                                  await _saveMonthly(picked.year, picked.month);
                                } else {
                                  // User cancelled, revert to previous selection
                                  setState(() {});
                                }
                              } else if (i == 2) {
                                await _pickCustomRange();
                                // Force rebuild to show updated selection
                                setState(() {});
                              } else {
                                setState(() => _selectedRangeIndex = i);
                                await _saveSelectedRangeIndex(i);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Scan Status Summary
                  Builder(
                    builder: (context) {
                      int pendingCount = 0;
                      int trackingCount = 0;
                      int completedCount = 0;

                      for (final session in filteredSessions) {
                        final status = session['status'] ?? session['source'];
                        if (status == 'pending' || status == 'pending_review') {
                          pendingCount++;
                        } else if (status == 'expert_review' ||
                            status == 'tracking') {
                          trackingCount++;
                        } else if (status == 'completed' ||
                            status == 'reviewed') {
                          completedCount++;
                        }
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.analytics_outlined,
                                  color: Colors.green[700],
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  tr('scan_summary'),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[800],
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green[50],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    tr(
                                      'total_count',
                                      namedArgs: {
                                        'count':
                                            filteredSessions.length.toString(),
                                      },
                                    ),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green[700],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildStatusCard(
                                    tr('pending'),
                                    pendingCount,
                                    Icons.schedule,
                                    Colors.orange,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildStatusCard(
                                    tr('tracking'),
                                    trackingCount,
                                    Icons.track_changes,
                                    Colors.blue,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildStatusCard(
                                    tr('completed'),
                                    completedCount,
                                    Icons.check_circle,
                                    Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  if (filteredSessions.isEmpty) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.grey),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              tr('no_tracked_scans'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  // Disease Breakdown Summary
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey[200]!, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.pie_chart,
                                color: Colors.green[700],
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tr('farm_health_breakdown'),
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                  Text(
                                    _getTimeRangeLabel(_selectedRangeIndex),
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                tr(
                                  'total_count',
                                  namedArgs: {'count': total.toString()},
                                ),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Healthy count
                        _buildDiseaseRow(
                          'Healthy',
                          healthy,
                          total,
                          TrackingModels.diseaseColors['healthy']!,
                          Icons.check_circle,
                        ),
                        const SizedBox(height: 12),
                        // Individual diseases
                        for (final disease in TrackingModels.diseaseLabels)
                          if (overallCounts[disease] != null &&
                              overallCounts[disease]! > 0) ...[
                            _buildDiseaseRow(
                              TrackingModels.formatLabel(disease),
                              overallCounts[disease]!,
                              total,
                              TrackingModels.diseaseColors[disease]!,
                              Icons.warning_rounded,
                            ),
                            const SizedBox(height: 12),
                          ],
                      ],
                    ),
                  ),
                  // Health Insights (combined with trend)
                  if (total > 0)
                    _buildHealthInsights(
                      healthy,
                      totalDiseased,
                      total,
                      overallCounts,
                      chartData,
                    ),
                  // Trend Bar Chart
                  Text(
                    tr('farm_health_trend'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 260,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child:
                        chartData.isEmpty
                            ? Center(child: Text(tr('not_enough_data')))
                            : LineChart(
                              LineChartData(
                                minY: 0,
                                maxY: 100,
                                minX: 0,
                                maxX:
                                    chartData.isEmpty
                                        ? 0
                                        : (chartData.length - 1).toDouble(),
                                lineTouchData: LineTouchData(
                                  touchTooltipData: LineTouchTooltipData(
                                    tooltipBgColor: const Color.fromARGB(
                                      255,
                                      255,
                                      255,
                                      255,
                                    ),
                                    tooltipRoundedRadius: 8,
                                    tooltipPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    tooltipBorder: BorderSide(
                                      color: Colors.grey[300]!,
                                      width: 1.5,
                                    ),
                                    getTooltipItems: (touchedSpots) {
                                      return touchedSpots.map((spot) {
                                        final percentage = spot.y
                                            .toStringAsFixed(1);
                                        // Get disease name from bar index
                                        String diseaseName;
                                        Color lineColor;

                                        if (spot.barIndex == 0) {
                                          // First line is healthy
                                          diseaseName = 'Healthy';
                                          lineColor =
                                              TrackingModels
                                                  .diseaseColors['healthy']!;
                                        } else {
                                          // Other lines are diseases
                                          final diseaseIndex =
                                              spot.barIndex - 1;
                                          if (diseaseIndex <
                                              TrackingModels
                                                  .diseaseLabels
                                                  .length) {
                                            final diseaseKey =
                                                TrackingModels
                                                    .diseaseLabels[diseaseIndex];
                                            diseaseName =
                                                TrackingModels.formatLabel(
                                                  diseaseKey,
                                                );
                                            lineColor =
                                                TrackingModels
                                                    .diseaseColors[diseaseKey]!;
                                          } else {
                                            diseaseName = 'Unknown';
                                            lineColor = Colors.grey;
                                          }
                                        }

                                        return LineTooltipItem(
                                          '$diseaseName\n$percentage%',
                                          TextStyle(
                                            color: lineColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        );
                                      }).toList();
                                    },
                                  ),
                                ),
                                lineBarsData: [
                                  // Healthy line
                                  LineChartBarData(
                                    spots: [
                                      for (int i = 0; i < chartData.length; i++)
                                        FlSpot(
                                          i.toDouble(),
                                          (chartData[i]['healthy'] as num?)
                                                  ?.toDouble() ??
                                              0,
                                        ),
                                    ],
                                    isCurved: true,
                                    color:
                                        TrackingModels.diseaseColors['healthy'],
                                    barWidth: 4,
                                    dotData: FlDotData(show: true),
                                    belowBarData: BarAreaData(show: false),
                                  ),
                                  // Percentage disease lines
                                  for (final d in TrackingModels.diseaseLabels)
                                    LineChartBarData(
                                      spots: [
                                        for (
                                          int i = 0;
                                          i < chartData.length;
                                          i++
                                        )
                                          FlSpot(
                                            i.toDouble(),
                                            (chartData[i][d] as num?)
                                                    ?.toDouble() ??
                                                0,
                                          ),
                                      ],
                                      isCurved: true,
                                      color: TrackingModels.diseaseColors[d],
                                      barWidth: 4,
                                      dotData: FlDotData(show: true),
                                      belowBarData: BarAreaData(show: false),
                                    ),
                                ],
                                titlesData: FlTitlesData(
                                  show: true,
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 42,
                                      interval: 1,
                                      getTitlesWidget: (value, meta) {
                                        if (value < 0 ||
                                            value >= chartData.length) {
                                          return const SizedBox.shrink();
                                        }
                                        // Show only integer tick positions (0..5)
                                        if (value != value.roundToDouble()) {
                                          return const SizedBox.shrink();
                                        }
                                        final group =
                                            chartData[value.toInt()]['group']
                                                as String;
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            top: 8.0,
                                          ),
                                          child: Text(
                                            group,
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 36,
                                      interval: 25,
                                      getTitlesWidget: (value, meta) {
                                        if (value % 25 == 0) {
                                          return Text(
                                            '${value.toInt()}%',
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          );
                                        }
                                        return const SizedBox.shrink();
                                      },
                                    ),
                                  ),
                                  topTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  rightTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                ),
                                gridData: const FlGridData(
                                  show: true,
                                  horizontalInterval: 25,
                                  drawVerticalLine: false,
                                ),
                                borderData: FlBorderData(show: false),
                              ),
                            ),
                  ),
                  const SizedBox(height: 12),
                  // Legend
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        TrackingChart.buildLegendItem(
                          TrackingModels.diseaseColors['healthy']!,
                          TrackingModels.formatLabel('healthy'),
                        ),
                        for (final d in TrackingModels.diseaseLabels)
                          TrackingChart.buildLegendItem(
                            TrackingModels.diseaseColors[d]!,
                            TrackingModels.formatLabel(d),
                          ),
                      ],
                    ),
                  ),
                  // Combined Trend Analysis
                  if (chartData.length >= 2)
                    _buildCombinedTrendAnalysis(chartData, overallCounts),
                  const SizedBox(height: 32),
                  Text(
                    tr('history'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr(
                      'scans_from_period',
                      namedArgs: {
                        'period': _getTimeRangeLabel(_selectedRangeIndex),
                      },
                    ),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredSessions.length,
                    itemBuilder: (context, index) {
                      final session = filteredSessions[index];
                      final date =
                          session['date'] != null
                              ? DateFormat(
                                'MMM d, yyyy – h:mma',
                              ).format(DateTime.parse(session['date']))
                              : '';
                      final images = session['images'] as List? ?? [];

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: InkWell(
                          onTap: () => _showSessionDetails(session),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            isThreeLine: true,
                            leading:
                                images.isNotEmpty &&
                                        images[0]['imageUrl'] != null &&
                                        (images[0]['imageUrl'] as String)
                                            .isNotEmpty
                                    ? CachedNetworkImage(
                                      imageUrl: images[0]['imageUrl'],
                                      width: 56,
                                      height: 56,
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
                                    )
                                    : images.isNotEmpty &&
                                        images[0]['imagePath'] != null
                                    ? Image.file(
                                      File(images[0]['imagePath']),
                                      width: 56,
                                      height: 56,
                                      fit: BoxFit.cover,
                                    )
                                    : const Icon(Icons.image, size: 56),
                            title: Text(
                              tr('session', namedArgs: {'date': date}),
                            ),
                            subtitle: Text(
                              tr(
                                'image_count',
                                namedArgs: {'count': images.length.toString()},
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (session['source'] != 'completed' &&
                                    session['source'] != 'reviewed')
                                  InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder:
                                            (context) => AlertDialog(
                                              title: Text(tr('delete_session')),
                                              content: Text(
                                                tr('delete_session_confirm'),
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed:
                                                      () => Navigator.of(
                                                        context,
                                                      ).pop(false),
                                                  child: Text(tr('cancel')),
                                                ),
                                                TextButton(
                                                  onPressed:
                                                      () => Navigator.of(
                                                        context,
                                                      ).pop(true),
                                                  child: Text(
                                                    tr('delete'),
                                                    style: const TextStyle(
                                                      color: Colors.red,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                      );
                                      if (confirm == true) {
                                        final images =
                                            (session['images'] as List?) ?? [];
                                        bool imageDeleteError = false;
                                        for (final img in images) {
                                          try {
                                            final storagePath =
                                                img['storagePath'] as String?;
                                            final imageUrl =
                                                img['imageUrl'] as String?;

                                            if (storagePath != null &&
                                                storagePath.isNotEmpty) {
                                              // Preferred: delete by known storage path
                                              await FirebaseStorage.instance
                                                  .ref()
                                                  .child(storagePath)
                                                  .delete();
                                            } else if (imageUrl != null &&
                                                imageUrl.isNotEmpty) {
                                              // If it's a Firebase URL, delete via URL
                                              if (imageUrl.startsWith(
                                                    'gs://',
                                                  ) ||
                                                  imageUrl.startsWith(
                                                    'https://firebasestorage.googleapis.com',
                                                  )) {
                                                await FirebaseStorage.instance
                                                    .refFromURL(imageUrl)
                                                    .delete();
                                              } else {
                                                // Legacy Supabase cleanup (best-effort)
                                                final uri = Uri.parse(imageUrl);
                                                final segments =
                                                    uri.pathSegments;
                                                final bucketIndex = segments
                                                    .indexOf('mangosense');
                                                if (bucketIndex != -1 &&
                                                    bucketIndex + 1 <
                                                        segments.length) {
                                                  final supabase =
                                                      Supabase.instance.client;
                                                  final supabasePath = segments
                                                      .sublist(bucketIndex + 1)
                                                      .join('/');
                                                  await supabase.storage
                                                      .from('mangosense')
                                                      .remove([supabasePath]);
                                                }
                                              }
                                            }
                                          } catch (e) {
                                            imageDeleteError = true;
                                          }
                                        }
                                        try {
                                          if (session['source'] == 'pending') {
                                            final docId =
                                                session['sessionId'] ??
                                                session['id'];
                                            await FirebaseFirestore.instance
                                                .collection('scan_requests')
                                                .doc(docId)
                                                .delete();
                                          } else {
                                            final docId =
                                                session['sessionId'] ??
                                                session['id'];
                                            await FirebaseFirestore.instance
                                                .collection('tracking')
                                                .doc(docId)
                                                .delete();
                                          }
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  imageDeleteError
                                                      ? tr(
                                                        'session_deleted_with_errors',
                                                      )
                                                      : tr('session_deleted'),
                                                ),
                                                backgroundColor:
                                                    imageDeleteError
                                                        ? Colors.orange
                                                        : Colors.red,
                                              ),
                                            );
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  tr(
                                                    'failed_to_delete_session',
                                                    args: [e.toString()],
                                                  ),
                                                ),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        }
                                      }
                                    },
                                    child: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                      size: 22,
                                    ),
                                  ),
                                if (session['source'] != 'completed' &&
                                    session['source'] != 'reviewed')
                                  const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: TrackingModels.getSourceColor(
                                      session['source'],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    TrackingModels.getSourceDisplayText(
                                      session['source'],
                                    ),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// Bounding box painter removed as overlay option is disabled
