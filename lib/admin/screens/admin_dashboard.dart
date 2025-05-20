import 'package:flutter/material.dart';
import '../models/admin_user.dart';
import 'user_management.dart';
// import 'expert_management.dart';
import 'reports.dart';
import 'settings.dart';
import 'reports.dart' show DiseaseDistributionChart;

class AdminDashboard extends StatefulWidget {
  final AdminUser adminUser;
  const AdminDashboard({Key? key, required this.adminUser}) : super(key: key);

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;
  late List<Widget> _screens;

  // Dummy data for disease distribution (same as in reports.dart)
  final List<Map<String, dynamic>> _diseaseStats = [
    {'name': 'Anthracnose', 'count': 156, 'percentage': 0.25},
    {'name': 'Bacterial Blackspot', 'count': 98, 'percentage': 0.16},
    {'name': 'Powdery Mildew', 'count': 145, 'percentage': 0.23},
    {'name': 'Dieback', 'count': 70, 'percentage': 0.11},
    {'name': 'Tip Burn (Unknown)', 'count': 42, 'percentage': 0.07},
    {'name': 'Healthy', 'count': 112, 'percentage': 0.18},
  ];

  @override
  void initState() {
    super.initState();
    _screens = [
      _buildDashboard(),
      const UserManagement(),
      // const ExpertManagement(),
      const Reports(),
      const Settings(),
    ];
  }

  Widget _buildDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Section (left-aligned, no card)
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, ${widget.adminUser.username}!',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Last login: ${widget.adminUser.lastLogin.toString()}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ],
            ),
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
                  _buildStatCard(
                    'Total Users',
                    '1,234',
                    Icons.people,
                    Colors.blue,
                  ),
                  _buildStatCard(
                    'Pending Approvals',
                    '12',
                    Icons.pending_actions,
                    Colors.orange,
                  ),
                  _buildStatCard(
                    'Total Reports',
                    '567',
                    Icons.assessment,
                    Colors.purple,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Disease Distribution Chart
          DiseaseDistributionChart(diseaseStats: _diseaseStats),

          // Recent Activity
          Center(
            child: Column(
              children: [
                const Text(
                  'Recent Activity',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Card(
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: 5,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.green[100],
                          child: Icon(
                            Icons.person_add,
                            color: Colors.green[700],
                          ),
                        ),
                        title: Text('New User Registration #${1000 + index}'),
                        subtitle: Text('2 hours ago'),
                        trailing: IconButton(
                          icon: const Icon(Icons.check_circle_outline),
                          color: Colors.green,
                          onPressed: () {
                            // Handle approval
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return StatefulBuilder(
      builder: (context, setState) {
        bool isHovered = false;
        return MouseRegion(
          onEnter: (_) => setState(() => isHovered = true),
          onExit: (_) => setState(() => isHovered = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            transform:
                Matrix4.identity()..translate(0.0, isHovered ? -5.0 : 0.0, 0.0),
            child: Card(
              elevation: isHovered ? 8 : 2,
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
          ),
        );
      },
    );
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
              Expanded(child: _screens[_selectedIndex]),
            ],
          ),
        );
      },
    );
  }
}
