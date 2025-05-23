import 'package:flutter/material.dart';
import '../models/user_store.dart';

class UserManagement extends StatefulWidget {
  const UserManagement({Key? key}) : super(key: key);

  @override
  State<UserManagement> createState() => _UserManagementState();
}

class _UserManagementState extends State<UserManagement> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'All';

  List<Map<String, dynamic>> get _filteredUsers {
    final filtered =
        UserStore.users.where((user) {
          final matchesSearch =
              user['name'].toString().toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ) ||
              user['email'].toString().toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ) ||
              user['role'].toString().toLowerCase().contains(
                _searchQuery.toLowerCase(),
              );
          final matchesStatus =
              _selectedFilter == 'All' ||
              user['status'] == _selectedFilter.toLowerCase();
          return matchesSearch && matchesStatus;
        }).toList();

    // Sort by name only
    filtered.sort(
      (a, b) => a['name'].toString().compareTo(b['name'].toString()),
    );
    return filtered;
  }

  @override
  void dispose() {
    _searchController.dispose();
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
            'User Management',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search... (name, email, or role)',
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
                    ['All', 'Pending', 'Active']
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
            child: Card(
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
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      user['role'] == 'expert'
                                          ? Colors.purple.withOpacity(0.1)
                                          : Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  user['role'].toString().toUpperCase(),
                                  style: TextStyle(
                                    color:
                                        user['role'] == 'expert'
                                            ? Colors.purple
                                            : Colors.blue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(Text(user['registeredAt'])),
                            DataCell(Text(user['lastActive'])),
                            DataCell(
                              SizedBox(
                                height: 40,
                                child: Row(
                                  mainAxisSize: MainAxisSize.max,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    if (user['status'] == 'pending')
                                      SizedBox(
                                        height: 36,
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 0,
                                            ),
                                            minimumSize: const Size(92, 36),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          child: const Text('Accept'),
                                          onPressed: () {
                                            setState(() {
                                              user['status'] = 'active';
                                            });
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  '${user['name']} has been accepted',
                                                ),
                                                backgroundColor: Colors.green,
                                              ),
                                            );
                                          },
                                        ),
                                      )
                                    else
                                      const SizedBox(width: 92, height: 36),
                                    const Spacer(),
                                    Align(
                                      alignment: Alignment.center,
                                      child: IconButton(
                                        icon: const Icon(Icons.edit),
                                        color: Colors.blue,
                                        tooltip: 'Edit User',
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () async {
                                          final nameController =
                                              TextEditingController(
                                                text: user['name'],
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
                                                  ElevatedButton(
                                                    onPressed: () {
                                                      Navigator.pop(context, {
                                                        'name':
                                                            nameController.text,
                                                        'email':
                                                            emailController
                                                                .text,
                                                        'status': status,
                                                        'role': role,
                                                      });
                                                    },
                                                    child: const Text('Save'),
                                                  ),
                                                ],
                                              );
                                            },
                                          );

                                          if (result != null) {
                                            setState(() {
                                              user['name'] = result['name'];
                                              user['email'] = result['email'];
                                              user['status'] = result['status'];
                                              user['role'] = result['role'];
                                            });
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  '${user['name']} has been updated',
                                                ),
                                                backgroundColor: Colors.blue,
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                    ),
                                    Align(
                                      alignment: Alignment.center,
                                      child: IconButton(
                                        icon: const Icon(Icons.delete),
                                        color: Colors.red,
                                        tooltip: 'Delete User',
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () {
                                          showDialog(
                                            context: context,
                                            builder:
                                                (context) => AlertDialog(
                                                  title: const Text(
                                                    'Delete User',
                                                  ),
                                                  content: Text(
                                                    'Are you sure you want to delete ${user['name']}?',
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed:
                                                          () => Navigator.pop(
                                                            context,
                                                          ),
                                                      child: const Text(
                                                        'Cancel',
                                                      ),
                                                    ),
                                                    TextButton(
                                                      onPressed: () {
                                                        setState(() {
                                                          UserStore.users
                                                              .remove(user);
                                                        });
                                                        Navigator.pop(context);
                                                        ScaffoldMessenger.of(
                                                          context,
                                                        ).showSnackBar(
                                                          SnackBar(
                                                            content: Text(
                                                              '${user['name']} has been deleted',
                                                            ),
                                                            backgroundColor:
                                                                Colors.red,
                                                          ),
                                                        );
                                                      },
                                                      child: const Text(
                                                        'Delete',
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                ),
              ),
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
