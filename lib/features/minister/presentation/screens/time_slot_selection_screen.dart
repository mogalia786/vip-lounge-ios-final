import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:vip_lounge/core/widgets/Send_My_FCM.dart';
import 'concierge_closed_day_helper.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/workflow_service.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/providers/app_auth_provider.dart';
import '../../../../core/constants/service_options.dart';
import 'package:fluttertoast/fluttertoast.dart';

class TimeSlotSelectionScreen extends StatefulWidget {
  final DateTime selectedDate;
  final String venueId;
  final String venueName;
  final int serviceDuration;
  final Service selectedService;
  final VenueType selectedVenue;
  final String serviceCategory;
  final String? subServiceName;
  final Function(DateTime) onTimeSelected;
  final String ministerFirstName;
  final String ministerLastName;
  final String ministerPhoneNumber;
  final String ministerId;

  const TimeSlotSelectionScreen({
    super.key,
    required this.selectedDate,
    required this.venueId,
    required this.venueName,
    required this.serviceDuration,
    required this.selectedService,
    required this.selectedVenue,
    required this.serviceCategory,
    this.subServiceName,
    required this.onTimeSelected,
    required this.ministerFirstName,
    required this.ministerLastName,
    required this.ministerPhoneNumber,
    required this.ministerId,
  });

  @override
  State<TimeSlotSelectionScreen> createState() => _TimeSlotSelectionScreenState();
}

class _TimeSlotSelectionScreenState extends State<TimeSlotSelectionScreen> {
  // Time slots and booking state
  List<DateTime> _availableTimeSlots = [];
  List<DateTime> _bookedTimeSlots = [];
  DateTime? _selectedTimeSlot;
  bool _isLoadingConsultants = false;
  List<Map<String, dynamic>> _consultantsAndStaff = [];
  Map<String, dynamic>? _selectedConsultant;
  bool _isBooking = false;
  bool _isLoading = true;
  
  // Services
  final NotificationService _notificationService = NotificationService();
  final WorkflowService _workflowService = WorkflowService();
  
  // Pickup location selection
  Map<String, dynamic>? _selectedPickupLocation;
  
  // Consultant selection
  String? _selectedConsultantId;
  String? _selectedConsultantName;
  String? _selectedConsultantEmail;

  // --- CLOSED DAYS & BUSINESS HOURS STATE ---
  DateTime? _openingTime;
  DateTime? _closingTime;
  Map<String, dynamic>? _businessHoursMap;
  Map<String, dynamic>? _defaultBusinessHours;

  // Helper to get abbreviated weekday key (e.g., 'mon', 'tue', ...)
  String _weekdayKey(DateTime date) {
    final key = DateFormat('E').format(date).toLowerCase();
    print('[DEBUG] _weekdayKey for ${date.toIso8601String()} = $key (weekday: ${date.weekday})');
    return key;
  }

  // Use shared ClosedDayHelper for closed day logic
  Future<void> _ensureClosedDayDataLoaded() async {
    await ClosedDayHelper.ensureLoaded();
  }

  bool _isDateClosed(DateTime date) {
    return ClosedDayHelper.isDateClosed(date);
  }

  // Returns the opening/closing TimeOfDay for the selected date, or null if closed
  Map<String, TimeOfDay?> _getBusinessHoursForDate(DateTime date, {bool withBuffer = false}) {
    print('[DEBUG] Retrieving business hours for date: ${date.toString()}');
    
    // Get day key ('mon', 'tue', etc.)
    final String dayKey = _weekdayKey(date);
    print('[DEBUG] Day key for ${date.toString()}: $dayKey');
    
    int openBuffer = withBuffer ? -1 : 0;
    int closeBuffer = withBuffer ? 1 : 0;
    
    // Check if we have hours for this day in the business hours map
    if (_businessHoursMap != null && _businessHoursMap![dayKey] != null) {
      print('[DEBUG] Found business hours entry for $dayKey');
      final dayHours = _businessHoursMap![dayKey];
      print('[DEBUG] Day hours content: $dayHours');
      
      // Check if the day is marked as closed
      if (dayHours['closed'] == true) {
        print('[DEBUG] Day is marked as closed');
        return {'open': null, 'close': null};
      }
      
      // Get open and close times
      if (dayHours['open'] != null && dayHours['close'] != null) {
        final String openStr = dayHours['open'].toString();
        final String closeStr = dayHours['close'].toString();
        print('[DEBUG] Raw times - open: $openStr, close: $closeStr');
        
        // Parse time strings
        final openParts = openStr.split(":");
        final closeParts = closeStr.split(":");
        print('[DEBUG] Parsed parts - open: $openParts, close: $closeParts');
        
        if (openParts.length >= 2 && closeParts.length >= 2) {
          try {
            TimeOfDay open = TimeOfDay(hour: int.parse(openParts[0]), minute: int.parse(openParts[1]));
            TimeOfDay close = TimeOfDay(hour: int.parse(closeParts[0]), minute: int.parse(closeParts[1]));
            
            if (withBuffer) {
              open = TimeOfDay(hour: (open.hour + openBuffer).clamp(0, 23), minute: open.minute);
              close = TimeOfDay(hour: (close.hour + closeBuffer).clamp(0, 23), minute: close.minute);
            }
            
            print('[DEBUG] Returning times - open: ${open.hour}:${open.minute}, close: ${close.hour}:${close.minute}');
            return {'open': open, 'close': close};
          } catch (e) {
            print('[ERROR] Failed to parse time strings: $e');
          }
        } else {
          print('[ERROR] Invalid time format - open: $openStr, close: $closeStr');
        }
      }
    } else {
      print('[DEBUG] No business hours entry found for day: $dayKey');
    }
    
    // No fallback to settings or hardcoded values - only use Firestore data
    // This follows user's GOLDEN RULE: no hardcoded defaults or fallbacks
    print('[WARNING] No business hours found for this day: $dayKey');
    // Return null values to indicate no business hours available
    return {'open': null, 'close': null};
  }

