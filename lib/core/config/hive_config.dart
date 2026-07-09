import 'package:hive_flutter/hive_flutter.dart';

/// Handles Hive local storage initialization
class HiveConfig {
  static const List<String> boxNames = [
    'reviews',
    'userBox',
    'settings',
    'notificationBox',
  ];

  static Future<void> initialize() async {
    try {
      await Hive.initFlutter();
      
      // Open all required boxes
      for (final boxName in boxNames) {
        try {
          await Hive.openBox(boxName);
          print('✅ Hive box opened: $boxName');
        } catch (e) {
          print('⚠️ Hive box already open or error for $boxName: $e');
        }
      }
      
      print('✅ Hive initialized successfully');
    } catch (e) {
      print('❌ Hive initialization failed: $e');
      rethrow;
    }
  }

  /// Get a specific Hive box
  static Box<T> getBox<T>(String name) {
    return Hive.box<T>(name);
  }
}
