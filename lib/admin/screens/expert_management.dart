import 'package:flutter/material.dart';

class ExpertManagement extends StatefulWidget {
  const ExpertManagement({Key? key}) : super(key: key);

  @override
  State<ExpertManagement> createState() => _ExpertManagementState();
}

class _ExpertManagementState extends State<ExpertManagement> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'All';

  // Dummy data for testing
  final List<Map<String, dynamic>> _experts = [
    {
      'id': 'EXP_001',
      'name': 'Dr. Sarah Wilson',
      'email': 'sarah@example.com',
      'specialization': 'Plant Pathology',
      'status': 'pending',
      'registeredAt': '2024-03-15 09:30',
      'lastActive': '2024-03-15 09:30',
      'reviewsCompleted': 0,
    },
    {
      'id': 'EXP_002',
      'name': 'Dr. James Brown',
      'email': 'james@example.com',
      'specialization': 'Agricultural Science',
      'status': 'active',
      'registeredAt': '2024-03-14 14:20',
      'lastActive': '2024-03-15 08:45',
      'reviewsCompleted': 156,
    },
    {
      'id': 'EXP_003',
      'name': 'Dr. Emily Davis',
      'email': 'emily@example.com',
      'specialization': 'Crop Protection',
      'status': 'suspended',
      'registeredAt': '2024-03-13 11:15',
      'lastActive': '2024-03-14 15:30',
      'reviewsCompleted': 89,
    },
  ];

  List<Map<String, dynamic>> get _filteredExperts {
    return _experts.where((expert) {
      final matchesSearch =
          expert['name'].toString().toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          expert['email'].toString().toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          expert['specialization'].toString().toLowerCase().contains(
            _searchQuery.toLowerCase(),
          );

      final matchesFilter =
          _selectedFilter == 'All' ||
          expert['status'] == _selectedFilter.toLowerCase();

      return matchesSearch && matchesFilter;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Text(
            'Expert Management',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),

          // Search and Filter Bar
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search experts...',
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

          // Experts Table
          Expanded(
            child: Card(
              child: SingleChildScrollView(
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Name')),
                    DataColumn(label: Text('Specialization')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Reviews')),
                    DataColumn(label: Text('Registered')),
                    DataColumn(label: Text('Last Active')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows:
                      _filteredExperts.map((expert) {
                        return DataRow(
                          cells: [
                            DataCell(Text(expert['name'])),
                            DataCell(Text(expert['specialization'])),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(
                                    expert['status'],
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  expert['status'].toString().toUpperCase(),
                                  style: TextStyle(
                                    color: _getStatusColor(expert['status']),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              Text(expert['reviewsCompleted'].toString()),
                            ),
                            DataCell(Text(expert['registeredAt'])),
                            DataCell(Text(expert['lastActive'])),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (expert['status'] == 'pending')
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
                                    onPressed: () {
                                      // Handle edit
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
