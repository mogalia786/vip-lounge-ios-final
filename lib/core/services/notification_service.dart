import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

  Future<void> sendFCMToFloorManager({
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    try {
      print('Sending FCM to floor managers:');
      print('Title: $title');
      print('Body: $body');
      print('Data: $data');

      // Get all floor manager tokens
      final floorManagerTokens = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'floor_manager')
          .get();

      print('Found ${floorManagerTokens.docs.length} floor managers');

      for (var doc in floorManagerTokens.docs) {
        final token = doc.data()['fcmToken'];
        if (token != null && token.toString().isNotEmpty) {
          print('Floor manager token found: $token');
          
          // In a real app, we would call a Cloud Function or server endpoint here
          // that would use the Firebase Admin SDK to send an FCM message.
          // For now, we'll use Firestore to create the notification
          // document which will trigger the bottom nav bar notification
          // and rely on FCM configuration in firebase_messaging.dart
          
          // Create a notification in the notifications collection
          await _firestore.collection('notifications').add({
            'title': title,
            'body': body,
            'data': data,
            'role': 'floor_manager',
            'assignedToId': doc.id,
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
            'notificationType': 'appointment_request',
          });
          
          print('Notification created for floor manager: ${doc.id}');
        } else {
          print('No FCM token found for floor manager: ${doc.id}');
        }
      }
    } catch (e) {
      print('Error sending FCM: $e');
      throw e;
    }
  }

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
        if (data['ministerPhone'] != null && data['ministerPhone'].toString().isNotEmpty) {
          details += '\nMinister Phone: ${data['ministerPhone']}';
        }
        details += '\nTap the chat icon to message the minister.';
        break;
      case 'minister_arrived':
        details = 'Minister $ministerName has arrived for $serviceName at $venueName.\nTime: $formattedTime';
        break;
      case 'session_started':
        details = 'Session started for $ministerName.\nService: $serviceName\nVenue: $venueName\nConsultant: $consultantName\nTime: $formattedTime';
        break;
      case 'session_completed':
        details = 'Session completed for $ministerName.\nService: $serviceName\nVenue: $venueName\nConsultant: $consultantName';
        break;
      case 'cleaning_assigned':
        details = 'You have been assigned to clean $venueName after $ministerName\'s session.';
        break;
      case 'cleaning_completed':
        details = 'Cleaning completed for $venueName after $ministerName\'s session.';
        break;
      default:
        details = 'Appointment for $ministerName\nService: $serviceName\nVenue: $venueName\nDate: $formattedDate\nTime: $formattedTime';
    }

    // Add staff info for consultant/concierge/cleaner roles
    if (role == 'consultant') {
      details += '\nAssigned by: ${data['assignedBy'] ?? ''}';
    } else if (role == 'concierge') {
      details += '\nAssigned by: ${data['assignedBy'] ?? ''}';
    } else if (role == 'cleaner') {
      details += '\nAssigned by: ${data['assignedBy'] ?? ''}';
    }
    return details.trim();
  }

  Future<void> createNotification({
    required String title,
    String? body,
    required Map<String, dynamic> data,
    required String role,
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
        role: role,
      );
      print('Creating notification with data:');
      print('Title: $title');
      print('Body: $generatedBody');
      print('Role: $role');
      print('AssignedToId: $assignedToId');
      print('Data: $data');

      // Defensive: Enrich missing minister fields if possible
      if ((data['ministerId'] != null) &&
          ((data['ministerFirstName'] == null || data['ministerFirstName'].toString().isEmpty) ||
           (data['ministerLastName'] == null || data['ministerLastName'].toString().isEmpty) ||
           (data['ministerEmail'] == null || data['ministerEmail'].toString().isEmpty) ||
           (data['ministerPhone'] == null || data['ministerPhone'].toString().isEmpty))) {
        print('Minister info incomplete in notification data. Fetching from Firestore...');
        final ministerProfile = await _fetchMinisterProfile(data['ministerId']);
        data['ministerFirstName'] ??= ministerProfile['ministerFirstName'];
        data['ministerLastName'] ??= ministerProfile['ministerLastName'];
        data['ministerEmail'] ??= ministerProfile['ministerEmail'];
        data['ministerPhone'] ??= ministerProfile['ministerPhone'];
      }

      // Handle different types of appointmentTime
      DateTime appointmentTime;
      if (data['appointmentTime'] is Timestamp) {
        appointmentTime = (data['appointmentTime'] as Timestamp).toDate();
      } else if (data['appointmentTime'] is String) {
        appointmentTime = DateTime.parse(data['appointmentTime']);
      } else if (data['appointmentTimeISO'] != null && data['appointmentTimeISO'] is String) {
        // Fall back to ISO string if provided
        appointmentTime = DateTime.parse(data['appointmentTimeISO']);
      } else {
        // Default to current time if parsing fails
        print('Warning: Could not parse appointment time, using current time');
        appointmentTime = DateTime.now();
      }
      
      final formattedDate = DateFormat('EEEE, MMMM d, y').format(appointmentTime);
      final formattedTime = DateFormat('h:mm a').format(appointmentTime);

      final notificationData = {
        'title': title,
        'body': generatedBody,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'role': role,
        'assignedToId': assignedToId,
        'notificationType': type,
        'appointmentId': data['appointmentId'],
        'ministerId': data['ministerId'],
        'ministerFirstName': data['ministerFirstName'],
        'ministerLastName': data['ministerLastName'],
        'ministerEmail': data['ministerEmail'],
        'ministerPhone': data['ministerPhone'],
        'serviceId': data['serviceId'],
        'serviceName': data['serviceName'],
        'serviceCategory': data['serviceCategory'],
        'subServiceName': data['subServiceName'],
        'venueId': data['venueId'],
        'venueName': data['venueName'],
        'consultantName': data['consultantName'],
        'conciergeName': data['conciergeName'],
        'cleanerName': data['cleanerName'],
        // Store the appointment time consistently as a Timestamp for Firestore
        'appointmentTime': Timestamp.fromDate(appointmentTime),
        // Also store as ISO string for easy access
        'appointmentTimeISO': appointmentTime.toIso8601String(),
        'appointmentDate': formattedDate,
        'appointmentTimeFormatted': formattedTime,
        'duration': data['duration'],
        'status': data['status'] ?? 'pending',
        'sendAsPushNotification': true,
      };

      print('Writing notification to Firestore: $notificationData');

      final docRef = await _firestore.collection('notifications').add(notificationData);
      print('Successfully created notification with ID: ${docRef.id}');

    } catch (e) {
      print('Error creating notification: $e');
      throw e;
    }
  }

  Future<void> assignBookingToUser({
    required String appointmentId,
    required Map<String, dynamic> appointmentData,
    required List<Map<String, dynamic>> assignedUsers,
    required String ministerId,
    required String ministerName,
    required String floorManagerId,
    required String floorManagerName,
  }) async {
    // Debug: Print all appointmentData and assignedUsers
    print('[DEBUG] assignBookingToUser called');
    print('[DEBUG] appointmentData: ' + appointmentData.toString());
    print('[DEBUG] assignedUsers: ' + assignedUsers.toString());
    print('[DEBUG] ministerId: $ministerId, ministerName: $ministerName');
    print('[DEBUG] floorManagerId: $floorManagerId, floorManagerName: $floorManagerName');

    // Defensive: Ensure all fields in appointmentData are safe
    appointmentData.forEach((k, v) {
      if (v == null) {
        print('[ERROR] appointmentData field $k is null!');
        appointmentData[k] = '';
      } else if (v is! String && v is! int && v is! bool && v is! Map && v is! List) {
        print('[ERROR] appointmentData field $k is not a valid Firestore type: $v (${v.runtimeType})');
        appointmentData[k] = v.toString();
      }
    });

    // Defensive: Ensure all assignedUsers fields are safe
    for (int i = 0; i < assignedUsers.length; i++) {
      assignedUsers[i].forEach((k, v) {
        if (v == null) {
          print('[ERROR] assignedUsers[$i] field $k is null!');
          assignedUsers[i][k] = '';
        } else if (v is! String && v is! int && v is! bool && v is! Map && v is! List) {
          print('[ERROR] assignedUsers[$i] field $k is not a valid Firestore type: $v (${v.runtimeType})');
          assignedUsers[i][k] = v.toString();
        }
      });
    }

    // Notification payloads
    Map<String, dynamic> ministerNotification = {
      'to': ministerId,
      'title': 'Appointment Assigned',
      'body': 'Dear $ministerName, your appointment has been assigned.',
      'appointmentId': appointmentId,
      'notificationType': 'assignment',
    };
    Map<String, dynamic> floorManagerNotification = {
      'to': floorManagerId,
      'title': 'Assignment Complete',
      'body': 'You have assigned staff to appointment for $ministerName.',
      'appointmentId': appointmentId,
      'notificationType': 'assignment',
    };
    print('[DEBUG] ministerNotification: ' + ministerNotification.toString());
    print('[DEBUG] floorManagerNotification: ' + floorManagerNotification.toString());

    // Defensive: Ensure all notification payloads are safe
    for (var notif in [ministerNotification, floorManagerNotification]) {
      notif.forEach((k, v) {
        if (v == null) {
          print('[ERROR] notification payload field $k is null!');
          notif[k] = '';
        } else if (v is! String && v is! int && v is! bool && v is! Map && v is! List) {
          print('[ERROR] notification payload field $k is not a valid Firestore/FCM type: $v (${v.runtimeType})');
          notif[k] = v.toString();
        }
      });
    }

    // Get the appointment document to ensure it exists
    final appointmentDoc = await _firestore.collection('appointments').doc(appointmentId).get();
    if (!appointmentDoc.exists) {
      throw Exception('Appointment not found: $appointmentId');
    }

    // Get the user document to ensure it exists
    final userDoc = await _firestore.collection('users').doc(floorManagerId).get();
    if (!userDoc.exists) {
      throw Exception('User not found: $floorManagerId');
    }

    // Support multi-role assignment (consultant, concierge, cleaner)
    Map<String, dynamic> updateFields = {'status': 'assigned'};
    for (int i = 0; i < assignedUsers.length; i++) {
      final assignedUser = assignedUsers[i];
      if (assignedUser['assignRole'] == 'consultant') {
        updateFields['assignedConsultantId'] = assignedUser['userId'];
        updateFields['assignedConsultantName'] = assignedUser['userName'];
      } else if (assignedUser['assignRole'] == 'concierge') {
        updateFields['assignedConciergeId'] = assignedUser['userId'];
        updateFields['assignedConciergeName'] = assignedUser['userName'];
      } else if (assignedUser['assignRole'] == 'cleaner') {
        updateFields['assignedCleanerId'] = assignedUser['userId'];
        updateFields['assignedCleanerName'] = assignedUser['userName'];
      }
    }

    print('[DEBUG] assignBookingToUser: updateFields = ' + updateFields.toString());

    // Debug: Print all updateFields and their types before updating Firestore
    updateFields.forEach((k, v) {
      print('[DEBUG] updateFields: $k = $v (type: ${v.runtimeType})');
    });
    // Defensive: Throw if any assigned*Id or assigned*Name is null or not String
    for (var key in updateFields.keys) {
      if ((key.endsWith('Id') || key.endsWith('Name')) && updateFields[key] != null && updateFields[key] is! String) {
        throw Exception('Field $key is not a String: value=${updateFields[key]}, type=${updateFields[key].runtimeType}');
      }
    }
    await _firestore.collection('appointments').doc(appointmentId).update(updateFields);

    // Update appointment data with assignment details
    final updatedAppointmentData = Map<String, dynamic>.from(appointmentData);
    updatedAppointmentData['appointmentId'] = appointmentId;
    updatedAppointmentData['status'] = 'assigned';

    print('Creating notification with data: $updatedAppointmentData');

    // Create notifications for each assigned staff
    for (int i = 0; i < assignedUsers.length; i++) {
      final assignedUser = assignedUsers[i];
      await createNotification(
        title: 'New Appointment Assigned',
        body: 'You have been assigned to assist Minister ${updatedAppointmentData['ministerFirstName'] ?? 'Unknown'} ${updatedAppointmentData['ministerLastName'] ?? ''}',
        data: updatedAppointmentData,
        role: assignedUser['assignRole'],
        assignedToId: assignedUser['userId'],
      );
    }

    // Create notification for minister about consultant assignment
    await createNotification(
      title: 'Consultant Assigned',
      body: 'Your appointment has been assigned to staff.',
      data: updatedAppointmentData,
      role: 'minister',
      assignedToId: ministerId,
    );

    // Send FCM to assigned user
    final token = userDoc.data()?['fcmToken'];
    if (token != null) {
      await _fcm.sendMessage(
        to: token,
        data: _convertToStringMap(updatedAppointmentData),
        messageId: 'appointment_assigned_${appointmentId}',
        messageType: 'appointment_assigned',
        collapseKey: 'appointment_${appointmentId}',
      );
    }

    // Send FCM to minister
    final ministerDoc = await _firestore.collection('users').doc(ministerId).get();
    final ministerToken = ministerDoc.data()?['fcmToken'];
    if (ministerToken != null) {
      await _fcm.sendMessage(
        to: ministerToken,
        data: _convertToStringMap(updatedAppointmentData),
        messageId: 'consultant_assigned_${appointmentId}',
        messageType: 'consultant_assigned',
        collapseKey: 'appointment_${appointmentId}',
      );
    }

    // Send FCM to concierge
    final conciergeDocs = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'concierge')
        .get();

    for (var doc in conciergeDocs.docs) {
      final conciergeToken = doc.data()['fcmToken'];
      if (conciergeToken != null) {
        await _fcm.sendMessage(
          to: conciergeToken,
          data: _convertToStringMap(updatedAppointmentData),
          messageId: 'appointment_concierge_${appointmentId}',
          messageType: 'appointment_concierge',
          collapseKey: 'appointment_${appointmentId}',
        );
      }
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
        body: 'Please rate your experience with $consultantName',
        data: notificationData,
        role: 'minister',
        assignedToId: ministerId,
      );
      
      // Send FCM to minister
      final ministerDoc = await _firestore.collection('users').doc(ministerId).get();
      final ministerToken = ministerDoc.data()?['fcmToken'];
      if (ministerToken != null) {
        await _fcm.sendMessage(
          to: ministerToken,
          data: _convertToStringMap(notificationData),
          messageId: 'rating_request_${appointmentId}',
          messageType: 'rating_request',
          collapseKey: 'rating_${appointmentId}',
        );
      }
      
      // Update appointment to indicate rating was requested
      await _firestore.collection('appointments').doc(appointmentId).update({
        'ratingRequested': true,
        'ratingRequestedAt': FieldValue.serverTimestamp(),
      });
      
      print('Rating request sent successfully to minister: $ministerId');
      
    } catch (e) {
      print('Error sending rating request: $e');
      throw e;
    }
  }
}
