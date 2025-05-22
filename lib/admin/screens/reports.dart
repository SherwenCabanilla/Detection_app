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
    'activeUsers': 890,
    'pendingApprovals': 12,
    'averageResponseTime': '2.5 hours',
  };

  // Dummy data for reports trend
  final List<Map<String, dynamic>> _reportsTrend = [
    {'date': '2024-03-01', 'count': 45},
    {'date': '2024-03-02', 'count': 52},
    {'date': '2024-03-03', 'count': 48},
    {'date': '2024-03-04', 'count': 65},
    {'date': '2024-03-05', 'count': 58},
    {'date': '2024-03-06', 'count': 72},
    {'date': '2024-03-07', 'count': 68},
  ];

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
                  'Reports',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
                TotalReportsCard(reportsTrend: _reportsTrend),
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
    VoidCallback? onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
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
      ),
    );
  }

  void _showReportsTrendDialog(BuildContext context) {
    showDialog(context: context, builder: (context) => ReportsTrendDialog());
  }
}

class TotalReportsCard extends StatelessWidget {
  final List<Map<String, dynamic>> reportsTrend;

  const TotalReportsCard({Key? key, required this.reportsTrend})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () => _showReportsTrendDialog(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.assessment, size: 32, color: Colors.purple),
              const SizedBox(height: 8),
              Text(
                reportsTrend
                    .fold<int>(0, (sum, item) => sum + (item['count'] as int))
                    .toString(),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Total Reports',
                style: TextStyle(color: Colors.grey, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showReportsTrendDialog(BuildContext context) {
    showDialog(context: context, builder: (context) => ReportsTrendDialog());
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
      {
        'name': 'Anthracnose',
        'count': 12,
        'percentage': 0.30,
        'type': 'disease',
      },
      {
        'name': 'Bacterial Blackspot',
        'count': 8,
        'percentage': 0.20,
        'type': 'disease',
      },
      {
        'name': 'Powdery Mildew',
        'count': 10,
        'percentage': 0.25,
        'type': 'disease',
      },
      {'name': 'Dieback', 'count': 4, 'percentage': 0.10, 'type': 'disease'},
      {'name': 'Healthy', 'count': 4, 'percentage': 0.15, 'type': 'healthy'},
    ],
    'Last 7 Days': [
      {
        'name': 'Anthracnose',
        'count': 156,
        'percentage': 0.25,
        'type': 'disease',
      },
      {
        'name': 'Bacterial Blackspot',
        'count': 98,
        'percentage': 0.16,
        'type': 'disease',
      },
      {
        'name': 'Powdery Mildew',
        'count': 145,
        'percentage': 0.23,
        'type': 'disease',
      },
      {'name': 'Dieback', 'count': 70, 'percentage': 0.11, 'type': 'disease'},
      {'name': 'Healthy', 'count': 112, 'percentage': 0.25, 'type': 'healthy'},
    ],
    'Last 30 Days': [
      {
        'name': 'Anthracnose',
        'count': 450,
        'percentage': 0.28,
        'type': 'disease',
      },
      {
        'name': 'Bacterial Blackspot',
        'count': 320,
        'percentage': 0.20,
        'type': 'disease',
      },
      {
        'name': 'Powdery Mildew',
        'count': 380,
        'percentage': 0.24,
        'type': 'disease',
      },
      {'name': 'Dieback', 'count': 180, 'percentage': 0.11, 'type': 'disease'},
      {'name': 'Healthy', 'count': 150, 'percentage': 0.17, 'type': 'healthy'},
    ],
    'Last 90 Days': [
      {
        'name': 'Anthracnose',
        'count': 1200,
        'percentage': 0.30,
        'type': 'disease',
      },
      {
        'name': 'Bacterial Blackspot',
        'count': 850,
        'percentage': 0.21,
        'type': 'disease',
      },
      {
        'name': 'Powdery Mildew',
        'count': 950,
        'percentage': 0.24,
        'type': 'disease',
      },
      {'name': 'Dieback', 'count': 450, 'percentage': 0.11, 'type': 'disease'},
      {'name': 'Healthy', 'count': 300, 'percentage': 0.14, 'type': 'healthy'},
    ],
    'Last Year': [
      {
        'name': 'Anthracnose',
        'count': 4800,
        'percentage': 0.32,
        'type': 'disease',
      },
      {
        'name': 'Bacterial Blackspot',
        'count': 3200,
        'percentage': 0.21,
        'type': 'disease',
      },
      {
        'name': 'Powdery Mildew',
        'count': 3600,
        'percentage': 0.24,
        'type': 'disease',
      },
      {'name': 'Dieback', 'count': 1800, 'percentage': 0.12, 'type': 'disease'},
      {'name': 'Healthy', 'count': 700, 'percentage': 0.11, 'type': 'healthy'},
    ],
  };

  List<Map<String, dynamic>> get _currentData =>
      _timeRangeData[_selectedTimeRange] ?? _timeRangeData['Last 7 Days']!;

  List<Map<String, dynamic>> get _diseaseData =>
      _currentData.where((item) => item['type'] == 'disease').toList();

  List<Map<String, dynamic>> get _healthyData =>
      _currentData.where((item) => item['type'] == 'healthy').toList();

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
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Distribution',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButton<String>(
                    value: _selectedTimeRange,
                    items:
                        _timeRangeData.keys.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(
                              value,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedTimeRange = newValue;
                        });
                      }
                    },
                    underline: const SizedBox(),
                    icon: const Icon(
                      Icons.arrow_drop_down,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            // Disease Distribution Chart
            Container(
              height: widget.height ?? 400,
              width: double.infinity,
              child: Row(
                children: [
                  // Diseases Chart
                  Expanded(
                    flex: 3,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red[50],
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.warning_rounded,
                                      size: 16,
                                      color: Colors.red[700],
                                    ),
                                    const SizedBox(width: 6),
                                    const Text(
                                      'Diseases',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              Text(
                                'Total: ${_diseaseData.fold<int>(0, (sum, item) => sum + (item['count'] as int))} cases',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Expanded(
                            child: BarChart(
                              BarChartData(
                                alignment: BarChartAlignment.spaceAround,
                                maxY:
                                    _diseaseData
                                        .map((d) => d['count'].toDouble())
                                        .reduce((a, b) => a > b ? a : b) *
                                    1.2,
                                barTouchData: BarTouchData(
                                  enabled: true,
                                  touchTooltipData: BarTouchTooltipData(
                                    tooltipBgColor: Colors.blueGrey,
                                    getTooltipItem: (
                                      group,
                                      groupIndex,
                                      rod,
                                      rodIndex,
                                    ) {
                                      if (groupIndex < 0 ||
                                          groupIndex >= _diseaseData.length) {
                                        return null;
                                      }
                                      final disease = _diseaseData[groupIndex];
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
                                        if (value < 0 ||
                                            value >= _diseaseData.length) {
                                          return const SizedBox.shrink();
                                        }
                                        final disease =
                                            _diseaseData[value.toInt()];
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            top: 8.0,
                                          ),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                disease['name'],
                                                style: TextStyle(
                                                  color: _getDiseaseColor(
                                                    disease['name'],
                                                  ),
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 14,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                              const SizedBox(height: 6),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: _getDiseaseColor(
                                                    disease['name'],
                                                  ).withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  '${(disease['percentage'] * 100).toStringAsFixed(1)}%',
                                                  style: TextStyle(
                                                    color: _getDiseaseColor(
                                                      disease['name'],
                                                    ),
                                                    fontWeight: FontWeight.w500,
                                                    fontSize: 12,
                                                  ),
                                                ),
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
                                            style: TextStyle(
                                              color: Colors.grey[600],
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
                                gridData: FlGridData(
                                  show: true,
                                  drawVerticalLine: false,
                                  horizontalInterval: 50,
                                  getDrawingHorizontalLine: (value) {
                                    return FlLine(
                                      color: Colors.grey[200],
                                      strokeWidth: 1,
                                    );
                                  },
                                ),
                                barGroups:
                                    _diseaseData.asMap().entries.map((entry) {
                                      final index = entry.key;
                                      final disease = entry.value;
                                      return BarChartGroupData(
                                        x: index,
                                        barRods: [
                                          BarChartRodData(
                                            toY: disease['count'].toDouble(),
                                            color: _getDiseaseColor(
                                              disease['name'],
                                            ),
                                            width: 36,
                                            borderRadius:
                                                const BorderRadius.vertical(
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
                  ),
                  const SizedBox(width: 24),
                  // Healthy Plants Chart
                  Expanded(
                    flex: 1,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green[50],
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.check_circle_rounded,
                                      size: 16,
                                      color: Colors.green[700],
                                    ),
                                    const SizedBox(width: 6),
                                    const Text(
                                      'Healthy',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              Text(
                                'Total: ${_healthyData.fold<int>(0, (sum, item) => sum + (item['count'] as int))} cases',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Expanded(
                            child: BarChart(
                              BarChartData(
                                alignment: BarChartAlignment.spaceAround,
                                maxY:
                                    _healthyData
                                        .map((d) => d['count'].toDouble())
                                        .reduce((a, b) => a > b ? a : b) *
                                    1.2,
                                barTouchData: BarTouchData(
                                  enabled: true,
                                  touchTooltipData: BarTouchTooltipData(
                                    tooltipBgColor: Colors.blueGrey,
                                    getTooltipItem: (
                                      group,
                                      groupIndex,
                                      rod,
                                      rodIndex,
                                    ) {
                                      if (groupIndex < 0 ||
                                          groupIndex >= _healthyData.length) {
                                        return null;
                                      }
                                      final disease = _healthyData[groupIndex];
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
                                        if (value < 0 ||
                                            value >= _healthyData.length) {
                                          return const SizedBox.shrink();
                                        }
                                        final disease =
                                            _healthyData[value.toInt()];
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            top: 8.0,
                                          ),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                disease['name'],
                                                style: TextStyle(
                                                  color: _getDiseaseColor(
                                                    disease['name'],
                                                  ),
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 14,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                              const SizedBox(height: 6),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: _getDiseaseColor(
                                                    disease['name'],
                                                  ).withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  '${(disease['percentage'] * 100).toStringAsFixed(1)}%',
                                                  style: TextStyle(
                                                    color: _getDiseaseColor(
                                                      disease['name'],
                                                    ),
                                                    fontWeight: FontWeight.w500,
                                                    fontSize: 12,
                                                  ),
                                                ),
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
                                            style: TextStyle(
                                              color: Colors.grey[600],
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
                                gridData: FlGridData(
                                  show: true,
                                  drawVerticalLine: false,
                                  horizontalInterval: 50,
                                  getDrawingHorizontalLine: (value) {
                                    return FlLine(
                                      color: Colors.grey[200],
                                      strokeWidth: 1,
                                    );
                                  },
                                ),
                                barGroups:
                                    _healthyData.asMap().entries.map((entry) {
                                      final index = entry.key;
                                      final disease = entry.value;
                                      return BarChartGroupData(
                                        x: index,
                                        barRods: [
                                          BarChartRodData(
                                            toY: disease['count'].toDouble(),
                                            color: _getDiseaseColor(
                                              disease['name'],
                                            ),
                                            width: 36,
                                            borderRadius:
                                                const BorderRadius.vertical(
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
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ReportsTrendDialog extends StatefulWidget {
  @override
  State<ReportsTrendDialog> createState() => _ReportsTrendDialogState();
}

class _ReportsTrendDialogState extends State<ReportsTrendDialog> {
  String _selectedTimeRange = 'Last 7 Days';

  // Dummy data for different time ranges
  final Map<String, List<Map<String, dynamic>>> _timeRangeData = {
    '1 Day': [
      {'date': '2024-03-07', 'count': 68},
    ],
    'Last 7 Days': [
      {'date': '2024-03-01', 'count': 45},
      {'date': '2024-03-02', 'count': 52},
      {'date': '2024-03-03', 'count': 48},
      {'date': '2024-03-04', 'count': 65},
      {'date': '2024-03-05', 'count': 58},
      {'date': '2024-03-06', 'count': 72},
      {'date': '2024-03-07', 'count': 68},
    ],
    'Last 30 Days': List.generate(
      30,
      (i) => {
        'date': '2024-03-${(i + 1).toString().padLeft(2, '0')}',
        'count': 40 + (i % 10) * 2,
      },
    ),
    'Last 60 Days': List.generate(
      60,
      (i) => {
        'date':
            '2024-02-${(i < 29 ? (i + 1) : (i - 28)).toString().padLeft(2, '0')}',
        'count': 35 + (i % 15),
      },
    ),
    'Last 90 Days': List.generate(
      90,
      (i) => {
        'date':
            '2024-01-${(i < 31 ? (i + 1) : (i - 30)).toString().padLeft(2, '0')}',
        'count': 30 + (i % 20),
      },
    ),
    'Last Year': List.generate(
      12,
      (i) => {
        'date': '2023-${(i + 1).toString().padLeft(2, '0')}',
        'count': 100 + i * 10,
      },
    ),
  };

  List<Map<String, dynamic>> get _currentData =>
      _timeRangeData[_selectedTimeRange] ?? _timeRangeData['Last 7 Days']!;

  List<Map<String, dynamic>> get _aggregatedData {
    // For large ranges, aggregate by week
    if (_selectedTimeRange == 'Last 30 Days' ||
        _selectedTimeRange == 'Last 60 Days' ||
        _selectedTimeRange == 'Last 90 Days') {
      final data = _currentData;
      final int daysPerBar = 7;
      List<Map<String, dynamic>> result = [];
      for (int i = 0; i < data.length; i += daysPerBar) {
        int sum = 0;
        for (int j = i; j < i + daysPerBar && j < data.length; j++) {
          sum += data[j]['count'] as int;
        }
        result.add({'date': data[i]['date'], 'count': sum});
      }
      return result;
    }
    return _currentData;
  }

  @override
  Widget build(BuildContext context) {
    final isManyBars = _aggregatedData.length > 10;
    final chartWidth =
        isManyBars ? (_aggregatedData.length * 60.0) : double.infinity;
    final int totalReports = _aggregatedData.fold<int>(
      0,
      (sum, item) => sum + (item['count'] as int),
    );
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
      child: Container(
        width: 800,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Reports',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            'User activity',
                                            style: TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.close),
                                            onPressed:
                                                () => Navigator.pop(context),
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
                    const SizedBox(width: 12),
                    DropdownButton<String>(
                      value: _selectedTimeRange,
                      items:
                          [
                                '1 Day',
                                'Last 7 Days',
                                'Last 30 Days',
                                'Last 60 Days',
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
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Total Reports: $totalReports',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.purple,
              ),
            ),
            const SizedBox(height: 12),
            if (_aggregatedData.isEmpty)
              const Center(child: Text('No data available for this range.'))
            else
              SizedBox(
                height: 400,
                child:
                    isManyBars
                        ? SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: chartWidth,
                            child: _buildBarChart(
                              key: ValueKey(_selectedTimeRange),
                            ),
                          ),
                        )
                        : _buildBarChart(key: ValueKey(_selectedTimeRange)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChart({Key? key}) {
    // Debug print to trace data
    print(
      'DEBUG: _selectedTimeRange=$_selectedTimeRange, _aggregatedData.length=${_aggregatedData.length}',
    );
    for (var i = 0; i < _aggregatedData.length; i++) {
      print('DEBUG: _aggregatedData[$i]=${_aggregatedData[i]}');
    }
    // Data validation
    if (_selectedTimeRange == 'Last Year' && _aggregatedData.length != 12) {
      return const Center(
        child: Text('Data error: Expected 12 months of data.'),
      );
    }
    if (_aggregatedData.isEmpty ||
        _aggregatedData.any((d) => d['date'] == null || d['count'] == null)) {
      return const Center(child: Text('Data error: Invalid or missing data.'));
    }
    return BarChart(
      key: key,
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY:
            _aggregatedData
                .map((d) => d['count'] as int)
                .reduce((a, b) => a > b ? a : b) *
            1.2,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            tooltipBgColor: Colors.blueGrey,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              if (groupIndex < 0 || groupIndex >= _aggregatedData.length) {
                return null;
              }
              final report = _aggregatedData[groupIndex];
              String label = _barLabel(groupIndex, report['date']);
              return BarTooltipItem(
                '$label\n${report['count']} reports',
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
              reservedSize: 36,
              getTitlesWidget: (value, meta) {
                if (value < 0 || value >= _aggregatedData.length) {
                  return const SizedBox.shrink();
                }
                final date = _aggregatedData[value.toInt()]['date'];
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    _barLabel(value.toInt(), date),
                    style: const TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.w500,
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
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                if (value % 20 == 0) {
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
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        barGroups:
            _aggregatedData.asMap().entries.map((entry) {
              final index = entry.key;
              final report = entry.value;
              return BarChartGroupData(
                x: index,
                barRods: [
                  BarChartRodData(
                    toY: (report['count'] as int).toDouble(),
                    color: Colors.purple,
                    width: 28,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(8),
                    ),
                    rodStackItems: [],
                  ),
                ],
              );
            }).toList(),
        gridData: FlGridData(show: true, drawVerticalLine: false),
        extraLinesData: ExtraLinesData(),
        groupsSpace: 12,
      ),
    );
  }

  String _barLabel(int index, String date) {
    if (_selectedTimeRange == 'Last Year') {
      final parts = date.split('-');
      int monthNum = 1;
      if (parts.length > 1) {
        monthNum = int.tryParse(parts[1]) ?? 1;
      }
      const months = [
        '',
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
      if (monthNum < 1 || monthNum > 12) {
        return '?';
      }
      return months[monthNum];
    } else if (_selectedTimeRange == 'Last 30 Days' ||
        _selectedTimeRange == 'Last 60 Days' ||
        _selectedTimeRange == 'Last 90 Days') {
      return 'Wk ${index + 1}';
    } else {
      final parts = date.split('-');
      return parts.length > 2 ? '${parts[1]}/${parts[2]}' : date;
    }
  }
}
