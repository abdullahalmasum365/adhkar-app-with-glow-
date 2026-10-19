// ============================================================================
// lib/services/fcm_service.dart
//
// FIREBASE CLOUD MESSAGING (FCM) SERVICE — Adhkaar 365
//
// Handles:
//   - Remote Push Notifications from Firebase Console (Announcements, Jumu'ah, Ramadan, etc.)
//   - Background & Terminated message processing
//   - Foreground message display via local notification heads-up banner
//   - Universal topic subscriptions ('all_users', 'announcements')
//   - Language-targeted topic subscriptions ('lang_bn', 'lang_en', etc.)
//   - Deep-link navigation on notification tap
//   - Token synchronization to Firestore for logged-in users
// ============================================================================

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_service.dart';

/// Top-level background message handler.
/// MUST be annotated @pragma('vm:entry-point') so the Dart tree-shaker
/// retains it in release builds.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } catch (e) {
    debugPrint('[FcmService BG] Firebase.initializeApp notice: $e');
  }
  debugPrint('[FcmService BG] Received background message: id=${message.messageId}, data=${message.data}');
}

class FcmService {
  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;
  FcmService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  bool _initialized = false;
  String? _currentToken;

  String? get currentToken => _currentToken;

  /// Initializes FCM permissions, handlers, topic subscriptions, and token syncing.
  Future<void> init() async {
    if (_initialized) return;
    if (Firebase.apps.isEmpty) {
      debugPrint('[FcmService] Firebase is not initialized, skipping FCM setup');
      return;
    }

    try {
      // 1. Request notification permissions (for Android 13+ & iOS)
      final settings = await _fcm.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      debugPrint('[FcmService] Notification permission status: ${settings.authorizationStatus}');

      // 2. Set presentation options for iOS foreground notifications
      await _fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // 3. Register background message handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // 4. Handle foreground notifications (show heads-up banner via local notification)
      FirebaseMessaging.onMessage.listen(_onForegroundMessage);

      // 5. Handle notification click when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen(_onNotificationOpenedApp);

      // 6. Handle notification click when app was launched from terminated state
      final initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('[FcmService] App launched from terminated state via FCM: ${initialMessage.data}');
        _handleMessageNavigation(initialMessage);
      }

      // 7. Subscribe to default broadcast topics
      await subscribeToTopics();

      // 8. Retrieve & save FCM token
      _currentToken = await _fcm.getToken();
      debugPrint('[FcmService] Initial FCM Token: $_currentToken');
      if (_currentToken != null) {
        await _saveTokenLocallyAndToCloud(_currentToken!);
      }

      // 9. Listen for token refreshes
      _fcm.onTokenRefresh.listen((newToken) {
        debugPrint('[FcmService] Token refreshed: $newToken');
        _currentToken = newToken;
        _saveTokenLocallyAndToCloud(newToken);
      });

      _initialized = true;
      debugPrint('[FcmService] FCM initialized successfully');
    } catch (e) {
      debugPrint('[FcmService] Error initializing FCM: $e');
    }
  }

  /// Subscribes to broadcast topics:
  /// - 'all_users': For universal announcements to all app users
  /// - 'announcements': For special updates and news
  /// - 'lang_{code}': For language-targeted notifications (e.g. 'lang_bn', 'lang_en')
  Future<void> subscribeToTopics() async {
    try {
      await _fcm.subscribeToTopic('all_users');
      await _fcm.subscribeToTopic('announcements');

      final prefs = await SharedPreferences.getInstance();
      final lang = prefs.getString('language_code') ?? 'en';
      await _fcm.subscribeToTopic('lang_$lang');
      debugPrint('[FcmService] Subscribed to topics: all_users, announcements, lang_$lang');
    } catch (e) {
      debugPrint('[FcmService] Error subscribing to topics: $e');
    }
  }

  /// Called when the user changes their interface language in Settings.
  /// Unsubscribes from the old language topic and subscribes to the new one.
  Future<void> onLanguageChanged(String oldLang, String newLang) async {
    if (oldLang == newLang) return;
    try {
      await _fcm.unsubscribeFromTopic('lang_$oldLang');
      await _fcm.subscribeToTopic('lang_$newLang');
      debugPrint('[FcmService] Language topic updated from lang_$oldLang to lang_$newLang');
    } catch (e) {
      debugPrint('[FcmService] Error updating language topic: $e');
    }
  }

  void _onForegroundMessage(RemoteMessage message) {
    debugPrint('[FcmService] Foreground message received: ${message.messageId}');
    final notification = message.notification;
    final title = notification?.title ?? message.data['title'] ?? 'Adhkaar 365';
    final body = notification?.body ?? message.data['body'] ?? '';
    final payload = message.data['route'] ?? message.data['payload'] ?? message.data['category'] ?? '';

    NotificationService().showAnnouncementNotification(
      id: message.hashCode,
      title: title,
      body: body,
      payload: payload.isNotEmpty ? payload : null,
    );
  }

  void _onNotificationOpenedApp(RemoteMessage message) {
    debugPrint('[FcmService] User tapped notification from background: ${message.data}');
    _handleMessageNavigation(message);
  }

  void _handleMessageNavigation(RemoteMessage message) {
    final payload = message.data['route'] ?? message.data['payload'] ?? message.data['category'] ?? '';
    if (payload.isNotEmpty) {
      NotificationService.routeForPayload(payload);
    }
  }

  Future<void> _saveTokenLocallyAndToCloud(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_token', token);

      final user = FirebaseAuth.instance.currentUser;
      if (user != null && Firebase.apps.isNotEmpty) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'fcmToken': token,
          'fcmUpdatedAt': FieldValue.serverTimestamp(),
          'platform': Platform.operatingSystem,
        }, SetOptions(merge: true));
        debugPrint('[FcmService] Token synced to Firestore for user: ${user.uid}');
      }
    } catch (e) {
      debugPrint('[FcmService] Error saving FCM token: $e');
    }
  }
}
