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

  Widget _buildCompactHealthCard(
    int healthy,
    int diseased,
    int total,
    Map<String, int> overallCounts,
  ) {
    if (total == 0) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[300]!, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(Icons.info_outline, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              tr('no_data_available'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              tr('start_scanning_to_see_results'),
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

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

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [statusColor.withOpacity(0.1), statusColor.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.3), width: 1.5),
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
          // Health Status Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(statusIcon, color: statusColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('farm_health_status'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tr(statusKey),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Key Metrics
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '${(healthy / total * 100).toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tr('healthy'),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 40, color: Colors.grey[300]),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '${(diseased / total * 100).toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.red[700],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tr('diseased'),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Most Prevalent Disease
          if (topDisease != null && topDiseaseCount > 0) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange[700],
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('most_common_disease'),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${TrackingModels.formatLabel(topDisease)} (${(topDiseaseCount / diseased * 100).toStringAsFixed(1)}%)',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange[900],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Recommendations
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
                const SizedBox(height: 10),
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

  Widget _buildDistributionChart(Map<String, int> overallCounts, int total) {
    if (total == 0) {
      return const SizedBox.shrink();
    }

    // Prepare pie chart data
    List<PieChartSectionData> sections = [];

    // Add healthy section
    final healthyCount = overallCounts['healthy'] ?? 0;
    if (healthyCount > 0) {
      final percentage = (healthyCount / total * 100);
      sections.add(
        PieChartSectionData(
          value: healthyCount.toDouble(),
          title: percentage >= 8 ? '${percentage.toStringAsFixed(0)}%' : '',
          color: TrackingModels.diseaseColors['healthy'],
          radius: 70,
          titleStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: [Shadow(color: Colors.black26, blurRadius: 2)],
          ),
        ),
      );
    }

    // Add disease sections
    for (final disease in TrackingModels.diseaseLabels) {
      final count = overallCounts[disease] ?? 0;
      if (count > 0) {
        final percentage = (count / total * 100);
        sections.add(
          PieChartSectionData(
            value: count.toDouble(),
            title: percentage >= 8 ? '${percentage.toStringAsFixed(0)}%' : '',
            color: TrackingModels.diseaseColors[disease],
            radius: 70,
            titleStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [Shadow(color: Colors.black26, blurRadius: 2)],
            ),
          ),
        );
      }
    }

    if (sections.isEmpty) {
      return const SizedBox.shrink();
    }

    // Prepare legend items
    List<Map<String, dynamic>> legendItems = [];
    if (healthyCount > 0) {
      legendItems.add({
        'label': TrackingModels.formatLabel('healthy'),
        'count': healthyCount,
        'color': TrackingModels.diseaseColors['healthy']!,
      });
    }
    for (final disease in TrackingModels.diseaseLabels) {
      final count = overallCounts[disease] ?? 0;
      if (count > 0) {
        legendItems.add({
          'label': TrackingModels.formatLabel(disease),
          'count': count,
          'color': TrackingModels.diseaseColors[disease]!,
        });
      }
    }
    legendItems.sort(
      (a, b) => (b['count'] as int).compareTo(a['count'] as int),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!, width: 1.5),
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
          // Header
          Row(
            children: [
              Icon(Icons.pie_chart, color: Colors.blue[700], size: 24),
              const SizedBox(width: 12),
              Text(
                tr('disease_distribution'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Chart - Centered at top
          Center(
            child: SizedBox(
              height: 220,
              width: 220,
              child: PieChart(
                PieChartData(
                  sections: sections,
                  sectionsSpace: 2,
                  centerSpaceRadius: 45,
                  startDegreeOffset: -90,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Legend - Simple list at bottom
          Column(
            children:
                legendItems
                    .map(
                      (item) => _buildLegendItem(
                        item['label'] as String,
                        item['count'] as int,
                        total,
                        item['color'] as Color,
                      ),
                    )
                    .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, int count, int total, Color color) {
    final percentage = (count / total * 100);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Colors.grey[800],
              ),
            ),
          ),
          Text(
            '${percentage.toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
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
    // Build overall detected labels for this report (no per-image percentages)
    final Set<String> overallDetected = <String>{};
    final List<dynamic> diseaseSummary =
        (session['diseaseSummary'] as List?) ?? [];
    const validDiseases = {
      'anthracnose',
      'bacterial blackspot',
      'bacterial_blackspot',
      'backterial_blackspot',
      'powdery mildew',
      'powdery_mildew',
      'dieback',
    };
    bool _isNonMango(String normalized) =>
        normalized == 'banana' ||
        normalized == 'eggplant' ||
        normalized == 'moringa';
    bool _isExcluded(String normalized) =>
        normalized == 'tip burn' ||
        normalized == 'tip_burn' ||
        normalized == 'unknown';
    void _addIfRelevant(String raw) {
      final normalized = raw.toLowerCase().replaceAll('_', ' ').trim();
      final isHealthy = normalized == 'healthy';
      final isValidDisease =
          validDiseases.contains(normalized) ||
          validDiseases.contains(raw.toLowerCase());
      if (_isNonMango(normalized) || _isExcluded(normalized)) return;
      if (isValidDisease || isHealthy) {
        overallDetected.add(TrackingModels.formatLabel(raw));
      }
    }

    if (diseaseSummary.isNotEmpty) {
      for (final e in diseaseSummary) {
        if (e is Map) {
          final raw =
              (e['disease'] ?? e['label'] ?? e['name'] ?? '').toString();
          if (raw.isNotEmpty) _addIfRelevant(raw);
        }
      }
    } else {
      for (final img in images) {
        if (img is Map && img['results'] is List) {
          for (final r in (img['results'] as List)) {
            if (r is Map && r['disease'] != null) {
              _addIfRelevant(r['disease'].toString());
            }
          }
        }
      }
    }

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
                          // Overall Results (single summary for the report)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.blue.withOpacity(0.18),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.fact_check,
                                      color: Colors.blue[700],
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      tr('overall_results'),
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue[800],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  overallDetected.isEmpty
                                      ? tr('no_detections')
                                      : overallDetected.join(', '),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[800],
                                  ),
                                ),
                                // Expert validation (if available on this session)
                                if (expertReview != null &&
                                    expertReview['healthStatus'] != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    '${tr('health_status')}: ${expertReview['healthStatus'] == 'healthy' ? tr('healthy') : tr('not_healthy')}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          expertReview['healthStatus'] ==
                                                  'healthy'
                                              ? Colors.green[700]
                                              : Colors.orange[800],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          for (int idx = 0; idx < images.length; idx++) ...[
                            Card(
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${tr('images')} ${idx + 1}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
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
                  const SizedBox(height: 16),
                  // Compact Health Card
                  _buildCompactHealthCard(
                    healthy,
                    totalDiseased,
                    total,
                    overallCounts,
                  ),
                  const SizedBox(height: 16),
                  // Distribution Chart
                  _buildDistributionChart(overallCounts, total),
                  const SizedBox(height: 24),
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
