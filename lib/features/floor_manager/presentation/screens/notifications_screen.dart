import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/providers/app_auth_provider.dart';
import '../../../../core/models/app_user.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/notification_item.dart';
import '../../../minister/presentation/screens/minister_home_screen.dart';
import '../../../minister/presentation/screens/minister_chat_dialog.dart';
import 'appointment_details_screen.dart';

class NotificationsScreen extends StatelessWidget {
  final String? userRole;
  final String? userId;
  final bool forMinister;
  final String? ministerId;

  const NotificationsScreen({
    super.key,
    this.userRole,
    this.userId,
    this.forMinister = false,
    this.ministerId,
  });

  Future<void> _markAsRead(String notificationId) async {
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }

  @override
  Widget build(BuildContext context) {
    print('Building NotificationsScreen with role: $userRole, forMinister: $forMinister, ministerId: $ministerId'); // Debug print

    final user = Provider.of<AppAuthProvider>(context).appUser;
    final role = userRole ?? user?.role;

    if (role == null && !forMinister) {
      return const Center(
        child: Text(
          'User not found',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(forMinister ? 'My Notifications' : 'Notifications'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _getNotificationsStream(user),
        builder: (context, snapshot) {
          print('StreamBuilder state: ${snapshot.connectionState}'); // Debug connection state
          
          if (snapshot.hasError) {
            print('Error in NotificationsScreen: ${snapshot.error}'); // Debug print
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.white),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data == null) {
            print('No data in snapshot'); // Debug print
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)),
              ),
            );
          }

          final notifications = snapshot.data!.docs;
          print('Found ${notifications.length} notifications'); // Debug print
          
          // Debug print each notification
          notifications.forEach((doc) {
            final data = doc.data() as Map<String, dynamic>;
            print('Notification: ${doc.id}');
            print('  Title: ${data['title']}');
            print('  Role: ${data['role']}');
            print('  CreatedAt: ${data['createdAt']}');
            if (forMinister) {
              print('  Minister ID: ${data['ministerId']}');
            }
          });
          
          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off, size: 64, color: Colors.grey[700]),
                  const SizedBox(height: 16),
                  Text(
                    forMinister 
                      ? 'No notifications for you yet.\nYou\'ll be notified when staff is assigned to your appointments.'
                      : 'No notifications',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[400], fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              final notificationData = notification.data() as Map<String, dynamic>;
              final isRead = notificationData['isRead'] as bool? ?? false;
              notificationData['id'] = notification.id;
              print('Building notification ${index + 1}: ${notificationData['title']}'); // Debug print

              return Dismissible(
                key: Key(notification.id),
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16.0),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                direction: DismissDirection.endToStart,
                onDismissed: (direction) async {
                  await FirebaseFirestore.instance
                      .collection('notifications')
                      .doc(notification.id)
                      .delete();
                },
                child: NotificationItem(
                  notification: notificationData,
                  onTapCallback: () async {
                    await _markAsRead(notification.id);
                    final data = notification.data() as Map<String, dynamic>;
                    final notificationType = data['notificationType'] ?? data['type'] ?? '';
                    final title = data['title']?.toString().toLowerCase() ?? '';
                    final role = data['role']?.toString().toLowerCase() ?? '';
                    final appointmentId = data['appointmentId'] ?? data['data']?['appointmentId'] ?? data['data']?['id'] ?? data['id'] ?? '';
                    final String resolvedAppointmentId = (appointmentId != null && appointmentId.toString().isNotEmpty)
                      ? appointmentId.toString()
                      : (data['id'] ?? notification.id ?? '').toString();
                    print('[DEBUG][NOTIF TAP] notification.id: ${notification.id}');
                    print('[DEBUG][NOTIF TAP] notificationData: $notificationData');
                    print('[DEBUG][NOTIF TAP] data: $data');
                    print('[DEBUG][NOTIF TAP] Fields: appointmentId=$appointmentId, resolvedAppointmentId=$resolvedAppointmentId, data.id=${data['id']}, data.appointmentId=${data['appointmentId']}, data.data?.appointmentId=${data['data']?['appointmentId']}, notification.id=${notification.id}');
                    // Block only for staff assignment and role is floor_manager
                    if (title.contains('staff assignment') && role == 'floorManager') {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('No details available for this notification')),
                      );
                      return;
                    }
                    // Allow all other roles to open their assignment notifications
                    if ((notificationType == 'chat' || notificationType == 'message') && resolvedAppointmentId.isNotEmpty) {
                       // Fetch appointment and open chat dialog directly
                       final appointmentDoc = await FirebaseFirestore.instance.collection('appointments').doc(resolvedAppointmentId).get();
                       final appointmentData = appointmentDoc.data() ?? {};
                       appointmentData['id'] = resolvedAppointmentId;
                       showDialog(
                         context: context,
                         barrierDismissible: false,
                         builder: (BuildContext dialogContext) {
                           return MinisterChatDialog(appointment: appointmentData);
                         },
                       );
                       return;
                     }
                     if ((notificationType == 'new_appointment' || notificationType == 'booking_made' || notificationType == 'appointment' || notificationType == 'staff_assigned') && resolvedAppointmentId.isNotEmpty) {
                       Navigator.of(context).push(
                         MaterialPageRoute(
                           builder: (context) => AppointmentDetailsScreen(appointmentId: resolvedAppointmentId),
                         ),
                       );
                       return;
                     }
                     ScaffoldMessenger.of(context).showSnackBar(
                       const SnackBar(content: Text('No details available for this notification')),
                     );
                  },
                  onDismissCallback: () async {
                    await FirebaseFirestore.instance
                        .collection('notifications')
                        .doc(notification.id)
                        .delete();
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
  
  Stream<QuerySnapshot> _getNotificationsStream(AppUser? user) {
    if (forMinister && ministerId != null) {
      print('Getting notifications for minister: $ministerId');
      return FirebaseFirestore.instance
          .collection('notifications')
          .where('assignedToId', isEqualTo: ministerId)
          .orderBy('createdAt', descending: true)
          .snapshots();
    } else if (user != null) {
      // For floor managers, we need to get both their personal notifications
      // and any notifications for the floor_manager role
      if (user.role == 'floor_manager' || user.role == 'floorManager') {
        print('Getting notifications for floor manager: ${user.uid}');
        return FirebaseFirestore.instance
            .collection('notifications')
            .where('assignedToId', isEqualTo: user.uid)
            .orderBy('createdAt', descending: true)
            .snapshots();
      } else {
        // For other users, just get their personal notifications
        print('Getting notifications for user: ${user.uid}, role: ${user.role}');
        return FirebaseFirestore.instance
            .collection('notifications')
            .where('assignedToId', isEqualTo: user.uid)
            .orderBy('createdAt', descending: true)
            .snapshots();
      }
    } else {
      // Fallback: Get all notifications for floor_manager role
      // This should only happen if the user is not logged in, which shouldn't happen
      print('Getting all notifications for floor_manager role (fallback)');
      return FirebaseFirestore.instance
          .collection('notifications')
          .where('role', isEqualTo: 'floor_manager')
          .orderBy('createdAt', descending: true)
          .snapshots();
    }
  }
}

// Helper method to show staff assignment details for ministers
void _showStaffAssignmentDetails(BuildContext context, Map<String, dynamic> notificationData) {
  final appointmentId = notificationData['appointmentId'] as String? ?? '';
  final staffType = notificationData['staffType'] as String? ?? '';
  final staffName = notificationData['staffName'] as String? ?? 'Staff Member';
  final consultantName = notificationData['consultantName'] as String? ?? '';
  final consultantId = notificationData['consultantId'] as String? ?? '';
  final conciergeName = notificationData['conciergeName'] as String? ?? '';
  final conciergeId = notificationData['conciergeId'] as String? ?? '';
  final cleanerName = notificationData['cleanerName'] as String? ?? '';
  final serviceName = notificationData['serviceName'] as String? ?? 'Your service';
  
  // Format the appointment time
  String appointmentTimeDisplay = 'Scheduled time';
  if (notificationData['appointmentTime'] is Timestamp) {
    final timestamp = notificationData['appointmentTime'] as Timestamp;
    final dateTime = timestamp.toDate();
    appointmentTimeDisplay = DateFormat('MMM d, yyyy h:mm a').format(dateTime);
  }

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Colors.grey[900],
      title: Text(
        'Staff Assignment Details',
        style: TextStyle(color: AppColors.primary),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your appointment for $serviceName on $appointmentTimeDisplay has been assigned to:',
              style: TextStyle(color: Colors.white),
            ),
            SizedBox(height: 16),
            
            // Consultant details with chat option
            if (consultantName.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStaffDetailWithChat(
                    context,
                    'Consultant',
                    consultantName,
                    consultantId,
                    appointmentId,
                    Colors.blue,
                    appointmentTimeDisplay,
                    serviceName,
                  ),
                  const SizedBox(height: 4),
                  if ((notificationData['consultantPhone'] ?? '').toString().isNotEmpty)
                    GestureDetector(
                      onTap: () async {
                        final uri = Uri(scheme: 'tel', path: notificationData['consultantPhone']);
                        await launchUrl(uri);
                      },
                      child: Text(
                        notificationData['consultantPhone'],
                        style: const TextStyle(color: Colors.lightBlueAccent, decoration: TextDecoration.underline),
                      ),
                    ),
                  if ((notificationData['consultantEmail'] ?? '').toString().isNotEmpty)
                    GestureDetector(
                      onTap: () async {
                        final uri = Uri(scheme: 'mailto', path: notificationData['consultantEmail']);
                        await launchUrl(uri);
                      },
                      child: Text(
                        notificationData['consultantEmail'],
                        style: const TextStyle(color: Colors.lightBlueAccent, decoration: TextDecoration.underline),
                      ),
                    ),
                ],
              ),
              
