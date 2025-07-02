import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vip_lounge/core/constants/colors.dart';

class ConsultantAppointmentWidget extends StatefulWidget {
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

  const ConsultantAppointmentWidget({
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
  State<ConsultantAppointmentWidget> createState() => _ConsultantAppointmentWidgetState();
}

class _ConsultantAppointmentWidgetState extends State<ConsultantAppointmentWidget> {
  bool _endSessionButtonDisabled = false;

  @override
  Widget build(BuildContext context) {
    final appointmentTime = widget.appointment['appointmentTime'] is DateTime
        ? widget.appointment['appointmentTime'] as DateTime
        : (widget.appointment['appointmentTime'] is Timestamp)
            ? (widget.appointment['appointmentTime'] as Timestamp).toDate()
            : DateTime.now();
    final formattedDate = DateFormat('EEEE, MMMM d').format(appointmentTime);
    final formattedTime = DateFormat('h:mm a').format(appointmentTime);
    final ministerName = widget.appointment['ministerName'] ?? 'Unknown Minister';
    final serviceName = widget.appointment['serviceName'] ?? 'Unknown Service';
    final venue = widget.appointment['venue'] ?? widget.appointment['venueName'] ?? 'Unknown Venue';
    final ministerPhone = widget.appointment['ministerPhone'] ?? '';
    final ministerEmail = widget.appointment['ministerEmail'] ?? '';
    final notes = widget.appointment['notes'] ?? '';
    final isCompleted = widget.appointment['status'] == 'completed';
    final hasStarted = widget.appointment['status'] == 'in-progress' || widget.appointment['status'] == 'in_progress';

    return Card(
      color: widget.isEvenCard ? Colors.grey[900] : Colors.black,
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
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary),
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
                if (ministerPhone.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.phone, color: AppColors.primary),
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
                    icon: const Icon(Icons.email, color: AppColors.primary),
                    tooltip: 'Email Minister',
                    onPressed: () async {
                      final url = Uri(scheme: 'mailto', path: ministerEmail);
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url);
                      }
                    },
                  ),
                if (widget.onChatWithMinister != null)
                  IconButton(
                    icon: const Icon(Icons.message, color: AppColors.primary),
                    tooltip: 'Chat with Minister',
                    onPressed: widget.onChatWithMinister,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (isCompleted)
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check, color: Colors.white),
                      label: const Text('Completed', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[700],
                        foregroundColor: Colors.white,
                      ),
                      onPressed: null,
                    ),
                  )
                else ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.play_arrow, color: Colors.green),
                      label: const Text('Start Session', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[900],
                        side: const BorderSide(color: Colors.green),
                      ),
                      onPressed: widget.disableStartSession ? null : widget.onStartSession,
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
                      onPressed: _endSessionButtonDisabled ? null : () async {
  setState(() { _endSessionButtonDisabled = true; });
  if (widget.onEndSession != null) widget.onEndSession!();
}
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.note, color: AppColors.primary),
                    label: const Text('Add/View Notes', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      side: const BorderSide(color: AppColors.primary),
                    ),
                    onPressed: widget.onAddNotes,
                  ),
                ),
              ],
            ),
            if (notes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Notes: $notes',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            const SizedBox(height: 8),
            if ((widget.statusOptions?.isNotEmpty ?? false))
              Builder(
                builder: (context) {
                  final optionValues = widget.statusOptions!.map((o) => o['value']).whereType<String>().toList();
                  final safeStatus = (widget.status != null && optionValues.contains(widget.status))
                      ? widget.status
                      : (optionValues.isNotEmpty ? optionValues.first : null);
                  return DropdownButton<String>(
                    value: safeStatus,
                    items: optionValues.map((value) {
                      final label = widget.statusOptions!.firstWhere((o) => o['value'] == value)['label'] ?? value;
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(label),
                      );
                    }).toList(),
                    onChanged: widget.onChangeStatus,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
