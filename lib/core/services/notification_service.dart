import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive/hive.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Handles Firebase Cloud Messaging (FCM) and local notifications
class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'high_importance_v2';
  static const String _channelName = 'High Importance Notifications';

  /// Initialize local notifications
  static Future<void> initializeLocalNotifications() async {
    try {
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@drawable/ic_stat_notify');
      const InitializationSettings initSettings =
          InitializationSettings(android: androidSettings);

      await _localNotificationsPlugin.initialize(initSettings);

      // Create Android notification channel (Android 8+)
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'Used for important notifications like reviews and requests',
        importance: Importance.high,
      );

      final androidPlugin = _localNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(channel);

      print('✅ Local notifications initialized');
    } catch (e) {
      print('❌ Local notifications initialization failed: $e');
    }
  }

  /// Request notification permissions and setup FCM
  static Future<void> setupFCM() async {
    try {
      // Request notification permissions
      await FirebaseMessaging.instance.requestPermission();

      // Get FCM token and store it
      String? token = await FirebaseMessaging.instance.getToken();
      final user = FirebaseAuth.instance.currentUser;

      if (user != null && token != null) {
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({'fcmToken': token}, SetOptions(merge: true));
          print('✅ FCM token saved: \${token.substring(0, 20)}...');
        } catch (e) {
          print('⚠️ Error saving FCM token: \$e');
        }
      }

      // Set up background message handler
      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);

      // Set up topic subscriptions
      _subscribeToTopics();

      // Listen for token refresh
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        final u = FirebaseAuth.instance.currentUser;
        if (u != null) {
          try {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(u.uid)
                .update({'fcmToken': newToken});
            print('✅ FCM token refreshed');
          } catch (e) {
            print('⚠️ Error updating FCM token: \$e');
          }
        }
        _subscribeToTopics();
      });

      // Listen for foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      print('✅ FCM setup completed');
    } catch (e) {
      print('❌ FCM setup failed: \$e');
    }
  }

  /// Subscribe to appropriate notification topics
  static Future<void> _subscribeToTopics() async {
    try {
      final settingsBox = Hive.box('settings');
      final notificationsEnabled =
          settingsBox.get('enableNotifications', defaultValue: true) as bool;

      if (notificationsEnabled) {
        await FirebaseMessaging.instance.subscribeToTopic('all_users');

        final userBox = Hive.box('userBox');
        final profile = userBox.get('userProfile') as Map?;
        final role = profile?['role'] as String?;

        if (role == 'expert') {
          await FirebaseMessaging.instance.subscribeToTopic('experts');
        } else {
          await FirebaseMessaging.instance.unsubscribeFromTopic('experts');
        }
      } else {
        await FirebaseMessaging.instance.unsubscribeFromTopic('all_users');
        await FirebaseMessaging.instance.unsubscribeFromTopic('experts');
      }
    } catch (e) {
      print('⚠️ Error subscribing to topics: \$e');
    }
  }

  /// Handle foreground messages
  static void _handleForegroundMessage(RemoteMessage message) {
    try {
      final settingsBox = Hive.box('settings');
      final enabled =
          settingsBox.get('enableNotifications', defaultValue: true) as bool;

      if (!enabled) return;

      RemoteNotification? notification = message.notification;
      AndroidNotification? android = notification?.android;

      if (notification != null && android != null) {
        _localNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              _channelName,
              importance: Importance.max,
              priority: Priority.high,
            ),
          ),
        );
      }
    } catch (e) {
      print('⚠️ Error handling foreground message: \$e');
    }
  }

  /// Background message handler
  @pragma('vm:entry-point')
  static Future<void> _firebaseMessagingBackgroundHandler(
      RemoteMessage message) async {
    try {
      await Firebase.initializeApp();
      await initializeLocalNotifications();

      // Avoid duplicates: if FCM includes a notification payload,
      // Android will display it automatically. Only show for data-only messages.
      if (message.notification == null) {
        final String title = message.data['title']?.toString() ?? 'Notification';
        final String body = message.data['body']?.toString() ?? '';

        await _localNotificationsPlugin.show(
          message.hashCode,
          title,
          body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              _channelName,
              importance: Importance.max,
              priority: Priority.high,
            ),
          ),
        );
      }
    } catch (e) {
      print('❌ Background message handler failed: \$e');
    }
  }
}
