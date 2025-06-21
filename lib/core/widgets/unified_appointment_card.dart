import 'dart:async';
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
      final conciergeStarted = data['conciergeSessionStarted'] == true;
      final consultantEnded = data['consultantSessionEnded'] == true;
      
      // If session was previously ended, never show the button again
      // This prevents toggling back after ending a session
      if (_hideConciergeSessionButton && conciergeEnded) {
        // Already hidden and ended, don't change state
        print('[BUTTON STATE] Concierge button already hidden and will remain hidden permanently');
        return;
      }
      
      setState(() {
        _hideConciergeSessionButton = conciergeEnded;
        // Debug print for concierge button state
        print('[BUTTON STATE] Concierge role: ${widget.role}, button hidden: $conciergeEnded');
        print('[BUTTON STATE DETAILS] conciergeSessionStarted: $conciergeStarted, conciergeSessionEnded: ${data['conciergeSessionEnded']}, consultantEnded: $consultantEnded');
      });
    }
  }

  // Real-time session state subscription
  StreamSubscription<DocumentSnapshot>? _sessionSubscription;

  @override
  void initState() {
    super.initState();
    _appointmentData = Map<String, dynamic>.from(widget.appointmentInfo);
    
    // Always override appointmentTime with widget.date if provided (from date scroll)
    if (widget.date != null) {
      _appointmentData['appointmentTime'] = widget.date;
    }
    
    // Subscribe to realtime updates (only when session might be active)
    _setupSessionListener();
    
    // Set correct button state for all roles initially
    _updateSessionButtonStateFromData(_appointmentData);
  }
  
  void _setupSessionListener() {
    final appointmentId = widget.appointmentId;
    if (appointmentId.isEmpty) return;
    
    // Only subscribe to appointments that might be in active session state
    // This avoids subscribing to every single appointment card
    final status = _appointmentData['status']?.toString().toLowerCase() ?? '';
    final isRelevantRole = widget.role == 'consultant' || widget.role == 'concierge';
    
    if (isRelevantRole && status != 'cancelled' && status != 'completed') {
      // Listen for real-time updates to this appointment
      try {
        _sessionSubscription = FirebaseFirestore.instance
          .collection('appointments')
          .doc(appointmentId)
          .snapshots()
          .listen((snapshot) {
            if (snapshot.exists && mounted) {
              final data = snapshot.data()!;
              setState(() {
                _appointmentData = data;
                _updateSessionButtonStateFromData(data);
                
                // Debug the session state
                final consultantStarted = data['consultantSessionStarted'] == true;
                final consultantEnded = data['consultantSessionEnded'] == true;
                final conciergeStarted = data['conciergeSessionStarted'] == true;
                final conciergeEnded = data['conciergeSessionEnded'] == true;
                print('[SESSION LISTENER] Role: ${widget.role}, appointment: $appointmentId');
                print('[SESSION LISTENER] conciergeStarted: $conciergeStarted, conciergeEnded: $conciergeEnded');
                print('[SESSION LISTENER] consultantStarted: $consultantStarted, consultantEnded: $consultantEnded'); 
              });
            }
          });
      } catch (e) {
        print('[ERROR] Failed to setup session listener: $e');
      }
    }
  }
  
  @override
  void dispose() {
    _sessionSubscription?.cancel();
    super.dispose();
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
  
  // Format appointment time for notifications
  String _formatAppointmentTime(Map<String, dynamic> appointment) {
    DateTime? appointmentTime;
    
    // Try to get appointment time from different possible fields
    if (appointment['appointmentTimeUTC'] != null) {
      if (appointment['appointmentTimeUTC'] is Timestamp) {
        appointmentTime = (appointment['appointmentTimeUTC'] as Timestamp).toDate();
      } else if (appointment['appointmentTimeUTC'] is DateTime) {
        appointmentTime = appointment['appointmentTimeUTC'] as DateTime;
      }
    } else if (appointment['appointmentTime'] != null) {
      if (appointment['appointmentTime'] is Timestamp) {
        appointmentTime = (appointment['appointmentTime'] as Timestamp).toDate();
      } else if (appointment['appointmentTime'] is DateTime) {
        appointmentTime = appointment['appointmentTime'] as DateTime;
      }
    }
    
    if (appointmentTime != null) {
      // Convert UTC to local if needed
      if (appointmentTime.isUtc) {
        appointmentTime = appointmentTime.toLocal();
      }
      return '${appointmentTime.hour.toString().padLeft(2, '0')}:${appointmentTime.minute.toString().padLeft(2, '0')} on ${appointmentTime.day}/${appointmentTime.month}/${appointmentTime.year}';
    }
    return 'scheduled';
  }
  
  // Get venue details formatted for notifications
  String _getVenueDetails(Map<String, dynamic> appointment) {
    final venue = appointment['venueName'] ?? appointment['venue'];
    final location = appointment['location'] ?? appointment['venueLocation'];
    
    if (venue != null && location != null) {
      return '$venue at $location';
    } else if (venue != null) {
      return venue.toString();
    } else if (location != null) {
      return location.toString();
    }
    return 'the venue';
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
    // Fallback logic: prefer 'appointmentId', then 'id', then 'docId'
    dynamic idRaw = appointment['appointmentId'];
    if (idRaw == null || idRaw.toString().isEmpty) {
      idRaw = appointment['id'];
      if (idRaw != null && idRaw.toString().isNotEmpty) {
        debugPrint('[WARN] appointmentId missing, falling back to id: '+idRaw.toString());
      }
    }
    if (idRaw == null || idRaw.toString().isEmpty) {
      idRaw = appointment['docId'];
      if (idRaw != null && idRaw.toString().isNotEmpty) {
        debugPrint('[WARN] appointmentId/id missing, falling back to docId: '+idRaw.toString());
      }
    }
    if (idRaw == null || idRaw.toString().isEmpty) {
      debugPrint('Error: appointmentId, id, and docId all missing in _showNotesDialog. Appointment: $appointment');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot show notes: Appointment ID missing.')),
      );
      return;
    }
    final String appointmentId = idRaw.toString();
    // Defensive: ensure _appointmentData always has appointmentId
    if (!_appointmentData.containsKey('appointmentId') || (_appointmentData['appointmentId']?.toString().isEmpty ?? true)) {
      debugPrint('[INFO] Setting _appointmentData["appointmentId"] = $appointmentId');
      _appointmentData['appointmentId'] = appointmentId;
    }
    String field = 'notes';
    if (role == 'concierge') field = 'conciergeNotes';
    if (role == 'consultant') field = 'consultantNotes';
    if (role == 'cleaner') field = 'cleanerNotes';
    if (!appointment.containsKey(field)) {
      debugPrint('Warning: Field "$field" not found in appointment. Available keys: ${appointment.keys.toList()}');
    }
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
              // Helper method to format appointment time from Timestamp or DateTime
  String _formatAppointmentTime(dynamic appointmentTime) {
    if (appointmentTime == null) return 'Unknown time';
    DateTime dateTime;
    if (appointmentTime is Timestamp) {
      dateTime = appointmentTime.toDate();
    } else if (appointmentTime is DateTime) {
      dateTime = appointmentTime;
    } else {
      return 'Unknown time format';
    }
    return DateFormat('EEE, MMM d, yyyy - h:mm a').format(dateTime.toLocal());
  }
  
  // Helper method to get venue details as string
  String _getVenueDetails() {
    final venueName = _appointmentData['venueName'] ?? 'Unknown venue';
    final venueAddress = _appointmentData['venueAddress'] ?? '';
    return venueAddress.isNotEmpty ? '$venueName ($venueAddress)' : venueName;
  }
  
  await notificationService.sendFCMToUser(
                userId: _appointmentData['consultantId'],
                title: 'VIP Arrival: ${_appointmentData['ministerName'] ?? 'Client'}',
                body: 'VIP ${_appointmentData['ministerName'] ?? 'Client'} has arrived for ${_appointmentData['serviceName'] ?? 'appointment'} at ${_getVenueDetails()} scheduled for ${_formatAppointmentTime(_appointmentData['appointmentTime'])}.',
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
                title: 'Welcome to Your Appointment',
                body: 'Welcome to your ${_appointmentData['serviceName'] ?? 'appointment'} at ${_getVenueDetails(_appointmentData)}. Your concierge is ${_appointmentData['conciergeName'] ?? 'waiting for you'}.',
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
                body: 'Your session with ${_appointmentData['consultantName'] ?? 'your consultant'} for ${_appointmentData['serviceName'] ?? 'your appointment'} has started at ${_getVenueDetails(_appointmentData)}.',
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
                body: 'Consultant ${_appointmentData['consultantName'] ?? ''} has started the session with VIP ${_appointmentData['ministerName'] ?? 'Client'} for ${_appointmentData['serviceName'] ?? 'the appointment'} at ${_getVenueDetails(_appointmentData)}.',
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
                title: 'VIP Session Ended - Escort Required',
                body: 'Please escort VIP ${appointmentData['ministerName'] ?? 'Client'} out of the lounge. Their ${appointmentData['serviceName'] ?? 'appointment'} at ${_getVenueDetails(appointmentData)} has ended. Appointment status: ${_statusLabel(appointmentData['status'] ?? '')}.',
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
                title: 'VIP Session Ended - Escort Required',
                body: 'Please escort VIP ${appointmentData['ministerName'] ?? 'Client'} out of the lounge. Their ${appointmentData['serviceName'] ?? 'appointment'} at ${_getVenueDetails(appointmentData)} has ended.',
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
                title: 'Thank You for Your Visit',
                body: 'Thank you for attending your ${appointmentData['serviceName'] ?? 'appointment'} with consultant ${appointmentData['consultantName'] ?? ''} at ${_getVenueDetails(appointmentData)} on ${_formatAppointmentTime(appointmentData['appointmentTime'])}. Status: ${_statusLabel(appointmentData['status'] ?? '')}. We hope you enjoyed your experience!',
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

    // Special handling for concierge End Session button after consultant ends
    bool sessionEnded = false;
    
    if (isConsultant) {
      // For consultant: Hide button if consultant session is ended
      sessionEnded = consultantSessionEnded;
    } else if (isConcierge) {
      // For concierge: Only hide if concierge has already ended their session
      sessionEnded = conciergeSessionEnded;
    } else {
      // For other roles, use standard logic
      sessionEnded = (isConsultant && consultantSessionEnded) || (isConcierge && conciergeSessionEnded);
    }
    
    // Debug visibility
    print('[DEBUG SESSION BUTTON] Role: ${widget.role}, sessionEnded: $sessionEnded, _hideConciergeSessionButton: $_hideConciergeSessionButton');

    // Hide buttons completely if this role has ended their session
    // This ensures concierge buttons don't show again after session is ended
    if ((isConcierge && _hideConciergeSessionButton) || (isConsultant && _hideConsultantSessionButton)) {
      print('[DEBUG] Hiding session buttons for ${widget.role} because session was ended');
      sessionEnded = true;
    }

    // --- NEW BUTTONS LOGIC ---
    List<Widget> sessionButtons = [];

    // --- VIEW NOTES BUTTON (ALWAYS SHOW FOR STAFF/CONSULTANT) ---
    String notesField = 'notes';
    if (widget.role == 'consultant' || widget.role == 'staff') notesField = 'consultantNotes';
    if (widget.role == 'concierge') notesField = 'conciergeNotes';
    if (widget.role == 'cleaner') notesField = 'cleanerNotes';
    final String? notesValue = (appointmentData[notesField]?.toString().trim().isNotEmpty ?? false)
        ? appointmentData[notesField]?.toString()
        : null;
    // Always show for consultant/staff, only conditional for others
    if (widget.role == 'consultant' || widget.role == 'staff' || notesValue != null) {
      sessionButtons.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: OutlinedButton.icon(
            icon: const Icon(Icons.sticky_note_2, color: Colors.amber),
            label: Text(
              notesValue == null || notesValue.isEmpty ? 'Add Notes' : 'View Notes',
              style: const TextStyle(color: Colors.amber),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.amber),
              foregroundColor: Colors.amber,
            ),
            onPressed: () {
              // DEBUG PRINT FOR STAFF/CONSULTANT NOTES BUTTON
              print('[DEBUG] UnifiedAppointmentCard Notes button pressed. role: \x1B[32m${widget.role}\x1B[0m, appointmentId: \x1B[33m${appointmentData['id'] ?? appointmentData['docId'] ?? appointmentData['appointmentId']}\x1B[0m');
              _showNotesDialog(context, appointmentData);
            },
          ),
        ),
      );
    }

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
                  // Update local fields AND hide button permanently
                  _updateLocalFields({'conciergeSessionEnded': true});
                  setState(() {
                    _hideConciergeSessionButton = true;
                  });
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
                if (sessionStaffRoles.contains(widget.role) && 
                    ((widget.role == 'concierge' && !_hideConciergeSessionButton) || 
                     (widget.role != 'concierge' && statusValue != 'completed')))
                  ElevatedButton(
                    onPressed: () async {
                    final String role = widget.role;
                    final String startField = '${role}SessionStarted';
                    final String endField = '${role}SessionEnded';
                    final String startTimeField = '${role}StartTime';
                    final String endTimeField = '${role}EndTime';
                    final appointmentId = widget.appointmentId;
                    
                    // Debug visibility for troubleshooting
                    print('[SESSION BUTTON DEBUG] Button pressed for role: $role, startField: $startField, endField: $endField');
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
                        // Rule 1: Consultant must wait for concierge to start
                        if (role == 'consultant' && !(data['conciergeSessionStarted'] == true)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Cannot start session. VIP not arrived. Please wait for the concierge to activate the appointment.')),
                          );
                          return;
                        }

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
                        
                        // Send notifications based on role
                        final notificationService = VipNotificationService();
                        
                        // Concierge Start Session -> Notify Consultant & Minister
                        if (role == 'concierge') {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('VIP Client has arrived. Consultant and Minister notified.')),
                          );
                          
                          // Extract relevant details for personalized messages
                          final vipName = extractMinisterName(_appointmentData);
                          final consultantName = _appointmentData['consultantName'] ?? 'Consultant';
                          final venueName = _appointmentData['venueName'] ?? 'the venue';
                          final appointmentTimeFormatted = _formatAppointmentTime(_appointmentData);
                          
                          // Notify consultant
                          final consultantId = data['consultantId'] ?? _appointmentData['consultantId'];
                          if (consultantId != null && consultantId.toString().isNotEmpty) {
                            await notificationService.sendFCMToUser(
                              userId: consultantId,
                              title: '$vipName Has Arrived',
                              body: '$vipName has arrived for their $appointmentTimeFormatted appointment at $venueName and is being escorted to your location.',
                              data: {
                                'appointmentId': appointmentId,
                                'notificationType': 'client_arrived',
                              },
                              messageType: 'client_arrived',
                            );
                          }
                          
                          // Notify minister (VIP)
                          final ministerId = _appointmentData['ministerId'] ?? _appointmentData['ministerUID'] ?? _appointmentData['ministerUid'];
                          if (ministerId != null && ministerId.toString().isNotEmpty) {
                            // Get concierge name
                            final conciergeName = _appointmentData['conciergeName'] ?? 'Your concierge';
                            final venueDetails = _getVenueDetails(_appointmentData);
                            
                            await notificationService.createNotification(
                              title: 'Welcome to $venueDetails',
                              body: '$conciergeName is escorting you to your appointment. Enjoy your VIP experience!',
                              data: {
                                'appointmentId': appointmentId,
                                'notificationType': 'welcome',
                              },
                              role: 'minister',
                              assignedToId: ministerId,
                              notificationType: 'welcome',
                            );
                          }
                        } 
                        // Consultant Start Session -> Notify Minister & Concierge
                        else if (role == 'consultant') {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Session started.')),
                          );
                          
                          // Notify minister about consultant session starting
                          final ministerId = _appointmentData['ministerId'] ?? _appointmentData['ministerUID'] ?? _appointmentData['ministerUid'];
                          if (ministerId != null && ministerId.toString().isNotEmpty) {
                            // Get personalized details
                            final vipName = extractMinisterName(_appointmentData);
                            final consultantName = _appointmentData['consultantName'] ?? 'Your consultant';
                            final venueDetails = _getVenueDetails(_appointmentData);
                            final appointmentTimeFormatted = _formatAppointmentTime(_appointmentData);
                            
                            await notificationService.createNotification(
                              title: 'Your VIP Session Has Started',
                              body: '$consultantName is now ready to assist you at $venueDetails. Enjoy your premium consultation service.',
                              data: {
                                'appointmentId': appointmentId,
                                'notificationType': 'session_started',
                                'consultantName': consultantName,
                              },
                              role: 'minister',
                              assignedToId: ministerId,
                              notificationType: 'session_started',
                            );
                          }
                          
                          // Notify concierge
                          final conciergeId = data['conciergeId'] ?? _appointmentData['conciergeId'];
                          if (conciergeId != null && conciergeId.toString().isNotEmpty) {
                            await notificationService.sendFCMToUser(
                              userId: conciergeId,
                              title: 'Consultant Session Started',
                              body: 'Consultant has started the session with the VIP client.',
                              data: {
                                'appointmentId': appointmentId,
                                'notificationType': 'consultant_started',
                              },
                              messageType: 'consultant_started',
                            );
                          }
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Session started.')),
                          );
                        }
                      } 
                      // End Session
                      else if (_appointmentData[startField] == true && _appointmentData[endField] != true) {
                        // Rule: Concierge can only end session after consultant has ended
                        if (role == 'concierge') {
                          if (!(data['consultantSessionEnded'] == true)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Consultant must end session before you can end session.')),
                            );
                            return;
                          }
                        }
                        
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
                        
                        final notificationService = VipNotificationService();
                        
                        // Consultant End Session -> Notify Concierge & Floor Manager to escort VIP
                        if (role == 'consultant') {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Session ended. Concierge has been notified to escort the VIP.')),
                          );
                          
                          // Get personalized details for all notifications
                          final vipName = extractMinisterName(_appointmentData);
                          final consultantName = _appointmentData['consultantName'] ?? 'Consultant';
                          final venueDetails = _getVenueDetails(_appointmentData);
                          
                          // Notify concierge
                          final conciergeId = data['conciergeId'] ?? _appointmentData['conciergeId'];
                          if (conciergeId != null && conciergeId.toString().isNotEmpty) {
                            final conciergeName = _appointmentData['conciergeName'] ?? 'Concierge';
                            await notificationService.sendFCMToUser(
                              userId: conciergeId,
                              title: 'Escort $vipName',
                              body: 'VIP session with $consultantName has ended. Please escort $vipName from $venueDetails to their vehicle.',
                              data: {
                                'appointmentId': appointmentId,
                                'notificationType': 'escort_vip',
                                'vipName': vipName,
                              },
                              messageType: 'escort_vip',
                            );
                          }
                          
                          // Notify floor manager
                          final floorManagerId = data['floorManagerId'] ?? _appointmentData['floorManagerId'];
                          if (floorManagerId != null && floorManagerId.toString().isNotEmpty) {
                            await notificationService.sendFCMToUser(
                              userId: floorManagerId,
                              title: 'VIP Escort: $vipName',
                              body: 'Consultant session with $vipName has ended at $venueDetails. Please assist the concierge with VIP escort.',
                              data: {
                                'appointmentId': appointmentId,
                                'notificationType': 'escort_vip',
                                'vipName': vipName,
                                'venueDetails': venueDetails,
                              },
                              messageType: 'escort_vip',
                            );
                          }
                        }
                        // Concierge End Session -> Notify Consultant & Floor Manager that VIP has left
                        else if (role == 'concierge') {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Session ended. VIP has been escorted out.')),
                          );
                          
                          // Get personalized details for all notifications
                          final vipName = extractMinisterName(_appointmentData);
                          final consultantName = _appointmentData['consultantName'] ?? 'Consultant';
                          final conciergeName = _appointmentData['conciergeName'] ?? 'Concierge';
                          final venueDetails = _getVenueDetails(_appointmentData);
                          
                          // Notify consultant
                          final consultantId = data['consultantId'] ?? _appointmentData['consultantId'];
                          if (consultantId != null && consultantId.toString().isNotEmpty) {
                            await notificationService.sendFCMToUser(
                              userId: consultantId,
                              title: '$vipName Has Departed',
                              body: '$conciergeName has escorted $vipName from $venueDetails. Your VIP appointment is now complete.',
                              data: {
                                'appointmentId': appointmentId,
                                'notificationType': 'client_left',
                                'vipName': vipName,
                              },
                              messageType: 'client_left',
                            );
                          }
                          
                          // Notify floor manager
                          final floorManagerId = data['floorManagerId'] ?? _appointmentData['floorManagerId'];
                          if (floorManagerId != null && floorManagerId.toString().isNotEmpty) {
                            await notificationService.sendFCMToUser(
                              userId: floorManagerId,
                              title: '$vipName Has Departed',
                              body: '$vipName has been escorted out of $venueDetails by $conciergeName. VIP appointment is complete.',
                              data: {
                                'appointmentId': appointmentId,
                                'notificationType': 'client_left',
                                'vipName': vipName,
                                'venueDetails': venueDetails,
                              },
                              messageType: 'client_left',
                            );
                          }
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Session ended.')),
                          );
                        }
                        
                        // Send thank you notification with rating prompt to VIP (Minister) for all roles
                        final ministerId = _appointmentData['ministerId'] ?? _appointmentData['ministerUID'] ?? _appointmentData['ministerUid'];
                        if (ministerId != null && ministerId.toString().isNotEmpty) {
                          try {
                            await notificationService.createNotification(
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