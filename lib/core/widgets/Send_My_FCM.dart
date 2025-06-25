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
  }) async {
    try {
      // Get appointment details
      final appointmentDoc = await _firestore.collection('appointments').doc(appointmentId).get();
      if (!appointmentDoc.exists) {
        throw Exception('Appointment not found: $appointmentId');
      }
      
      final appointmentData = appointmentDoc.data()!;
      
      // Create notification data
      final notificationData = {
        'appointmentId': appointmentId,
        'showRating': showRating,
        ...additionalData,
        ...appointmentData,
      };
      
      // Create in-app notification in Firestore
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
      
      // Send FCM push notification
      final recipientDoc = await _firestore.collection('users').doc(recipientId).get();
      final recipientToken = recipientDoc.data()?['fcmToken'];
      
      // Method 1: Direct Firebase SDK (may not work in all environments)
      if (recipientToken != null) {
        try {
          final stringData = _convertToStringMap(notificationData);
          
          await _fcm.sendMessage(
            to: recipientToken,
            data: stringData,
            messageId: 'notification_${appointmentId}_${DateTime.now().millisecondsSinceEpoch}',
            messageType: notificationType,
            collapseKey: 'notification_${appointmentId}',
          );
        } catch (fcmError) {
          // Try Method 2: Cloud Function
          _sendViaCloudFunction(recipientToken, title, body, notificationData, notificationType);
        }
      }
    } catch (e) {
      // Don't throw - allow execution to continue
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
      
      await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
    } catch (e) {
      // Silent failure
    }
  }
}