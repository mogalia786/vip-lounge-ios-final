import 'package:flutter/material.dart';

class CleanerChatDialog extends StatelessWidget {
  final String cleanerId;
  final String appointmentId;

  const CleanerChatDialog({
    Key? key,
    required this.cleanerId,
    required this.appointmentId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Cleaner Chat'),
      content: Text('Chat functionality for cleaners will be implemented here.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Close'),
        ),
      ],
    );
  }
}
