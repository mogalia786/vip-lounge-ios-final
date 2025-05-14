import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vip_lounge/core/constants/colors.dart';

class ConciergeAppointmentWidget extends StatelessWidget {
  final Map<String, dynamic> appointment;
  final bool isEvenCard;
  final VoidCallback? onStartSession;
  final VoidCallback? onEndSession;
  final VoidCallback? onAddNotes;
  final VoidCallback? onChatWithMinister;
  final List<Map<String, String>>? statusOptions;
  final String? status;
  final void Function(String?)? onChangeStatus;
  final bool disableStartSession;

  const ConciergeAppointmentWidget({
    Key? key,
    required this.appointment,
    required this.isEvenCard,
    this.onStartSession,
    this.onEndSession,
    this.onAddNotes,
    this.onChatWithMinister,
    this.statusOptions,
    this.status,
    this.onChangeStatus,
    this.disableStartSession = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final appointmentTime = appointment['appointmentTime'] is DateTime
        ? appointment['appointmentTime'] as DateTime
        : (appointment['appointmentTime'] is Timestamp)
            ? (appointment['appointmentTime'] as Timestamp).toDate()
            : DateTime.now();
    final formattedDate = DateFormat('EEEE, MMMM d').format(appointmentTime);
    final formattedTime = DateFormat('h:mm a').format(appointmentTime);
    final ministerName = appointment['ministerName'] ?? 'Unknown Minister';
    final serviceName = appointment['serviceName'] ?? 'Unknown Service';
    final venue = appointment['venue'] ?? appointment['venueName'] ?? 'Unknown Venue';
    final ministerPhone = appointment['ministerPhone'] ?? '';
    final ministerEmail = appointment['ministerEmail'] ?? '';
    final isCompleted = appointment['status'] == 'completed';
    final hasStarted = appointment['conciergeSessionStarted'] == true && !isCompleted;

    return Card(
      color: isEvenCard ? Colors.grey[900] : Colors.black,
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  ministerName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.gold),
                ),
                Text(
                  formattedDate,
                  style: const TextStyle(fontSize: 13, color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('$serviceName · $venue', style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 4),
            Text('Time: $formattedTime', style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 8),
            Row(
              children: [
                if (isCompleted)
                  ElevatedButton(
                    onPressed: null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[700],
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Completed'),
                  )
                else ...[
                  if (!hasStarted && onStartSession != null)
                    ElevatedButton(
                      onPressed: disableStartSession ? null : onStartSession,
                      child: const Text('Start Session'),
                    ),
                  if (hasStarted && onEndSession != null)
                    ElevatedButton(
                      onPressed: onEndSession,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('End Session'),
                    ),
                ],
                if (ministerPhone.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.phone, color: AppColors.gold),
                    tooltip: 'Call Minister',
                    onPressed: () async {
                      final url = Uri(scheme: 'tel', path: ministerPhone);
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url);
                      }
                    },
                  ),
                if (ministerEmail.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.email, color: AppColors.gold),
                    tooltip: 'Email Minister',
                    onPressed: () async {
                      final url = Uri(scheme: 'mailto', path: ministerEmail);
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url);
                      }
                    },
                  ),
                if (onChatWithMinister != null)
                  IconButton(
                    icon: const Icon(Icons.message, color: AppColors.gold),
                    tooltip: 'Chat with Minister',
                    onPressed: onChatWithMinister,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.play_arrow, color: Colors.green),
                    label: const Text('Start Session', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[900],
                      side: const BorderSide(color: Colors.green),
                    ),
                    onPressed: disableStartSession ? null : onStartSession,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.stop, color: Colors.red),
                    label: const Text('End Session', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[900],
                      side: const BorderSide(color: Colors.red),
                    ),
                    onPressed: onEndSession,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.note, color: AppColors.gold),
                    label: const Text('Add/View Notes', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      side: const BorderSide(color: AppColors.gold),
                    ),
                    onPressed: onAddNotes,
                  ),
                ),
              ],
            ),
            if ((appointment['conciergeNotes'] ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Notes: ${appointment['conciergeNotes']}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            const SizedBox(height: 8),
            if ((statusOptions?.isNotEmpty ?? false))
              Builder(
                builder: (context) {
                  final optionValues = statusOptions!.map((o) => o['value']).whereType<String>().toList();
                  final safeStatus = (status != null && optionValues.contains(status))
                      ? status
                      : (optionValues.isNotEmpty ? optionValues.first : null);
                  return DropdownButton<String>(
                    value: safeStatus,
                    items: optionValues.map((value) {
                      final label = statusOptions!.firstWhere((o) => o['value'] == value)['label'] ?? value;
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(label),
                      );
                    }).toList(),
                    onChanged: onChangeStatus,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _NotesSection extends StatefulWidget {
  final String appointmentId;
  final String initialNotes;
  final String notesField;

  const _NotesSection({
    Key? key,
    required this.appointmentId,
    required this.initialNotes,
    required this.notesField,
  }) : super(key: key);

  @override
  _NotesSectionState createState() => _NotesSectionState();
}

class _NotesSectionState extends State<_NotesSection> {
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _notesController.text = widget.initialNotes;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _notesController,
          maxLines: 5,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Enter notes',
          ),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: () async {
            await FirebaseFirestore.instance.collection('appointments').doc(widget.appointmentId).update({
              widget.notesField: _notesController.text,
            });
            Navigator.of(context).pop();
          },
          child: const Text('Save Notes'),
        ),
      ],
    );
  }
}
