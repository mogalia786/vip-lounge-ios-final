import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/services/vip_notification_service.dart';

class UnifiedAppointmentCard extends StatefulWidget {
  final String role;
  final bool isConsultant;
  final String ministerName;
  final String appointmentId;
  final Map<String, dynamic> appointmentInfo;
  final DateTime? date;
  final TimeOfDay? time;
  final String? ministerId;
  final bool disableStartSession;
  final bool viewOnly;

  const UnifiedAppointmentCard({
    Key? key,
    required this.role,
    required this.isConsultant,
    required this.ministerName,
    required this.appointmentId,
    required this.appointmentInfo,
    this.date,
    this.time,
    this.ministerId,
    this.disableStartSession = false,
    this.viewOnly = false,
  }) : super(key: key);

  @override
  State<UnifiedAppointmentCard> createState() => _UnifiedAppointmentCardState();
}

class _UnifiedAppointmentCardState extends State<UnifiedAppointmentCard> {
  late Map<String, dynamic> _appointmentData;

  @override
  void initState() {
    super.initState();
    _appointmentData = Map<String, dynamic>.from(widget.appointmentInfo);
    // Always override appointmentTime with widget.date if provided (from date scroll)
    if (widget.date != null) {
      _appointmentData['appointmentTime'] = widget.date;
    }
  }

  @override
  void didUpdateWidget(covariant UnifiedAppointmentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only update local state if new appointmentInfo is actually different
    final Map<String, dynamic> newInfo = Map<String, dynamic>.from(widget.appointmentInfo);
    bool hasChanged = false;
    for (final key in newInfo.keys) {
      if (_appointmentData[key] != newInfo[key]) {
        hasChanged = true;
        break;
      }
    }
    if (hasChanged) {
      // --- Only update fields that are NOT session state fields, to preserve local UI state ---
      for (final entry in newInfo.entries) {
        final key = entry.key;
        // Do not overwrite session state fields if already set locally
        if (key.endsWith('SessionStarted') || key.endsWith('SessionEnded') || key.endsWith('StartTime') || key.endsWith('EndTime')) {
          // If the local value is not null/undefined, keep it
          if (_appointmentData[key] != null) continue;
        }
        _appointmentData[key] = entry.value;
      }
      // Always override appointmentTime with widget.date if provided
      if (widget.date != null) {
        _appointmentData['appointmentTime'] = widget.date;
      }
      setState(() {});
    } else if (widget.date != null && widget.date != oldWidget.date) {
      // Only the date changed, update just appointmentTime
      _updateLocalFields({'appointmentTime': widget.date});
    }
    // This logic ensures session state fields are only set by direct user actions, not by upstream prop changes.
  }

  void _updateLocalFields(Map<String, dynamic> fields) {
    setState(() {
      _appointmentData.addAll(fields);
    });
  }

  static String extractMinisterName(Map<String, dynamic> appointment) {
    return appointment['ministerName'] ??
        appointment['minister']?['name'] ??
        ((appointment['ministerFirstName'] ?? '') + ' ' + (appointment['ministerLastName'] ?? '')).trim().isNotEmpty
            ? ((appointment['ministerFirstName'] ?? '') + ' ' + (appointment['ministerLastName'] ?? '')).trim()
            : 'Unknown Minister';
  }

  static const List<Map<String, String>> _consultantStatusOptions = [
    {'value': 'pending', 'label': 'Pending'},
    {'value': 'in-progress', 'label': 'In Progress'},
    {'value': 'awaiting_documents', 'label': 'Awaiting Documents'},
    {'value': 'awaiting_approval', 'label': 'Awaiting Approval'},
    {'value': 'awaiting_verification', 'label': 'Awaiting Verification'},
    {'value': 'completed', 'label': 'Completed'},
    {'value': 'cancelled', 'label': 'Cancelled'},
    {'value': 'did_not_attend', 'label': 'Did Not Attend'},
  ];

