import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/services/vip_notification_service.dart';
import 'rating_utils.dart';

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

  // Local UI state for button hiding/disabling
  bool _hideConsultantSessionButton = false;
  bool _hideConciergeSessionButton = false;

  void _updateSessionButtonStateFromData(Map<String, dynamic> data) {
    if (widget.role == 'consultant') {
      final consultantEnded = data['consultantSessionEnded'] == true;
      setState(() {
        _hideConsultantSessionButton = consultantEnded;
      });
    } else if (widget.role == 'concierge') {
      final conciergeEnded = data['conciergeSessionEnded'] == true;
      setState(() {
        _hideConciergeSessionButton = conciergeEnded;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _appointmentData = Map<String, dynamic>.from(widget.appointmentInfo);
    // Always override appointmentTime with widget.date if provided (from date scroll)
    if (widget.date != null) {
      _appointmentData['appointmentTime'] = widget.date;
    }
    _fetchSessionStateFromFirestore().then((_) {
      setState(() {
        _updateSessionButtonStateFromData(_appointmentData);
      });
    });
    // Set correct button state for all roles (in case fetch is slow, still set initial state)
    _updateSessionButtonStateFromData(_appointmentData);
  }

  Future<void> _fetchSessionStateFromFirestore() async {
    final appointmentId = widget.appointmentId;
    if (appointmentId.isEmpty) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('appointments').doc(appointmentId).get();
      final data = doc.data();
      if (data != null) {
        setState(() {
          _appointmentData.addAll(data);
          _updateSessionButtonStateFromData(_appointmentData);
        });
      }
    } catch (e) {
      // Optionally handle error
    }
  }

  @override
  void didUpdateWidget(covariant UnifiedAppointmentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Always update local state with latest widget.appointmentInfo, including session fields
    final Map<String, dynamic> newInfo = Map<String, dynamic>.from(widget.appointmentInfo);
    for (final entry in newInfo.entries) {
      _appointmentData[entry.key] = entry.value;
    }
    // Always override appointmentTime with widget.date if provided
    if (widget.date != null) {
      _appointmentData['appointmentTime'] = widget.date;
    }
    setState(() {
      _updateSessionButtonStateFromData(_appointmentData);
    });
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
            : 'Unknown VIP';
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

      // Send notification to VIP (Minister) with thank you and rating prompt
      if (_appointmentData['ministerId'] != null && _appointmentData['ministerId'].toString().isNotEmpty) {
        await VipNotificationService().createNotification(
          title: 'Thank you for visiting',
          body: 'Thank you for attending your appointment. Please rate our service.',
          data: {
            'appointmentId': widget.appointmentId,
            'notificationType': 'thank_you',
            'showRating': true,
          },
          role: 'minister',
          assignedToId: _appointmentData['ministerId'],
          notificationType: 'thank_you',
        );
      }
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
        if (data != null && data[startField] != true) {
          // Start session logic
          await FirebaseFirestore.instance.collection('appointments').doc(appointmentId).update({
            startField: true,
            '${role}StartTime': DateTime.now(),
            'status': 'in-progress',
          });
          _updateLocalFields({startField: true, 'status': 'in-progress', '${role}StartTime': DateTime.now()});
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Session started')),
          );
          final notificationService = VipNotificationService();
          // Send notification to all parties with contact info
          if (role == 'concierge') {
            // Notify consultant and minister
            if (_appointmentData['consultantId'] != null && _appointmentData['consultantId'].toString().isNotEmpty) {
              await notificationService.createNotification(
                title: 'VIP Has Arrived',
                body: 'The VIP has arrived for the appointment.',
                data: {
                  'appointmentId': appointmentId,
                  'notificationType': 'minister_arrived',
                  'ministerName': _appointmentData['ministerName'] ?? '',
                  'serviceName': _appointmentData['serviceName'] ?? '',
                  'venueName': _appointmentData['venueName'] ?? '',
                  'appointmentTime': _appointmentData['appointmentTime'],
                  'consultantId': _appointmentData['consultantId'],
                  'consultantName': _appointmentData['consultantName'] ?? '',
                  'consultantPhone': _appointmentData['consultantPhone'] ?? '',
                  'consultantEmail': _appointmentData['consultantEmail'] ?? '',
                  'conciergeName': _appointmentData['conciergeName'] ?? '',
                  'conciergePhone': _appointmentData['conciergePhone'] ?? '',
                  'conciergeEmail': _appointmentData['conciergeEmail'] ?? '',
                },
                role: 'consultant',
                assignedToId: _appointmentData['consultantId'],
                notificationType: 'vip_arrived',
              );
              await notificationService.sendFCMToUser(
                userId: _appointmentData['consultantId'],
                title: 'VIP Has Arrived',
                body: 'The VIP has arrived for the appointment.',
                data: {
                  'appointmentId': appointmentId,
                  'notificationType': 'minister_arrived',
                  'ministerName': _appointmentData['ministerName'] ?? '',
                  'serviceName': _appointmentData['serviceName'] ?? '',
                  'venueName': _appointmentData['venueName'] ?? '',
                  'appointmentTime': _appointmentData['appointmentTime'],
                  'consultantId': _appointmentData['consultantId'],
                  'consultantName': _appointmentData['consultantName'] ?? '',
                  'consultantPhone': _appointmentData['consultantPhone'] ?? '',
                  'consultantEmail': _appointmentData['consultantEmail'] ?? '',
                  'conciergeName': _appointmentData['conciergeName'] ?? '',
                  'conciergePhone': _appointmentData['conciergePhone'] ?? '',
                  'conciergeEmail': _appointmentData['conciergeEmail'] ?? '',
                },
                messageType: 'vip_arrived',
              );
            }
            if (_appointmentData['ministerId'] != null && _appointmentData['ministerId'].toString().isNotEmpty) {
              await notificationService.createNotification(
                title: 'You Have Arrived',
                body: 'Welcome to your appointment. Concierge: ${_appointmentData['conciergeName'] ?? ''}',
                data: {
                  'appointmentId': appointmentId,
                  'notificationType': 'minister_arrived',
                  'conciergeName': _appointmentData['conciergeName'] ?? '',
                  'conciergePhone': _appointmentData['conciergePhone'] ?? '',
                  'conciergeEmail': _appointmentData['conciergeEmail'] ?? '',
                },
                role: 'minister',
                assignedToId: _appointmentData['ministerId'],
                notificationType: 'vip_arrived',
              );
            }
            _updateLocalFields({'conciergeSessionStarted': true});
          }
          if (role == 'consultant') {
            // Notify minister and concierge
            if (_appointmentData['ministerId'] != null && _appointmentData['ministerId'].toString().isNotEmpty) {
              await notificationService.createNotification(
                title: 'Consultant Session Started',
                body: 'Your consultant session has started.',
                data: {
                  'appointmentId': appointmentId,
                  'notificationType': 'consultant_session_started',
                  'consultantName': _appointmentData['consultantName'] ?? '',
                  'consultantPhone': _appointmentData['consultantPhone'] ?? '',
                  'consultantEmail': _appointmentData['consultantEmail'] ?? '',
                },
                role: 'minister',
                assignedToId: _appointmentData['ministerId'],
                notificationType: 'consultant_session_started',
              );
            }
            if (_appointmentData['conciergeId'] != null && _appointmentData['conciergeId'].toString().isNotEmpty) {
              await notificationService.createNotification(
                title: 'Consultant Session Started',
                body: 'Consultant has started the session.',
                data: {
                  'appointmentId': appointmentId,
                  'notificationType': 'consultant_session_started',
                  'consultantName': _appointmentData['consultantName'] ?? '',
                  'consultantPhone': _appointmentData['consultantPhone'] ?? '',
                  'consultantEmail': _appointmentData['consultantEmail'] ?? '',
                },
                role: 'concierge',
                assignedToId: _appointmentData['conciergeId'],
                notificationType: 'consultant_session_started',
              );
            }
            _updateLocalFields({'consultantSessionStarted': true});
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
                title: 'VIP Session Ended',
                body: 'Please escort VIP ${appointmentData['ministerName'] ?? ''} out of the lounge. Status: ${_statusLabel(appointmentData['status'] ?? '')}.',
                data: {
                  'appointmentId': appointmentId,
                  'notificationType': 'escort_minister_out',
                  'ministerName': appointmentData['ministerName'] ?? '',
                  'serviceName': appointmentData['serviceName'] ?? '',
                  'enableConciergeEndSession': true,
                  'status': appointmentData['status'] ?? '',
                  'showRating': true,
                },
                role: 'concierge',
                assignedToId: appointmentData['conciergeId'],
                notificationType: 'escort_vip_out',
              );
              await notificationService.sendFCMToUser(
                userId: appointmentData['conciergeId'],
                title: 'VIP Session Ended',
                body: 'Please escort VIP ${appointmentData['ministerName'] ?? ''} out of the lounge.',
                data: {
                  'appointmentId': appointmentId,
                  'notificationType': 'escort_minister_out',
                  'ministerName': appointmentData['ministerName'] ?? '',
                  'serviceName': appointmentData['serviceName'] ?? '',
                  'enableConciergeEndSession': true,
                },
                messageType: 'escort_vip_out',
              );
              // Concierge: enable End Session after consultant ends
              await FirebaseFirestore.instance.collection('appointments').doc(appointmentId).update({'enableConciergeEndSession': true});
              _updateLocalFields({'enableConciergeEndSession': true});
            }
            // 2. Thank minister for attendance (with full details)
            if (appointmentData['ministerId'] != null && appointmentData['ministerId'].toString().isNotEmpty) {
              await notificationService.createNotification(
                title: 'Thank You for Attending',
                body: 'Thank you for attending your appointment. Status: ${_statusLabel(appointmentData['status'] ?? '')}. You were assigned to consultant: '
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
                  'consultantPhone': appointmentData['consultantPhone'] ?? '',
                  'consultantEmail': appointmentData['consultantEmail'] ?? '',
                  'status': appointmentData['status'] ?? '',
                  'showRating': true,
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
                  'consultantPhone': appointmentData['consultantPhone'] ?? '',
                  'consultantEmail': appointmentData['consultantEmail'] ?? '',
                  'status': appointmentData['status'] ?? '',
                },
                messageType: 'thank_minister',
              );
            }
            // 3. Notify floor manager
            if (appointmentData['floorManagerId'] != null && appointmentData['floorManagerId'].toString().isNotEmpty) {
              await notificationService.createNotification(
                title: 'Minister Session Completed',
                body: 'Minister ${appointmentData['ministerName'] ?? ''}\'s session has been completed. Status: ${_statusLabel(appointmentData['status'] ?? '')}.',
                data: {
                  'appointmentId': appointmentId,
                  'notificationType': 'minister_session_completed',
                  'ministerName': appointmentData['ministerName'] ?? '',
                  'serviceName': appointmentData['serviceName'] ?? '',
                  'status': appointmentData['status'] ?? '',
                  'showRating': true,
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
            // 4. Notify consultant that minister has left (after concierge ends session)
            if (appointmentData['consultantId'] != null && appointmentData['consultantId'].toString().isNotEmpty) {
              await notificationService.createNotification(
                title: 'Minister Has Left',
                body: 'Minister ${appointmentData['ministerName'] ?? ''} has left the lounge. Status: ${_statusLabel(appointmentData['status'] ?? '')}. Thank you for your service.',
                data: {
                  'appointmentId': appointmentId,
                  'notificationType': 'minister_left',
                  'ministerName': appointmentData['ministerName'] ?? '',
                  'serviceName': appointmentData['serviceName'] ?? '',
                  'status': appointmentData['status'] ?? '',
                  'showRating': true,
                },
                role: 'consultant',
                assignedToId: appointmentData['consultantId'],
                notificationType: 'minister_left',
              );
              await notificationService.sendFCMToUser(
                userId: appointmentData['consultantId'],
                title: 'Minister Has Left',
                body: 'Minister ${appointmentData['ministerName'] ?? ''} has left the lounge. Thank you for your service.',
                data: {
                  'appointmentId': appointmentId,
                  'notificationType': 'minister_left',
                  'ministerName': appointmentData['ministerName'] ?? '',
                  'serviceName': appointmentData['serviceName'] ?? '',
                },
                messageType: 'minister_left',
              );
            }
            // 5. Thank minister again for attending and confirm session end
            if (appointmentData['ministerId'] != null && appointmentData['ministerId'].toString().isNotEmpty) {
              await notificationService.createNotification(
                title: 'Thank You for Visiting',
                body: 'Thank you, VIP ${appointmentData['ministerName'] ?? ''}, for visiting the VIP lounge.\nStatus: ${_statusLabel(appointmentData['status'] ?? '')}. We hope you had a pleasant experience.',
                data: {
                  'appointmentId': appointmentId,
                  'notificationType': 'thank_minister_final',
                  'ministerName': appointmentData['ministerName'] ?? '',
                  'serviceName': appointmentData['serviceName'] ?? '',
                  'status': appointmentData['status'] ?? '',
                  'showRating': true,
                },
                role: 'minister',
                assignedToId: appointmentData['ministerId'],
                notificationType: 'thank_minister_final',
              );
              await notificationService.sendFCMToUser(
                userId: appointmentData['ministerId'],
                title: 'Thank You for Visiting',
                body: 'Thank you, Minister ${appointmentData['ministerName'] ?? ''}, for visiting the VIP lounge. We hope you had a pleasant experience.\n\nPlease rate your experience using the link below.',
                data: {
                  'appointmentId': appointmentId,
                  'notificationType': 'thank_minister_final',
                  'ministerName': appointmentData['ministerName'] ?? '',
                  'serviceName': appointmentData['serviceName'] ?? '',
                },
                messageType: 'thank_minister_final',
              );
            }
            // Hide consultant session button after ending
            _updateLocalFields({'consultantSessionEnded': true, 'hideConsultantSessionButton': true});
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
    final isConsultant = widget.role == 'consultant';
    final isConcierge = widget.role == 'concierge';
    final consultantSessionStarted = appointmentData['consultantSessionStarted'] == true;
    final consultantSessionEnded = appointmentData['consultantSessionEnded'] == true;
    final conciergeSessionStarted = appointmentData['conciergeSessionStarted'] == true;
    final conciergeSessionEnded = appointmentData['conciergeSessionEnded'] == true;

    // Debug prints
    print('consultantSessionStarted: $consultantSessionStarted');
    print('consultantSessionEnded: $consultantSessionEnded');
    print('_hideConsultantSessionButton: $_hideConsultantSessionButton');
    print('viewOnly: ${widget.viewOnly}');
    print('statusValue: ${appointmentData['status']}');

    // Hide both buttons if session ended for this role
    final sessionEnded = (isConsultant && consultantSessionEnded) || (isConcierge && conciergeSessionEnded);

    // --- NEW BUTTONS LOGIC ---
    List<Widget> sessionButtons = [];
    if (!sessionEnded && (isConsultant || isConcierge)) {
      sessionButtons.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.check, color: Colors.white),
            label: const Text('Start Session'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              final doc = await FirebaseFirestore.instance.collection('appointments').doc(widget.appointmentId).get();
              final data = doc.data() ?? {};
              if (isConsultant) {
                if (data['consultantSessionStarted'] == true) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Session already started.')),
                  );
                  return;
                }
                await FirebaseFirestore.instance.collection('appointments').doc(widget.appointmentId).update({
                  'consultantSessionStarted': true,
                });
                _updateLocalFields({'consultantSessionStarted': true});
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Session started.')),
                );
              } else if (isConcierge) {
                if (data['conciergeSessionStarted'] == true) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Session is already started.')),
                  );
                } else {
                  await FirebaseFirestore.instance.collection('appointments').doc(widget.appointmentId).update({
                    'conciergeSessionStarted': true,
                  });
                  _updateLocalFields({'conciergeSessionStarted': true});
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Minister has arrived.')),
                  );
                }
              }
            },
          ),
        ),
      );
      sessionButtons.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.close, color: Colors.white),
            label: const Text('End Session'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final doc = await FirebaseFirestore.instance.collection('appointments').doc(widget.appointmentId).get();
              final data = doc.data() ?? {};
              if (isConsultant) {
                if (data['consultantSessionStarted'] == true && data['consultantSessionEnded'] != true) {
                  await FirebaseFirestore.instance.collection('appointments').doc(widget.appointmentId).update({
                    'consultantSessionEnded': true,
                  });
                  _updateLocalFields({'consultantSessionEnded': true});
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Session ended.')),
                  );
                  // Send thank you notification with rating link to VIP
                  if (_appointmentData['ministerId'] != null && _appointmentData['ministerId'].toString().isNotEmpty) {
                    await VipNotificationService().createNotification(
                      title: 'Thank you for visiting',
                      body: 'Thank you for attending your appointment. Please rate our service.',
                      data: {
                        'appointmentId': widget.appointmentId,
                        'notificationType': 'thank_you',
                        'showRating': true,
                      },
                      role: 'minister',
                      assignedToId: _appointmentData['ministerId'],
                      notificationType: 'thank_you',
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('You must start the session first or session already ended.')),
                  );
                }
              } else if (isConcierge) {
                if (data['consultantSessionEnded'] == true && data['conciergeSessionEnded'] != true) {
                  await FirebaseFirestore.instance.collection('appointments').doc(widget.appointmentId).update({
                    'conciergeSessionEnded': true,
                  });
                  _updateLocalFields({'conciergeSessionEnded': true});
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Session ended.')),
                  );
                  // Send thank you notification with rating link to VIP
                  if (_appointmentData['ministerId'] != null && _appointmentData['ministerId'].toString().isNotEmpty) {
                    await VipNotificationService().createNotification(
                      title: 'Thank you for visiting',
                      body: 'Thank you for attending your appointment. Please rate our service.',
                      data: {
                        'appointmentId': widget.appointmentId,
                        'notificationType': 'thank_you',
                        'showRating': true,
                      },
                      role: 'minister',
                      assignedToId: _appointmentData['ministerId'],
                      notificationType: 'thank_you',
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Consultant must end session before you can end session.')),
                  );
                }
              }
            },
          ),
        ),
      );
    }
    // --- END NEW BUTTONS LOGIC ---

    // Use the possibly overridden appointmentTime
    final dynamic rawAppointmentTime = appointmentData['appointmentTime'] ?? widget.date ?? DateTime.now();
    DateTime? appointmentTime;
    if (rawAppointmentTime is Timestamp) {
      appointmentTime = rawAppointmentTime.toDate();
    } else if (rawAppointmentTime is DateTime) {
      appointmentTime = rawAppointmentTime;
    } else if (rawAppointmentTime is String) {
      appointmentTime = DateTime.tryParse(rawAppointmentTime);
    }
    appointmentTime ??= DateTime.now();
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
    // Expanded: Allow session logic for all staff roles except 'minister' and 'vip'
