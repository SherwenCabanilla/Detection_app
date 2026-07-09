import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

/// Keeps Hive login state in sync with Firebase Auth
class AuthSyncService {
  static void setupAuthStateListener() {
    try {
      bool isFirstAuthCheck = true;
      
      FirebaseAuth.instance.authStateChanges().listen((user) async {
        // Skip the very first null event during app startup
        if (isFirstAuthCheck && user == null) {
          isFirstAuthCheck = false;
          return;
        }
        isFirstAuthCheck = false;

        final box = Hive.box('userBox');
        
        if (user == null) {
          // User signed out
          await box.put('isLoggedIn', false);
          await box.delete('userProfile');
          print('📱 User signed out');
          return;
        }

        // Check user status before saving login state
        try {
          final doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

          if (doc.exists) {
            final data = doc.data() as Map<String, dynamic>;
            final status = data['status'];

            // Only save login state if user is active
            if (status == 'active') {
              await box.put('isLoggedIn', true);
              
              // Ensure minimal profile is saved locally for routing
              Map? profile = box.get('userProfile') as Map?;
              if (profile == null || profile['userId'] != user.uid) {
                final updated = {
                  'userId': user.uid,
                  'fullName': data['fullName'] ?? profile?['fullName'] ?? '',
                  'email': data['email'] ?? profile?['email'] ?? user.email ?? '',
                  'role': data['role'] ?? profile?['role'],
                };
                await box.put('userProfile', updated);
              }
              print('📱 User logged in: ${user.uid}');
            } else {
              // User is not active
              await box.put('isLoggedIn', false);
              await box.delete('userProfile');
              print('⚠️ User status is inactive');
            }
          } else {
            // User document doesn't exist
            await box.put('isLoggedIn', false);
            await box.delete('userProfile');
            print('⚠️ User document not found');
          }
        } catch (e) {
          // On error, don't save login state
          await box.put('isLoggedIn', false);
          await box.delete('userProfile');
          print('❌ Error checking user status: $e');
        }
      });
    } catch (e) {
      print('❌ Auth state listener setup failed: $e');
    }
  }
}
