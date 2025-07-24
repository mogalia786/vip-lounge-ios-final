import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/colors.dart';
import 'unified_appointment_card.dart';
import 'Send_My_FCM.dart';
import '../services/vip_notification_service.dart';

class AppointmentSearchWidget extends StatefulWidget {
  final String userRole;
  final String currentUserId;

  const AppointmentSearchWidget({
    Key? key,
    required this.userRole,
    required this.currentUserId,
  }) : super(key: key);

  @override
  _AppointmentSearchWidgetState createState() => _AppointmentSearchWidgetState();
}

class _AppointmentSearchWidgetState extends State<AppointmentSearchWidget> {
  final TextEditingController _searchController = TextEditingController();
  Map<String, dynamic>? _foundAppointment;
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _searchAppointment() async {
    if (_searchController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a reference number';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _foundAppointment = null;
    });

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .where('referenceNumber', isEqualTo: _searchController.text.trim())
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        final appointmentData = doc.data();
        appointmentData['id'] = doc.id;
        appointmentData['docId'] = doc.id;

        // Filter by user role - check multiple possible field names
        bool isAssigned = false;
        
        if (widget.userRole == 'consultant') {
          // Check various possible field names for consultant assignment
          isAssigned = appointmentData['assignedToConsultant'] == widget.currentUserId ||
                      appointmentData['consultantId'] == widget.currentUserId ||
                      appointmentData['assignedConsultant'] == widget.currentUserId;
        } else if (widget.userRole == 'staff') {
          // Check various possible field names for staff assignment
          isAssigned = appointmentData['assignedToStaff'] == widget.currentUserId ||
                      appointmentData['staffId'] == widget.currentUserId ||
                      appointmentData['assignedStaff'] == widget.currentUserId;
        } else {
          // For other roles, show the appointment
          isAssigned = true;
        }
        
