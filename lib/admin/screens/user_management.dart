import 'package:flutter/material.dart';
import '../models/user_store.dart';

class UserManagement extends StatefulWidget {
  const UserManagement({Key? key}) : super(key: key);

  @override
  State<UserManagement> createState() => _UserManagementState();
}

class _UserManagementState extends State<UserManagement>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'All';
  late TabController _tabController;

  // Dummy data for testing
  final List<Map<String, dynamic>> _users = [
    {
      'id': 'USER_001',
      'name': 'John Doe',
      'email': 'john@example.com',
      'status': 'pending',
      'role': 'user',
      'registeredAt': '2024-03-15 10:30',
      'lastActive': '2024-03-15 10:30',
    },
    {
      'id': 'USER_002',
      'name': 'Jane Smith',
      'email': 'jane@example.com',
      'status': 'active',
      'role': 'user',
      'registeredAt': '2024-03-14 15:45',
      'lastActive': '2024-03-15 09:20',
    },
    {
      'id': 'USER_003',
      'name': 'Mike Johnson',
      'email': 'mike@example.com',
      'status': 'active',
      'role': 'expert',
      'registeredAt': '2024-03-13 09:15',
      'lastActive': '2024-03-14 16:30',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  List<Map<String, dynamic>> get _filteredUsers =>
      _users.where((user) {
        final matchesSearch =
            user['name'].toString().toLowerCase().contains(
              _searchQuery.toLowerCase(),
            ) ||
            user['email'].toString().toLowerCase().contains(
              _searchQuery.toLowerCase(),
            );
        final matchesFilter =
            _selectedFilter == 'All' ||
            user['status'] == _selectedFilter.toLowerCase();
        return matchesSearch && matchesFilter && user['role'] == 'user';
      }).toList();

  List<Map<String, dynamic>> get _filteredExperts =>
      _users.where((user) {
        final matchesSearch =
            user['name'].toString().toLowerCase().contains(
              _searchQuery.toLowerCase(),
            ) ||
            user['email'].toString().toLowerCase().contains(
              _searchQuery.toLowerCase(),
            );
        final matchesFilter =
            _selectedFilter == 'All' ||
            user['status'] == _selectedFilter.toLowerCase();
        return matchesSearch && matchesFilter && user['role'] == 'expert';
      }).toList();

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'User & Expert Management',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          TabBar(
            controller: _tabController,
            tabs: const [Tab(text: 'Users'), Tab(text: 'Experts')],
            labelColor: Colors.green,
            unselectedLabelColor: Colors.black54,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search... (name or email)',
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
              const SizedBox(width: 16),
              DropdownButton<String>(
                value: _selectedFilter,
                items:
                    ['All', 'Pending', 'Active', 'Suspended']
                        .map(
                          (status) => DropdownMenuItem(
                            value: status,
                            child: Text(status),
                          ),
                        )
                        .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedFilter = value;
                    });
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Users Table
                Card(
                  child: SingleChildScrollView(
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Name')),
                        DataColumn(label: Text('Email')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Role')),
                        DataColumn(label: Text('Registered')),
                        DataColumn(label: Text('Last Active')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows:
                          _filteredUsers.map((user) {
                            return DataRow(
                              cells: [
                                DataCell(Text(user['name'])),
                                DataCell(Text(user['email'])),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(
                                        user['status'],
                                      ).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      user['status'].toString().toUpperCase(),
                                      style: TextStyle(
                                        color: _getStatusColor(user['status']),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  DropdownButton<String>(
                                    value: user['role'],
                                    items:
                                        ['user', 'expert']
                                            .map(
                                              (role) => DropdownMenuItem(
                                                value: role,
                                                child: Text(
                                                  role[0].toUpperCase() +
                                                      role.substring(1),
                                                ),
                                              ),
                                            )
                                            .toList(),
                                    onChanged: (value) {
                                      if (value != null) {
                                        setState(() {
                                          user['role'] = value;
                                        });
                                      }
                                    },
                                  ),
                                ),
                                DataCell(Text(user['registeredAt'])),
                                DataCell(Text(user['lastActive'])),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (user['status'] == 'pending')
                                        IconButton(
                                          icon: const Icon(
                                            Icons.check_circle_outline,
                                          ),
                                          color: Colors.green,
                                          onPressed: () {
                                            // Handle approval
                                          },
                                        ),
                                      IconButton(
                                        icon: const Icon(Icons.edit),
                                        color: Colors.blue,
                                        onPressed: () async {
                                          final nameController =
                                              TextEditingController(
                                                text: user['name'],
                                              );
                                          final addressController =
                                              TextEditingController(
                                                text: user['address'] ?? '',
                                              );
                                          final phoneController =
                                              TextEditingController(
                                                text: user['phone'] ?? '',
                                              );
                                          final emailController =
                                              TextEditingController(
                                                text: user['email'],
                                              );
                                          String status = user['status'];
                                          String role = user['role'];
                                          final result = await showDialog<
                                            Map<String, dynamic>
                                          >(
                                            context: context,
                                            builder: (context) {
                                              return AlertDialog(
                                                title: const Text('Edit User'),
                                                content: SingleChildScrollView(
                                                  child: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      TextField(
                                                        controller:
                                                            nameController,
                                                        decoration:
                                                            const InputDecoration(
                                                              labelText: 'Name',
                                                            ),
                                                      ),
                                                      TextField(
                                                        controller:
                                                            addressController,
                                                        decoration:
                                                            const InputDecoration(
                                                              labelText:
                                                                  'Address',
                                                            ),
                                                      ),
                                                      TextField(
                                                        controller:
                                                            phoneController,
                                                        decoration:
                                                            const InputDecoration(
                                                              labelText:
                                                                  'Phone Number',
                                                            ),
                                                      ),
                                                      TextField(
                                                        controller:
                                                            emailController,
                                                        decoration:
                                                            const InputDecoration(
                                                              labelText:
                                                                  'Email',
                                                            ),
                                                      ),
                                                      DropdownButtonFormField<
                                                        String
                                                      >(
                                                        value: status,
                                                        items:
                                                            [
                                                                  'pending',
                                                                  'active',
                                                                  'suspended',
                                                                ]
                                                                .map(
                                                                  (
                                                                    s,
                                                                  ) => DropdownMenuItem(
                                                                    value: s,
                                                                    child: Text(
                                                                      s[0].toUpperCase() +
                                                                          s.substring(1),
                                                                    ),
                                                                  ),
                                                                )
                                                                .toList(),
                                                        onChanged: (value) {
                                                          if (value != null)
                                                            status = value;
                                                        },
                                                        decoration:
                                                            const InputDecoration(
                                                              labelText:
                                                                  'Status',
                                                            ),
                                                      ),
                                                      DropdownButtonFormField<
                                                        String
                                                      >(
                                                        value: role,
                                                        items:
                                                            ['user', 'expert']
                                                                .map(
                                                                  (
                                                                    r,
                                                                  ) => DropdownMenuItem(
                                                                    value: r,
                                                                    child: Text(
                                                                      r[0].toUpperCase() +
                                                                          r.substring(1),
                                                                    ),
                                                                  ),
                                                                )
                                                                .toList(),
                                                        onChanged: (value) {
                                                          if (value != null)
                                                            role = value;
                                                        },
                                                        decoration:
                                                            const InputDecoration(
                                                              labelText: 'Role',
                                                            ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed:
                                                        () => Navigator.pop(
                                                          context,
                                                          null,
                                                        ),
                                                    child: const Text('Cancel'),
                                                  ),
                                                  TextButton(
                                                    onPressed: () async {
                                                      final passwordController =
                                                          TextEditingController();
                                                      final reset = await showDialog<
                                                        String
                                                      >(
                                                        context: context,
                                                        builder: (context) {
                                                          return AlertDialog(
                                                            title: const Text(
                                                              'Reset Password',
                                                            ),
                                                            content: TextField(
                                                              controller:
                                                                  passwordController,
                                                              decoration:
                                                                  const InputDecoration(
                                                                    labelText:
                                                                        'New Password',
                                                                  ),
                                                              obscureText: true,
                                                            ),
                                                            actions: [
                                                              TextButton(
                                                                onPressed:
                                                                    () => Navigator.pop(
                                                                      context,
                                                                      null,
                                                                    ),
                                                                child:
                                                                    const Text(
                                                                      'Cancel',
                                                                    ),
                                                              ),
                                                              ElevatedButton(
                                                                onPressed:
                                                                    () => Navigator.pop(
                                                                      context,
                                                                      passwordController
                                                                          .text,
                                                                    ),
                                                                child:
                                                                    const Text(
                                                                      'Save',
                                                                    ),
                                                              ),
                                                            ],
                                                          );
                                                        },
                                                      );
                                                      if (reset != null &&
                                                          reset.isNotEmpty) {
                                                        setState(() {
                                                          user['password'] =
                                                              reset;
                                                        });
                                                        ScaffoldMessenger.of(
                                                          context,
                                                        ).showSnackBar(
                                                          const SnackBar(
                                                            content: Text(
                                                              'Password reset successfully!',
                                                            ),
                                                          ),
                                                        );
                                                      }
                                                    },
                                                    child: const Text(
                                                      'Reset Password',
                                                    ),
                                                  ),
                                                  ElevatedButton(
                                                    child: const Text('Save'),
                                                    onPressed: () {
                                                      Navigator.pop(context, {
                                                        'name':
                                                            nameController.text,
                                                        'address':
                                                            addressController
                                                                .text,
                                                        'phone':
                                                            phoneController
                                                                .text,
                                                        'email':
                                                            emailController
                                                                .text,
                                                        'status': status,
                                                        'role': role,
                                                      });
                                                    },
                                                  ),
                                                ],
                                              );
                                            },
                                          );
                                          if (result != null) {
                                            setState(() {
                                              user['name'] = result['name'];
                                              user['address'] =
                                                  result['address'];
                                              user['phone'] = result['phone'];
                                              user['email'] = result['email'];
                                              user['status'] = result['status'];
                                              user['role'] = result['role'];
                                            });
                                          }
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete),
                                        color: Colors.red,
                                        onPressed: () {
                                          // Handle delete
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                    ),
                  ),
                ),
                // Experts Table
                Card(
                  child: SingleChildScrollView(
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Name')),
                        DataColumn(label: Text('Email')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Role')),
                        DataColumn(label: Text('Registered')),
                        DataColumn(label: Text('Last Active')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows:
                          _filteredExperts.map((user) {
                            return DataRow(
                              cells: [
                                DataCell(Text(user['name'])),
                                DataCell(Text(user['email'])),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(
                                        user['status'],
                                      ).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      user['status'].toString().toUpperCase(),
                                      style: TextStyle(
                                        color: _getStatusColor(user['status']),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  DropdownButton<String>(
                                    value: user['role'],
                                    items:
                                        ['user', 'expert']
                                            .map(
                                              (role) => DropdownMenuItem(
                                                value: role,
                                                child: Text(
                                                  role[0].toUpperCase() +
                                                      role.substring(1),
                                                ),
                                              ),
                                            )
                                            .toList(),
                                    onChanged: (value) {
                                      if (value != null) {
                                        setState(() {
                                          user['role'] = value;
                                        });
                                      }
                                    },
                                  ),
                                ),
                                DataCell(Text(user['registeredAt'])),
                                DataCell(Text(user['lastActive'])),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (user['status'] == 'pending')
                                        IconButton(
                                          icon: const Icon(
                                            Icons.check_circle_outline,
                                          ),
                                          color: Colors.green,
                                          onPressed: () {
                                            // Handle approval
                                          },
                                        ),
                                      IconButton(
                                        icon: const Icon(Icons.edit),
                                        color: Colors.blue,
                                        onPressed: () async {
                                          final nameController =
                                              TextEditingController(
                                                text: user['name'],
                                              );
                                          final addressController =
                                              TextEditingController(
                                                text: user['address'] ?? '',
                                              );
                                          final phoneController =
                                              TextEditingController(
                                                text: user['phone'] ?? '',
                                              );
                                          final emailController =
                                              TextEditingController(
                                                text: user['email'],
                                              );
                                          String status = user['status'];
                                          String role = user['role'];
                                          final result = await showDialog<
                                            Map<String, dynamic>
                                          >(
                                            context: context,
                                            builder: (context) {
                                              return AlertDialog(
                                                title: const Text('Edit User'),
                                                content: SingleChildScrollView(
                                                  child: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      TextField(
                                                        controller:
                                                            nameController,
                                                        decoration:
                                                            const InputDecoration(
                                                              labelText: 'Name',
                                                            ),
                                                      ),
                                                      TextField(
                                                        controller:
                                                            addressController,
                                                        decoration:
                                                            const InputDecoration(
                                                              labelText:
                                                                  'Address',
                                                            ),
                                                      ),
                                                      TextField(
                                                        controller:
                                                            phoneController,
                                                        decoration:
                                                            const InputDecoration(
                                                              labelText:
                                                                  'Phone Number',
                                                            ),
                                                      ),
                                                      TextField(
                                                        controller:
                                                            emailController,
                                                        decoration:
                                                            const InputDecoration(
                                                              labelText:
                                                                  'Email',
                                                            ),
                                                      ),
                                                      DropdownButtonFormField<
                                                        String
                                                      >(
                                                        value: status,
                                                        items:
                                                            [
                                                                  'pending',
                                                                  'active',
                                                                  'suspended',
                                                                ]
                                                                .map(
                                                                  (
                                                                    s,
                                                                  ) => DropdownMenuItem(
                                                                    value: s,
                                                                    child: Text(
                                                                      s[0].toUpperCase() +
                                                                          s.substring(1),
                                                                    ),
                                                                  ),
                                                                )
                                                                .toList(),
                                                        onChanged: (value) {
                                                          if (value != null)
                                                            status = value;
                                                        },
                                                        decoration:
                                                            const InputDecoration(
                                                              labelText:
                                                                  'Status',
                                                            ),
                                                      ),
                                                      DropdownButtonFormField<
                                                        String
                                                      >(
                                                        value: role,
                                                        items:
                                                            ['user', 'expert']
                                                                .map(
                                                                  (
                                                                    r,
                                                                  ) => DropdownMenuItem(
                                                                    value: r,
                                                                    child: Text(
                                                                      r[0].toUpperCase() +
                                                                          r.substring(1),
                                                                    ),
                                                                  ),
                                                                )
                                                                .toList(),
                                                        onChanged: (value) {
                                                          if (value != null)
                                                            role = value;
                                                        },
                                                        decoration:
                                                            const InputDecoration(
                                                              labelText: 'Role',
                                                            ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed:
                                                        () => Navigator.pop(
                                                          context,
                                                          null,
                                                        ),
                                                    child: const Text('Cancel'),
                                                  ),
                                                  TextButton(
                                                    onPressed: () async {
                                                      final passwordController =
                                                          TextEditingController();
                                                      final reset = await showDialog<
                                                        String
                                                      >(
                                                        context: context,
                                                        builder: (context) {
                                                          return AlertDialog(
                                                            title: const Text(
                                                              'Reset Password',
                                                            ),
                                                            content: TextField(
                                                              controller:
                                                                  passwordController,
                                                              decoration:
                                                                  const InputDecoration(
                                                                    labelText:
                                                                        'New Password',
                                                                  ),
                                                              obscureText: true,
                                                            ),
                                                            actions: [
                                                              TextButton(
                                                                onPressed:
                                                                    () => Navigator.pop(
                                                                      context,
                                                                      null,
                                                                    ),
                                                                child:
                                                                    const Text(
                                                                      'Cancel',
                                                                    ),
                                                              ),
                                                              ElevatedButton(
                                                                onPressed:
                                                                    () => Navigator.pop(
                                                                      context,
                                                                      passwordController
                                                                          .text,
                                                                    ),
                                                                child:
                                                                    const Text(
                                                                      'Save',
                                                                    ),
                                                              ),
                                                            ],
                                                          );
                                                        },
                                                      );
                                                      if (reset != null &&
                                                          reset.isNotEmpty) {
                                                        setState(() {
                                                          user['password'] =
                                                              reset;
                                                        });
                                                        ScaffoldMessenger.of(
                                                          context,
                                                        ).showSnackBar(
                                                          const SnackBar(
                                                            content: Text(
                                                              'Password reset successfully!',
                                                            ),
                                                          ),
                                                        );
                                                      }
                                                    },
                                                    child: const Text(
                                                      'Reset Password',
                                                    ),
                                                  ),
                                                  ElevatedButton(
                                                    child: const Text('Save'),
                                                    onPressed: () {
                                                      Navigator.pop(context, {
                                                        'name':
                                                            nameController.text,
                                                        'address':
                                                            addressController
                                                                .text,
                                                        'phone':
                                                            phoneController
                                                                .text,
                                                        'email':
                                                            emailController
                                                                .text,
                                                        'status': status,
                                                        'role': role,
                                                      });
                                                    },
                                                  ),
                                                ],
                                              );
                                            },
                                          );
                                          if (result != null) {
                                            setState(() {
                                              user['name'] = result['name'];
                                              user['address'] =
                                                  result['address'];
                                              user['phone'] = result['phone'];
                                              user['email'] = result['email'];
                                              user['status'] = result['status'];
                                              user['role'] = result['role'];
                                            });
                                          }
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete),
                                        color: Colors.red,
                                        onPressed: () {
                                          // Handle delete
                                        },
                                      ),
                                    ],
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
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'suspended':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
