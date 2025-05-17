import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/colors.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/app_auth_provider.dart';

// Helper extension to capitalize first letter of a string
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${this.substring(1)}";
  }
}

class NotificationItem extends StatelessWidget {
  final Map<String, dynamic> notification;
  final VoidCallback onTapCallback;
  final VoidCallback onDismissCallback;

  const NotificationItem({
    super.key,
    required this.notification,
    required this.onTapCallback,
    required this.onDismissCallback,
  });

  Map<String, dynamic> _getNotificationData() {
    // Add debug logging to see notification content
    print('🔔 Notification Item: Received notification: ${notification.keys}');
    
    // For chat notifications, print more details
    if (notification['notificationType'] == 'chat') {
      print('💬 Chat Notification: appointmentId=${notification['appointmentId']}, '
            'senderRole=${notification['senderRole']}, '
            'serviceName=${notification['serviceName']}, '
            'appointmentTime=${notification['appointmentTime']}');
    }
    
    // Handle both old and new notification formats
    if (notification.containsKey('data')) {
      return notification['data'] as Map<String, dynamic>;
    }
    return notification;
  }

  @override
  Widget build(BuildContext context) {
    final data = _getNotificationData();
    final bool isRead = notification['isRead'] as bool? ?? false;
    final DateTime? createdAt = (notification['createdAt'] as Timestamp?)?.toDate();
    final DateTime? timestamp = (notification['timestamp'] as Timestamp?)?.toDate();
    final notificationType = notification['type'] ?? notification['notificationType'] ?? '';
    final String title = notification['title'] ?? data['title'] ?? '';
    final String body = notification['body'] ?? data['body'] ?? '';
    final String appointmentId = notification['appointmentId'] ?? data['appointmentId'] ?? '';

    // Color coding by type
    Color leftBarColor;
    IconData icon;
    switch (notificationType) {
      case 'assignment_confirmed':
        leftBarColor = Colors.blue;
        icon = Icons.assignment_turned_in;
        break;
      case 'appointment_assigned':
      case 'booking_assigned':
        leftBarColor = Colors.yellow[700]!;
        icon = Icons.person_add_alt_1;
        break;
      case 'chat':
      case 'message':
      case 'message_received':
      case 'chat_message':
        leftBarColor = Colors.red;
        icon = Icons.chat_bubble_outline;
        break;
      case 'booking_made':
      case 'new_appointment':
        leftBarColor = Colors.green;
        icon = Icons.event_available;
        break;
      case 'minister_arrived':
        leftBarColor = Colors.orange;
        icon = Icons.directions_walk;
        break;
      case 'minister_left':
      case 'appointment_completed':
        leftBarColor = Colors.purple;
        icon = Icons.check_circle_outline;
        break;
      case 'thank_minister':
        leftBarColor = Colors.amber;
        icon = Icons.emoji_events;
        break;
      case 'booking_cancelled':
        leftBarColor = Colors.grey;
        icon = Icons.cancel_outlined;
        break;
      default:
        leftBarColor = Colors.grey;
        icon = Icons.notifications;
    }

    // Determine which name to show based on role and notification
    String displayName = '';
    // Priority: ministerName > staffName > consultantName > conciergeName > cleanerName > userName
    if ((notification['ministerName'] ?? data['ministerName'])?.toString().isNotEmpty == true) {
      displayName = (notification['ministerName'] ?? data['ministerName']).toString();
    } else if ((notification['staffName'] ?? data['staffName'])?.toString().isNotEmpty == true) {
      displayName = (notification['staffName'] ?? data['staffName']).toString();
    } else if ((notification['consultantName'] ?? data['consultantName'])?.toString().isNotEmpty == true) {
      displayName = (notification['consultantName'] ?? data['consultantName']).toString();
    } else if ((notification['conciergeName'] ?? data['conciergeName'])?.toString().isNotEmpty == true) {
      displayName = (notification['conciergeName'] ?? data['conciergeName']).toString();
    } else if ((notification['cleanerName'] ?? data['cleanerName'])?.toString().isNotEmpty == true) {
      displayName = (notification['cleanerName'] ?? data['cleanerName']).toString();
    } else if ((notification['userName'] ?? data['userName'])?.toString().isNotEmpty == true) {
      displayName = (notification['userName'] ?? data['userName']).toString();
    }
    String displayTitle = displayName.isNotEmpty ? displayName : title;

    // Extract more appointment and staff info for rich card
    String serviceName = data['serviceName']?.toString() ?? '';
    String venueName = data['venueName']?.toString() ?? '';
    String status = data['status']?.toString() ?? '';
    String staffName = data['staffName']?.toString() ?? '';
    String staffType = data['staffType']?.toString() ?? '';
    String consultantName = data['consultantName']?.toString() ?? '';
    String conciergeName = data['conciergeName']?.toString() ?? '';
    String cleanerName = data['cleanerName']?.toString() ?? '';
    String ministerPhone = data['ministerPhone']?.toString() ?? '';
    String appointmentTime = '';
    if (data['appointmentTime'] is Timestamp) {
      appointmentTime = DateFormat('EEE, MMM d, yyyy – h:mm a').format((data['appointmentTime'] as Timestamp).toDate());
    } else if (data['appointmentTime'] is String && data['appointmentTime'].isNotEmpty) {
      try {
        appointmentTime = DateFormat('yyyy-MM-ddTHH:mm:ss').format(DateTime.parse(data['appointmentTime']));
      } catch (_) {
        appointmentTime = data['appointmentTime'];
      }
    }

    // Compose details for display
    final ministerEmail = data['ministerEmail']?.toString() ?? '';
    final ministerId = data['ministerId']?.toString() ?? '';
    // Top horizontal row: Minister Name, Phone (tappable), Email, ID
    Widget ministerRow = Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Row(
      children: [
        if (displayName.isNotEmpty) ...[
          Icon(Icons.person, color: AppColors.gold, size: 18),
          SizedBox(width: 4),
          Flexible(child: Text(displayName, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis)),
        ],
        if (ministerPhone.isNotEmpty) ...[
          SizedBox(width: 12),
          Icon(Icons.phone, color: AppColors.gold, size: 18),
          SizedBox(width: 2),
          GestureDetector(
            onTap: () => NotificationItem._launchPhoneCall(ministerPhone),
            child: Text(ministerPhone, style: TextStyle(color: Colors.blue, fontSize: 13, decoration: TextDecoration.underline)),
          ),
        ],
      ],
    ),
    if (ministerId.isNotEmpty) ...[
      SizedBox(height: 4),
      Row(
        children: [
          Icon(Icons.badge, color: AppColors.gold, size: 18),
          SizedBox(width: 2),
          Text('ID: $ministerId', style: TextStyle(color: Colors.white, fontSize: 13)),
        ],
      ),
    ],
    if (ministerEmail.isNotEmpty) ...[
      SizedBox(height: 4),
      Row(
        children: [
          Icon(Icons.email, color: AppColors.gold, size: 18),
          SizedBox(width: 2),
          Text(ministerEmail, style: TextStyle(color: Colors.white, fontSize: 13)),
        ],
      ),
    ],
  ],
);



    // Details: Consultant, Venue, Service, Date, Time
    List<Widget> details = [];
    if (consultantName.isNotEmpty) details.add(_infoRow(Icons.person, 'Consultant', consultantName));
    if (venueName.isNotEmpty) details.add(_infoRow(Icons.location_on, 'Venue', venueName));
    if (serviceName.isNotEmpty) details.add(_infoRow(Icons.miscellaneous_services, 'Service', serviceName));
    if (appointmentTime.isNotEmpty) details.add(_infoRow(Icons.calendar_today, 'Date', appointmentTime));
    // If time is separately available, add it
    final timeStr = (data['appointmentTime'] is Timestamp)
      ? DateFormat('HH:mm').format((data['appointmentTime'] as Timestamp).toDate())
      : '';
    if (timeStr.isNotEmpty) details.add(_infoRow(Icons.access_time, 'Time', timeStr));

    return Dismissible(
      key: Key(notification['id'] ?? ''),
      onDismissed: (_) => onDismissCallback(),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: Colors.grey[900],
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            onTapCallback();
            // Open appointment details for all notifications with appointmentId
            if (appointmentId.isNotEmpty) {
              Navigator.of(context).pushNamed(
                '/floor_manager/appointment_details',
                arguments: {
                  'appointmentId': appointmentId,
                  'notification': notification,
                },
              );
            } else if (notification['notificationType'] == 'chat' && notification['appointmentId'] != null) {
              final senderId = notification['senderId'] ?? '';
              final senderRoleVal = notification['senderRole'] ?? '';
              final senderNameVal = notification['senderName'] ?? '';
              _openChatFromNotification(context, notification['appointmentId'], senderRoleVal, senderId, senderNameVal);
            }
          },
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 64,
                  decoration: BoxDecoration(
                    color: leftBarColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              displayTitle,
                              style: TextStyle(
                                color: isRead ? Colors.grey[400] : Colors.white,
                                fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (createdAt != null)
                            Text(
                              DateFormat('MMM d, h:mm a').format(createdAt),
                              style: TextStyle(color: Colors.grey[500], fontSize: 12),
                            ),
                        ],
                      ),
                      if (body.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0, bottom: 2.0),
                          child: notification['role'] == 'minister'
                              ? Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.gold.withOpacity(0.13),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.gold, width: 1.2),
                                  ),
                                  child: Text(
                                    body,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    textAlign: TextAlign.left,
                                  ),
                                )
                              : Text(
                                  body,
                                  style: TextStyle(color: Colors.grey[300], fontSize: 14),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                        ),
                      // Always show the minister row if any info present
                      if (displayName.isNotEmpty || ministerPhone.isNotEmpty || ministerEmail.isNotEmpty || ministerId.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6.0, bottom: 2.0),
                          child: ministerRow,
                        ),
                      if (details.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: details,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(icon, color: leftBarColor, size: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Icon(icon, color: AppColors.gold, size: 18),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600)),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 13))),
        ],
      ),
    );
  }

  // Method to open chat dialog from notification
  void _openChatFromNotification(BuildContext context, String appointmentId, String? senderRole, 
                                String? senderId, String? senderName) {
    // First, get the appointment data to be able to open the chat
    FirebaseFirestore.instance
        .collection('appointments')
        .doc(appointmentId)
        .get()
        .then((appointmentDoc) {
      if (appointmentDoc.exists) {
        final appointmentData = appointmentDoc.data() as Map<String, dynamic>;
        appointmentData['id'] = appointmentId;
        
        // Get current user role
        final currentUser = Provider.of<AppAuthProvider>(context, listen: false).appUser;
        if (currentUser == null) return;
        
        if (currentUser.role == 'minister') {
          // For ministers, open the chat dialog with the consultant or floor manager
          _openMinisterChatDialog(context, appointmentData, senderRole, senderId, senderName);
        } else if (senderRole == 'minister' && currentUser.role == 'consultant') {
          // For consultants, open the chat with the minister
          _openConsultantChatDialog(context, appointmentData);
        } else if (currentUser.role == 'floor_manager') {
          // For floor managers, open the chat dialog with the selected staff
          _openFloorManagerChatDialog(context, appointmentId, senderRole ?? 'consultant', senderId ?? '', senderName ?? 'Staff');
        }
      }
    });
  }
  
  // Open chat dialog for minister
  void _openMinisterChatDialog(BuildContext context, Map<String, dynamic> appointment, 
                            String? senderRole, String? senderId, String? senderName) {
    // Navigate to the minister home screen and open the chat
    Navigator.pushNamed(context, '/minister/home').then((_) {
      // After navigation, find the page state and open chat dialog
      // Note: This is a simplified version - in a real app we would use a more robust method
      // to open the chat dialog, possibly by using a global key or a provider
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.black,
            title: Text('Chat with $senderName', style: TextStyle(color: AppColors.gold)),
            content: Text('Please use the chat button in the appointment card to chat with $senderName.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('OK', style: TextStyle(color: AppColors.gold)),
              ),
            ],
          ),
        );
      });
    });
  }
  
  // Open chat dialog for consultant
  void _openConsultantChatDialog(BuildContext context, Map<String, dynamic> appointment) {
    // Navigate to consultant home and show a message
    Navigator.pushNamed(context, '/consultant/home').then((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.black,
            title: Text('Chat Available', style: TextStyle(color: AppColors.gold)),
            content: Text('Please view the appointment details to chat with the minister.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('OK', style: TextStyle(color: AppColors.gold)),
              ),
            ],
          ),
        );
      });
    });
  }
  
  // Open chat dialog for floor manager
  void _openFloorManagerChatDialog(BuildContext context, String appointmentId, 
                                String recipientRole, String recipientId, String recipientName) {
    // Get the FloorManagerHomeScreen state to access its _openChatDialog method
    Navigator.pushNamed(context, '/floor_manager/home').then((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.black,
            title: Text('Chat with $recipientName', style: TextStyle(color: AppColors.gold)),
            content: Text('Please view the appointment to chat with $recipientName.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('OK', style: TextStyle(color: AppColors.gold)),
              ),
            ],
          ),
        );
      });
    });
  }
    // Helper function to launch phone call
  static Future<void> _launchPhoneCall(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
