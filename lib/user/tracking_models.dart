import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class TrackingModels {
  // Use the same color mapping as DetectionPainter
  static const Map<String, Color> diseaseColors = {
    'anthracnose': Colors.orange,
    'backterial_blackspot': Colors.purple,
    'bacterial_blackspot': Colors.purple,
    'dieback': Colors.red,
    'healthy': Color.fromARGB(255, 2, 119, 252),
    'powdery_mildew': Color.fromARGB(255, 9, 46, 2),
    'tip_burn': Colors.brown,
    'Unknown': Colors.grey,
  };

  // List of real diseases (excluding tip burn/unknown)
  // Note: bacterial_blackspot is normalized to backterial_blackspot when counting
  static const List<String> diseaseLabels = [
    'anthracnose',
    'backterial_blackspot', // This represents both backterial_blackspot and bacterial_blackspot
    'powdery_mildew',
    'dieback',
  ];

  static const List<Map<String, dynamic>> timeRanges = [
    {'label': 'Last 7 Days', 'days': 7},
    {'label': 'Monthly', 'days': 30},
    {'label': 'Custom', 'days': null},
  ];

  static bool isRealDisease(String label) {
    final l = label.toLowerCase();
    // Handle both spellings of bacterial black spot
    if (l == 'bacterial_blackspot' || l == 'backterial_blackspot') {
      return true;
    }
    return diseaseLabels.contains(l);
  }

  static String getSourceDisplayText(String? source) {
    switch (source) {
      case 'expert_review':
        return tr('reviewing');
      case 'completed':
        return tr('completed');
      case 'reviewed':
        return tr('reviewed');
      case 'pending':
        return tr('pending');
      case 'pending_review':
        return tr('pending_review');
      default:
        return tr('tracking');
    }
  }

  static Color getSourceColor(String? source) {
    switch (source) {
      case 'expert_review':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      case 'reviewed':
        return Colors.green;
      case 'pending':
        return Colors.orangeAccent;
      case 'pending_review':
        return Colors.yellow;
      default:
        return Colors.blue;
    }
  }

  static String formatLabel(String label) {
    switch (label.toLowerCase()) {
      case 'backterial_blackspot':
      case 'bacterial_blackspot':
        return 'Bacterial black spot';
      case 'powdery_mildew':
        return 'Powdery Mildew';
      case 'tip_burn':
      case 'tip burn':
        return 'Burnt leaf';
      case 'healthy':
        return 'Healthy';
      case 'dieback':
        return 'Dieback';
      case 'anthracnose':
        return 'Anthracnose';
      default:
        return label.isNotEmpty
            ? label[0].toUpperCase() + label.substring(1)
            : 'Unknown';
    }
  }

  static List<Map<String, dynamic>> filterSessions(
    List<Map<String, dynamic>> sessions,
    int selectedRangeIndex, {
    DateTime? customStart,
    DateTime? customEnd,
    int? monthlyYear,
    int? monthlyMonth,
  }) {
    if (sessions.isEmpty) return [];
    final now = DateTime.now();

    // Index 0: Last 7 Days
    if (selectedRangeIndex == 0) {
      final startInclusive = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 6)); // 7 days inclusive
      final endInclusive = DateTime(now.year, now.month, now.day);
      return sessions.where((session) {
        final dateStr = session['date'];
        if (dateStr == null) return false;
        final parsed = DateTime.tryParse(dateStr);
        if (parsed == null) return false;
        final d = DateTime(parsed.year, parsed.month, parsed.day);
        return !d.isBefore(startInclusive) && !d.isAfter(endInclusive);
      }).toList();
    }

    // Index 1: Monthly (with month/year picker)
    if (selectedRangeIndex == 1) {
      if (monthlyYear != null && monthlyMonth != null) {
        final startInclusive = DateTime(monthlyYear, monthlyMonth, 1);
        final endInclusive = DateTime(monthlyYear, monthlyMonth + 1, 0);
        return sessions.where((session) {
          final dateStr = session['date'];
          if (dateStr == null) return false;
          final parsed = DateTime.tryParse(dateStr);
          if (parsed == null) return false;
          final d = DateTime(parsed.year, parsed.month, parsed.day);
          return !d.isBefore(startInclusive) && !d.isAfter(endInclusive);
        }).toList();
      }
      // If no month/year selected, show all
      return List<Map<String, dynamic>>.from(sessions);
    }

    // Index 2: Custom range
    if (selectedRangeIndex == 2) {
      if (customStart == null || customEnd == null) {
        return List<Map<String, dynamic>>.from(sessions);
      }
      final startInclusive = DateTime(
        customStart.year,
        customStart.month,
        customStart.day,
      );
      final endInclusive = DateTime(
        customEnd.year,
        customEnd.month,
        customEnd.day,
      );
      return sessions.where((session) {
        final dateStr = session['date'];
        if (dateStr == null) return false;
        final parsed = DateTime.tryParse(dateStr);
        if (parsed == null) return false;
        final d = DateTime(parsed.year, parsed.month, parsed.day);
        return !d.isBefore(startInclusive) && !d.isAfter(endInclusive);
      }).toList();
    }

    // Default: show all
    return List<Map<String, dynamic>>.from(sessions);
  }

  static Map<String, Map<String, int>> monthlyHealthyAndDiseases(
    List<Map<String, dynamic>> scans,
  ) {
    final Map<String, Map<String, int>> result = {};
    
    // Group scans by month and session to count unique diseases per report
    final Map<String, Map<String, Set<String>>> diseasesByMonthAndSession = {};
    
    for (final scan in scans) {
      final date = scan['date'] ?? '';
      final label = (scan['disease'] ?? '').toLowerCase();
      if (date.isEmpty || label == 'tip_burn' || label == 'unknown') continue;
      
      final month = date.substring(0, 7); // 'YYYY-MM'
      final sessionKey = date; // Use date as session identifier
      
      diseasesByMonthAndSession.putIfAbsent(month, () => {});
      diseasesByMonthAndSession[month]!.putIfAbsent(sessionKey, () => <String>{});
      
      if (label == 'healthy') {
        diseasesByMonthAndSession[month]![sessionKey]!.add('healthy');
      } else if (isRealDisease(label)) {
        // Normalize bacterial black spot to backterial_blackspot for consistency
        final normalizedLabel = (label == 'bacterial_blackspot' || label == 'backterial_blackspot')
            ? 'backterial_blackspot'
            : label;
        diseasesByMonthAndSession[month]![sessionKey]!.add(normalizedLabel);
      }
    }
    
    // Initialize result map for each month
    for (final month in diseasesByMonthAndSession.keys) {
      result.putIfAbsent(
        month,
        () => {
          'healthy': 0,
          'backterial_blackspot': 0, // This will also count bacterial_blackspot after normalization
          ...{for (var d in diseaseLabels.where((d) => d != 'backterial_blackspot')) d: 0},
        },
      );
    }
    
    // Count each unique disease once per session per month
    for (final monthEntry in diseasesByMonthAndSession.entries) {
      final month = monthEntry.key;
      for (final diseases in monthEntry.value.values) {
        for (final disease in diseases) {
          // Normalize bacterial_blackspot to backterial_blackspot for counting
          final normalizedDisease = (disease == 'bacterial_blackspot' || disease == 'backterial_blackspot')
              ? 'backterial_blackspot'
              : disease;
          result[month]![normalizedDisease] = (result[month]![normalizedDisease] ?? 0) + 1;
        }
      }
    }
    
    return result;
  }

  static Map<String, int> overallHealthyAndDiseases(
    List<Map<String, dynamic>> scans,
  ) {
    final Map<String, int> result = {
      'healthy': 0,
      'backterial_blackspot': 0, // This will also count bacterial_blackspot after normalization
      ...{for (var d in diseaseLabels.where((d) => d != 'backterial_blackspot')) d: 0},
    };
    
    // Group scans by session/date to count unique diseases per report
    final Map<String, Set<String>> diseasesBySession = {};
    
    for (final scan in scans) {
      final date = scan['date'] ?? '';
      final label = (scan['disease'] ?? '').toLowerCase();
      if (label == 'tip_burn' || label == 'unknown') continue;
      
      // Use date as session identifier (or could use sessionId if available)
      final sessionKey = date;
      diseasesBySession.putIfAbsent(sessionKey, () => <String>{});
      
      if (label == 'healthy') {
        diseasesBySession[sessionKey]!.add('healthy');
      } else if (isRealDisease(label)) {
        // Normalize bacterial black spot to backterial_blackspot for consistency
        final normalizedLabel = (label == 'bacterial_blackspot' || label == 'backterial_blackspot')
            ? 'backterial_blackspot'
            : label;
        diseasesBySession[sessionKey]!.add(normalizedLabel);
      }
    }
    
    // Count each unique disease once per session
    for (final diseases in diseasesBySession.values) {
      for (final disease in diseases) {
        // Normalize bacterial_blackspot to backterial_blackspot for counting
        final normalizedDisease = (disease == 'bacterial_blackspot' || disease == 'backterial_blackspot')
            ? 'backterial_blackspot'
            : disease;
        result[normalizedDisease] = (result[normalizedDisease] ?? 0) + 1;
      }
    }
    
    return result;
  }

  static List<Map<String, dynamic>> flattenScans(
    List<Map<String, dynamic>> sessions,
  ) {
    final List<Map<String, dynamic>> scans = [];
    for (final session in sessions) {
      final date = session['date'];
      final images = session['images'] as List? ?? [];
      for (final img in images) {
        final results = img['results'] as List? ?? [];
        for (final res in results) {
          scans.add({
            'disease': res['disease'],
            'confidence': res['confidence'],
            'date': date,
            'imagePath': img['imagePath'],
          });
        }
      }
    }
    return scans;
  }
}
