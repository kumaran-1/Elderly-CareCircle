import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'api_client.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class PushNotificationService {
  PushNotificationService(this._apiClient);

  final ApiClient _apiClient;
  FirebaseMessaging? _messaging;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) {
      return;
    }

    try {
      await Firebase.initializeApp();
      _messaging = FirebaseMessaging.instance;

      final settings = await _messaging!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        return;
      }

      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      _messaging!.onTokenRefresh.listen((token) {
        _registerToken(token);
      });

      final token = await _messaging!.getToken();
      if (token != null) {
        await _registerToken(token);
      }

      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      _initialized = true;
    } catch (_) {
      // Push notification init failed; app continues without push
    }
  }

  Future<void> _registerToken(String token) async {
    try {
      await _apiClient.registerDevice(token);
    } catch (_) {
      // Token registration failed; will retry on next init
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    if (kDebugMode) {
      debugPrint('Foreground message: ${message.notification?.title}');
    }
  }
}
