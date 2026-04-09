import 'dart:async';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'supabase_client.dart';

/// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  if (kDebugMode) debugPrint('[FCM-BG] Message: ${message.messageId}');
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
  StreamSubscription<RemoteMessage>? _messageOpenedSub;

  /// Custom vibration pattern: attention pulse + pause + confirm pulse
  /// Values in milliseconds: [wait, vibrate, pause, vibrate]
  static final Int64List _vibrationPattern =
      Int64List.fromList([0, 150, 100, 200]);

  /// Android notification channels — one per notification type
  static const _channelBooking = AndroidNotificationChannel(
    'beautycita_booking',
    'Reservaciones',
    description: 'Confirmaciones y actualizaciones de citas',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
    sound: RawResourceAndroidNotificationSound('beautycita_notify'),
  );

  static const _channelChat = AndroidNotificationChannel(
    'beautycita_chat',
    'Mensajes',
    description: 'Nuevos mensajes de salones',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
    sound: RawResourceAndroidNotificationSound('beautycita_notify'),
  );

  static const _channelPayment = AndroidNotificationChannel(
    'beautycita_payment',
    'Pagos',
    description: 'Confirmaciones de pago y recibos',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
    sound: RawResourceAndroidNotificationSound('beautycita_notify'),
  );

  static const _channelAlert = AndroidNotificationChannel(
    'beautycita_alert',
    'Alertas',
    description: 'Alertas del sistema y promociones',
    importance: Importance.defaultImportance,
    playSound: true,
    enableVibration: true,
    sound: RawResourceAndroidNotificationSound('beautycita_notify'),
  );

  /// Route FCM message to the correct notification channel
  static AndroidNotificationChannel _channelForType(String? type) {
    return switch (type) {
      'booking_confirmed' || 'booking_updated' || 'booking_cancelled' || 'booking_reminder'
          => _channelBooking,
      'chat_message' || 'new_message'
          => _channelChat,
      'payment_received' || 'payment_failed' || 'refund_processed'
          => _channelPayment,
      _ => _channelAlert,
    };
  }

  /// Initialize Firebase and notification permissions
  Future<void> initialize() async {
    if (_initialized) return;

    // Check enable_push_notifications toggle before initializing FCM
    try {
      if (SupabaseClientService.isInitialized) {
        final row = await SupabaseClientService.client
            .from('app_config')
            .select('value')
            .eq('key', 'enable_push_notifications')
            .maybeSingle();
        if (row != null && row['value'] == 'false') {
          if (kDebugMode) debugPrint('[Notifications] Push disabled by feature toggle');
          return;
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Notifications] Toggle check failed, proceeding: $e');
    }

    // iOS sideload (free Apple ID) has no APNs certificate.
    // Skip ALL FCM initialization — no token registration, no foreground
    // handlers, no background handlers. All notifications come via WhatsApp.
    // This early return is intentional — not just token registration.
    if (Platform.isIOS) {
      if (kDebugMode) debugPrint('[Notifications] iOS sideload — skipping FCM entirely (no APNs)');
      return;
    }

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

      if (kDebugMode) debugPrint('[FCM] Permission status: ${settings.authorizationStatus}');

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
        _tokenRefreshSub = _messaging!.onTokenRefresh.listen((newToken) async {
          _fcmToken = newToken;
          try {
            await _saveTokenToDatabase();
          } catch (e) {
            if (kDebugMode) debugPrint('[FCM] Token refresh save error: $e');
          }
        });

        // Handle foreground messages
        _foregroundSub = FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

        // Handle notification tap when app was terminated
        final initialMessage = await _messaging!.getInitialMessage();
        if (initialMessage != null) {
          _handleNotificationTap(initialMessage);
        }

        // Handle notification tap when app was in background
        _messageOpenedSub = FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

        _initialized = true;
        if (kDebugMode) debugPrint('[FCM] Initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[FCM] Initialization error: $e');
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
      settings: const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (response) {
        if (kDebugMode) debugPrint('[LOCAL] Notification tapped: ${response.payload}');
        // Parse payload and navigate if needed
      },
    );

    // Create Android notification channels + clean up legacy channel
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.deleteNotificationChannel(channelId: 'booking_alerts');
      await androidPlugin.createNotificationChannel(_channelBooking);
      await androidPlugin.createNotificationChannel(_channelChat);
      await androidPlugin.createNotificationChannel(_channelPayment);
      await androidPlugin.createNotificationChannel(_channelAlert);
    }
  }

  /// Handle foreground messages - show local notification
  void _handleForegroundMessage(RemoteMessage message) {
    if (kDebugMode) debugPrint('[FCM-FG] Message: ${message.notification?.title}');

    final notification = message.notification;
    if (notification != null) {
      final channel = _channelForType(message.data['type'] as String?);
      _localNotifications.show(
        id: message.hashCode,
        title: notification.title,
        body: notification.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            importance: channel.importance,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            sound: channel.sound,
            vibrationPattern: _vibrationPattern,
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
    if (kDebugMode) debugPrint('[FCM] Notification tapped: ${message.data}');

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

      if (kDebugMode) debugPrint('[FCM] Token saved to database');
    } catch (e) {
      if (kDebugMode) debugPrint('[FCM] Error saving token: $e');
    }
  }

  /// Get current FCM token
  String? get token => _fcmToken;

  /// Subscribe to topic for broadcasts
  Future<void> subscribeToTopic(String topic) async {
    if (_messaging == null) return;
    await _messaging!.subscribeToTopic(topic);
    if (kDebugMode) debugPrint('[FCM] Subscribed to topic: $topic');
  }

  /// Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    if (_messaging == null) return;
    await _messaging!.unsubscribeFromTopic(topic);
    if (kDebugMode) debugPrint('[FCM] Unsubscribed from topic: $topic');
  }

  /// Cleanup
  void dispose() {
    _foregroundSub?.cancel();
    _tokenRefreshSub?.cancel();
    _messageOpenedSub?.cancel();
  }
}
