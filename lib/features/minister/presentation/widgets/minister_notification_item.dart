import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/colors.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/app_auth_provider.dart';
import '../../../../core/services/vip_notification_service.dart';

class MinisterNotificationItem extends StatefulWidget {
  final Map<String, dynamic> notification;
  final VoidCallback? onTap;
  final void Function(int rating, String comment)? onRate;

  MinisterNotificationItem({Key? key, required this.notification, this.onTap, this.onRate}) : super(key: key);

  @override
  _MinisterNotificationItemState createState() => _MinisterNotificationItemState();
}

class _MinisterNotificationItemState extends State<MinisterNotificationItem> {
  late bool _hasRatedLocal;

  // Returns sender info for appointment notifications based on notification header
  Future<Map<String, String>> _likeIsAppointment(Map<String, dynamic> notification) async {
    final data = notification['data'] ?? {};
    final appointmentId = notification['appointmentId'] ?? data['appointmentId'];
    String senderName = '';
    String senderId = '';
    String staffRole = '';
    String header = (notification['title'] ?? notification['body'] ?? '').toString().toLowerCase();
    if (appointmentId != null && appointmentId.toString().isNotEmpty) {
      try {
        final appointmentDoc = await FirebaseFirestore.instance.collection('appointments').doc(appointmentId).get();
        final appointmentData = appointmentDoc.data();
        if (appointmentData != null) {
          if (header.contains('concierge')) {
            senderId = appointmentData['conciergeId'] ?? '';
            senderName = appointmentData['conciergeName'] ?? '';
            staffRole = appointmentData['conciergeRole'] ?? appointmentData['role'] ?? notification['role'] ?? 'concierge';
          } else if (header.contains('consultant')) {
            senderId = appointmentData['consultantId'] ?? '';
            senderName = appointmentData['consultantName'] ?? '';
            staffRole = appointmentData['consultantRole'] ?? appointmentData['role'] ?? notification['role'] ?? 'consultant';
          } else if (header.contains('assignedstaff') || header.contains('assigned staff')) {
            senderId = appointmentData['assignedStaffId'] ?? '';
            senderName = appointmentData['assignedStaffName'] ?? '';
            staffRole = appointmentData['assignedStaffRole'] ?? appointmentData['role'] ?? notification['role'] ?? 'staff';
          } else {
            // Fallback: prefer consultant, then concierge, then assignedStaff
            senderId = appointmentData['consultantId'] ?? appointmentData['conciergeId'] ?? appointmentData['assignedStaffId'] ?? '';
            senderName = appointmentData['consultantName'] ?? appointmentData['conciergeName'] ?? appointmentData['assignedStaffName'] ?? '';
            staffRole = appointmentData['consultantRole'] ?? appointmentData['conciergeRole'] ?? appointmentData['assignedStaffRole'] ?? appointmentData['role'] ?? notification['role'] ?? 'consultant';
          }
        } else {
          // No appointment data found, fallback to notification
          staffRole = notification['role'] ?? data['role'] ?? 'consultant';
        }
      } catch (e) {
        debugPrint('ERROR: _likeIsAppointment failed: $e');
        staffRole = notification['role'] ?? data['role'] ?? 'consultant';
      }
    } else {
      // No appointmentId, fallback to notification
      staffRole = notification['role'] ?? data['role'] ?? 'consultant';
    }
    debugPrint('DEBUG: _likeIsAppointment returning role: ' + staffRole);
    return {'senderId': senderId, 'senderName': senderName, 'role': staffRole};
  }

  @override
  void initState() {
    super.initState();
    _hasRatedLocal = widget.notification['hasRated'] == true;
  }

  String _formatTime(dynamic timestamp) {
    DateTime? dt;
    if (timestamp is DateTime) {
      dt = timestamp;
    } else if (timestamp is String) {
      dt = DateTime.tryParse(timestamp);
    } else if (timestamp != null && timestamp.toString().isNotEmpty) {
      try {
        dt = DateTime.parse(timestamp.toString());
      } catch (_) {}
    }
    if (dt == null) return '';
    return DateFormat('HH:mm').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.notification;
    // For query notifications, always use senderName from notification data for header
    String senderName = '';
    String senderId = '';
    final notificationType = data['type'] ?? '';
    final isQuery = notificationType == 'query' || notificationType == 'query_resolved';
    if (isQuery) {
      senderName = data['senderName'] ?? widget.notification['senderName'] ?? '';
      senderId = data['senderId'] ?? widget.notification['senderId'] ?? '';
    } else {
      senderName = data['senderName'] ?? data['staffName'] ?? data['consultantName'] ?? data['conciergeName'] ?? '';
      senderId = data['senderId'] ?? data['staffId'] ?? data['consultantId'] ?? data['conciergeId'] ?? '';
    }
    final title = data['title']?.toString() ?? '';
    final body = data['body']?.toString() ?? '';
    final time = _formatTime(data['createdAt'] ?? data['timestamp']);

    // For 'concierge assigned' or 'consultant assigned', ensure name/id is used from data, not Firestore
    // Only show admin toast if BOTH name and id are missing
    bool needsAppointmentFetch = false;
    final headerText = (title + ' ' + body).toLowerCase();
    if ((senderName.isEmpty || senderId.isEmpty) && (headerText.contains('concierge assigned') || headerText.contains('consultant assigned'))) {
      needsAppointmentFetch = false; // Don't fetch, just use what is available
    }
    // For all other notifications, only fetch if both are missing
    if (senderName.isEmpty && senderId.isEmpty) {
      needsAppointmentFetch = true;
    }

    Widget buildHeader(String name) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6.0),
        child: Text(
          name,
          style: const TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      );
    }

    FutureBuilder<Map<String, String>> buildWithAppointmentFetch(Widget Function(String, String) builder) {
      return FutureBuilder<Map<String, String>>(
        future: _likeIsAppointment(widget.notification),
        builder: (context, snapshot) {
          String name = senderName;
          String id = senderId;
          if (snapshot.hasData) {
            name = snapshot.data!['senderName'] ?? '';
            id = snapshot.data!['senderId'] ?? '';
          }
          return builder(name, id);
        },
      );
    }

    Widget notificationContent(String name, String id) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (name.isNotEmpty) buildHeader(name),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title.isNotEmpty)
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    if (body.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6.0, bottom: 10.0),
                        child: Text(
                          body,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                time,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          // Show rating button for all notifications except messages, if not rated and name/id is present
          if (!_hasRatedLocal && notificationType != 'message' && name.isNotEmpty && id.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.red ?? Colors.red, Colors.red.shade700, Colors.red.shade400],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.18),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () async {
                          // Only show toast if both name and id are missing
                          if (name.isEmpty || id.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Cannot submit rating: sender info missing. Please contact admin.')),
                            );
                            return;
                          }
                          final result = await showDialog(
                            context: context,
                            builder: (context) => _RatingDialog(senderName: name, senderId: id),
                          );
                          if (result is Map && result['hasRated'] == true) {
                            setState(() => _hasRatedLocal = true);
                          }
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.star, color: Colors.white, size: 22),
                            SizedBox(width: 8),
                            Text('Rate Experience', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue[900],
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: needsAppointmentFetch
        ? buildWithAppointmentFetch(notificationContent)
        : notificationContent(senderName, senderId),
    );
  }
}

