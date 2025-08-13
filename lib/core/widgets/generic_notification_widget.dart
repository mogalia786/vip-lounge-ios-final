import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform, kIsWeb;

class GenericNotificationWidget {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  // Copy of the rating notification pattern
  Future<void> sendGenericNotification({
    required String recipientId,
    required String title,
    required String body,
    required String appointmentId,
    required String role,
    required Map<String, dynamic> additionalData,
  }) async {
    try {
      print('\n🔔🔔🔔 NOTIFICATION START: Sending generic notification to $role: $recipientId');
      
      // Get appointment details (exactly like rating code)
      print('🔍 Fetching appointment: $appointmentId');
      final appointmentDoc = await _firestore.collection('appointments').doc(appointmentId).get();
      if (!appointmentDoc.exists) {
        print('⚠️ ERROR: Appointment not found: $appointmentId');
        throw Exception('Appointment not found: $appointmentId');
      }
      
      final appointmentData = appointmentDoc.data()!;
      print('✓ Got appointment data: ${appointmentData.keys.join(', ')}');
      
      // Create notification data (exactly like rating code)
      final notificationData = {
        'appointmentId': appointmentId,
        ...additionalData,
        ...appointmentData,
      };
      print('📦 Prepared notification data');
      
      // Create in-app notification (exactly like rating code)
      print('📝 Creating in-app notification in Firestore');
      await _firestore.collection('notifications').add({
        'title': title,
        'body': body,
        'data': notificationData,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'role': role,
        'assignedToId': recipientId,
      });
      print('✓ In-app notification created');
      
      // Send FCM (exactly like rating code)
      print('🔍 Fetching recipient token: $recipientId');
      final recipientDoc = await _firestore.collection('users').doc(recipientId).get();
      final recipientToken = recipientDoc.data()?['fcmToken'];
      print('📱 Recipient token: ${recipientToken != null ? 'Found' : 'NULL/MISSING - CANNOT SEND!'}');
      
      if (recipientToken != null) {
        final stringData = _convertToStringMap(notificationData);
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
          print('🚀 Sending FCM message via Firebase SDK (Android only)');
          try {
            await _fcm.sendMessage(
              to: recipientToken,
              data: stringData,
              messageId: 'notification_${appointmentId}_${DateTime.now().millisecondsSinceEpoch}',
              messageType: 'generic_notification',
              collapseKey: 'notification_${appointmentId}',
            );
            print('✅ FCM message sent successfully');
          } catch (fcmError) {
            print('❌ FCM ERROR: $fcmError');
          }
        } else {
          print('[FCM] sendMessage skipped on this platform (iOS/web). Token=$recipientToken');
        }
      } else {
        print('⛔ NO TOKEN - Cannot send FCM notification');
      }
      
      print('✅ Generic notification process complete for $role: $recipientId\n');
    } catch (e) {
      print('❌❌❌ ERROR in notification process: $e');
      // Don't throw - allow execution to continue
    }
  }

  // Helper method (exactly like rating code)
  Map<String, String> _convertToStringMap(Map<String, dynamic> data) {
    return data.map((key, value) => MapEntry(key, value?.toString() ?? ''));
  }
}
