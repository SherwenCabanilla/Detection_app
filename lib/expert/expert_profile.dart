import 'package:flutter/material.dart';
// import '../routes.dart';
import '../about_app_page.dart';
import '../user/login_page.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:mime/mime.dart';
import 'package:hive/hive.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:flutter/painting.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../shared/tracking_hive_boxes.dart';

class ExpertProfile extends StatefulWidget {
  const ExpertProfile({Key? key}) : super(key: key);

  @override
  State<ExpertProfile> createState() => _ExpertProfileState();
}

class _ExpertProfileState extends State<ExpertProfile> {
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();
  bool _notificationsEnabled = false;
  bool _isUploadingImage = false;

  // User data variables
  String _userName = 'Loading...';
  String _userRole = 'Expert';
  String _userEmail = '';
  String _userPhone = '';
  String _userAddress = '';
  String? _profileImageUrl;
  String _memberSince = 'Loading...';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _saveFcmTokenToFirestore();
    _listenToProfileUpdates();
    try {
      final settingsBox = Hive.box('settings');
      if (!settingsBox.containsKey('enableNotifications')) {
        settingsBox.put('enableNotifications', true);
      }
      final enabled =
          settingsBox.get('enableNotifications', defaultValue: true) as bool;
      _notificationsEnabled = enabled;
    } catch (_) {}
  }

  Future<void> _wipeAllLocalData() async {
    String? profileUid;
    try {
      if (Hive.isBoxOpen('userBox')) {
        profileUid =
            Hive.box('userBox').get('userProfile')?['userId']?.toString();
      } else {
        final ub = await Hive.openBox('userBox');
        profileUid = ub.get('userProfile')?['userId']?.toString();
      }
    } catch (_) {}

    try {
      // Clear FCM token from current user's Firestore document before logout
      try {
        final user = FirebaseAuth.instance.currentUser;
        final uid = user?.uid ?? profileUid;
        if (uid != null && uid.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .update({'fcmToken': FieldValue.delete()});
        }
      } catch (_) {}

      // Stop Firestore listeners and clear cache
      try {
        await FirebaseFirestore.instance.terminate();
        await FirebaseFirestore.instance.clearPersistence();
      } catch (_) {}

      final boxNames = <String>{
        'userBox',
        'diseaseBox',
        'settings',
        ...TrackingHiveBoxes.legacyBoxNames,
        if (profileUid != null && profileUid.isNotEmpty) ...[
          TrackingHiveBoxes.groupsBoxName(profileUid),
          TrackingHiveBoxes.sessionCacheBoxName(profileUid),
        ],
      };
      for (final name in boxNames) {
        try {
          if (Hive.isBoxOpen(name)) {
            final box = Hive.box(name);
            await box.deleteFromDisk();
          } else {
            final box = await Hive.openBox(name);
            await box.deleteFromDisk();
          }
        } catch (_) {}
      }

      // Clear Flutter image cache
      try {
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
      } catch (_) {}

      // Clear temporary directory contents
      try {
        final tmp = Directory.systemTemp;
        // Attempt to wipe common temp area; ignore errors on restricted platforms
        for (final f in tmp.listSync()) {
          try {
            f.deleteSync(recursive: true);
          } catch (_) {}
        }
      } catch (_) {}
    } catch (_) {}
  }

  void _showBlockingProgress(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.6),
                  ),
                  const SizedBox(width: 16),
                  Flexible(
                    child: Text(
                      message,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  // Helper method to convert Firestore data to Hive-compatible format
  Map<String, dynamic> _convertFirestoreDataForHive(Map<String, dynamic> data) {
    final convertedData = <String, dynamic>{};
    data.forEach((key, value) {
      if (value is Timestamp) {
        // Convert Firestore Timestamp to ISO 8601 string
        convertedData[key] = value.toDate().toIso8601String();
      } else {
        convertedData[key] = value;
      }
    });
    return convertedData;
  }

  void _listenToProfileUpdates() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .listen((snapshot) async {
            if (snapshot.exists && snapshot.data() != null) {
              final data = snapshot.data() as Map<String, dynamic>;

              // Save to Hive cache - convert Timestamps first
              try {
                final userBox = await Hive.openBox('userBox');
                final hiveCompatibleData = _convertFirestoreDataForHive(data);
                await userBox.put('userProfile', hiveCompatibleData);
                print('✅ Expert profile updated in Hive cache: ${data['fullName']}');
              } catch (e) {
                print('❌ Error updating Hive cache: $e');
              }

              // Update UI - always update when Firestore data changes
              if (mounted) {
                setState(() {
                  _userName = data['fullName'] ?? 'Unknown Expert';
                  _userRole = data['role'] ?? 'Expert';
                  _userEmail = data['email'] ?? '';
                  _userPhone = data['phoneNumber'] ?? '';
                  _userAddress = data['address'] ?? '';
                  // Only set profile image URL if it's not null and not empty
                  final imageProfile = data['imageProfile'];
                  _profileImageUrl =
                      (imageProfile != null &&
                              imageProfile.toString().isNotEmpty)
                          ? imageProfile.toString()
                          : null;
                  _isLoading = false;
                });
                print('✅ Expert profile UI updated: ${data['fullName']}');
              }
            }
          });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh member since when page is focused
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _loadMemberSince(user);
    }
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Always fetch fresh data from Firestore first
        try {
          final userDoc =
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .get();

          if (userDoc.exists && userDoc.data() != null) {
            final data = userDoc.data() as Map<String, dynamic>;

            // Update Hive cache with fresh data (convert Timestamps first)
            try {
              final userBox = await Hive.openBox('userBox');
              final hiveCompatibleData = _convertFirestoreDataForHive(data);
              await userBox.put('userProfile', hiveCompatibleData);
            } catch (e) {
              print('⚠️ Error saving to Hive cache: $e');
            }

            // Update UI with fresh data
            if (mounted) {
              setState(() {
                _userName = data['fullName'] ?? 'Unknown Expert';
                _userRole = data['role'] ?? 'Expert';
                _userEmail = data['email'] ?? '';
                _userPhone = data['phoneNumber'] ?? '';
                _userAddress = data['address'] ?? '';
                // Only set profile image URL if it's not null and not empty
                final imageProfile = data['imageProfile'];
                _profileImageUrl =
                    (imageProfile != null && imageProfile.toString().isNotEmpty)
                        ? imageProfile.toString()
                        : null;
                _isLoading = false;
              });
            }

            // Load member since
            _loadMemberSince(user);
            print('✅ Expert profile loaded from Firestore: ${data['fullName']}');
            return;
          }
        } catch (e) {
          print('⚠️ Error fetching from Firestore, trying cache: $e');
        }

        // Fallback to cached data if Firestore fails
        final userBox = await Hive.openBox('userBox');
        final localProfile = userBox.get('userProfile');
        if (localProfile != null && mounted) {
          setState(() {
            _userName = localProfile['fullName'] ?? 'Unknown Expert';
            _userRole = localProfile['role'] ?? 'Expert';
            _userEmail = localProfile['email'] ?? '';
            _userPhone = localProfile['phoneNumber'] ?? '';
            _userAddress = localProfile['address'] ?? '';
            // Only set profile image URL if it's not null and not empty
            final imageProfile = localProfile['imageProfile'];
            _profileImageUrl =
                (imageProfile != null && imageProfile.toString().isNotEmpty)
                    ? imageProfile.toString()
                    : null;
            _isLoading = false;
          });

          // Load member since even when using local data
          _loadMemberSince(user);
          print('✅ Expert profile loaded from cache: ${localProfile['fullName']}');
        }
      }
    } catch (e) {
      print('❌ Error loading user data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _loadMemberSince(User user) async {
    try {
      // Fetch user data from Firestore
      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;

        // Debug: Print all data to see what we have
        print('DEBUG: User data keys: ${data.keys.toList()}');
        print('DEBUG: acceptedAt: ${data['acceptedAt']}');
        print('DEBUG: createdAt: ${data['createdAt']}');

        // Priority: acceptedAt > createdAt
        dynamic dateValue;
        if (data['acceptedAt'] != null) {
          dateValue = data['acceptedAt'];
          print('DEBUG: Using acceptedAt: $dateValue');
        } else if (data['createdAt'] != null) {
          dateValue = data['createdAt'];
          print('DEBUG: Using createdAt: $dateValue');
        } else {
          print('DEBUG: No date fields found');
        }

        if (dateValue != null) {
          // Parse the date - handle Firestore Timestamps
          DateTime? memberDate;
          try {
            // Handle different date formats
            if (dateValue is DateTime) {
              memberDate = dateValue;
            } else if (dateValue is Timestamp) {
              // Handle Firestore Timestamp
              memberDate = dateValue.toDate();
              print('DEBUG: Converted Timestamp to DateTime: $memberDate');
            } else if (dateValue is String) {
              // Try parsing the full date string
              memberDate = DateTime.parse(
                dateValue.replaceAll(' at ', ' ').split(' UTC')[0],
              );
            }
          } catch (e) {
            print('Error parsing date: $e');
            // Fallback to current time if parsing fails
            memberDate = DateTime.now();
          }

          if (memberDate != null) {
            // Format as "Month Year" (e.g., "January 2024")
            final monthNames = [
              tr('january'),
              tr('february'),
              tr('march'),
              tr('april'),
              tr('may'),
              tr('june'),
              tr('july'),
              tr('august'),
              tr('september'),
              tr('october'),
              tr('november'),
              tr('december'),
            ];
            final month = monthNames[memberDate.month - 1];
            final year = memberDate.year;

            setState(() {
              _memberSince = '$month $year';
            });
          } else {
            setState(() {
              _memberSince = 'N/A';
            });
          }
        } else {
          setState(() {
            _memberSince = 'N/A';
          });
        }
      } else {
        setState(() {
          _memberSince = 'N/A';
        });
      }
    } catch (e) {
      print('Error loading member since: $e');
      setState(() {
        _memberSince = 'N/A';
      });
    }
  }

  Future<void> _pickProfileImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (pickedFile != null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Text(tr('change_profile_photo')),
              content: Text(tr('confirm_change_profile_photo')),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(tr('cancel')),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(tr('update')),
                ),
              ],
            ),
      );
      if (confirmed == true) {
        if (!mounted) return;
        setState(() {
          _profileImage = File(pickedFile.path);
        });

        // Upload to Firebase Storage
        await _uploadProfileImage(pickedFile.path);
      }
    }
  }

  Future<void> _uploadProfileImage(String imagePath) async {
    setState(() {
      _isUploadingImage = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final file = File(imagePath);
        final ref = FirebaseStorage.instance
            .ref()
            .child('profile')
            .child('${user.uid}.jpg');

        final detectedMime = lookupMimeType(file.path) ?? 'image/jpeg';

        // Upload with 20 second timeout
        await ref
            .putFile(file, SettableMetadata(contentType: detectedMime))
            .timeout(
              const Duration(seconds: 20),
              onTimeout: () {
                throw Exception(
                  'Upload timeout - Please check your internet connection',
                );
              },
            );

        final url = await ref.getDownloadURL().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw Exception('Timeout getting image URL - Please try again');
          },
        );

        // Update Firestore with new image URL
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'imageProfile': url})
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                throw Exception(
                  'Timeout updating profile - Please check your connection',
                );
              },
            );

        // Update Hive cache immediately
        final userBox = await Hive.openBox('userBox');
        final cachedProfile =
            userBox.get('userProfile') as Map<dynamic, dynamic>?;
        if (cachedProfile != null) {
          final updatedProfile = Map<String, dynamic>.from(cachedProfile);
          updatedProfile['imageProfile'] = url;
          await userBox.put('userProfile', updatedProfile);
        }

        if (!mounted) return;
        setState(() {
          _profileImageUrl = url;
          _isUploadingImage = false;
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile image updated successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error uploading profile image: $e');
      if (!mounted) return;
      setState(() {
        _isUploadingImage = false;
      });

      // Determine error message based on error type
      String errorMessage = 'Failed to update profile image';
      if (e.toString().contains('timeout') ||
          e.toString().contains('Timeout')) {
        errorMessage =
            'Upload timeout - Please check your internet connection and try again';
      } else if (e.toString().contains('network') ||
          e.toString().contains('connection')) {
        errorMessage = 'Network error - Please check your internet connection';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  child: Text(
                    tr('profile_photo_options'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.camera_alt,
                      color: Colors.green[700],
                      size: 20,
                    ),
                  ),
                  title: Text(tr('change_photo')),
                  subtitle: Text(tr('upload_new_profile_photo')),
                  onTap: () {
                    Navigator.pop(context);
                    _pickProfileImage();
                  },
                ),
                if (_profileImageUrl != null || _profileImage != null) ...[
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.delete_outline,
                        color: Colors.red[700],
                        size: 20,
                      ),
                    ),
                    title: Text(tr('delete_photo')),
                    subtitle: Text(tr('remove_current_profile_photo')),
                    onTap: () {
                      Navigator.pop(context);
                      _deleteProfileImage();
                    },
                  ),
                ],
                const SizedBox(height: 20),
              ],
            ),
          ),
    );
  }

  Future<void> _deleteProfileImage() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(tr('delete_profile_photo')),
            content: Text(tr('confirm_delete_profile_photo')),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(tr('cancel')),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: Text(tr('delete')),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      setState(() {
        _isUploadingImage = true;
      });

      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          // Delete from Firebase Storage if image exists
          if (_profileImageUrl != null) {
            try {
              final ref = FirebaseStorage.instance
                  .ref()
                  .child('profile')
                  .child('${user.uid}.jpg');
              await ref.delete();
            } catch (e) {
              print('Error deleting from storage: $e');
              // Continue even if storage deletion fails
            }
          }

          // Update Firestore to remove image URL
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({'imageProfile': FieldValue.delete()})
              .timeout(
                const Duration(seconds: 10),
                onTimeout: () {
                  throw Exception(
                    'Timeout updating profile - Please check your connection',
                  );
                },
              );

          // Update Hive cache immediately
          final userBox = await Hive.openBox('userBox');
          final cachedProfile =
              userBox.get('userProfile') as Map<dynamic, dynamic>?;
          if (cachedProfile != null) {
            final updatedProfile = Map<String, dynamic>.from(cachedProfile);
            updatedProfile.remove('imageProfile');
            await userBox.put('userProfile', updatedProfile);
          }

          if (!mounted) return;
          setState(() {
            _profileImageUrl = null;
            _profileImage = null;
            _isUploadingImage = false;
          });

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile image deleted successfully!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        print('Error deleting profile image: $e');
        if (!mounted) return;
        setState(() {
          _isUploadingImage = false;
        });

        String errorMessage = 'Failed to delete profile image';
        if (e.toString().contains('timeout') ||
            e.toString().contains('Timeout')) {
          errorMessage =
              'Delete timeout - Please check your internet connection and try again';
        } else if (e.toString().contains('network') ||
            e.toString().contains('connection')) {
          errorMessage =
              'Network error - Please check your internet connection';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _saveFcmTokenToFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'fcmToken': token});
      }
    }
  }

  Widget _buildProfileOption({
    required String title,
    required IconData icon,
    VoidCallback? onTap,
    bool showDivider = true,
  }) {
    return Column(
      children: [
        ListTile(
          leading: Icon(icon, color: Colors.green),
          title: Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: onTap,
        ),
        if (showDivider) const Divider(height: 1),
      ],
    );
  }

  void _showEditProfileDialog(BuildContext context) {
    final TextEditingController nameController = TextEditingController(
      text: _userName,
    );
    final TextEditingController emailController = TextEditingController(
      text: _userEmail,
    );
    final TextEditingController phoneController = TextEditingController(
      text: _userPhone,
    );
    final TextEditingController addressController = TextEditingController(
      text: _userAddress,
    );
    
    // Validation state
    final ValueNotifier<bool> hasValidated = ValueNotifier<bool>(false);
    final ValueNotifier<Map<String, String?>> fieldErrors = ValueNotifier<Map<String, String?>>({});
    
    // Validation functions
    String? validateFullName(String? value) {
      if (value == null || value.trim().isEmpty) {
        return 'Please enter your full name';
      }
      if (value.trim().length < 2) {
        return 'Name must be at least 2 characters';
      }
      return null;
    }
    
    String? validateAddress(String? value) {
      if (value == null || value.trim().isEmpty) {
        return 'Please enter your address';
      }
      if (value.trim().length < 5) {
        return 'Please enter a complete address';
      }
      return null;
    }
    
    String? validatePhone(String? value) {
      if (value == null || value.trim().isEmpty) {
        return 'Please enter your phone number';
      }
      // Philippine phone number validation: 09XXXXXXXXX (11 digits starting with 09)
      final phoneRegex = RegExp(r'^09\d{9}$');
      String cleanNumber = value.replaceAll(RegExp(r'[\s\-\(\)]'), '');
      if (!phoneRegex.hasMatch(cleanNumber)) {
        return 'Please enter a valid mobile number (09XXXXXXXXX)';
      }
      return null;
    }
    
    String? validateEmail(String? value) {
      if (value == null || value.trim().isEmpty) {
        return 'Please enter your email';
      }
      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
      if (!emailRegex.hasMatch(value)) {
        return 'Please enter a valid email address';
      }
      return null;
    }
    
    // Helper function to build validated text fields
    Widget buildValidatedTextField({
      required String label,
      required TextEditingController controller,
      required String fieldKey,
      required String? Function(String?) validator,
      IconData? prefixIcon,
      TextInputType? keyboardType,
      List<TextInputFormatter>? inputFormatters,
      bool enabled = true,
    }) {
      return ValueListenableBuilder<Map<String, String?>>(
        valueListenable: fieldErrors,
        builder: (context, errors, _) {
          final errorText = hasValidated.value ? errors[fieldKey] : null;
          final hasError = errorText != null && errorText.isNotEmpty;
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                enabled: enabled,
                keyboardType: keyboardType,
                inputFormatters: inputFormatters,
                onChanged: (value) {
                  if (hasValidated.value) {
                    fieldErrors.value = {
                      ...fieldErrors.value,
                      fieldKey: validator(value),
                    };
                  }
                },
                decoration: InputDecoration(
                  labelText: label,
                  prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
                  filled: true,
                  fillColor: hasError ? Colors.redAccent.withOpacity(0.1) : Colors.transparent,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: hasError ? Colors.redAccent : Colors.grey,
                      width: hasError ? 1.5 : 1,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: hasError ? Colors.redAccent : Colors.grey,
                      width: hasError ? 1.5 : 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: hasError ? Colors.redAccent : Colors.green,
                      width: hasError ? 1.5 : 2,
                    ),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Colors.redAccent,
                      width: 1.5,
                    ),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Colors.redAccent,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              if (hasError)
                Padding(
                  padding: const EdgeInsets.only(left: 12, top: 6, right: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            errorText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      );
    }

    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Edit Profile',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    buildValidatedTextField(
                      label: 'Full Name',
                      controller: nameController,
                      fieldKey: 'fullName',
                      validator: validateFullName,
                      prefixIcon: Icons.person,
                      keyboardType: TextInputType.name,
                    ),
                    const SizedBox(height: 12),
                    buildValidatedTextField(
                      label: 'Email',
                      controller: emailController,
                      fieldKey: 'email',
                      validator: validateEmail,
                      prefixIcon: Icons.email,
                      keyboardType: TextInputType.emailAddress,
                      enabled: false,
                    ),
                    const SizedBox(height: 12),
                    buildValidatedTextField(
                      label: 'Phone Number',
                      controller: phoneController,
                      fieldKey: 'phone',
                      validator: validatePhone,
                      prefixIcon: Icons.phone,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(15),
                      ],
                    ),
                    const SizedBox(height: 12),
                    buildValidatedTextField(
                      label: 'Address',
                      controller: addressController,
                      fieldKey: 'address',
                      validator: validateAddress,
                      prefixIcon: Icons.location_on,
                      keyboardType: TextInputType.streetAddress,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          // Validate all fields
                          hasValidated.value = true;
                          fieldErrors.value = {
                            'fullName': validateFullName(nameController.text),
                            'email': validateEmail(emailController.text),
                            'phone': validatePhone(phoneController.text),
                            'address': validateAddress(addressController.text),
                          };
                          
                          // Check if there are any errors
                          if (fieldErrors.value.values.any((error) => error != null && error.isNotEmpty)) {
                            return;
                          }
                          
                          try {
                            final user = FirebaseAuth.instance.currentUser;
                            if (user != null) {
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(user.uid)
                                  .update({
                                    'fullName': nameController.text.trim(),
                                    'phoneNumber': phoneController.text.trim(),
                                    'address': addressController.text.trim(),
                                  });

                              // Update local state
                              setState(() {
                                _userName = nameController.text.trim();
                                _userPhone = phoneController.text.trim();
                                _userAddress = addressController.text.trim();
                              });

                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Profile updated successfully'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            print('Error updating profile: $e');
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Failed to update profile'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Save Changes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final TextEditingController currentPasswordController =
        TextEditingController();
    final TextEditingController newPasswordController = TextEditingController();
    final TextEditingController confirmPasswordController =
        TextEditingController();
    final ValueNotifier<String?> errorNotifier = ValueNotifier<String?>(null);
    // Visibility toggles for password fields
    final ValueNotifier<bool> hideCurrent = ValueNotifier<bool>(true);
    final ValueNotifier<bool> hideNew = ValueNotifier<bool>(true);
    final ValueNotifier<bool> hideConfirm = ValueNotifier<bool>(true);
    
    // Password strength tracking
    final ValueNotifier<String> passwordStrength = ValueNotifier<String>('');
    final ValueNotifier<Color> passwordStrengthColor = ValueNotifier<Color>(Colors.grey);
    
    void calculatePasswordStrength(String password) {
      bool hasLength = password.length >= 8;
      bool hasUppercase = password.contains(RegExp(r'[A-Z]'));
      bool hasLowercase = password.contains(RegExp(r'[a-z]'));
      bool hasNumber = password.contains(RegExp(r'[0-9]'));
      bool hasSpecialChar = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

      bool meetsRequirements = hasLength && hasUppercase && hasLowercase && hasNumber;

      if (!hasLength || (!hasUppercase && !hasLowercase && !hasNumber)) {
        passwordStrength.value = 'Weak';
        passwordStrengthColor.value = Colors.red;
      } else if (!meetsRequirements) {
        passwordStrength.value = 'Medium';
        passwordStrengthColor.value = Colors.orange;
      } else {
        passwordStrength.value = hasSpecialChar ? 'Strong' : 'Good';
        passwordStrengthColor.value = hasSpecialChar ? Colors.green : Colors.lightGreen;
      }
    }

    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Change Password',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ValueListenableBuilder<bool>(
                    valueListenable: hideCurrent,
                    builder:
                        (context, hidden, _) => TextField(
                          controller: currentPasswordController,
                          obscureText: hidden,
                          decoration: InputDecoration(
                            labelText: 'Current Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(
                                hidden
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () => hideCurrent.value = !hidden,
                            ),
                          ),
                        ),
                  ),
                  const SizedBox(height: 12),
                  ValueListenableBuilder<bool>(
                    valueListenable: hideNew,
                    builder:
                        (context, hidden, _) => TextField(
                          controller: newPasswordController,
                          obscureText: hidden,
                          onChanged: (value) => calculatePasswordStrength(value),
                          decoration: InputDecoration(
                            labelText: 'New Password',
                            prefixIcon: const Icon(Icons.lock),
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(
                                hidden
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () => hideNew.value = !hidden,
                            ),
                          ),
                        ),
                  ),
                  // Password Strength Indicator
                  ValueListenableBuilder<String>(
                    valueListenable: passwordStrength,
                    builder: (context, strength, _) {
                      if (newPasswordController.text.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 8, left: 12),
                        child: Row(
                          children: [
                            Text(
                              'Password Strength: ',
                              style: TextStyle(color: Colors.grey[700], fontSize: 12),
                            ),
                            ValueListenableBuilder<Color>(
                              valueListenable: passwordStrengthColor,
                              builder: (context, color, _) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: color, width: 1),
                                ),
                                child: Text(
                                  strength,
                                  style: TextStyle(
                                    color: color,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  ValueListenableBuilder<bool>(
                    valueListenable: hideConfirm,
                    builder:
                        (context, hidden, _) => TextField(
                          controller: confirmPasswordController,
                          obscureText: hidden,
                          decoration: InputDecoration(
                            labelText: 'Confirm New Password',
                            prefixIcon: const Icon(Icons.lock),
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(
                                hidden
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () => hideConfirm.value = !hidden,
                            ),
                          ),
                        ),
                  ),
                  const SizedBox(height: 16),
                  ValueListenableBuilder<String?>(
                    valueListenable: errorNotifier,
                    builder:
                        (context, error, child) =>
                            error == null
                                ? const SizedBox.shrink()
                                : Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Text(
                                    error,
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final current = currentPasswordController.text;
                        final newPass = newPasswordController.text;
                        final confirm = confirmPasswordController.text;

                        if (current.isEmpty ||
                            newPass.isEmpty ||
                            confirm.isEmpty) {
                          errorNotifier.value = 'All fields are required.';
                          return;
                        }

                        if (newPass != confirm) {
                          errorNotifier.value = 'New passwords do not match.';
                          return;
                        }

                        // Enhanced password validation
                        if (newPass.length < 8) {
                          errorNotifier.value = 'Password must be at least 8 characters';
                          return;
                        }
                        
                        if (!newPass.contains(RegExp(r'[A-Z]'))) {
                          errorNotifier.value = 'Password must contain at least one uppercase letter';
                          return;
                        }
                        
                        if (!newPass.contains(RegExp(r'[a-z]'))) {
                          errorNotifier.value = 'Password must contain at least one lowercase letter';
                          return;
                        }
                        
                        if (!newPass.contains(RegExp(r'[0-9]'))) {
                          errorNotifier.value = 'Password must contain at least one number';
                          return;
                        }

                        try {
                          final user = FirebaseAuth.instance.currentUser;
                          if (user != null && user.email != null) {
                            // Re-authenticate user with current password
                            final credential = EmailAuthProvider.credential(
                              email: user.email!,
                              password: current,
                            );
                            await user.reauthenticateWithCredential(credential);

                            // Update password
                            await user.updatePassword(newPass);

                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Password changed successfully!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } on FirebaseAuthException catch (e) {
                          String errorMessage =
                              'An error occurred while changing password.';
                          if (e.code == 'wrong-password') {
                            errorMessage = 'Current password is incorrect.';
                          } else if (e.code == 'weak-password') {
                            errorMessage = 'New password is too weak.';
                          } else if (e.code == 'requires-recent-login') {
                            errorMessage =
                                'Please log out and log in again before changing password.';
                          }
                          errorNotifier.value = errorMessage;
                        } catch (e) {
                          errorNotifier.value = 'An unexpected error occurred.';
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Change Password',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
                ),
              ),
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      body:
          user == null
              ? const Center(child: Text('Not logged in'))
              : _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: _loadUserData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    children: [
                    // Profile Card
                    Container(
                      color: Colors.green[50],
                      padding: const EdgeInsets.symmetric(vertical: 24.0),
                      child: Column(
                        children: [
                          // Profile Picture
                          Stack(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  if (_profileImageUrl != null ||
                                      _profileImage != null) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (context) =>
                                                _FullScreenProfileImage(
                                                  imageUrl: _profileImageUrl,
                                                  imageFile: _profileImage,
                                                  userName: _userName,
                                                ),
                                      ),
                                    );
                                  }
                                },
                                child: Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 4,
                                    ),
                                    color: Colors.white,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Stack(
                                    children: [
                                      _profileImage != null
                                          ? ClipOval(
                                            child: Image.file(
                                              _profileImage!,
                                              width: 120,
                                              height: 120,
                                              fit: BoxFit.cover,
                                            ),
                                          )
                                          : _profileImageUrl != null
                                          ? ClipOval(
                                            child: CachedNetworkImage(
                                              imageUrl: _profileImageUrl!,
                                              width: 120,
                                              height: 120,
                                              fit: BoxFit.cover,
                                              placeholder:
                                                  (context, url) =>
                                                      const CircularProgressIndicator(),
                                              errorWidget:
                                                  (context, url, error) =>
                                                      const Icon(
                                                        Icons.person,
                                                        size: 70,
                                                        color: Colors.green,
                                                      ),
                                            ),
                                          )
                                          : Container(
                                            width: 120,
                                            height: 120,
                                            decoration: BoxDecoration(
                                              color: Colors.grey[200],
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Center(
                                              child: Icon(
                                                Icons.person,
                                                size: 70,
                                                color: Colors.green,
                                              ),
                                            ),
                                          ),
                                      // Upload indicator overlay
                                      if (_isUploadingImage)
                                        Container(
                                          width: 120,
                                          height: 120,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.black.withOpacity(
                                              0.6,
                                            ),
                                          ),
                                          child: const Center(
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                CircularProgressIndicator(
                                                  color: Colors.white,
                                                  strokeWidth: 3,
                                                ),
                                                SizedBox(height: 8),
                                                Text(
                                                  'Uploading...',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: _showImageOptions,
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: Colors.green[700],
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 3,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.2),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.more_vert,
                                        size: 18,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Expert Name
                          Text(
                            _isLoading ? 'Loading...' : _userName,
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          // Expert Role Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _userRole.toLowerCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Member Since Card
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.calendar_today,
                                        color: Colors.green,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          _memberSince,
                                          style: TextStyle(
                                            color: Colors.green[700],
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    tr('member_since'),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.grey[700],
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Profile Options
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _buildProfileOption(
                            title: 'Edit Profile',
                            icon: Icons.edit,
                            onTap: () => _showEditProfileDialog(context),
                          ),
                          _buildProfileOption(
                            title: 'About App',
                            icon: Icons.info,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const AboutAppPage(),
                                ),
                              );
                            },
                          ),
                          _buildProfileOption(
                            title: 'Change Password',
                            icon: Icons.lock,
                            onTap: () => _showChangePasswordDialog(context),
                          ),
                          _buildProfileOption(
                            title: 'Log Out',
                            icon: Icons.logout,
                            showDivider: false,
                            onTap: () async {
                              final shouldLogout = await showDialog<bool>(
                                context: context,
                                builder:
                                    (context) => AlertDialog(
                                      title: const Text('Confirm Logout'),
                                      content: const Text(
                                        'Are you sure you want to logout?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed:
                                              () => Navigator.of(
                                                context,
                                              ).pop(false),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed:
                                              () => Navigator.of(
                                                context,
                                              ).pop(true),
                                          child: const Text('Logout'),
                                        ),
                                      ],
                                    ),
                              );
                              if (shouldLogout == true) {
                                _showBlockingProgress(
                                  context,
                                  'Logging out...',
                                );
                                // Sign out from Firebase
                                await FirebaseAuth.instance.signOut();
                                // Also sign out and disconnect Google so chooser shows
                                try {
                                  final google = GoogleSignIn();
                                  await google.signOut();
                                  await google.disconnect();
                                } catch (_) {}
                                // Wipe local data but keep app running
                                await _wipeAllLocalData();
                                if (!mounted) return;
                                Navigator.of(
                                  context,
                                  rootNavigator: true,
                                ).pop(); // dismiss loader
                                Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const LoginPage(),
                                  ),
                                  (route) => false,
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Preferences Section
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 8, bottom: 4),
                            child: Text(
                              'Preferences',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ),
                          SwitchListTile(
                            value: _notificationsEnabled,
                            onChanged: (value) async {
                              setState(() {
                                _notificationsEnabled = value;
                              });
                              // Persist locally
                              try {
                                final settingsBox = await Hive.openBox(
                                  'settings',
                                );
                                await settingsBox.put(
                                  'enableNotifications',
                                  value,
                                );
                              } catch (_) {}
                              // Mirror to Firestore for backend gating
                              final user = FirebaseAuth.instance.currentUser;
                              if (user != null) {
                                try {
                                  await FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(user.uid)
                                      .update({'enableNotifications': value});
                                } catch (_) {}
                              }
                              // Apply topic change immediately (experts -> all_users + experts)
                              try {
                                if (value) {
                                  await FirebaseMessaging.instance
                                      .subscribeToTopic('all_users');
                                  await FirebaseMessaging.instance
                                      .subscribeToTopic('experts');
                                } else {
                                  await FirebaseMessaging.instance
                                      .unsubscribeFromTopic('all_users');
                                  await FirebaseMessaging.instance
                                      .unsubscribeFromTopic('experts');
                                }
                              } catch (_) {}
                            },
                            title: const Text('Enable Notifications'),
                            secondary: const Icon(
                              Icons.notifications,
                              color: Colors.green,
                            ),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Description
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.green.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Expert Access',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'This profile is exclusively for plant disease experts. Regular users and other personnel do not have access to this interface.',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // App Version
                    const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
    );
  }
}

// Full-screen profile image viewer
class _FullScreenProfileImage extends StatelessWidget {
  final String? imageUrl;
  final File? imageFile;
  final String userName;

  const _FullScreenProfileImage({
    Key? key,
    this.imageUrl,
    this.imageFile,
    required this.userName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(userName, style: const TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child:
              imageFile != null
                  ? Image.file(imageFile!, fit: BoxFit.contain)
                  : imageUrl != null
                  ? CachedNetworkImage(
                    imageUrl: imageUrl!,
                    fit: BoxFit.contain,
                    placeholder:
                        (context, url) => const CircularProgressIndicator(
                          color: Colors.white,
                        ),
                    errorWidget:
                        (context, url, error) => const Icon(
                          Icons.person,
                          size: 200,
                          color: Colors.white,
                        ),
                  )
                  : const Icon(Icons.person, size: 200, color: Colors.white),
        ),
      ),
    );
  }
}
