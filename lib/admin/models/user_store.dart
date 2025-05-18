class UserStore {
  static final List<Map<String, dynamic>> users = [
    {
      'id': 'USER_001',
      'name': 'John Doe',
      'address': '123 Mango St.',
      'phone': '09171234567',
      'email': 'john@example.com',
      'status': 'pending',
      'role': 'user',
      'registeredAt': '2024-03-15 10:30',
      'lastActive': '2024-03-15 10:30',
      'lastLogin': '2024-06-10 09:00',
    },
    {
      'id': 'USER_002',
      'name': 'Jane Smith',
      'address': '456 Orchard Ave.',
      'phone': '09179876543',
      'email': 'jane@example.com',
      'status': 'active',
      'role': 'user',
      'registeredAt': '2024-03-14 15:45',
      'lastActive': '2024-03-15 09:20',
      'lastLogin': '2024-06-09 18:30',
    },
    {
      'id': 'USER_003',
      'name': 'Mike Johnson',
      'address': '789 Farm Rd.',
      'phone': '09170001122',
      'email': 'mike@example.com',
      'status': 'active',
      'role': 'expert',
      'registeredAt': '2024-03-13 09:15',
      'lastActive': '2024-03-14 16:30',
      'lastLogin': '2024-06-10 08:00',
      'averageResponseTime': 120, // in minutes
    },
  ];

  static final List<Map<String, dynamic>> userActivity = [
    {'date': '2024-06-01', 'logins': 10, 'reports': 5},
    {'date': '2024-06-02', 'logins': 15, 'reports': 8},
    {'date': '2024-06-03', 'logins': 12, 'reports': 6},
    {'date': '2024-06-04', 'logins': 18, 'reports': 10},
    {'date': '2024-06-05', 'logins': 20, 'reports': 12},
    {'date': '2024-06-06', 'logins': 14, 'reports': 7},
    {'date': '2024-06-07', 'logins': 17, 'reports': 9},
  ];
}
