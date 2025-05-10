import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/constants/colors.dart';

class AssignEmployeeDialog extends StatefulWidget {
  final Map<String, dynamic> appointmentData;

  const AssignEmployeeDialog({
    Key? key,
    required this.appointmentData,
  }) : super(key: key);

  @override
  State<AssignEmployeeDialog> createState() => _AssignEmployeeDialogState();
}

class _AssignEmployeeDialogState extends State<AssignEmployeeDialog> {
  String? selectedUserId;
  bool isLoading = false;
  List<Map<String, dynamic>> employees = [];

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    setState(() => isLoading = true);

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', whereIn: ['employee', 'consultant'])
          .orderBy('firstName')
          .get();

      setState(() {
        employees = querySnapshot.docs
            .map((doc) {
              final data = doc.data();
              return {
                'id': doc.id,
                'firstName': data['firstName'] ?? '',
                'lastName': data['lastName'] ?? '',
                'name': '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim(),
              };
            })
            .toList();
      });
    } catch (e) {
      print('Error loading employees: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading employees: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _assignEmployee() async {
    if (selectedUserId == null) return;

    setState(() => isLoading = true);

    try {
      final selectedEmployee = employees.firstWhere((e) => e['id'] == selectedUserId);
      // Get the appointment ID from the correct field
      final appointmentId = widget.appointmentData['appointmentId'] ?? widget.appointmentData['id'];
      if (appointmentId == null) {
        throw Exception('No appointment ID found in data');
      }
      print('[ASSIGN] Appointment Data: ${widget.appointmentData}');
      print('[ASSIGN] Selected Employee: ${selectedEmployee}');
      print('[ASSIGN] Using appointment ID: ${appointmentId}');

      // Compose the assignment list (for future multi-role support)
      final assignedUsers = [
        {
          'userId': selectedUserId!,
          'userName': selectedEmployee['name'],
          'assignRole': selectedEmployee['role'] ?? 'consultant',
        },
      ];

      // Gather minister and floor manager info for notification
      final ministerId = widget.appointmentData['ministerId'] ?? '';
      final ministerName = (widget.appointmentData['ministerFirstName'] ?? '') + ' ' + (widget.appointmentData['ministerLastName'] ?? '');
      final floorManagerId = widget.appointmentData['floorManagerId'] ?? '';
      final floorManagerName = (widget.appointmentData['floorManagerFirstName'] ?? '') + ' ' + (widget.appointmentData['floorManagerLastName'] ?? '');

      print('[ASSIGN] Will call VipNotificationService.assignBookingToUser with:');
      print('  appointmentId: ${appointmentId}');
      print('  assignedUsers: ${assignedUsers}');
      print('  ministerId: ${ministerId}, ministerName: ${ministerName}');
      print('  floorManagerId: ${floorManagerId}, floorManagerName: ${floorManagerName}');

      final notificationService = VipNotificationService();
      await notificationService.assignBookingToUser(
        appointmentId: appointmentId,
        appointmentData: widget.appointmentData,
        assignedUsers: assignedUsers,
        ministerId: ministerId,
        ministerName: ministerName,
        floorManagerId: floorManagerId,
        floorManagerName: floorManagerName,
      );

      print('[ASSIGN] Assignment and notification complete.');
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      print('Error assigning employee: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error assigning employee: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.grey[900],
      title: const Text(
        'Assign Employee',
        style: TextStyle(color: Colors.white),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: isLoading
            ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.gold),
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select an employee to assign:',
                    style: TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedUserId,
                    dropdownColor: Colors.grey[850],
                    isExpanded: true,  
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: employees.map<DropdownMenuItem<String>>((employee) {
                      return DropdownMenuItem<String>(
                        value: employee['id'] as String,
                        child: Text(
                          employee['name'] as String,
                          style: const TextStyle(color: Colors.white),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => selectedUserId = value);
                    },
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            'Cancel',
            style: TextStyle(color: AppColors.gold),
          ),
        ),
        ElevatedButton(
          onPressed: selectedUserId == null || isLoading ? null : _assignEmployee,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.gold,
            foregroundColor: Colors.black,
          ),
          child: const Text('Assign'),
        ),
      ],
    );
  }
}
