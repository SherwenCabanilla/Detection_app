import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

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
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Disease Distribution',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 300,
                            child: PieChart(
                              PieChartData(
                                sections:
                                    _diseaseStats.map((disease) {
                                      return PieChartSectionData(
                                        value: disease['count'].toDouble(),
                                        title:
                                            '${(disease['percentage'] * 100).toStringAsFixed(1)}%',
                                        color: _getDiseaseColor(
                                          disease['name'],
                                        ),
                                        radius: 100,
                                        titleStyle: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      );
                                    }).toList(),
                                sectionsSpace: 2,
                                centerSpaceRadius: 40,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children:
                                  _diseaseStats.map((disease) {
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 16),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 16,
                                            height: 16,
                                            decoration: BoxDecoration(
                                              color: _getDiseaseColor(
                                                disease['name'],
                                              ),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            disease['name'],
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                            ),
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

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
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
}
