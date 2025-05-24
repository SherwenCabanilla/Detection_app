import 'package:flutter/material.dart';

class Settings extends StatefulWidget {
  final VoidCallback? onViewReports;
  const Settings({Key? key, this.onViewReports}) : super(key: key);

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  bool _emailNotifications = true;
  String _selectedLanguage = 'English';
  String? _email = 'admin@example.com';

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Settings',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),

          // Profile Settings
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Profile Settings',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.email),
                  title: const Text('Edit Email'),
                  subtitle: Text(_email ?? 'admin@example.com'),
                  onTap: () async {
                    final newEmail = await showDialog<String>(
                      context: context,
                      builder: (context) {
                        final controller = TextEditingController(
                          text: _email ?? 'admin@example.com',
                        );
                        return AlertDialog(
                          title: const Text('Edit Email'),
                          content: TextField(
                            controller: controller,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                            ),
                            keyboardType: TextInputType.emailAddress,
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context, controller.text);
                              },
                              child: const Text('Save'),
                            ),
                          ],
                        );
                      },
                    );
                    if (newEmail != null && newEmail.isNotEmpty) {
                      setState(() {
                        _email = newEmail;
                      });
                    }
                  },
                ),
                StatefulBuilder(
                  builder: (context, setState) {
                    bool isHovered = false;
                    return MouseRegion(
                      onEnter: (_) => setState(() => isHovered = true),
                      onExit: (_) => setState(() => isHovered = false),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color:
                              isHovered ? Colors.green.withOpacity(0.1) : null,
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.lock),
                          title: const Text('Change Password'),
                          subtitle: const Text(
                            'Update your admin account password',
                          ),
                          onTap: () async {
                            final currentPasswordController =
                                TextEditingController();
                            final newPasswordController =
                                TextEditingController();
                            final confirmPasswordController =
                                TextEditingController();
                            String? errorMessage;
                            final result = await showDialog<bool>(
                              context: context,
                              barrierDismissible: false,
                              builder: (context) {
                                return StatefulBuilder(
                                  builder: (context, setState) {
                                    return AlertDialog(
                                      title: const Text('Change Password'),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          TextField(
                                            controller:
                                                currentPasswordController,
                                            obscureText: true,
                                            decoration: const InputDecoration(
                                              labelText: 'Current Password',
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          TextField(
                                            controller: newPasswordController,
                                            obscureText: true,
                                            decoration: const InputDecoration(
                                              labelText: 'New Password',
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          TextField(
                                            controller:
                                                confirmPasswordController,
                                            obscureText: true,
                                            decoration: const InputDecoration(
                                              labelText: 'Confirm New Password',
                                            ),
                                          ),
                                          if (errorMessage != null) ...[
                                            const SizedBox(height: 10),
                                            Text(
                                              errorMessage!,
                                              style: const TextStyle(
                                                color: Colors.red,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed:
                                              () =>
                                                  Navigator.pop(context, false),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            showDialog(
                                              context: context,
                                              builder:
                                                  (context) => AlertDialog(
                                                    title: const Text(
                                                      'Forgot Password?',
                                                    ),
                                                    content: const Text(
                                                      'Please contact the system administrator to reset your password.',
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                        onPressed:
                                                            () => Navigator.pop(
                                                              context,
                                                            ),
                                                        child: const Text('OK'),
                                                      ),
                                                    ],
                                                  ),
                                            );
                                          },
                                          child: const Text('Forgot Password?'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () {
                                            final current =
                                                currentPasswordController.text
                                                    .trim();
                                            final newPass =
                                                newPasswordController.text
                                                    .trim();
                                            final confirm =
                                                confirmPasswordController.text
                                                    .trim();
                                            if (current.isEmpty ||
                                                newPass.isEmpty ||
                                                confirm.isEmpty) {
                                              setState(() {
                                                errorMessage =
                                                    'All fields are required.';
                                              });
                                              return;
                                            }
                                            if (newPass != confirm) {
                                              setState(() {
                                                errorMessage =
                                                    'New passwords do not match.';
                                              });
                                              return;
                                            }
                                            // Here you would add logic to verify the current password and update it.
                                            Navigator.pop(context, true);
                                          },
                                          child: const Text('Save'),
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                            );
                            if (result == true) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Password changed successfully!',
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Notification Settings
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Notification Settings',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.email),
                  title: const Text('Email Notifications'),
                  subtitle: const Text('Receive notifications via email'),
                  value: _emailNotifications,
                  onChanged: (bool value) {
                    setState(() {
                      _emailNotifications = value;
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // System Management
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'System Management',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ),
                StatefulBuilder(
                  builder: (context, setState) {
                    bool isHovered = false;
                    return MouseRegion(
                      onEnter: (_) => setState(() => isHovered = true),
                      onExit: (_) => setState(() => isHovered = false),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color:
                              isHovered ? Colors.green.withOpacity(0.1) : null,
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.assessment),
                          title: const Text('View Reports'),
                          subtitle: const Text('Access system reports'),
                          onTap: widget.onViewReports,
                        ),
                      ),
                    );
                  },
                ),
                const Divider(),
                StatefulBuilder(
                  builder: (context, setState) {
                    bool isHovered = false;
                    return MouseRegion(
                      onEnter: (_) => setState(() => isHovered = true),
                      onExit: (_) => setState(() => isHovered = false),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: isHovered ? Colors.red.withOpacity(0.1) : null,
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.logout, color: Colors.red),
                          title: const Text(
                            'Logout',
                            style: TextStyle(color: Colors.red),
                          ),
                          onTap: () {
                            Navigator.of(context).pushNamedAndRemoveUntil(
                              '/login',
                              (route) => false,
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
