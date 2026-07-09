import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Handles Firebase initialization and configuration
class FirebaseConfig {
  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp();
      
      // Enable Firestore offline persistence
      try {
        await FirebaseFirestore.instance.enablePersistence();
      } catch (e) {
        print('⚠️ Firestore persistence already enabled or error: $e');
      }
      
      // Set Firebase Auth persistence to LOCAL (default)
      try {
        await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
      } catch (e) {
        print('⚠️ Firebase Auth persistence already set: $e');
      }
      
      print('✅ Firebase initialized successfully');
    } catch (e) {
      print('❌ Firebase initialization failed: $e');
      rethrow;
    }
  }
}
