import 'package:flutter/material.dart';
import 'package:vip_lounge/core/constants/colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/app_auth_provider.dart';
import 'package:provider/provider.dart';
import '../../features/floor_manager/presentation/widgets/notification_item.dart';
import 'package:vip_lounge/core/widgets/unified_appointment_card.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vip_lounge/core/widgets/unified_appointment_card.dart';

/// A uniform notification list widget for all roles (minister, floor manager, consultant, etc)
/// Queries notifications by assignedToId and displays them using NotificationItem.
class RoleNotificationList extends StatelessWidget {
  // Returns the full English month name for a given month number (1-12)
  static String _monthName(int month) {
    const months = [
      '', // 0-index unused
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    if (month < 1 || month > 12) return '';
    return months[month];
  }

  // Determines if a date header should be shown above the notification at [index]
  bool _shouldShowDateHeader(List notifications, int index, DateTime? notifDate) {
    if (index == 0 || notifDate == null) return true;
    final prevData = (notifications[index - 1].data() as Map<String, dynamic>);
    final prevTimestamp = prevData['timestamp'] ?? prevData['createdAt'];
    DateTime? prevDate;
    if (prevTimestamp is Timestamp) {
      prevDate = prevTimestamp.toDate();
    } else if (prevTimestamp is DateTime) {
      prevDate = prevTimestamp;
    } else if (prevTimestamp is String) {
      prevDate = DateTime.tryParse(prevTimestamp);
    }
    if (prevDate == null) return true;
    return prevDate.year != notifDate.year || prevDate.month != notifDate.month || prevDate.day != notifDate.day;
  }

  final String? userId;
  final String? userRole;
  final bool showTitle;

  const RoleNotificationList({
    Key? key,
    required this.userId,
    this.userRole,
    this.showTitle = false,
  }) : super(key: key);

  // Use timestamp if available, else fallback to createdAt
  Stream<QuerySnapshot> _notificationStream(String? uid) {
    if (uid == null || uid.isEmpty) {
      // Return empty stream if no user
      return const Stream.empty();
    }
    // Try to order by timestamp, fallback to createdAt
    return FirebaseFirestore.instance
        .collection('notifications')
        .where('assignedToId', isEqualTo: uid)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveUserId = userId ?? Provider.of<AppAuthProvider>(context).appUser?.uid;
    final effectiveUserRole = userRole ?? Provider.of<AppAuthProvider>(context).appUser?.role;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: showTitle
          ? AppBar(
              backgroundColor: Colors.transparent,
              title: const Text('Notifications'),
            )
          : null,
      body: StreamBuilder<QuerySnapshot>(
        stream: _notificationStream(effectiveUserId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            if ((effectiveUserRole ?? '').toLowerCase() == 'concierge') {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 64, color: Color(0xFFD4AF37)),
                    SizedBox(height: 16),
                    Text(
                      'Unable to load notifications. Please contact support.',
                      style: TextStyle(color: Color(0xFFD4AF37), fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Text(
                      snapshot.error.toString(),
                      style: TextStyle(color: Color(0xFFD4AF37), fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }
            return Center(
              child: Text('Error: \\${snapshot.error}', style: const TextStyle(color: Colors.white)),
            );
          }
          if (!snapshot.hasData) {
            if ((effectiveUserRole ?? '').toLowerCase() == 'concierge') {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.hourglass_empty, size: 64, color: Color(0xFFD4AF37)),
                    SizedBox(height: 16),
                    Text(
                      'Loading notifications...',
                      style: TextStyle(color: Color(0xFFD4AF37), fontSize: 16),
                    ),
                  ],
                ),
              );
            }
            return const Center(
              child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37))),
            );
          }
          final notifications = snapshot.data!.docs
              .where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final type = data['type'] ?? data['notificationType'];
                return type != null && type.toString().trim().isNotEmpty;
              })
              .toList();
          if (notifications.isEmpty) {
            if ((effectiveUserRole ?? '').toLowerCase() == 'concierge') {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.notifications_off, size: 64, color: Color(0xFFD4AF37)),
                    SizedBox(height: 16),
                    Text(
                      'No notifications found for Concierge.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFFD4AF37), fontSize: 16),
                    ),
                  ],
                ),
              );
            }
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off, size: 64, color: Colors.grey[700]),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[400], fontSize: 16),
                  ),
                ],
              ),
            );
          }
          // For ministers, show notification as colored separator rows, not cards
          if ((effectiveUserRole ?? '').toLowerCase() == 'minister') {
            return ListView.separated(
              itemCount: notifications.length,
              separatorBuilder: (context, index) {
                final type = (notifications[index].data() as Map<String, dynamic>)['type'] ?? '';
                Color color;
                switch (type) {
                  case 'sickleave':
                    color = AppColors.primary;
                    break;
                  case 'staff_assignment':
                    color = Colors.amber;
                    break;
                  case 'booking_confirmation':
                    color = Colors.green;
                    break;
                  default:
                    color = Colors.grey;
                }
                return Divider(thickness: 3, color: color);
              },
              itemBuilder: (context, index) {
                final notification = notifications[index];
                final data = notification.data() as Map<String, dynamic>;
                final type = data['type'] ?? '';
                Color notificationColor;
                final lowerType = (type?.toString() ?? '').toLowerCase();
                final lowerBody = (data['body']?.toString() ?? '').toLowerCase();
                // Red for message/chat, blue for any appointment/thank you/reminder/booking/cancel types
                Gradient notificationGradient;
Color textColor = Colors.white;
if (lowerType.contains('message') || lowerType.contains('chat')) {
  notificationGradient = LinearGradient(colors: [Colors.red.shade900, Colors.orange.shade700], begin: Alignment.topLeft, end: Alignment.bottomRight);
  textColor = Colors.amberAccent;
} else if (lowerType.contains('appointment') || lowerType.contains('booking') || lowerType.contains('reminder') || lowerType.contains('cancel') || lowerType.contains('thank you') || lowerBody.contains('appointment') || lowerBody.contains('booking') || lowerBody.contains('reminder') || lowerBody.contains('cancel') || lowerBody.contains('thank you')) {
  notificationGradient = LinearGradient(colors: [Colors.blue.shade900, Colors.purple.shade700], begin: Alignment.topLeft, end: Alignment.bottomRight);
  textColor = Colors.amberAccent;
} else if (lowerType.contains('assignment') || lowerType.contains('staff_assignment')) {
  notificationGradient = LinearGradient(colors: [Colors.green.shade800, Colors.teal.shade400], begin: Alignment.topLeft, end: Alignment.bottomRight);
  textColor = Colors.black;
} else {
  notificationGradient = LinearGradient(colors: [Colors.pink.shade700, Colors.deepPurple.shade400], begin: Alignment.topLeft, end: Alignment.bottomRight);
  textColor = Colors.white;
}
                // --- Date header logic ---
final timestamp = data['timestamp'] ?? data['createdAt'];
DateTime? notifDate;
if (timestamp is Timestamp) {
  notifDate = timestamp.toDate();
} else if (timestamp is DateTime) {
  notifDate = timestamp;
} else if (timestamp is String) {
  notifDate = DateTime.tryParse(timestamp);
}
String dateHeader = notifDate != null ? '${notifDate.day.toString().padLeft(2, '0')} ${_monthName(notifDate.month)} ${notifDate.year}' : '';

return Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    if (index == 0 || _shouldShowDateHeader(notifications, index, notifDate))
      Padding(
        padding: const EdgeInsets.only(left: 16, top: 12, bottom: 4),
        child: Text(dateHeader, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
      ),
    Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      decoration: BoxDecoration(
        gradient: notificationGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: ExpansionTile(
        backgroundColor: Colors.transparent,
        title: Text(
          lowerType.contains('staff_assignment') || lowerType.contains('assignment')
            ? 'Consultant Assigned'
            : (data['title'] ?? ''),
          style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 17),
        ),
        trailing: (data.containsKey('isRead') && data['isRead'] == false)
          ? Icon(Icons.circle, color: Colors.amberAccent, size: 12)
          : null,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildNotificationBody(
              context,
              data,
              consultantPhone: (lowerType.contains('assignment') || lowerType.contains('staff_assignment'))
                ? data['consultantPhone'] ?? data['consultant_phone']
                : (notificationGradient.colors.first == Colors.blue.shade900 ? data['consultantPhone'] : null),
              conciergePhone: (lowerType.contains('assignment') || lowerType.contains('staff_assignment'))
                ? data['conciergePhone'] ?? data['concierge_phone']
                : (notificationGradient.colors.first == Colors.blue.shade900 ? data['conciergePhone'] : null),
              showAssignmentDetails: lowerType.contains('assignment') || lowerType.contains('staff_assignment'),
              textColor: textColor,
            ),
          ),
        ],
        onExpansionChanged: (expanded) async {
          if (expanded) {
            // Mark as read in Firestore if not already
            if (!(data['isRead'] == true)) {
              await FirebaseFirestore.instance
                .collection('notifications')
                .doc(notification.id)
                .update({'isRead': true});
            }
            // Handle navigation for message and appointment/thank you/cancel/reminder types
            final notificationType = (data['type'] ?? data['notificationType'] ?? '').toString().toLowerCase();
            final bodyText = (data['body'] ?? '').toString().toLowerCase();
            final appointmentId = data['appointmentId'] ?? data['data']?['appointmentId'] ?? data['data']?['id'];
            if (notificationType.contains('message') || notificationType.contains('chat')) {
              // Open chat dialog with appointment context
              if (appointmentId != null && appointmentId.toString().isNotEmpty) {
                final apptDoc = await FirebaseFirestore.instance.collection('appointments').doc(appointmentId.toString()).get();
                if (apptDoc.exists) {
                  final apptData = apptDoc.data() as Map<String, dynamic>;
                  apptData['id'] = appointmentId;
                  // Use the minister chat dialog
                  // ignore: use_build_context_synchronously
                  Navigator.of(context).pushNamed(
                    '/minister/home/chat',
                    arguments: {'appointmentId': appointmentId, 'appointment': apptData},
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No appointment found for this chat notification.')),
                  );
                }
              }
            } else if (
              notificationGradient.colors.first == Colors.blue.shade900 &&
              appointmentId != null && appointmentId.toString().isNotEmpty
            ) {
              try {
                final apptDoc = await FirebaseFirestore.instance.collection('appointments').doc(appointmentId.toString()).get();
                String? consultantPhone;
                String? conciergePhone;
                if (apptDoc.exists) {
                  final apptData = apptDoc.data() as Map<String, dynamic>;
                  consultantPhone = apptData['consultantPhone'] ?? apptData['consultant_phone'] ?? '';
                  conciergePhone = apptData['conciergePhone'] ?? apptData['concierge_phone'] ?? '';
                  final apptMap = {'id': apptDoc.id, ...apptData};
                  await showDialog(
                    context: context,
                    builder: (_) => Dialog(
                      backgroundColor: Colors.transparent,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue[900],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: _buildNotificationBody(
                          context,
                          data,
                          consultantPhone: consultantPhone,
                          conciergePhone: conciergePhone,
                        ),
                      ),
                    ),
                  );
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => UnifiedAppointmentCard(
                        role: effectiveUserRole ?? 'minister',
                        isConsultant: false,
                        ministerName: apptMap['ministerName'] ?? '',
                        appointmentId: appointmentId,
                        appointmentInfo: apptMap,
                        date: apptMap['appointmentTime'] is DateTime
                            ? apptMap['appointmentTime']
                            : (apptMap['appointmentTime'] is Timestamp)
                                ? (apptMap['appointmentTime'] as Timestamp).toDate()
                                : null,
                        viewOnly: true,
                      ),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No appointment details found for this notification.')),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error fetching appointment details: $e')),
                );
              }
            }
          }
        },
      ),
    ),
  ],
);

              },
            );
          }
          // All other roles: keep card UI
          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              final notificationData = notification.data() as Map<String, dynamic>;
              notificationData['id'] = notification.id;

              return Dismissible(
                key: Key(notification.id),
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16.0),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                direction: DismissDirection.endToStart,
                child: NotificationItem(
                  notification: notificationData,
                  onTapCallback: () async {
                    await FirebaseFirestore.instance
                        .collection('notifications')
                        .doc(notification.id)
                        .update({'isRead': true});

                    final notificationType = notificationData['type'] ?? notificationData['notificationType'] ?? '';
                    final appointmentId = notificationData['appointmentId'] ?? notificationData['data']?['appointmentId'] ?? notificationData['data']?['id'];

                    if (notificationType == 'message' || notificationType == 'chat' || notificationType == 'message_received' || notificationType == 'chat_message') {
                      if (appointmentId != null && appointmentId.toString().isNotEmpty) {
                        Navigator.of(context).pushNamed(
                          '/minister/home/chat',
                          arguments: {'appointmentId': appointmentId},
                        );
                        return;
                      }
                    } else if (appointmentId != null && appointmentId.toString().isNotEmpty) {
                      final appointments = Provider.of<AppAuthProvider>(context, listen: false).appointments;
                      Map<String, dynamic>? appointment = appointments.firstWhere(
                        (a) => (a['id']?.toString() ?? '') == appointmentId.toString(),
                        orElse: () => {},
                      );

                      if (appointment.isNotEmpty) {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => UnifiedAppointmentCard(
                              role: effectiveUserRole ?? 'consultant',
                              isConsultant: (effectiveUserRole ?? '').toLowerCase() == 'consultant',
                              ministerName: appointment['ministerName'] ?? '',
                              appointmentId: appointmentId,
                              appointmentInfo: appointment,
                              date: appointment['appointmentTime'] is DateTime
                                  ? appointment['appointmentTime']
                                  : (appointment['appointmentTime'] is Timestamp)
                                      ? (appointment['appointmentTime'] as Timestamp).toDate()
                                      : null,
                              viewOnly: true,
                            ),
                          ),
                        );
                      } else {
                        try {
                          final apptDoc = await FirebaseFirestore.instance.collection('appointments').doc(appointmentId.toString()).get();
                          if (apptDoc.exists) {
                            final apptData = apptDoc.data() as Map<String, dynamic>;
                            final apptMap = {'id': apptDoc.id, ...apptData};
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => UnifiedAppointmentCard(
                                  role: effectiveUserRole ?? 'consultant',
                                  isConsultant: (effectiveUserRole ?? '').toLowerCase() == 'consultant',
                                  ministerName: apptMap['ministerName'] ?? '',
                                  appointmentId: appointmentId,
                                  appointmentInfo: apptMap,
                                  date: apptMap['appointmentTime'] is DateTime
                                      ? apptMap['appointmentTime']
                                      : (apptMap['appointmentTime'] is Timestamp)
                                          ? (apptMap['appointmentTime'] as Timestamp).toDate()
                                          : null,
                                  viewOnly: true,
                                ),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('No appointment details found for this notification.')),
                            );
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error fetching appointment details: $e')),
                          );
                        }
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('No details available for this notification.')),
                      );
                    }
                  },
                  onDismissCallback: () {}
                )
              );
            },
          );
        },
      ),
    );
  }
}
  /// Helper to build notification body with clickable phone numbers for consultant/concierge
  Widget _buildNotificationBody(BuildContext context, Map<String, dynamic> data, {String? consultantPhone, String? conciergePhone, bool showAssignmentDetails = false, Color? textColor}) {
    // Gather all possible emails and phones
    final userEmail = data['userEmail'] ?? '';
    final consultantEmail = data['consultantEmail'] ?? '';
    final conciergeEmail = data['conciergeEmail'] ?? '';
    final senderEmail = data['senderEmail'] ?? '';
    final senderName = data['senderName'] ?? '';
    final senderPhone = data['senderPhone'] ?? '';
    final isMessage = (data['type']?.toString().toLowerCase() ?? '').contains('message') || (data['type']?.toString().toLowerCase() ?? '').contains('chat');
    final bodyText = data['body'] ?? '';
    final phoneWidgets = <Widget>[];
    if (isMessage) {
      // Show message notification with sender info
      if (senderName.isNotEmpty) {
        phoneWidgets.add(Row(children: [
          Icon(Icons.person, color: textColor ?? Colors.white, size: 18),
          SizedBox(width: 6),
          Text('New message from $senderName', style: TextStyle(fontWeight: FontWeight.bold, color: textColor ?? Colors.white)),
        ]));
      }
      if (senderPhone.isNotEmpty) {
        phoneWidgets.add(Row(children: [
          Icon(Icons.phone, color: textColor ?? Colors.white, size: 18),
          SizedBox(width: 6),
          GestureDetector(
            onTap: () async {
              final url = 'tel:$senderPhone';
              if (await canLaunchUrl(Uri.parse(url))) {
                await launchUrl(Uri.parse(url));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Could not launch $senderPhone')),
                );
              }
            },
            child: Text(senderPhone, style: TextStyle(color: Colors.blueAccent, decoration: TextDecoration.underline)),
          ),
        ]));
      }
      if (senderEmail.isNotEmpty) {
        phoneWidgets.add(Row(children: [
          Icon(Icons.email, color: textColor ?? Colors.white, size: 18),
          SizedBox(width: 6),
          GestureDetector(
            onTap: () async {
              final url = 'mailto:$senderEmail';
              if (await canLaunchUrl(Uri.parse(url))) {
                await launchUrl(Uri.parse(url));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Could not launch mailto:$senderEmail')),
                );
              }
            },
            child: Text(senderEmail, style: TextStyle(color: Colors.blueAccent, decoration: TextDecoration.underline)),
          ),
        ]));
      }
    }
    if (showAssignmentDetails) {
      // Show full appointment details for assignment notifications
      final service = data['serviceName'] ?? data['service'] ?? '';
      final venue = data['venueName'] ?? data['venue'] ?? '';
      final time = data['appointmentTime'] ?? data['time'] ?? '';
      final consultant = data['consultantName'] ?? '';
      final concierge = data['conciergeName'] ?? '';
      phoneWidgets.addAll([
        if (consultant.isNotEmpty)
          Row(children: [
            Icon(Icons.person, color: textColor ?? Colors.black, size: 18),
            SizedBox(width: 6),
            Text('Consultant: $consultant', style: TextStyle(color: textColor ?? Colors.black)),
          ]),
        if (consultantPhone != null && consultantPhone.isNotEmpty)
          GestureDetector(
            onTap: () => launchUrl(Uri.parse('tel:$consultantPhone')),
            child: Row(children: [
              Icon(Icons.phone, color: textColor ?? Colors.black, size: 18),
              SizedBox(width: 6),
              Text('Call Consultant: $consultantPhone', style: TextStyle(decoration: TextDecoration.underline, color: textColor ?? Colors.black, fontWeight: FontWeight.bold)),
            ]),
          ),
        if (concierge.isNotEmpty)
          Row(children: [
            Icon(Icons.person, color: textColor ?? Colors.black, size: 18),
            SizedBox(width: 6),
            Text('Concierge: $concierge', style: TextStyle(color: textColor ?? Colors.black)),
          ]),
        if (conciergePhone != null && conciergePhone.isNotEmpty)
          GestureDetector(
            onTap: () => launchUrl(Uri.parse('tel:$conciergePhone')),
            child: Row(children: [
              Icon(Icons.phone, color: textColor ?? Colors.black, size: 18),
              SizedBox(width: 6),
              Text('Call Concierge: $conciergePhone', style: TextStyle(decoration: TextDecoration.underline, color: textColor ?? Colors.black, fontWeight: FontWeight.bold)),
            ]),
          ),
        if (service.toString().isNotEmpty)
          Row(children: [
            Icon(Icons.room_service, color: textColor ?? Colors.black, size: 18),
            SizedBox(width: 6),
            Text('Service: $service', style: TextStyle(color: textColor ?? Colors.black)),
          ]),
        if (venue.toString().isNotEmpty)
          Row(children: [
            Icon(Icons.location_on, color: textColor ?? Colors.black, size: 18),
            SizedBox(width: 6),
            Text('Venue: $venue', style: TextStyle(color: textColor ?? Colors.black)),
          ]),
        if (time.toString().isNotEmpty)
          Row(children: [
            Icon(Icons.access_time, color: textColor ?? Colors.black, size: 18),
            SizedBox(width: 6),
            Text('Time: $time', style: TextStyle(color: textColor ?? Colors.black)),
          ]),
        SizedBox(height: 10),
      ]);
    }
    if (consultantPhone != null && consultantPhone.isNotEmpty && !showAssignmentDetails) {
      phoneWidgets.add(Row(
        children: [
          const Icon(Icons.phone, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () async {
              final url = 'tel:$consultantPhone';
              if (await canLaunchUrl(Uri.parse(url))) {
                await launchUrl(Uri.parse(url));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Could not launch $consultantPhone')),
                );
              }
            },
            child: Text('Consultant: $consultantPhone', style: const TextStyle(color: Colors.white, decoration: TextDecoration.underline)),
          ),
        ],
      ));
      phoneWidgets.add(const SizedBox(height: 8));
    }
    if (conciergePhone != null && conciergePhone.isNotEmpty) {
      phoneWidgets.add(Row(
        children: [
          const Icon(Icons.phone, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () async {
              final url = 'tel:$conciergePhone';
              if (await canLaunchUrl(Uri.parse(url))) {
                await launchUrl(Uri.parse(url));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Could not launch $conciergePhone')),
                );
              }
            },
            child: Text('Concierge: $conciergePhone', style: const TextStyle(color: Colors.white, decoration: TextDecoration.underline)),
          ),
        ],
      ));
      phoneWidgets.add(const SizedBox(height: 8));
    }
    // Show emails if present (user, consultant, concierge)
    if (userEmail.isNotEmpty) {
      phoneWidgets.add(Row(children: [
        Icon(Icons.email, color: textColor ?? Colors.white, size: 18),
        SizedBox(width: 6),
        GestureDetector(
          onTap: () async {
            final url = 'mailto:$userEmail';
            if (await canLaunchUrl(Uri.parse(url))) {
              await launchUrl(Uri.parse(url));
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Could not launch mailto:$userEmail')),
              );
            }
          },
          child: Text(userEmail, style: TextStyle(color: Colors.blueAccent, decoration: TextDecoration.underline)),
        ),
      ]));
    }
    if (consultantEmail.isNotEmpty) {
      phoneWidgets.add(Row(children: [
        Icon(Icons.email, color: textColor ?? Colors.white, size: 18),
        SizedBox(width: 6),
        GestureDetector(
          onTap: () async {
            final url = 'mailto:$consultantEmail';
            if (await canLaunchUrl(Uri.parse(url))) {
              await launchUrl(Uri.parse(url));
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Could not launch mailto:$consultantEmail')),
              );
            }
          },
          child: Text(consultantEmail, style: TextStyle(color: Colors.blueAccent, decoration: TextDecoration.underline)),
        ),
      ]));
    }
    if (conciergeEmail.isNotEmpty) {
      phoneWidgets.add(Row(children: [
        Icon(Icons.email, color: textColor ?? Colors.white, size: 18),
        SizedBox(width: 6),
        GestureDetector(
          onTap: () async {
            final url = 'mailto:$conciergeEmail';
            if (await canLaunchUrl(Uri.parse(url))) {
              await launchUrl(Uri.parse(url));
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Could not launch mailto:$conciergeEmail')),
              );
            }
          },
          child: Text(conciergeEmail, style: TextStyle(color: Colors.blueAccent, decoration: TextDecoration.underline)),
        ),
      ]));
    }
    // Compute date/time string from timestamp or createdAt
    final timestamp = data['timestamp'] ?? data['createdAt'];
    DateTime? notifDate;
    if (timestamp is Timestamp) {
      notifDate = timestamp.toDate();
    } else if (timestamp is DateTime) {
      notifDate = timestamp;
    } else if (timestamp is String) {
      notifDate = DateTime.tryParse(timestamp);
    }
    String notifDateTimeStr = notifDate != null
        ? '${notifDate.day.toString().padLeft(2, '0')} ${RoleNotificationList._monthName(notifDate.month)} ${notifDate.year} • '
          + '${notifDate.hour.toString().padLeft(2, '0')}:${notifDate.minute.toString().padLeft(2, '0')}'
        : '';
    if (notifDateTimeStr.isNotEmpty) {
      phoneWidgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4.0),
          child: Text(
            notifDateTimeStr,
            style: TextStyle(fontSize: 12, color: (textColor ?? Colors.white).withOpacity(0.75)),
          ),
        ),
      );
    }
    // Add clickable consultant/concierge contact for staff_assignment/assignment
    final type = (data['type'] ?? data['notificationType'] ?? '').toString().toLowerCase();
    if (type.contains('assignment') || type.contains('staff_assignment')) {
      final cPhone = data['consultantPhone'] ?? data['consultant_phone'] ?? '';
      final cEmail = data['consultantEmail'] ?? '';
      final gPhone = data['conciergePhone'] ?? data['concierge_phone'] ?? '';
      final gEmail = data['conciergeEmail'] ?? '';
      if (cPhone.toString().isNotEmpty) {
        phoneWidgets.add(Row(children: [
          Icon(Icons.phone, color: Colors.blueAccent, size: 18),
          SizedBox(width: 6),
          GestureDetector(
            onTap: () async {
              final url = 'tel:$cPhone';
              if (await canLaunchUrl(Uri.parse(url))) {
                await launchUrl(Uri.parse(url));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Could not launch $cPhone')),
                );
              }
            },
            child: Text('Consultant: $cPhone', style: TextStyle(color: Colors.blueAccent, decoration: TextDecoration.underline)),
          ),
        ]));
      }
      if (cEmail.toString().isNotEmpty) {
        phoneWidgets.add(Row(children: [
          Icon(Icons.email, color: Colors.blueAccent, size: 18),
          SizedBox(width: 6),
          GestureDetector(
            onTap: () async {
              final url = 'mailto:$cEmail';
              if (await canLaunchUrl(Uri.parse(url))) {
                await launchUrl(Uri.parse(url));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Could not launch mailto:$cEmail')),
                );
              }
            },
            child: Text('Consultant: $cEmail', style: TextStyle(color: Colors.blueAccent, decoration: TextDecoration.underline)),
          ),
        ]));
      }
      if (gPhone.toString().isNotEmpty) {
        phoneWidgets.add(Row(children: [
          Icon(Icons.phone, color: Colors.tealAccent, size: 18),
          SizedBox(width: 6),
          GestureDetector(
            onTap: () async {
              final url = 'tel:$gPhone';
              if (await canLaunchUrl(Uri.parse(url))) {
                await launchUrl(Uri.parse(url));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Could not launch $gPhone')),
                );
              }
            },
            child: Text('Concierge: $gPhone', style: TextStyle(color: Colors.tealAccent, decoration: TextDecoration.underline)),
          ),
        ]));
      }
      if (gEmail.toString().isNotEmpty) {
        phoneWidgets.add(Row(children: [
          Icon(Icons.email, color: Colors.tealAccent, size: 18),
          SizedBox(width: 6),
          GestureDetector(
            onTap: () async {
              final url = 'mailto:$gEmail';
              if (await canLaunchUrl(Uri.parse(url))) {
                await launchUrl(Uri.parse(url));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Could not launch mailto:$gEmail')),
                );
              }
            },
            child: Text('Concierge: $gEmail', style: TextStyle(color: Colors.tealAccent, decoration: TextDecoration.underline)),
          ),
        ]));
      }
    }
    phoneWidgets.add(SelectableText(
      bodyText,
      style: const TextStyle(color: Colors.white),
    ));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: phoneWidgets,
    );
  }
