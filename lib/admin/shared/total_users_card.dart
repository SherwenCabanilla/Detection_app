import 'package:flutter/material.dart';
import '../models/user_store.dart';

class TotalUsersCard extends StatelessWidget {
  final double? width;
  const TotalUsersCard({Key? key, this.width}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final int totalUsers =
        UserStore.users.where((u) => u['status'] == 'active').length;
    return Card(
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
    );
  }
}
