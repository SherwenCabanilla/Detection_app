import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Handles app localization setup
class LocalizationConfig {
  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('bs'),
    Locale('tl'),
  ];

  static Future<void> initialize() async {
    try {
      await EasyLocalization.ensureInitialized();
      print('✅ Localization initialized successfully');
    } catch (e) {
      print('❌ Localization initialization failed: $e');
      rethrow;
    }
  }

  /// Load saved locale from Hive
  static Locale? getSavedLocale() {
    try {
      final settingsBox = Hive.box('settings');
      final String? localeCode = settingsBox.get('locale_code');
      
      if (localeCode != null && ['en', 'bs', 'tl'].contains(localeCode)) {
        return Locale(localeCode);
      }
    } catch (e) {
      print('⚠️ Error getting saved locale: $e');
    }
    return null;
  }
}
