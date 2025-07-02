import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

/// Enhanced notification service that implements the complete notification flow process
/// for the VIP lounge booking system, ensuring all stakeholders receive appropriate
/// notifications at each stage of the booking process.
class VipNotificationService {
  // Debug log file path
  static const String debugLogFilePath = 'debugs/notification_debug_log.txt';

  /// Append a debug log entry to the notification debug log file
  Future<void> logNotificationDebug({
    required String trigger,
    required String eventType,
    required String recipient,
    required String body,
    required bool localSuccess,
    required bool fcmSuccess,
    String? error,
  }) async {
    try {
      final now = DateTime.now().toIso8601String();
      final logLine = '[${now}] TRIGGER: $trigger | EVENT: $eventType | TO: $recipient | BODY: $body | LOCAL: ${localSuccess ? 'success' : 'fail'} | FCM: ${fcmSuccess ? 'success' : 'fail'}${error != null ? ' | ERROR: $error' : ''}\n';
      final logFile = File(debugLogFilePath);
      await logFile.writeAsString(logLine, mode: FileMode.append, flush: true);
    } catch (e) {
      // If logging fails, print to console
      print('[DEBUG LOGGING ERROR] $e');
    }
  }

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Convert map values to strings for FCM compatibility
  Map<String, String> convertToStringMap(Map<String, dynamic> data) {
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

  /// Creates a notification in the notifications collection for a specific user or role
  Future<void> createNotification({
    required String title,
    required String body,
    required Map<String, dynamic> data,
    required String role,
    String? assignedToId,
    String? notificationType,
  }) async {
    print('[NOTIF][DEBUG][START] createNotification called');
    print('[NOTIF][DEBUG] Title: $title');
    print('[NOTIF][DEBUG] Body: $body');
    print('[NOTIF][DEBUG] Role: $role');
    print('[NOTIF][DEBUG] AssignedToId: $assignedToId');
    print('[NOTIF][DEBUG] NotificationType: $notificationType');
    print('[NOTIF][DEBUG] Data: $data');
    print('[NOTIF] createNotification called with title: $title, role: $role, assignedToId: $assignedToId');
    // Defensive: do not create notification if assignedToId is present but empty
    if (assignedToId != null && assignedToId.isEmpty) {
      print('[ERROR] createNotification: assignedToId is empty, aborting notification creation.');
      return;
    }
    try {
      // Fetch appointment and minister/user info if appointmentId is present and not already included
      Map<String, dynamic> enrichedData = Map<String, dynamic>.from(data);
// Always default showRating to true for VIP rating on every step
if (!enrichedData.containsKey('showRating')) {
  enrichedData['showRating'] = true;
}
      // Always ensure appointmentId is present and correct
      final appointmentId = data['appointmentId'] ?? data['id'];
      if (appointmentId != null && appointmentId.toString().isNotEmpty) {
        enrichedData['appointmentId'] = appointmentId.toString();
      }
      // Always join users collection for assignedToId to get contact info
      if (assignedToId != null && assignedToId.isNotEmpty) {
        final userDoc = await _firestore.collection('users').doc(assignedToId).get();
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          enrichedData['userPhone'] = userData['phone'] ?? userData['phoneNumber'] ?? '';
          enrichedData['userEmail'] = userData['email'] ?? '';
        }
      }
      if (appointmentId != null && (data['serviceName'] == null || data['ministerName'] == null)) {
        // Get appointment details
        final appointmentDoc = await _firestore.collection('appointments').doc(appointmentId).get();
        if (appointmentDoc.exists) {
          final appointmentData = appointmentDoc.data()!;
          enrichedData.addAll({
            'serviceName': appointmentData['serviceName'],
            'venueName': appointmentData['venueName'],
            'appointmentTime': appointmentData['appointmentTime'],
            'status': appointmentData['status'],
            'ministerId': appointmentData['ministerId'],
          });
          // Get minister info if not present
          if (appointmentData['ministerId'] != null && (data['ministerName'] == null || data['ministerFirstName'] == null)) {
            final ministerDoc = await _firestore.collection('users').doc(appointmentData['ministerId']).get();
            if (ministerDoc.exists) {
              final ministerData = ministerDoc.data()!;
              enrichedData.addAll({
                'ministerName': ministerData['name'] ?? '',
                'ministerFirstName': ministerData['firstName'] ?? '',
                'ministerLastName': ministerData['lastName'] ?? '',
                'ministerPhone': ministerData['phone'] ?? '',
                'ministerEmail': ministerData['email'] ?? '',
              });
            }
          }
        }
      }
      // Ensure showRating is always true for minister notifications
      if (role == 'minister') {
        enrichedData['showRating'] = true;
      }
      final notificationData = {
        'title': title,
        'body': body,
        'data': enrichedData,
        'role': role,
        'assignedToId': assignedToId,
        'notificationType': notificationType ?? 'general',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'timestamp': FieldValue.serverTimestamp(), // Always set timestamp for sorting
        // For minister notifications, ensure phone, date, and message body are present at top level
        if (role == 'minister') ...{
          'phone': enrichedData['ministerPhone'] ?? '',
          'fullBody': body,
          'notificationDate': DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
        },
      };
      print('[NOTIF] Writing notification to Firestore: ' + notificationData.toString());
      // Also ensure phone is in data for UI
      if (role == 'minister') {
        notificationData['data']['ministerPhone'] = enrichedData['ministerPhone'] ?? '';
      }
      if (role == 'consultant' || role == 'concierge' || role == 'cleaner') {
        notificationData['staffId'] = assignedToId;
      }
      // Remove any null or empty fields for cleanliness
      notificationData.removeWhere((k, v) => v == null);
      await _firestore.collection('notifications').add(notificationData);
      print('[NOTIF] Notification successfully written to Firestore');
      // Send FCM push notification if assignedToId is present
      if (assignedToId != null && assignedToId.isNotEmpty) {
        await sendFCMToUser(
          userId: assignedToId,
          title: title,
          body: 'Please rate my service.',
          data: convertToStringMap(enrichedData),
          messageType: notificationType ?? 'general',
        );
      }
    } catch (e) {
      print('Error in createNotification: $e');
      throw e;
    }
  }

