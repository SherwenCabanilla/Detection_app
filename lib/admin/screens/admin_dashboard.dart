import 'package:flutter/material.dart';
import '../models/admin_user.dart';
import 'user_management.dart';
// import 'expert_management.dart';
import 'reports.dart';
import 'settings.dart';

class AdminDashboard extends StatefulWidget {
  final AdminUser adminUser;
  const AdminDashboard({Key? key, required this.adminUser}) : super(key: key);

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;
  late List<Widget> _screens;

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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Welcome Section
          Center(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Welcome, ${widget.adminUser.username}!',
                      style: const TextStyle(
                        fontSize: 24,
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
    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          NavigationRail(
            extended: true,
            backgroundColor: const Color(0xFF2D7204),
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard, color: Colors.white),
                label: Text('Dashboard', style: TextStyle(color: Colors.white)),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.people, color: Colors.white),
                label: Text('Users', style: TextStyle(color: Colors.white)),
              ),
              // NavigationRailDestination(
              //   icon: Icon(Icons.medical_services, color: Colors.white),
              //   label: Text('Experts', style: TextStyle(color: Colors.white)),
              // ),
              NavigationRailDestination(
                icon: Icon(Icons.assessment, color: Colors.white),
                label: Text('Reports', style: TextStyle(color: Colors.white)),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings, color: Colors.white),
                label: Text('Settings', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
          // Main Content
          Expanded(child: _screens[_selectedIndex]),
        ],
      ),
    );
  }
}
