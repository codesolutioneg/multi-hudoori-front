import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';

import '../di/injection.dart';
import '../router/app_router.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background isolate — no UI navigation here.
}

class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  GoRouter? _router;
  String? _subscribedTopic;
  bool _initialized = false;

  void attachRouter(GoRouter router) => _router = router;

  Future<void> init() async {
    if (kIsWeb || _initialized) return;
    _initialized = true;
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _local.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (_) => _openInbox(),
    );

    if (Platform.isAndroid) {
      await _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              'hudoori_alerts',
              'Hudoori alerts',
              importance: Importance.high,
            ),
          );
    }

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen((m) => _handleRemoteMessage(m));
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      _handleRemoteMessage(initial);
    }
  }

  Future<void> syncSession({required String? companyId}) async {
    if (kIsWeb) return;
    await init();
    await _requestPermission();
    String? token;
    try {
      token = await FirebaseMessaging.instance.getToken();
    } catch (e) {
      debugPrint('FCM getToken failed: $e');
    }
    try {
      await api.setFcmToken(token);
    } catch (e) {
      debugPrint('FCM token sync failed: $e');
    }
    await _syncTopic(companyId);
  }

  Future<void> onLogout() async {
    if (kIsWeb) return;
    await _syncTopic(null);
    try {
      await api.setFcmToken(null);
    } catch (_) {}
  }

  Future<void> _requestPermission() async {
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> _syncTopic(String? companyId) async {
    final next = companyId != null && companyId.isNotEmpty
        ? 'company_$companyId'
        : null;
    if (_subscribedTopic == next) return;
    try {
      if (_subscribedTopic != null) {
        await FirebaseMessaging.instance.unsubscribeFromTopic(_subscribedTopic!);
      }
      if (next != null) {
        await FirebaseMessaging.instance.subscribeToTopic(next);
      }
      _subscribedTopic = next;
    } catch (e) {
      debugPrint('FCM topic sync failed: $e');
    }
  }

  void _onForegroundMessage(RemoteMessage message) {
    final n = message.notification;
    if (n == null) return;
    _local.show(
      message.hashCode,
      n.title,
      n.body,
      NotificationDetails(
        android: const AndroidNotificationDetails(
          'hudoori_alerts',
          'Hudoori alerts',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: 'notifications',
    );
  }

  void _handleRemoteMessage(RemoteMessage message) {
    final route = message.data['route']?.toString();
    if (route != null && route.isNotEmpty && route != '/notifications') {
      _router?.push(route);
      return;
    }
    _openInbox();
  }

  void _openInbox() {
    _router?.push(AppRoutes.notifications);
  }
}
