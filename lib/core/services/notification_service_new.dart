import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform, kIsWeb;
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Convert values to string format for FCM
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
  
  // Helper method to get floor manager FCM tokens
  Future<List<String>> _getFloorManagerFcmTokens() async {
    List<String> tokens = [];
    try {
      final floorManagerDocs = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'floor_manager')
          .get();
      
      for (var doc in floorManagerDocs.docs) {
        final token = doc.data()['fcmToken'];
        if (token != null && token.toString().isNotEmpty) {
          tokens.add(token.toString());
        }
      }
    } catch (e) {
      print('Error getting floor manager tokens: $e');
    }
    return tokens;
  }
  
  // Helper method to get consultant FCM tokens
  Future<List<String>> _getConsultantsFcmTokens() async {
    List<String> tokens = [];
    try {
      final consultantDocs = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'consultant')
          .get();
      
      for (var doc in consultantDocs.docs) {
        final token = doc.data()['fcmToken'];
        if (token != null && token.toString().isNotEmpty) {
          tokens.add(token.toString());
        }
      }
    } catch (e) {
      print('Error getting consultant tokens: $e');
    }
    return tokens;
  }
  
  // Helper method to get a user's FCM token
  Future<String?> _getUserFcmToken(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return doc.data()?['fcmToken'];
      }
    } catch (e) {
      print('Error getting user token: $e');
    }
    return null;
  }
  
  // Send push notification using Firebase Cloud Messaging
  Future<void> _sendPushNotification(String token, String title, String body, Map<String, dynamic> data) async {
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await _fcm.sendMessage(
          to: token,
          data: _convertToStringMap(data),
          messageId: 'notification_${DateTime.now().millisecondsSinceEpoch}',
          messageType: data['notificationType'] ?? 'general',
          collapseKey: data['appointmentId'] != null ? 'appointment_${data['appointmentId']}' : 'general',
        );
      } else {
        debugPrint('[FCM] _sendPushNotification skipped on this platform (iOS/web). Token=$token');
      }
    } catch (e) {
      print('Error sending push notification: $e');
    }
  }
  
  // Helper to fetch minister details to enrich notifications
  Future<Map<String, dynamic>> _fetchMinisterProfile(String ministerId) async {
    try {
      final doc = await _firestore.collection('users').doc(ministerId).get();
      if (doc.exists) {
        final data = doc.data() ?? {};
        return {
          'ministerFirstName': data['firstName'] ?? '',
          'ministerLastName': data['lastName'] ?? '',
          'ministerEmail': data['email'] ?? '',
          'ministerPhone': data['phoneNumber'] ?? '',
        };
      }
    } catch (e) {
      print('Error fetching minister profile: $e');
    }
    return {
      'ministerFirstName': '',
      'ministerLastName': '',
      'ministerEmail': '',
      'ministerPhone': '',
    };
  }
  
  // Helper to generate a detailed, human-readable body for notifications
  String buildNotificationBody({
    required String notificationType,
    required Map<String, dynamic> data,
    required String role,
  }) {
    // Defensive extraction
    final ministerName = (data['ministerFirstName'] ?? '') + ' ' + (data['ministerLastName'] ?? '');
    final serviceName = data['serviceName'] ?? '';
    final venueName = data['venueName'] ?? '';
    final formattedDate = data['appointmentDate'] ?? '';
    final formattedTime = data['appointmentTimeFormatted'] ?? '';
    final duration = data['duration'] != null ? '${data['duration']} min' : '';
    final consultantName = data['consultantName'] ?? '';
    final conciergeName = data['conciergeName'] ?? '';
    final cleanerName = data['cleanerName'] ?? '';
    final status = data['status'] ?? '';
    String details = '';

    switch (notificationType) {
      case 'booking_made':
        details = 'New Appointment Request:\nMinister: $ministerName\nService: $serviceName\nVenue: $venueName\nDate: $formattedDate\nTime: $formattedTime\nDuration: $duration';
        break;
      case 'booking_assigned':
        details = 'New Appointment Assigned:\nService: $serviceName\nVenue: $venueName\nDate: $formattedDate\nTime: $formattedTime';
        if (ministerName.trim().isNotEmpty) {
          details += '\nMinister: $ministerName';
        }
        if (data['ministerPhone'] != null && data['ministerPhone'].toString().isNotEmpty) {
          details += '\nMinister Phone: ${data['ministerPhone']}';
        }
        details += '\nTap the chat icon to message the minister.';
        break;
      case 'concierge_assigned':
        details = 'New Appointment Assigned:\nService: $serviceName\nVenue: $venueName\nDate: $formattedDate\nTime: $formattedTime';
        if (ministerName.trim().isNotEmpty) {
          details += '\nMinister: $ministerName';
        }
        details += '\nYou will be responsible for greeting and escorting the minister.';
        break;
      default:
        details = 'Appointment Details:\nService: $serviceName\nVenue: $venueName\nDate: $formattedDate\nTime: $formattedTime';
        if (ministerName.trim().isNotEmpty) {
          details += '\nMinister: $ministerName';
        }
        if (consultantName.isNotEmpty) {
          details += '\nConsultant: $consultantName';
        }
        if (conciergeName.isNotEmpty) {
          details += '\nConcierge: $conciergeName';
        }
        if (status.isNotEmpty) {
          details += '\nStatus: $status';
        }
    }
    return details.trim();
  }
  
  // Create an in-app notification record in Firestore
  Future<void> createNotification({
    required String title,
    String? body,
    required Map<String, dynamic> data,
    String? userId,
    String? role,
    String? assignedToId,
    String? notificationType,
  }) async {
    try {
      final type = notificationType ?? data['notificationType'] ?? 'general';
      
      // Ensure showRating is always true for minister notifications
      if (role == 'minister') {
        data['showRating'] = true;
      }
      
      final generatedBody = body ?? buildNotificationBody(
        notificationType: type,
        data: data,
        role: role ?? '',
      );
      
      // Enrich minister data if needed
      if ((data['ministerId'] != null) &&
          ((data['ministerFirstName'] == null || data['ministerFirstName'].toString().isEmpty) ||
           (data['ministerLastName'] == null || data['ministerLastName'].toString().isEmpty))) {
        print('Minister info incomplete in notification data. Fetching from Firestore...');
        final ministerProfile = await _fetchMinisterProfile(data['ministerId'].toString());
        data.addAll(ministerProfile);
      }
      
      // Format appointment time for display
      DateTime? appointmentTime;
      if (data['appointmentTime'] != null) {
        if (data['appointmentTime'] is Timestamp) {
          appointmentTime = (data['appointmentTime'] as Timestamp).toDate();
        } else if (data['appointmentTime'] is DateTime) {
          appointmentTime = data['appointmentTime'] as DateTime;
        } else if (data['appointmentTime'] is String) {
          try {
            appointmentTime = DateTime.parse(data['appointmentTime'] as String);
          } catch (e) {
            print('Failed to parse appointment time string: $e');
          }
        }
      }
      
      // Create the notification document
      final notification = {
        'title': title,
        'body': generatedBody,
        'data': data,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
        'notificationType': type,
      };
      
      // Add target user or role
      if (assignedToId != null && assignedToId.isNotEmpty) {
        notification['assignedToId'] = assignedToId;
      } else if (userId != null && userId.isNotEmpty) {
        notification['userId'] = userId;
      } else if (role != null && role.isNotEmpty) {
        notification['role'] = role;
      }
      
      // Add appointment data if available
      if (appointmentTime != null) {
        notification['appointmentTime'] = Timestamp.fromDate(appointmentTime);
        notification['appointmentTimeISO'] = appointmentTime.toIso8601String();
        notification['appointmentDate'] = DateFormat('MMM dd, yyyy').format(appointmentTime);
        notification['appointmentTimeFormatted'] = DateFormat('HH:mm').format(appointmentTime);
      }
      
      // Store the notification in Firestore
      await _firestore.collection('notifications').add(notification);
      
      // Update unread badge count
      if (userId != null && userId.isNotEmpty) {
        await _updateUnreadBadgeCount(userId: userId);
      } else if (role != null && role.isNotEmpty) {
        await _updateUnreadBadgeCountForRole(role: role);
      }
      
      print('Notification created successfully');
    } catch (e) {
      print('Error creating notification: $e');
    }
  }
  
  // Helper method to update unread badge count for a specific user
  Future<void> _updateUnreadBadgeCount({required String userId}) async {
    try {
      final unreadQuery = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();
      
      final count = unreadQuery.docs.length;
      
      await _firestore.collection('users').doc(userId).update({
        'unreadNotifications': count
      });
      
      print('Updated unread notification count for user $userId: $count');
    } catch (e) {
      print('Error updating unread badge count: $e');
    }
  }
  
  // Helper method to update unread badge count for all users with a specific role
  Future<void> _updateUnreadBadgeCountForRole({required String role}) async {
    try {
      final usersQuery = await _firestore
          .collection('users')
          .where('role', isEqualTo: role)
          .get();
      
      for (final userDoc in usersQuery.docs) {
        final userId = userDoc.id;
        await _updateUnreadBadgeCount(userId: userId);
      }
      
      print('Updated unread notification count for all users with role: $role');
    } catch (e) {
      print('Error updating unread badge count for role: $e');
    }
  }
  
  // Send notification to all floor managers
  Future<void> sendFCMToFloorManager({
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    try {
      final floorManagerTokens = await _getFloorManagerFcmTokens();
      for (final token in floorManagerTokens) {
        await _sendPushNotification(token, title, body, data);
      }
      
      // Also create a notification record for the floor managers
      await createNotification(
        title: title,
        body: body,
        data: data,
        role: 'floor_manager'
      );
    } catch (e) {
      print('Error sending FCM to floor managers: $e');
    }
  }
  
  // Send notification to a specific user
  Future<void> sendFCMToUser({
    required String userId,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    try {
      final userToken = await _getUserFcmToken(userId);
      if (userToken != null && userToken.isNotEmpty) {
        await _sendPushNotification(userToken, title, body, data);
      }
      
      // Also create a notification record for this user
      await createNotification(
        title: title,
        body: body,
        data: data,
        userId: userId
      );
    } catch (e) {
      print('Error sending FCM to user: $e');
    }
  }
  
  // Send notification to all consultants
  Future<void> sendFCMToConsultants({
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    try {
      final consultantTokens = await _getConsultantsFcmTokens();
      for (final token in consultantTokens) {
        await _sendPushNotification(token, title, body, data);
      }
      
      // Also create notifications for all consultants
      await createNotification(
        title: title,
        body: body,
        data: data,
        role: 'consultant'
      );
    } catch (e) {
      print('Error sending FCM to consultants: $e');
    }
  }
  
  // Assign booking to staff users
  Future<void> assignBookingToUser({
    required String appointmentId,
    required Map<String, dynamic> appointmentData,
    required List<Map<String, dynamic>> assignedUsers,
    required String ministerId,
    required String ministerName,
    required String floorManagerId,
    required String floorManagerName,
  }) async {
    try {
      print('Assigning appointment $appointmentId to users');
      
      // Update appointment status in Firestore
      await _firestore.collection('appointments').doc(appointmentId).update({
        'status': 'assigned',
        'assignedUsers': assignedUsers,
        'assignedAt': FieldValue.serverTimestamp(),
      });
      
      // Update appointment data with assignment details
      final updatedAppointmentData = Map<String, dynamic>.from(appointmentData);
      updatedAppointmentData['appointmentId'] = appointmentId;
      updatedAppointmentData['status'] = 'assigned';
      updatedAppointmentData['notificationType'] = 'booking_assigned';
      
      // Notify each assigned user
      for (final userMap in assignedUsers) {
        final userId = userMap['userId'];
        final userName = userMap['userName'] ?? '';
        final userRole = userMap['userRole'] ?? '';
        
        if (userId != null) {
          // Create rich notification text
          final notificationBody = buildNotificationBody(
            notificationType: 'booking_assigned',
            data: updatedAppointmentData,
            role: userRole,
          );
          
          // Send notifications to this staff member
          await sendFCMToUser(
            userId: userId,
            title: 'New Appointment Assigned',
            body: notificationBody,
            data: updatedAppointmentData,
          );
        }
      }
      
      // Notify the minister about assignment
      await sendFCMToUser(
        userId: ministerId,
        title: 'Your Appointment Has Been Assigned',
        body: 'Your appointment has been assigned to our staff. They will be ready to assist you.',
        data: updatedAppointmentData,
      );
      
      // Notify floor manager
      await sendFCMToUser(
        userId: floorManagerId,
        title: 'Booking Assignment Complete',
        body: 'Appointment ${appointmentData['serviceName']} has been successfully assigned to staff.',
        data: updatedAppointmentData,
      );
      
      print('Appointment assignments completed successfully');
    } catch (e) {
      print('Error assigning booking: $e');
    }
  }
  
  // Send rating request notification to minister
  Future<void> sendRatingRequestToMinister({
    required String appointmentId,
    required String consultantId,
    required String consultantName,
    required String ministerId,
  }) async {
    try {
      print('Sending rating request to minister: $ministerId for consultant: $consultantName');
      
      // Get appointment details
      final appointmentDoc = await _firestore.collection('appointments').doc(appointmentId).get();
      if (!appointmentDoc.exists) {
        throw Exception('Appointment not found: $appointmentId');
      }
      
      final appointmentData = appointmentDoc.data()!;
      
      // Create notification data
      final notificationData = {
        'appointmentId': appointmentId,
        'consultantId': consultantId,
        'consultantName': consultantName,
        'ministerId': ministerId,
        'isRatingRequest': true,
        ...appointmentData,
      };
      
      // Create in-app notification for minister
      await createNotification(
        title: 'Rate Your Experience',
        body: 'Please rate your experience with $consultantName for your ${appointmentData['serviceName'] ?? 'appointment'}.',
        data: notificationData,
        userId: ministerId,
        notificationType: 'rating_request',
      );
      
      // Send FCM to minister
      await sendFCMToUser(
        userId: ministerId,
        title: 'Rate Your Experience',
        body: 'Please rate your experience with $consultantName for your ${appointmentData['serviceName'] ?? 'appointment'}.',
        data: notificationData,
      );
      
      // Update appointment to indicate rating was requested
      await _firestore.collection('appointments').doc(appointmentId).update({
        'ratingRequested': true,
        'ratingRequestedAt': FieldValue.serverTimestamp(),
      });
      
      print('Rating request sent successfully to minister: $ministerId');
    } catch (e) {
      print('Error sending rating request: $e');
    }
  }
}