            SizedBox(height: 8),
            
            // Concierge details with chat option
            if (conciergeName.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStaffDetailWithChat(
                    context,
                    'Concierge',
                    conciergeName,
                    conciergeId,
                    appointmentId,
                    Colors.purple,
                    appointmentTimeDisplay,
                    serviceName,
                  ),
                  const SizedBox(height: 4),
                  if ((notificationData['conciergePhone'] ?? '').toString().isNotEmpty)
                    GestureDetector(
                      onTap: () async {
                        final uri = Uri(scheme: 'tel', path: notificationData['conciergePhone']);
                        await launchUrl(uri);
                      },
                      child: Text(
                        notificationData['conciergePhone'],
                        style: const TextStyle(color: Colors.lightBlueAccent, decoration: TextDecoration.underline),
                      ),
                    ),
                  if ((notificationData['conciergeEmail'] ?? '').toString().isNotEmpty)
                    GestureDetector(
                      onTap: () async {
                        final uri = Uri(scheme: 'mailto', path: notificationData['conciergeEmail']);
                        await launchUrl(uri);
                      },
                      child: Text(
                        notificationData['conciergeEmail'],
                        style: const TextStyle(color: Colors.lightBlueAccent, decoration: TextDecoration.underline),
                      ),
                    ),
                ],
              ),
              
            SizedBox(height: 8),
              
            // Cleaner details (no chat option)
            if (cleanerName.isNotEmpty)
              _buildStaffDetail(
                'Cleaner',
                cleanerName,
                Colors.teal,
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          child: Text(
            'Close',
            style: TextStyle(color: AppColors.primary),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    ),
  );
}

