import 'package:vip_lounge/features/minister/presentation/screens/minister_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:vip_lounge/features/minister/presentation/screens/minister_chat_dialog.dart';
import 'package:vip_lounge/features/consultant/presentation/widgets/consultant_appointment_widget.dart';
import 'package:vip_lounge/features/concierge/presentation/widgets/concierge_appointment_widget.dart';
import 'package:vip_lounge/features/consultant/presentation/widgets/consultant_appointment_widget.dart';
import 'package:vip_lounge/features/concierge/presentation/widgets/concierge_appointment_widget.dart';
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

  // Helper for launching email
  void _launchEmail(String email) async {
    final Uri emailUri = Uri(scheme: 'mailto', path: email);
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine if this notification is a message/chat type
    final data = _getNotificationData();
    final notificationType = notification['type'] ?? notification['notificationType'] ?? '';
    final isMessageType = notificationType == 'message' ||
        notificationType == 'chat' ||
        notificationType == 'message_received' ||
        notificationType == 'chat_message';
    // If it's a message/chat, disable tap by making onTapCallback a no-op
    final effectiveOnTap = isMessageType ? null : null; // Always disable tap for message/chat notifications

    final bool isRead = notification['isRead'] as bool? ?? false;
    final DateTime? createdAt = (notification['createdAt'] as Timestamp?)?.toDate();
    final DateTime? timestamp = (notification['timestamp'] as Timestamp?)?.toDate();
    // Fallback for missing title/body for concierge and other roles
    String title = notification['title'] ?? data['title'] ?? '';
    String body = notification['body'] ?? data['body'] ?? '';
    final String appointmentId = notification['appointmentId'] ?? data['appointmentId'] ?? '';
    // If still blank and this is a concierge notification, provide defaults
    if (title.isEmpty && (notification['role'] == 'concierge' || data['role'] == 'concierge')) {
      title = 'Concierge Notification';
    }
    if (body.isEmpty && (notification['role'] == 'concierge' || data['role'] == 'concierge')) {
      body = 'You have a new notification.';
    }

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
    // Ensure displayTitle is never blank
    String displayTitle = displayName.isNotEmpty ? displayName : (title.isNotEmpty ? title : 'Notification');

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
    // Consultant/Concierge contact info
    // (No redeclaration of consultantName/conciergeName here, already declared above)
    final consultantPhone = data['consultantPhone']?.toString() ?? data['consultantMobile']?.toString() ?? '';
    final consultantEmail = data['consultantEmail']?.toString() ?? '';
    final conciergePhone = data['conciergePhone']?.toString() ?? data['conciergeMobile']?.toString() ?? '';
    final conciergeEmail = data['conciergeEmail']?.toString() ?? '';

    // Top horizontal row: Minister Name, Phone (tappable), Email, ID
    Widget ministerRow = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (displayName.isNotEmpty) ...[
              Icon(Icons.person, color: AppColors.primary, size: 18),
              SizedBox(width: 4),
              Flexible(child: Text(displayName, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis)),
            ],
            if (ministerPhone.isNotEmpty) ...[
              SizedBox(width: 12),
              Icon(Icons.phone, color: AppColors.primary, size: 18),
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
  Text('Minister ID', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
  Padding(
    padding: const EdgeInsets.only(left: 20, top: 2),
    child: Text(ministerId, style: TextStyle(color: Colors.white, fontSize: 13)),
  ),
],
        if (ministerEmail.isNotEmpty) ...[
          SizedBox(height: 4),
          Text('Minister Email', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          Padding(
            padding: const EdgeInsets.only(left: 20, top: 2),
            child: GestureDetector(
              onTap: effectiveOnTap,
              onLongPress: onDismissCallback,
              behavior: HitTestBehavior.opaque,
              child: AbsorbPointer(
                absorbing: isMessageType,
                child: Text(ministerEmail, style: TextStyle(color: Colors.blue, fontSize: 13, decoration: TextDecoration.underline)),
              ),
            ),
          ),
        ],
        // Consultant Info
        if (consultantName.isNotEmpty || consultantPhone.isNotEmpty || consultantEmail.isNotEmpty) ...[
          SizedBox(height: 8),
          Text('Assigned Consultant', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          if (consultantName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 20, top: 2),
              child: Text(consultantName, style: TextStyle(color: Colors.white, fontSize: 13)),
            ),
          if (consultantPhone.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 20, top: 2),
              child: Row(
                children: [
                  Icon(Icons.phone, color: AppColors.primary, size: 16),
                  SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => NotificationItem._launchPhoneCall(consultantPhone),
                    child: Text(consultantPhone, style: TextStyle(color: Colors.blue, fontSize: 13, decoration: TextDecoration.underline)),
                  ),
                ],
              ),
            ),
          if (consultantEmail.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 20, top: 2),
              child: Row(
                children: [
                  Icon(Icons.email, color: AppColors.primary, size: 16),
                  SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => _launchEmail(consultantEmail),
                    child: Text(consultantEmail, style: TextStyle(color: Colors.blue, fontSize: 13, decoration: TextDecoration.underline)),
                  ),
                ],
              ),
            ),
  SizedBox(height: 8),
  Text('Assigned Consultant', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
  if (consultantName.isNotEmpty)
    Padding(
      padding: const EdgeInsets.only(left: 20, top: 2),
      child: Text(consultantName, style: TextStyle(color: Colors.white, fontSize: 13)),
    ),
  if (consultantPhone.isNotEmpty)
    Padding(
      padding: const EdgeInsets.only(left: 20, top: 2),
      child: Row(
        children: [
          Icon(Icons.phone, color: AppColors.primary, size: 16),
          SizedBox(width: 4),
          GestureDetector(
            onTap: () => NotificationItem._launchPhoneCall(consultantPhone),
            child: Text(consultantPhone, style: TextStyle(color: Colors.blue, fontSize: 13, decoration: TextDecoration.underline)),
          ),
        ],
      ),
    ),
  if (consultantEmail.isNotEmpty)
    Padding(
      padding: const EdgeInsets.only(left: 20, top: 2),
      child: Row(
        children: [
          Icon(Icons.email, color: AppColors.primary, size: 16),
          SizedBox(width: 4),
          GestureDetector(
            onTap: () => _launchEmail(consultantEmail),
            child: Text(consultantEmail, style: TextStyle(color: Colors.blue, fontSize: 13, decoration: TextDecoration.underline)),
          ),
        ],
      ),
    ),
],
        // Concierge Info
