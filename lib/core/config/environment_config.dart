import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Handles environment variables and external service configuration
class EnvironmentConfig {
  static Future<void> initialize() async {
    try {
      // Load environment variables
      await dotenv.load();
      
      // Initialize Supabase
      await Supabase.initialize(
        url: dotenv.env['SUPABASE_URL'] ?? '',
        anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
      );
      
      print('✅ Environment and Supabase configured successfully');
    } catch (e) {
      print('❌ Environment configuration failed: $e');
      rethrow;
    }
  }
}
