import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/app_auth_provider.dart';
import 'package:provider/provider.dart';
import '../../features/floor_manager/presentation/widgets/notification_item.dart';
import 'package:vip_lounge/core/widgets/unified_appointment_card.dart';

/// A uniform notification list widget for all roles (minister, floor manager, consultant, etc)
/// Queries notifications by assignedToId and displays them using NotificationItem.
class RoleNotificationList extends StatelessWidget {
  final String? userId;
  final String? userRole;
  final bool showTitle;

  const RoleNotificationList({
    Key? key,
    required this.userId,
    this.userRole,
    this.showTitle = false,
  }) : super(key: key);

  Stream<QuerySnapshot> _notificationStream(String? uid) {
    if (uid == null || uid.isEmpty) {
      // Return empty stream if no user
      return const Stream.empty();
    }
    return FirebaseFirestore.instance
        .collection('notifications')
        .where('assignedToId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
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
            return Center(
              child: Text('Error: \\${snapshot.error}', style: const TextStyle(color: Colors.white)),
            );
          }
          if (!snapshot.hasData) {
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
                onDismissed: (direction) async {
                  await FirebaseFirestore.instance
                      .collection('notifications')
                      .doc(notification.id)
                      .delete();
                },
                child: NotificationItem(
                  notification: notificationData,
                  onTapCallback: () async {
                    await FirebaseFirestore.instance
                        .collection('notifications')
                        .doc(notification.id)
                        .update({'isRead': true});
                    // Unified navigation logic for all roles and notification types
                    final notificationType = notificationData['type'] ?? notificationData['notificationType'] ?? '';
                    final appointmentId = notificationData['appointmentId'] ?? notificationData['data']?['appointmentId'];

                    // Open chat dialog for this appointment (if appointmentId exists)
                    if (notificationType == 'message' || notificationType == 'chat' || notificationType == 'message_received' || notificationType == 'chat_message') {
                      final appointmentId = notificationData['appointmentId'] ?? notificationData['data']?['appointmentId'] ?? notificationData['data']?['id'];
                      // Try to get consultantId and consultantName from notification or fallback to current user
                      String? consultantId = notificationData['consultantId'] ?? notificationData['data']?['consultantId'];
                      String? consultantName = notificationData['consultantName'] ?? notificationData['data']?['consultantName'];
                      if (consultantId == null || consultantName == null) {
                        final appUser = Provider.of<AppAuthProvider>(context, listen: false).appUser;
                        consultantId = appUser?.uid;
                        consultantName = appUser != null ? (appUser.firstName ?? '') + ' ' + (appUser.lastName ?? '') : null;
                      }
                      if (appointmentId != null && appointmentId.toString().isNotEmpty && consultantId != null && consultantName != null && consultantName.trim().isNotEmpty) {
                        Navigator.of(context).pushReplacementNamed(
                          '/consultant/chat',
                          arguments: {
                            'appointmentId': appointmentId,
                            'consultantId': consultantId,
                            'consultantName': consultantName.trim(),
                            'consultantRole': 'consultant',
                          },
                        );
                        return;
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('No chat details available for this notification.')),
                        );
                        return;
                      }
                    } else if (appointmentId != null && appointmentId.toString().isNotEmpty) {
                      // Always open UnifiedAppointmentCard in read-only mode for all other types
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
                        // Fetch from Firestore if not found locally
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
                            const SnackBar(content: Text('Error fetching appointment details.')),
                          );
                        }
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('No details available for this notification.')),
                      );
                    }
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
}
