import 'package:flutter/material.dart';
import '../models/user_store.dart';

class PendingApprovalsCard extends StatelessWidget {
  final double? width;
  const PendingApprovalsCard({Key? key, this.width}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final int pendingCount =
        UserStore.users.where((u) => u['status'] == 'pending').length;
    return Card(
      child: Container(
        width: width,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pending_actions, size: 32, color: Colors.orange),
            const SizedBox(height: 8),
            Text(
              pendingCount.toString(),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Pending Approvals',
              style: TextStyle(color: Colors.grey, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