  // Generates time slots for the selected date, using business hours and correct interval
  List<DateTime> _generateTimeSlots() {
    final slots = <DateTime>[];
    final date = widget.selectedDate;
    
    print('[DEBUG] Generating time slots for date: ${date.toString()}, day key: ${_weekdayKey(date)}');
    print('[DEBUG] Business hours map contains keys: ${_businessHoursMap?.keys.toList() ?? 'null'}');
    
    if (_businessHoursMap != null) {
      // Emergency: debug dump all business hours data to see what we're working with
      print('[DEBUG] Full business hours map:');
      _businessHoursMap!.forEach((key, value) {
        print('[DEBUG]   $key: $value');
      });
      
      // Let's check for day keys different from what we expect
      // Try matching with different formats
      final dayFormats = [
        _weekdayKey(date),                 // Standard format (mon, tue, etc)
        DateFormat('EEE').format(date).toLowerCase(), // 3-letter abbr
        date.weekday.toString(),          // Numeric day of week
        'day${date.weekday}',             // day1, day2, etc.
        DateFormat('EEEE').format(date).toLowerCase() // Full day name
      ];
      
      print('[DEBUG] Trying possible day formats: $dayFormats');
      
      // Check if any of these formats exist in the business hours
      for (final format in dayFormats) {
        if (_businessHoursMap!.containsKey(format)) {
          print('[DEBUG] FOUND MATCH! Day format "$format" exists in business hours');
          
          // Print the full day data
          print('[DEBUG] Day data for $format: ${_businessHoursMap![format]}');
        }
      }
    } else {
      print('[ERROR] No business hours data loaded from Firestore');
    }
    
    // Existing logic
    final hours = _getBusinessHoursForDate(date);
    final open = hours['open'];
    final close = hours['close'];
    print('[DEBUG] Hours for date: open=$open, close=$close');
    
    if (open == null || close == null) {
      print('[DEBUG] No business hours found for this date, returning empty slots');
      return slots; // Closed
    }
    
    DateTime current = DateTime(date.year, date.month, date.day, open.hour, open.minute);
    final end = DateTime(date.year, date.month, date.day, close.hour, close.minute);
    
    print('[DEBUG] Start time: $current, End time: $end');
    
    while (current.isBefore(end)) {
      slots.add(current);
      current = current.add(const Duration(minutes: 30)); // Always 30 min interval
    }
    
    print('[DEBUG] Generated ${slots.length} time slots');
    return slots;
  }

  @override
  void initState() {
    super.initState();
    // Initialize with default values in case Firestore fails to load
    _defaultBusinessHours = {
      'open': '09:00',
      'close': '17:00',
    };
    _fetchClosedDaysAndHours().then((_) => _loadTimeSlots());
    _fetchConsultantsAndStaff(); // Pre-load consultants
  }

