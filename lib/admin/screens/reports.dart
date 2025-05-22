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
                  label: const Text('User activity'),
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
                            '1 Day',
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

class DiseaseDistributionChart extends StatefulWidget {
  final List<Map<String, dynamic>> diseaseStats;
  final double? height;
  const DiseaseDistributionChart({
    Key? key,
    required this.diseaseStats,
    this.height,
  }) : super(key: key);

  @override
  State<DiseaseDistributionChart> createState() =>
      _DiseaseDistributionChartState();
}

class _DiseaseDistributionChartState extends State<DiseaseDistributionChart> {
  String _selectedTimeRange = 'Last 7 Days';

  // Dummy data for different time ranges
  final Map<String, List<Map<String, dynamic>>> _timeRangeData = {
    '1 Day': [
      {'name': 'Anthracnose', 'count': 12, 'percentage': 0.30},
      {'name': 'Bacterial Blackspot', 'count': 8, 'percentage': 0.20},
      {'name': 'Powdery Mildew', 'count': 10, 'percentage': 0.25},
      {'name': 'Dieback', 'count': 4, 'percentage': 0.10},
      {'name': 'Tip Burn (Unknown)', 'count': 2, 'percentage': 0.05},
      {'name': 'Healthy', 'count': 4, 'percentage': 0.10},
    ],
    'Last 7 Days': [
      {'name': 'Anthracnose', 'count': 156, 'percentage': 0.25},
      {'name': 'Bacterial Blackspot', 'count': 98, 'percentage': 0.16},
      {'name': 'Powdery Mildew', 'count': 145, 'percentage': 0.23},
      {'name': 'Dieback', 'count': 70, 'percentage': 0.11},
      {'name': 'Tip Burn (Unknown)', 'count': 42, 'percentage': 0.07},
      {'name': 'Healthy', 'count': 112, 'percentage': 0.18},
    ],
    'Last 30 Days': [
      {'name': 'Anthracnose', 'count': 450, 'percentage': 0.28},
      {'name': 'Bacterial Blackspot', 'count': 320, 'percentage': 0.20},
      {'name': 'Powdery Mildew', 'count': 380, 'percentage': 0.24},
      {'name': 'Dieback', 'count': 180, 'percentage': 0.11},
      {'name': 'Tip Burn (Unknown)', 'count': 120, 'percentage': 0.07},
      {'name': 'Healthy', 'count': 150, 'percentage': 0.10},
    ],
    'Last 90 Days': [
      {'name': 'Anthracnose', 'count': 1200, 'percentage': 0.30},
      {'name': 'Bacterial Blackspot', 'count': 850, 'percentage': 0.21},
      {'name': 'Powdery Mildew', 'count': 950, 'percentage': 0.24},
      {'name': 'Dieback', 'count': 450, 'percentage': 0.11},
      {'name': 'Tip Burn (Unknown)', 'count': 250, 'percentage': 0.06},
      {'name': 'Healthy', 'count': 300, 'percentage': 0.08},
    ],
    'Last Year': [
      {'name': 'Anthracnose', 'count': 4800, 'percentage': 0.32},
      {'name': 'Bacterial Blackspot', 'count': 3200, 'percentage': 0.21},
      {'name': 'Powdery Mildew', 'count': 3600, 'percentage': 0.24},
      {'name': 'Dieback', 'count': 1800, 'percentage': 0.12},
      {'name': 'Tip Burn (Unknown)', 'count': 900, 'percentage': 0.06},
      {'name': 'Healthy', 'count': 700, 'percentage': 0.05},
    ],
  };

  List<Map<String, dynamic>> get _currentData =>
      _timeRangeData[_selectedTimeRange] ?? _timeRangeData['Last 7 Days']!;

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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Disease Distribution',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                DropdownButton<String>(
                  value: _selectedTimeRange,
                  items:
                      [
                            '1 Day',
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
            const SizedBox(height: 16),
            Container(
              height: widget.height ?? 320,
              width: double.infinity,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY:
                      _currentData
                          .map((d) => d['count'].toDouble())
                          .reduce((a, b) => a > b ? a : b) *
                      1.2,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      tooltipBgColor: Colors.blueGrey,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final disease = _currentData[groupIndex];
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
                          if (value < 0 || value >= _currentData.length) {
                            return const SizedBox.shrink();
                          }
                          final disease = _currentData[value.toInt()];
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
                      _currentData.asMap().entries.map((entry) {
                        final index = entry.key;
                        final disease = entry.value;
                        return BarChartGroupData(
                          x: index,
                          barRods: [
                            BarChartRodData(
                              toY: disease['count'].toDouble(),
                              color: _getDiseaseColor(disease['name']),
                              width: 36,
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
