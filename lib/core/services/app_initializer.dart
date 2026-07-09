import 'package:hive_flutter/hive_flutter.dart';
import '../config/firebase_config.dart';
import '../config/hive_config.dart';
import '../config/localization_config.dart';
import '../config/environment_config.dart';
import '../../shared/connectivity_service.dart';

/// Orchestrates all app initialization in the correct order
class AppInitializer {
  static Future<void> initializeAll() async {
    try {
      print('🚀 Starting app initialization...');
      
      // Step 1: Firebase (must be first)
      print('📱 Initializing Firebase...');
      await FirebaseConfig.initialize();
      
      // Step 2: Hive local storage
      print('💾 Initializing Hive...');
      await HiveConfig.initialize();
      
      // Step 3: Localization
      print('🌍 Initializing Localization...');
      await LocalizationConfig.initialize();
      
      // Step 4: Environment & Supabase
      print('⚙️ Initializing Environment & Supabase...');
      await EnvironmentConfig.initialize();
      
      // Step 5: Connectivity service
      print('📡 Initializing Connectivity Service...');
      connectivityService.initialize();
      
      print('✅ App initialization completed successfully!');
    } catch (e) {
      print('❌ App initialization failed: $e');
      rethrow;
    }
  }

  /// Verify that all critical services are initialized
  static void verifyInitialization() {
    try {
      assert(Hive.isBoxOpen('userBox'), '❌ userBox not initialized');
      assert(Hive.isBoxOpen('settings'), '❌ settings box not initialized');
      assert(Hive.isBoxOpen('reviews'), '❌ reviews box not initialized');
      assert(Hive.isBoxOpen('notificationBox'), '❌ notificationBox not initialized');
      print('✅ All critical services verified');
    } catch (e) {
      print('❌ Verification failed: $e');
      rethrow;
    }
  }
}