  Future<void> _loadTimeSlots() async {
    setState(() => _isLoading = true);

    try {
      // Query all appointments for the venue on the selected date
      final querySnapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .where('venueId', isEqualTo: widget.venueId)
          .get();

      print('Loaded ${querySnapshot.docs.length} appointments for venue ${widget.venueId}');
      
      // Create a list of booked slots with their durations and statuses
      final bookedSlotsWithData = querySnapshot.docs.map((doc) {
        final data = doc.data();
        DateTime? appointmentDateTime;
        
        // Handle both Timestamp and String formats for backward compatibility
        if (data['appointmentTime'] is Timestamp) {
          appointmentDateTime = (data['appointmentTime'] as Timestamp).toDate();
        } else if (data['appointmentTime'] is String) {
          try {
            appointmentDateTime = DateTime.parse(data['appointmentTime']);
          } catch (e) {
            print('Error parsing date string: ${data['appointmentTime']}');
          }
        }
        
        if (appointmentDateTime == null) {
          return null;
        }
        
        return {
          'id': doc.id,
          'startTime': appointmentDateTime,
          'duration': data['duration'] is int ? data['duration'] : widget.serviceDuration,
          'status': data['status'] is String ? data['status'] : 'pending'
        };
      }).whereType<Map<String, dynamic>>().toList(); // Filter out null entries

      // Filter appointments for the selected date and exclude cancelled ones
      final selectedDateStart = DateTime(widget.selectedDate.year, widget.selectedDate.month, widget.selectedDate.day);
      final selectedDateEnd = selectedDateStart.add(const Duration(days: 1));
      
      final activeBookedSlots = bookedSlotsWithData
          .where((slot) {
                final startTime = slot['startTime'] as DateTime;
                return startTime.isAfter(selectedDateStart.subtract(const Duration(minutes: 1))) && 
                       startTime.isBefore(selectedDateEnd) && 
                       slot['status'] != 'cancelled';
              })
          .map((slot) => slot['startTime'] as DateTime)
          .toList();

      print('Found ${activeBookedSlots.length} active bookings for date ${widget.selectedDate.toString().split(' ')[0]}');
      
      _availableTimeSlots = _generateTimeSlots();
      setState(() {
        _bookedTimeSlots = activeBookedSlots;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading time slots: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading time slots: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  bool _isSlotBooked(DateTime slot) {
    // Get the end time of the potential new booking
    final newBookingEndTime = slot.add(Duration(minutes: widget.serviceDuration));
    
    // Create the start time with buffer (15 min before the actual start)
    final newBookingStartWithBuffer = slot.subtract(const Duration(minutes: 15));
    
    // Create the end time with buffer (15 min after the actual end)
    final newBookingEndWithBuffer = newBookingEndTime.add(const Duration(minutes: 15));
    
    // For each existing booking
    return _bookedTimeSlots.any((bookedSlot) {
      // Get the start time of existing booking (with 15 min buffer before)
      final bookedSlotStartWithBuffer = bookedSlot.subtract(const Duration(minutes: 15));
      
      // Get end time of existing booking based on service duration and cleaning buffer
      final bookedSlotEndTime = bookedSlot.add(
        Duration(minutes: widget.serviceDuration)
      );
      
      // Add 15 min buffer after end time
      final bookedSlotEndWithBuffer = bookedSlotEndTime.add(
        Duration(minutes: widget.selectedVenue.cleaningBuffer)
      );
      
      // Check for any overlap between the slots (including buffer times)
      // Case 1: New booking starts during an existing booking (including buffer)
      // Case 2: New booking ends during an existing booking (including buffer)
      // Case 3: New booking completely contains an existing booking
      // Case 4: Existing booking completely contains the new booking
      return (newBookingStartWithBuffer.isAfter(bookedSlotStartWithBuffer) && 
             newBookingStartWithBuffer.isBefore(bookedSlotEndWithBuffer)) || // Case 1
             (newBookingEndWithBuffer.isAfter(bookedSlotStartWithBuffer) && 
             newBookingEndWithBuffer.isBefore(bookedSlotEndWithBuffer)) || // Case 2
             (newBookingStartWithBuffer.isBefore(bookedSlotStartWithBuffer) && 
             newBookingEndWithBuffer.isAfter(bookedSlotEndWithBuffer)) || // Case 3
             (newBookingStartWithBuffer.isAtSameMomentAs(bookedSlotStartWithBuffer)) || // Exact same start time
             (bookedSlotStartWithBuffer.isAfter(newBookingStartWithBuffer) && 
             bookedSlotStartWithBuffer.isBefore(newBookingEndWithBuffer)); // Case 4
    });
  }

  // Fetch consultants and staff for the selected time slot
  Future<void> _fetchConsultantsAndStaff() async {
    try {
      setState(() => _isLoadingConsultants = true);
      
      // Query all users with role 'consultant' or 'staff'
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
        setState(() => _isLoadingConsultants = false);
      }
    }
  }
  
  // Check if staff is available at specified time - using the floor manager availability check method
  Future<bool> _isStaffAvailable(String staffId, String staffType, Timestamp appointmentTime, int duration, String? currentAppointmentId) async {
    // Check if staff is on sick leave
    final staffDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(staffId)
        .get();
    if (staffDoc.exists) {
      final staffData = staffDoc.data();
      if (staffData != null && (staffData['isSick'] == true || staffData['onSickLeave'] == true)) {
        print('[DEBUG][AVAILABILITY] Staff $staffId is on sick leave');
        return false;
      }
    }

    final appointmentStart = appointmentTime.toDate();
    final appointmentEnd = appointmentStart.add(Duration(minutes: duration));

    // Check for overlapping appointments
    final overlappingAppointments = await FirebaseFirestore.instance
        .collection('appointments')
        .where('${staffType}Id', isEqualTo: staffId)
        .get();

    for (var doc in overlappingAppointments.docs) {
      final data = doc.data();

      // Skip if looking at the same appointment
      if (currentAppointmentId != null && doc.id == currentAppointmentId) continue;

      if (data['appointmentTime'] is Timestamp) {
        final otherAppointmentTime = data['appointmentTime'] as Timestamp;
        final otherStart = otherAppointmentTime.toDate();
        final otherDuration = data['duration'] is int ? data['duration'] as int : 60;
        final otherEnd = otherStart.add(Duration(minutes: otherDuration));

        // Check for overlap
        if (appointmentStart.isBefore(otherEnd) && appointmentEnd.isAfter(otherStart)) {
          print('[DEBUG][AVAILABILITY] Staff $staffId has conflict with appointment ${doc.id} ($otherStart - $otherEnd)');
          return false;
        }
      }
    }

    print('[DEBUG][AVAILABILITY] Staff $staffId is available for $appointmentStart - $appointmentEnd');
    return true;
  }
  
  
  // Update availability for all consultants for the selected time
  Future<void> _updateConsultantAvailability(DateTime selectedTime) async {
    if (_consultantsAndStaff.isEmpty) await _fetchConsultantsAndStaff();
    
    List<Map<String, dynamic>> updatedList = [];
    
    for (var consultant in _consultantsAndStaff) {
      // Convert selectedTime to Timestamp for _isStaffAvailable
      final timestamp = Timestamp.fromDate(selectedTime);
      // Use _isStaffAvailable to check availability
      final isAvailable = await _isStaffAvailable(
        consultant['id'], 
        'consultant', // staffType (consultant or staff)
        timestamp,
        widget.serviceDuration, // appointment duration in minutes
        null // No current appointment ID for new bookings
      );
      
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

  // When a time slot is selected - show pickup location selection first
  Future<void> _handleTimeSlotSelection(DateTime selectedTime) async {
    setState(() {
      _selectedTimeSlot = selectedTime;
      _selectedPickupLocation = null; // Reset pickup location when time slot changes
    });
    
    // Show pickup location selection dialog
    await _showPickupLocationDialog();
  }
  
  // Show pickup location selection dialog
  Future<void> _showPickupLocationDialog() async {
    final locations = await _fetchPickupLocations();
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Pickup Location'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: locations.length,
            itemBuilder: (context, index) {
              final location = locations[index];
              final imageUrl = location['imageUrl'] as String?;
              final name = location['name'] as String;
              final description = location['description'] as String?;
              
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(8),
                  leading: imageUrl != null && imageUrl.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            imageUrl,
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => 
                                const Icon(Icons.broken_image, size: 30),
                          ),
                        )
                      : const Icon(Icons.location_on, size: 30, color: Colors.blue),
                  title: Text(name),
                  subtitle: description?.isNotEmpty == true ? Text(description!) : null,
                  onTap: () {
                    setState(() {
                      _selectedPickupLocation = location;
                    });
                    Navigator.pop(context);
                    _showConsultantSelection();
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
  
  // Show consultant selection after pickup location is selected
  Future<void> _showConsultantSelection() async {
    setState(() => _isLoadingConsultants = true);
    
    // Load consultants for dropdown
    await _updateConsultantAvailability(_selectedTimeSlot!);
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
          side: BorderSide(color: AppColors.richGold, width: 2.0),
        ),
        child: Container(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title
              Text(
                'Select a Consultant',
                style: TextStyle(
                  color: AppColors.richGold,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              
              // Loading indicator or content
              _isLoadingConsultants
                  ? Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.richGold),
                      ),
                    )
                  : ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // No preference option
                            Card(
                              color: Colors.grey[900],
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.0),
                                side: BorderSide(color: AppColors.richGold, width: 1.0),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                leading: Icon(Icons.person_outline, color: AppColors.richGold, size: 28),
                                title: Text(
                                  'No preference', 
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                subtitle: Text(
                                  'The floor manager will assign a consultant',
                                  style: TextStyle(color: Colors.grey[400]),
                                ),
                                onTap: () {
                                  setState(() {
                                    _selectedConsultantId = null;
                                    _selectedConsultantName = null;
                                    _selectedConsultantEmail = null;
                                  });
                                  Navigator.pop(context);
                                  _showBookingConfirmation();
                                },
                              ),
                            ),
                            
                            // List of consultants and staff
                            ..._consultantsAndStaff.map((consultant) {
                              final isAvailable = consultant['isAvailable'] == true;
                              final role = (consultant['role'] as String?)?.toLowerCase() ?? '';
                              
                              // Skip if not a consultant or staff
                              if (role != 'consultant' && role != 'staff') return const SizedBox.shrink();
                              
                              return Card(
                                color: isAvailable ? Colors.grey[900] : Colors.grey[800],
                                margin: const EdgeInsets.only(bottom: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                  side: BorderSide(
                                    color: isAvailable ? AppColors.richGold : Colors.grey[700]!,
                                    width: 1.0,
                                  ),
                                ),
                                child: Opacity(
                                  opacity: isAvailable ? 1.0 : 0.6,
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    leading: CircleAvatar(
                                      backgroundColor: isAvailable 
                                          ? AppColors.richGold.withOpacity(0.2) 
                                          : Colors.grey[700],
                                      child: isAvailable
                                          ? Text(
                                              consultant['name'].toString().substring(0, 1).toUpperCase(),
                                              style: TextStyle(
                                                color: AppColors.richGold,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            )
                                          : Icon(Icons.block, color: Colors.grey[500]),
                                    ),
                                    title: Text(
                                      consultant['name'] ?? 'Unknown',
                                      style: TextStyle(
                                        color: isAvailable ? Colors.white : Colors.grey[500],
                                        fontWeight: FontWeight.bold,
                                        decoration: isAvailable ? null : TextDecoration.lineThrough,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${consultant['role'] ?? 'Staff'}',
                                          style: TextStyle(
                                            color: isAvailable ? Colors.grey[400] : Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                        ),
                                        if (!isAvailable) ...[
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(Icons.block, size: 14, color: Colors.red[400]),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Not available',
                                                style: TextStyle(
                                                  color: Colors.red[400],
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                    trailing: isAvailable
                                        ? Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.richGold)
                                        : null,
                                    onTap: isAvailable
                                        ? () {
                                            setState(() {
                                              _selectedConsultantId = consultant['id'];
                                              _selectedConsultantName = consultant['name'];
                                              _selectedConsultantEmail = consultant['email'];
                                            });
                                            Navigator.pop(context);
                                            _showBookingConfirmation();
                                          }
                                        : null,
                                  ),
                                ),
                              );
                            }).where((widget) => widget != const SizedBox.shrink()).toList(),
                          ],
                        ),
                      ),
                    ),
              
              // Close button
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    side: BorderSide(color: AppColors.richGold, width: 1.0),
                  ),
                ),
                child: Text(
                  'CANCEL',
                  style: TextStyle(
                    color: AppColors.richGold,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).then((_) {
      setState(() => _isLoadingConsultants = false);
    });
  }
  
  // Show booking confirmation dialog
  Future<void> _showBookingConfirmation() {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Booking'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Service: ${widget.selectedService.name}'),
            Text('Date: ${DateFormat('EEEE, MMMM d, yyyy').format(_selectedTimeSlot!)}'),
            Text('Time: ${DateFormat('h:mm a').format(_selectedTimeSlot!)}'),
            if (_selectedPickupLocation != null) 
              Text('Pickup: ${_selectedPickupLocation!['name']}'),
            if (_selectedConsultantName != null)
              Text('Consultant: $_selectedConsultantName')
            else
              const Text('Consultant: No preference (will be assigned)'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _handleBookAppointment();
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
  
  // Fetch pickup locations from Firestore
  Future<List<Map<String, dynamic>>> _fetchPickupLocations() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('pickup_locations')
          .orderBy('name')
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? '',
          'description': data['description'],
          'imageUrl': data['imageUrl'],
        };
      }).toList();
    } catch (e) {
      print('Error fetching pickup locations: $e');
      return [];
    }
  }
  
  // Generate a random alphanumeric reference number (5 characters)
  String _generateReferenceNumber() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return String.fromCharCodes(
      Iterable.generate(5, (_) => chars.codeUnitAt(random.nextInt(chars.length)))
    );
  }

  // Handle the booking process
  Future<void> _handleBookAppointment() async {
    if (_selectedTimeSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a time slot first')),
      );
      return;
    }
    
    // Check if pickup location is selected
    if (_selectedPickupLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a pickup location')),
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

      // Get floor manager details
      Map<String, dynamic>? floorManagerData;
      try {
        final floorManagerQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'floorManager')
            .limit(1)
            .get();
            
        if (floorManagerQuery.docs.isNotEmpty) {
          final doc = floorManagerQuery.docs.first;
          floorManagerData = {
            'floorManagerId': doc.id,
            'floorManagerName': '${doc.data()['firstName'] ?? ''} ${doc.data()['lastName'] ?? ''}'.trim(),
          };
          print('[DEBUG] Found floor manager: ${floorManagerData['floorManagerName']}');
        } else {
          print('[WARNING] No floor manager found in the system');
        }
      } catch (e) {
        print('[ERROR] Error fetching floor manager: $e');
      }

      // Generate reference number
      final referenceNumber = _generateReferenceNumber();
      
      // Create appointment data with base fields
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
        'referenceNumber': referenceNumber, // Add reference number
        'typeOfVip': ministerData['clientType'] ?? 'VIP Client', // Use clientType from user data
        // Add pickup location data
        'pickupLocation': {
          'id': _selectedPickupLocation!['id'],
          'name': _selectedPickupLocation!['name'],
          'description': _selectedPickupLocation!['description'],
          'imageUrl': _selectedPickupLocation!['imageUrl'],
        },
        // Add floor manager data if available
        if (floorManagerData != null) ...{
          'floorManagerId': floorManagerData['floorManagerId'],
          'floorManagerName': floorManagerData['floorManagerName'],
        },
      };
      
      // Only add consultant fields if a specific consultant was selected (not 'No preference')
      // This follows the user's requirement to not set these fields when 'No preference' is selected
      if (_selectedConsultantId != null) {
        appointmentData['consultantId'] = _selectedConsultantId;
        appointmentData['consultantName'] = _selectedConsultantName;
        appointmentData['consultantEmail'] = _selectedConsultantEmail;
        print('[DEBUG] Consultant selected: $_selectedConsultantName (ID: $_selectedConsultantId)');
      } else {
        print('[DEBUG] No consultant preference selected - consultant fields will not be set');
      }

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
      try {
        await notificationService.sendFCMToFloorManager(
          title: 'New Appointment #$referenceNumber',
          body: 'A new appointment has been booked by ${ministerData['firstName']} ${ministerData['lastName']} (Ref: #$referenceNumber)',
          data: {
            'type': 'booking',
            'bookingId': appointmentId,
            'appointmentTime': _selectedTimeSlot!.toIso8601String(),
            'serviceName': widget.selectedService.name,
            'ministerName': '${ministerData['firstName']} ${ministerData['lastName']}',
            'floorManagerId': floorManagerData?['floorManagerId'],
            'referenceNumber': referenceNumber,
          },
        );
        print('[DEBUG] Sent FCM notification to floor managers');
      } catch (e) {
        print('[ERROR] Failed to send FCM to floor managers: $e');
      }
      
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
                title: 'New Appointment #$referenceNumber Assigned',
                body: 'You have been assigned to a new appointment with ${ministerData['firstName']} ${ministerData['lastName']} (Ref: #$referenceNumber)',
                data: {
                  'type': 'booking',
                  'bookingId': appointmentId,
                  'referenceNumber': referenceNumber,
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
        eventData: {
          ...appointmentData,
          'referenceNumber': referenceNumber, // Include reference number in event data
          'serviceId': widget.selectedService.id,
          'serviceName': widget.selectedService.name,
          'serviceCategory': widget.serviceCategory,
          'subServiceName': widget.subServiceName,
          'venueId': widget.venueId,
          'venueName': widget.venueName,
          'appointmentTime': _selectedTimeSlot!.toIso8601String(),
          'duration': widget.serviceDuration,
        },
        notes: 'Booking created by minister',
      );

      // Create notification for floor managers
      final notificationData = {
        ...appointmentData,
        'appointmentId': appointmentId,
        'notificationType': 'new_appointment',
      };

      print('Creating notification with data: $notificationData');

      // Format appointment time for display
      final formattedTime = DateFormat('EEEE, MMMM d, yyyy, h:mm a').format(_selectedTimeSlot!);
      
      try {
        // Send initial welcome notification to minister
        await _notificationService.createNotification(
          role: 'minister',
          assignedToId: ministerData['uid'],
          title: 'Booking Confirmation',
          body: 'Your booking #$referenceNumber for ${widget.selectedService.name} at ${widget.venueName} on $formattedTime has been confirmed. A staff member will be assigned to you shortly.',
          notificationType: 'booking_confirmation',
          data: {
            'appointmentId': appointmentId,
            'notificationType': 'booking_confirmation',
            'status': 'pending',
            'referenceNumber': referenceNumber,
          },
        );
        
        // Also send notification using SendMyFCM with dynamic content based on category/subcategory
        final sendMyFCM = new SendMyFCM();
        
        // Get client name from ministerData
        String clientName = '${ministerData['firstName'] ?? ''} ${ministerData['lastName'] ?? ''}';
        clientName = clientName.trim();
        
        // Generate dynamic notification body based on service category and subcategory
        String categorySpecificMessage = '';
        String mainCategory = widget.serviceCategory;
        String subcategory = widget.subServiceName ?? '';
        
        if (mainCategory.contains('Contract Services')) {
          if (subcategory.contains('New contract')) {
            categorySpecificMessage = 'Documents Needed for Your New Contract Appointment\n\n'
                'Hi $clientName, '
                'Thanks for booking your new contract appointment. Please bring the following documents with you:\n'
                '• ID\n'
                '• Latest Proof of Residence (not older than 3 months)\n'
                '• Latest Proof of Banking Details\n'
                '• Latest Proof of Income:\n'
                ' – Payslip or\n'
                ' – 3 months\' bank statements\n'
                'We look forward to assisting you!';
          } else if (subcategory.contains('Upgrade') && subcategory.contains('Individual')) {
            categorySpecificMessage = 'Documents for Your Upgrade Appointment\n\n'
                'Hi $clientName, for your upgrade appointment, kindly bring:\n'
                '• Valid ID or Driver\'s Licence\n\n'
                'Thank you for choosing our VIP service.';
          } else if (subcategory.contains('Upgrade') && subcategory.contains('Business')) {
            categorySpecificMessage = 'Business Upgrade Appointment – Required Documents\n\n'
                'Hi $clientName, for your business upgrade, please bring:\n'
                '• Director\'s ID\n'
                '• Company order\n'
                'Please ensure all documents are available for a seamless process.';
          } else {
            // Default for other Contract Services
            categorySpecificMessage = 'Documents Needed for Your Appointment\n\n'
                'Hi $clientName, '
                'Thanks for booking your Contract Services appointment. Please bring the following documents with you:\n'
                '• ID\n'
                '• Latest Proof of Residence (not older than 3 months)\n'
                '• Latest Proof of Banking Details\n'
                '• Latest Proof of Income:\n'
                ' – Payslip or\n'
                ' – 3 months\' bank statements\n'
                'We look forward to assisting you!';
          }
        } else if (mainCategory.contains('Device and sim Services') || 
                  subcategory.contains('SIM Swap')) {
          if (subcategory.contains('Individual')) {
            categorySpecificMessage = 'SIM Swap Appointment – Required Documents\n\n'
                'Hi $clientName, for your SIM swap, please bring:\n'
                '• Valid ID and Proof of Address\n'
                'We\'re here to help you get reconnected quickly.';
          } else if (subcategory.contains('Business')) {
            categorySpecificMessage = 'Business SIM Swap – Required Documents\n\n'
                'Hi $clientName, for your business SIM swap, kindly bring:\n'
                '• Company order on official letterhead\n'
                '• Director\'s ID\n'
                'Let us know if you need any assistance before your appointment.';
          } else if (subcategory.contains('Prepaid')) {
            categorySpecificMessage = 'Documents for Prepaid Activation\n\n'
                'Hi $clientName, for your prepaid SIM activation, please bring:\n'
                '• Valid ID\n'
                '• Proof of address\n'
                'Your convenience is our priority.';
          }
        } else if (mainCategory.contains('Business solutions')) {
          categorySpecificMessage = 'Business Upgrade Appointment – Required Documents\n\n'
                'Hi $clientName, for your business upgrade, please bring:\n'
                '• Director\'s ID\n'
                '• Company order\n'
                'Please ensure all documents are available for a seamless process.';
        } else if (mainCategory.contains('Value Added') || subcategory.contains('VAS')) {
          categorySpecificMessage = 'Documents for Your Value-Added Service\n\n'
                'Hi $clientName, to process your VAS request, please bring:\n'
                '• Valid ID\n'
                'Feel free to reach out if you have any questions before your appointment.';
        }
        
        // If no specific message was set, use the default
        if (categorySpecificMessage.isEmpty) {
          categorySpecificMessage = 'Your booking #$referenceNumber for ${widget.selectedService.name} at ${widget.venueName} on $formattedTime has been confirmed. A staff member will be assigned to you shortly.';
        } else {
          // Add the standard booking confirmation at the end if we have a specific message
          categorySpecificMessage += '\n\nBooking #$referenceNumber\n${widget.selectedService.name} at ${widget.venueName} on $formattedTime.';
        }
        
        await sendMyFCM.sendNotification(
          recipientId: ministerData['uid'],
          title: 'Booking Confirmation #$referenceNumber',
          body: categorySpecificMessage,
          appointmentId: appointmentId,
          role: 'minister',
          additionalData: {
            'notificationType': 'booking_confirmation',
            'status': 'pending',
            'serviceCategory': mainCategory,
            'subServiceName': subcategory,
            'referenceNumber': referenceNumber,
          },
          showRating: false,
          notificationType: 'booking_confirmation',
        );

        // Query all floor managers and send notification to each
        final floorManagerQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'floorManager')
            .get();
        final floorManagerUids = floorManagerQuery.docs
            .map((doc) => doc.data()['uid'] as String?)
            .where((uid) => uid != null && uid.isNotEmpty)
            .cast<String>()
            .toList();
        print('Floor Manager UIDs (time slot selection): ' + floorManagerUids.join(', '));
        for (var floorManagerUid in floorManagerUids) {
          await _notificationService.createNotification(
            role: 'floorManager',
            assignedToId: floorManagerUid,
            title: 'New Appointment Request #$referenceNumber',
            body: 'Minister ${ministerData['firstName'] ?? ''} ${ministerData['lastName'] ?? ''} has requested an appointment (Ref: #$referenceNumber)',
            notificationType: 'new_appointment',
            data: notificationData..['referenceNumber'] = referenceNumber,
          );
          
          // Also send notification to floor managers using SendMyFCM
          final sendMyFCM = new SendMyFCM();
          await sendMyFCM.sendNotification(
            recipientId: floorManagerUid,
            title: 'New Appointment Request #$referenceNumber',
            body: 'Minister ${ministerData['firstName'] ?? ''} ${ministerData['lastName'] ?? ''} has requested an appointment (Ref: #$referenceNumber)',
            appointmentId: appointmentId,
            role: 'floorManager',
            additionalData: notificationData..['referenceNumber'] = referenceNumber,
            showRating: false,
            notificationType: 'new_appointment',
          );
        }
        
        // If a consultant was selected, send them a notification
        if (_selectedConsultantId != null && _selectedConsultantName != null) {
          print('Sending notification to selected consultant: $_selectedConsultantName (ID: $_selectedConsultantId)');
          
          // Create notification for the consultant
          await _notificationService.createNotification(
            role: 'consultant',
            assignedToId: _selectedConsultantId!,
            title: 'New Appointment #$referenceNumber Assigned',
            body: 'Minister ${ministerData['firstName'] ?? ''} ${ministerData['lastName'] ?? ''} has requested an appointment and selected you as their consultant (Ref: #$referenceNumber)',
            notificationType: 'assigned_appointment',
            data: notificationData..['referenceNumber'] = referenceNumber,
          );
          
          // Also send FCM notification to the consultant
          final consultantFcm = new SendMyFCM();
          await consultantFcm.sendNotification(
            recipientId: _selectedConsultantId!,
            title: 'New Appointment #$referenceNumber Assigned',
            body: 'Minister ${ministerData['firstName'] ?? ''} ${ministerData['lastName'] ?? ''} has requested an appointment and selected you as their consultant (Ref: #$referenceNumber)',
            appointmentId: appointmentId,
            role: 'consultant',
            additionalData: notificationData,
            showRating: false,
            notificationType: 'assigned_appointment',
          );
        }
        print('Notifications sent successfully');
      } catch (e) {
        print('Error sending notifications: $e');
        // Continue with booking even if notification fails
      }

      // 🔥 ADD TO CALENDAR AFTER SUCCESSFUL BOOKING
      print('🔥🔥🔥 STARTING CALENDAR INTEGRATION 🔥🔥🔥');
      try {
        await _addAppointmentToCalendar(
          _selectedTimeSlot!,
          referenceNumber,
        );
        print('🔥🔥🔥 CALENDAR INTEGRATION COMPLETED 🔥🔥🔥');
      } catch (calendarError) {
        print('🔥 CALENDAR INTEGRATION ERROR: $calendarError');
        // Don't fail the booking if calendar fails
      }

      if (mounted) {
        // Navigate back to home screen after successful booking
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/minister/home',
          (route) => false, // This removes all routes from the stack
        );
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Appointment booked successfully'),
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      print('Error booking appointment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error booking appointment: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isBooking = false);
      }
    }
  }

  // Add appointment to device calendar using simple add_2_calendar plugin - NO PERMISSIONS NEEDED!
  Future<void> _addAppointmentToCalendar(
    DateTime appointmentTime,
    String referenceNumber,
  ) async {
    print('🔥🔥🔥 CALENDAR INTEGRATION METHOD CALLED - START 🔥🔥🔥');
    print('🔥 Method parameters received:');
    print('🔥 - appointmentTime: $appointmentTime');
    print('🔥 - referenceNumber: $referenceNumber');
    
    // Get appointment data from widget properties
    final serviceName = widget.selectedService.name;
    final venueName = widget.venueName;
    final duration = widget.serviceDuration;
    final subServiceName = widget.subServiceName;
    
    print('🔥 Appointment data from widget:');
    print('🔥 - serviceName: $serviceName');
    print('🔥 - venueName: $venueName');
    print('🔥 - duration: $duration');
    print('🔥 - subServiceName: $subServiceName');
    
    try {
      print('🔥 STEP 1: Calculating event details...');
      
      // Calculate end time
      final endTime = appointmentTime.add(Duration(minutes: duration));
      
      // Create event details
      final eventTitle = subServiceName != null && subServiceName.isNotEmpty
          ? '$serviceName - $subServiceName'
          : serviceName;
      
      final eventDescription = 'Appointment with VIP Premium lounge\n\n'
          'Service: $serviceName\n'
          '${subServiceName != null && subServiceName.isNotEmpty ? 'Sub-Service: $subServiceName\n' : ''}'
          'Venue: $venueName\n'
          'Reference: $referenceNumber\n\n'
          'Please arrive 15 minutes early.';
      
      print('📅 STEP 2: Event details calculated:');
      print('📅 - Title: $eventTitle');
      print('📅 - Start: $appointmentTime');
      print('📅 - End: $endTime');
      print('📅 - Location: $venueName');
      print('📅 - Description length: ${eventDescription.length} chars');
      
      print('📅 STEP 3: Creating Event object...');
      
      // Create event using add_2_calendar plugin
      final Event event = Event(
        title: eventTitle,
        description: eventDescription,
        location: venueName,
        startDate: appointmentTime,
        endDate: endTime,
        iosParams: IOSParams(
          reminder: Duration(minutes: 15), // 15 minute reminder
        ),
        androidParams: AndroidParams(
          emailInvites: [], // no email invites
        ),
      );
      
      print('✅ STEP 4: Event object created successfully!');
      print('📅📅📅 STEP 5: CALLING Add2Calendar.addEvent2Cal() 📅📅📅');
      
      // Add event to calendar - this opens the device's calendar app
      final bool result = await Add2Calendar.addEvent2Cal(event);
      
      print('📅 STEP 6: Add2Calendar.addEvent2Cal() returned: $result');
      
      if (result) {
        print('✅✅✅ CALENDAR APP OPENED SUCCESSFULLY! ✅✅✅');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('📅 Calendar opened! Save the event to add it to your calendar.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 4),
            ),
          );
        }
      } else {
        print('❌❌❌ FAILED TO OPEN CALENDAR APP - RESULT WAS FALSE ❌❌❌');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Failed to open calendar app'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      print('❌❌❌ ERROR DURING CALENDAR INTEGRATION ❌❌❌');
      print('❌ Error: $e');
      print('❌ Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Calendar error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    
    print('🔥🔥🔥 CALENDAR INTEGRATION METHOD FINISHED 🔥🔥🔥');
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AppAuthProvider>(context);
    final ministerData = authProvider.ministerData;
    final dateFormat = DateFormat('EEEE, MMMM d, yyyy');
    
    // Group time slots by hour for better organization
    final Map<int, List<DateTime>> timeSlotsByHour = {};
    for (final slot in _availableTimeSlots) {
      if (!timeSlotsByHour.containsKey(slot.hour)) {
        timeSlotsByHour[slot.hour] = [];
      }
      timeSlotsByHour[slot.hour]!.add(slot);
    }
    
    // Sort hours for consistent display
    final sortedHours = timeSlotsByHour.keys.toList()..sort();
    
    final isClosed = _isDateClosed(widget.selectedDate);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Select Appointment Time',
          style: TextStyle(color: AppColors.richGold, fontWeight: FontWeight.bold),
        ),
        iconTheme: IconThemeData(color: AppColors.richGold),
      ),
      body: Stack(
        children: [
          // Main content
          _isLoading 
            ? Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppColors.richGold)))
            : Column(
            children: [
              // Date and service info section at top
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Service info
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.richGold, width: 1),
                          ),
                          child: Icon(Icons.spa, color: AppColors.richGold, size: 24),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.selectedService.name,
                                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              if (widget.subServiceName != null && widget.subServiceName!.isNotEmpty)
                                Text(
                                  widget.subServiceName!,
                                  style: TextStyle(color: Colors.grey[400], fontSize: 14),
                                ),
                              const SizedBox(height: 4),
                              Text(
                                '${widget.serviceDuration} minutes',
                                style: TextStyle(color: AppColors.richGold, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Date and venue
                    Row(
                      children: [
                        // Date display
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.richGold.withOpacity(0.5)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today, color: AppColors.richGold, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Date',
                                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                                      ),
                                      Text(
                                        dateFormat.format(widget.selectedDate),
                                        style: const TextStyle(color: Colors.white, fontSize: 14),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        const SizedBox(width: 12),
                        
                        // Venue display
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.richGold.withOpacity(0.5)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.location_on, color: AppColors.richGold, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Venue',
                                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                                      ),
                                      Text(
                                        widget.venueName,
                                        style: const TextStyle(color: Colors.white, fontSize: 14),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Available time slots section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Icon(Icons.access_time, color: AppColors.richGold, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Available Time Slots',
                      style: TextStyle(
                        color: AppColors.richGold,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Time slot selection area
              Expanded(
                child: isClosed
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.event_busy, color: AppColors.richGold, size: 64),
                          const SizedBox(height: 16),
                          Text(
                            'Closed on this day',
                            style: TextStyle(color: AppColors.richGold, fontSize: 16),
                          ),
                          const SizedBox(height: 24),
                          OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: AppColors.richGold),
                              foregroundColor: AppColors.richGold,
                            ),
                            child: const Text('Select Another Date'),
                          ),
                        ],
                      ),
                    )
                  : _availableTimeSlots.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.event_busy, color: AppColors.richGold, size: 64),
                            const SizedBox(height: 16),
                            Text(
                              'No time slots available for this date',
                              style: TextStyle(color: AppColors.richGold, fontSize: 16),
                            ),
                            const SizedBox(height: 24),
                            OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: AppColors.richGold),
                                foregroundColor: AppColors.richGold,
                              ),
                              child: const Text('Select Another Date'),
                            ),
                          ],
                        ),
                      )
                    : Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: ListView.builder(
                          itemCount: sortedHours.length,
                          itemBuilder: (context, index) {
                            final hour = sortedHours[index];
                            final slots = timeSlotsByHour[hour]!;
                            String timeOfDay = "";
                            if (hour < 12) {
                              timeOfDay = "Morning";
                            } else if (hour < 17) {
                              timeOfDay = "Afternoon";
                            } else {
                              timeOfDay = "Evening";
                            }
                            final displayHour = hour > 12 ? hour - 12 : hour;
                            final amPm = hour >= 12 ? 'PM' : 'AM';
                            return Card(
                              margin: const EdgeInsets.only(bottom: 16),
                              color: Colors.grey[900],
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.black,
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(color: AppColors.richGold.withOpacity(0.7)),
                                          ),
                                          child: Text(
                                            '$timeOfDay',
                                            style: TextStyle(color: AppColors.richGold, fontSize: 12),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          '$displayHour $amPm',
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 12,
                                      children: slots.map((timeSlot) {
                                        final isBooked = _isSlotBooked(timeSlot);
                                        final isNowPast = timeSlot.isBefore(DateTime.now());
                                        final isDisabled = isBooked || isNowPast || _isBooking;
                                        return InkWell(
                                          onTap: isDisabled ? null : () => _handleTimeSlotSelection(timeSlot),
                                          borderRadius: BorderRadius.circular(8),
                                          child: Container(
                                            width: 80,
                                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                                            decoration: BoxDecoration(
                                              color: isDisabled 
                                                ? (isBooked ? Colors.grey[800] : Colors.grey) 
                                                : Colors.black,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: isDisabled 
                                                  ? (isBooked ? Colors.redAccent.withOpacity(0.5) : Colors.grey) 
                                                  : AppColors.richGold,
                                              ),
                                              boxShadow: isDisabled ? [] : [
                                                BoxShadow(
                                                  color: AppColors.richGold.withOpacity(0.2),
                                                  blurRadius: 4,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  '${timeSlot.hour.toString().padLeft(2, '0')}:${timeSlot.minute.toString().padLeft(2, '0')}',
                                                  style: TextStyle(
                                                    color: isDisabled 
                                                      ? (isBooked ? Colors.redAccent.withOpacity(0.7) : Colors.grey) 
                                                      : AppColors.richGold,
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                                if (isDisabled)
                                                  Text(
                                                    isBooked ? 'Booked' : 'Unavailable',
                                                    style: TextStyle(
                                                      color: isBooked ? Colors.redAccent.withOpacity(0.7) : Colors.grey,
                                                      fontSize: 10,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
              
              // Note: Removing the consultant selection UI from here as it will be added to stack overlay
              
              // Booking indicator
              if (_isBooking)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: _isLoading
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.richGold),
                ),
                const SizedBox(height: 16),
                Text(
                  'Loading time slots...',
                  style: TextStyle(color: AppColors.richGold),
                ),
              ],
            ),
          )
        : Column(
            children: [
              const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppColors.richGold)),
              const SizedBox(height: 16),
              Text(
                'Confirming your appointment...',
                style: TextStyle(color: AppColors.richGold, fontSize: 16),
              ),
            ],
          ),
                ),
            ],
          ),
          
          // Consultant selection overlay when a time slot is selected
          if (_selectedTimeSlot != null && !isClosed)
            Positioned.fill(
              child: GestureDetector(
                onTap: () {}, // Prevent taps from passing through to background
                child: Container(
                  color: Colors.black.withOpacity(0.7),
                  child: Center(
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.9,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 15,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title and close button
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Select Consultant',
                                style: TextStyle(color: AppColors.richGold, fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              IconButton(
                                icon: Icon(Icons.close, color: AppColors.richGold),
                                onPressed: () {
                                  setState(() => _selectedTimeSlot = null);
                                },
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 8),
                          
                          // Selected time display
                          Text(
                            'Selected Time: ${DateFormat('h:mm a').format(_selectedTimeSlot!)}',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                          
                          const Divider(color: Colors.grey, height: 24),
                          
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Text(
                              'Please select your preferred consultant. Unavailable consultants are shown in gray.',
                              style: TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                          ),
                          
                          // Consultant dropdown
                          _isLoadingConsultants
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.richGold),
                                  ),
                                ),
                              )
                            : Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.richGold, width: 1),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    isExpanded: true,
                                    dropdownColor: Colors.black,
                                    value: _selectedConsultantId,
                                    hint: Text('Select consultant', style: TextStyle(color: Colors.white70)),
                                    icon: Icon(Icons.arrow_drop_down, color: AppColors.richGold),
                                    items: [
                                       DropdownMenuItem<String>(
                                        value: null,
                                        child: Text(
                                          'No preference',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ),
                                      ...(_consultantsAndStaff).map((consultant) {
                                        // Always show all consultants, but grey out and disable unavailable ones
                                        final bool isAvailable = consultant['isAvailable'] ?? false;
                                        return DropdownMenuItem<String>(
                                          value: consultant['id'],
                                          enabled: isAvailable, // Only allow selecting available consultants
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  consultant['name'],
                                                  style: TextStyle(
                                                    color: isAvailable ? Colors.white : Colors.grey[600],
                                                    fontWeight: isAvailable ? FontWeight.normal : FontWeight.normal,
                                                  ),
                                                ),
                                              ),
                                              // Show availability indicator
                                              if (!isAvailable)
                                                Tooltip(
                                                  message: 'Consultant not available at selected time',
                                                  child: Icon(
                                                    Icons.block,
                                                    color: Colors.red[300],
                                                    size: 16,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ],
                                    onChanged: (String? consultantId) {
                                      setState(() {
                                        _selectedConsultantId = consultantId;
                                        if (consultantId == null) {
                                          _selectedConsultantName = null;
                                          _selectedConsultantEmail = null;
                                        } else {
                                          // Find the consultant in the list
                                          final consultant = (_consultantsAndStaff)
                                                .firstWhere((c) => c['id'] == consultantId);
                                          _selectedConsultantName = consultant['name'];
                                          _selectedConsultantEmail = consultant['email'];
                                          print('Selected consultant: ${consultant['name']}, Email: ${consultant['email']}');
                                        }
                                      });
                                    },
                                  ),
                                ),
                              ),
                          
                          const SizedBox(height: 24),
                          
                          // Book button
                          ElevatedButton(
                            onPressed: _isBooking ? null : _handleBookAppointment,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.richGold,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              minimumSize: const Size(double.infinity, 48),
                            ),
                            child: _isBooking
                              ? SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'BOOK THIS APPOINTMENT',
                                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _fetchClosedDaysAndHours() async {
    // Call static method directly
    await ClosedDayHelper.ensureLoaded();

    try {
      // Fetch business hours from global settings
      print('[DEBUG] Fetching global business hours');
      final doc = await FirebaseFirestore.instance
          .collection('business')
          .doc('settings')
          .get();
          
      if (doc.exists && doc.data() != null) {
        final data = doc.data();
        if (data != null) {
          // Business hours (per day)
          if (data['businessHours'] != null) {
            setState(() {
              _businessHoursMap = data['businessHours'] as Map<String, dynamic>;
              print('[DEBUG] Loaded business hours: ${_businessHoursMap?.keys.toList() ?? 'none'}');
            });
          } else {
            print('[WARNING] No global business settings found');
            setState(() {
              _businessHoursMap = null;
            });
          }
        }
      } else {
        print('[WARNING] No global business settings found');
      }
      
      // Log any existing business hours we might have loaded
      if (_businessHoursMap != null) {
        print('[DEBUG] Current business hours map:');
        for (var key in _businessHoursMap!.keys) {
          print('[DEBUG]   $key: ${_businessHoursMap![key]}');
        }
      } else {
        print('[DEBUG] No business hours map loaded yet');
      }
      
      // NO LONGER USING DEFAULT HOURS AS FALLBACK - per user requirement
      // Only get settings for debug purposes
      final settingsDoc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('businessHours')
          .get();
      
      if (settingsDoc.exists && settingsDoc.data() != null) {
        final data = settingsDoc.data();
        print('[DEBUG] Settings data available (for debug only): $data');
      } else {
        print('[DEBUG] No settings doc found');
      }
    } catch (e) {
      print('[ERROR] Error fetching business hours: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading business hours: $e'))
        );
      }
    } finally {
      // Make sure we reset loading status even if there's an error
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}