        if (isAssigned) {
          setState(() {
            _foundAppointment = appointmentData;
          });
        } else {
          // Debug info for troubleshooting
          print('Assignment check failed:');
          print('User Role: ${widget.userRole}');
          print('User ID: ${widget.currentUserId}');
          print('Appointment data keys: ${appointmentData.keys.toList()}');
          if (widget.userRole == 'consultant') {
            print('assignedToConsultant: ${appointmentData['assignedToConsultant']}');
            print('consultantId: ${appointmentData['consultantId']}');
            print('assignedConsultant: ${appointmentData['assignedConsultant']}');
          } else if (widget.userRole == 'staff') {
            print('assignedToStaff: ${appointmentData['assignedToStaff']}');
            print('staffId: ${appointmentData['staffId']}');
            print('assignedStaff: ${appointmentData['assignedStaff']}');
          }
          
          setState(() {
            _errorMessage = 'Appointment not assigned to you';
          });
        }
      } else {
        setState(() {
          _errorMessage = 'No appointment found with this reference number';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error searching appointment: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _changeAppointmentStatus(String newStatus) async {
    if (_foundAppointment == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(_foundAppointment!['id'])
          .update({
        'status': newStatus,
        'lastModified': FieldValue.serverTimestamp(),
        'modifiedBy': widget.currentUserId,
      });

      // Send notification to minister
      final ministerName = _foundAppointment!['ministerName'] ?? _foundAppointment!['ministerFirstname'] ?? 'Unknown';
      final referenceNumber = _foundAppointment!['referenceNumber'] ?? 'Unknown';
      final ministerId = _foundAppointment!['ministerId'] ?? '';
      
      print('=== NOTIFICATION DEBUG ===');
      print('Minister Name: $ministerName');
      print('Reference Number: $referenceNumber');
      print('Minister ID: $ministerId');
      print('Appointment ID: ${_foundAppointment!['id']}');
      print('All appointment keys: ${_foundAppointment!.keys.toList()}');
      
      if (ministerId.isNotEmpty) {
        final title = 'Appointment Status Updated';
        final body = 'Your appointment (Ref: $referenceNumber) status has been changed to $newStatus by ${widget.userRole}';
        
        print('Sending FCM notification...');
        print('Title: $title');
        print('Body: $body');
        
        // Send FCM notification
        try {
          await SendMyFCM().sendNotification(
            recipientId: ministerId,
            title: title,
            body: body,
            appointmentId: _foundAppointment!['id'],
            role: 'minister',
            notificationType: 'appointment_status_change',
          );
          print('FCM notification sent successfully!');
        } catch (fcmError) {
          print('FCM notification failed: $fcmError');
        }
        
        // Send local notification
        await VipNotificationService().createNotification(
          title: title,
          body: body,
          data: {
            'appointmentId': _foundAppointment!['id'],
            'referenceNumber': referenceNumber,
            'newStatus': newStatus,
            'changedBy': widget.userRole,
          },
          role: 'minister',
          assignedToId: ministerId,
          notificationType: 'appointment_status_change',
        );
      }

      // Update local state
      setState(() {
        _foundAppointment!['status'] = newStatus;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Appointment status updated to $newStatus'),
          backgroundColor: AppColors.gold,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showStatusChangeConfirmation(String newStatus) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.black,
        title: Text(
          'Change Status',
          style: TextStyle(color: AppColors.gold),
        ),
        content: Text(
          'Are you sure you want to change the appointment status to "$newStatus"?\n\nThis will send a notification to the minister.',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _changeAppointmentStatus(newStatus);
            },
            child: Text('Confirm', style: TextStyle(color: AppColors.gold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      width: MediaQuery.of(context).size.width * 0.95,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.black.withOpacity(0.8),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.search, color: AppColors.gold, size: 20),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Search Appointment',
                    style: TextStyle(
                      color: AppColors.gold,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          ),

          // Search Section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Enter appointment reference number',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    filled: true,
                    fillColor: AppColors.black.withOpacity(0.5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppColors.gold.withOpacity(0.3)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppColors.gold.withOpacity(0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppColors.gold),
                    ),
                  ),
                  onSubmitted: (_) => _searchAppointment(),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _searchAppointment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                            ),
                          )
                        : const Text(
                            'Search',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
          ),

          // Error Message
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Found Appointment
          if (_foundAppointment != null)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SingleChildScrollView(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.black.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.gold.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.check_circle, color: AppColors.gold, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Appointment Found',
                              style: TextStyle(
                                color: AppColors.gold,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        UnifiedAppointmentCard(
                          role: widget.userRole,
                          isConsultant: widget.userRole == 'consultant',
                          ministerName: _foundAppointment!['ministerName'] ?? _foundAppointment!['ministerFirstname'] ?? 'Unknown Minister',
                          appointmentId: _foundAppointment!['id'] ?? _foundAppointment!['docId'] ?? '',
                          appointmentInfo: _foundAppointment!,
                          date: _foundAppointment!['appointmentTime'] is Timestamp 
                              ? (_foundAppointment!['appointmentTime'] as Timestamp).toDate()
                              : DateTime.now(),
                          time: _foundAppointment!['appointmentTime'] is Timestamp 
                              ? TimeOfDay.fromDateTime((_foundAppointment!['appointmentTime'] as Timestamp).toDate())
                              : TimeOfDay.fromDateTime(DateTime.now()),
                        ),
                        
                        // Status Change Section
                        if (_foundAppointment!['status'] != 'completed')
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 16),
                              Text(
                                'Change Status:',
                                style: TextStyle(
                                  color: AppColors.gold,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: AppColors.black.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.gold.withOpacity(0.3)),
                                ),
                                child: DropdownButton<String>(
                                  value: null,
                                  hint: Text(
                                    'Select new status',
                                    style: TextStyle(color: Colors.grey[400]),
                                  ),
                                  dropdownColor: AppColors.black,
                                  style: const TextStyle(color: Colors.white),
                                  underline: const SizedBox(),
                                  isExpanded: true,
                                  items: [
                                    'pending',
                                    'confirmed',
                                    'in_progress',
                                    'completed',
                                    'cancelled',
                                  ]
                                      .where((status) => status != _foundAppointment!['status'])
                                      .map((status) => DropdownMenuItem(
                                            value: status,
                                            child: Text(
                                              status.replaceAll('_', ' ').toUpperCase(),
                                              style: const TextStyle(color: Colors.white),
                                            ),
                                          ))
                                      .toList(),
                                  onChanged: (newStatus) {
                                    if (newStatus != null) {
                                      _showStatusChangeConfirmation(newStatus);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