  Future<void> _updateStatus(BuildContext context, String? newStatus) async {
    if (newStatus == null || widget.appointmentId.isEmpty) return;
    try {
      await FirebaseFirestore.instance.collection('appointments').doc(widget.appointmentId).update({'status': newStatus});
      _updateLocalFields({'status': newStatus});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status updated to: ${_statusLabel(newStatus)}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating status: $e')),
      );
    }
  }

  Future<void> _showNotesDialog(BuildContext context, Map<String, dynamic> appointment) async {
    final String role = widget.role;
    final String appointmentId = appointment['id'] ?? appointment['docId'] ?? appointment['appointmentId'];
    String field = 'notes';
    if (role == 'concierge') field = 'conciergeNotes';
    if (role == 'consultant') field = 'consultantNotes';
    if (role == 'cleaner') field = 'cleanerNotes';
    final currentNotes = (appointment[field] ?? '').toString();
    final TextEditingController notesController = TextEditingController(text: currentNotes);
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        title: const Text('Session Notes', style: TextStyle(color: Colors.amber)),
        content: TextField(
          controller: notesController,
          decoration: const InputDecoration(hintText: 'Enter session notes'),
          maxLines: 5,
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final notes = notesController.text.trim();
              if (notes.isNotEmpty) {
                try {
                  await FirebaseFirestore.instance.collection('appointments').doc(appointmentId).update({field: notes});
                  _updateLocalFields({field: notes});
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Notes saved successfully')),
                  );
                } catch (e) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error saving notes: $e')),
                  );
                }
              } else {
                Navigator.pop(context);
              }
            },
            child: const Text('Save', style: TextStyle(color: Colors.amber)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleStartSession(BuildContext context, Map<String, dynamic> appointment) async {
    final role = widget.role;
    final appointmentId = appointment['id'] ?? appointment['docId'] ?? appointment['appointmentId'];
    if (appointmentId != null && appointmentId.toString().isNotEmpty) {
      try {
        final doc = await FirebaseFirestore.instance.collection('appointments').doc(appointmentId).get();
        final data = doc.data();
        bool isSessionStarted = false;
        String startField = '';
        String endField = '';
        if (role == 'concierge') {
          startField = 'conciergeSessionStarted';
          endField = 'conciergeSessionEnded';
        } else if (role == 'consultant') {
          startField = 'consultantSessionStarted';
          endField = 'consultantSessionEnded';
        } else if (role == 'cleaner') {
          startField = 'cleanerSessionStarted';
          endField = 'cleanerSessionEnded';
        }
        if (startField.isNotEmpty && data != null) {
          isSessionStarted = data[startField] == true && data[endField] != true;
        }
        if (!isSessionStarted) {
          // Start session logic
          await FirebaseFirestore.instance.collection('appointments').doc(appointmentId).update({
            startField: true,
            '${role}StartTime': DateTime.now(),
            'status': 'in-progress',
          });
          _updateLocalFields({startField: true, 'status': 'in-progress', '${role}StartTime': DateTime.now()});
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Session started')), // TODO: Localize
          );
          // --- SEND NOTIFICATION TO CONSULTANT ON MINISTER ARRIVAL ---
          if (role == 'concierge' && _appointmentData['consultantId'] != null && _appointmentData['consultantId'].toString().isNotEmpty) {
            final notificationService = VipNotificationService();
            await notificationService.createNotification(
              title: 'Minister Arrived',
              body: 'The minister has arrived for the appointment.',
              data: {
                'appointmentId': appointmentId,
                'notificationType': 'minister_arrived',
                'ministerName': _appointmentData['ministerName'] ?? '',
                'serviceName': _appointmentData['serviceName'] ?? '',
                'venueName': _appointmentData['venueName'] ?? '',
                'appointmentTime': _appointmentData['appointmentTime'],
                'consultantId': _appointmentData['consultantId'],
                'consultantName': _appointmentData['consultantName'] ?? '',
              },
              role: 'consultant',
              assignedToId: _appointmentData['consultantId'],
              notificationType: 'minister_arrived',
            );
            await notificationService.sendFCMToUser(
              userId: _appointmentData['consultantId'],
              title: 'Minister Arrived',
              body: 'The minister has arrived for the appointment.',
              data: {
                'appointmentId': appointmentId,
                'notificationType': 'minister_arrived',
                'ministerName': _appointmentData['ministerName'] ?? '',
                'serviceName': _appointmentData['serviceName'] ?? '',
                'venueName': _appointmentData['venueName'] ?? '',
                'appointmentTime': _appointmentData['appointmentTime'],
                'consultantId': _appointmentData['consultantId'],
                'consultantName': _appointmentData['consultantName'] ?? '',
              },
              messageType: 'minister_arrived',
            );
          }
        } else {
          // End session logic
          String? newStatus = _appointmentData['status'];
          if (role == 'concierge') {
            newStatus = 'completed';
          }
          await FirebaseFirestore.instance.collection('appointments').doc(appointmentId).update({
            endField: true,
            '${role}EndTime': DateTime.now(),
            'status': newStatus,
          });
          _updateLocalFields({endField: true, 'status': newStatus, '${role}EndTime': DateTime.now()});
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Session ended')), // TODO: Localize
          );

          // --- SEND NOTIFICATIONS ON CONSULTANT SESSION END ---
          if (role == 'consultant') {
            final notificationService = VipNotificationService();
            final appointmentData = {...data ?? {}, ..._appointmentData};
            // 1. Notify concierge to escort minister out
            if (appointmentData['conciergeId'] != null && appointmentData['conciergeId'].toString().isNotEmpty) {
              await notificationService.createNotification(
                title: 'Minister Session Ended',
                body: 'Please escort Minister ${appointmentData['ministerName'] ?? ''} out of the lounge.',
                data: {
                  'appointmentId': appointmentId,
                  'notificationType': 'escort_minister_out',
                  'ministerName': appointmentData['ministerName'] ?? '',
                  'serviceName': appointmentData['serviceName'] ?? '',
                },
                role: 'concierge',
                assignedToId: appointmentData['conciergeId'],
                notificationType: 'escort_minister_out',
              );
              await notificationService.sendFCMToUser(
                userId: appointmentData['conciergeId'],
                title: 'Minister Session Ended',
                body: 'Please escort Minister ${appointmentData['ministerName'] ?? ''} out of the lounge.',
                data: {
                  'appointmentId': appointmentId,
                  'notificationType': 'escort_minister_out',
                  'ministerName': appointmentData['ministerName'] ?? '',
                  'serviceName': appointmentData['serviceName'] ?? '',
                },
                messageType: 'escort_minister_out',
              );
            }
            // 2. Thank minister for attendance
            if (appointmentData['ministerId'] != null && appointmentData['ministerId'].toString().isNotEmpty) {
              await notificationService.createNotification(
                title: 'Thank You for Attending',
                body: 'Thank you for attending your appointment. You were assigned to consultant: '
                    '${appointmentData['consultantName'] ?? ''} at ${appointmentData['venueName'] ?? ''} on '
                    '${appointmentData['appointmentTime'] != null ? DateFormat('yyyy-MM-dd – kk:mm').format((appointmentData['appointmentTime'] is Timestamp)
                        ? (appointmentData['appointmentTime'] as Timestamp).toDate()
                        : appointmentData['appointmentTime']) : ''}',
                data: {
                  'appointmentId': appointmentId,
                  'notificationType': 'thank_minister',
                  'serviceName': appointmentData['serviceName'] ?? '',
                  'consultantName': appointmentData['consultantName'] ?? '',
                  'venueName': appointmentData['venueName'] ?? '',
                  'appointmentTime': appointmentData['appointmentTime'],
                },
                role: 'minister',
                assignedToId: appointmentData['ministerId'],
                notificationType: 'thank_minister',
              );
              await notificationService.sendFCMToUser(
                userId: appointmentData['ministerId'],
                title: 'Thank You for Attending',
                body: 'Thank you for attending your appointment. You were assigned to consultant: '
                    '${appointmentData['consultantName'] ?? ''} at ${appointmentData['venueName'] ?? ''} on '
                    '${appointmentData['appointmentTime'] != null ? DateFormat('yyyy-MM-dd – kk:mm').format((appointmentData['appointmentTime'] is Timestamp)
                        ? (appointmentData['appointmentTime'] as Timestamp).toDate()
                        : appointmentData['appointmentTime']) : ''}',
                data: {
                  'appointmentId': appointmentId,
                  'notificationType': 'thank_minister',
                  'serviceName': appointmentData['serviceName'] ?? '',
                  'consultantName': appointmentData['consultantName'] ?? '',
                  'venueName': appointmentData['venueName'] ?? '',
                  'appointmentTime': appointmentData['appointmentTime'],
                },
                messageType: 'thank_minister',
              );
            }
            // 3. Optionally notify floor manager (if you want)
            if (appointmentData['floorManagerId'] != null && appointmentData['floorManagerId'].toString().isNotEmpty) {
              await notificationService.createNotification(
                title: 'Minister Session Completed',
                body: 'Minister ${appointmentData['ministerName'] ?? ''}\'s session has been completed.',
                data: {
                  'appointmentId': appointmentId,
                  'notificationType': 'minister_session_completed',
                  'ministerName': appointmentData['ministerName'] ?? '',
                  'serviceName': appointmentData['serviceName'] ?? '',
                },
                role: 'floor_manager',
                assignedToId: appointmentData['floorManagerId'],
                notificationType: 'minister_session_completed',
              );
              await notificationService.sendFCMToUser(
                userId: appointmentData['floorManagerId'],
                title: 'Minister Session Completed',
                body: 'Minister ${appointmentData['ministerName'] ?? ''}\'s session has been completed.',
                data: {
                  'appointmentId': appointmentId,
                  'notificationType': 'minister_session_completed',
                  'ministerName': appointmentData['ministerName'] ?? '',
                  'serviceName': appointmentData['serviceName'] ?? '',
                },
                messageType: 'minister_session_completed',
              );
            }
          }
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating session: $e')),
        );
      }
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'in-progress':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'in-progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      case 'awaiting_documents':
        return 'Awaiting Documents';
      case 'awaiting_approval':
        return 'Awaiting Approval';
      case 'awaiting_verification':
        return 'Awaiting Verification';
      default:
        return status;
    }
  }

  Widget _infoRow(BuildContext context, String label, String value, Color accentColor, {bool isLink = false, required Color textColor, int valueFlex = 1}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Text('$label: ', style: TextStyle(color: accentColor, fontWeight: FontWeight.bold)),
          Expanded(
            flex: valueFlex,
            child: isLink
                ? GestureDetector(
                    onTap: () {
                      // Implement phone/email tap if needed
                    },
                    child: Text(value, style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline)),
                  )
                : Text(value, style: TextStyle(color: textColor)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appointmentData = _appointmentData;
    // Use the possibly overridden appointmentTime
    final dynamic rawAppointmentTime = appointmentData['appointmentTime'] ?? widget.date ?? DateTime.now();
    DateTime appointmentTime;
    if (rawAppointmentTime is Timestamp) {
      appointmentTime = rawAppointmentTime.toDate();
    } else if (rawAppointmentTime is DateTime) {
      appointmentTime = rawAppointmentTime;
    } else if (rawAppointmentTime is String) {
      // Attempt to parse ISO8601 string
      appointmentTime = DateTime.tryParse(rawAppointmentTime) ?? DateTime.now();
    } else {
      appointmentTime = DateTime.now();
    }
    final formattedDate = DateFormat('EEEE, MMMM d, yyyy').format(appointmentTime);
    final formattedTime = DateFormat('h:mm a').format(appointmentTime);
    final safeMinisterName = extractMinisterName(appointmentData);
    final String serviceName = appointmentData['serviceName'] ?? appointmentData['service'] ?? 'VIP Service';
    final String venue = appointmentData['venue'] ?? appointmentData['venueName'] ?? 'VIP Lounge';
    final String notes = (appointmentData['notes'] ?? appointmentData['consultantNotes'] ?? '').toString();
    final String statusValue = appointmentData['status'] ?? 'pending';
    final String safeAppointmentId = widget.appointmentId;
    final ministerPhone = appointmentData['ministerPhone'] ?? '';
    final ministerEmail = appointmentData['ministerEmail'] ?? '';
    final accentColor = Colors.amber[600]!;
    final textColor = Colors.white;

    // Assigned to user full name (consultant, concierge, or cleaner)
    String assignedToName = '';
    if (appointmentData['consultantName'] != null && appointmentData['consultantName'].toString().isNotEmpty) {
      assignedToName = appointmentData['consultantName'];
    } else if (appointmentData['conciergeName'] != null && appointmentData['conciergeName'].toString().isNotEmpty) {
      assignedToName = appointmentData['conciergeName'];
    } else if (appointmentData['cleanerName'] != null && appointmentData['cleanerName'].toString().isNotEmpty) {
      assignedToName = appointmentData['cleanerName'];
    }

    // Logic for role-based controls
    final bool showStartSession = (widget.role == 'concierge' || widget.role == 'cleaner' || widget.role == 'consultant') && !widget.viewOnly;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.amber.shade700,
          width: 3.5,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withOpacity(0.25),
            blurRadius: 14,
            spreadRadius: 2,
            offset: Offset(0, 4),
          ),
        ],
        gradient: LinearGradient(
          colors: [
            Colors.black,
            Colors.amber.shade900.withOpacity(0.12),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      constraints: const BoxConstraints(minWidth: 0, maxWidth: double.infinity),
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 40),
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.all(18.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(Icons.info, color: Colors.lightBlueAccent, size: 22),
                    const SizedBox(width: 7),
                    Text(
                      'Status: ' + (appointmentData['status']?.toString().toUpperCase() ?? 'UNKNOWN'),
                      style: const TextStyle(
                        color: Colors.lightBlueAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text('Appointment Details', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 19)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('$formattedDate · $formattedTime', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurpleAccent, fontSize: 17)),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        safeMinisterName,
                        style: TextStyle(fontWeight: FontWeight.bold, color: accentColor, fontSize: 20),
                      ),
                    ),
                    // Add chat icon for consultant/concierge if ministerId exists
                    if (!widget.viewOnly && (widget.role == 'consultant' || widget.role == 'concierge' || widget.role == 'cleaner') && (widget.ministerId != null && widget.ministerId!.isNotEmpty))
                      IconButton(
                        icon: Icon(Icons.chat_bubble_outline, color: Colors.amber[600], size: 26),
                        tooltip: 'Chat with Minister',
                        onPressed: () {
                          // Navigate to chat screen with minister for all roles
                          String route;
                          Map<String, dynamic> args = {
                            'appointmentId': widget.appointmentId,
                            'ministerId': widget.ministerId,
                            'ministerName': safeMinisterName,
                          };
                          if (widget.role == 'consultant') {
                            route = '/consultant/chat';
                            args.addAll({
                              'consultantId': widget.appointmentInfo['consultantId'] ?? '',
                              'consultantName': widget.appointmentInfo['consultantName'] ?? '',
                              'consultantRole': 'consultant',
                            });
                          } else if (widget.role == 'concierge') {
                            route = '/concierge/chat';
                            args.addAll({
                              'conciergeId': widget.appointmentInfo['conciergeId'] ?? '',
                              'conciergeName': widget.appointmentInfo['conciergeName'] ?? '',
                              'conciergeRole': 'concierge',
                            });
                          } else if (widget.role == 'cleaner') {
                            route = '/cleaner/chat';
                            args.addAll({
                              'cleanerId': widget.appointmentInfo['cleanerId'] ?? '',
                              'cleanerName': widget.appointmentInfo['cleanerName'] ?? '',
                              'cleanerRole': 'cleaner',
                            });
                          } else {
                            route = '/chat';
                          }
                          Navigator.of(context).pushNamed(route, arguments: args);
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                // Info rows: make value take all available space and not wrap unnecessarily
                _infoRow(context, 'ID', safeAppointmentId, accentColor, textColor: Colors.amber[600]!, valueFlex: 3),
                _infoRow(context, 'Service', serviceName, accentColor, textColor: textColor, valueFlex: 3),
                _infoRow(context, 'Venue', venue, accentColor, textColor: textColor, valueFlex: 3),
                if (ministerPhone != '')
                  _infoRow(context, 'Phone', ministerPhone, accentColor, isLink: true, textColor: textColor, valueFlex: 3),
                if (ministerEmail != '')
                  _infoRow(context, 'Email', ministerEmail, accentColor, textColor: textColor, valueFlex: 3),
                if (assignedToName.isNotEmpty)
                  _infoRow(context, 'Assigned To', assignedToName, accentColor, textColor: textColor, valueFlex: 3),
                const SizedBox(height: 10),
                if (!widget.viewOnly && widget.role == 'consultant')
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text('Status:', style: TextStyle(color: accentColor, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButton<String>(
                          value: _consultantStatusOptions.any((option) => option['value'] == statusValue)
                            ? statusValue
                            : _consultantStatusOptions.first['value'],
                          isExpanded: true,
                          onChanged: (appointmentData['consultantSessionEnded'] == true)
                              ? null
                              : (newStatus) async {
                                  await _updateStatus(context, newStatus);
                                },
                          items: _consultantStatusOptions.map((option) {
                            return DropdownMenuItem<String>(
                              value: option['value'],
                              child: Text(
                                option['label'] ?? '',
                                style: TextStyle(
                                  color: Colors.amber[600],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          }).toList(),
                          dropdownColor: Colors.black,
                          iconEnabledColor: Colors.amber[600],
                          underline: Container(height: 1, color: Colors.amber[600]),
                          disabledHint: Text(_statusLabel(statusValue), style: TextStyle(color: Colors.grey)),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 10),
                if (!widget.viewOnly)
                  ElevatedButton.icon(
                    icon: Icon(Icons.note_add, color: Colors.amber[600]),
                    label: Text('Notes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber[800],
                      side: BorderSide(color: Colors.amber[600]!),
                      textStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    onPressed: () => _showNotesDialog(context, appointmentData),
                  ),
                const SizedBox(height: 8),
                if (widget.role == 'consultant' && appointmentData['consultantSessionEnded'] == true && !widget.viewOnly)
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.check_circle, color: Colors.blue),
                          label: const Text('Session Completed', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[900],
                            side: const BorderSide(color: Colors.blue, width: 2),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: null,
                        ),
                      ),
                    ],
                  ),
                if (showStartSession &&
                     !(widget.role == 'consultant' && appointmentData['consultantSessionEnded'] == true) &&
                     !(widget.role == 'concierge' && appointmentData['conciergeSessionEnded'] == true) &&
                     !(widget.role == 'cleaner' && appointmentData['cleanerSessionEnded'] == true) && !widget.viewOnly)
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: Icon(
                            appointmentData['${widget.role}SessionStarted'] == true ? Icons.stop : Icons.play_arrow,
                            color: appointmentData['${widget.role}SessionStarted'] == true ? Colors.red : Colors.green,
                          ),
                          label: Row(
                            children: [
                              Text(
                                appointmentData['${widget.role}SessionStarted'] == true ? 'End Session' : 'Start Session',
                                style: const TextStyle(color: Colors.white),
                              ),
                              if (widget.role == 'concierge' && appointmentData['consultantSessionStarted'] == true && appointmentData['consultantSessionEnded'] != true)
                                Padding(
                                  padding: const EdgeInsets.only(left: 6.0),
                                  child: Tooltip(
                                    message: 'Consultant must end session first',
                                    child: Icon(Icons.info_outline, color: Colors.redAccent, size: 18),
                                  ),
                                ),
                            ],
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.disableStartSession
                              ? Colors.grey[700]
                              : (appointmentData['${widget.role}SessionStarted'] == true ? Colors.red[900] : Colors.green[900]),
                            side: BorderSide(
                              color: widget.disableStartSession
                                ? Colors.grey
                                : (appointmentData['${widget.role}SessionStarted'] == true ? Colors.red : Colors.green),
                            ),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: (widget.disableStartSession || appointmentData['consultantSessionEnded'] == true ||
  (widget.role == 'concierge' && appointmentData['consultantSessionStarted'] == true && appointmentData['consultantSessionEnded'] != true))
  ? null
  : () => _handleStartSession(context, appointmentData),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
