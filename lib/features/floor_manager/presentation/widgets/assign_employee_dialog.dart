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
  @override
  void initState() {
    super.initState();
    print('[DEBUG] AssignEmployeeDialog opened.');
  }
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
      final appointmentId = widget.appointmentData['appointmentId'] ?? widget.appointmentData['id'];
      final appointmentTime = widget.appointmentData['appointmentTime'];
      final duration = widget.appointmentData['duration'] is int ? widget.appointmentData['duration'] as int : 60;
      final role = widget.appointmentData['assignRole'] ?? widget.appointmentData['role'] ?? '';
      final sickUserId = widget.appointmentData['sickUserId'];
      final sickRole = widget.appointmentData['sickRole'];
      final Timestamp? startTimestamp = appointmentTime is Timestamp ? appointmentTime : null;
      final DateTime? startDate = startTimestamp?.toDate();
      final DateTime? endDate = startDate != null ? startDate.add(Duration(minutes: duration)) : null;

      // Get all employees for the role
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: role)
          .orderBy('firstName')
          .get();
      List<Map<String, dynamic>> loadedEmployees = querySnapshot.docs
          .map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'firstName': data['firstName'] ?? '',
              'lastName': data['lastName'] ?? '',
              'name': '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim(),
              'role': data['role'] ?? '',
            };
          })
          .toList();

      // Exclude sick user
      if (sickUserId != null && sickRole == role) {
        loadedEmployees = loadedEmployees.where((e) => e['id'] != sickUserId).toList();
      }
      // For consultants, exclude those already assigned to another post at the same slot
      if (role == 'consultant' && startDate != null && endDate != null) {
        List<Map<String, dynamic>> filteredEmployees = [];
        for (final emp in loadedEmployees) {
          final assigned = await FirebaseFirestore.instance
              .collection('appointments')
              .where('consultantId', isEqualTo: emp['id'])
              .get();
          bool hasConflict = false;
          for (final doc in assigned.docs) {
            if (doc.id == appointmentId) continue;
            final data = doc.data();
            final Timestamp? otherTime = data['appointmentTime'] as Timestamp?;
            final int otherDuration = data['duration'] is int ? data['duration'] as int : 60;
            if (otherTime == null) continue;
            final DateTime otherStart = otherTime.toDate();
            final DateTime otherEnd = otherStart.add(Duration(minutes: otherDuration));
            if (startDate.isBefore(otherEnd) && endDate.isAfter(otherStart)) {
              hasConflict = true;
              break;
            }
          }
          if (!hasConflict) filteredEmployees.add(emp);
        }
        loadedEmployees = filteredEmployees;
      }
      setState(() {
        employees = loadedEmployees;
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

    // --- Prevent consultant double-booking for consultants only ---
    final selectedRole = selectedEmployee['role'] ?? '';
    if (selectedRole == 'consultant') {
      final appointmentDoc = await FirebaseFirestore.instance.collection('appointments').doc(appointmentId).get();
      if (!appointmentDoc.exists) {
        throw Exception('Appointment not found');
      }
      final appointmentData = appointmentDoc.data()!;
      final Timestamp? appointmentTime = appointmentData['appointmentTime'] as Timestamp?;
      final int duration = appointmentData['duration'] is int ? appointmentData['duration'] as int : 60;
      if (appointmentTime == null) {
        throw Exception('Appointment time not found');
      }
      final DateTime start = appointmentTime.toDate();
      final DateTime end = start.add(Duration(minutes: duration));

      // Query for overlapping appointments for this consultant (excluding current)
      final overlapping = await FirebaseFirestore.instance
        .collection('appointments')
        .where('consultantId', isEqualTo: selectedUserId)
        .get();
      for (final doc in overlapping.docs) {
        if (doc.id == appointmentId) continue;
        final data = doc.data();
        final Timestamp? otherTime = data['appointmentTime'] as Timestamp?;
        final int otherDuration = data['duration'] is int ? data['duration'] as int : 60;
        if (otherTime == null) continue;
        final DateTime otherStart = otherTime.toDate();
        final DateTime otherEnd = otherStart.add(Duration(minutes: otherDuration));
        // Overlap check
        if (start.isBefore(otherEnd) && end.isAfter(otherStart)) {
          // Conflict!
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('This consultant is already assigned to another appointment at this time.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          setState(() => isLoading = false);
          return;
        }
      }
    }
    // --- End overlap check ---

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

      // Notify minister with new assignment details
      final appointmentDoc = await FirebaseFirestore.instance.collection('appointments').doc(appointmentId).get();
      final appointmentData = appointmentDoc.data() ?? {};
      final consultantName = assignedUsers.firstWhere((u) => u['assignRole'] == 'consultant', orElse: () => null)?['userName'] ?? '';
      final conciergeName = assignedUsers.firstWhere((u) => u['assignRole'] == 'concierge', orElse: () => null)?['userName'] ?? '';
      final ministerNotificationBody = 'A new ${consultantName.isNotEmpty ? 'consultant: $consultantName' : ''}${consultantName.isNotEmpty && conciergeName.isNotEmpty ? ' and ' : ''}${conciergeName.isNotEmpty ? 'concierge: $conciergeName' : ''} has been assigned to your appointment on '
        + (appointmentData['appointmentTime'] is Timestamp ? (appointmentData['appointmentTime'] as Timestamp).toDate().toString() : '')
        + '. Please check your appointment details.';
      if (ministerId != null && ministerId.toString().isNotEmpty) {
        await notificationService.createNotification(
          title: 'Appointment Staff Updated',
          body: ministerNotificationBody,
          data: {
            ...appointmentData,
            'consultantName': consultantName,
            'conciergeName': conciergeName,
          },
          role: 'minister',
          assignedToId: ministerId,
          notificationType: 'staff_assignment',
        );
      }

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
