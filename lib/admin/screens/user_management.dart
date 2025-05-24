import 'package:flutter/material.dart';
import '../models/user_store.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class UserManagement extends StatefulWidget {
  const UserManagement({Key? key}) : super(key: key);

  @override
  State<UserManagement> createState() => _UserManagementState();
}

class _UserManagementState extends State<UserManagement> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _horizontalScrollController = ScrollController();
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
    _horizontalScrollController.dispose();
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
          Flexible(
            fit: FlexFit.loose,
            child: Card(
              child: SizedBox(
                height: 672,
                child: Scrollbar(
                  thumbVisibility: true,
                  controller: _horizontalScrollController,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    controller: _horizontalScrollController,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Name')),
                          DataColumn(label: Text('Email')),
                          DataColumn(label: Text('Phone Number')),
                          DataColumn(label: Text('Address')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Role')),
                          DataColumn(label: Text('Registered')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows:
                            _filteredUsers.map((user) {
                              return DataRow(
                                cells: [
                                  DataCell(Text(user['name'])),
                                  DataCell(Text(user['email'])),
                                  DataCell(Text(user['phone'] ?? '')),
                                  DataCell(Text(user['address'] ?? '')),
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
                                          color: _getStatusColor(
                                            user['status'],
                                          ),
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
                                  DataCell(
                                    SizedBox(
                                      height: 40,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.max,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          if (user['status'] == 'pending')
                                            SizedBox(
                                              height: 36,
                                              child: ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.green,
                                                  foregroundColor: Colors.white,
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 16,
                                                        vertical: 0,
                                                      ),
                                                  minimumSize: const Size(
                                                    92,
                                                    36,
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
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
                                            )
                                          else
                                            const SizedBox(
                                              width: 92,
                                              height: 36,
                                            ),
                                          const Spacer(),
                                          Align(
                                            alignment: Alignment.center,
                                            child: IconButton(
                                              icon: const Icon(Icons.edit),
                                              color: Colors.blue,
                                              tooltip: 'Edit User',
                                              visualDensity:
                                                  VisualDensity.compact,
                                              onPressed: () async {
                                                final nameController =
                                                    TextEditingController(
                                                      text: user['name'],
                                                    );
                                                final emailController =
                                                    TextEditingController(
                                                      text: user['email'],
                                                    );
                                                final addressController =
                                                    TextEditingController(
                                                      text:
                                                          user['address'] ?? '',
                                                    );
                                                final phoneController =
                                                    TextEditingController(
                                                      text: user['phone'] ?? '',
                                                    );
                                                String status = user['status'];
                                                String role = user['role'];
                                                // Assume user['profileImage'] holds the image path, or null
                                                final String? profileImagePath =
                                                    user['profileImage'];

                                                final result = await showDialog<
                                                  Map<String, dynamic>
                                                >(
                                                  context: context,
                                                  builder: (context) {
                                                    return Dialog(
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              16.0,
                                                            ),
                                                      ),
                                                      elevation: 0,
                                                      backgroundColor:
                                                          Colors.white,
                                                      child: ConstrainedBox(
                                                        constraints:
                                                            const BoxConstraints(
                                                              maxWidth: 400,
                                                            ),
                                                        child: SingleChildScrollView(
                                                          child: Padding(
                                                            padding:
                                                                const EdgeInsets.all(
                                                                  24.0,
                                                                ),
                                                            child: Column(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .min,
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                Align(
                                                                  alignment:
                                                                      Alignment
                                                                          .center,
                                                                  child: Column(
                                                                    children: [
                                                                      CircleAvatar(
                                                                        radius:
                                                                            40,
                                                                        backgroundImage:
                                                                            (profileImagePath !=
                                                                                        null &&
                                                                                    profileImagePath.isNotEmpty)
                                                                                ? FileImage(
                                                                                      File(
                                                                                        profileImagePath,
                                                                                      ),
                                                                                    )
                                                                                    as ImageProvider<
                                                                                      Object
                                                                                    >?
                                                                                : null,
                                                                        child:
                                                                            (profileImagePath ==
                                                                                        null ||
                                                                                    profileImagePath.isEmpty)
                                                                                ? const Icon(
                                                                                  Icons.person,
                                                                                  size:
                                                                                      50,
                                                                                  color:
                                                                                      Colors.green,
                                                                                )
                                                                                : null,
                                                                      ),
                                                                      const SizedBox(
                                                                        height:
                                                                            8,
                                                                      ),
                                                                      const SizedBox(
                                                                        height:
                                                                            12,
                                                                      ),
                                                                      Text(
                                                                        user['name'],
                                                                        style: const TextStyle(
                                                                          fontSize:
                                                                              18,
                                                                          fontWeight:
                                                                              FontWeight.bold,
                                                                        ),
                                                                      ),
                                                                      Text(
                                                                        user['email'],
                                                                        style: const TextStyle(
                                                                          fontSize:
                                                                              13,
                                                                          color:
                                                                              Colors.grey,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                  height: 20,
                                                                ),

                                                                const Text(
                                                                  'Name',
                                                                ),
                                                                const SizedBox(
                                                                  height: 6,
                                                                ),
                                                                TextField(
                                                                  controller:
                                                                      nameController,
                                                                  decoration: InputDecoration(
                                                                    hintText:
                                                                        'Enter name',
                                                                    border: OutlineInputBorder(
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                            8,
                                                                          ),
                                                                    ),
                                                                    contentPadding: const EdgeInsets.symmetric(
                                                                      horizontal:
                                                                          12,
                                                                      vertical:
                                                                          10,
                                                                    ),
                                                                    isDense:
                                                                        true,
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                  height: 14,
                                                                ),

                                                                const Text(
                                                                  'Email address',
                                                                ),
                                                                const SizedBox(
                                                                  height: 6,
                                                                ),
                                                                TextField(
                                                                  controller:
                                                                      emailController,
                                                                  decoration: InputDecoration(
                                                                    hintText:
                                                                        'Enter email',
                                                                    border: OutlineInputBorder(
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                            8,
                                                                          ),
                                                                    ),
                                                                    contentPadding: const EdgeInsets.symmetric(
                                                                      horizontal:
                                                                          12,
                                                                      vertical:
                                                                          10,
                                                                    ),
                                                                    prefixIcon:
                                                                        const Icon(
                                                                          Icons
                                                                              .email_outlined,
                                                                        ),
                                                                    isDense:
                                                                        true,
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                  height: 14,
                                                                ),

                                                                const Text(
                                                                  'Address',
                                                                ),
                                                                const SizedBox(
                                                                  height: 6,
                                                                ),
                                                                TextField(
                                                                  controller:
                                                                      addressController,
                                                                  decoration: InputDecoration(
                                                                    hintText:
                                                                        'Enter address',
                                                                    border: OutlineInputBorder(
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                            8,
                                                                          ),
                                                                    ),
                                                                    contentPadding: const EdgeInsets.symmetric(
                                                                      horizontal:
                                                                          12,
                                                                      vertical:
                                                                          10,
                                                                    ),
                                                                    isDense:
                                                                        true,
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                  height: 14,
                                                                ),

                                                                const Text(
                                                                  'Phone Number',
                                                                ),
                                                                const SizedBox(
                                                                  height: 6,
                                                                ),
                                                                TextField(
                                                                  controller:
                                                                      phoneController,
                                                                  decoration: InputDecoration(
                                                                    hintText:
                                                                        'Enter phone number',
                                                                    border: OutlineInputBorder(
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                            8,
                                                                          ),
                                                                    ),
                                                                    contentPadding: const EdgeInsets.symmetric(
                                                                      horizontal:
                                                                          12,
                                                                      vertical:
                                                                          10,
                                                                    ),
                                                                    isDense:
                                                                        true,
                                                                  ),
                                                                  keyboardType:
                                                                      TextInputType
                                                                          .phone,
                                                                ),
                                                                const SizedBox(
                                                                  height: 14,
                                                                ),

                                                                const Text(
                                                                  'Status',
                                                                ),
                                                                const SizedBox(
                                                                  height: 6,
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
                                                                                s[0]
                                                                                        .toUpperCase() +
                                                                                    s.substring(
                                                                                      1,
                                                                                    ),
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
                                                                  decoration: InputDecoration(
                                                                    border: OutlineInputBorder(
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                            8,
                                                                          ),
                                                                    ),
                                                                    contentPadding: const EdgeInsets.symmetric(
                                                                      horizontal:
                                                                          12,
                                                                      vertical:
                                                                          10,
                                                                    ),
                                                                    isDense:
                                                                        true,
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                  height: 14,
                                                                ),

                                                                const Text(
                                                                  'Role',
                                                                ),
                                                                const SizedBox(
                                                                  height: 6,
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
                                                                                r[0]
                                                                                        .toUpperCase() +
                                                                                    r.substring(
                                                                                      1,
                                                                                    ),
                                                                              ),
                                                                            ),
                                                                          )
                                                                          .toList(),
                                                                  onChanged: (
                                                                    value,
                                                                  ) {
                                                                    if (value !=
                                                                        null)
                                                                      role =
                                                                          value;
                                                                  },
                                                                  decoration: InputDecoration(
                                                                    border: OutlineInputBorder(
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                            8,
                                                                          ),
                                                                    ),
                                                                    contentPadding: const EdgeInsets.symmetric(
                                                                      horizontal:
                                                                          12,
                                                                      vertical:
                                                                          10,
                                                                    ),
                                                                    isDense:
                                                                        true,
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                  height: 20,
                                                                ),

                                                                Row(
                                                                  mainAxisAlignment:
                                                                      MainAxisAlignment
                                                                          .spaceBetween,
                                                                  children: [
                                                                    Expanded(
                                                                      child: ElevatedButton.icon(
                                                                        onPressed: () {
                                                                          showDialog(
                                                                            context:
                                                                                context,
                                                                            builder:
                                                                                (
                                                                                  context,
                                                                                ) => AlertDialog(
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
                                                                                        setState(
                                                                                          () {
                                                                                            UserStore.users.remove(
                                                                                              user,
                                                                                            );
                                                                                          },
                                                                                        );
                                                                                        Navigator.pop(
                                                                                          context,
                                                                                        );
                                                                                        Navigator.pop(
                                                                                          context,
                                                                                          {
                                                                                            'deleted':
                                                                                                true,
                                                                                          },
                                                                                        );
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
                                                                        icon: const Icon(
                                                                          Icons
                                                                              .delete_outline,
                                                                          color:
                                                                              Colors.red,
                                                                        ),
                                                                        label: const Text(
                                                                          'Delete user',
                                                                          style: TextStyle(
                                                                            color:
                                                                                Colors.red,
                                                                          ),
                                                                        ),
                                                                        style: ElevatedButton.styleFrom(
                                                                          backgroundColor: Colors.red.withOpacity(
                                                                            0.1,
                                                                          ),
                                                                          elevation:
                                                                              0,
                                                                          shape: RoundedRectangleBorder(
                                                                            borderRadius: BorderRadius.circular(
                                                                              8,
                                                                            ),
                                                                          ),
                                                                          padding: const EdgeInsets.symmetric(
                                                                            horizontal:
                                                                                12,
                                                                            vertical:
                                                                                8,
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    const SizedBox(
                                                                      width: 16,
                                                                    ),
                                                                    TextButton(
                                                                      onPressed:
                                                                          () => Navigator.pop(
                                                                            context,
                                                                            null,
                                                                          ),
                                                                      child: const Text(
                                                                        'Cancel',
                                                                        style: TextStyle(
                                                                          color:
                                                                              Colors.grey,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    const SizedBox(
                                                                      width: 16,
                                                                    ),
                                                                    ElevatedButton(
                                                                      onPressed: () {
                                                                        Navigator.pop(
                                                                          context,
                                                                          {
                                                                            'name':
                                                                                nameController.text,
                                                                            'email':
                                                                                emailController.text,
                                                                            'address':
                                                                                addressController.text,
                                                                            'phone':
                                                                                phoneController.text,
                                                                            'status':
                                                                                status,
                                                                            'role':
                                                                                role,
                                                                          },
                                                                        );
                                                                      },
                                                                      style: ElevatedButton.styleFrom(
                                                                        backgroundColor:
                                                                            Colors.black,
                                                                        foregroundColor:
                                                                            Colors.white,
                                                                        shape: RoundedRectangleBorder(
                                                                          borderRadius:
                                                                              BorderRadius.circular(
                                                                                8,
                                                                              ),
                                                                        ),
                                                                        padding: const EdgeInsets.symmetric(
                                                                          horizontal:
                                                                              16,
                                                                          vertical:
                                                                              8,
                                                                        ),
                                                                      ),
                                                                      child: const Text(
                                                                        'Save changes',
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                );

                                                if (result != null &&
                                                    result.containsKey(
                                                      'deleted',
                                                    ) &&
                                                    result['deleted']) {
                                                  // User was deleted, no need to update fields
                                                } else if (result != null) {
                                                  setState(() {
                                                    user['name'] =
                                                        result['name'];
                                                    user['email'] =
                                                        result['email'];
                                                    user['address'] =
                                                        result['address'];
                                                    user['phone'] =
                                                        result['phone'];
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
