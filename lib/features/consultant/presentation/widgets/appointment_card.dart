import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/services/vip_notification_service.dart';
import 'appointment_status_chip.dart';

class AppointmentCard extends StatelessWidget {
  final Map<String, dynamic> appointment;
  final VoidCallback onTap;
  final String role;
  final void Function(BuildContext, Map<String, dynamic>)? onChatWithMinister;
  final void Function(BuildContext, Map<String, dynamic>)? onStartSession;
  final void Function(BuildContext, Map<String, dynamic>)? onEndSession;
  final void Function(BuildContext, Map<String, dynamic>, String)? onChangeStatus;
  final List<Map<String, String>>? statusOptions;

  const AppointmentCard({
    Key? key,
    required this.appointment,
    required this.onTap,
    required this.role,
    this.onChatWithMinister,
    this.onStartSession,
    this.onEndSession,
    this.onChangeStatus,
    this.statusOptions,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final appointmentId = appointment['docId'] ?? appointment['id'] ?? appointment['appointmentId'];
    if (appointmentId == null || appointmentId.toString().isEmpty) {
      print('DEBUG: AppointmentCard: appointmentId missing or empty. appointment=' + appointment.toString());
      return const SizedBox();
    }
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('appointments').doc(appointmentId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          print('DEBUG: AppointmentCard: Firestore has no data for $appointmentId');
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!.data() as Map<String, dynamic>?;
        if (data == null) {
          print('DEBUG: AppointmentCard: Firestore document is null for $appointmentId');
          return const SizedBox();
        }
        final appointmentData = {...appointment, ...data};
        print('DEBUG: AppointmentCard: appointmentData merged=' + appointmentData.toString());
        if (role == 'consultant') {
          final minister = appointmentData['minister'] as Map<String, dynamic>?;
          final ministerData = appointmentData['ministerData'] as Map<String, dynamic>?;
          String displayMinisterName = 'Unknown Minister';
          if (minister != null && minister['firstName'] != null) {
            displayMinisterName = '${minister['firstName']} ${minister['lastName'] ?? ''}'.trim();
          } else if (ministerData != null && ministerData['firstName'] != null) {
            displayMinisterName = '${ministerData['firstName']} ${ministerData['lastName'] ?? ''}'.trim();
          } else if (appointmentData['ministerName'] != null) {
            displayMinisterName = appointmentData['ministerName'];
          } else if (appointmentData['ministerFirstName'] != null) {
            displayMinisterName = '${appointmentData['ministerFirstName']} ${appointmentData['ministerLastName'] ?? ''}'.trim();
          }
          final ministerPhone = minister?['phone'] ?? ministerData?['phone'] ?? appointmentData['ministerPhone'] ?? '';
          final ministerEmail = minister?['email'] ?? ministerData?['email'] ?? appointmentData['ministerEmail'] ?? '';
          final status = (appointmentData['status'] ?? 'pending').toString();
          final serviceName = appointmentData['serviceName'] ?? appointmentData['service'] ?? 'VIP Service';
          final venue = appointmentData['venue'] ?? appointmentData['venueName'] ?? 'VIP Lounge';
          final notes = appointmentData['notes'] ?? appointmentData['consultantNotes'] ?? '';
          final safeAppointmentId = appointmentId.toString();
          final appointmentTime = appointmentData['appointmentTime'] is Timestamp
              ? (appointmentData['appointmentTime'] as Timestamp).toDate()
              : appointmentData['appointmentTime'] ?? DateTime.now();
          final formattedDate = DateFormat('EEEE, MMMM d, yyyy').format(appointmentTime);
          final formattedTime = DateFormat('h:mm a').format(appointmentTime);
          Color accentColor = Colors.blue[800]!;
          Color textColor = Colors.white;
          Color secondaryTextColor = Colors.blueGrey[100]!;
          bool sessionStarted = status == 'in_progress';
          return Card(
            elevation: 2.0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: const Color(0xFFFFD700), width: 2.0),
            ),
            child: Container(
              padding: const EdgeInsets.all(16),
              color: Colors.black,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- STATUS CHIP (TOP LEFT ABOVE DATE/TIME) ---
                  Align(
                    alignment: Alignment.topLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _statusColor(status),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        _statusLabel(status),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  // 1. Header: Date and Time
                  Text('$formattedDate · $formattedTime', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurpleAccent, fontSize: 17)),
                  const SizedBox(height: 8),
                  // 2. Minister name + chat icon
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          displayMinisterName,
                          style: TextStyle(fontWeight: FontWeight.bold, color: accentColor, fontSize: 20),
                        ),
                      ),
                      if (onChatWithMinister != null)
                        Stack(
                          alignment: Alignment.topRight,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chat_bubble_outline, color: Colors.amber),
                              onPressed: () {
                                final chatData = {'appointmentId': safeAppointmentId, 'ministerName': displayMinisterName};
                                onChatWithMinister!(context, {...appointmentData, ...chatData});
                              },
                            ),
                            if ((appointmentData['unreadMessageCount'] ?? 0) > 0)
                              Positioned(
                                right: 6,
                                top: 6,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 20,
                                    minHeight: 20,
                                  ),
                                  child: Text(
                                    '${appointmentData['unreadMessageCount']}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      const SizedBox(width: 6),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 3. Info rows
                  _infoRow(context, 'ID', safeAppointmentId, accentColor, textColor: Colors.amber[600]!),
                  _infoRow(context, 'Service', serviceName, accentColor, textColor: textColor),
                  _infoRow(context, 'Venue', venue, accentColor, textColor: textColor),
                  if (ministerPhone != '')
                    _infoRow(context, 'Phone', ministerPhone, accentColor, isLink: true, textColor: textColor),
                  if (ministerEmail != '')
                    _infoRow(context, 'Email', ministerEmail, accentColor, textColor: textColor),
                  const SizedBox(height: 10),
                  // 4. Update Status label + dropdown
                  if (onChangeStatus != null && statusOptions != null)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text('Status:', style: TextStyle(color: accentColor, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Builder(
                            builder: (context) {
                              // Ensure the current status value exists in statusOptions, otherwise fallback to the first option
                              final statusValues = statusOptions!.map((o) => o['value'] ?? '').toSet();
                              final dropdownValue = statusValues.contains(status) ? status : statusOptions!.first['value'];
                              return DropdownButton<String>(
                                value: dropdownValue,
                                isExpanded: true,
                                onChanged: (newStatus) {
                                  if (newStatus != null && onChangeStatus != null) {
                                    onChangeStatus!(context, appointmentData, newStatus);
                                  }
                                },
                                items: statusOptions?.map((option) {
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
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 10),
                  // 5. Notes section
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    icon: Icon(Icons.note_add, color: Colors.amber[600]),
                    label: Text('Consultant Notes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber[800],
                      side: BorderSide(color: Colors.amber[600]!),
                      textStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: Colors.black,
                          title: const Text('Consultant Notes', style: TextStyle(color: Colors.white)),
                          content: _NotesSection(
                            appointmentId: safeAppointmentId,
                            initialNotes: appointmentData['consultantNotes'] ?? '',
                            notesField: 'consultantNotes',
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  // --- SESSION BUTTONS ---
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: Icon(
                            appointmentData['consultantSessionStarted'] == true && appointmentData['consultantSessionEnded'] != true
                                ? Icons.stop
                                : Icons.play_arrow,
                            color: appointmentData['consultantSessionStarted'] == true && appointmentData['consultantSessionEnded'] != true
                                ? Colors.red
                                : (appointmentData['conciergeSessionStarted'] == true ? Colors.green : Colors.grey),
                          ),
                          label: Text(
                            appointmentData['consultantSessionStarted'] == true && appointmentData['consultantSessionEnded'] != true
                                ? 'End Session'
                                : 'Start Session',
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: appointmentData['consultantSessionStarted'] == true && appointmentData['consultantSessionEnded'] != true
                                ? Colors.red[900]
                                : (appointmentData['conciergeSessionStarted'] == true ? Colors.green[900] : Colors.grey[700]),
                            side: BorderSide(
                              color: appointmentData['consultantSessionStarted'] == true && appointmentData['consultantSessionEnded'] != true
                                  ? Colors.red
                                  : (appointmentData['conciergeSessionStarted'] == true ? Colors.green : Colors.grey),
                            ),
                          ),
                          onPressed: _canEnableStartSession(appointmentData)
                              ? () async {
                                  final docId = appointmentId;
                                  if (docId == null || docId.toString().isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Error: Appointment ID missing.')),
                                    );
                                    return;
                                  }
                                  if (appointmentData['consultantSessionStarted'] == true && appointmentData['consultantSessionEnded'] != true) {
                                    // End session: update Firestore with end time
                                    await FirebaseFirestore.instance.collection('appointments').doc(docId).update({
                                      'consultantSessionEnded': true,
                                      'consultantSessionEndTime': FieldValue.serverTimestamp(),
                                      'status': 'completed',
                                    });
                                    if (onEndSession != null) onEndSession!(context, appointmentData);
                                  } else {
                                    // Start session: update Firestore with start time
                                    await FirebaseFirestore.instance.collection('appointments').doc(docId).update({
                                      'consultantSessionStarted': true,
                                      'consultantSessionStartTime': FieldValue.serverTimestamp(),
                                      'status': 'in-progress',
                                    });
                                    if (onStartSession != null) onStartSession!(context, appointmentData);
                                  }
                                }
                              : null,
                        ),
                      ),
                    ],
                  ),
                  // 6. Attendance widget refresh logic (if present)
                  // TODO: Add attendance widget here if needed, ensure UI refreshes after actions
                ],
              ),
            ),
          );
        } else if (role == 'concierge') {
          final minister = appointmentData['minister'] as Map<String, dynamic>?;
          final ministerData = appointmentData['ministerData'] as Map<String, dynamic>?;
          String displayMinisterName = 'Unknown Minister';
          if (minister != null && minister['firstName'] != null) {
            displayMinisterName = '${minister['firstName']} ${minister['lastName'] ?? ''}'.trim();
          } else if (ministerData != null && ministerData['firstName'] != null) {
            displayMinisterName = '${ministerData['firstName']} ${ministerData['lastName'] ?? ''}'.trim();
          } else if (appointmentData['ministerName'] != null) {
            displayMinisterName = appointmentData['ministerName'];
          } else if (appointmentData['ministerFirstName'] != null) {
            displayMinisterName = '${appointmentData['ministerFirstName']} ${appointmentData['ministerLastName'] ?? ''}'.trim();
          }
          final ministerPhone = minister?['phone'] ?? ministerData?['phone'] ?? appointmentData['ministerPhone'] ?? '';
          final ministerEmail = minister?['email'] ?? ministerData?['email'] ?? appointmentData['ministerEmail'] ?? '';
          final status = (appointmentData['status'] ?? 'pending').toString();
          final serviceName = appointmentData['serviceName'] ?? appointmentData['service'] ?? 'VIP Service';
          final venue = appointmentData['venue'] ?? appointmentData['venueName'] ?? 'VIP Lounge';
          final notes = appointmentData['notes'] ?? appointmentData['consultantNotes'] ?? '';
          final safeAppointmentId = appointmentId.toString();
          final appointmentTime = appointmentData['appointmentTime'] is Timestamp
              ? (appointmentData['appointmentTime'] as Timestamp).toDate()
              : appointmentData['appointmentTime'] ?? DateTime.now();
          final formattedDate = DateFormat('EEEE, MMMM d, yyyy').format(appointmentTime);
          final formattedTime = DateFormat('h:mm a').format(appointmentTime);
          Color accentColor = Colors.blue[800]!;
          Color textColor = Colors.white;
          Color secondaryTextColor = Colors.blueGrey[100]!;
          bool sessionStarted = status == 'in_progress';
          return Card(
            elevation: 2.0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: const Color(0xFFFFD700), width: 2.0),
            ),
            child: Container(
              padding: const EdgeInsets.all(16),
              color: Colors.black,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- STATUS CHIP (TOP LEFT ABOVE DATE/TIME) ---
                  Align(
                    alignment: Alignment.topLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      child: AppointmentStatusChip(
                        status: status,
                      ),
                    ),
                  ),
                  // --- DATE/TIME ---
                  Text('$formattedDate · $formattedTime', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurpleAccent, fontSize: 17)),
                  const SizedBox(height: 8),
                  // 2. Minister name + chat icon
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          displayMinisterName,
                          style: TextStyle(fontWeight: FontWeight.bold, color: accentColor, fontSize: 20),
                        ),
                      ),
                      if (onChatWithMinister != null)
                        IconButton(
                          icon: const Icon(Icons.message, color: AppColors.gold),
                          tooltip: 'Chat with Minister',
                          onPressed: () => onChatWithMinister!(context, appointmentData),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 3. Info rows
                  _infoRow(context, 'ID', safeAppointmentId, accentColor, textColor: Colors.amber[600]!),
                  _infoRow(context, 'Service', serviceName, accentColor, textColor: textColor),
                  _infoRow(context, 'Venue', venue, accentColor, textColor: textColor),
                  if (ministerPhone != '')
                    _infoRow(context, 'Phone', ministerPhone, accentColor, isLink: true, textColor: textColor),
                  if (ministerEmail != '')
                    _infoRow(context, 'Email', ministerEmail, accentColor, textColor: textColor),
                  if (notes != '')
                    _infoRow(context, 'Notes', notes, accentColor, textColor: secondaryTextColor),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: Icon(
                        appointmentData['conciergeSessionStarted'] == true ? Icons.stop : Icons.play_arrow,
                        color: appointmentData['conciergeSessionStarted'] == true ? Colors.red : Colors.green,
                      ),
                      label: Text(
                        appointmentData['conciergeSessionStarted'] == true ? 'End Session' : 'Start Session',
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: appointmentData['conciergeSessionStarted'] == true ? Colors.red[900] : Colors.green[900],
                        side: BorderSide(color: appointmentData['conciergeSessionStarted'] == true ? Colors.red : Colors.green),
                      ),
                      onPressed: () {
                        if (appointmentData['conciergeSessionStarted'] == true) {
                          if (onEndSession != null) onEndSession!(context, appointmentData);
                        } else {
                          if (onStartSession != null) onStartSession!(context, appointmentData);
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    icon: Icon(Icons.note_add, color: Colors.amber[600]),
                    label: Text('Concierge Notes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber[800],
                      side: BorderSide(color: Colors.amber[600]!),
                      textStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: Colors.black,
                          title: const Text('Concierge Notes', style: TextStyle(color: Colors.white)),
                          content: _NotesSection(
                            appointmentId: safeAppointmentId,
                            initialNotes: appointmentData['conciergeNotes'] ?? '',
                            notesField: 'conciergeNotes',
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        } else if (role == 'cleaner') {
          final status = (appointmentData['status'] ?? 'pending').toString();
          final serviceName = appointmentData['serviceName'] ?? appointmentData['service'] ?? 'VIP Service';
          final venue = appointmentData['venue'] ?? appointmentData['venueName'] ?? 'VIP Lounge';
          final appointmentTime = appointmentData['appointmentTime'] is Timestamp
              ? (appointmentData['appointmentTime'] as Timestamp).toDate()
              : appointmentData['appointmentTime'] ?? DateTime.now();
          final formattedDate = DateFormat('EEEE, MMMM d, yyyy').format(appointmentTime);
          final formattedTime = DateFormat('h:mm a').format(appointmentTime);
          String displayMinisterName = 'Unknown Minister';
          if (appointmentData['ministerFirstName'] != null) {
            displayMinisterName = '${appointmentData['ministerFirstName']} ${appointmentData['ministerLastName'] ?? ''}'.trim();
          } else if (appointmentData['ministerName'] != null) {
            displayMinisterName = appointmentData['ministerName'];
          }
          Color accentColor = Colors.teal[700]!;
          return Card(
            elevation: 2.0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: const Color(0xFFFFD700), width: 2.0),
            ),
            child: Container(
              padding: const EdgeInsets.all(16),
              color: Colors.black,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status chip
                  Align(
                    alignment: Alignment.topLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _statusColor(status),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        _statusLabel(status),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  // Date and time
                  Text('$formattedDate · $formattedTime', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurpleAccent, fontSize: 17)),
                  const SizedBox(height: 8),
                  // Minister name
                  Text(
                    displayMinisterName,
                    style: TextStyle(fontWeight: FontWeight.bold, color: accentColor, fontSize: 20),
                  ),
                  const SizedBox(height: 8),
                  // Venue
                  Text('Venue: $venue', style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  // Service
                  Text('Service: $serviceName', style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 12),
                  // Start button (enabled), End button (optional), Status dropdown (disabled)
                  Row(
                    children: [
                      if (onStartSession != null)
                        ElevatedButton(
                          onPressed: () => onStartSession!(context, appointmentData),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[700],
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Start'),
                        ),
                      const SizedBox(width: 12),
                      if (onEndSession != null)
                        OutlinedButton(
                          onPressed: () => onEndSession!(context, appointmentData),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red[700],
                          ),
                          child: const Text('End'),
                        ),
                      const SizedBox(width: 12),
                      if (statusOptions != null && onChangeStatus != null)
                        DropdownButton<String>(
                          value: status,
                          items: statusOptions!.map((opt) => DropdownMenuItem<String>(
                            value: opt['value'],
                            child: Text(opt['label'] ?? opt['value']!),
                          )).toList(),
                          onChanged: null, // always disabled for cleaner
                          disabledHint: Text(_statusLabel(status)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }
        return SizedBox.shrink();
      },
    );
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'in_progress':
        return Colors.orangeAccent;
      case 'completed':
        return Colors.green;
      case 'minister_arrived':
        return Colors.blueAccent;
      case 'did_not_attend':
        return Colors.purple;
      case 'scheduled':
        return Colors.deepPurpleAccent;
      case 'cancelled':
        return Colors.red;
      case 'pending':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'in_progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      case 'minister_arrived':
        return 'Arrived';
      case 'did_not_attend':
        return 'Did Not Attend';
      case 'scheduled':
        return 'Scheduled';
      case 'cancelled':
        return 'Cancelled';
      default:
        return (status ?? '').isEmpty ? 'Unknown' : status!;
    }
  }

  Widget _infoRow(BuildContext context, String label, String value, Color accent, {bool isLink = false, Color textColor = Colors.black87}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label:', style: TextStyle(color: accent, fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(
            child: isLink
                ? GestureDetector(
                    onTap: () async {
                      final uri = Uri.parse('tel:$value');
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Could not launch phone dialer')),
                        );
                      }
                    },
                    child: Text(
                      value,
                      style: TextStyle(
                        color: Colors.blue[700],
                        decoration: TextDecoration.underline,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                : Text(
                    value,
                    style: TextStyle(
                      color: textColor,
                      decoration: TextDecoration.none,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
          ),
        ],
      ),
    );
  }

  bool _canEnableStartSession(Map<String, dynamic> appointment) {
    // Fix: Only enable if status is 'in-progress' or 'pending' and conciergeSessionStarted is true
    return (appointment['status'] == 'in_progress' || appointment['status'] == 'pending') && appointment['conciergeSessionStarted'] == true;
  }
}

class _NotesSection extends StatefulWidget {
  final String appointmentId;
  final String initialNotes;
  final String notesField;

  const _NotesSection({Key? key, required this.appointmentId, required this.initialNotes, required this.notesField}) : super(key: key);
  @override
  State<_NotesSection> createState() => _NotesSectionState();
}

class _NotesSectionState extends State<_NotesSection> {
  late TextEditingController _controller;
  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialNotes);
  }
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          maxLines: 3,
          minLines: 3,
          decoration: InputDecoration(
            labelText: 'Notes',
            border: OutlineInputBorder(),
            labelStyle: TextStyle(color: Colors.white70),
            filled: true,
            fillColor: Colors.white10,
          ),
          style: TextStyle(color: Colors.white),
        ),
        SizedBox(height: 6),
        SizedBox(
          height: 56,
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: Icon(Icons.note_add, color: Colors.amber[600]),
            label: Text('Notes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber[800],
              side: BorderSide(color: Colors.amber[600]!),
              textStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            onPressed: () async {
              if (widget.appointmentId.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Error: Appointment ID is missing. Cannot save notes.')),
                );
                return;
              }
              try {
                final doc = await FirebaseFirestore.instance.collection('appointments').doc(widget.appointmentId).get();
                if (!doc.exists) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Error: Appointment document not found.')),
                  );
                  return;
                }
                await doc.reference.update({widget.notesField: _controller.text});
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Notes saved successfully')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to save notes: $e')),
                );
              }
            },
          ),
        ),
      ],
    );
  }
}