if (conciergeName.isNotEmpty || conciergePhone.isNotEmpty || conciergeEmail.isNotEmpty) ...[
  SizedBox(height: 8),
  Text('Assigned Concierge', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
  if (conciergeName.isNotEmpty)
    Padding(
      padding: const EdgeInsets.only(left: 20, top: 2),
      child: Text(conciergeName, style: TextStyle(color: Colors.white, fontSize: 13)),
    ),
  if (conciergePhone.isNotEmpty)
    Padding(
      padding: const EdgeInsets.only(left: 20, top: 2),
      child: Row(
        children: [
          Icon(Icons.phone, color: AppColors.primary, size: 16),
          SizedBox(width: 4),
          GestureDetector(
            onTap: () => NotificationItem._launchPhoneCall(conciergePhone),
            child: Text(conciergePhone, style: TextStyle(color: Colors.blue, fontSize: 13, decoration: TextDecoration.underline)),
          ),
        ],
      ),
    ),
  if (conciergeEmail.isNotEmpty)
    Padding(
      padding: const EdgeInsets.only(left: 20, top: 2),
      child: Row(
        children: [
          Icon(Icons.email, color: AppColors.primary, size: 16),
          SizedBox(width: 4),
          GestureDetector(
            onTap: () => _launchEmail(conciergeEmail),
            child: Text(conciergeEmail, style: TextStyle(color: Colors.blue, fontSize: 13, decoration: TextDecoration.underline)),
          ),
        ],
      ),
    ),
],
      ],
    );

    // Details: Consultant, Venue, Service, Date, Time
    List<Widget> details = [];
    if (consultantName.isNotEmpty) details.add(_singleColumnInfo(Icons.person, 'Consultant', consultantName));
    if (venueName.isNotEmpty) details.add(_singleColumnInfo(Icons.location_on, 'Venue', venueName));
    if (serviceName.isNotEmpty) details.add(_singleColumnInfo(Icons.miscellaneous_services, 'Service', serviceName));
    if (appointmentTime.isNotEmpty) details.add(_singleColumnInfo(Icons.calendar_today, 'Date', appointmentTime));
    // If time is separately available, add it
    final timeStr = (data['appointmentTime'] is Timestamp)
      ? DateFormat('HH:mm').format((data['appointmentTime'] as Timestamp).toDate())
      : '';
    if (timeStr.isNotEmpty) details.add(_singleColumnInfo(Icons.access_time, 'Time', timeStr));

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
            // Determine the user's role
            final userRole = Provider.of<AppAuthProvider>(context, listen: false).appUser?.role;
            // Only floor manager can open appointment details
            if (appointmentId.isNotEmpty && userRole == 'floor_manager') {
              Navigator.of(context).pushNamed(
                '/floor_manager/appointment_details',
                arguments: {
                  'appointmentId': appointmentId,
                  'notification': notification,
                },
              );
              return;
            }
            // If minister, consultant, or concierge, handle chat navigation only
            if ((notificationType == 'message' || notificationType == 'chat' || notificationType == 'message_received' || notificationType == 'chat_message') && notification['appointmentId'] != null) {
              final senderId = notification['senderId'] ?? '';
              final senderRoleVal = notification['senderRole'] ?? '';
              final senderNameVal = notification['senderName'] ?? '';
              if (userRole == 'consultant') {
                FirebaseFirestore.instance
                    .collection('appointments')
                    .doc(notification['appointmentId'])
                    .get()
                    .then((appointmentDoc) {
                  if (appointmentDoc.exists) {
                    final appointmentData = appointmentDoc.data() as Map<String, dynamic>;
                    appointmentData['id'] = notification['appointmentId'];
                    Navigator.pushNamed(context, '/consultant/home').then((_) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        showDialog(
                          context: context,
                          builder: (context) => ConsultantAppointmentWidget(
                            appointment: appointmentData,
                            isEvenCard: false,
                          ),
                        );
                      });
                    });
                  }
                });
                return;
              } else if (userRole == 'concierge') {
                FirebaseFirestore.instance
                    .collection('appointments')
                    .doc(notification['appointmentId'])
                    .get()
                    .then((appointmentDoc) {
                  if (appointmentDoc.exists) {
                    final appointmentData = appointmentDoc.data() as Map<String, dynamic>;
                    appointmentData['id'] = notification['appointmentId'];
                    Navigator.pushNamed(context, '/concierge/home').then((_) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        showDialog(
                          context: context,
                          builder: (context) => ConciergeAppointmentWidget(
                            appointment: appointmentData,
                            isEvenCard: false,
                          ),
                        );
                      });
                    });
                  }
                });
                return;
              } else if (userRole == 'minister') {
                // Open chat dialog for minister, do NOT navigate to floor manager screen
                _openChatFromNotification(context, notification['appointmentId'], senderRoleVal, senderId, senderNameVal);
                return;
              }
            }
            // For all other cases, do nothing (prevent navigation)
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
                        mainAxisAlignment: MainAxisAlignment.start,
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
                        ],
                      ),
                      if (createdAt != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2.0, bottom: 2.0),
                          child: Text(
                            DateFormat('MMM d, h:mm a').format(createdAt),
                            style: TextStyle(color: Colors.grey[500], fontSize: 12),
                          ),
                        ),
                      if (body.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0, bottom: 2.0),
                          child: notification['role'] == 'minister'
                              ? Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.13),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.primary, width: 1.2),
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
                      // Show consultant and concierge contact info if present
                      if ((data['consultantPhone'] != null && data['consultantPhone'].toString().isNotEmpty) ||
                          (data['consultantEmail'] != null && data['consultantEmail'].toString().isNotEmpty) ||
                          (data['conciergePhone'] != null && data['conciergePhone'].toString().isNotEmpty) ||
                          (data['conciergeEmail'] != null && data['conciergeEmail'].toString().isNotEmpty))
                        Padding(
                          padding: const EdgeInsets.only(top: 6.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (data['consultantPhone'] != null && data['consultantPhone'].toString().isNotEmpty)
                                _singleColumnInfo(Icons.phone, 'Consultant Phone', data['consultantPhone'].toString()),
                              if (data['consultantEmail'] != null && data['consultantEmail'].toString().isNotEmpty)
                                _singleColumnInfo(Icons.email, 'Consultant Email', data['consultantEmail'].toString()),
                              if (data['conciergePhone'] != null && data['conciergePhone'].toString().isNotEmpty)
                                _singleColumnInfo(Icons.phone, 'Concierge Phone', data['conciergePhone'].toString()),
                              if (data['conciergeEmail'] != null && data['conciergeEmail'].toString().isNotEmpty)
                                _singleColumnInfo(Icons.email, 'Concierge Email', data['conciergeEmail'].toString()),
                            ],
                          ),
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

  Widget _singleColumnInfo(IconData icon, String label, String value) {
    final isPhone = label.toLowerCase().contains('phone');
    final isEmail = label.toLowerCase().contains('email');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 26, top: 2),
            child: isPhone
                ? GestureDetector(
                    onTap: () => NotificationItem._launchPhoneCall(value),
                    child: Text(
                      value,
                      style: const TextStyle(color: Colors.blue, fontSize: 13, decoration: TextDecoration.underline),
                    ),
                  )
                : isEmail
                    ? GestureDetector(
                        onTap: () => _launchEmail(value),
                        child: Text(
                          value,
                          style: const TextStyle(color: Colors.blue, fontSize: 13, decoration: TextDecoration.underline),
                        ),
                      )
                    : Text(value, style: const TextStyle(color: Colors.white, fontSize: 13)),
          ),
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
                            String? senderRole, String? senderId, String? senderName) async {
    final appointmentId = appointment['id'] ?? appointment['appointmentId'];
    // If already on minister home, open dialog directly; otherwise, navigate and let home screen handle
    bool isMinisterHome = ModalRoute.of(context)?.settings.name == '/minister/home';
    // Always fetch latest appointment data and open chat dialog directly
    final appointmentDoc = await FirebaseFirestore.instance.collection('appointments').doc(appointmentId).get();
    final appointmentData = appointmentDoc.data() ?? {};
    appointmentData['id'] = appointmentId;
    if (senderRole != null) appointmentData['selectedRole'] = senderRole;
    if (senderId != null) appointmentData['selectedStaffId'] = senderId;
    if (senderName != null) appointmentData['selectedStaffName'] = senderName;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return MinisterChatDialog(appointment: appointmentData);
      },
    );
  }
  
  // Open chat dialog for consultant
  void _openConsultantChatDialog(BuildContext context, Map<String, dynamic> appointment) {
    Navigator.pushNamed(context, '/consultant/home').then((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          builder: (context) => MinisterChatDialog(
            appointment: appointment,
          ),
        );
      });
    });
  }

  // Open chat dialog for concierge
  void _openConciergeChatDialog(BuildContext context, Map<String, dynamic> appointment) {
    // Navigate to concierge home and show a message
    Navigator.pushNamed(context, '/concierge/home').then((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.black,
            title: Text('Chat Available', style: TextStyle(color: AppColors.primary)),
            content: Text('Please view the appointment details to chat with the minister.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('OK', style: TextStyle(color: AppColors.primary)),
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
    // Get the FloorManagerHomeScreenNew state to access its _openChatDialog method
    Navigator.pushNamed(context, '/floor_manager/home').then((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.black,
            title: Text('Chat with $recipientName', style: TextStyle(color: AppColors.primary)),
            content: Text('Please view the appointment to chat with $recipientName.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('OK', style: TextStyle(color: AppColors.primary)),
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
