import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/sick_leave_service.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/services/vip_notification_service.dart';

class StaffAssignmentDialog extends StatefulWidget {
  final Map<String, dynamic> appointment;
  
  const StaffAssignmentDialog({
    Key? key,
    required this.appointment,
  }) : super(key: key);

  @override
  State<StaffAssignmentDialog> createState() => _StaffAssignmentDialogState();
}

class _StaffAssignmentDialogState extends State<StaffAssignmentDialog> {

  String? _selectedConsultant;
  String? _selectedConcierge;
  String? _selectedCleaner;
  
  List<Map<String, dynamic>> _consultants = [];
  List<Map<String, dynamic>> _concierges = [];
  List<Map<String, dynamic>> _cleaners = [];
  
  bool _isLoading = true;
  final VipNotificationService _notificationService = VipNotificationService();
  
  @override
  void initState() {
    super.initState();
    print('[DEBUG] StaffAssignmentDialog opened from notification tap. Appointment id: \'${widget.appointment['id']}\'');
    _loadStaff();
  }
  
  Future<void> _loadStaff() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Load consultants
      final consultantsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'consultant')
          .get();
      
      final List<Map<String, dynamic>> consultantsList = [];
final Timestamp? currentAppointmentTime = widget.appointment['appointmentTime'];
DateTime? currentStartTime = currentAppointmentTime?.toDate();
DateTime? currentEndTime = currentStartTime != null && widget.appointment['duration'] != null
    ? currentStartTime.add(Duration(minutes: int.tryParse(widget.appointment['duration'].toString()) ?? 60))
    : (currentStartTime != null ? currentStartTime.add(Duration(hours: 1)) : null);


final DateTime? apptDay = currentStartTime != null ? DateTime(currentStartTime.year, currentStartTime.month, currentStartTime.day) : null;

final sickLeaveService = SickLeaveService();
final sickConsultantLeaves = apptDay != null
    ? await sickLeaveService.getSickLeavesForRange(apptDay, 'consultant')
    : [];
final sickConciergeLeaves = apptDay != null
    ? await sickLeaveService.getSickLeavesForRange(apptDay, 'concierge')
    : [];
final sickCleanerLeaves = apptDay != null
    ? await sickLeaveService.getSickLeavesForRange(apptDay, 'cleaner')
    : [];
final sickConsultantIds = sickConsultantLeaves.map((s) => s.userId).toSet();
final sickConciergeIds = sickConciergeLeaves.map((s) => s.userId).toSet();
final sickCleanerIds = sickCleanerLeaves.map((s) => s.userId).toSet();

