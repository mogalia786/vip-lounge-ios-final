import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:vip_lounge/features/shared/utils/app_update_helper.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/providers/app_auth_provider.dart';
import 'package:vip_lounge/core/services/vip_notification_service.dart';
import '../../../../core/services/notification_service.dart';
import 'appointments_screen.dart';
import 'package:vip_lounge/features/minister/presentation/screens/concierge_closed_day_helper.dart';
import 'staff_management_screen.dart';
import 'notifications_screen.dart';
import 'floor_manager_query_inbox_screen.dart';
import 'floor_manager_chat_list_screen.dart';
import '../widgets/staff_assignment_dialog.dart';
import '../widgets/message_icon_widget.dart';

class FloorManagerHomeScreen extends StatefulWidget {
  const FloorManagerHomeScreen({super.key});

  @override
  State<FloorManagerHomeScreen> createState() => _FloorManagerHomeScreenState();
}

class _FloorManagerHomeScreenState extends State<FloorManagerHomeScreen> {
  int _unreadNotifications = 0;
  int _unreadMessages = 0;
  DateTime _selectedDate = DateTime.now();
  final ScrollController _horizontalScrollController = ScrollController();

  // --- NOTIFICATION DEBUG PRINTS ---
  void _initializePushNotificationDebug() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('[Debug] FCM notification with message [33m${message.notification?.body ?? message.data}[0m OK');
    });
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('[Debug] FCM notification (opened app) with message [34m${message.notification?.body ?? message.data}[0m OK');
    });
  }

  @override
  void initState() {
    super.initState();
    // Silwela in-app update check
    _initializePushNotificationDebug();
    _listenToUnreadNotifications();
    _listenToUnreadMessages();
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    super.dispose();
  }

  void _listenToUnreadNotifications() {
    final user = Provider.of<AppAuthProvider>(context, listen: false).appUser;
    final userId = user?.uid;
    if (userId == null) return;
    FirebaseFirestore.instance
        .collection('notifications')
        .where('assignedToId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _unreadNotifications = snapshot.docs.length;
        });
      }
    });
  }

  void _listenToUnreadMessages() {
    final user = Provider.of<AppAuthProvider>(context, listen: false).appUser;
    final userId = user?.uid;
    if (userId == null) return;
    
    // Listen for unread messages where floor manager is the receiver
    FirebaseFirestore.instance
        .collection('messages')
        .where('receiverId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _unreadMessages = snapshot.docs.length;
        });
      }
    });
  }
  
  // Method to assign staff to an appointment
  Future<void> _assignStaff(String appointmentId, String staffType, String staffName, String staffId) async {
    // Fetch user contact info from users collection
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(staffId).get();
    final userData = userDoc.data() ?? {};
    final String phone = userData['phoneNumber'] ?? '';
    final String email = userData['email'] ?? '';
    final String fullName = ((userData['firstName'] ?? '') + ' ' + (userData['lastName'] ?? '')).trim();

    // Prepare update data
    final updateData = <String, dynamic>{};
    if (staffType == 'consultant') {
      updateData['consultantId'] = staffId;
      updateData['consultantName'] = fullName.isNotEmpty ? fullName : staffName;
      updateData['consultantPhone'] = phone;
      updateData['consultantEmail'] = email;
    } else if (staffType == 'concierge') {
      updateData['conciergeId'] = staffId;
      updateData['conciergeName'] = fullName.isNotEmpty ? fullName : staffName;
      updateData['conciergePhone'] = phone;
      updateData['conciergeEmail'] = email;
    }
    // Always initialize all session fields
    updateData['consultantSessionStarted'] = false;
    updateData['consultantSessionEnded'] = false;
    updateData['conciergeSessionStarted'] = false;
    updateData['conciergeSessionEnded'] = false;
    await FirebaseFirestore.instance.collection('appointments').doc(appointmentId).update(updateData);
    // Existing notification/activity logic continues below (unchanged)
  
    try {
      // Get the current floor manager's ID
      final user = Provider.of<AppAuthProvider>(context, listen: false).appUser;
      final floorManagerId = user?.uid;
      final floorManagerName = user?.name ?? 'Floor Manager';

      // Get the appointment data first to include in activity log
      final appointmentDoc = await FirebaseFirestore.instance
          .collection('appointments')
          .doc(appointmentId)
          .get();

      if (!appointmentDoc.exists) {
        throw Exception('Appointment not found');
      }

      final appointmentData = appointmentDoc.data();

      // Get full minister data to ensure we have the complete name
      String ministerName = 'Unknown Minister';
      if (appointmentData != null && appointmentData['ministerId'] != null) {
        final ministerDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(appointmentData['ministerId'])
            .get();

        if (ministerDoc.exists) {
          final ministerData = ministerDoc.data();
          ministerName = ministerData?['name'] ??
                        (ministerData?['firstName'] != null && ministerData?['lastName'] != null ?
                        '${ministerData?['firstName']} ${ministerData?['lastName']}' :
                        appointmentData['ministerName'] ?? 'Unknown Minister');
        } else {
          ministerName = appointmentData['ministerName'] ?? 'Unknown Minister';
        }
      }

      final appointmentTime = appointmentData?['appointmentTime'];
      final venueName = appointmentData?['venueName'] ?? 'No venue';
      final serviceName = appointmentData?['serviceName'] ?? '';
      final ministerId = appointmentData?['ministerId'] ?? '';
      final consultantId = appointmentData?['consultantId'] ?? (staffType == 'consultant' ? staffId : '');
      final consultantName = appointmentData?['consultantName'] ?? (staffType == 'consultant' ? (fullName.isNotEmpty ? fullName : staffName) : '');
      final consultantPhone = appointmentData?['consultantPhone'] ?? (staffType == 'consultant' ? phone : '');
      final consultantEmail = appointmentData?['consultantEmail'] ?? (staffType == 'consultant' ? email : '');
      final conciergeId = appointmentData?['conciergeId'] ?? (staffType == 'concierge' ? staffId : '');
      final conciergeName = appointmentData?['conciergeName'] ?? (staffType == 'concierge' ? (fullName.isNotEmpty ? fullName : staffName) : '');
      final conciergePhone = appointmentData?['conciergePhone'] ?? (staffType == 'concierge' ? phone : '');
      final conciergeEmail = appointmentData?['conciergeEmail'] ?? (staffType == 'concierge' ? email : '');
      final cleanerId = appointmentData?['cleanerId'] ?? (staffType == 'cleaner' ? staffId : '');
      final cleanerName = appointmentData?['cleanerName'] ?? (staffType == 'cleaner' ? staffName : '');

      // Merge all update fields
      final mergedUpdateData = <String, dynamic>{
        // Contact info
        if (staffType == 'consultant')
          ...{
            'consultantId': staffId,
            'consultantName': consultantName,
            'consultantPhone': consultantPhone,
            'consultantEmail': consultantEmail,
          },
        if (staffType == 'concierge')
          ...{
            'conciergeId': staffId,
            'conciergeName': conciergeName,
            'conciergePhone': conciergePhone,
            'conciergeEmail': conciergeEmail,
          },
        // Audit info
        '${staffType}Id': staffId,
        '${staffType}Name': fullName.isNotEmpty ? fullName : staffName,
        'updatedAt': FieldValue.serverTimestamp(),
        'lastUpdatedBy': floorManagerId,
        'lastUpdatedByName': floorManagerName,
      };

      await FirebaseFirestore.instance.collection('appointments').doc(appointmentId).update(mergedUpdateData);

      // Track the assignment in staff_activities collection
      await FirebaseFirestore.instance.collection('staff_activities').add({
        'staffId': staffId,
        'staffName': fullName.isNotEmpty ? fullName : staffName,
        'staffType': staffType,
        'activityType': 'assignment',
        'appointmentId': appointmentId,
        'ministerName': ministerName,
        'venueName': venueName,
        'appointmentTime': appointmentTime,
        'assignedBy': floorManagerId,
        'assignedByName': floorManagerName,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'assigned',
      });

      // Send notifications to assigned staff (consultant, concierge, cleaner)
      if (consultantId != null && consultantId.toString().isNotEmpty) {
        await VipNotificationService().createNotification(
          title: 'New Appointment Assigned',
          body: 'You have been assigned to a new appointment. Minister: $ministerName, Service: $serviceName, Venue: $venueName.',
          data: {
            ...appointmentData ?? {},
            'appointmentId': appointmentId,
            'staffType': 'consultant',
            'consultantName': consultantName,
            'consultantPhone': consultantPhone,
            'consultantEmail': consultantEmail,
            'conciergeName': conciergeName,
            'conciergePhone': conciergePhone,
            'conciergeEmail': conciergeEmail,
            'serviceName': serviceName,
            'venueName': venueName,
            'appointmentTime': appointmentTime,
            'ministerName': ministerName,
          },
          role: 'consultant',
          assignedToId: consultantId,
          notificationType: 'booking_assigned',
        );
      }
      if (conciergeId != null && conciergeId.toString().isNotEmpty) {
        await VipNotificationService().createNotification(
          title: 'New Appointment Assigned',
          body: 'You have been assigned to a new appointment. Minister: $ministerName, Service: $serviceName, Venue: $venueName.',
          data: {
            ...appointmentData ?? {},
            'appointmentId': appointmentId,
            'staffType': 'concierge',
            'consultantName': consultantName,
            'consultantPhone': consultantPhone,
            'consultantEmail': consultantEmail,
            'conciergeName': conciergeName,
            'conciergePhone': conciergePhone,
            'conciergeEmail': conciergeEmail,
            'serviceName': serviceName,
            'venueName': venueName,
            'appointmentTime': appointmentTime,
            'ministerName': ministerName,
          },
          role: 'concierge',
          assignedToId: conciergeId,
          notificationType: 'booking_assigned',
        );
      }
      if (cleanerId != null && cleanerId.toString().isNotEmpty) {
        await VipNotificationService().createNotification(
          title: 'New Appointment Assigned',
          body: 'You have been assigned to a new appointment. Minister: $ministerName, Service: $serviceName, Venue: $venueName.',
          data: {
            ...appointmentData ?? {},
            'appointmentId': appointmentId,
            'staffType': 'cleaner',
            'consultantName': consultantName,
            'consultantPhone': consultantPhone,
            'consultantEmail': consultantEmail,
            'conciergeName': conciergeName,
            'conciergePhone': conciergePhone,
            'conciergeEmail': conciergeEmail,
            'serviceName': serviceName,
            'venueName': venueName,
            'appointmentTime': appointmentTime,
            'ministerName': ministerName,
          },
          role: 'cleaner',
          assignedToId: cleanerId,
          notificationType: 'booking_assigned',
        );
      }
      // If both consultant and concierge are assigned (not cleaner), notify minister with two detailed notifications
      if (
        consultantId != null && consultantId.toString().isNotEmpty &&
        conciergeId != null && conciergeId.toString().isNotEmpty
      ) {
        // Consultant notification
        await VipNotificationService().createNotification(
          title: 'Consultant Assigned to Your Appointment',
          body: 'Your consultant is $consultantName. You can contact them at ${consultantPhone.isNotEmpty ? consultantPhone : 'N/A'} or $consultantEmail.',
          data: {
            ...appointmentData ?? {},
            'appointmentId': appointmentId,
            'staffType': 'consultant',
            'consultantId': consultantId,
            'consultantName': consultantName,
            'consultantPhone': consultantPhone,
            'consultantEmail': consultantEmail,
            'serviceName': serviceName,
            'venueName': venueName,
            'appointmentTime': appointmentTime,
            'ministerName': ministerName,
          },
          role: 'minister',
          assignedToId: ministerId,
          notificationType: 'booking_assigned',
        );
        // Concierge notification
        await VipNotificationService().createNotification(
          title: 'Concierge Assigned to Your Appointment',
          body: 'Your concierge is $conciergeName. You can contact them at ${conciergePhone.isNotEmpty ? conciergePhone : 'N/A'} or $conciergeEmail.',
          data: {
            ...appointmentData ?? {},
            'appointmentId': appointmentId,
            'staffType': 'concierge',
            'conciergeId': conciergeId,
            'conciergeName': conciergeName,
            'conciergePhone': conciergePhone,
            'conciergeEmail': conciergeEmail,
            'serviceName': serviceName,
            'venueName': venueName,
            'appointmentTime': appointmentTime,
            'ministerName': ministerName,
          },
          role: 'minister',
          assignedToId: ministerId,
          notificationType: 'booking_assigned',
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$staffType assigned successfully')),
      );
    } catch (e) {
      final user = Provider.of<AppAuthProvider>(context, listen: false).appUser;
      final floorManagerId = user?.uid;
      final floorManagerName = user?.name ?? 'Floor Manager';
      
      // Get the appointment data first to include in activity log
      final appointmentDoc = await FirebaseFirestore.instance
          .collection('appointments')
          .doc(appointmentId)
          .get();
      
      if (!appointmentDoc.exists) {
        throw Exception('Appointment not found');
      }
      
      final appointmentData = appointmentDoc.data();
      
      // Get full minister data to ensure we have the complete name
      String ministerName = 'Unknown Minister';
      if (appointmentData != null && appointmentData['ministerId'] != null) {
        final ministerDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(appointmentData['ministerId'])
            .get();
            
        if (ministerDoc.exists) {
          final ministerData = ministerDoc.data();
          ministerName = ministerData?['name'] ?? 
                        (ministerData?['firstName'] != null && ministerData?['lastName'] != null ? 
                        '${ministerData?['firstName']} ${ministerData?['lastName']}' : 
                        appointmentData['ministerName'] ?? 'Unknown Minister');
        } else {
          ministerName = appointmentData['ministerName'] ?? 'Unknown Minister';
        }
      }
      
      final appointmentTime = appointmentData?['appointmentTime'];
      final venueName = appointmentData?['venueName'] ?? 'No venue';
      
      // Update appointment in Firestore with all necessary fields
      final updateData = {
        '${staffType}Id': staffId,
        '${staffType}Name': staffName,
        'updatedAt': FieldValue.serverTimestamp(),
        'lastUpdatedBy': floorManagerId,
        'lastUpdatedByName': floorManagerName,
      };
      
      // Track the assignment in staff_activities collection
      await FirebaseFirestore.instance.collection('staff_activities').add({
        'staffId': staffId,
        'staffName': staffName,
        'staffType': staffType,
        'activityType': 'assignment',
        'appointmentId': appointmentId,
        'ministerName': ministerName,
        'venueName': venueName,
        'appointmentTime': appointmentTime,
        'assignedBy': floorManagerId,
        'assignedByName': floorManagerName,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'assigned', // Initial status when assigned
      });
      
      // Gather all assigned staff IDs and names
      final consultantId = appointmentData?['consultantId'] ?? (staffType == 'consultant' ? staffId : '');
      final consultantName = appointmentData?['consultantName'] ?? (staffType == 'consultant' ? staffName : '');
      final consultantPhone = appointmentData?['consultantPhone'] ?? '';
      final conciergeId = appointmentData?['conciergeId'] ?? (staffType == 'concierge' ? staffId : '');
      final conciergeName = appointmentData?['conciergeName'] ?? (staffType == 'concierge' ? staffName : '');
      final conciergePhone = appointmentData?['conciergePhone'] ?? '';
      final cleanerId = appointmentData?['cleanerId'] ?? (staffType == 'cleaner' ? staffId : '');
      final cleanerName = appointmentData?['cleanerName'] ?? (staffType == 'cleaner' ? staffName : '');
      final serviceName = appointmentData?['serviceName'] ?? '';
      final ministerId = appointmentData?['ministerId'] ?? '';
      final appointmentIdForNotif = appointmentId;

      // Send notifications to assigned staff (consultant, concierge, cleaner)
      if (consultantId != null && consultantId.toString().isNotEmpty) {
        await VipNotificationService().createNotification(
          title: 'New Appointment Assigned',
          body: 'You have been assigned to a new appointment. Minister: $ministerName, Service: $serviceName, Venue: $venueName.',
          data: {
            ...appointmentData ?? {},
            'appointmentId': appointmentIdForNotif,
            'staffType': 'consultant',
            'consultantName': consultantName,
            'consultantPhone': consultantPhone,
            'conciergeName': conciergeName,
            'conciergePhone': conciergePhone,
            'serviceName': serviceName,
            'venueName': venueName,
            'appointmentTime': appointmentTime,
            'ministerName': ministerName,
          },
          role: 'consultant',
          assignedToId: consultantId,
          notificationType: 'booking_assigned',
        );
      }
      if (conciergeId != null && conciergeId.toString().isNotEmpty) {
        await VipNotificationService().createNotification(
          title: 'New Appointment Assigned',
          body: 'You have been assigned to a new appointment. Minister: $ministerName, Service: $serviceName, Venue: $venueName.',
          data: {
            ...appointmentData ?? {},
            'appointmentId': appointmentIdForNotif,
            'staffType': 'concierge',
            'consultantName': consultantName,
            'consultantPhone': consultantPhone,
            'conciergeName': conciergeName,
            'conciergePhone': conciergePhone,
            'serviceName': serviceName,
            'venueName': venueName,
            'appointmentTime': appointmentTime,
            'ministerName': ministerName,
          },
          role: 'concierge',
          assignedToId: conciergeId,
          notificationType: 'booking_assigned',
        );
      }
      if (cleanerId != null && cleanerId.toString().isNotEmpty) {
        await VipNotificationService().createNotification(
          title: 'New Appointment Assigned',
          body: 'You have been assigned to a new appointment. Minister: $ministerName, Service: $serviceName, Venue: $venueName.',
          data: {
            ...appointmentData ?? {},
            'appointmentId': appointmentIdForNotif,
            'staffType': 'cleaner',
            'consultantName': consultantName,
            'conciergeName': conciergeName,
            'serviceName': serviceName,
            'venueName': venueName,
            'appointmentTime': appointmentTime,
            'ministerName': ministerName,
          },
          role: 'cleaner',
          assignedToId: cleanerId,
          notificationType: 'booking_assigned',
        );
      }
      // If both consultant and concierge are assigned (not cleaner), notify minister with two detailed notifications
      if (
        consultantId != null && consultantId.toString().isNotEmpty &&
        conciergeId != null && conciergeId.toString().isNotEmpty
      ) {
        // Consultant notification
        await VipNotificationService().createNotification(
          title: 'Consultant Assigned to Your Appointment',
          body: 'Your consultant is $consultantName. You can contact them at ${consultantPhone.isNotEmpty ? consultantPhone : 'N/A'} or ${appointmentData?['consultantEmail'] ?? ''}.',
          data: {
            ...appointmentData ?? {},
            'appointmentId': appointmentIdForNotif,
            'staffType': 'consultant',
            'consultantId': consultantId,
            'consultantName': consultantName,
            'consultantPhone': consultantPhone,
            'consultantEmail': appointmentData?['consultantEmail'] ?? '',
            'serviceName': serviceName,
            'venueName': venueName,
            'appointmentTime': appointmentTime,
            'ministerName': ministerName,
          },
          role: 'minister',
          assignedToId: ministerId,
          notificationType: 'booking_assigned',
        );
        // Concierge notification
        await VipNotificationService().createNotification(
          title: 'Concierge Assigned to Your Appointment',
          body: 'Your concierge is $conciergeName. You can contact them at ${conciergePhone.isNotEmpty ? conciergePhone : 'N/A'} or ${appointmentData?['conciergeEmail'] ?? ''}.',
          data: {
            ...appointmentData ?? {},
            'appointmentId': appointmentIdForNotif,
            'staffType': 'concierge',
            'conciergeId': conciergeId,
            'conciergeName': conciergeName,
            'conciergePhone': conciergePhone,
            'conciergeEmail': appointmentData?['conciergeEmail'] ?? '',
            'serviceName': serviceName,
            'venueName': venueName,
            'appointmentTime': appointmentTime,
            'ministerName': ministerName,
          },
          role: 'minister',
          assignedToId: ministerId,
          notificationType: 'booking_assigned',
        );
      }
      
      // Update the appointment document
      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(appointmentId)
          .update(updateData);
      
      // Send notification to the assigned staff
      await _sendAssignmentNotification(staffId, staffType, appointmentId);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$staffType assigned successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
  
  Future<void> _sendAssignmentNotification(String staffId, String staffType, String appointmentId) async {
    try {
      // Get appointment details to include in the notification
      final appointmentDoc = await FirebaseFirestore.instance
          .collection('appointments')
          .doc(appointmentId)
          .get();
      
      if (!appointmentDoc.exists) {
        print('Appointment not found when creating notification');
        return;
      }
      
      final appointmentData = appointmentDoc.data() as Map<String, dynamic>;
      final ministerName = appointmentData['ministerName'] ?? 'Unknown Minister';
      final appointmentTime = appointmentData['appointmentTime'] as Timestamp?;
      final formattedTime = appointmentTime != null 
          ? DateFormat('dd MMM yyyy, hh:mm a').format(appointmentTime.toDate()) 
          : 'Unknown time';
      final venueName = appointmentData['venueName'] ?? 'Unknown venue';
      
      // Get the current floor manager information
      final user = Provider.of<AppAuthProvider>(context, listen: false).appUser;
      final floorManagerName = user?.name ?? 'Floor Manager';
      
      // Create notification content
      final title = 'New $staffType Assignment';
      final body = 'You have been assigned to assist $ministerName on $formattedTime at $venueName';
      
      // 1. Create in-app display notification in Firestore
      await FirebaseFirestore.instance.collection('notifications').add({
        'title': title,
        'body': body,
        'receiverId': staffId,
        'type': 'appointment_assigned',
        'appointmentId': appointmentId,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'role': staffType,
        'senderName': floorManagerName,
        'ministerName': ministerName,
        'appointmentTime': appointmentTime,
        'venueName': venueName,
      });
      
      // 2. Attempt to send FCM push notification if token is available
      try {
        final staffDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(staffId)
            .get();
            
        if (staffDoc.exists) {
          final fcmToken = staffDoc.data()?['fcmToken'];
          
          if (fcmToken != null) {
            // Use the notification service to create notification
            await NotificationService().createNotification(
              title: title,
              body: body,
              data: {
                'type': 'appointment_assigned',
                'appointmentId': appointmentId,
                'staffType': staffType,
                'ministerName': ministerName,
                'appointmentTime': appointmentTime,
                'venueName': venueName,
              },
              role: staffType,
              assignedToId: staffId,
            );
            
            print('Push notification sent to $staffType with ID: $staffId');
          } else {
            print('No FCM token found for $staffType with ID: $staffId');
          }
        }
      } catch (e) {
        print('Error sending push notification: $e');
        // Don't rethrow - we don't want to fail the entire assignment if just the push notification fails
      }
    } catch (e) {
      print('Error in notification system: $e');
    }
  }
  
  Future<void> _sendThankYouToMinister(String appointmentId) async {
    try {
      // Fetch appointment to get ministerId and ministerName
      final doc = await FirebaseFirestore.instance.collection('appointments').doc(appointmentId).get();
      if (!doc.exists) return;
      final data = doc.data() ?? {};
      final ministerId = data['ministerId'] ?? '';
      final ministerName = data['ministerName'] ?? 'Minister';
      if (ministerId.isEmpty) return;
      final message = 'Thank you for attending. If you have any queries, please log them using your booking ID: $appointmentId.';
      await FirebaseFirestore.instance.collection('notifications').add({
        'title': 'Thank you for attending',
        'body': message,
        'receiverId': ministerId,
        'type': 'thank_you',
        'appointmentId': appointmentId,
        'senderRole': 'floor_manager',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });
    } catch (e) {
      print('Error sending thank you notification to minister: $e');
    }
  }
  
  // Call this after appointment is marked completed
  Future<void> completeAppointmentAndNotifyMinister(String appointmentId) async {
    try {
      // Mark appointment as completed
      await FirebaseFirestore.instance.collection('appointments').doc(appointmentId).update({
        'status': 'completed',
        'completionTime': DateTime.now(),
      });
      // Send thank you notification to minister
      await _sendThankYouToMinister(appointmentId);
    } catch (e) {
      print('Error completing appointment and notifying minister: $e');
    }
  }
  
  // Helper method to get status color
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'assigned':
        return Colors.blue;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
  
  // Helper method to get status text display
  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return 'COMPLETED';
      case 'cancelled':
        return 'CANCELLED';
      case 'assigned':
        return 'ASSIGNED';
      case 'pending':
        return 'PENDING';
      default:
        return status.toUpperCase();
    }
  }
  
  void _openChatDialog(BuildContext context, String appointmentId, String recipientId, String recipientName, String recipientRole) {
    final TextEditingController messageController = TextEditingController();
    
    // Mark notifications as read
    FirebaseFirestore.instance
        .collection('notifications')
        .where('appointmentId', isEqualTo: appointmentId)
        .where('role', isEqualTo: 'floor_manager')
        .where('isRead', isEqualTo: false)
        .get()
        .then((snapshot) {
          for (var doc in snapshot.docs) {
            doc.reference.update({'isRead': true});
          }
        });
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        title: Text('Chat with $recipientName', style: TextStyle(color: AppColors.gold)),
        content: Container(
          width: double.maxFinite,
          height: 300,
          child: Column(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('chats')
                      .doc(appointmentId)
                      .collection('messages')
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return Center(child: CircularProgressIndicator(color: AppColors.gold));
                    }
                    
                    final messages = snapshot.data!.docs;
                    if (messages.isEmpty) {
                      return Center(child: Text('No messages yet', style: TextStyle(color: Colors.grey)));
                    }
                    
                    return ListView.builder(
                      reverse: true,
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index].data() as Map<String, dynamic>;
                        final isMe = message['senderRole'] == 'floor_manager';
                        
                        // Get the timestamp for messages
                        final timestamp = message['timestamp'] as Timestamp?;
                        final DateTime? messageTime = timestamp?.toDate();
                        final String timeText = messageTime != null 
                            ? DateFormat('MMM d, h:mm a').format(messageTime)
                            : '';
                        
                        return Column(
                          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            Align(
                              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isMe ? AppColors.gold : Colors.grey[800],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      message['text'],
                                      style: TextStyle(color: isMe ? Colors.black : Colors.white),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      timeText,
                                      style: TextStyle(
                                        color: isMe ? Colors.black54 : Colors.grey[400],
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(height: 4),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: TextField(
                  controller: messageController,
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: Colors.grey[900],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(Icons.send, color: AppColors.gold),
                      onPressed: () {
                        final message = messageController.text;
                        if (message.trim().isNotEmpty) {
                          // Get current user ID from provider
                          final currentUser = Provider.of<AppAuthProvider>(context, listen: false).appUser;
                          final floorManagerId = currentUser?.uid ?? 'unknown';
                          
                          // Send message
                          FirebaseFirestore.instance.collection('chats').doc(appointmentId).collection('messages').add({
                            'appointmentId': appointmentId,
                            'text': message,
                            'senderId': floorManagerId,
                            'senderRole': 'floor_manager',
                            'recipientId': recipientId,
                            'recipientRole': recipientRole,
                            'timestamp': FieldValue.serverTimestamp(),
                          }).then((_) {
                            // Create a notification for the recipient about this message
                            if (recipientRole == 'minister') {
                              // Get floor manager name
                              FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(floorManagerId)
                                  .get()
                                  .then((userDoc) {
                                if (userDoc.exists) {
                                  final floorManagerName = 
                                      '${userDoc.data()?['firstName'] ?? 'Floor Manager'} ${userDoc.data()?['lastName'] ?? ''}';
                                  
                                  // Create notification for minister
                                  FirebaseFirestore.instance.collection('notifications').add({
                                    'title': 'New Message',
                                    'body': 'Floor Manager $floorManagerName sent you a message',
                                    'isRead': false,
                                    'createdAt': FieldValue.serverTimestamp(),
                                    'role': 'minister',
                                    'ministerId': recipientId,
                                    'appointmentId': appointmentId, 
                                    'senderId': floorManagerId,
                                    'senderRole': 'floor_manager',
                                    'senderName': floorManagerName,
                                    'notificationType': 'chat',
                                    'messageText': message,
                                    'name': floorManagerName,
                                    'email': userDoc.data()?['email'] ?? 'No email provided',
                                    'phone': userDoc.data()?['phoneNumber'] ?? 'No phone provided',
                                  });
                                }
                              });
                            }
                          });
                          
                          // Clear text field
                          messageController.clear();
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: AppColors.gold)),
          ),
        ],
      ),
    );
  }
  
  // Method to open chat dialog with the user who made the booking
  void _openUserMessageDialog(BuildContext context, Map<String, dynamic> appointment, String appointmentId) {
    final TextEditingController messageController = TextEditingController();
    final userId = appointment['ministerId'] ?? '';
    final userName = '${appointment['ministerFirstName'] ?? ''} ${appointment['ministerLastName'] ?? ''}';
    
    // Mark notifications as read
    FirebaseFirestore.instance
        .collection('notifications')
        .where('appointmentId', isEqualTo: appointmentId)
        .where('role', isEqualTo: 'floor_manager')
        .where('isRead', isEqualTo: false)
        .get()
        .then((snapshot) {
          for (var doc in snapshot.docs) {
            doc.reference.update({'isRead': true});
          }
        });
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Message to $userName', style: TextStyle(color: AppColors.gold)),
        content: Container(
          width: double.maxFinite,
          height: 300,
          child: Column(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('chats')
                      .doc(appointmentId)
                      .collection('messages')
                      .where('recipientRole', isEqualTo: 'minister')
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return Center(child: CircularProgressIndicator(color: AppColors.gold));
                    }
                    
                    final messages = snapshot.data!.docs;
                    if (messages.isEmpty) {
                      return Center(child: Text('No messages yet', style: TextStyle(color: Colors.grey)));
                    }
                    
                    return ListView.builder(
                      reverse: true,
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index].data() as Map<String, dynamic>;
                        final isMe = message['senderRole'] == 'floor_manager';
                        
                        // Get the timestamp for messages
                        final timestamp = message['timestamp'] as Timestamp?;
                        final DateTime? messageTime = timestamp?.toDate();
                        final String timeText = messageTime != null 
                            ? DateFormat('MMM d, h:mm a').format(messageTime)
                            : '';
                        
                        return Column(
                          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            Align(
                              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isMe ? AppColors.gold : Colors.grey[800],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      message['text'],
                                      style: TextStyle(color: isMe ? Colors.black : Colors.white),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      timeText,
                                      style: TextStyle(
                                        color: isMe ? Colors.black54 : Colors.grey[400],
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(height: 4),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: TextField(
                  controller: messageController,
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: Colors.grey[900],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(Icons.send, color: AppColors.gold),
                      onPressed: () {
                        final message = messageController.text;
                        if (message.trim().isNotEmpty) {
                          // Get current user ID from provider
                          final currentUser = Provider.of<AppAuthProvider>(context, listen: false).appUser;
                          final floorManagerId = currentUser?.uid ?? 'unknown';
                          
                          // Send message
                          FirebaseFirestore.instance.collection('chats').doc(appointmentId).collection('messages').add({
                            'appointmentId': appointmentId,
                            'text': message,
                            'senderId': floorManagerId,
                            'senderRole': 'floor_manager',
                            'recipientId': userId,
                            'recipientRole': 'minister',
                            'timestamp': FieldValue.serverTimestamp(),
                          }).then((_) {
                            // Create notification for the user
                            FirebaseFirestore.instance
                                .collection('users')
                                .doc(floorManagerId)
                                .get()
                                .then((userDoc) {
                              if (userDoc.exists) {
                                final floorManagerName = 
                                    '${userDoc.data()?['firstName'] ?? 'Floor Manager'} ${userDoc.data()?['lastName'] ?? ''}';
                                
                                FirebaseFirestore.instance.collection('notifications').add({
                                  'title': 'New Message',
                                  'body': 'Floor Manager $floorManagerName sent you a message',
                                  'isRead': false,
                                  'createdAt': FieldValue.serverTimestamp(),
                                  'role': 'minister',
                                  'ministerId': userId,
                                  'appointmentId': appointmentId, 
                                  'senderId': floorManagerId,
                                  'senderRole': 'floor_manager',
                                  'senderName': floorManagerName,
                                  'notificationType': 'chat',
                                  'messageText': message,
                                  'name': floorManagerName,
                                  'email': userDoc.data()?['email'] ?? 'No email provided',
                                  'phone': userDoc.data()?['phoneNumber'] ?? 'No phone provided',
                                });
                              }
                            });
                          });
                          
                          // Clear text field
                          messageController.clear();
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text('Close', style: TextStyle(color: AppColors.gold)),
          ),
        ],
      ),
    );
  }
  
  // Function to show staff selection dialog
  void _showStaffSelectionDialog(BuildContext context, String appointmentId, String staffType) {
    showDialog(
      context: context,
      builder: (context) => FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('appointments').doc(appointmentId).get(),
        builder: (context, appointmentSnapshot) {
          if (!appointmentSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final appointmentData = appointmentSnapshot.data!.data() as Map<String, dynamic>;
          final appointmentTime = (appointmentData['appointmentTime'] as Timestamp).toDate();
          
          return FutureBuilder<QuerySnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .where('role', isEqualTo: staffType)
                .get(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              
              final staffMembers = snapshot.data!.docs;
              
              // Check availability for each staff member
              return FutureBuilder<List<QueryDocumentSnapshot>>(
                future: _getStaffAvailability(staffMembers, appointmentTime),
                builder: (context, availabilitySnapshot) {
                  if (!availabilitySnapshot.hasData) {
                    return const AlertDialog(
                      title: Text('Loading staff availability...'),
                      content: Center(child: CircularProgressIndicator()),
                    );
                  }
                  
                  final availableStaff = availabilitySnapshot.data!;
                  
                  if (availableStaff.isEmpty) {
                    return AlertDialog(
                      title: Text('No Available ${_capitalize(staffType)}s'),
                      content: Text(
                        'All ${_capitalize(staffType)}s are already booked for this time slot. Please try a different time or date.',
                        style: TextStyle(color: Colors.red),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'),
                        ),
                      ],
                    );
                  }
                  
                  return AlertDialog(
                    title: Text('Select ${_capitalize(staffType)}'),
                    content: Container(
                      width: double.maxFinite,
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: availableStaff.length,
                        itemBuilder: (context, index) {
                          final staff = availableStaff[index].data() as Map<String, dynamic>;
                          final staffId = availableStaff[index].id;
                          final staffName = staff['name'] ?? 'Unknown';
                          
                          return ListTile(
                            title: Text(staffName),
                            onTap: () {
                              Navigator.pop(context);
                              _assignStaff(appointmentId, staffType, staffName, staffId);
                            },
                          );
                        },
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
  
  // Helper method to capitalize first letter
  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }
  
  // Enhanced method to check staff availability for a specific time slot
  Future<List<QueryDocumentSnapshot>> _getStaffAvailability(
    List<QueryDocumentSnapshot> staffMembers, 
    DateTime appointmentTime
  ) async {
    // Define buffer time around appointment (e.g., 1 hour before and after)
    final appointmentStartBuffer = appointmentTime.subtract(Duration(hours: 1));
    final appointmentEndBuffer = appointmentTime.add(Duration(hours: 1));
    
    print('Checking staff availability for time slot: ${DateFormat('yyyy-MM-dd HH:mm').format(appointmentTime)}');
    print('Using buffer: ${DateFormat('HH:mm').format(appointmentStartBuffer)} - ${DateFormat('HH:mm').format(appointmentEndBuffer)}');
    
    // Get all appointments in the time range
    final appointmentsQuery = await FirebaseFirestore.instance
        .collection('appointments')
        .where('appointmentTime', isGreaterThanOrEqualTo: Timestamp.fromDate(appointmentStartBuffer))
        .where('appointmentTime', isLessThanOrEqualTo: Timestamp.fromDate(appointmentEndBuffer))
        .get();
    
    print('Found ${appointmentsQuery.docs.length} potentially conflicting appointments');
    
    final List<String> unavailableConsultantIds = [];
    final List<String> unavailableConciergeIds = [];
    final List<String> unavailableCleanerIds = [];
    
    // Identify unavailable staff
    for (var appointmentDoc in appointmentsQuery.docs) {
      final appointment = appointmentDoc.data();
      final appointmentId = appointmentDoc.id;
      
      // Skip the current appointment we're trying to assign (if updating existing assignment)
      if (appointmentDoc.id == appointmentId) continue;
      
      // Get the appointment time to check for actual conflict
      final appointmentTimestamp = appointment['appointmentTime'] as Timestamp?;
      if (appointmentTimestamp != null) {
        final appointmentDateTime = appointmentTimestamp.toDate();
        
        // Check if it's an actual time conflict (within +/- 1 hour)
        final difference = appointmentDateTime.difference(appointmentTime).inMinutes.abs();
        if (difference <= 60) { // If appointments are within 60 minutes of each other
          // Add consultants to unavailable list
          if (appointment['consultantId'] != null && appointment['consultantId'].toString().isNotEmpty) {
            unavailableConsultantIds.add(appointment['consultantId']);
            print('Unavailable consultant: ${appointment['consultantId']} (conflict with appointment ${appointmentDoc.id} at ${DateFormat('HH:mm').format(appointmentDateTime)})');
          }
          
          // Add concierges to unavailable list
          if (appointment['conciergeId'] != null && appointment['conciergeId'].toString().isNotEmpty) {
            unavailableConciergeIds.add(appointment['conciergeId']);
            print('Unavailable concierge: ${appointment['conciergeId']} (conflict with appointment ${appointmentDoc.id} at ${DateFormat('HH:mm').format(appointmentDateTime)})');
          }
          
          // Add cleaners to unavailable list
          if (appointment['cleanerId'] != null && appointment['cleanerId'].toString().isNotEmpty) {
            unavailableCleanerIds.add(appointment['cleanerId']);
            print('Unavailable cleaner: ${appointment['cleanerId']} (conflict with appointment ${appointmentDoc.id} at ${DateFormat('HH:mm').format(appointmentDateTime)})');
          }
        }
      }
    }
    
    // Filter staff members based on unavailability lists
    final availableStaff = staffMembers.where((staffDoc) {
      final staffId = staffDoc.id;
      final staffRole = (staffDoc.data() as Map<String, dynamic>)['role'];
      
      if (staffRole == 'consultant') {
        return !unavailableConsultantIds.contains(staffId);
      } else if (staffRole == 'concierge') {
        return !unavailableConciergeIds.contains(staffId);
      } else if (staffRole == 'cleaner') {
        return !unavailableCleanerIds.contains(staffId);
      }
      
      return true; // Default to available if role doesn't match
    }).toList();
    
    print('Available staff: ${availableStaff.length}');
    
    return availableStaff;
  }

  void _loadAppointments() {
    setState(() {});
  }

  Widget _buildDateScroll30Days() {
    final now = DateTime.now();
    final days = List.generate(30, (i) => DateTime(now.year, now.month, now.day).add(Duration(days: i)));
    return Container(
      color: Colors.greenAccent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
        child: SizedBox(
          height: 80, // Increased height for visibility
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: days.length,
            itemBuilder: (context, i) {
              final day = days[i];
              final isSelected = _selectedDate.year == day.year && _selectedDate.month == day.month && _selectedDate.day == day.day;
              // Debug print
              print('Building date item for: ' + day.toString());
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDate = day;
                    _loadAppointments();
                  });
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.redAccent : Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormat('E').format(day),
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('d').format(day),
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = Provider.of<AppAuthProvider>(context).appUser;
    final userName = currentUser != null ? currentUser.name ?? 'Floor Manager' : 'Floor Manager';
    
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Row(
          children: [
            Text(
              'Role: Floor Manager',
              style: TextStyle(
                color: AppColors.gold,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.verified, color: AppColors.gold, size: 22),
          ],
        ),
        actions: [
          // Chat icon using MessageIconWidget
          const MessageIconWidget(),
          // Search icon
          IconButton(
            icon: const Icon(Icons.search, color: AppColors.richGold),
            tooltip: 'Search',
            onPressed: () {
              // Search functionality to be implemented
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.richGold),
            tooltip: 'Logout',
            onPressed: () async {
              await Provider.of<AppAuthProvider>(context, listen: false).signOut();
              if (context.mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildDateScroll30Days(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('appointments')
                  .where('date', isEqualTo: DateFormat('yyyy-MM-dd').format(_selectedDate))
                  .orderBy('startTime', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator(color: AppColors.gold));
                }
                final appointments = snapshot.data!.docs;
                if (appointments.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_busy, color: Colors.grey, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          'No appointments for this day',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: appointments.length,
                  padding: const EdgeInsets.all(8),
                  itemBuilder: (context, index) {
                    final appointment = appointments[index].data() as Map<String, dynamic>;
                    final appointmentId = appointments[index].id;
                    
                    // Check if staff are assigned
                    final consultantAssigned = appointment['consultantId'] != null;
                    final cleanerAssigned = appointment['cleanerId'] != null;
                    final conciergeAssigned = appointment['conciergeId'] != null;
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.gold.withOpacity(0.5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header with minister info and time
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.gold.withOpacity(0.15),
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(8),
                                topRight: Radius.circular(8),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Minister ${appointment['ministerFirstName'] ?? ''} ${appointment['ministerLastName'] ?? ''}',
                                        style: TextStyle(
                                          color: AppColors.gold,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        appointment['appointmentTime'] != null
                                            ? DateFormat('h:mm a').format((appointment['appointmentTime'] as Timestamp).toDate())
                                            : 'Time not set',
                                        style: TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                
                                // Message buttons
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Row(
                                    children: [
                                      // Message to Minister
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: () {
                                            final ministerId = appointment['ministerId'] ?? '';
                                            final ministerName = '${appointment['ministerFirstName'] ?? ''} ${appointment['ministerLastName'] ?? ''}';
                                            _openChatDialog(context, appointmentId, 'minister', ministerId, ministerName);
                                          },
                                          icon: Icon(Icons.chat, size: 16, color: Colors.white),
                                          label: Text('Message Minister', style: TextStyle(color: Colors.white, fontSize: 11)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.blue,
                                            minimumSize: Size(0, 30),
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 10),
                                      // Message to User
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: () {
                                            _openUserMessageDialog(context, appointment, appointmentId);
                                          },
                                          icon: Icon(Icons.chat, size: 16, color: Colors.white),
                                          label: Text('Message User', style: TextStyle(color: Colors.white, fontSize: 11)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.orange,
                                            minimumSize: Size(0, 30),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                
                                // Status indicator
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(appointment['status'] ?? 'pending'),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _getStatusText(appointment['status'] ?? 'pending'),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Appointment details and service
                          Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Service: ${appointment['serviceName'] ?? 'Not specified'}',
                                        style: TextStyle(color: Colors.white, fontSize: 12),
                                      ),
                                    ),
                                    
                                    // Inbox button with notification indicator
                                    StreamBuilder<QuerySnapshot>(
                                      stream: FirebaseFirestore.instance
                                          .collection('notifications')
                                          .where('appointmentId', isEqualTo: appointmentId)
                                          .where('role', isEqualTo: 'floor_manager')
                                          .where('notificationType', isEqualTo: 'chat')
                                          .where('isRead', isEqualTo: false)
                                          .snapshots(),
                                      builder: (context, snapshot) {
                                        final hasUnread = snapshot.hasData && snapshot.data!.docs.isNotEmpty;
                                        
                                        return Stack(
                                          children: [
                                            ElevatedButton.icon(
                                              onPressed: () {
                                                final ministerId = appointment['ministerId'] ?? '';
                                                final ministerName = '${appointment['ministerFirstName'] ?? ''} ${appointment['ministerLastName'] ?? ''}';
                                                _openChatDialog(context, appointmentId, 'minister', ministerId, ministerName);
                                              },
                                              icon: Icon(Icons.inbox, color: Colors.white, size: 16),
                                              label: Text('Inbox', style: TextStyle(color: Colors.white, fontSize: 12)),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.blue,
                                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              ),
                                            ),
                                            if (hasUnread)
                                              Positioned(
                                                right: 2,
                                                top: 2,
                                                child: Container(
                                                  padding: EdgeInsets.all(4),
                                                  decoration: BoxDecoration(
                                                    color: Colors.red,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Text(
                                                    '${snapshot.data!.docs.length}',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 8,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        );
                                      },
                                    ),
                                  ],
                                ),
                                
                                const SizedBox(height: 8),
                                Divider(color: Colors.grey.withOpacity(0.3)),
                                const SizedBox(height: 8),
                                
                                // Staff assignment section
                                Row(
                                  children: [
                                    Expanded(
                                      child: Scrollbar(
                                        controller: _horizontalScrollController,
                                        thumbVisibility: true,
                                        thickness: 6,
                                        radius: const Radius.circular(8),
                                        child: SingleChildScrollView(
                                          controller: _horizontalScrollController,
                                          scrollDirection: Axis.horizontal,
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: ElevatedButton(
                                                  onPressed: () => _showStaffSelectionDialog(context, appointmentId, 'consultant'),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: consultantAssigned ? Colors.green : AppColors.gold,
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                                    padding: const EdgeInsets.symmetric(vertical: 0),
                                                    minimumSize: Size(0, 26),
                                                  ),
                                                  child: Text(
                                                    consultantAssigned ? (appointment['consultantName'] ?? 'Reassign') : 'Consultant',
                                                    style: const TextStyle(color: Colors.black, fontSize: 11),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ),
                                              
                                              // Chat buttons for each assigned staff
                                              if (consultantAssigned)
                                                Padding(
                                                  padding: const EdgeInsets.only(left: 4),
                                                  child: InkWell(
                                                    onTap: () {
                                                      final consultantId = appointment['consultantId'] ?? '';
                                                      final consultantName = appointment['consultantName'] ?? 'Consultant';
                                                      _openChatDialog(context, appointmentId, 'consultant', consultantId, consultantName);
                                                    },
                                                    child: Container(
                                                      decoration: BoxDecoration(
                                                        color: Colors.blue,
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      padding: const EdgeInsets.all(4),
                                                      child: const Icon(Icons.chat, size: 18, color: Colors.white),
                                                    ),
                                                  ),
                                                ),
                                              
                                              // Cleaner button
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: ElevatedButton(
                                                  onPressed: () => _showStaffSelectionDialog(context, appointmentId, 'cleaner'),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: cleanerAssigned ? Colors.green : AppColors.gold,
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                                    padding: const EdgeInsets.symmetric(vertical: 0),
                                                    minimumSize: Size(0, 26),
                                                  ),
                                                  child: Text(
                                                    cleanerAssigned ? (appointment['cleanerName'] ?? 'Reassign') : 'Cleaner',
                                                    style: const TextStyle(color: Colors.black, fontSize: 11),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ),
                                              
                                              // Cleaner chat button
                                              if (cleanerAssigned)
                                                Padding(
                                                  padding: const EdgeInsets.only(left: 4),
                                                  child: InkWell(
                                                    onTap: () {
                                                      final cleanerId = appointment['cleanerId'] ?? '';
                                                      final cleanerName = appointment['cleanerName'] ?? 'Cleaner';
                                                      _openChatDialog(context, appointmentId, 'cleaner', cleanerId, cleanerName);
                                                    },
                                                    child: Container(
                                                      decoration: BoxDecoration(
                                                        color: Colors.blue,
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      padding: const EdgeInsets.all(4),
                                                      child: const Icon(Icons.chat, size: 18, color: Colors.white),
                                                    ),
                                                  ),
                                                ),
                                              
                                              // Concierge button
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: ElevatedButton(
                                                  onPressed: () => _showStaffSelectionDialog(context, appointmentId, 'concierge'),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: conciergeAssigned ? Colors.green : AppColors.gold,
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                                    padding: const EdgeInsets.symmetric(vertical: 0),
                                                    minimumSize: Size(0, 26),
                                                  ),
                                                  child: Text(
                                                    conciergeAssigned ? (appointment['conciergeName'] ?? 'Reassign') : 'Concierge',
                                                    style: const TextStyle(color: Colors.black, fontSize: 11),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ),
                                              
                                              // Concierge chat button
                                              if (conciergeAssigned)
                                                Padding(
                                                  padding: const EdgeInsets.only(left: 4),
                                                  child: InkWell(
                                                    onTap: () {
                                                      final conciergeId = appointment['conciergeId'] ?? '';
                                                      final conciergeName = appointment['conciergeName'] ?? 'Concierge';
                                                      _openChatDialog(context, appointmentId, 'concierge', conciergeId, conciergeName);
                                                    },
                                                    child: Container(
                                                      decoration: BoxDecoration(
                                                        color: Colors.blue,
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      padding: const EdgeInsets.all(4),
                                                      child: const Icon(Icons.chat, size: 18, color: Colors.white),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                // Add a visual scrollbar track below the buttons
                                SizedBox(
                                  height: 8,
                                  child: Scrollbar(
                                    thumbVisibility: true,
                                    thickness: 6,
                                    radius: const Radius.circular(8),
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: SizedBox(width: 400), // Dummy width for visual bar
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.black,
        selectedItemColor: AppColors.gold,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Appointments',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Staff',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inbox),
            label: 'Inbox',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: 'Messages',
          ),
        ],
        currentIndex: 0,
        onTap: (index) {
          if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => AppointmentsScreen()),
            );
          } else if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => StaffManagementScreen()),
            );
          } else if (index == 3) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => FloorManagerQueryInboxScreen()),
            );
          } else if (index == 4) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => FloorManagerChatListScreen()),
            );
          }
        },
      ),

    );
  }
}
