import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:month_year_picker/month_year_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

// Core services
import 'core/services/app_initializer.dart';
import 'core/services/auth_sync_service.dart';
import 'core/services/notification_service.dart';
import 'core/config/localization_config.dart';

// UI
import 'user/login_page.dart';
import 'user/home_page.dart';
import 'user/register_page.dart';
import 'expert/expert_dashboard.dart';
import 'shared/no_internet_banner.dart';

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Initialize all app services in correct order
      await AppInitializer.initializeAll();
      
      // Verify critical services
      AppInitializer.verifyInitialization();

      // Setup auth state listener (syncs Firebase ↔ Hive)
      AuthSyncService.setupAuthStateListener();

      // Initialize notifications (local + FCM)
      await NotificationService.initializeLocalNotifications();

      // Style system UI
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Color.fromARGB(102, 255, 255, 255),
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.dark,
        ),
      );

      // Load saved locale from Hive
      final startLocale = LocalizationConfig.getSavedLocale();

      runApp(
        EasyLocalization(
          supportedLocales: LocalizationConfig.supportedLocales,
          path: 'assets/lang',
          fallbackLocale: const Locale('en'),
          startLocale: startLocale,
          child: const CapstoneApp(),
        ),
      );
    },
    (error, stack) {
      // Optionally forward to crash reporter
      print('🔥 Unhandled error: $error\n$stack');
    },
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) {
        if (!kReleaseMode) parent.print(zone, line);
      },
    ),
  );
}

class CapstoneApp extends StatelessWidget {
  const CapstoneApp({Key? key}) : super(key: key);

  Future<Widget> _getStartPage() async {
    final box = Hive.box('userBox');
    final isLoggedIn = box.get('isLoggedIn', defaultValue: false) as bool;

    if (!isLoggedIn) {
      print('📱 No login state, showing login page');
      return const LoginPage();
    }

    final userProfile = box.get('userProfile');
    final role = userProfile != null ? userProfile['role'] : null;
    final userId = userProfile != null ? userProfile['userId'] : null;

    print('📱 User logged in as: $role');

    // Check user approval status from Firestore
    if (userId != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();

        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          final status = data['status'];

          if (status != 'active') {
            print('📱 User status is $status, clearing login state');
            await box.put('isLoggedIn', false);
            await box.delete('userProfile');
            return const LoginPage();
          }
        }
      } catch (e) {
        print('📱 Error checking user status: $e');
        await box.put('isLoggedIn', false);
        await box.delete('userProfile');
        return const LoginPage();
      }
    }

    if (role == 'expert') {
      return const ExpertDashboard();
    } else {
      return const HomePage();
    }
  }

  void _setupFCM(BuildContext context) async {
    // FCM setup moved to NotificationService
    // This just needs to be called once to subscribe to topics
    await NotificationService.setupFCM();
  }

  @override
  Widget build(BuildContext context) {
    _setupFCM(context);
    
    return MaterialApp(
      title: 'Mango Detection',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.green,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.green,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
          ),
          foregroundColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Colors.blue,
          ),
        ),
      ),
      localizationsDelegates: [
        ...context.localizationDelegates,
        MonthYearPickerLocalizations.delegate,
      ],
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      home: FutureBuilder<Widget>(
        future: _getStartPage(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return snapshot.data!;
        },
      ),
      routes: {
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/user-home': (context) => const HomePage(),
        '/expert-home': (context) => const ExpertDashboard(),
      },
      builder: (context, child) =>
          NoInternetBanner(child: child ?? const SizedBox.shrink()),
    );
  }
}