for (var doc in consultantsSnapshot.docs) {
  final data = doc.data();
  final consultantId = doc.id;
  // Exclude if consultant is on sick leave for the day
  if (sickConsultantIds.contains(consultantId)) continue;
  // Query all appointments at this slot (not cancelled) where this consultant is assigned
  final assignedAppointments = await FirebaseFirestore.instance
      .collection('appointments')
      .where('appointmentTime', isEqualTo: currentStartTime != null ? Timestamp.fromDate(currentStartTime) : null)
      .where('status', isNotEqualTo: 'cancelled')
      .get();

  bool isDoubleBooked = false;
  print('[DEBUG] Checking consultant $consultantId for appointmentTime: '
        'currentStartTime=$currentStartTime, as Timestamp=${currentStartTime != null ? Timestamp.fromDate(currentStartTime) : 'null'}');
  for (var appt in assignedAppointments.docs) {
    if (appt.id == widget.appointment['id']) continue; // skip self
    final apptData = appt.data();
    print('[DEBUG] Found appointmentTime in Firestore: '
          '${apptData['appointmentTime']} (as DateTime: '
          '${apptData['appointmentTime'] is Timestamp ? (apptData['appointmentTime'] as Timestamp).toDate() : apptData['appointmentTime']})');
    final apptConsultantId = apptData['consultantId'] ?? apptData['assignedConsultantId'];
    if (apptConsultantId == consultantId) {
      print('[DEBUG] Consultant $consultantId excluded: already assigned at this slot (appointment ${appt.id}).');
      isDoubleBooked = true;
      break;
    }
  }
  if (!isDoubleBooked) {
    consultantsList.add({
      'id': consultantId,
      'name': '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}',
      ...data,
    });
  }
}
      
      // Load concierges
      final conciergesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'concierge')
          .get();
      
      final List<Map<String, dynamic>> conciergesList = [];
      for (var doc in conciergesSnapshot.docs) {
        final data = doc.data();
        final conciergeId = doc.id;
        // Exclude if concierge is on sick leave for the day
        if (sickConciergeIds.contains(conciergeId)) continue;
        conciergesList.add({
          'id': doc.id,
          'name': '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}',
          ...data,
        });
      }
      
      // Load cleaners
      final cleanersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'cleaner')
          .get();
      
      final List<Map<String, dynamic>> cleanersList = [];
      for (var doc in cleanersSnapshot.docs) {
        final data = doc.data();
        final cleanerId = doc.id;
        // Exclude if cleaner is on sick leave for the day
        if (sickCleanerIds.contains(cleanerId)) continue;
        cleanersList.add({
          'id': doc.id,
          'name': '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}',
          ...data,
        });
      }
      
      // Pre-select currently assigned staff if any
      final appointmentData = widget.appointment;
      _selectedConsultant = appointmentData['assignedConsultantId'];
      _selectedConcierge = appointmentData['assignedConciergeId'];
      _selectedCleaner = appointmentData['assignedCleanerId'];
      
      setState(() {
        _consultants = consultantsList;
        _concierges = conciergesList;
        _cleaners = cleanersList;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading staff: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _assignStaff() async {
    // Print the full appointment object for debugging
    print('[DEBUG] widget.appointment: \n${widget.appointment}');
    // Always provide non-null Strings for staff IDs and names, with robust diagnostic output
    String consultantName = '';
    if (_selectedConsultant != null) {
      try {
        print('[DEBUG] _consultants: \n${_consultants.toString()}');
        print('[DEBUG] _selectedConsultant: \n${_selectedConsultant.toString()}');
        final consultant = (_consultants ?? []).firstWhere(
          (staff) => staff['id'] == _selectedConsultant,
          orElse: () => {'name': 'Unknown Consultant', 'id': _selectedConsultant ?? ''},
        );
        consultantName = (consultant['name'] ?? '').toString();
      } catch (e, stack) {
        print('[ERROR] Exception in consultant firstWhere: $e');
        print('[ERROR] Stack trace: $stack');
        consultantName = 'Unknown Consultant';
      }
    }
    String conciergeName = '';
    if (_selectedConcierge != null) {
      try {
        print('[DEBUG] _concierges: \n${_concierges.toString()}');
        print('[DEBUG] _selectedConcierge: \n${_selectedConcierge.toString()}');
        final concierge = (_concierges ?? []).firstWhere(
          (staff) => staff['id'] == _selectedConcierge,
          orElse: () => {'name': 'Unknown Concierge', 'id': _selectedConcierge ?? ''},
        );
        conciergeName = (concierge['name'] ?? '').toString();
      } catch (e, stack) {
        print('[ERROR] Exception in concierge firstWhere: $e');
        print('[ERROR] Stack trace: $stack');
        conciergeName = 'Unknown Concierge';
      }
    }
    String cleanerName = '';
    if (_selectedCleaner != null) {
      try {
        print('[DEBUG] _cleaners: \n${_cleaners.toString()}');
        print('[DEBUG] _selectedCleaner: \n${_selectedCleaner.toString()}');
        final cleaner = (_cleaners ?? []).firstWhere(
          (staff) => staff['id'] == _selectedCleaner,
          orElse: () => {'name': 'Unknown Cleaner', 'id': _selectedCleaner ?? ''},
        );
        cleanerName = (cleaner['name'] ?? '').toString();
      } catch (e, stack) {
        print('[ERROR] Exception in cleaner firstWhere: $e');
        print('[ERROR] Stack trace: $stack');
        cleanerName = 'Unknown Cleaner';
      }
    }
    final updateData = {
      'assignedConsultantId': _selectedConsultant ?? '',
      'assignedConsultantName': consultantName,
      'assignedConciergeId': _selectedConcierge ?? '',
      'assignedConciergeName': conciergeName,
      'assignedCleanerId': _selectedCleaner ?? '',
      'assignedCleanerName': cleanerName,
    };
    print('[DEBUG] FINAL updateData for Firestore:');
    updateData.forEach((k, v) {
      print('  $k = $v (type: \${v.runtimeType})');
    });
    try {
      await FirebaseFirestore.instance.collection('appointments').doc(widget.appointment['id'].toString()).update(updateData);
      // --- Send notifications to assigned staff ---
      if (_selectedConsultant != null && _selectedConsultant!.isNotEmpty) {
        await _notificationService.createNotification(
          title: 'You have been assigned as Consultant',
          body: 'You have been assigned to an appointment.',
          data: widget.appointment,
          role: 'consultant',
          assignedToId: _selectedConsultant!,
          notificationType: 'booking_assigned',
        );
      }
      if (_selectedConcierge != null && _selectedConcierge!.isNotEmpty) {
        await _notificationService.createNotification(
          title: 'You have been assigned as Concierge',
          body: 'You have been assigned to an appointment.',
          data: widget.appointment,
          role: 'concierge',
          assignedToId: _selectedConcierge!,
          notificationType: 'booking_assigned',
        );
      }
      if (_selectedCleaner != null && _selectedCleaner!.isNotEmpty) {
        await _notificationService.createNotification(
          title: 'You have been assigned as Cleaner',
          body: 'You have been assigned to an appointment.',
          data: widget.appointment,
          role: 'cleaner',
          assignedToId: _selectedCleaner!,
          notificationType: 'booking_assigned',
        );
      }
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e, stack) {
      print('Error assigning staff: $e');
      print('Stack trace: $stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error assigning staff: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // Ensure correct appointment time usage
    final Timestamp? appointmentTimestamp = widget.appointment['appointmentTime'];
    final DateTime? appointmentDateTime = appointmentTimestamp?.toDate();
    final String displayTime = appointmentDateTime != null
        ? DateFormat('yyyy-MM-dd HH:mm').format(appointmentDateTime)
        : 'Unknown Time';
    
    final ministerName = ((widget.appointment['ministerFirstName'] ?? '') + ' ' + (widget.appointment['ministerLastName'] ?? '')).trim().isEmpty
      ? 'Unknown Minister'
      : ((widget.appointment['ministerFirstName'] ?? '') + ' ' + (widget.appointment['ministerLastName'] ?? '')).trim();
    final serviceName = widget.appointment['serviceName'] ?? 'Unknown Service';
    
    return Dialog(
      backgroundColor: Colors.grey[900],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.gold, width: 1),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Assign Staff to Appointment',
                      style: TextStyle(
                        color: AppColors.gold,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Appointment details
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[850],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Minister: $ministerName',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Service: $serviceName',
                            style: const TextStyle(color: Colors.white),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Date & Time: $displayTime',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Consultant dropdown
                    Text(
                      'Consultant',
                      style: TextStyle(
                        color: AppColors.gold,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedConsultant,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.grey[800],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                      dropdownColor: Colors.grey[800],
                      style: const TextStyle(color: Colors.white),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('None', style: TextStyle(color: Colors.grey)),
                        ),
                        ..._consultants.map((consultant) {
                          return DropdownMenuItem<String>(
                            value: consultant['id'],
                            child: Text(consultant['name']),
                          );
                        }).toList(),
                      ],
                      onChanged: (value) {
                        print('Floor manager selecting Consultant: $value');
                        setState(() {
                          _selectedConsultant = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Concierge dropdown
                    Text(
                      'Concierge',
                      style: TextStyle(
                        color: AppColors.gold,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedConcierge,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.grey[800],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                      dropdownColor: Colors.grey[800],
                      style: const TextStyle(color: Colors.white),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('None', style: TextStyle(color: Colors.grey)),
                        ),
                        ..._concierges.map((concierge) {
                          return DropdownMenuItem<String>(
                            value: concierge['id'],
                            child: Text(concierge['name']),
                          );
                        }).toList(),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedConcierge = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Cleaner dropdown
                    Text(
                      'Cleaner',
                      style: TextStyle(
                        color: AppColors.gold,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedCleaner,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.grey[800],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                      dropdownColor: Colors.grey[800],
                      style: const TextStyle(color: Colors.white),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('None', style: TextStyle(color: Colors.grey)),
                        ),
                        ..._cleaners.map((cleaner) {
                          return DropdownMenuItem<String>(
                            value: cleaner['id'],
                            child: Text(cleaner['name']),
                          );
                        }).toList(),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedCleaner = value;
                        });
                      },
                    ),
                    const SizedBox(height: 24),
                    
                    // Action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () {
  print('Floor manager tapped Select Consultant button');
  _assignStaff();
},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.gold,
                            foregroundColor: Colors.black,
                          ),
                          child: const Text('Assign Staff'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