class _RatingDialog extends StatefulWidget {
  final String senderName;
  final String senderId;
  const _RatingDialog({Key? key, required this.senderName, required this.senderId}) : super(key: key);

  @override
  State<_RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<_RatingDialog> {
  @override
  void dispose() {
    debugPrint('DEBUG: _RatingDialogState disposed');
    super.dispose();
  }

  int _rating = 0;
  String _comment = '';
  bool _submitting = false;

  void _submitRating() async {
    debugPrint('DEBUG: _submitRating called');
    setState(() => _submitting = true);
    final appAuth = Provider.of<AppAuthProvider>(context, listen: false);
    final user = appAuth.appUser;
    final notification = (context.findAncestorWidgetOfExactType<MinisterNotificationItem>()?.notification ?? {}) as Map<String, dynamic>;
    final data = notification['data'] ?? {};
    final queryId = notification['queryId'] ?? data['queryId'] ?? data['referenceNumber'] ?? data['query'];
    final appointmentId = notification['appointmentId'] ?? data['appointmentId'];

    // Fetch sender info AND role
    final senderInfo = await _likeIsAppointment(notification);
    String senderName = senderInfo['senderName'] ?? widget.senderName;
    String senderId = senderInfo['senderId'] ?? widget.senderId;
    String staffRole = senderInfo['role'] ?? 'consultant';

    final notificationId = notification['id'];
    final now = DateTime.now();
    if ((senderName.isEmpty || senderId.isEmpty)) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot submit rating: sender info missing.')),
      );
      return;
    }
    try {
      debugPrint('DEBUG: _submitRating writing role: ' + staffRole);
      await FirebaseFirestore.instance.collection('ratings').add({
        'senderName': senderName,
        'senderId': senderId,
        'role': staffRole,
        'rating': _rating,
        'comment': _comment,
        'createdAt': now,
        'ratedBy': user?.uid,
        'isQuery': queryId != null && queryId.toString().isNotEmpty,
        'queryId': queryId ?? '',
        'appointmentId': appointmentId ?? '',
      });
      // Only update queries/appointments if a valid ID is present
      if (queryId != null && queryId.toString().isNotEmpty) {
        await FirebaseFirestore.instance.collection('queries').doc(queryId).update({
          'rating': _rating,
          'ratingComment': _comment,
          'ratedAt': now,
          'ratedBy': user?.uid,
        });
      } else if (appointmentId != null && appointmentId.toString().isNotEmpty) {
        await FirebaseFirestore.instance.collection('appointments').doc(appointmentId).update({
          'rating': _rating,
          'ratingComment': _comment,
          'ratedAt': now,
          'ratedBy': user?.uid,
        });
      }
      if (notificationId != null && notificationId.toString().isNotEmpty) {
        await FirebaseFirestore.instance.collection('notifications').doc(notificationId).update({'hasRated': true});
      }
      Navigator.of(context).pop({'rating': _rating, 'comment': _comment, 'hasRated': true});
      setState(() => _submitting = false);
    } catch (e) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting rating: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.blue[900],
      title: const Text('Rate Your Experience', style: TextStyle(color: Colors.white)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 0),
                child: GestureDetector(
                  onTap: () {
                    setState(() => _rating = index + 1);
                  },
                  child: Icon(
                    Icons.star,
                    color: _rating > index ? Colors.amber : Colors.white24,
                    size: 36,
                  ),
                ),
              )),
            ),
            const SizedBox(height: 16),
            TextField(
              enabled: !_submitting,
              minLines: 2,
              maxLines: 4,
              onChanged: (val) => _comment = val,
              decoration: InputDecoration(
                hintText: 'Add a comment (optional)',
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.blue[800],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          onPressed: _submitting || _rating == 0 ? null : _submitRating,
          child: _submitting
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Submit'),
        ),
      ],
    );
  }
}
