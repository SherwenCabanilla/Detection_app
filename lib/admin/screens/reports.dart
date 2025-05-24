import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'reports_list.dart';
import '../shared/total_users_card.dart';
import '../shared/pending_approvals_card.dart';

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
    'averageResponseTime': '2.39 hours',
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
              crossAxisCount: 4,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.2,
              children: [
                const TotalUsersCard(),
                TotalReportsCard(reportsTrend: _reportsTrend),
                const PendingApprovalsCard(),
                _buildStatCard(
                  'Avg. Response Time',
                  _stats['averageResponseTime'],
                  Icons.timer,
                  Colors.teal,
                  onTap: () => _showAvgResponseTimeModal(context),
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
          padding: const EdgeInsets.all(10),
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

  void _showAvgResponseTimeModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const AvgResponseTimeModal(),
    );
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

class AvgResponseTimeModal extends StatefulWidget {
  const AvgResponseTimeModal({Key? key}) : super(key: key);

  @override
  State<AvgResponseTimeModal> createState() => _AvgResponseTimeModalState();
}

class _AvgResponseTimeModalState extends State<AvgResponseTimeModal> {
  String _selectedRange = 'Last 7 Days';

  // Hardcoded mock data for each range
  final Map<String, List<String>> _labelsData = {
    '1 Day': ['May 1'],
    'Last 7 Days': [
      'Apr 25',
      'Apr 26',
      'Apr 27',
      'Apr 28',
      'Apr 29',
      'Apr 30',
      'May 1',
    ],
    'Last 30 Days': [for (int i = 2; i <= 30; i++) 'Apr $i'] + ['May 1'],
    'Last 60 Days':
        [for (int i = 3; i <= 31; i++) 'Mar $i'] +
        [for (int i = 1; i <= 29; i++) 'Apr $i'] +
        ['Apr 30'],
    'Last 90 Days':
        [for (int i = 1; i <= 31; i++) 'Feb $i'] +
        [for (int i = 1; i <= 31; i++) 'Mar $i'] +
        [for (int i = 1; i <= 28; i++) 'Apr $i'],
    'Last Year': [
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
    ],
  };
  final Map<String, List<double>> _responseTimesData = {
    '1 Day': [2.1],
    'Last 7 Days': [2.5, 2.2, 2.8, 2.0, 2.7, 2.4, 2.1],
    'Last 30 Days': List.generate(30, (i) => 1.5 + (i % 7) * 0.2),
    'Last 60 Days': List.generate(60, (i) => 1.2 + (i % 10) * 0.15),
    'Last 90 Days': List.generate(90, (i) => 1.0 + (i % 15) * 0.1),
    'Last Year': [2.5, 2.3, 2.1, 2.0, 1.9, 1.8, 1.7, 1.8, 1.9, 2.0, 2.2, 2.4],
  };
  final Map<String, List<int>> _distributionData = {
    // <1h, 1-4h, 4-24h, >24h
    '1 Day': [2, 5, 1, 0],
    'Last 7 Days': [10, 30, 8, 2],
    'Last 30 Days': [40, 120, 30, 10],
    'Last 60 Days': [80, 220, 60, 20],
    'Last 90 Days': [120, 320, 90, 30],
    'Last Year': [500, 1800, 400, 100],
  };

  @override
  Widget build(BuildContext context) {
    List<String> labels = _labelsData[_selectedRange]!;
    List<double> responseTimes = _responseTimesData[_selectedRange]!;
    List<int> distribution = _distributionData[_selectedRange]!;

    // Aggregate by week for long ranges
    List<String> displayLabels = labels;
    List<double> displayResponseTimes = responseTimes;
    if (_selectedRange == 'Last 30 Days' ||
        _selectedRange == 'Last 60 Days' ||
        _selectedRange == 'Last 90 Days') {
      // Aggregate every 7 days
      List<double> weeklyAverages = [];
      List<String> weekLabels = [];
      for (int i = 0; i < responseTimes.length; i += 7) {
        int end = (i + 7 < responseTimes.length) ? i + 7 : responseTimes.length;
        double avg =
            responseTimes.sublist(i, end).reduce((a, b) => a + b) / (end - i);
        weeklyAverages.add(double.parse(avg.toStringAsFixed(2)));
        weekLabels.add('Wk ${(i ~/ 7) + 1}');
      }
      displayLabels = weekLabels;
      displayResponseTimes = weeklyAverages;
    }

    // Find best/worst days
    double minVal = displayResponseTimes.reduce((a, b) => a < b ? a : b);
    double maxVal = displayResponseTimes.reduce((a, b) => a > b ? a : b);
    int minIdx = displayResponseTimes.indexOf(minVal);
    int maxIdx = displayResponseTimes.indexOf(maxVal);
    String bestDay = displayLabels[minIdx];
    String worstDay = displayLabels[maxIdx];

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: 700,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Average Response Time',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Detailed breakdown of response times',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.blueGrey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Average response time within $_selectedRange: '
                      '${displayResponseTimes.isNotEmpty ? (displayResponseTimes.reduce((a, b) => a + b) / displayResponseTimes.length).toStringAsFixed(2) : '-'} hours',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.teal,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    DropdownButton<String>(
                      value: _selectedRange,
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
                            _selectedRange = value;
                          });
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 28),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Trend Chart
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 35),
                child: SizedBox(
                  height: 220,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12.0),
                    child: LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: true,
                          horizontalInterval: 0.5,
                          verticalInterval: 1,
                          getDrawingHorizontalLine:
                              (value) => FlLine(
                                color: Colors.grey[200],
                                strokeWidth: 1,
                              ),
                          getDrawingVerticalLine:
                              (value) => FlLine(
                                color: Colors.grey[200],
                                strokeWidth: 1,
                              ),
                        ),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 56,
                              getTitlesWidget: (value, meta) {
                                if (value % 1 == 0) {
                                  return Text(
                                    value.toStringAsFixed(1),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.blueGrey,
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                              interval: 0.5,
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              getTitlesWidget: (value, meta) {
                                final idx = value.toInt();
                                if (idx >= 0 && idx < displayLabels.length) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      displayLabels[idx],
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blueGrey,
                                      ),
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                              interval: 1,
                            ),
                          ),
                          rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        borderData: FlBorderData(
                          show: true,
                          border: Border.all(
                            color: Colors.grey[300]!,
                            width: 2,
                          ),
                        ),
                        minX: 0,
                        maxX: (displayLabels.length - 1).toDouble(),
                        minY: 0,
                        maxY:
                            (displayResponseTimes.reduce(
                                      (a, b) => a > b ? a : b,
                                    ) *
                                    1.2)
                                .toDouble(),
                        lineBarsData: [
                          LineChartBarData(
                            spots: [
                              for (int i = 0; i < displayLabels.length; i++)
                                FlSpot(i.toDouble(), displayResponseTimes[i]),
                            ],
                            isCurved: true,
                            color: Colors.teal,
                            barWidth: 6,
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                colors: [
                                  Colors.teal.withOpacity(0.3),
                                  Colors.teal.withOpacity(0.05),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                            dotData: FlDotData(
                              show: true,
                              getDotPainter:
                                  (spot, percent, bar, index) =>
                                      FlDotCirclePainter(
                                        radius: 7,
                                        color: Colors.white,
                                        strokeWidth: 4,
                                        strokeColor: Colors.teal,
                                      ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Distribution Histogram
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Response Time Distribution',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 120,
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY:
                              (distribution.reduce((a, b) => a > b ? a : b) *
                                      1.2)
                                  .toDouble(),
                          barGroups: [
                            for (int i = 0; i < 4; i++)
                              BarChartGroupData(
                                x: i,
                                barRods: [
                                  BarChartRodData(
                                    toY: distribution[i].toDouble(),
                                    color: Colors.teal,
                                    width: 32,
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(8),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 32,
                                getTitlesWidget: (value, meta) {
                                  if (value % 10 == 0) {
                                    return Text(
                                      value.toInt().toString(),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.blueGrey,
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
                                getTitlesWidget: (value, meta) {
                                  switch (value.toInt()) {
                                    case 0:
                                      return const Text(
                                        '<1h',
                                        style: TextStyle(fontSize: 14),
                                      );
                                    case 1:
                                      return const Text(
                                        '1-4h',
                                        style: TextStyle(fontSize: 14),
                                      );
                                    case 2:
                                      return const Text(
                                        '4-24h',
                                        style: TextStyle(fontSize: 14),
                                      );
                                    case 3:
                                      return const Text(
                                        '>24h',
                                        style: TextStyle(fontSize: 14),
                                      );
                                    default:
                                      return const SizedBox.shrink();
                                  }
                                },
                              ),
                            ),
                            rightTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            topTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Best/Worst Days
            Row(
              children: [
                Expanded(
                  child: Card(
                    color: Colors.green[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Text(
                            'Fastest Day',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '$bestDay',
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.green,
                            ),
                          ),
                          Text(
                            '${minVal.toStringAsFixed(2)} hours',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Card(
                    color: Colors.red[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Text(
                            'Slowest Day',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '$worstDay',
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.red,
                            ),
                          ),
                          Text(
                            '${maxVal.toStringAsFixed(2)} hours',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
