import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

/// Background message handler — must be a top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background messages are handled automatically by the OS as notifications
  debugPrint('FCM background message: ${message.messageId}');
}

/// FCM service — initialises Firebase Messaging, requests permission,
/// and returns the device token for registration with the backend.
class FcmService {
  static final _fcm = FirebaseMessaging.instance;
  static String? _token;

  static Future<void> init() async {
    // Request notification permissions (iOS / Android 13+)
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Foreground messages show as visual in-app banner (handled by OS on background)
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Register background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    try {
      _token = await _fcm.getToken();
      debugPrint('FCM token: $_token');
    } catch (e) {
      debugPrint('Failed to get FCM token: $e');
    }
  }

  static String? get token => _token;

  /// Re-fetch token (call after login if token may have changed)
  static Future<String?> refreshToken() async {
    try {
      _token = await _fcm.getToken();
    } catch (e) {
      debugPrint('Failed to refresh FCM token: $e');
    }
    return _token;
  }
}
