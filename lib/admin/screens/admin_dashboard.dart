import 'package:flutter/material.dart';
import '../models/admin_user.dart';
import 'user_management.dart';
// import 'expert_management.dart';
import 'reports.dart';
import 'settings.dart';
import 'reports.dart' show DiseaseDistributionChart, TotalReportsCard;
import '../models/user_store.dart';
import '../shared/total_users_card.dart';
import '../shared/pending_approvals_card.dart';

class AdminDashboard extends StatefulWidget {
  final AdminUser adminUser;
  const AdminDashboard({Key? key, required this.adminUser}) : super(key: key);

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;

  // Dummy data for disease distribution (same as in reports.dart)
  final List<Map<String, dynamic>> _diseaseStats = [
    {'name': 'Anthracnose', 'count': 156, 'percentage': 0.25},
    {'name': 'Bacterial Blackspot', 'count': 98, 'percentage': 0.16},
    {'name': 'Powdery Mildew', 'count': 145, 'percentage': 0.23},
    {'name': 'Dieback', 'count': 70, 'percentage': 0.11},
    {'name': 'Tip Burn (Unknown)', 'count': 42, 'percentage': 0.07},
    {'name': 'Healthy', 'count': 112, 'percentage': 0.18},
  ];

  // Dummy data for reports trend
  final List<Map<String, dynamic>> _reportsTrend = [
    {'date': '2024-03-01', 'count': 45},
    {'date': '2024-03-02', 'count': 52},
    {'date': '2024-03-03', 'count': 48},
    {'date': '2024-03-04', 'count': 65},
    {'date': '2024-03-05', 'count': 58},
    {'date': '2024-03-06', 'count': 72},
    {'date': '2024-03-07', 'count': 68},
  ];

  @override
  void initState() {
    super.initState();
  }

