import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
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
  List<DateTime> _availableTimeSlots = [];
  List<DateTime> _bookedTimeSlots = [];
  bool _isLoading = true;
  bool _isBooking = false;
  final NotificationService _notificationService = NotificationService();
  final WorkflowService _workflowService = WorkflowService();

  // --- CLOSED DAYS & BUSINESS HOURS STATE ---
  Set<String> _closedDaysSet = {};
  TimeOfDay? _openingTime;
  TimeOfDay? _closingTime;
  Map<String, dynamic>? _businessHoursMap;
  Map<String, dynamic>? _defaultBusinessHours;

  // Helper to get abbreviated weekday key (e.g., 'mon', 'tue', ...)
  String _weekdayKey(DateTime date) {
    return DateFormat('E').format(date).toLowerCase(); // returns 'mon', 'tue', etc.
  }

  // Helper to check if selected date is closed
  bool _isDateClosed(DateTime date) {
    final String dayKey = _weekdayKey(date);
    print('[DEBUG] Checking closed for $dayKey: ' + (_businessHoursMap != null ? _businessHoursMap![dayKey].toString() : 'NO MAP'));
    if (_businessHoursMap != null && _businessHoursMap![dayKey] is Map && _businessHoursMap![dayKey]['closed'] == true) {
      print('[DEBUG] $dayKey is closed');
      return true;
    }
    return _closedDaysSet.contains(DateFormat('yyyy-MM-dd').format(date));
  }

  // Returns the opening/closing TimeOfDay for the selected date, or null if closed
  Map<String, TimeOfDay?> _getBusinessHoursForDate(DateTime date, {bool withBuffer = false}) {
    final String dayKey = _weekdayKey(date);
    int openBuffer = withBuffer ? -1 : 0;
    int closeBuffer = withBuffer ? 1 : 0;
    if (_businessHoursMap != null && _businessHoursMap![dayKey] is Map) {
      final dayHours = _businessHoursMap![dayKey];
      if (dayHours['closed'] == true) return {'open': null, 'close': null};
      if (dayHours['open'] != null && dayHours['close'] != null) {
        final openParts = (dayHours['open'] as String).split(":");
        final closeParts = (dayHours['close'] as String).split(":");
        TimeOfDay open = TimeOfDay(hour: int.parse(openParts[0]), minute: int.parse(openParts[1]));
        TimeOfDay close = TimeOfDay(hour: int.parse(closeParts[0]), minute: int.parse(closeParts[1]));
        if (withBuffer) {
          open = TimeOfDay(hour: (open.hour + openBuffer).clamp(0, 23), minute: open.minute);
          close = TimeOfDay(hour: (close.hour + closeBuffer).clamp(0, 23), minute: close.minute);
        }
        return {'open': open, 'close': close};
      }
    }
    // Fallback to settings if available, otherwise null
    if (_defaultBusinessHours != null) {
      final openParts = (_defaultBusinessHours!['open'] as String).split(":");
      final closeParts = (_defaultBusinessHours!['close'] as String).split(":");
      TimeOfDay open = TimeOfDay(hour: int.parse(openParts[0]), minute: int.parse(openParts[1]));
      TimeOfDay close = TimeOfDay(hour: int.parse(closeParts[0]), minute: int.parse(closeParts[1]));
      if (withBuffer) {
        open = TimeOfDay(hour: (open.hour + openBuffer).clamp(0, 23), minute: open.minute);
        close = TimeOfDay(hour: (close.hour + closeBuffer).clamp(0, 23), minute: close.minute);
      }
      return {'open': open, 'close': close};
    }
    return {'open': null, 'close': null};
  }

  // Generates time slots for the selected date, using business hours and correct interval
  List<DateTime> _generateTimeSlots() {
    final slots = <DateTime>[];
    final date = widget.selectedDate;
    final hours = _getBusinessHoursForDate(date);
    final opening = hours['open'];
    final closing = hours['close'];
    if (opening == null || closing == null) return slots; // Closed
    DateTime current = DateTime(date.year, date.month, date.day, opening.hour, opening.minute);
    final end = DateTime(date.year, date.month, date.day, closing.hour, closing.minute);
    while (current.isBefore(end)) {
      slots.add(current);
      current = current.add(const Duration(minutes: 30)); // Always 30 min interval
    }
    return slots;
  }

  @override
  void initState() {
    super.initState();
    _fetchClosedDaysAndHours().then((_) => _loadTimeSlots());
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

  Future<void> _handleTimeSlotSelection(DateTime selectedTime) async {
    setState(() => _isBooking = true);

    try {
      final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
      final ministerData = authProvider.ministerData;
      
      if (ministerData == null) {
        throw Exception('Minister data not found');
      }

      print('Booking with minister data: $ministerData'); // Debug print

      // Create appointment data
      final appointmentData = {
        'ministerId': ministerData['uid'],
        'ministerFirstName': ministerData['firstName'] ?? '',
        'ministerLastName': ministerData['lastName'] ?? '',
        'ministerEmail': ministerData['email'] ?? '',
        'ministerPhone': ministerData['phoneNumber'] ?? 'Not provided',
        'serviceId': widget.selectedService.id,
        'serviceName': widget.selectedService.name,
        'serviceCategory': widget.serviceCategory,
        'subServiceName': widget.subServiceName,
        'venueId': widget.venueId,
        'venueName': widget.venueName,
        'appointmentTime': Timestamp.fromDate(selectedTime),
        'appointmentTimeISO': selectedTime.toIso8601String(),
        'duration': widget.serviceDuration,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      };

      print('Creating appointment with data: $appointmentData');

      // Create the appointment
      final appointmentRef = await FirebaseFirestore.instance
          .collection('appointments')
          .add(appointmentData);

      // Record workflow event for booking creation
      await _workflowService.recordEvent(
        appointmentId: appointmentRef.id,
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
          'appointmentTime': selectedTime.toIso8601String(),
          'duration': widget.serviceDuration,
        },
      );

      // Create notification for floor managers
      final notificationData = {
        ...appointmentData,
        'appointmentId': appointmentRef.id,
        'notificationType': 'new_appointment',
      };

      print('Creating notification with data: $notificationData');

      // Format appointment time for display
      final formattedTime = DateFormat('EEEE, MMMM d, yyyy, h:mm a').format(selectedTime);
      
      try {
        // Send initial welcome notification to minister
        await _notificationService.createNotification(
          role: 'minister',
          assignedToId: ministerData['uid'],
          title: 'Booking Confirmation',
          body: 'Thank you for booking ${widget.selectedService.name} at ${widget.venueName} on $formattedTime. A staff member will be assigned to you shortly.',
          notificationType: 'booking_confirmation',
          data: {
            'appointmentId': appointmentRef.id,
            'notificationType': 'booking_confirmation',
            'status': 'pending',
          },
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
            role: 'floor_manager',
            assignedToId: floorManagerUid,
            title: 'New Appointment Request',
            body: 'Minister ${ministerData['firstName'] ?? ''} ${ministerData['lastName'] ?? ''} has requested an appointment',
            notificationType: 'new_appointment',
            data: notificationData,
          );
        }
        print('Notifications sent successfully');
      } catch (e) {
        print('Error sending notifications: $e');
        // Continue with booking even if notification fails
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
          style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold),
        ),
        iconTheme: IconThemeData(color: AppColors.gold),
      ),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppColors.gold)))
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
                            border: Border.all(color: AppColors.gold, width: 1),
                          ),
                          child: Icon(Icons.spa, color: AppColors.gold, size: 24),
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
                                style: TextStyle(color: AppColors.gold, fontSize: 14),
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
                              border: Border.all(color: AppColors.gold.withOpacity(0.5)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today, color: AppColors.gold, size: 20),
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
                              border: Border.all(color: AppColors.gold.withOpacity(0.5)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.location_on, color: AppColors.gold, size: 20),
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
                    Icon(Icons.access_time, color: AppColors.gold, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Available Time Slots',
                      style: TextStyle(
                        color: AppColors.gold,
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
                          Icon(Icons.event_busy, color: AppColors.gold, size: 64),
                          const SizedBox(height: 16),
                          Text(
                            'Closed on this day',
                            style: TextStyle(color: AppColors.gold, fontSize: 16),
                          ),
                          const SizedBox(height: 24),
                          OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: AppColors.gold),
                              foregroundColor: AppColors.gold,
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
                            Icon(Icons.event_busy, color: AppColors.gold, size: 64),
                            const SizedBox(height: 16),
                            Text(
                              'No time slots available for this date',
                              style: TextStyle(color: AppColors.gold, fontSize: 16),
                            ),
                            const SizedBox(height: 24),
                            OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: AppColors.gold),
                                foregroundColor: AppColors.gold,
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
                                            border: Border.all(color: AppColors.gold.withOpacity(0.7)),
                                          ),
                                          child: Text(
                                            '$timeOfDay',
                                            style: TextStyle(color: AppColors.gold, fontSize: 12),
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
                                                  : AppColors.gold,
                                              ),
                                              boxShadow: isDisabled ? [] : [
                                                BoxShadow(
                                                  color: AppColors.gold.withOpacity(0.2),
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
                                                      : AppColors.gold,
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
              
              // Booking indicator
              if (_isBooking)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  color: Colors.black,
                  child: Column(
                    children: [
                      const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.amber)),
                      const SizedBox(height: 16),
                      Text(
                        'Confirming your appointment...',
                        style: TextStyle(color: AppColors.gold, fontSize: 16),
                      ),
                    ],
                  ),
                ),
            ],
          ),
    );
  }

  Future<void> _fetchClosedDaysAndHours() async {
    final doc = await FirebaseFirestore.instance.collection('business').doc('settings').get();
    final data = doc.data();
    if (data != null) {
      // Closed days
      if (data['closedDays'] != null) {
        final List<dynamic> days = data['closedDays'];
        setState(() {
          _closedDaysSet = days.map((e) => e.toString()).toSet();
        });
      }
      // Business hours (per day)
      if (data['businessHours'] != null) {
        final bh = data['businessHours'] as Map<String, dynamic>;
        setState(() {
          _businessHoursMap = bh;
        });
      }
      // Default opening/closing from settings (for buffer fallback)
      if (data['defaultBusinessHours'] != null) {
        setState(() {
          _defaultBusinessHours = data['defaultBusinessHours'] as Map<String, dynamic>;
        });
      }
    }
  }
}