  /// Sends FCM to a specific user
  Future<void> sendFCMToUser({
    required String userId,
    required String title,
    required String body,
    required Map<String, dynamic> data,
    required String messageType,
  }) async {
    print('[FCM][DEBUG][START] sendFCMToUser called');
    print('[FCM][DEBUG] User ID: $userId');
    print('[FCM][DEBUG] Title: $title');
    print('[FCM][DEBUG] Body: $body');
    print('[FCM][DEBUG] Message Type: $messageType');
    print('[FCM][DEBUG] Data: $data');
    if (userId.isEmpty) {
      print('[FCM] ERROR: userId is empty, cannot send FCM.');
      return;
    }
    try {
      // Before using the path in Firestore, print it for debugging
      print('[DEBUG] Firestore document path: users/$userId');
      print('[FCM][DEBUG] Fetching user document for ID: $userId');
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        print('[FCM][ERROR] User document does not exist for ID: $userId');
        return;
      }
      final token = userDoc.data()?['fcmToken'];
      print('[FCM][DEBUG] FCM Token found: ${token != null && token.isNotEmpty ? 'YES' : 'NO'}');
      if (token == null || token.isEmpty) {
        print('[FCM][ERROR] No FCM token found for user ID: $userId');
        print('[FCM][DEBUG] User document data: ${userDoc.data()}');
      }

      print('[FCM] Preparing to send FCM to user: $userId');
      print('[FCM] Title: $title');
      print('[FCM] Body: $body');
      print('[FCM] Data: $data');
      print('[FCM] MessageType: $messageType');

      if (token != null && token.toString().isNotEmpty) {
        // Use your deployed Cloud Function endpoint
        final url = Uri.parse('https://us-central1-vip-lounge-f3730.cloudfunctions.net/sendNotification');

        final payload = {
          'token': token,
          'title': title,
          'body': body,
          'data': data,
          'messageType': messageType,
        };

        print('[FCM][DEBUG] Sending FCM request to: $url');
        print('[FCM][DEBUG] Payload: $payload');
        
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        );

        print('[FCM][DEBUG] HTTP Response Status: ${response.statusCode}');
        print('[FCM][DEBUG] HTTP Response Body: ${response.body}');

        if (response.statusCode == 200) {
          print('[FCM][SUCCESS] Push notification sent to user $userId: "$title"');
        } else {
          print('[FCM][ERROR] Failed to send push notification. Status: ${response.statusCode}');
          print('[FCM][DEBUG] Response: ${response.body}');
          print('[FCM] Failed to send push notification: ${response.body}');
        }
      } else {
        print('[FCM] No FCM token found for user $userId');
      }
    } catch (e) {
      print('[FCM] Error sending FCM to user: $e');
    }
  }

  /// 1. BOOKING CREATION: Minister creates booking, notification sent to floor manager
  Future<void> notifyBookingCreation({
    required String appointmentId,
    required Map<String, dynamic> appointmentData,
  }) async {
    if (appointmentId.isEmpty) {
      print('[ERROR] notifyBookingCreation: appointmentId is empty, aborting notification send.');
      return;
    }
    try {
      // Ensure we have complete minister information
      final ministerData = await _getMinisterDetails(appointmentData['ministerId']);
      
      // Format date and time for readability in notifications
      final appointmentTime = appointmentData['appointmentTime'] is Timestamp
          ? (appointmentData['appointmentTime'] as Timestamp).toDate()
          : DateTime.now();
      final formattedDateTime = DateFormat('EEEE, MMMM d, y, h:mm a').format(appointmentTime);
      final serviceName = appointmentData['serviceName'] ?? 'Unknown Service';
      
      // Make sure we have all appointment details
      final fullAppointmentData = {
        ...appointmentData,
        'id': appointmentId,
        'ministerPhone': ministerData['phone'] ?? '',
        'ministerEmail': ministerData['email'] ?? '',
        'ministerFirstName': ministerData['firstName'] ?? '',
        'ministerLastName': ministerData['lastName'] ?? '',
      };
      
      // Add phone numbers to notification data
      final consultantPhone = appointmentData['consultantPhone'] ?? '';
      final conciergePhone = appointmentData['conciergePhone'] ?? '';
      
      // 1. Notify Consultant
      final consultant = appointmentData['staff'] != null && appointmentData['staff']['consultant'] != null
          ? appointmentData['staff']['consultant']
          : null;
      if (consultant != null && consultant['id'] != null && consultant['id'].toString().isNotEmpty) {
        final consultantId = consultant['id'];
        final consultantName = consultant['name'] ?? '';
        await createNotification(
          title: 'New Appointment Assigned',
          body: 'You have been assigned to a new appointment. Minister: ${fullAppointmentData['ministerFirstName']} ${fullAppointmentData['ministerLastName']}, Venue: ${fullAppointmentData['venueName']}, Time: $formattedDateTime.',
          data: {
            ...fullAppointmentData,
            'appointmentId': appointmentId,
            'notificationType': 'booking_assigned',
            'consultantPhone': consultantPhone,
            'conciergePhone': conciergePhone,
          },
          role: 'consultant',
          assignedToId: consultantId,
          notificationType: 'booking_assigned',
        );
        print('[DEBUG] Consultant notification written to Firestore');
        await sendFCMToUser(
          userId: consultantId,
          title: 'New Appointment Assigned',
          body: 'You have been assigned to a new appointment. Minister: ${fullAppointmentData['ministerFirstName']} ${fullAppointmentData['ministerLastName']}, Venue: ${fullAppointmentData['venueName']}, Time: $formattedDateTime.',
          data: convertToStringMap({
            ...fullAppointmentData,
            'appointmentId': appointmentId,
            'notificationType': 'booking_assigned',
            'consultantPhone': consultantPhone,
            'conciergePhone': conciergePhone,
          }),
          messageType: 'booking_assigned',
        );
        print('[DEBUG] After sending FCM to consultantId: $consultantId');
      }
      
      // 2. Notify Concierge
      final concierge = appointmentData['staff'] != null && appointmentData['staff']['concierge'] != null
          ? appointmentData['staff']['concierge']
          : null;
      if (concierge != null && concierge['id'] != null && concierge['id'].toString().isNotEmpty) {
        final conciergeId = concierge['id'];
        final conciergeName = concierge['name'] ?? '';
        await createNotification(
          title: 'New Appointment Assigned',
          body: 'You have been assigned to receive Minister ${fullAppointmentData['ministerFirstName']} ${fullAppointmentData['ministerLastName']} on $formattedDateTime. Consultant: ${consultant != null ? (consultant['name'] ?? '') : ''}, Phone: $consultantPhone',
          data: {
            ...fullAppointmentData,
            'appointmentId': appointmentId,
            'notificationType': 'booking_assigned',
            'consultantPhone': consultantPhone,
            'conciergePhone': conciergePhone,
          },
          role: 'concierge',
          assignedToId: conciergeId,
          notificationType: 'booking_assigned',
        );
        await sendFCMToUser(
          userId: conciergeId,
          title: 'New Appointment Assigned',
          body: 'You have been assigned to receive Minister ${fullAppointmentData['ministerFirstName']} ${fullAppointmentData['ministerLastName']} on $formattedDateTime. Consultant: ${consultant != null ? (consultant['name'] ?? '') : ''}, Phone: $consultantPhone',
          data: convertToStringMap({
            ...fullAppointmentData,
            'appointmentId': appointmentId,
            'notificationType': 'booking_assigned',
            'consultantPhone': consultantPhone,
            'conciergePhone': conciergePhone,
          }),
          messageType: 'booking_assigned',
        );
        print('[DEBUG] After sending FCM to conciergeId: $conciergeId');
      }
      
      // 3. Notify Cleaner if assigned
      final cleaner = appointmentData['staff'] != null && appointmentData['staff']['cleaner'] != null
          ? appointmentData['staff']['cleaner']
          : null;
      if (cleaner != null && cleaner['id'] != null && cleaner['id'].toString().isNotEmpty) {
        final cleanerId = cleaner['id'];
        final cleanerName = cleaner['name'] ?? '';
        await createNotification(
          title: 'New Appointment Assigned',
          body: "You have been assigned to prepare the venue for Minister "+
                "${fullAppointmentData['ministerFirstName']} ${fullAppointmentData['ministerLastName']}'s appointment on $formattedDateTime",
          data: fullAppointmentData,
          role: 'cleaner',
          assignedToId: cleanerId,
          notificationType: 'booking_assigned',
        );
        
        await sendFCMToUser(
          userId: cleanerId,
          title: 'New Appointment Assigned',
          body: "You have been assigned to prepare the venue for Minister "+
                "${fullAppointmentData['ministerFirstName']} ${fullAppointmentData['ministerLastName']}'s appointment on $formattedDateTime",
          data: convertToStringMap(fullAppointmentData),
          messageType: 'booking_assigned',
        );
        print('[DEBUG] After sending FCM to cleanerId: $cleanerId');
      }
      
      // 4. Notify Minister about staff assignment (if any staff assigned)
      String assignedConsultant = consultant != null && consultant['name'] != null ? consultant['name'] : '';
      String assignedConcierge = concierge != null && concierge['name'] != null ? concierge['name'] : '';
      if (assignedConsultant.isNotEmpty || assignedConcierge.isNotEmpty) {
        await createNotification(
          title: 'Staff Assigned to Your Appointment',
          body: 'Your appointment on $formattedDateTime has been assigned to ' +
            (assignedConsultant.isNotEmpty ? '$assignedConsultant (Consultant)' : '') +
            (assignedConsultant.isNotEmpty && assignedConcierge.isNotEmpty ? ' and ' : '') +
            (assignedConcierge.isNotEmpty ? '$assignedConcierge (Concierge)' : ''),
          data: fullAppointmentData,
          role: 'minister',
          assignedToId: appointmentData['ministerId'],
          notificationType: 'staff_assigned',
        );
      }
      
      // Send FCM push notification to minister
      await sendFCMToUser(
        userId: appointmentData['ministerId'],
        title: 'Staff Assigned to Your Appointment',
        body: 'Your appointment on $formattedDateTime has been assigned to ' +
          (assignedConsultant.isNotEmpty ? '$assignedConsultant (Consultant)' : '') +
          (assignedConsultant.isNotEmpty && assignedConcierge.isNotEmpty ? ' and ' : '') +
          (assignedConcierge.isNotEmpty ? '$assignedConcierge (Concierge)' : ''),
        data: convertToStringMap(fullAppointmentData),
        messageType: 'staff_assigned',
      );
      
      // 5. Notify floor manager (assignment summary)
      final floorManagersQuery = await _firestore.collection('users').where('role', isEqualTo: 'floor_manager').get();
      for (var doc in floorManagersQuery.docs) {
        final floorManagerId = doc.id;
        await createNotification(
          title: 'Staff Assignment Successful',
          body:
              'You assigned consultant ' +
              (assignedConsultant.isNotEmpty ? assignedConsultant : 'Not assigned') +
              ' and concierge ' +
              (assignedConcierge.isNotEmpty ? assignedConcierge : 'Not assigned') +
              ' to appointment $appointmentId.\nService: ${fullAppointmentData['serviceName']}\nVenue: ${fullAppointmentData['venueName']}\nDate: $formattedDateTime\nMinister: ${fullAppointmentData['ministerFirstName']} ${fullAppointmentData['ministerLastName']}\nDuration: ${fullAppointmentData['duration'] ?? ''} min',
          data: {
            ...fullAppointmentData,
          },
          role: 'floor_manager',
          assignedToId: floorManagerId,
          notificationType: 'staff_assigned',
        );
      }
    } catch (e) {
      print('Error sending staff assignment notifications: $e');
      throw e;
    }
  }

  /// 3. ASSIGNMENT FLOW: Floor manager assigns booking to staff members
  Future<void> notifyBookingAssignment({
    required String appointmentId,
    required Map<String, dynamic> appointmentData,
    required Map<String, String> assignedStaff, // Map of role -> userId
  }) async {
    if (appointmentId.isEmpty) {
      print('[ERROR] notifyBookingAssignment: appointmentId is empty, aborting notification send.');
      return;
    }
    try {
      // Get the minister's full details to include in notifications
      final ministerDetails = await _getMinisterDetails(appointmentData['ministerId']);
      final ministerName = ministerDetails['name'] ?? 
                          '${ministerDetails['firstName'] ?? 'Unknown'} ${ministerDetails['lastName'] ?? 'Minister'}';
      
      // Format appointment time for readable display
      final appointmentTimestamp = appointmentData['appointmentTime'] as Timestamp?;
      final appointmentTime = appointmentTimestamp?.toDate() ?? DateTime.now();
      final formattedDate = DateFormat('EEEE, MMMM d').format(appointmentTime);
      final formattedTime = DateFormat('h:mm a').format(appointmentTime);
      final serviceName = appointmentData['serviceName'] ?? 'Unknown Service';
      
      // Create enhanced appointment data with minister contact info
      final enhancedAppointmentData = {
        ...appointmentData,
        'id': appointmentId,
        'formattedDate': formattedDate,
        'formattedTime': formattedTime,
        'ministerName': ministerName,
        'ministerPhone': ministerDetails['phone'] ?? 'Not provided',
        'ministerEmail': ministerDetails['email'] ?? 'Not provided',
        'ministerDetails': ministerDetails,
      };
      
      // 1. Notify each assigned staff member with complete booking details
      for (var entry in assignedStaff.entries) {
        final role = entry.key;
        final staffId = entry.value;
        
        if (staffId.isEmpty) continue;
        
        // Get staff name from the appointment data or use a default
        final staffRole = _getRoleTitle(role);
        final staffName = appointmentData['${role}Name'] ?? staffRole;
        
        // Create notification in Firestore
        await createNotification(
          title: 'New Appointment Assignment',
          body: 'You have been assigned to $ministerName\'s $formattedDate $formattedTime ${appointmentData['serviceName'] ?? 'appointment'}',
          data: {
            ...enhancedAppointmentData,
            'assignmentTime': FieldValue.serverTimestamp(),
            'staffRole': role,
          },
          role: role,
          assignedToId: staffId,
          notificationType: 'assignment',
        );
        
        // Send FCM notification
        await sendFCMToUser(
          userId: staffId,
          title: 'New Appointment Assignment',
          body: 'You have been assigned to $ministerName\'s $formattedDate $formattedTime ${appointmentData['serviceName'] ?? 'appointment'}',
          data: convertToStringMap({
            ...enhancedAppointmentData,
            'type': 'assignment',
            'staffRole': role,
          }),
          messageType: 'assignment',
        );
      }
      
      // 2. Send confirmation notification back to the minister
      await createNotification(
        title: 'Staff Assigned to Your Appointment',
        body:
            'Your ${appointmentData['serviceName'] ?? 'appointment'} on $formattedDate at $formattedTime has been assigned.\nConsultant:  ${appointmentData['consultantName'] ?? 'Not assigned'}\nConcierge:  ${appointmentData['conciergeName'] ?? 'Not assigned'}\nTap the consultant/concierge phone number to call, or tap the chat icon to message.',
        data: {
          ...enhancedAppointmentData,
          'assignmentTime': FieldValue.serverTimestamp(),
          'consultantId': assignedStaff['consultant'],
          'consultantName': appointmentData['consultantName'] ?? '',
          'consultantPhone': appointmentData['consultantPhone'] ?? '',
          'consultantEmail': appointmentData['consultantEmail'] ?? '',
          'conciergeId': assignedStaff['concierge'],
          'conciergeName': appointmentData['conciergeName'] ?? '',
          'conciergePhone': appointmentData['conciergePhone'] ?? '',
          'conciergeEmail': appointmentData['conciergeEmail'] ?? '',
          'venueName': appointmentData['venueName'] ?? '',
          'venueAddress': appointmentData['venueAddress'] ?? '',
          'chatAvailable': true,
        },
        role: 'minister',
        assignedToId: appointmentData['ministerId'],
        notificationType: 'staff_assignment',
      );
      
      await sendFCMToUser(
        userId: appointmentData['ministerId'],
        title: 'Staff Assigned to Your Appointment',
        body:
            'Your ${appointmentData['serviceName'] ?? 'appointment'} on $formattedDate at $formattedTime has been assigned.\nConsultant:  ${appointmentData['consultantName'] ?? 'Not assigned'}\nConcierge:  ${appointmentData['conciergeName'] ?? 'Not assigned'}\nTap the consultant/concierge phone number to call, or tap the chat icon to message.',
        data: convertToStringMap({
          ...enhancedAppointmentData,
          'type': 'staff_assignment',
          'consultantId': assignedStaff['consultant'],
          'consultantName': appointmentData['consultantName'] ?? '',
          'consultantPhone': appointmentData['consultantPhone'] ?? '',
          'conciergeId': assignedStaff['concierge'],
          'conciergeName': appointmentData['conciergeName'] ?? '',
          'conciergePhone': appointmentData['conciergePhone'] ?? '',
          'chatAvailable': true,
        }),
        messageType: 'staff_assignment',
      );
    } catch (e) {
      print('Error notifying booking assignment: $e');
      throw e;
    }
  }

  /// 4. ACCEPTANCE FLOW: Staff acknowledges assignment
  Future<void> notifyAssignmentAcceptance({
    required String appointmentId,
    required String staffId,
    required String staffRole,
  }) async {
    if (appointmentId.isEmpty) {
      print('[ERROR] notifyAssignmentAcceptance: appointmentId is empty, aborting notification send.');
      return;
    }
    if (staffId.isEmpty) {
      print('[ERROR] notifyAssignmentAcceptance: staffId is empty, aborting notification send.');
      return;
    }
    try {
      // Get appointment details
      final appointmentDoc = await _firestore.collection('appointments').doc(appointmentId).get();
      if (!appointmentDoc.exists) {
        throw Exception('Appointment not found: $appointmentId');
      }
      
      final appointmentData = appointmentDoc.data()!;
      
      // Get staff details
      final staffDoc = await _firestore.collection('users').doc(staffId).get();
      final staffData = staffDoc.data() ?? {};
      final staffName = '${staffData['firstName'] ?? ''} ${staffData['lastName'] ?? ''}';
      
      // Get minister details
      final ministerData = await _getMinisterDetails(appointmentData['ministerId']);
      final ministerName = '${ministerData['firstName'] ?? ''} ${ministerData['lastName'] ?? ''}';
      
      final now = DateTime.now();
      final formattedTime = DateFormat('h:mm a').format(now);
      final serviceName = appointmentData['serviceName'] ?? 'Unknown Service';
      
      // 1. Notify minister
      await createNotification(
        title: 'Assignment Accepted',
        body: 'Your $serviceName appointment has been accepted by $staffName (${_getRoleTitle(staffRole)})',
        data: {
          ...appointmentData,
          'id': appointmentId,
          'acceptedBy': staffId,
          'acceptedByName': staffName,
          'acceptedByRole': staffRole,
          'acceptanceTime': now,
        },
        role: 'minister',
        assignedToId: appointmentData['ministerId'],
        notificationType: 'assignment_accepted',
      );
      
      // Send FCM to minister
      await sendFCMToUser(
        userId: appointmentData['ministerId'],
        title: 'Assignment Accepted',
        body: 'Your $serviceName appointment has been accepted by $staffName (${_getRoleTitle(staffRole)})',
        data: {
          ...appointmentData,
          'id': appointmentId,
          'acceptedBy': staffId,
          'acceptedByName': staffName,
          'acceptedByRole': staffRole,
          'acceptanceTime': Timestamp.fromDate(now),
        },
        messageType: 'assignment_accepted',
      );
      
      // 2. Notify floor managers
      final floorManagerDocs = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'floor_manager')
          .get();
      
      for (var doc in floorManagerDocs.docs) {
        final floorManagerId = doc.id;
        
        await createNotification(
          title: 'Assignment Accepted',
          body: '$staffName (${_getRoleTitle(staffRole)}) has accepted the assignment for $serviceName on $formattedTime',
          data: {
            ...appointmentData,
            'id': appointmentId,
            'acceptedBy': staffId,
            'acceptedByName': staffName,
            'acceptedByRole': staffRole,
            'acceptanceTime': Timestamp.fromDate(now),
          },
          role: 'floor_manager',
          assignedToId: floorManagerId,
          notificationType: 'assignment_accepted',
        );
        
        await sendFCMToUser(
          userId: floorManagerId,
          title: 'Assignment Accepted',
          body: '$staffName (${_getRoleTitle(staffRole)}) has accepted the assignment for $serviceName on $formattedTime',
          data: {
            ...appointmentData,
            'id': appointmentId,
            'acceptedBy': staffId,
            'acceptedByName': staffName,
            'acceptedByRole': staffRole,
            'acceptanceTime': Timestamp.fromDate(now),
          },
          messageType: 'assignment_accepted',
        );
      }
    } catch (e) {
      print('Error notifying assignment acceptance: $e');
      throw e;
    }
  }

  /// 5. APPOINTMENT START FLOW: Staff begins appointment
  Future<void> notifyAppointmentStart({
    required String appointmentId,
    required String staffId,
    required String staffRole,
  }) async {
    if (appointmentId.isEmpty) {
      print('[ERROR] notifyAppointmentStart: appointmentId is empty, aborting notification send.');
      return;
    }
    if (staffId.isEmpty) {
      print('[ERROR] notifyAppointmentStart: staffId is empty, aborting notification send.');
      return;
    }
    try {
      // Get appointment details
      final appointmentDoc = await _firestore.collection('appointments').doc(appointmentId).get();
      if (!appointmentDoc.exists) {
        throw Exception('Appointment not found: $appointmentId');
      }
      
      final appointmentData = appointmentDoc.data()!;
      
      // Get staff details
      final staffDoc = await _firestore.collection('users').doc(staffId).get();
      final staffData = staffDoc.data() ?? {};
      final staffName = '${staffData['firstName'] ?? ''} ${staffData['lastName'] ?? ''}';
      final staffPhone = staffData['phone'] ?? '';
      final staffEmail = staffData['email'] ?? '';
      
      // Get minister details
      final ministerData = await _getMinisterDetails(appointmentData['ministerId']);
      final ministerName = '${ministerData['firstName'] ?? ''} ${ministerData['lastName'] ?? ''}';
      
      final floorManagersQuery = await _firestore.collection('users').where('role', isEqualTo: 'floor_manager').get();
      
      // Format time and service name safely
      final DateTime appointmentDateTime = appointmentData['appointmentTime'] is Timestamp
          ? (appointmentData['appointmentTime'] as Timestamp).toDate()
          : DateTime.now();
      final formattedTime = DateFormat('EEEE, MMMM d, y, h:mm a').format(appointmentDateTime);
      final serviceName = appointmentData['serviceName'] ?? 'the service';
      final now = DateTime.now();
      
      for (var doc in floorManagersQuery.docs) {
        final floorManagerId = doc.id;
        
        await createNotification(
          title: 'Appointment Started',
          body: '$staffName (${_getRoleTitle(staffRole)}) has started the $serviceName appointment with VIP $ministerName at $formattedTime',
          data: {
            ...appointmentData,
            'id': appointmentId,
            'startedBy': staffId,
            'startedByName': staffName,
            'startedByRole': staffRole,
            'startTime': Timestamp.fromDate(now),
          },
          role: 'floor_manager',
          assignedToId: floorManagerId,
          notificationType: 'appointment_started',
        );
        
        await sendFCMToUser(
          userId: floorManagerId,
          title: 'Appointment Started',
          body: '$staffName (${_getRoleTitle(staffRole)}) has started the $serviceName appointment with VIP $ministerName at $formattedTime',
          data: {
            ...appointmentData,
            'id': appointmentId,
            'startedBy': staffId,
            'startedByName': staffName,
            'startedByRole': staffRole,
            'startTime': Timestamp.fromDate(now),
          },
          messageType: 'appointment_started',
        );
      }
      
      // 3. If concierge started the appointment, notify the assigned consultant
      if (staffRole == 'concierge' && appointmentData['consultantId'] != null) {
        final consultantId = appointmentData['consultantId'];
        
        // Get consultant details
        final consultantDoc = await _firestore.collection('users').doc(consultantId).get();
        final consultantData = consultantDoc.data() ?? {};
        final consultantName = '${consultantData['firstName'] ?? ''} ${consultantData['lastName'] ?? ''}';
        
        await createNotification(
          title: 'VIP Has Arrived',
          body: 'VIP $ministerName has arrived and is with the concierge. Please prepare for your appointment.',
          data: {
            ...appointmentData,
            'id': appointmentId,
            'ministerArrivedTime': Timestamp.fromDate(now),
            'receivedBy': staffId,
            'receivedByName': staffName,
          },
          role: 'consultant',
          assignedToId: consultantId,
          notificationType: 'minister_arrived',
        );
        
        await sendFCMToUser(
          userId: consultantId,
          title: 'VIP Has Arrived',
          body: 'VIP $ministerName has arrived and is with the concierge. Please prepare for your appointment.',
          data: {
            ...appointmentData,
            'id': appointmentId,
            'ministerArrivedTime': Timestamp.fromDate(now),
            'receivedBy': staffId,
            'receivedByName': staffName,
          },
          messageType: 'minister_arrived',
        );
      }
    } catch (e) {
      print('Error notifying appointment start: $e');
      throw e;
    }
  }

  /// 6. APPOINTMENT COMPLETION: Staff completes appointment
  Future<void> notifyAppointmentCompletion({
    required String appointmentId,
    required String staffId,
    required String staffRole,
  }) async {
    if (appointmentId.isEmpty) {
      print('[ERROR] notifyAppointmentCompletion: appointmentId is empty, aborting notification send.');
      return;
    }
    if (staffId.isEmpty) {
      print('[ERROR] notifyAppointmentCompletion: staffId is empty, aborting notification send.');
      return;
    }
    try {
      // Get appointment details
      final appointmentDoc = await _firestore.collection('appointments').doc(appointmentId).get();
      if (!appointmentDoc.exists) {
        throw Exception('Appointment not found: $appointmentId');
      }
      
      final appointmentData = appointmentDoc.data()!;
      
      // Get staff details
      final staffDoc = await _firestore.collection('users').doc(staffId).get();
      final staffData = staffDoc.data() ?? {};
      final staffName = '${staffData['firstName'] ?? ''} ${staffData['lastName'] ?? ''}';
      
      // Get minister details
      final ministerData = await _getMinisterDetails(appointmentData['ministerId']);
      final ministerName = '${ministerData['firstName'] ?? ''} ${ministerData['lastName'] ?? ''}';
      
      final now = DateTime.now();
      final formattedTime = DateFormat('h:mm a').format(now);
      final serviceName = appointmentData['serviceName'] ?? 'Unknown Service';
      
      // 1. If consultant role is completing, send thank you to minister
      if (staffRole == 'consultant') {
        await createNotification(
          title: 'Appointment Completed',
          body: 'Thank you for visiting us! Your $serviceName appointment with $staffName has been completed.',
          data: {
            ...appointmentData,
            'id': appointmentId,
            'completedBy': staffId,
            'completedByName': staffName,
            'completedByRole': staffRole,
            'completionTime': Timestamp.fromDate(now),
          },
          role: 'minister',
          assignedToId: appointmentData['ministerId'],
          notificationType: 'appointment_completed',
        );
        
        await sendFCMToUser(
          userId: appointmentData['ministerId'],
          title: 'Appointment Completed',
          body: 'Thank you for visiting us! Your $serviceName appointment with $staffName has been completed.',
          data: {
            ...appointmentData,
            'id': appointmentId,
            'completedBy': staffId,
            'completedByName': staffName,
            'completedByRole': staffRole,
            'completionTime': Timestamp.fromDate(now),
          },
          messageType: 'appointment_completed',
        );
      }
      
      // 2. Notify floor managers
      final floorManagerDocs = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'floor_manager')
          .get();
      
      for (var doc in floorManagerDocs.docs) {
        final floorManagerId = doc.id;
        
        await createNotification(
          title: 'Appointment Completed',
          body: '$staffName (${_getRoleTitle(staffRole)}) has completed their part of the $serviceName appointment with Minister $ministerName at $formattedTime',
          data: {
            ...appointmentData,
            'id': appointmentId,
            'completedBy': staffId,
            'completedByName': staffName,
            'completedByRole': staffRole,
            'completionTime': Timestamp.fromDate(now),
          },
          role: 'floor_manager',
          assignedToId: floorManagerId,
          notificationType: 'role_completion',
        );
        
        await sendFCMToUser(
          userId: floorManagerId,
          title: 'Appointment Completed',
          body: '$staffName (${_getRoleTitle(staffRole)}) has completed their part of the $serviceName appointment with Minister $ministerName at $formattedTime',
          data: {
            ...appointmentData,
            'id': appointmentId,
            'completedBy': staffId,
            'completedByName': staffName,
            'completedByRole': staffRole,
            'completionTime': Timestamp.fromDate(now),
          },
          messageType: 'role_completion',
        );
      }
      
      // 3. Notify other assigned staff (except the one who marked it as completed)
      final staffRoles = ['consultant', 'concierge', 'cleaner'];
      for (final role in staffRoles) {
        final roleId = appointmentData['${role}Id'];
        
        // Skip if no staff assigned for this role or if it's the staff who marked as completed
        if (roleId == null || roleId.isEmpty || (role == staffRole && roleId == staffId)) {
          continue;
        }
        
        // Ensure showRating is always true for minister notifications
        if (role == 'minister') {
          appointmentData['showRating'] = true;
        }
        await createNotification(
          title: 'Appointment Completed',
          body: 'The $serviceName with $ministerName on $formattedTime has been completed by ${_getRoleTitle(staffRole)}.',
          data: appointmentData,
          role: role,
          assignedToId: roleId,
          notificationType: 'appointment_completed',
        );
        
        await sendFCMToUser(
          userId: roleId,
          title: 'Appointment Completed',
          body: 'The $serviceName with $ministerName on $formattedTime has been completed by ${_getRoleTitle(staffRole)}.',
          data: appointmentData,
          messageType: 'appointment_completed',
        );
      }
      
      // 4. Notify concierge if consultant starts session (minister arrived)
      if (staffRole == 'consultant' && appointmentData['conciergeId'] != null) {
        final conciergeId = appointmentData['conciergeId'];
        final consultantName = staffName;
        await createNotification(
          title: 'VIP Has Arrived',
          body: 'Minister $ministerName has arrived for the appointment. Please receive and assist.',
          data: {
            ...appointmentData,
            'id': appointmentId,
            'ministerArrivedTime': Timestamp.fromDate(now),
            'receivedBy': staffId,
            'receivedByName': consultantName,
          },
          role: 'concierge',
          assignedToId: conciergeId,
          notificationType: 'minister_arrived',
        );
        await sendFCMToUser(
          userId: conciergeId,
          title: 'VIP Has Arrived',
          body: 'Minister $ministerName has arrived for the appointment. Please receive and assist.',
          data: convertToStringMap({
            ...appointmentData,
            'id': appointmentId,
            'ministerArrivedTime': Timestamp.fromDate(now),
            'receivedBy': staffId,
            'receivedByName': consultantName,
          }),
          messageType: 'minister_arrived',
        );
      }
    } catch (e) {
      print('Error notifying appointment completion: $e');
      throw e;
    }
  }

  /// Returns a list of notifications for a consultant (one-time fetch)
  Future<List<Map<String, dynamic>>> getConsultantNotificationsOnce(String consultantId) async {
    if (consultantId.isEmpty) return [];
    final snapshot = await _firestore
        .collection('notifications')
        .where('assignedToId', isEqualTo: consultantId)
        .orderBy('timestamp', descending: true)
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  /// Returns a stream of notifications for a consultant (real-time updates)
  Stream<List<Map<String, dynamic>>> getConsultantNotificationsStream(String consultantId) {
    if (consultantId.isEmpty) return const Stream.empty();
    return _firestore
        .collection('notifications')
        .where('assignedToId', isEqualTo: consultantId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              data['id'] = doc.id;
              return data;
            }).toList());
  }

  /// Helper method to get full minister details
  Future<Map<String, dynamic>> _getMinisterDetails(String ministerId) async {
    try {
      final ministerDoc = await _firestore.collection('users').doc(ministerId).get();
      if (!ministerDoc.exists) {
        return {
          'firstName': 'Unknown',
          'lastName': 'Minister',
          'phone': '',
          'email': '',
        };
      }
      
      return ministerDoc.data() ?? {};
    } catch (e) {
      print('Error getting minister details: $e');
      return {
        'firstName': 'Unknown',
        'lastName': 'Minister',
        'phone': '',
        'email': '',
      };
    }
  }

  /// Helper method to get role title
  String _getRoleTitle(String role) {
    switch (role) {
      case 'floor_manager':
        return 'Floor Manager';
      case 'consultant':
        return 'Consultant';
      case 'concierge':
        return 'Concierge';
      case 'cleaner':
        return 'Cleaner';
      case 'minister':
        return 'Minister';
      default:
        return role.substring(0, 1).toUpperCase() + role.substring(1);
    }
  }

  /// Send notification for a new message
  Future<void> sendMessageNotification({
    required String senderId, 
    required String senderName,
    required String recipientId,
    required String recipientRole,
    required String message,
    required String appointmentId,
    String? appointmentDetails,
    required String senderRole,
  }) async {
    if (recipientId.isEmpty) {
      print('[ERROR] sendMessageNotification: recipientId is empty, aborting notification send.');
      return;
    }
    if (appointmentId.isEmpty) {
      print('[ERROR] sendMessageNotification: appointmentId is empty, aborting notification send.');
      return;
    }
    try {
      // Fetch sender contact info
      final senderDoc = await _firestore.collection('users').doc(senderId).get();
      final senderData = senderDoc.data() ?? {};
      
      // Fetch recipient contact info
      final recipientDoc = await _firestore.collection('users').doc(recipientId).get();
      final recipientData = recipientDoc.data() ?? {};
      
      // Create the notification data
      final notificationData = {
        'senderId': senderId,
        'senderName': senderName,
        'senderRole': senderRole,
        'senderPhone': senderData['phone'] ?? senderData['phoneNumber'] ?? '',
        'senderEmail': senderData['email'] ?? '',
        'recipientId': recipientId,
        'recipientRole': recipientRole,
        'recipientPhone': recipientData['phone'] ?? recipientData['phoneNumber'] ?? '',
        'recipientEmail': recipientData['email'] ?? '',
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'appointmentId': appointmentId,
        'appointmentDetails': appointmentDetails,
        'type': 'message',
      };
      
      // Ensure showRating is always true for minister notifications
      if (recipientRole == 'minister') {
        notificationData['showRating'] = true;
      }
      // Create a notification in Firestore
      await createNotification(
        title: 'Message from ${_getRoleTitle(senderRole)}: $senderName',
        body: message,
        data: notificationData,
        role: recipientRole,
        assignedToId: recipientId,
        notificationType: 'message',
      );
      
      // Send FCM notification
      await sendFCMToUser(
        userId: recipientId,
        title: 'Message from ${_getRoleTitle(senderRole)}: $senderName',
        body: message,
        data: convertToStringMap(notificationData),
        messageType: 'message',
      );
    } catch (e) {
      print('Error sending message notification: $e');
      throw e;
    }
  }

  /// Notify assigned staff about booking completion
  Future<void> notifyBookingCompletion({
    required String appointmentId,
    required Map<String, dynamic> appointmentData,
    required String staffRole,
    required String staffId,
  }) async {
    if (appointmentId.isEmpty) {
      print('[ERROR] notifyBookingCompletion: appointmentId is empty, aborting notification send.');
      return;
    }
    if (staffId.isEmpty) {
      print('[ERROR] notifyBookingCompletion: staffId is empty, aborting notification send.');
      return;
    }
    try {
      // Extract necessary data from the appointment
      final ministerData = await _getMinisterDetails(appointmentData['ministerId']);
      final ministerName = ministerData['name'] ?? 
                          '${ministerData['firstName'] ?? 'Unknown'} ${ministerData['lastName'] ?? 'Minister'}';
      
      // Format the appointment time for display
      final appointmentTimestamp = appointmentData['appointmentTime'] as Timestamp?;
      final appointmentTime = appointmentTimestamp?.toDate() ?? DateTime.now();
      final formattedDate = DateFormat('EEEE, MMMM d').format(appointmentTime);
      final formattedTime = DateFormat('h:mm a').format(appointmentTime);
      final serviceName = appointmentData['serviceName'] ?? 'appointment';
      
      // Common notification data
      final notificationData = {
        'id': appointmentId,
        'appointmentId': appointmentId,
        'ministerName': ministerName,
        'serviceName': serviceName,
        'formattedDate': formattedDate,
        'formattedTime': formattedTime,
        'completionTime': FieldValue.serverTimestamp(),
        'completedByRole': staffRole,
        'completedById': staffId,
      };
      
      // Ensure showRating is always true for minister notifications
      if (staffRole == 'minister') {
        notificationData['showRating'] = true;
      }
      // 1. Notify the minister
      final ministerId = appointmentData['ministerId'];
      if (ministerId != null) {
        await createNotification(
          title: 'Appointment Completed',
          body: 'Your $serviceName on $formattedDate at $formattedTime has been completed.',
          data: notificationData,
          role: 'minister',
          assignedToId: ministerId,
          notificationType: 'appointment_completed',
        );
        
        await sendFCMToUser(
          userId: ministerId,
          title: 'Appointment Completed',
          body: 'Your $serviceName on $formattedDate at $formattedTime has been completed.',
          data: convertToStringMap(notificationData),
          messageType: 'appointment_completed',
        );
      }
      
      // 2. Notify the floor manager(s)
      final floorManagersQuery = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'floor_manager')
          .get();
      
      for (final floorManagerDoc in floorManagersQuery.docs) {
        final floorManagerId = floorManagerDoc.id;
        print('[NOTIFY] Preparing to notify floor manager: $floorManagerId');
        try {
          await createNotification(
            title: 'Appointment Completed',
            body: '$serviceName with $ministerName on $formattedDate at $formattedTime has been completed by ${_getRoleTitle(staffRole)}.',
            data: notificationData,
            role: 'floor_manager',
            assignedToId: floorManagerId,
            notificationType: 'appointment_completed',
          );
          print('[NOTIFY] In-app notification created for floor manager: $floorManagerId');
        } catch (e) {
          print('[ERROR] Failed to create in-app notification for floor manager $floorManagerId: $e');
        }
        try {
          await sendFCMToUser(
            userId: floorManagerId,
            title: 'Appointment Completed',
            body: '$serviceName with $ministerName on $formattedDate at $formattedTime has been completed by ${_getRoleTitle(staffRole)}.',
            data: convertToStringMap(notificationData),
            messageType: 'appointment_completed',
          );
          print('[NOTIFY] FCM sent to floor manager: $floorManagerId');
        } catch (e) {
          print('[ERROR] Failed to send FCM to floor manager $floorManagerId: $e');
        }
      }
      
      // 3. Notify other assigned staff (except the one who marked it as completed)
      final staffRoles = ['consultant', 'concierge', 'cleaner'];
      for (final role in staffRoles) {
        final roleId = appointmentData['${role}Id'];
        
        // Skip if no staff assigned for this role or if it's the staff who marked as completed
        if (roleId == null || roleId.isEmpty || (role == staffRole && roleId == staffId)) {
          continue;
        }
        
        // Ensure showRating is always true for minister notifications
        if (role == 'minister') {
          notificationData['showRating'] = true;
        }
        await createNotification(
          title: 'Appointment Completed',
          body: 'The $serviceName with $ministerName on $formattedDate at $formattedTime has been completed by ${_getRoleTitle(staffRole)}.',
          data: notificationData,
          role: role,
          assignedToId: roleId,
          notificationType: 'appointment_completed',
        );
        
        await sendFCMToUser(
          userId: roleId,
          title: 'Appointment Completed',
          body: 'The $serviceName with $ministerName on $formattedDate at $formattedTime has been completed by ${_getRoleTitle(staffRole)}.',
          data: convertToStringMap(notificationData),
          messageType: 'appointment_completed',
        );
      }
    } catch (e) {
      print('Error notifying booking completion: $e');
      throw e;
    }
  }

  /// Notify assigned staff about booking cancellation
  Future<void> notifyBookingCancellation({
    required String appointmentId,
    required Map<String, dynamic> appointmentData,
    required List<String> assignedUserIds,
  }) async {
    if (appointmentId.isEmpty) {
      print('[ERROR] notifyBookingCancellation: appointmentId is empty, aborting notification send.');
      return;
    }
    try {
      // Set status to cancelled
      await _firestore.collection('appointments').doc(appointmentId).update({
        'status': 'cancelled',
        'consultantId': null, // Release consultant
        'conciergeId': null, // Release concierge
        'cleanerId': null, // Release cleaner
        'timeSlotStatus': 'free',
      });
      // Notify all assigned users and floor manager
      for (final userId in assignedUserIds) {
        await createNotification(
          title: 'Booking Cancelled',
          body: 'The booking for ${appointmentData['serviceName']} at ${appointmentData['venueName']} on ${appointmentData['formattedDateTime']} has been cancelled.',
          data: {
            ...appointmentData,
            'appointmentId': appointmentId,
            'notificationType': 'booking_cancelled',
          },
          role: 'user',
          assignedToId: userId,
          notificationType: 'booking_cancelled',
        );
      }
    } catch (e) {
      print('Error in notifyBookingCancellation: $e');
      throw e;
    }
  }

  /// Mark a notification as read by document ID
  Future<void> markNotificationAsRead(String notificationId) async {
    if (notificationId.isEmpty) return;
    await _firestore.collection('notifications').doc(notificationId).update({'isRead': true});
  }
}