// Build staff detail row with chat button
Widget _buildStaffDetailWithChat(
  BuildContext context,
  String role,
  String name,
  String id,
  String appointmentId,
  Color color,
  String appointmentTime,
  String serviceName,
) {
  return Container(
    padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
    decoration: BoxDecoration(
      color: Colors.grey[850],
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withOpacity(0.5)),
    ),
    child: Row(
      children: [
        CircleAvatar(
          backgroundColor: color,
          radius: 16,
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : role[0].toUpperCase(),
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                role,
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
              Text(
                name,
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              Text(
                appointmentTime,
                style: TextStyle(color: Colors.grey[400], fontSize: 10),
              ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(Icons.chat, color: color),
          tooltip: 'Chat with $name',
          onPressed: () {
            // Close the dialog
            Navigator.of(context).pop();
            
            // Navigate to chat with this staff member
            _navigateToChatWithStaff(context, appointmentId, id, role.toLowerCase(), name, appointmentTime, serviceName);
          },
        ),
      ],
    ),
  );
}

// Navigate to chat with staff
void _navigateToChatWithStaff(
  BuildContext context,
  String appointmentId,
  String staffId,
  String staffRole,
  String staffName,
  String appointmentTime,
  String serviceName,
) {
  // Show a confirmation dialog with specific role details 
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Colors.grey[900],
      title: Text(
        'Chat with $staffName',
        style: TextStyle(color: AppColors.primary),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'You are about to start a chat with your ${staffRole.toLowerCase()}:',
            style: TextStyle(color: Colors.white),
          ),
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[850],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      staffRole.toLowerCase() == 'consultant' ? Icons.person : Icons.room_service,
                      color: staffRole.toLowerCase() == 'consultant' ? Colors.blue : Colors.purple,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Text(
                      '$staffName - ${staffRole.toUpperCase()}',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  'Appointment: $serviceName',
                  style: TextStyle(color: Colors.grey[400], fontSize: 14),
                ),
                Text(
                  'Time: $appointmentTime',
                  style: TextStyle(color: Colors.grey[400], fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          child: Text(
            'Cancel',
            style: TextStyle(color: Colors.grey),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        TextButton(
          child: Text(
            'Open Chat',
            style: TextStyle(color: AppColors.primary),
          ),
          onPressed: () {
            // Close the dialog
            Navigator.of(context).pop();
            // Navigate to minister home and open chat
            Navigator.of(context).pushNamedAndRemoveUntil(
              '/minister/home',
              (route) => false,
              arguments: {
                'openChat': true,
                'appointmentId': appointmentId,
                'staffId': staffId,
                'staffRole': staffRole,
                'staffName': staffName,
                'serviceName': serviceName,
                'appointmentTime': appointmentTime,
              },
            );
          },
        ),
      ],
    ),
  );
}

// Build staff detail row without chat button
Widget _buildStaffDetail(
  String role,
  String name,
  Color color,
) {
  return Container(
    padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
    decoration: BoxDecoration(
      color: Colors.grey[850],
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withOpacity(0.5)),
    ),
    child: Row(
      children: [
        CircleAvatar(
          backgroundColor: color,
          radius: 16,
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : role[0].toUpperCase(),
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                role,
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
              Text(
                name,
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

// Navigate to chat from message notification
void _navigateToChat(BuildContext context, Map<String, dynamic> notificationData) {
  final appointmentId = notificationData['appointmentId'] as String? ?? '';
  
  if (appointmentId.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Cannot open chat: Missing appointment ID')),
    );
    return;
  }
  
  Navigator.of(context).pushNamed(
    '/minister/home/chat',
    arguments: {
      'appointmentId': appointmentId,
      'fromNotification': true,
    },
  );
}
