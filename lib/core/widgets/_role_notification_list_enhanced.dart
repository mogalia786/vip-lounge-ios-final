import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../features/floor_manager/presentation/widgets/notification_item.dart';
import '../providers/app_auth_provider.dart';
import 'unified_appointment_card.dart';

/// Enhanced, robust, and clean notification list widget for all roles.
/// Handles Firestore notification querying, read/dismiss logic, and navigation to appointment details.
class RoleNotificationListEnhanced extends StatelessWidget {
  final String? userId;
  final String? userRole;
  final bool showTitle;

  const RoleNotificationListEnhanced({
    Key? key,
    required this.userId,
    this.userRole,
    this.showTitle = false,
  }) : super(key: key);

  Color _getNotificationIconColor(String type) {
    switch (type) {
      case 'booking_confirmation':
      case 'booking_creation':
        return Colors.green;
      case 'booking_update':
      case 'booking_cancel':
        return Colors.orange;
      case 'chat':
        return Colors.blue;
      case 'attendance':
        return Colors.purple;
      case 'task':
        return Colors.brown;
      default:
        return Colors.grey;
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _notificationStream(String? uid) {
    if (uid == null || uid.isEmpty) {
      return const Stream.empty();
    }
    return FirebaseFirestore.instance
        .collection('notifications')
        .where('assignedToId', isEqualTo: uid)
        .where('role', isEqualTo: userRole)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> _handleNotificationTap(
    BuildContext context,
    Map<String, dynamic> notificationData,
    QueryDocumentSnapshot<Map<String, dynamic>> notification,
    String? effectiveUserRole,
  ) async {
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(notification.id)
        .update({'isRead': true});
    final notificationType = notificationData['type'] ?? notificationData['notificationType'] ?? '';
    final rawData = notification.data();
    dynamic appointmentId = rawData['appointmentId'];
    if (appointmentId == null && rawData['data'] is Map) {
      appointmentId = rawData['data']['appointmentId'];
    }
    if (appointmentId == null || appointmentId.toString().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No details available for this notification.')),
      );
      return;
    }
    if (notificationType == 'assignment' || notificationType == 'staff_assignment') {
      try {
        final apptQuery = await FirebaseFirestore.instance
            .collection('appointments')
            .where('appointmentId', isEqualTo: appointmentId.toString())
            .get();
        if (apptQuery.docs.isNotEmpty) {
          final apptDoc = apptQuery.docs.first;
          final apptData = apptDoc.data();
          final apptMap = {'id': apptDoc.id, if (apptData != null) ...apptData};
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
            const SnackBar(content: Text('Appointment details not found.')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error loading appointment details.')),
        );
      }
    } else {
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
          final apptDoc = await FirebaseFirestore.instance
              .collection('appointments')
              .doc(appointmentId.toString())
              .get();
          if (apptDoc.exists) {
            final apptData = apptDoc.data();
            final apptMap = {'id': apptDoc.id, if (apptData != null) ...apptData};
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
    }
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
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _notificationStream(effectiveUserId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.white)));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37))));
          }
          final notifications = snapshot.data!.docs
              .where((doc) {
                final data = doc.data();
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
                  Text('No notifications', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[400], fontSize: 16)),
                ],
              ),
            );
          }
          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              final notificationData = notification.data();
              notificationData['id'] = notification.id;
              Color _getNotificationIconColor(String type) {
                switch (type) {
                  case 'booking_confirmation':
                  case 'booking_creation':
                    return Colors.green;
                  case 'booking_update':
                  case 'booking_cancel':
                    return Colors.orange;
                  case 'chat':
                    return Colors.blue;
                  case 'attendance':
                    return Colors.purple;
                  case 'task':
                    return Colors.brown;
                  default:
                    return Colors.grey;
                }
              }
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
                  onTapCallback: notificationData['type'] == 'booking_confirmation' || notificationData['notificationType'] == 'booking_confirmation'
                      ? null
                      : () => _handleNotificationTap(context, notificationData, notification, effectiveUserRole),
                  onDismissCallback: () => FirebaseFirestore.instance
                        .collection('notifications')
                        .doc(notification.id)
                        .delete(),
                  iconColor: _getNotificationIconColor(notificationData['type'] ?? notificationData['notificationType'] ?? ''),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
