import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

//import 'main.dart';
import 'notification_service.dart';

class PushNotificationService {
  static StreamSubscription<String>? _tokenRefreshSubscription;
  static StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;
  static bool _isConfigured = false;
  static String? _activeEmail;

  static Future<void> configureForUser(String email) async {
    _activeEmail = email;

    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return;
    }

    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    final token = await messaging.getToken();
    if (token != null) {
      await _saveToken(email, token);
    }

    if (!_isConfigured) {
      _tokenRefreshSubscription = messaging.onTokenRefresh.listen((token) {
        final activeEmail = _activeEmail;
        if (activeEmail != null) {
          _saveToken(activeEmail, token);
        }
      });

      _foregroundMessageSubscription = FirebaseMessaging.onMessage.listen((
        message,
      ) {
        final title =
            message.notification?.title ??
            message.data['title']?.toString() ??
            'Vaccination reminder';
        final body =
            message.notification?.body ??
            message.data['body']?.toString() ??
            'You have a vaccination update.';

        NotificationService.showInstantNotification(title: title, body: body);
      });

      _isConfigured = true;
    }
  }

  static Future<void> clearUserToken(String email) async {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(email)
        .get();
    final token = userDoc.data()?['fcmToken']?.toString();

    if (token != null && token.isNotEmpty) {
      await FirebaseFirestore.instance.collection('users').doc(email).update({
        'fcmToken': FieldValue.delete(),
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  static Future<void> _saveToken(String email, String token) async {
    final duplicateTokens = await FirebaseFirestore.instance
        .collection('users')
        .where('fcmToken', isEqualTo: token)
        .get();

    for (final doc in duplicateTokens.docs) {
      if (doc.id != email) {
        await doc.reference.update({
          'fcmToken': FieldValue.delete(),
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        });
      }
    }

    await FirebaseFirestore.instance.collection('users').doc(email).set({
      'fcmToken': token,
      'pushNotificationsEnabled': true,
      'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> dispose() async {
    await _tokenRefreshSubscription?.cancel();
    await _foregroundMessageSubscription?.cancel();
    _tokenRefreshSubscription = null;
    _foregroundMessageSubscription = null;
    _isConfigured = false;
    _activeEmail = null;
  }
}
