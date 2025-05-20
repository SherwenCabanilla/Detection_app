import 'package:flutter/material.dart';
import 'report_detail.dart';

class ReportsListScreen extends StatelessWidget {
  ReportsListScreen({Key? key}) : super(key: key);

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Reports'),
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
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
                  _dummyReports.map((report) {
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
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) =>
                                          ReportDetailScreen(report: report),
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
      ),
    );
  }
}
