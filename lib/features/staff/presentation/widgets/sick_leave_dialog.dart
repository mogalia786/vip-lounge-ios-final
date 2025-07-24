import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:vip_lounge/core/widgets/Send_My_FCM.dart';

class StaffSickLeaveDialog extends StatefulWidget {
  final String userId;
  final String userName;
  final String role;

  const StaffSickLeaveDialog({
    Key? key,
    required this.userId,
    required this.userName,
    required this.role,
  }) : super(key: key);

  @override
  State<StaffSickLeaveDialog> createState() => _StaffSickLeaveDialogState();
}

class _StaffSickLeaveDialogState extends State<StaffSickLeaveDialog> {
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = false;
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

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
    
    setState(() => _isLoading = true);
    
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Create sick leave record
      final sickLeaveRef = await _firestore.collection('sick_leaves').add({
        'userId': widget.userId,
        'userName': widget.userName,
        'role': widget.role,
        'startDate': Timestamp.fromDate(_startDate!),
        'endDate': Timestamp.fromDate(_endDate!),
        'status': 'pending',
        'submittedAt': FieldValue.serverTimestamp(),
        'approvedBy': null,
        'approvedAt': null,
      });

      // Send notification to floor managers using SendMyFCM
      final sendMyFCM = SendMyFCM();
      
      debugPrint('[SickLeave] Sending notification to floor managers...');
      
      try {
        // Get all active floor managers
        final floorManagersQuery = await _firestore
            .collection('users')
            .where('role', isEqualTo: 'floor_manager')
            .where('isActive', isEqualTo: true)
            .get();
            
        debugPrint('[SickLeave] Found ${floorManagersQuery.docs.length} floor managers');
        
        if (floorManagersQuery.docs.isEmpty) {
          debugPrint('[SickLeave] No active floor managers found');
          return;
        }
        
        // Send notification to each floor manager
        for (final managerDoc in floorManagersQuery.docs) {
          final floorManagerId = managerDoc.id;
          debugPrint('[SickLeave] Sending notification to floor manager: $floorManagerId');
          
          try {
            // Create a direct notification for sick leave
            await _firestore.collection('notifications').add({
              'title': 'Sick Leave Request',
              'body': '${widget.userName} (${widget.role}) has requested sick leave from ${DateFormat('MMM d, y').format(_startDate!)} to ${DateFormat('MMM d, y').format(_endDate!)}',
              'isRead': false,
              'createdAt': FieldValue.serverTimestamp(),
              'timestamp': FieldValue.serverTimestamp(),
              'role': 'floorManager',
              'assignedToId': floorManagerId,
              'notificationType': 'sick_leave',
              'data': {
                'sickLeaveId': sickLeaveRef.id,
                'userId': widget.userId,
                'userName': widget.userName,
                'role': widget.role,
                'startDate': _startDate!.toIso8601String(),
                'endDate': _endDate!.toIso8601String(),
                'status': 'pending',
                'type': 'sick_leave_request',
                'timestamp': FieldValue.serverTimestamp(),
              },
            });
            
            // Send FCM using SendMyFCM
            final notificationData = {
              'type': 'sick_leave',
              'sickLeaveId': sickLeaveRef.id,
              'click_action': 'FLUTTER_NOTIFICATION_CLICK',
              'title': 'Sick Leave Request',
              'body': '${widget.userName} (${widget.role}) has requested sick leave from ${DateFormat('MMM d, y').format(_startDate!)} to ${DateFormat('MMM d, y').format(_endDate!)}',
              'userId': widget.userId,
              'userName': widget.userName,
              'role': widget.role,
              'startDate': _startDate!.toIso8601String(),
              'endDate': _endDate!.toIso8601String(),
              'status': 'pending',
              'timestamp': DateTime.now().toIso8601String(),
            };
            
            await SendMyFCM().sendNotification(
              recipientId: floorManagerId,
              title: 'Sick Leave Request',
              body: '${widget.userName} (${widget.role}) has requested sick leave',
              appointmentId: sickLeaveRef.id, // Using sickLeaveId as appointmentId since it's required
              role: 'floor_manager',
              additionalData: notificationData,
              notificationType: 'sick_leave',
              skipAppointmentCheck: true, // Since this isn't tied to an appointment
            );
            debugPrint('[SickLeave] Notification sent successfully to $floorManagerId');
          } catch (e) {
            debugPrint('[SickLeave] Error sending notification to $floorManagerId: $e');
          }
        }
      } catch (e) {
        debugPrint('[SickLeave] Error getting floor managers: $e');
      }

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sick leave request submitted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit sick leave: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Request Sick Leave'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Select the date range for your sick leave:'),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('From: '),
              const SizedBox(width: 8),
              Text(_startDate == null 
                ? 'Select start date' 
                : DateFormat('MMM d, y').format(_startDate!)),
              IconButton(
                icon: const Icon(Icons.calendar_today, size: 20),
                onPressed: _isLoading ? null : () => _pickDate(isStart: true),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('To:     '),
              const SizedBox(width: 8),
              Text(_endDate == null 
                ? 'Select end date' 
                : DateFormat('MMM d, y').format(_endDate!)),
              IconButton(
                icon: const Icon(Icons.calendar_today, size: 20),
                onPressed: _isLoading ? null : () => _pickDate(isStart: false),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: (_isLoading || _startDate == null || _endDate == null) 
              ? null 
              : _submit,
          child: _isLoading 
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Submit'),
        ),
      ],
    );
  }
}
