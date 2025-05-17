import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/sick_leave_service.dart';

class SickLeaveDialog extends StatefulWidget {
  final String userId;
  final String userName;
  final String role;

  const SickLeaveDialog({Key? key, required this.userId, required this.userName, required this.role}) : super(key: key);

  @override
  State<SickLeaveDialog> createState() => _SickLeaveDialogState();
}

class _SickLeaveDialogState extends State<SickLeaveDialog> {
  DateTime? _startDate;
  DateTime? _endDate;
  bool _loading = false;

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate != null && picked.isAfter(_endDate!)) {
            _endDate = picked;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (_startDate == null || _endDate == null) return;
    setState(() => _loading = true);
    try {
      await SickLeaveService().submitSickLeave(
        userId: widget.userId,
        role: widget.role,
        startDate: _startDate!,
        endDate: _endDate!,
        userName: widget.userName,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit sick leave: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Request Sick Leave'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(_startDate == null ? 'Start Date' : DateFormat('yMMMd').format(_startDate!)),
              ),
              IconButton(
                icon: const Icon(Icons.calendar_today),
                onPressed: () => _pickDate(isStart: true),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Text(_endDate == null ? 'End Date' : DateFormat('yMMMd').format(_endDate!)),
              ),
              IconButton(
                icon: const Icon(Icons.calendar_today),
                onPressed: () => _pickDate(isStart: false),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _loading || _startDate == null || _endDate == null ? null : _submit,
          child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Submit'),
        ),
      ],
    );
  }
}
