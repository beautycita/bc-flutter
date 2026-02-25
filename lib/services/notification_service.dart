import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'supabase_client.dart';

/// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('[FCM-BG] Message: ${message.messageId}');
}

/// Notification service for FCM push notifications
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // Lazy — only access after Firebase.initializeApp() has been called
  FirebaseMessaging? _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  String? _fcmToken;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<String>? _tokenRefreshSub;

  /// Android notification channel for booking alerts
  static const AndroidNotificationChannel _bookingChannel =
      AndroidNotificationChannel(
    'booking_alerts',
    'Booking Alerts',
    description: 'Notifications for new bookings and updates',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  /// Initialize Firebase and notification permissions
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Initialize Firebase
      await Firebase.initializeApp();

      // Now safe to access FirebaseMessaging
      _messaging = FirebaseMessaging.instance;

      // Set background handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Request permissions
      final settings = await _messaging!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      debugPrint('[FCM] Permission status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        // Initialize local notifications for foreground display
        await _initLocalNotifications();

        // Get FCM token
        _fcmToken = await _messaging!.getToken();
        assert(() { debugPrint('[FCM] Token acquired'); return true; }());

        // Store token in database
        await _saveTokenToDatabase();

        // Listen for token refresh
        _tokenRefreshSub = _messaging!.onTokenRefresh.listen((newToken) {
          _fcmToken = newToken;
          _saveTokenToDatabase();
        });

        // Handle foreground messages
        _foregroundSub = FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

        // Handle notification tap when app was terminated
        final initialMessage = await _messaging!.getInitialMessage();
        if (initialMessage != null) {
          _handleNotificationTap(initialMessage);
        }

        // Handle notification tap when app was in background
        FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

        _initialized = true;
        debugPrint('[FCM] Initialized successfully');
      }
    } catch (e) {
      debugPrint('[FCM] Initialization error: $e');
    }
  }

  /// Initialize local notifications for foreground display
  Future<void> _initLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _localNotifications.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (response) {
        debugPrint('[LOCAL] Notification tapped: ${response.payload}');
        // Parse payload and navigate if needed
      },
    );

    // Create Android notification channel
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_bookingChannel);
  }

  /// Handle foreground messages - show local notification
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('[FCM-FG] Message: ${message.notification?.title}');

    final notification = message.notification;
    if (notification != null) {
      _localNotifications.show(
        message.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _bookingChannel.id,
            _bookingChannel.name,
            channelDescription: _bookingChannel.description,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: message.data['route'],
      );
    }
  }

  /// Handle notification tap - navigate to relevant screen
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('[FCM] Notification tapped: ${message.data}');

    final route = message.data['route'];
    final bookingId = message.data['booking_id'];

    // Navigation will be handled by the app's router
    // Store the pending navigation for the app to handle
    _pendingNavigation = {
      'route': route,
      'booking_id': bookingId,
    };
  }

  /// Pending navigation from notification tap
  Map<String, dynamic>? _pendingNavigation;
  Map<String, dynamic>? consumePendingNavigation() {
    final nav = _pendingNavigation;
    _pendingNavigation = null;
    return nav;
  }

  /// Save FCM token to Supabase for server-side notifications
  Future<void> _saveTokenToDatabase() async {
    if (_fcmToken == null) return;

    try {
      final userId = SupabaseClientService.currentUserId;
      if (userId == null) return;

      // Upsert FCM token to profiles table
      await SupabaseClientService.client
          .from('profiles')
          .update({
            'fcm_token': _fcmToken,
            'fcm_updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', userId);

      debugPrint('[FCM] Token saved to database');
    } catch (e) {
      debugPrint('[FCM] Error saving token: $e');
    }
  }

  /// Get current FCM token
  String? get token => _fcmToken;

  /// Subscribe to topic for broadcasts
  Future<void> subscribeToTopic(String topic) async {
    if (_messaging == null) return;
    await _messaging!.subscribeToTopic(topic);
    debugPrint('[FCM] Subscribed to topic: $topic');
  }

  /// Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    if (_messaging == null) return;
    await _messaging!.unsubscribeFromTopic(topic);
    debugPrint('[FCM] Unsubscribed from topic: $topic');
  }

  /// Cleanup
  void dispose() {
    _foregroundSub?.cancel();
    _tokenRefreshSub?.cancel();
  }
}
