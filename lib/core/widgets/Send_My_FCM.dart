import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform, kIsWeb;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

/// SendMyFCM is a utility class that handles both Firebase Cloud Messaging (FCM) 
/// push notifications and in-app notifications using the same pattern as rating notifications.
class SendMyFCM {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  /// Sends both FCM push notification and creates in-app notification
  /// Parameters:
  /// - recipientId: ID of user to receive notification
  /// - title: Title of the notification
  /// - body: Content/message body of the notification
  /// - appointmentId: Related appointment ID
  /// - role: Role of recipient (minister, consultant, concierge, floor_manager)
  /// - additionalData: Any extra data to include with notification
  /// - showRating: Whether to show rating option (defaults to false)
  /// - notificationType: Type of notification (default 'general')
  Future<void> sendNotification({
    required String recipientId,
    required String title,
    required String body,
    required String appointmentId,
    required String role,
    Map<String, dynamic> additionalData = const {},
    bool showRating = false,
    String notificationType = 'general',
    bool skipAppointmentCheck = false,
  }) async {
    try {
      debugPrint('[SendMyFCM] --- sendNotification START ---');
      debugPrint('[SendMyFCM] Params: recipientId=$recipientId, appointmentId=$appointmentId, role=$role, notificationType=$notificationType');

      // Initialize appointment data
      Map<String, dynamic> appointmentData = {};

      // Only fetch appointment details if not skipping the check
      if (!skipAppointmentCheck) {
        debugPrint('[SendMyFCM] Fetching appointment details for: $appointmentId');
        final appointmentDoc = await _firestore.collection('appointments').doc(appointmentId).get();
        if (!appointmentDoc.exists) {
          debugPrint('[SendMyFCM][ERROR] Appointment not found: $appointmentId. Notification will NOT be sent.');
          return;
        }
        appointmentData = appointmentDoc.data()!;
      } else {
        debugPrint('[SendMyFCM] Skipping appointment check for notification type: $notificationType');
      }
      debugPrint('[SendMyFCM] Loaded appointment data: ' + appointmentData.toString());

      // Create notification data
      final notificationData = {
        'appointmentId': appointmentId,
        'showRating': showRating,
        'notificationType': notificationType,
        ...additionalData,
        if (appointmentData.isNotEmpty) ...appointmentData,
      };

      debugPrint('[SendMyFCM] Notification data prepared: $notificationData');

      // Create in-app notification in Firestore (awaited, ensures UI shows update immediately)
      debugPrint('[SendMyFCM] Writing in-app notification to Firestore for $recipientId...');
      await _firestore.collection('notifications').add({
        'title': title,
        'body': body,
        'data': notificationData,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'timestamp': FieldValue.serverTimestamp(),
        'role': role,
        'assignedToId': recipientId,
        'notificationType': notificationType,
      });
      debugPrint('[SendMyFCM] In-app notification written to Firestore for $recipientId.');

      // Send FCM push notification in a detached task so UI never blocks
      unawaited(_sendPushAsync(
        recipientId: recipientId,
        title: title,
        body: body,
        notificationData: notificationData,
        appointmentId: appointmentId,
        notificationType: notificationType,
      ));
      debugPrint('[SendMyFCM] Push send dispatched (non-blocking).');
      debugPrint('[SendMyFCM] --- sendNotification END ---');
    } catch (e) {
      debugPrint('[SendMyFCM][ERROR] Exception in sendNotification: $e');
    }
  }

  // Internal: fire-and-forget push sending with short timeouts/guards
  Future<void> _sendPushAsync({
    required String recipientId,
    required String title,
    required String body,
    required Map<String, dynamic> notificationData,
    required String appointmentId,
    required String notificationType,
  }) async {
    try {
      final recipientDoc = await _firestore.collection('users').doc(recipientId).get();
      if (!recipientDoc.exists) {
        debugPrint('[SendMyFCM][PUSH] Recipient not found: $recipientId');
        return;
      }
      final recipientToken = recipientDoc.data()?['fcmToken'];
      if (recipientToken == null || recipientToken.toString().isEmpty) {
        debugPrint('[SendMyFCM][PUSH] Missing FCM token for $recipientId');
        return;
      }

      // Try SDK send first (Android only). iOS/web skip to avoid UnimplementedError.
      try {
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
          final stringData = _convertToStringMap(notificationData);
          await _fcm
              .sendMessage(
                to: recipientToken,
                data: stringData,
                messageId: 'notification_${appointmentId}_${DateTime.now().millisecondsSinceEpoch}',
                messageType: notificationType,
                collapseKey: 'notification_${appointmentId}',
              )
              .timeout(const Duration(seconds: 2));
          debugPrint('[SendMyFCM][PUSH] SDK send ok (Android)');
          return;
        } else {
          debugPrint('[SendMyFCM][PUSH] SDK send skipped on this platform (iOS/web).');
        }
      } catch (e) {
        debugPrint('[SendMyFCM][PUSH] SDK send failed or timed out: $e');
      }

      // Fallback to Cloud Function with a short timeout
      try {
        await _sendViaCloudFunction(recipientToken, title, body, notificationData, notificationType)
            .timeout(const Duration(seconds: 3));
        debugPrint('[SendMyFCM][PUSH] Cloud Function send attempted');
      } catch (e) {
        debugPrint('[SendMyFCM][PUSH] Cloud Function send failed or timed out: $e');
      }
    } catch (e) {
      debugPrint('[SendMyFCM][PUSH] Unexpected error: $e');
    }
  }

  // Helper method to convert to string map for FCM
  Map<String, String> _convertToStringMap(Map<String, dynamic> data) {
    return data.map((key, value) {
      // Convert Timestamp objects to ISO string format
      if (value is Timestamp) {
        return MapEntry(key, value.toDate().toIso8601String());
      }
      // Handle null values
      if (value == null) {
        return MapEntry(key, "");
      }
      // Convert everything else to string
      return MapEntry(key, value.toString());
    });
  }
  
  // Fallback method using cloud function
  Future<void> _sendViaCloudFunction(
    String token, 
    String title, 
    String body, 
    Map<String, dynamic> data,
    String messageType
  ) async {
    try {
      final url = Uri.parse('https://us-central1-vip-lounge-f3730.cloudfunctions.net/sendNotification');
      
      final payload = {
        'token': token,
        'title': title,
        'body': body,
        'data': _convertToStringMap(data),
        'messageType': messageType,
        'expanded': true,  // Flag to indicate expanded notification
        'style': 'bigText', // For Android, use bigText style
        'display_notification_details': true, // Custom flag for expanded details
      };
      
      final response = await http
          .post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      )
          .timeout(const Duration(seconds: 3));
    } catch (e) {
      // Silent failure
    }
  }
}