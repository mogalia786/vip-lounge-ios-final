import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Enhanced notification service that implements the complete notification flow process
/// for the VIP lounge booking system, ensuring all stakeholders receive appropriate
/// notifications at each stage of the booking process.
class VipNotificationService {
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
    // Defensive: do not create notification if assignedToId is present but empty
    if (assignedToId != null && assignedToId.isEmpty) {
      print('[ERROR] createNotification: assignedToId is empty, aborting notification creation.');
      return;
    }
    try {
      // Fetch appointment and minister/user info if appointmentId is present and not already included
      Map<String, dynamic> enrichedData = Map<String, dynamic>.from(data);
      // Always ensure appointmentId is present and correct
      final appointmentId = data['appointmentId'] ?? data['id'];
      if (appointmentId != null && appointmentId.toString().isNotEmpty) {
        enrichedData['appointmentId'] = appointmentId.toString();
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
      // Continue with notification creation as before
      final notificationData = {
        'title': title,
        'body': body,
        'data': enrichedData,
        'role': role,
        'assignedToId': assignedToId,
        'notificationType': notificationType ?? 'general',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      };
      if (role == 'consultant' || role == 'concierge' || role == 'cleaner') {
        notificationData['staffId'] = assignedToId;
      }
      await _firestore.collection('notifications').add(notificationData);
      // Send FCM push notification if assignedToId is present
      if (assignedToId != null && assignedToId.isNotEmpty) {
        await sendFCMToUser(
          userId: assignedToId,
          title: title,
          body: body,
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
    if (userId.isEmpty) {
      print('[FCM] ERROR: userId is empty, cannot send FCM.');
      return;
    }
    try {
      // Before using the path in Firestore, print it for debugging
      print('[DEBUG] Firestore document path: users/$userId');
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final token = userDoc.data()?['fcmToken'];

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

        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        );

        print('[FCM] HTTP response: ${response.statusCode} ${response.body}');

        if (response.statusCode == 200) {
          print('[FCM] Push notification sent to user $userId: "$title"');
        } else {
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
      
      // Make sure we have all appointment details
      final fullAppointmentData = {
        ...appointmentData,
        'id': appointmentId,
        'ministerPhone': ministerData['phone'] ?? '',
        'ministerEmail': ministerData['email'] ?? '',
        'ministerFirstName': ministerData['firstName'] ?? '',
        'ministerLastName': ministerData['lastName'] ?? '',
      };
      
      // Format date and time for readability in notifications
      final appointmentTime = appointmentData['appointmentTime'] is Timestamp
          ? (appointmentData['appointmentTime'] as Timestamp).toDate()
          : DateTime.now();
      
      final formattedDateTime = DateFormat('EEEE, MMMM d, y, h:mm a').format(appointmentTime);
      final serviceName = appointmentData['serviceName'] ?? 'Unknown Service';
      
      // 1. Send notification to ALL floor managers
      final floorManagerDocs = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'floor_manager')
          .get();
      
      for (var doc in floorManagerDocs.docs) {
        final floorManagerId = doc.id;
        
        // Create in-app notification (appears in bottom nav bar)
        await createNotification(
          title: 'New Booking Request',
          body: 'Minister ${fullAppointmentData['ministerFirstName']} ${fullAppointmentData['ministerLastName']} has requested a ${serviceName} appointment for $formattedDateTime',
          data: fullAppointmentData,
          role: 'floor_manager',
          assignedToId: floorManagerId,
          notificationType: 'booking_created',
        );
        
        // Send FCM push notification
        await sendFCMToUser(
          userId: floorManagerId,
          title: 'New Booking Request',
          body: 'Minister ${fullAppointmentData['ministerFirstName']} ${fullAppointmentData['ministerLastName']} has requested a ${serviceName} appointment for $formattedDateTime',
          data: fullAppointmentData,
          messageType: 'booking_created',
        );
      }
    } catch (e) {
      print('Error notifying booking creation: $e');
      throw e;
    }
  }

  /// 2. STAFF ASSIGNMENT: Floor manager assigns staff to an appointment
  Future<void> notifyStaffAssignment({
    required String appointmentId,
    required Map<String, dynamic> appointmentData,
    required String consultantId,
    required String consultantName,
    required String conciergeId,
    required String conciergeName,
    String? cleanerId,
    String? cleanerName,
  }) async {
    if (appointmentId.isEmpty) {
      print('[ERROR] notifyStaffAssignment: appointmentId is empty, aborting notification send.');
      return;
    }
    if (consultantId.isEmpty) {
      print('[ERROR] notifyStaffAssignment: consultantId is empty, aborting notification send.');
      return;
    }
    if (conciergeId.isEmpty) {
      print('[ERROR] notifyStaffAssignment: conciergeId is empty, aborting notification send.');
      return;
    }
    try {
      print('[DEBUG] notifyStaffAssignment called for appointmentId: $appointmentId');
      print('[DEBUG] consultantId: $consultantId, consultantName: $consultantName');
      print('[DEBUG] conciergeId: $conciergeId, conciergeName: $conciergeName');
      print('[DEBUG] cleanerId: $cleanerId, cleanerName: $cleanerName');

      // Get floor manager ID from appointmentData or fallback to assignedBy
      final floorManagerId = appointmentData['assignedById'] ?? appointmentData['floorManagerId'] ?? appointmentData['assignedFloorManagerId'];
      print('[DEBUG] Floor Manager ID for notification: $floorManagerId');

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
        'ministerName': (
          (ministerData['firstName'] != null && ministerData['lastName'] != null && ministerData['firstName'] != 'Unknown')
            ? '${ministerData['firstName']} ${ministerData['lastName']}'
            : (appointmentData['ministerName'] ?? 'Minister')
        ),
        'consultantId': consultantId,
        'consultantName': consultantName,
        'conciergeId': conciergeId,
        'conciergeName': conciergeName,
        'cleanerId': cleanerId,
        'cleanerName': cleanerName,
      };
      
      // Add phone numbers to notification data
      final consultantPhone = appointmentData['consultantPhone'] ?? '';
      final conciergePhone = appointmentData['conciergePhone'] ?? '';
      
      // 1. Notify Consultant
      print('[DEBUG] Creating consultant notification: assignedToId=$consultantId, data=$fullAppointmentData');
      await createNotification(
        title: 'New Appointment Assigned',
        body: 'You have been assigned to a new appointment. Minister: ${fullAppointmentData['ministerName']}, Service: ${fullAppointmentData['serviceName']}, Venue: ${fullAppointmentData['venueName']}, Time: $formattedDateTime. Concierge: $conciergeName, Phone: $conciergePhone',
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
      print('[DEBUG] Before sending FCM to consultantId: $consultantId');
      await sendFCMToUser(
        userId: consultantId,
        title: 'New Appointment Assigned',
        body: 'You have been assigned to a new appointment. Minister: ${fullAppointmentData['ministerName']}, Service: ${fullAppointmentData['serviceName']}, Venue: ${fullAppointmentData['venueName']}, Time: $formattedDateTime. Concierge: $conciergeName, Phone: $conciergePhone',
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
      
      // 2. Notify Concierge
      await createNotification(
        title: 'New Appointment Assigned',
        body: 'You have been assigned to receive Minister ${fullAppointmentData['ministerName']} for ${fullAppointmentData['serviceName']} on $formattedDateTime. Consultant: $consultantName, Phone: $consultantPhone',
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
      print('[DEBUG] Before sending FCM to conciergeId: $conciergeId');
      await sendFCMToUser(
        userId: conciergeId,
        title: 'New Appointment Assigned',
        body: 'You have been assigned to receive Minister ${fullAppointmentData['ministerName']} for ${fullAppointmentData['serviceName']} on $formattedDateTime. Consultant: $consultantName, Phone: $consultantPhone',
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
      
      // 3. Notify Cleaner if assigned
      if (cleanerId != null && cleanerId.isNotEmpty) {
        await createNotification(
          title: 'New Appointment Assigned',
          body: "You have been assigned to prepare the venue for Minister "+
                "${fullAppointmentData['ministerName']}'s ${fullAppointmentData['serviceName']} on $formattedDateTime",
          data: fullAppointmentData,
          role: 'cleaner',
          assignedToId: cleanerId,
          notificationType: 'booking_assigned',
        );
        
        print('[DEBUG] Before sending FCM to cleanerId: $cleanerId');
        await sendFCMToUser(
          userId: cleanerId,
          title: 'New Appointment Assigned',
          body: "You have been assigned to prepare the venue for Minister "+
                "${fullAppointmentData['ministerName']}'s ${fullAppointmentData['serviceName']} on $formattedDateTime",
          data: convertToStringMap(fullAppointmentData),
          messageType: 'booking_assigned',
        );
        print('[DEBUG] After sending FCM to cleanerId: $cleanerId');
      }
      
      // 4. Notify Minister about staff assignment
      await createNotification(
        title: 'Staff Assigned to Your Appointment',
        body: 'Your ${fullAppointmentData['serviceName']} appointment on $formattedDateTime has been assigned to $consultantName (Consultant) and $conciergeName (Concierge)',
        data: fullAppointmentData,
        role: 'minister',
        assignedToId: appointmentData['ministerId'],
        notificationType: 'staff_assigned',
      );
      
      // Send FCM push notification to minister
      await sendFCMToUser(
        userId: appointmentData['ministerId'],
        title: 'Staff Assigned to Your Appointment',
        body: 'Your ${fullAppointmentData['serviceName']} appointment on $formattedDateTime has been assigned to $consultantName (Consultant) and $conciergeName (Concierge)',
        data: convertToStringMap(fullAppointmentData),
        messageType: 'staff_assigned',
      );
      
      // 5. Notify floor manager (assignment summary)
      if (floorManagerId != null && floorManagerId.toString().isNotEmpty) {
        await createNotification(
          title: 'Staff Assignment Successful',
          body:
              'You assigned consultant $consultantName and concierge $conciergeName to appointment $appointmentId.\nService: ${fullAppointmentData['serviceName']}\nVenue: ${fullAppointmentData['venueName']}\nDate: $formattedDateTime\nMinister: ${fullAppointmentData['ministerName']}\nDuration: ${fullAppointmentData['duration'] ?? ''} min',
          data: {
            ...fullAppointmentData,
            'consultantId': consultantId,
            'consultantName': consultantName,
            'conciergeId': conciergeId,
            'conciergeName': conciergeName,
            'venueName': fullAppointmentData['venueName'] ?? '',
            'duration': fullAppointmentData['duration'] ?? '',
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
          'conciergeId': assignedStaff['concierge'],
          'conciergeName': appointmentData['conciergeName'] ?? '',
          'conciergePhone': appointmentData['conciergePhone'] ?? '',
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
      
      final now = DateTime.now();
      final formattedTime = DateFormat('h:mm a').format(now);
      final serviceName = appointmentData['serviceName'] ?? 'Unknown Service';
      
      // 1. Notify minister
      await createNotification(
        title: 'Appointment Started',
        body: 'Welcome! Your $serviceName appointment has started with $staffName (${_getRoleTitle(staffRole)})',
        data: {
          ...appointmentData,
          'id': appointmentId,
          'startedBy': staffId,
          'startedByName': staffName,
          'startedByRole': staffRole,
          'startTime': now,
          'staffPhone': staffPhone,
          'staffEmail': staffEmail,
        },
        role: 'minister',
        assignedToId: appointmentData['ministerId'],
        notificationType: 'appointment_started',
      );
      
      // Send FCM to minister
      await sendFCMToUser(
        userId: appointmentData['ministerId'],
        title: 'Appointment Started',
        body: 'Welcome! Your $serviceName appointment has started with $staffName (${_getRoleTitle(staffRole)})',
        data: {
          ...appointmentData,
          'id': appointmentId,
          'startedBy': staffId,
          'startedByName': staffName,
          'startedByRole': staffRole,
          'startTime': Timestamp.fromDate(now),
          'staffPhone': staffPhone,
          'staffEmail': staffEmail,
        },
        messageType: 'appointment_started',
      );
      
      // 2. Notify floor managers
      final floorManagerDocs = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'floor_manager')
          .get();
      
      for (var doc in floorManagerDocs.docs) {
        final floorManagerId = doc.id;
        
        await createNotification(
          title: 'Appointment Started',
          body: '$staffName (${_getRoleTitle(staffRole)}) has started the $serviceName appointment with Minister $ministerName at $formattedTime',
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
          body: '$staffName (${_getRoleTitle(staffRole)}) has started the $serviceName appointment with Minister $ministerName at $formattedTime',
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
          title: 'Minister Has Arrived',
          body: 'Minister $ministerName has arrived and is with the concierge. Please prepare for your appointment.',
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
          title: 'Minister Has Arrived',
          body: 'Minister $ministerName has arrived and is with the concierge. Please prepare for your appointment.',
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
        
        await createNotification(
          title: 'Appointment Completed',
          body: 'The $serviceName with $ministerName on $formattedTime has been completed by ${_getRoleTitle(staffRole)}.',
          data: {
            ...appointmentData,
            'id': appointmentId,
            'completedBy': staffId,
            'completedByName': staffName,
            'completedByRole': staffRole,
            'completionTime': Timestamp.fromDate(now),
          },
          role: role,
          assignedToId: roleId,
          notificationType: 'appointment_completed',
        );
        
        await sendFCMToUser(
          userId: roleId,
          title: 'Appointment Completed',
          body: 'The $serviceName with $ministerName on $formattedTime has been completed by ${_getRoleTitle(staffRole)}.',
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
      
      // 4. Notify concierge if consultant starts session (minister arrived)
      if (staffRole == 'consultant' && appointmentData['conciergeId'] != null) {
        final conciergeId = appointmentData['conciergeId'];
        final consultantName = staffName;
        await createNotification(
          title: 'Minister Has Arrived',
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
          title: 'Minister Has Arrived',
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
      // Create the notification data
      final notificationData = {
        'senderId': senderId,
        'senderName': senderName,
        'senderRole': senderRole,
        'recipientId': recipientId,
        'recipientRole': recipientRole,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'appointmentId': appointmentId,
        'appointmentDetails': appointmentDetails,
        'type': 'message',
      };
      
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
