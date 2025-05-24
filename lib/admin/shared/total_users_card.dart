import 'package:flutter/material.dart';
import '../models/user_store.dart';
import 'package:fl_chart/fl_chart.dart';

class TotalUsersCard extends StatelessWidget {
  final double? width;
  const TotalUsersCard({Key? key, this.width}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final int totalUsers =
        UserStore.users.where((u) => u['status'] == 'active').length;
    return Card(
      child: InkWell(
        onTap: () => _showUsersModal(context),
        child: Container(
          width: width,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.people, size: 32, color: Colors.blue),
              const SizedBox(height: 8),
              Text(
                totalUsers.toString(),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Total Users',
                style: TextStyle(color: Colors.grey, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _showUsersModal(BuildContext context) {
  showDialog(context: context, builder: (context) => const _UsersGrowthModal());
}

class _UsersGrowthModal extends StatefulWidget {
  const _UsersGrowthModal({Key? key}) : super(key: key);

  @override
  State<_UsersGrowthModal> createState() => _UsersGrowthModalState();
}

class _UsersGrowthModalState extends State<_UsersGrowthModal> {
  String _selectedRange = 'Last 7 Days';

  // Hardcoded dummy data for each range
  final Map<String, List<String>> _monthsData = {
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
  final Map<String, List<int>> _userCountsData = {
    '1 Day': [210],
    'Last 7 Days': [180, 185, 190, 200, 210, 220, 230],
    'Last 30 Days': List.generate(30, (i) => 100 + i * 5),
    'Last 60 Days': List.generate(60, (i) => 80 + i * 3),
    'Last 90 Days': List.generate(90, (i) => 60 + i * 2),
    'Last Year': [100, 120, 150, 180, 220, 270, 330, 400, 480, 570, 670, 780],
  };

  @override
  Widget build(BuildContext context) {
    // Helper to aggregate by week for large ranges
    List<int> _aggregateByWeek(List<int> data) {
      const int daysPerBar = 7;
      List<int> result = [];
      for (int i = 0; i < data.length; i += daysPerBar) {
        int sum = 0;
        for (int j = i; j < i + daysPerBar && j < data.length; j++) {
          sum += data[j];
        }
        result.add(sum);
      }
      return result;
    }

    // Helper to get x-axis label like Total Reports
    String _barLabel(int index, List<String> months) {
      if (_selectedRange == 'Last Year') {
        return months[index];
      } else if (_selectedRange == 'Last 30 Days' ||
          _selectedRange == 'Last 60 Days' ||
          _selectedRange == 'Last 90 Days') {
        return 'Wk ${index + 1}';
      } else {
        return months[index];
      }
    }

    List<String> months = _monthsData[_selectedRange]!;
    List<int> userCounts = _userCountsData[_selectedRange]!;

    // Use real user growth data for the full period (actual active users only)
    List<Map<String, dynamic>> activeUsers =
        UserStore.users.where((u) => u['status'] == 'active').toList();
    List<DateTime> regDates =
        activeUsers
            .map((u) => DateTime.parse(u['registeredAt'].substring(0, 10)))
            .toList();
    regDates.sort();
    DateTime? earliestDate = regDates.isNotEmpty ? regDates.first : null;
    DateTime? latestDate = regDates.isNotEmpty ? regDates.last : null;
    List<String> allDays = [];
    if (earliestDate != null && latestDate != null) {
      int totalDays = latestDate.difference(earliestDate).inDays + 1;
      allDays = List.generate(totalDays, (i) {
        final date = earliestDate.add(Duration(days: i));
        return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      });
    }
    if (_selectedRange == 'Full Growth') {
      months = allDays.map((d) => d.substring(5)).toList(); // MM-DD
      userCounts =
          allDays.map((dateStr) {
            final date = DateTime.parse(dateStr);
            return regDates.where((d) => !d.isAfter(date)).length;
          }).toList();
      // Aggregate by week if too many days
      if (userCounts.length > 30) {
        userCounts = _aggregateByWeek(userCounts);
        months = List.generate(userCounts.length, (i) => 'Wk ${i + 1}');
      }
    }

    // Aggregate by week for longer ranges
    if (_selectedRange == 'Last 30 Days' ||
        _selectedRange == 'Last 60 Days' ||
        _selectedRange == 'Last 90 Days') {
      userCounts = _aggregateByWeek(userCounts);
      months = List.generate(userCounts.length, (i) => 'Wk ${i + 1}');
    }

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
                      'User Growth',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Track how your user base grows over time',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.blueGrey,
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
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 35),
                child: SizedBox(
                  height: 350,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12.0),
                    child: LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: true,
                          horizontalInterval: 25,
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
                                // Dynamically choose interval for y-axis
                                double maxY =
                                    (userCounts.reduce(
                                              (a, b) => a > b ? a : b,
                                            ) *
                                            1.2)
                                        .toDouble();
                                double interval = 25;
                                if (maxY > 500)
                                  interval = 100;
                                else if (maxY > 200)
                                  interval = 50;
                                else if (maxY > 100)
                                  interval = 20;
                                else if (maxY > 50)
                                  interval = 10;
                                if (value % interval == 0) {
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
                              interval: 25,
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              getTitlesWidget: (value, meta) {
                                final idx = value.toInt();
                                if (idx >= 0 && idx < months.length) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      _barLabel(idx, months),
                                      style: const TextStyle(
                                        fontSize: 16,
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
                        maxX: (months.length - 1).toDouble(),
                        minY: 0,
                        maxY:
                            (userCounts.reduce((a, b) => a > b ? a : b) * 1.2)
                                .toDouble(),
                        lineBarsData: [
                          LineChartBarData(
                            spots: [
                              for (int i = 0; i < months.length; i++)
                                FlSpot(i.toDouble(), userCounts[i].toDouble()),
                            ],
                            isCurved: true,
                            color: Colors.blue,
                            barWidth: 6,
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                colors: [
                                  Colors.blue.withOpacity(0.3),
                                  Colors.blue.withOpacity(0.05),
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
                                        strokeColor: Colors.blue,
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
            Text(
              'This chart shows the growth of total users for the selected range.',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