  Widget _buildDashboard() {
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
                  'Dashboard',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Welcome, ${widget.adminUser.username}',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Stats Grid
            Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 3,
                  crossAxisSpacing: 24,
                  mainAxisSpacing: 24,
                  childAspectRatio: 1.8,
                  children: [
                    const TotalUsersCard(),
                    const PendingApprovalsCard(),
                    TotalReportsCard(reportsTrend: _reportsTrend),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Quick Accept Section
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Pending Approvals',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _selectedIndex = 1; // Switch to Users tab
                            });
                          },
                          icon: const Icon(Icons.people),
                          label: const Text('View All Users'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Name')),
                          DataColumn(label: Text('Email')),
                          DataColumn(label: Text('Role')),
                          DataColumn(label: Text('Registered')),
                          DataColumn(label: Text('Last Active')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows:
                            UserStore.users
                                .where((user) => user['status'] == 'pending')
                                .map(
                                  (user) => DataRow(
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
                                            color:
                                                user['role'] == 'expert'
                                                    ? Colors.purple.withOpacity(
                                                      0.1,
                                                    )
                                                    : Colors.blue.withOpacity(
                                                      0.1,
                                                    ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Text(
                                            user['role']
                                                .toString()
                                                .toUpperCase(),
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
                                      DataCell(Text(user['lastActive'] ?? '-')),
                                      DataCell(
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.green,
                                                foregroundColor: Colors.white,
                                                padding:
                                                    const EdgeInsets.symmetric(
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
                                                    backgroundColor:
                                                        Colors.green,
                                                  ),
                                                );
                                              },
                                            ),
                                            const SizedBox(width: 8),
                                            IconButton(
                                              icon: const Icon(Icons.edit),
                                              color: Colors.blue,
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
                                                      title: const Text(
                                                        'Edit User',
                                                      ),
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
                                                                    labelText:
                                                                        'Name',
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
                                                                          value:
                                                                              s,
                                                                          child: Text(
                                                                            s[0].toUpperCase() +
                                                                                s.substring(1),
                                                                          ),
                                                                        ),
                                                                      )
                                                                      .toList(),
                                                              onChanged: (
                                                                value,
                                                              ) {
                                                                if (value !=
                                                                    null)
                                                                  status =
                                                                      value;
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
                                                                  [
                                                                        'user',
                                                                        'expert',
                                                                      ]
                                                                      .map(
                                                                        (
                                                                          r,
                                                                        ) => DropdownMenuItem(
                                                                          value:
                                                                              r,
                                                                          child: Text(
                                                                            r[0].toUpperCase() +
                                                                                r.substring(1),
                                                                          ),
                                                                        ),
                                                                      )
                                                                      .toList(),
                                                              onChanged: (
                                                                value,
                                                              ) {
                                                                if (value !=
                                                                    null)
                                                                  role = value;
                                                              },
                                                              decoration:
                                                                  const InputDecoration(
                                                                    labelText:
                                                                        'Role',
                                                                  ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          onPressed:
                                                              () =>
                                                                  Navigator.pop(
                                                                    context,
                                                                    null,
                                                                  ),
                                                          child: const Text(
                                                            'Cancel',
                                                          ),
                                                        ),
                                                        ElevatedButton(
                                                          onPressed: () {
                                                            Navigator.pop(context, {
                                                              'name':
                                                                  nameController
                                                                      .text,
                                                              'email':
                                                                  emailController
                                                                      .text,
                                                              'status': status,
                                                              'role': role,
                                                            });
                                                          },
                                                          child: const Text(
                                                            'Save',
                                                          ),
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                );
                                                if (result != null) {
                                                  setState(() {
                                                    user['name'] =
                                                        result['name'];
                                                    user['email'] =
                                                        result['email'];
                                                    user['status'] =
                                                        result['status'];
                                                    user['role'] =
                                                        result['role'];
                                                  });
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        '${user['name']} has been updated',
                                                      ),
                                                      backgroundColor:
                                                          Colors.blue,
                                                    ),
                                                  );
                                                }
                                              },
                                            ),
                                            const SizedBox(width: 8),
                                            IconButton(
                                              icon: const Icon(Icons.delete),
                                              color: Colors.red,
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
                                                                () =>
                                                                    Navigator.pop(
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
                                                                    .remove(
                                                                      user,
                                                                    );
                                                              });
                                                              Navigator.pop(
                                                                context,
                                                              );
                                                              ScaffoldMessenger.of(
                                                                context,
                                                              ).showSnackBar(
                                                                SnackBar(
                                                                  content: Text(
                                                                    '${user['name']} has been deleted',
                                                                  ),
                                                                  backgroundColor:
                                                                      Colors
                                                                          .red,
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
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                                .toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Disease Distribution Chart
            DiseaseDistributionChart(diseaseStats: _diseaseStats),
            const SizedBox(height: 24),

            // Admin Activity Feed
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Recent Activity',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: 4,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (context, index) {
                        final activities = [
                          {
                            'icon': Icons.person_add,
                            'action': 'Accepted new user registration',
                            'user': 'John Doe',
                            'time': '2 hours ago',
                            'color': Colors.green,
                          },
                          {
                            'icon': Icons.verified_user,
                            'action': 'Verified expert account',
                            'user': 'Dr. Smith',
                            'time': '3 hours ago',
                            'color': Colors.blue,
                          },
                          {
                            'icon': Icons.block,
                            'action': 'Rejected user registration',
                            'user': 'Jane Smith',
                            'time': '5 hours ago',
                            'color': Colors.red,
                          },
                          {
                            'icon': Icons.edit,
                            'action': 'Updated user permissions',
                            'user': 'Mike Johnson',
                            'time': '1 day ago',
                            'color': Colors.orange,
                          },
                        ];

                        final activity = activities[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: activity['color'] as Color,
                            child: Icon(
                              activity['icon'] as IconData,
                              color: Colors.white,
                            ),
                          ),
                          title: Text(activity['action'] as String),
                          subtitle: Text(
                            '${activity['user']} • ${activity['time']}',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.more_vert),
                            onPressed: () {
                              // Show more options
                            },
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
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
    Color color, {
    double? percentChange,
    bool? isUp,
    VoidCallback? onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
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
      ),
    );
  }

  Widget _getScreen(int index) {
    switch (index) {
      case 0:
        return _buildDashboard();
      case 1:
        return const UserManagement();
      case 2:
        return const Reports();
      case 3:
        return const Settings();
      default:
        return _buildDashboard();
    }
  }

  @override
  Widget build(BuildContext context) {
    final sidebarItems = [
      {'icon': Icons.dashboard, 'label': 'Dashboard'},
      {'icon': Icons.people, 'label': 'Users'},
      {'icon': Icons.assessment, 'label': 'Reports'},
      {'icon': Icons.settings, 'label': 'Settings'},
    ];
    int? hoveredIndex;
    return StatefulBuilder(
      builder: (context, setSidebarState) {
        return Scaffold(
          body: Row(
            children: [
              // Custom Sidebar
              Container(
                width: 220,
                color: const Color(0xFF2D7204),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24.0),
                      child: Column(
                        children: [
                          Container(
                            height: 80,
                            width: 80,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                'assets/logo.png',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Admin Panel',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Sidebar Items
                    ...List.generate(sidebarItems.length, (index) {
                      final selected = _selectedIndex == index;
                      final hovered = hoveredIndex == index;
                      Color bgColor = Colors.transparent;
                      Color fgColor = Colors.white;
                      FontWeight fontWeight = FontWeight.w500;
                      if (selected) {
                        bgColor = const Color.fromARGB(255, 200, 183, 25);
                        fontWeight = FontWeight.bold;
                      } else if (hovered) {
                        bgColor = const Color.fromARGB(180, 200, 183, 25);
                        fontWeight = FontWeight.w600;
                      }
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 6.0,
                          horizontal: 12.0,
                        ),
                        child: MouseRegion(
                          onEnter:
                              (_) =>
                                  setSidebarState(() => hoveredIndex = index),
                          onExit:
                              (_) => setSidebarState(() => hoveredIndex = null),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(32),
                            onTap: () {
                              setState(() {
                                _selectedIndex = index;
                              });
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: bgColor,
                                borderRadius: BorderRadius.circular(32),
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 10,
                                horizontal: 18,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    sidebarItems[index]['icon'] as IconData,
                                    color: fgColor,
                                    size: 28,
                                  ),
                                  const SizedBox(width: 16),
                                  Text(
                                    sidebarItems[index]['label'] as String,
                                    style: TextStyle(
                                      color: fgColor,
                                      fontSize: 16,
                                      fontWeight: fontWeight,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                    const Spacer(),
                  ],
                ),
              ),
              // Main Content
              Expanded(child: _getScreen(_selectedIndex)),
            ],
          ),
        );
      },
    );
  }
}
