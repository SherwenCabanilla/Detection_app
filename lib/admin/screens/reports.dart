import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'reports_list.dart';

class Reports extends StatefulWidget {
  const Reports({Key? key}) : super(key: key);

  @override
  State<Reports> createState() => _ReportsState();
}

class _ReportsState extends State<Reports> {
  String _selectedTimeRange = 'Last 7 Days';

  // Dummy data for testing
  final Map<String, dynamic> _stats = {
    'totalUsers': 1234,
    'totalExperts': 45,
    'totalReports': 567,
    'activeUsers': 890,
    'pendingApprovals': 12,
    'averageResponseTime': '2.5 hours',
  };

  // Dummy previous period data for trend indicators
  final Map<String, dynamic> _previousStats = {
    'totalUsers': 1200,
    'totalReports': 600,
    'activeUsers': 850,
    'pendingApprovals': 15,
    'averageResponseTime': '2.8 hours',
  };

  final List<Map<String, dynamic>> _diseaseStats = [
    {'name': 'Anthracnose', 'count': 156, 'percentage': 0.25},
    {'name': 'Bacterial Blackspot', 'count': 98, 'percentage': 0.16},
    {'name': 'Powdery Mildew', 'count': 145, 'percentage': 0.23},
    {'name': 'Dieback', 'count': 70, 'percentage': 0.11},
    {'name': 'Tip Burn (Unknown)', 'count': 42, 'percentage': 0.07},
    {'name': 'Healthy', 'count': 112, 'percentage': 0.18},
  ];

