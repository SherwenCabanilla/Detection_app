import 'package:flutter/material.dart';

class ReportDetailScreen extends StatelessWidget {
  final Map<String, dynamic> report;
  const ReportDetailScreen({Key? key, required this.report}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Report Details: ${report['id']}'),
        backgroundColor: Colors.green,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Report ID: ${report['id']}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('User: ${report['user']}'),
                Text('Date: ${report['date']}'),
                Text('Disease: ${report['disease']}'),
                Text('Status: ${report['status']}'),
                const SizedBox(height: 16),
                if (report['image'] != null)
                  Container(
                    height: 180,
                    width: 180,
                    color: Colors.grey[200],
                    child: Image.network(report['image'], fit: BoxFit.cover),
                  )
                else
                  Container(
                    height: 180,
                    width: 180,
                    color: Colors.grey[200],
                    child: const Center(child: Text('No Image')),
                  ),
                const SizedBox(height: 16),
                Text('Details: ${report['details']}'),
                const SizedBox(height: 8),
                Text('Expert: ${report['expert'] ?? "-"}'),
                Text('Feedback: ${report['feedback'] ?? "-"}'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
