import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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

      // Create in-app notification in Firestore
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

      // Send FCM push notification
      final recipientDoc = await _firestore.collection('users').doc(recipientId).get();
      if (!recipientDoc.exists) {
        debugPrint('[SendMyFCM][ERROR] Recipient user not found in users: $recipientId. FCM will NOT be sent.');
        return;
      }
      debugPrint('[SendMyFCM] Loaded recipient doc for $recipientId: ' + (recipientDoc.data()?.toString() ?? 'null'));
      final recipientToken = recipientDoc.data()?['fcmToken'];
      if (recipientToken == null || recipientToken.toString().isEmpty) {
        debugPrint('[SendMyFCM][ERROR] No FCM token found for recipient: $recipientId. FCM will NOT be sent.');
        return;
      }
      debugPrint('[SendMyFCM] Recipient FCM token: $recipientToken');

      // Method 1: Direct Firebase SDK (may not work in all environments)
      debugPrint('[SendMyFCM] Attempting to send FCM push notification via FirebaseMessaging SDK...');
      try {
        final stringData = _convertToStringMap(notificationData);
        await _fcm.sendMessage(
          to: recipientToken,
          data: stringData,
          messageId: 'notification_${appointmentId}_${DateTime.now().millisecondsSinceEpoch}',
          messageType: notificationType,
          collapseKey: 'notification_${appointmentId}',
        );
        debugPrint('[SendMyFCM] FCM push notification sent successfully via FirebaseMessaging SDK.');
      } catch (fcmError) {
        debugPrint('[SendMyFCM][ERROR] Failed to send FCM via FirebaseMessaging SDK: $fcmError');
        // Try Method 2: Cloud Function
        debugPrint('[SendMyFCM] Falling back to Cloud Function method for FCM...');
        await _sendViaCloudFunction(recipientToken, title, body, notificationData, notificationType);
      }
      debugPrint('[SendMyFCM] --- sendNotification END ---');
    } catch (e) {
      debugPrint('[SendMyFCM][ERROR] Exception in sendNotification: $e');
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
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
    } catch (e) {
      // Silent failure
    }
  }
}