  // Dummy data for disease trends by year
  final List<int> _years = [2023, 2024, 2025];
  int _selectedYear = 2025;
  final List<String> _allMonths = [
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
  final Map<int, Map<String, List<int>>> _diseaseTrendsByYear = {
    2023: {
      'Anthracnose': [10, 15, 20, 30, 40, 50, 55, 60, 65, 70, 75, 80],
      'Bacterial Blackspot': [5, 10, 15, 20, 25, 30, 32, 34, 36, 38, 40, 42],
      'Powdery Mildew': [8, 12, 18, 25, 32, 40, 45, 50, 55, 60, 65, 70],
      'Dieback': [2, 4, 8, 12, 16, 20, 22, 24, 26, 28, 30, 32],
      'Tip Burn (Unknown)': [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
      'Healthy': [20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75],
    },
    2024: {
      'Anthracnose': [15, 25, 35, 45, 60, 80, 90, 100, 110, 490, 580, 700],
      'Bacterial Blackspot': [
        8,
        16,
        24,
        32,
        40,
        48,
        50,
        230,
        270,
        300,
        359,
        640,
      ],
      'Powdery Mildew': [
        50,
        70,
        120,
        150,
        190,
        230,
        250,
        270,
        400,
        450,
        500,
        600,
      ],
      'Dieback': [3, 6, 9, 12, 15, 18, 20, 22, 24, 230, 250, 300],
      'Tip Burn (Unknown)': [2, 4, 6, 8, 10, 12, 13, 14, 15, 146, 260, 379],
      'Healthy': [25, 30, 35, 40, 45, 50, 480, 500, 600, 700, 750, 800],
    },
    2025: {
      'Anthracnose': [30, 45, 60, 80, 120, 156],
      'Bacterial Blackspot': [10, 20, 40, 60, 80, 98],
      'Powdery Mildew': [20, 40, 60, 90, 120, 145],
      'Dieback': [5, 10, 20, 35, 50, 70],
      'Tip Burn (Unknown)': [2, 8, 15, 25, 35, 42],
      'Healthy': [40, 50, 60, 80, 100, 112],
    },
  };

  final int _demoCurrentMonth = 5; // May (1=Jan, 5=May, 12=Dec)

  // Helper to get months for the selected year
  List<String> _getMonthsForYear(int year) {
    final now = DateTime.now();
    if (year == now.year) {
      // For demo, use _demoCurrentMonth instead of now.month
      return _allMonths.sublist(0, _demoCurrentMonth);
    } else {
      return List.from(_allMonths);
    }
  }

  // Helper to pad or trim data arrays to match months
  List<int> _padDataToMonths(List<int> data, int monthCount) {
    if (data.length >= monthCount) {
      return data.sublist(0, monthCount);
    } else {
      return List<int>.from(data)
        ..addAll(List.filled(monthCount - data.length, 0));
    }
  }

  Color _getDiseaseColor(String disease) {
    switch (disease.toLowerCase()) {
      case 'anthracnose':
        return Colors.orange;
      case 'bacterial blackspot':
        return Colors.red;
      case 'powdery mildew':
        return const Color.fromARGB(255, 9, 46, 2);
      case 'dieback':
        return Colors.brown;
      case 'tip burn':
        return Colors.amber;
      case 'healthy':
        return const Color.fromARGB(255, 2, 119, 252);
      default:
        return Colors.grey;
    }
  }

  Color _getDiseaseTrendColor(String disease) {
    switch (disease.toLowerCase()) {
      case 'anthracnose':
        return Colors.orange;
      case 'bacterial blackspot':
        return Colors.red;
      case 'powdery mildew':
        return const Color.fromARGB(255, 9, 46, 2);
      case 'dieback':
        return Colors.brown;
      case 'tip burn (unknown)':
        return Colors.grey;
      case 'healthy':
        return const Color.fromARGB(255, 2, 119, 252);
      default:
        return Colors.black;
    }
  }

  @override
  void initState() {
    super.initState();
    // Force rebuild when widget is created
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Reports & Analytics',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.list),
                  label: const Text('View All Reports'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder:
                          (context) => Dialog(
                            insetPadding: const EdgeInsets.symmetric(
                              horizontal: 40,
                              vertical: 40,
                            ),
                            child: Container(
                              width: 900,
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'All Reports',
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.close),
                                        onPressed: () => Navigator.pop(context),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    height: 400,
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: ReportsListTable(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                    );
                  },
                ),
                DropdownButton<String>(
                  value: _selectedTimeRange,
                  items:
                      [
                            'Last 7 Days',
                            'Last 30 Days',
                            'Last 90 Days',
                            'Last Year',
                          ]
                          .map(
                            (range) => DropdownMenuItem(
                              value: range,
                              child: Text(range),
                            ),
                          )
                          .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedTimeRange = value;
                      });
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Stats Grid
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.2,
              children: [
                _buildStatCard(
                  'Total Users',
                  _stats['totalUsers'].toString(),
                  Icons.people,
                  Colors.blue,
                ),
                _buildStatCard(
                  'Total Reports',
                  _stats['totalReports'].toString(),
                  Icons.assessment,
                  Colors.purple,
                ),
                _buildStatCard(
                  'Active Users',
                  _stats['activeUsers'].toString(),
                  Icons.person,
                  Colors.orange,
                ),
                _buildStatCard(
                  'Pending Approvals',
                  _stats['pendingApprovals'].toString(),
                  Icons.pending_actions,
                  Colors.red,
                ),
                _buildStatCard(
                  'Avg. Response Time',
                  _stats['averageResponseTime'],
                  Icons.timer,
                  Colors.teal,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Charts Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Disease Distribution Chart
                Expanded(
                  child: DiseaseDistributionChart(diseaseStats: _diseaseStats),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Disease Trends Over Time',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        DropdownButton<int>(
                          value: _selectedYear,
                          items:
                              _years
                                  .map(
                                    (year) => DropdownMenuItem(
                                      value: year,
                                      child: Text(year.toString()),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedYear = value;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Builder(
                      builder: (context) {
                        final months = _getMonthsForYear(_selectedYear);
                        final trendsRaw =
                            _diseaseTrendsByYear[_selectedYear] ?? {};
                        final trends = <String, List<int>>{};
                        for (final entry in trendsRaw.entries) {
                          trends[entry.key] = _padDataToMonths(
                            entry.value,
                            months.length,
                          );
                        }
                        final hasData =
                            trends.isNotEmpty &&
                            trends.values.any((list) => list.any((v) => v > 0));
                        if (!hasData) {
                          return Container(
                            height: 200,
                            alignment: Alignment.center,
                            child: const Text(
                              'No data available for the selected year.',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          );
                        }
                        return Column(
                          children: [
                            SizedBox(
                              height: 260,
                              child: LineChart(
                                LineChartData(
                                  gridData: FlGridData(show: true),
                                  titlesData: FlTitlesData(
                                    leftTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 40,
                                        getTitlesWidget: (value, meta) {
                                          if (value % 50 == 0) {
                                            return Text(
                                              value.toInt().toString(),
                                              style: const TextStyle(
                                                color: Colors.black54,
                                                fontWeight: FontWeight.w500,
                                                fontSize: 12,
                                              ),
                                            );
                                          }
                                          return const SizedBox.shrink();
                                        },
                                      ),
                                    ),
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        interval: 1,
                                        getTitlesWidget: (value, meta) {
                                          if (value % 1 == 0 &&
                                              value >= 0 &&
                                              value < months.length) {
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                top: 8.0,
                                              ),
                                              child: Text(
                                                months[value.toInt()],
                                                style: const TextStyle(
                                                  color: Colors.black,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            );
                                          }
                                          return const SizedBox.shrink();
                                        },
                                        reservedSize: 36,
                                      ),
                                    ),
                                    topTitles: AxisTitles(
                                      sideTitles: SideTitles(showTitles: false),
                                    ),
                                    rightTitles: AxisTitles(
                                      sideTitles: SideTitles(showTitles: false),
                                    ),
                                  ),
                                  borderData: FlBorderData(show: false),
                                  lineBarsData:
                                      trends.entries.map((entry) {
                                        final color = _getDiseaseTrendColor(
                                          entry.key,
                                        );
                                        return LineChartBarData(
                                          spots:
                                              entry.value
                                                  .asMap()
                                                  .entries
                                                  .map(
                                                    (e) => FlSpot(
                                                      e.key.toDouble(),
                                                      e.value.toDouble(),
                                                    ),
                                                  )
                                                  .toList(),
                                          isCurved: true,
                                          color: color,
                                          barWidth: 3,
                                          dotData: FlDotData(show: false),
                                          belowBarData: BarAreaData(
                                            show: false,
                                          ),
                                        );
                                      }).toList(),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 16,
                              runSpacing: 8,
                              children:
                                  trends.keys
                                      .map(
                                        (disease) => Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 16,
                                              height: 4,
                                              color: _getDiseaseTrendColor(
                                                disease,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              disease,
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: _getDiseaseTrendColor(
                                                  disease,
                                                ),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                      .toList(),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    double? percentChange,
    bool? isUp,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  double _calcPercentChange(num current, num previous) {
    if (previous == 0) return 0;
    return ((current - previous) / previous) * 100;
  }
}

class ReportsListTable extends StatefulWidget {
  ReportsListTable({Key? key}) : super(key: key);

  @override
  State<ReportsListTable> createState() => _ReportsListTableState();
}

class _ReportsListTableState extends State<ReportsListTable> {
  final List<Map<String, dynamic>> _dummyReports = [
    {
      'id': 'RPT-001',
      'user': 'John Doe',
      'date': '2025-05-01',
      'disease': 'Anthracnose',
      'status': 'Reviewed',
      'image': null,
      'details': 'Leaf spots and necrosis detected.',
      'expert': 'Dr. Smith',
      'feedback': 'Confirmed Anthracnose. Apply fungicide.',
    },
    {
      'id': 'RPT-002',
      'user': 'Jane Smith',
      'date': '2025-05-02',
      'disease': 'Healthy',
      'status': 'Reviewed',
      'image': null,
      'details': 'No disease detected.',
      'expert': 'Dr. Lee',
      'feedback': 'No action needed.',
    },
    {
      'id': 'RPT-003',
      'user': 'Mike Johnson',
      'date': '2025-05-03',
      'disease': 'Powdery Mildew',
      'status': 'Pending',
      'image': null,
      'details': 'White powdery spots on leaves.',
      'expert': '',
      'feedback': '',
    },
  ];

  String _searchQuery = '';

  List<Map<String, dynamic>> get _filteredReports {
    if (_searchQuery.isEmpty) return _dummyReports;
    return _dummyReports.where((report) {
      final query = _searchQuery.toLowerCase();
      return report['user'].toString().toLowerCase().contains(query) ||
          report['disease'].toString().toLowerCase().contains(query) ||
          report['status'].toString().toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 400,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by user, disease, or status',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
        ),
        SizedBox(
          height: 300,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Report ID')),
                DataColumn(label: Text('User')),
                DataColumn(label: Text('Date')),
                DataColumn(label: Text('Disease')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Actions')),
              ],
              rows:
                  _filteredReports.map((report) {
                    return DataRow(
                      cells: [
                        DataCell(Text(report['id'])),
                        DataCell(Text(report['user'])),
                        DataCell(Text(report['date'])),
                        DataCell(Text(report['disease'])),
                        DataCell(Text(report['status'])),
                        DataCell(
                          ElevatedButton(
                            child: const Text('View'),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder:
                                    (context) => AlertDialog(
                                      title: Text(
                                        'Report Details: ${report['id']}',
                                      ),
                                      content: SingleChildScrollView(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'Report ID: ${report['id']}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text('User: ${report['user']}'),
                                            Text('Date: ${report['date']}'),
                                            Text(
                                              'Disease: ${report['disease']}',
                                            ),
                                            Text('Status: ${report['status']}'),
                                            const SizedBox(height: 16),
                                            if (report['image'] != null)
                                              Container(
                                                height: 180,
                                                width: 180,
                                                color: Colors.grey[200],
                                                child: Image.network(
                                                  report['image'],
                                                  fit: BoxFit.cover,
                                                ),
                                              )
                                            else
                                              Container(
                                                height: 180,
                                                width: 180,
                                                color: Colors.grey[200],
                                                child: const Center(
                                                  child: Text('No Image'),
                                                ),
                                              ),
                                            const SizedBox(height: 16),
                                            Text(
                                              'Details: ${report['details']}',
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Expert: ${report['expert'] ?? "-"}',
                                            ),
                                            Text(
                                              'Feedback: ${report['feedback'] ?? "-"}',
                                            ),
                                          ],
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed:
                                              () => Navigator.pop(context),
                                          child: const Text('Close'),
                                        ),
                                      ],
                                    ),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

class DiseaseDistributionChart extends StatelessWidget {
  final List<Map<String, dynamic>> diseaseStats;
  final double? height;
  const DiseaseDistributionChart({
    Key? key,
    required this.diseaseStats,
    this.height,
  }) : super(key: key);

  Color _getDiseaseColor(String disease) {
    switch (disease.toLowerCase()) {
      case 'anthracnose':
        return Colors.orange;
      case 'bacterial blackspot':
        return Colors.red;
      case 'powdery mildew':
        return const Color.fromARGB(255, 9, 46, 2);
      case 'dieback':
        return Colors.brown;
      case 'tip burn':
        return Colors.amber;
      case 'healthy':
        return const Color.fromARGB(255, 2, 119, 252);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Disease Distribution',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              height: height ?? 320,
              width: double.infinity,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY:
                      diseaseStats
                          .map((d) => d['count'].toDouble())
                          .reduce((a, b) => a > b ? a : b) *
                      1.2,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      tooltipBgColor: Colors.blueGrey,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final disease = diseaseStats[groupIndex];
                        return BarTooltipItem(
                          '${disease['name']}\n${disease['count']} cases\n${(disease['percentage'] * 100).toStringAsFixed(1)}%',
                          const TextStyle(color: Colors.white),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value < 0 || value >= diseaseStats.length) {
                            return const SizedBox.shrink();
                          }
                          final disease = diseaseStats[value.toInt()];
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  disease['name'],
                                  style: TextStyle(
                                    color: _getDiseaseColor(disease['name']),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${(disease['percentage'] * 100).toStringAsFixed(1)}%',
                                  style: const TextStyle(
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          );
                        },
                        reservedSize: 72,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          if (value % 50 == 0) {
                            return Text(
                              value.toInt().toString(),
                              style: const TextStyle(
                                color: Colors.black54,
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups:
                      diseaseStats.asMap().entries.map((entry) {
                        final index = entry.key;
                        final disease = entry.value;
                        return BarChartGroupData(
                          x: index,
                          barRods: [
                            BarChartRodData(
                              toY: disease['count'].toDouble(),
                              color: _getDiseaseColor(disease['name']),
                              width: 36, // Wider bar
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(8),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
