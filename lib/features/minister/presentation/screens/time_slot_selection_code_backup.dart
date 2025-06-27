// Saved code for consultant handling and time slot selection

// --- CONSULTANT STATE ---
Map<String, dynamic>? _selectedConsultant;
String? _selectedConsultantId;
String? _selectedConsultantName;
String? _selectedConsultantEmail;
List<Map<String, dynamic>> _consultantsAndStaff = [];
bool _isLoadingConsultants = false;
DateTime? _selectedTimeSlot;

// When a time slot is selected - simply show consultant dropdown, no booking yet
Future<void> _handleTimeSlotSelection(DateTime selectedTime) async {
  // Store the selected time and show loading
  setState(() {
    _selectedTimeSlot = selectedTime;
    _isLoadingConsultants = true;
  });
  
  // Load consultants for dropdown - no navigation or booking happens yet
  await _updateConsultantAvailability(selectedTime);
}

// Fetch consultants and staff, with availability status
Future<void> _fetchConsultantsAndStaff() async {
  setState(() {
    _isLoadingConsultants = true;
  });
  
  try {
    // Query consultants and staff
    final consultantsQuery = await FirebaseFirestore.instance
        .collection('users')
        .where('role', whereIn: ['consultant', 'staff'])
        .get();
        
    // Convert to list of maps with availability information (initially all true)
    List<Map<String, dynamic>> results = [];
    for (var doc in consultantsQuery.docs) {
      final data = doc.data();
      results.add({
        'id': doc.id,
        'name': '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}',
        'role': data['role'] ?? '',
        'isAvailable': true, // Default to available, will check later
        'email': data['email'] ?? '', // Add email
      });
    }
    
    // Sort by name
    results.sort((a, b) => a['name'].compareTo(b['name']));
    
    if (mounted) {
      setState(() {
        _consultantsAndStaff = results;
        _isLoadingConsultants = false;
      });
    }
  } catch (e) {
    print('Error fetching consultants: $e');
    if (mounted) {
      setState(() {
        _consultantsAndStaff = [];
        _isLoadingConsultants = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error loading consultants')),
      );
    }
  }
}

// Update consultant availability based on the selected time
Future<void> _updateConsultantAvailability(DateTime selectedTime) async {
  if (_consultantsAndStaff.isEmpty) {
    await _fetchConsultantsAndStaff();
  }
  
  List<Map<String, dynamic>> updatedList = [];
  
  // Check existing bookings for that time slot
  final bookingsQuery = await FirebaseFirestore.instance
      .collection('appointments')
      .where('appointmentTime', isEqualTo: Timestamp.fromDate(selectedTime))
      .get();
      
  // Build a set of busy consultant IDs
  final Set<String> busyConsultantIds = bookingsQuery.docs
      .map((doc) => doc.data()['consultantId'] as String?)
      .where((id) => id != null)
      .cast<String>()
      .toSet();
      
  print('[DEBUG] Busy consultants: $busyConsultantIds');
  
  // Update availability status
  for (var consultant in _consultantsAndStaff) {
    final String id = consultant['id'];
    final bool isAvailable = !busyConsultantIds.contains(id);
    
    updatedList.add({
      ...consultant,
      'isAvailable': isAvailable,
    });
  }
  
  if (mounted) {
    setState(() {
      _consultantsAndStaff = updatedList;
      _isLoadingConsultants = false;
    });
  }
}

// Handle the booking process
Future<void> _handleBookAppointment() async {
  if (_selectedTimeSlot == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please select a time slot first')),
    );
    return;
  }
  
  setState(() => _isBooking = true);
  
  try {
    final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
    final ministerData = authProvider.ministerData;
    
    if (ministerData == null) {
      throw Exception('Minister data not found');
    }

    print('Booking with minister data: $ministerData'); // Debug print

    // Debug print for UTC compatibility
    print('[DEBUG] _selectedTimeSlot (local): ' + _selectedTimeSlot!.toString());
    print('[DEBUG] _selectedTimeSlot.toUtc(): ' + _selectedTimeSlot!.toUtc().toString());
    print('[DEBUG] _selectedTimeSlot.toIso8601String(): ' + _selectedTimeSlot!.toIso8601String());

    // True UTC instant regardless of device timezone
    final guaranteedUtc = _selectedTimeSlot!.subtract(_selectedTimeSlot!.timeZoneOffset);
    print('[DEBUG] guaranteedUtc: ' + guaranteedUtc.toIso8601String());

    // Create appointment data
    final appointmentData = {
      'ministerId': ministerData['uid'],
      'ministerFirstName': ministerData['firstName'] ?? '',
      'ministerLastName': ministerData['lastName'] ?? '',
      'ministerPhoneNumber': ministerData['phoneNumber'] ?? '',
      'ministerEmail': ministerData['email'] ?? '',
      'venueId': widget.venueId,
      'venueName': widget.venueName,
      'appointmentTime': Timestamp.fromDate(_selectedTimeSlot!),
      'appointmentTimeUTC': Timestamp.fromDate(_selectedTimeSlot!.toUtc()), // Store clean UTC
      'serviceId': widget.selectedService.id,
      'serviceName': widget.selectedService.name,
      'serviceDuration': widget.serviceDuration,
      'serviceCategory': widget.serviceCategory,
      'subServiceName': widget.subServiceName,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'typeOfVip': 'VIP Client', // Add fixed value for type of VIP
      'consultantId': _selectedConsultantId, // May be null for 'no preference'
      'consultantName': _selectedConsultantName, // May be null for 'no preference'
      'consultantEmail': _selectedConsultantEmail // May be null for 'no preference'
    };

    print('Creating appointment with data: $appointmentData');

    // Save to Firestore
    final docRef = await FirebaseFirestore.instance
        .collection('appointments')
        .add(appointmentData);
    
    // Get the app ID for better reference in notifications
    final appointmentId = docRef.id;
    print('[DEBUG] Created appointment with ID: $appointmentId');
    
    // Send FCM to Floor Managers (always)
    final notificationService = NotificationService();
    await notificationService.sendFCMToFloorManager(
      title: 'New Appointment',
      body: 'A new appointment has been booked by ${ministerData['firstName']} ${ministerData['lastName']}',
      data: {
        'type': 'booking',
        'bookingId': appointmentId,
      },
    );
    
    // Only send FCM to consultant if one is selected
    if (_selectedConsultantId != null && _selectedConsultantId!.isNotEmpty) {
      try {
        // Get consultant FCM token
        final consultantDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(_selectedConsultantId)
            .get();
            
        if (consultantDoc.exists && consultantDoc.data() != null) {
          final consultantData = consultantDoc.data()!;
          final fcmToken = consultantData['fcmToken'];
          
          if (fcmToken != null && fcmToken.toString().isNotEmpty) {
            // Send notification to the consultant
            await notificationService.createNotification(
              title: 'New Appointment Assigned',
              body: 'You have been assigned to a new appointment with ${ministerData['firstName']} ${ministerData['lastName']}',
              data: {
                'type': 'booking',
                'bookingId': appointmentId,
              },
              role: 'consultant',
              assignedToId: _selectedConsultantId,
              notificationType: 'booking_assigned',
            );
            print('[DEBUG] Sent FCM to consultant: $_selectedConsultantName');
          }
        }
      } catch (e) {
        print('[ERROR] Failed to send notification to consultant: $e');
        // Continue with flow even if consultant notification fails
      }
    }
    
    // Record workflow event for booking creation
    await _workflowService.recordEvent(
      appointmentId: appointmentId,
      eventType: 'booking_created',
      initiatorId: ministerData['uid'],
      initiatorRole: 'minister',
      initiatorName: '${ministerData['firstName'] ?? ''} ${ministerData['lastName'] ?? ''}',
      notes: 'Booking created by minister',
      eventData: {
        'serviceId': widget.selectedService.id,
        'serviceName': widget.selectedService.name,
        'serviceCategory': widget.serviceCategory,
        'subServiceName': widget.subServiceName,
        'venueId': widget.venueId,
        'venueName': widget.venueName,
      }
    );

    // Successful booking UI flow
    if (mounted) {
      setState(() => _isBooking = false);
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Appointment booked successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Add to calendar option
      _addEventToCalendar();
      
      // Return the selected time to the parent screen
      widget.onTimeSelected(_selectedTimeSlot!);
      
      // Navigate back
      Navigator.of(context).pop();
    }
  } catch (e) {
    print('[ERROR] Booking failed: $e');
    if (mounted) {
      setState(() => _isBooking = false);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Booking failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } finally {
    if (mounted) {
      setState(() => _isBooking = false);
    }
  }
}

// UI ELEMENTS FOR CONSULTANT SELECTION
Widget _buildConsultantDropdown() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 12.0),
        child: Text(
          'Select a consultant (optional)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      if (_isLoadingConsultants)
        const Center(
          child: CircularProgressIndicator(),
        )
      else
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(4),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              hint: const Text('Select a consultant'),
              value: _selectedConsultantId,
              onChanged: (String? newValue) {
                if (newValue == null) {
                  setState(() {
                    _selectedConsultantId = null;
                    _selectedConsultantName = null;
                    _selectedConsultantEmail = null;
                  });
                  return;
                }
                
                // Find the selected consultant
                final consultant = _consultantsAndStaff.firstWhere(
                  (c) => c['id'] == newValue,
                  orElse: () => {'id': '', 'name': '', 'email': ''},
                );
                
                setState(() {
                  _selectedConsultantId = newValue;
                  _selectedConsultantName = consultant['name'];
                  _selectedConsultantEmail = consultant['email'];
                });
              },
              items: [
                const DropdownMenuItem<String>(
                  value: '',
                  child: Text('No preference'),
                ),
                ..._consultantsAndStaff.map<DropdownMenuItem<String>>((consultant) {
                  final isAvailable = consultant['isAvailable'] == true;
                  return DropdownMenuItem<String>(
                    value: consultant['id'],
                    enabled: isAvailable,
                    child: Text(
                      '${consultant['name']} (${consultant['role']})',
                      style: TextStyle(
                        color: isAvailable ? null : Colors.grey,
                        fontStyle: isAvailable ? null : FontStyle.italic,
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ),
      const SizedBox(height: 20),
    ],
  );
}

Widget _buildBookingButton() {
  return SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      onPressed: _isBooking ? null : _handleBookAppointment,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.richGold,
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      child: _isBooking
        ? const CircularProgressIndicator(color: Colors.white)
        : const Text(
            'Confirm Booking',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
    ),
  );
}
