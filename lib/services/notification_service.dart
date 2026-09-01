import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await NotificationService.saveToFirestore(
    title: message.notification?.title ?? '',
    body: message.notification?.body ?? '',
    type: message.data['type'] ?? 'system',
    userId: message.data['userId'],
  );
}

class NotificationService {
  static Future<void> initialize() async {
    await FirebaseMessaging.instance.requestPermission(
      alert: true, badge: true, sound: true,
    );
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true, badge: true, sound: true,
    );
    FirebaseMessaging.onMessage.listen((RemoteMessage msg) async {
      final n = msg.notification;
      if (n == null) return;
      await saveToFirestore(
        title: n.title ?? '',
        body: n.body ?? '',
        type: msg.data['type'] ?? 'system',
      );
    });
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  static Future<void> saveFcmToken() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;
    await FirebaseFirestore.instance
        .collection('users').doc(uid)
        .set({'fcm_token': token}, SetOptions(merge: true));
    FirebaseMessaging.instance.onTokenRefresh.listen((t) {
      FirebaseFirestore.instance
          .collection('users').doc(uid)
          .set({'fcm_token': t}, SetOptions(merge: true));
    });
  }

  // Used by: register.dart (welcome), admin_home.dart (approve/reject),
  //          Cloud Functions (expiry, monthly reminder)
  static Future<void> saveToFirestore({
    required String title,
    required String body,
    required String type,
    String? userId,
  }) async {
    final uid = userId ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('users').doc(uid)
        .collection('notifications')
        .add({
      'title': title,
      'body': body,
      'type': type,
      'read': false,
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> markRead(String notifId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('users').doc(uid)
        .collection('notifications').doc(notifId)
        .update({'read': true});
  }

  static IconData iconForType(String type) {
    switch (type) {
      case 'abone_approved':  return Icons.check_circle_outline;
      case 'abone_rejected':  return Icons.cancel_outlined;
      case 'abone_expiring':  return Icons.timer_outlined;
      case 'monthly_reminder':return Icons.calendar_today;
      case 'system':          return Icons.info_outline;
      default:                return Icons.notifications_outlined;
    }
  }

  static Color colorForType(String type) {
    switch (type) {
      case 'abone_approved':  return const Color(0xFF00C853);
      case 'abone_rejected':  return Colors.red;
      case 'abone_expiring':  return Colors.orange;
      case 'monthly_reminder':return const Color(0xFF3A7DFF);
      case 'system':          return Colors.grey;
      default:                return const Color(0xFF3A7DFF);
    }
  }
}