final List<String> sessionStaffRoles = [
  'consultant', 'concierge', 'cleaner', 'marketingAgent', 'marketing_agent', 'staff', 'generalStaff', 'general_staff', 'floorManager', 'floor_manager'
];
final bool showStartSession = sessionStaffRoles.contains(widget.role) && !widget.viewOnly;

    // --- REVIEW LABELS ---
    List<Widget> reviewLabels = [];
    final appointmentId = appointmentData['appointmentId'] ?? safeAppointmentId;
    final queryId = appointmentData['queryId'] ?? '';
    // For appointments: show for each assigned staff (consultant, concierge, cleaner) ONLY IF session ended for that role
    final staffRoles = ['consultant', 'concierge', 'cleaner'];
    final sessionEndedByRole = <String, bool>{
      'consultant': appointmentData['consultantSessionEnded'] == true,
      'concierge': appointmentData['conciergeSessionEnded'] == true,
      'cleaner': appointmentData['cleanerSessionEnded'] == true,
    };
    for (final role in staffRoles) {
      final staffName = appointmentData['${role}Name'] ?? '';
      final staffId = appointmentData['${role}Id'] ?? '';
      if (staffId.toString().isNotEmpty && sessionEndedByRole[role] == true) {
        reviewLabels.add(
          FutureBuilder<double?>(
            future: fetchAverageRatingForStaff(
              appointmentId: appointmentId,
              queryId: queryId,
              staffId: staffName.toString(), // Use staffName as senderId fallback
            ),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data == null) return const SizedBox.shrink();
              final avg = snapshot.data!;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0, bottom: 2),
                child: Chip(
                  backgroundColor: Colors.amber.shade700,
                  label: Text(
                    '$role review: ${avg.toStringAsFixed(1)}',
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              );
            },
          ),
        );
      }
    }
    // For queries: show for staff (senderId in ratings) ONLY IF status is resolved or closed
    if (queryId.isNotEmpty && appointmentData['staffName'] != null && (appointmentData['status'] == 'resolved' || appointmentData['status'] == 'closed')) {
      final staffName = appointmentData['staffName'];
      reviewLabels.add(
        FutureBuilder<double?>(
          future: fetchAverageRatingForStaff(
            appointmentId: '',
            queryId: queryId,
            staffId: staffName.toString(),
          ),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data == null) return const SizedBox.shrink();
            final avg = snapshot.data!;
            return Padding(
              padding: const EdgeInsets.only(right: 8.0, bottom: 2),
              child: Chip(
                backgroundColor: Colors.amber.shade700,
                label: Text(
                  'review: ${avg.toStringAsFixed(1)}',
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            );
          },
        ),
      );
    }
    // --- END REVIEW LABELS ---

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
                if (reviewLabels.isNotEmpty)
                  Wrap(
                    spacing: 4,
                    runSpacing: 2,
                    children: reviewLabels,
                  ),
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
                _infoRow(context, 'ID', safeAppointmentId, accentColor, textColor: Colors.orange, valueFlex: 3),
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
                                  await _fetchSessionStateFromFirestore();
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
                if (!widget.viewOnly) ...[
                  ElevatedButton.icon(
                    icon: Icon(Icons.note_add, color: Colors.amber[600]),
                    label: Text('Notes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber[800],
                      side: BorderSide(color: Colors.amber[600]!),
                    ),
                    onPressed: () {
                      _showNotesDialog(context, _appointmentData);
                    },
                  ),
                ],
                const SizedBox(height: 10),

                // Session button for all staff roles (except minister/vip)
                if (statusValue != 'completed' && sessionStaffRoles.contains(widget.role))
                  ElevatedButton(
                    onPressed: () async {
                    final String role = widget.role;
                    final String startField = '${role}SessionStarted';
                    final String endField = '${role}SessionEnded';
                    final String startTimeField = '${role}StartTime';
                    final String endTimeField = '${role}EndTime';
                    final appointmentId = widget.appointmentId;
                    try {
                      final doc = await FirebaseFirestore.instance.collection('appointments').doc(appointmentId).get();
                      final data = doc.data();
                      if (data == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Appointment not found.')),
                        );
                        return;
                      }
                      // Start Session
                      if (_appointmentData[startField] != true && _appointmentData[endField] != true) {
                        await FirebaseFirestore.instance.collection('appointments').doc(appointmentId).update({
                          startField: true,
                          startTimeField: DateTime.now(),
                          'status': 'in-progress',
                        });
                        setState(() {
                          _appointmentData[startField] = true;
                          _appointmentData['status'] = 'in-progress';
                          _appointmentData[startTimeField] = DateTime.now();
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Session started.')),
                        );
                      } 
                      // End Session
                      else if (_appointmentData[startField] == true && _appointmentData[endField] != true) {
                        await FirebaseFirestore.instance.collection('appointments').doc(appointmentId).update({
                          endField: true,
                          endTimeField: DateTime.now(),
                          'status': 'completed',
                        });
                        setState(() {
                          _appointmentData[endField] = true;
                          _appointmentData['status'] = 'completed';
                          _appointmentData[endTimeField] = DateTime.now();
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Session ended.')),
                        );
                        // Send thank you notification with rating prompt to VIP (Minister)
                        final ministerId = _appointmentData['ministerId'] ?? _appointmentData['ministerUID'] ?? _appointmentData['ministerUid'];
                        if (ministerId != null && ministerId.toString().isNotEmpty) {
                          try {
                            await VipNotificationService().createNotification(
                              title: 'Thank you for visiting',
                              body: 'Thank you for attending your appointment. Please rate our service.',
                              data: {
                                'appointmentId': appointmentId,
                                'notificationType': 'thank_you',
                                'showRating': true,
                                'endedByRole': role,
                              },
                              role: 'minister',
                              assignedToId: ministerId,
                              notificationType: 'thank_you',
                            );
                            // Debug log
                            // ignore: avoid_print
                            print('[DEBUG] Notification sent to minister ($ministerId) for role $role session end.');
                          } catch (e) {
                            // ignore: avoid_print
                            print('[ERROR] Failed to send notification to minister on session end for role $role: $e');
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error sending notification: $e')),
                            );
                          }
                        }
                      }
                    } catch (e) {
                      // ignore: avoid_print
                      print('[ERROR] Session logic error for role $role: $e');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Session error: $e')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: (_appointmentData['${widget.role}SessionStarted'] == true && _appointmentData['${widget.role}SessionEnded'] != true)
                        ? Colors.red[900]
                        : Colors.green[900],
                    side: BorderSide(
                      color: (_appointmentData['${widget.role}SessionStarted'] == true && _appointmentData['${widget.role}SessionEnded'] != true)
                          ? Colors.red
                          : Colors.green,
                    ),
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    (_appointmentData['${widget.role}SessionStarted'] == true && _appointmentData['${widget.role}SessionEnded'] != true)
                        ? 'End Session'
                        : 'Start Session',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ], // End of Column children
            ), // End of Column
          ), // End of Padding
        ), // End of SizedBox
      ), // End of Dialog
    ); // End of Container
  }
}