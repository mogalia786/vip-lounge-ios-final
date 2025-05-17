import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/workflow_event.dart';

class WorkflowService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Create a workflow event record and trigger notifications
  Future<void> recordEvent({
    required String appointmentId,
    required String eventType,
    required String initiatorId,
    required String initiatorRole,
    String? initiatorName,
    Map<String, dynamic>? eventData,
    String? notes,
  }) async {
    try {
      // Get appointment details
      final appointmentDoc = await _firestore
          .collection('appointments')
          .doc(appointmentId)
          .get();
          
      if (!appointmentDoc.exists) {
        print('Appointment not found when recording workflow event');
        return;
      }
      
      final appointmentData = appointmentDoc.data() as Map<String, dynamic>;
      
      // Create the workflow event record
      final workflowEvent = {
        'appointmentId': appointmentId,
        'eventType': eventType,
        'initiatorId': initiatorId,
        'initiatorRole': initiatorRole,
        'initiatorName': initiatorName,
        'eventData': eventData ?? {},
        'timestamp': FieldValue.serverTimestamp(),
        'notes': notes,
        
        // Staff involved
        'ministerId': appointmentData['ministerId'],
        'ministerName': appointmentData['ministerName'] ?? _getMinisterName(appointmentData),
        'consultantId': appointmentData['consultantId'],
        'consultantName': appointmentData['consultantName'],
        'conciergeId': appointmentData['conciergeId'],
        'conciergeName': appointmentData['conciergeName'],
        'cleanerId': appointmentData['cleanerId'],
        'cleanerName': appointmentData['cleanerName'],
        'floorManagerId': appointmentData['floorManagerId'],
        'floorManagerName': appointmentData['floorManagerName'],
        
        // Service details
        'serviceName': appointmentData['serviceName'],
        'venueName': appointmentData['venueName'],
        'appointmentTime': appointmentData['appointmentTime'],
        'status': appointmentData['status'],
      };
      
      // Record the event
      final docRef = await _firestore.collection('workflow').add(workflowEvent);
      
      // Generate appropriate notifications based on event type
      await _generateEventNotifications(eventType, appointmentId, workflowEvent);
      
      print('Workflow event recorded: ${docRef.id}');
    } catch (e) {
      print('Error recording workflow event: $e');
    }
  }
  
  // Helper method to handle different notification scenarios based on event type
  Future<void> _generateEventNotifications(
    String eventType, 
    String appointmentId,
    Map<String, dynamic> eventData
  ) async {
    switch (eventType) {
      case 'booking_created':
        await _handleBookingCreatedNotifications(appointmentId, eventData);
        break;
        
      case 'concierge_started':
        await _handleConciergeStartedNotifications(appointmentId, eventData);
        break;
        
      case 'consultant_started':
        await _handleConsultantStartedNotifications(appointmentId, eventData);
        break;
        
      case 'consultant_ended':
        await _handleConsultantEndedNotifications(appointmentId, eventData);
        break;
        
      case 'concierge_ended':
        await _handleConciergeEndedNotifications(appointmentId, eventData);
        break;
        
      case 'appointment_cancelled':
        await _handleAppointmentCancelledNotifications(appointmentId, eventData);
        break;
        
      case 'staff_assigned':
        await _handleStaffAssignedNotifications(appointmentId, eventData);
        break;
        
      default:
        print('No notification handling defined for event type: $eventType');
    }
  }
  
  // 1. Booking created - Send welcome message to minister
  Future<void> _handleBookingCreatedNotifications(
    String appointmentId, 
    Map<String, dynamic> eventData
  ) async {
    try {
      final ministerId = eventData['ministerId'];
      if (ministerId == null) return;
      
      final ministerName = eventData['ministerName'] ?? 'Minister';
      final serviceName = eventData['serviceName'] ?? 'your requested service';
      final venueName = eventData['venueName'] ?? 'our venue';
      
      // Format date and time
      String appointmentTimeStr = 'your scheduled time';
      if (eventData['appointmentTime'] is Timestamp) {
        final timestamp = eventData['appointmentTime'] as Timestamp;
        final dateTime = timestamp.toDate();
        appointmentTimeStr = DateFormat('EEEE, MMMM d, yyyy h:mm a').format(dateTime);
      }
      
      // Create a friendly welcome message
      final welcomeMessage = {
        'title': 'Thank you for your booking',
        'body': 'We have received your booking for $serviceName at $venueName on $appointmentTimeStr. We look forward to serving you.',
        'assignedToId': ministerId,
        'type': 'booking_confirmation',
        'appointmentId': appointmentId,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'role': 'minister',
        'sendAsPushNotification': true,
      };
      
      // Add the notification to Firestore
      await _firestore.collection('notifications').add(welcomeMessage);
      
      print('Booking welcome message sent to minister: $ministerId');
    } catch (e) {
      print('Error sending booking welcome notification: $e');
    }
  }
  
  // 2. Concierge started - Notify consultant that minister has arrived
  Future<void> _handleConciergeStartedNotifications(
    String appointmentId, 
    Map<String, dynamic> eventData
  ) async {
    try {
      final consultantId = eventData['consultantId'];
      final ministerName = eventData['ministerName'] ?? 'The minister';
      final currentTime = DateFormat('MMM d, yyyy h:mm a').format(DateTime.now());
      
      if (consultantId == null) {
        print('No consultant assigned to appointment');
        return;
      }
      
      // Notify consultant that minister has arrived
      final consultantNotification = {
        'title': 'Minister Has Arrived',
        'body': '$ministerName has arrived and is being escorted by the concierge. Please prepare for your session. ($currentTime)',
        'assignedToId': consultantId,
        'type': 'minister_arrival',
        'appointmentId': appointmentId,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'role': 'consultant',
        'sendAsPushNotification': true,
      };
      
      await _firestore.collection('notifications').add(consultantNotification);
      
      print('Minister arrival notification sent to consultant: $consultantId');
    } catch (e) {
      print('Error sending minister arrival notification: $e');
    }
  }
  
  // 3. Consultant started - Notify floor manager that session has started
  Future<void> _handleConsultantStartedNotifications(
    String appointmentId, 
    Map<String, dynamic> eventData
  ) async {
    try {
      final floorManagerId = eventData['floorManagerId'];
      final ministerName = eventData['ministerName'] ?? 'The minister';
      final consultantName = eventData['consultantName'] ?? 'The consultant';
      final currentTime = DateFormat('MMM d, yyyy h:mm a').format(DateTime.now());
      final serviceName = eventData['serviceName'] ?? 'the service';
      
      // Notify floor manager
      final floorManagerNotification = {
        'title': 'Session Started',
        'body': 'The session between $consultantName and $ministerName for $serviceName has started. ($currentTime)',
        'receiverId': floorManagerId,
        'type': 'session_started',
        'appointmentId': appointmentId,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'role': 'floor_manager',
        'sendAsPushNotification': true,
      };
      
      if (floorManagerId != null) {
        await _firestore.collection('notifications').add(floorManagerNotification);
        print('Session start notification sent to floor manager: $floorManagerId');
      } else {
        // If no specific floor manager, send to all floor managers
        final floorManagersQuery = await _firestore
            .collection('users')
            .where('role', isEqualTo: 'floor_manager')
            .get();
            
        for (var doc in floorManagersQuery.docs) {
          final notification = {
            ...floorManagerNotification,
            'assignedToId': doc.id,
          };
          await _firestore.collection('notifications').add(notification);
        }
        
        print('Session start notification sent to all floor managers');
      }
    } catch (e) {
      print('Error sending session start notification: $e');
    }
  }
  
  // 4. Consultant ended - Notify concierge and floor manager
  Future<void> _handleConsultantEndedNotifications(
    String appointmentId, 
    Map<String, dynamic> eventData
  ) async {
    try {
      final conciergeId = eventData['conciergeId'];
      final floorManagerId = eventData['floorManagerId'];
      final ministerName = eventData['ministerName'] ?? 'The minister';
      final consultantName = eventData['consultantName'] ?? 'The consultant';
      final currentTime = DateFormat('MMM d, yyyy h:mm a').format(DateTime.now());
      
      // 1. Notify concierge to escort minister
      if (conciergeId != null) {
        final conciergeNotification = {
          'title': 'Session Concluded - Action Required',
          'body': '$ministerName has concluded their session with $consultantName. Please escort the minister to their vehicle. ($currentTime)',
          'receiverId': conciergeId,
          'type': 'escort_minister',
          'appointmentId': appointmentId,
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
          'role': 'concierge',
          'sendAsPushNotification': true,
          'requiresAction': true,
        };
        
        await _firestore.collection('notifications').add(conciergeNotification);
        print('Escort request notification sent to concierge: $conciergeId');
      }
      
      // 2. Notify floor manager
      final floorManagerNotification = {
        'title': 'Session Concluded',
        'body': 'The session between $consultantName and $ministerName has concluded. The concierge has been notified to escort the minister. ($currentTime)',
        'receiverId': floorManagerId,
        'type': 'session_concluded',
        'appointmentId': appointmentId,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'role': 'floor_manager',
        'sendAsPushNotification': true,
      };
      
      if (floorManagerId != null) {
        await _firestore.collection('notifications').add(floorManagerNotification);
        print('Session conclusion notification sent to floor manager: $floorManagerId');
      } else {
        // If no specific floor manager, send to all floor managers
        final floorManagersQuery = await _firestore
            .collection('users')
            .where('role', isEqualTo: 'floor_manager')
            .get();
            
        for (var doc in floorManagersQuery.docs) {
          final notification = {
            ...floorManagerNotification,
            'assignedToId': doc.id,
          };
          await _firestore.collection('notifications').add(notification);
        }
        
        print('Session conclusion notification sent to all floor managers');
      }
    } catch (e) {
      print('Error sending session conclusion notifications: $e');
    }
  }
  
  // 5. Concierge ended - Send thank you message to minister and notify floor manager
  Future<void> _handleConciergeEndedNotifications(
    String appointmentId, 
    Map<String, dynamic> eventData
  ) async {
    try {
      final ministerId = eventData['ministerId'];
      final floorManagerId = eventData['floorManagerId'];
      final ministerName = eventData['ministerName'] ?? 'the minister';
      final serviceName = eventData['serviceName'] ?? 'your service';
      final currentTime = DateFormat('MMM d, yyyy h:mm a').format(DateTime.now());
      
      // 1. Send thank you message to minister
      if (ministerId != null) {
        final ministerThankYou = {
          'title': 'Thank You for Your Visit',
          'body': 'Thank you for allowing us to serve you today. It was our pleasure to assist you with $serviceName. We look forward to your next visit.',
          'assignedToId': ministerId,
          'type': 'thank_you',
          'appointmentId': appointmentId,
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
          'role': 'minister',
          'sendAsPushNotification': true,
        };
        
        await _firestore.collection('notifications').add(ministerThankYou);
        print('Thank you message sent to minister: $ministerId');
      }
      
      // 2. Notify floor manager that service is complete
      final floorManagerNotification = {
        'title': 'Service Completed',
        'body': 'The concierge has completed escorting $ministerName. The full service cycle is now complete. ($currentTime)',
        'receiverId': floorManagerId,
        'type': 'service_completed',
        'appointmentId': appointmentId,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'role': 'floor_manager',
        'sendAsPushNotification': true,
      };

      // 3. Notify consultant that minister has left the premises
      final consultantId = eventData['consultantId'];
      if (consultantId != null) {
        final consultantNotification = {
          'title': 'Minister Has Left',
          'body': '$ministerName has left the premises. The appointment is now fully completed. ($currentTime)',
          'assignedToId': consultantId,
          'type': 'minister_left',
          'appointmentId': appointmentId,
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
          'role': 'consultant',
          'sendAsPushNotification': true,
        };
        await _firestore.collection('notifications').add(consultantNotification);
        print('Minister left notification sent to consultant: $consultantId');
      }

      if (floorManagerId != null) {
        await _firestore.collection('notifications').add(floorManagerNotification);
        print('Service completion notification sent to floor manager: $floorManagerId');
      } else {
        // If no specific floor manager, send to all floor managers
        final floorManagersQuery = await _firestore
            .collection('users')
            .where('role', isEqualTo: 'floor_manager')
            .get();

        for (var doc in floorManagersQuery.docs) {
          final notification = {
            ...floorManagerNotification,
            'assignedToId': doc.id,
          };
          await _firestore.collection('notifications').add(notification);
        }

        print('Service completion notification sent to all floor managers');
      }
    } catch (e) {
      print('Error sending service completion notifications: $e');
    }
  }
  
  // 6. Appointment cancelled - Notify all relevant parties
  Future<void> _handleAppointmentCancelledNotifications(
    String appointmentId,
    Map<String, dynamic> eventData,
  ) async {
    try {
      // 0. Free up reserved timeslots for the appointment
      try {
        final appointmentRef = _firestore.collection('appointments').doc(appointmentId);
        final appointmentSnap = await appointmentRef.get();
        if (appointmentSnap.exists) {
          final appointment = appointmentSnap.data() as Map<String, dynamic>;
          // Assume timeslots are stored as a list of slot IDs or objects under 'timeslots' or 'reservedSlots'
          final timeslotFields = ['timeslots', 'reservedSlots', 'slotIds'];
          String? foundField;
          List<dynamic>? slotsToFree;
          for (final field in timeslotFields) {
            if (appointment.containsKey(field) && appointment[field] != null && (appointment[field] as List).isNotEmpty) {
              foundField = field;
              slotsToFree = List.from(appointment[field]);
              break;
            }
          }
          if (slotsToFree != null && foundField != null) {
            // Free each slot (assume slots are documents in a 'timeslots' collection)
            for (final slotId in slotsToFree) {
              try {
                await _firestore.collection('timeslots').doc(slotId.toString()).update({'status': 'available', 'appointmentId': null});
              } catch (e) {
                print('Failed to free timeslot $slotId: $e');
              }
            }
            // Remove slots from appointment
            await appointmentRef.update({foundField: []});
            print('Freed reserved timeslots for appointment $appointmentId');

            // Update status to cancelled for minister dashboard
            await appointmentRef.update({'status': 'cancelled', 'cancelledAt': FieldValue.serverTimestamp()});
            print('Updated minister dashboard appointment status to cancelled for $appointmentId');
          } else {
            print('No reserved timeslots found for appointment $appointmentId');
          }
        }
      } catch (e) {
        print('Error freeing timeslots or updating status for cancelled appointment: $e');
      }
      
      final ministerName = eventData['ministerName'] ?? 'Minister';
      final serviceName = eventData['serviceName'] ?? 'your service';
      final formattedTime = DateFormat('MMM d, yyyy h:mm a').format(DateTime.now());
      final consultantId = eventData['consultantId'];
      final conciergeId = eventData['conciergeId'];
      final cleanerId = eventData['cleanerId'];
      final floorManagerId = eventData['floorManagerId'];
      final ministerId = eventData['ministerId'];

      // 1. Notify all assigned staff (consultant, concierge, cleaner)
      final List<Map<String, dynamic>> staffList = [
        if (consultantId != null && consultantId != '') {'role': 'consultant', 'id': consultantId},
        if (conciergeId != null && conciergeId != '') {'role': 'concierge', 'id': conciergeId},
        if (cleanerId != null && cleanerId != '') {'role': 'cleaner', 'id': cleanerId},
      ];
      for (final staff in staffList) {
        await _firestore.collection('notifications').add({
          'title': 'Appointment Cancelled',
          'body': 'The $serviceName appointment with $ministerName on $formattedTime has been cancelled.',
          'receiverId': staff['id'],
          'type': 'appointment_cancelled',
          'appointmentId': appointmentId,
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
          'role': staff['role'],
          'sendAsPushNotification': true,
        });
      }

      // 2. Notify all floor managers
      final floorManagersQuery = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'floor_manager')
          .get();
      for (var doc in floorManagersQuery.docs) {
        await _firestore.collection('notifications').add({
          'title': 'Appointment Cancelled',
          'body': 'The $serviceName appointment with $ministerName on $formattedTime has been cancelled.',
          'assignedToId': doc.id,
          'type': 'appointment_cancelled',
          'appointmentId': appointmentId,
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
          'role': 'floor_manager',
          'sendAsPushNotification': true,
        });
      }

      // 3. Optionally notify the minister
      if (ministerId != null && ministerId != '') {
        await _firestore.collection('notifications').add({
          'title': 'Appointment Cancelled',
          'body': 'Your $serviceName appointment on $formattedTime has been cancelled. If this is an error, please contact support.',
          'assignedToId': ministerId,
          'type': 'appointment_cancelled',
          'appointmentId': appointmentId,
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
          'role': 'minister',
          'sendAsPushNotification': true,
        });
      }
    } catch (e) {
      print('Error sending cancellation notifications: $e');
    }
  }
  
  // 7. Staff assigned - Notify assigned consultant and concierge with appointment details
  Future<void> _handleStaffAssignedNotifications(
    String appointmentId, 
    Map<String, dynamic> eventData
  ) async {
    try {
      final appointmentDate = eventData['appointmentTime'] is Timestamp
          ? DateFormat('EEEE, MMM d, yyyy').format((eventData['appointmentTime'] as Timestamp).toDate())
          : 'Date not set';
      final appointmentTime = eventData['appointmentTime'] is Timestamp
          ? DateFormat('h:mm a').format((eventData['appointmentTime'] as Timestamp).toDate())
          : 'Time not set';
      final ministerFullName = (eventData['ministerName'] ?? eventData['ministerFirstName'] ?? '') + (eventData['ministerLastName'] != null ? ' ${eventData['ministerLastName']}' : '');
      final ministerPhone = eventData['ministerPhone'] ?? '';
      final ministerEmail = eventData['ministerEmail'] ?? '';
      final consultantName = eventData['consultantName'] ?? '';
      final conciergeName = eventData['conciergeName'] ?? '';
      final serviceCategory = eventData['serviceCategory'] ?? '';
      final subServiceName = eventData['subServiceName'] ?? '';
      final venueId = eventData['venueId'] ?? '';
      final duration = eventData['duration'] != null ? eventData['duration'].toString() : '';
      final status = eventData['status'] ?? '';
      final assignedBy = eventData['assignedBy'] ?? '';
      final createdAt = eventData['createdAt'] != null ? eventData['createdAt'].toString() : '';
      final updatedAt = eventData['updatedAt'] != null ? eventData['updatedAt'].toString() : '';

      final detailsBody =
        'Minister: $ministerFullName\n'
        'Phone: $ministerPhone\n'
        'Email: $ministerEmail\n'
        'Consultant: $consultantName\n'
        'Concierge: $conciergeName\n'
        'Service: ${eventData['serviceName'] ?? ''}\n'
        'Category: $serviceCategory\n'
        'Sub-Service: $subServiceName\n'
        'Venue: ${eventData['venueName'] ?? ''} ($venueId)\n'
        'Date: $appointmentDate\n'
        'Time: $appointmentTime\n'
        'Duration: $duration min\n'
        'Status: $status\n'
        'Assigned by: $assignedBy\n'
        'Created at: $createdAt\n'
        'Updated at: $updatedAt';

      final consultantId = eventData['consultantId'];
      final conciergeId = eventData['conciergeId'];

      final List<Map<String, dynamic>> staffList = [
        if (consultantId != null && consultantId != '') {'role': 'consultant', 'id': consultantId},
        if (conciergeId != null && conciergeId != '') {'role': 'concierge', 'id': conciergeId},
      ];
      for (final staff in staffList) {
        await _firestore.collection('notifications').add({
          'title': 'New Appointment Assigned',
          'body': detailsBody,
          'receiverId': staff['id'],
          'type': 'staff_assigned',
          'appointmentId': appointmentId,
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
          'role': staff['role'],
          'sendAsPushNotification': true,
        });
      }
    } catch (e) {
      print('Error sending staff assigned notifications: $e');
    }
  }
  
  // Helper method to get minister name from appointment data
  String _getMinisterName(Map<String, dynamic> appointmentData) {
    if (appointmentData['ministerName'] != null) {
      return appointmentData['ministerName'];
    } else if (appointmentData['ministerFirstName'] != null && appointmentData['ministerLastName'] != null) {
      return '${appointmentData['ministerFirstName']} ${appointmentData['ministerLastName']}';
    }
    return 'Minister';
  }
}
