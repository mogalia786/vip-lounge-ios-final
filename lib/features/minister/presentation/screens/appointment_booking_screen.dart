import 'dart:math';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../../core/constants/service_options.dart';
import '../../../../core/providers/app_auth_provider.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/services/notification_service.dart';
import '../widgets/time_slot_calendar.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../../../core/services/ios_calendar_channel.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdb;

class AppointmentBookingScreen extends StatefulWidget {
  const AppointmentBookingScreen({super.key});

  @override
  State<AppointmentBookingScreen> createState() => _AppointmentBookingScreenState();
}

class _AppointmentBookingScreenState extends State<AppointmentBookingScreen> {
  final NotificationService _notificationService = NotificationService();
  bool _isBooking = false;
  static bool _tzInitialized = false;

  void _ensureTimezoneInitialized() {
    if (_tzInitialized) return;
    try {
      tzdb.initializeTimeZones();
      // Note: tz.local defaults to UTC if not explicitly set.
      // If needed, set a specific location with:
      // tz.setLocalLocation(tz.getLocation('Africa/Johannesburg'));
    } catch (_) {
      // Safe to ignore; tz will still function with UTC.
    }
    _tzInitialized = true;
  }

  // Generate a random 5-character alphanumeric reference number
  String _generateReferenceNumber() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return List.generate(5, (index) => chars[random.nextInt(chars.length)]).join();
  }

  Future<void> testMinimalFirestoreWrite() async {
    final now = DateTime.now();
    final testData = {
      'testString': 'hello world',
      'testTimestamp': Timestamp.fromDate(now.toUtc()),
      'testIso': now.toUtc().toIso8601String(),
    };
    print('DEBUG: testData to be saved => $testData');
    await FirebaseFirestore.instance.collection('test_appointments').add(testData);
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
    
    // Get appointment data from current selections
    final serviceName = _selectedService!.name;
    final venueName = _selectedVenue!.name;
    final duration = _selectedSubService?.maxDuration ?? _selectedService!.maxDuration;
    final subServiceName = _selectedSubService?.name;
    
    print('🔥 Appointment data from selections:');
    print('🔥 - serviceName: $serviceName');
    print('🔥 - venueName: $venueName');
    print('🔥 - duration: $duration');
    print('🔥 - subServiceName: $subServiceName');
    
    try {
      print('🔥 STEP 1: Calculating event details...');
      
      // Calculate end time
      final endTime = appointmentTime.add(Duration(minutes: duration));
      
      // Create event details
      final eventTitle = subServiceName != null 
          ? '$serviceName - $subServiceName'
          : serviceName;
      
      final eventDescription = 'VIP Lounge Appointment\n\n'
          'Service: $serviceName\n'
          '${subServiceName != null ? 'Sub-Service: $subServiceName\n' : ''}'
          'Venue: $venueName\n'
          'Reference: $referenceNumber\n\n'
          'Please arrive 15 minutes early.';
      
      print('📅 STEP 2: Event details calculated:');
      print('📅 - Title: $eventTitle');
      print('📅 - Start: $appointmentTime');
      print('📅 - End: $endTime');
      print('📅 - Location: $venueName');
      print('📅 - Description length: ${eventDescription.length} chars');
      
      print('📅 STEP 3: Preparing platform-specific calendar flow...');

      if (Platform.isIOS) {
        // Use native EventKit bridge via MethodChannel
        print('🍏 iOS: Using native EventKit bridge');
        final ok = await IOSCalendarChannel.addEvent(
          title: eventTitle,
          description: eventDescription,
          location: venueName,
          start: appointmentTime,
          end: endTime,
          reminderMinutes: 15,
        );
        if (ok) {
          print('✅ iOS: Event saved via EventKit');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('📅 Event added to your calendar'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 3),
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('❌ Could not add event to calendar'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      } else {
        // Non-iOS platforms: show fallback (this Mac build targets iOS only)
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Calendar integration is available on iOS only in this build.'),
              backgroundColor: Colors.blueGrey,
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

  
  // Show fallback message when calendar integration fails
  void _showCalendarFallback() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Appointment booked successfully. Please manually add it to your calendar.'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  ServiceCategory? _selectedCategory;
  Service? _selectedService;
  SubService? _selectedSubService;
  VenueType? _selectedVenue;

  final _borderRadius = const BorderRadius.all(Radius.circular(12));

  OutlineInputBorder _buildBorder({double width = 1.0}) {
    return OutlineInputBorder(
      borderRadius: _borderRadius,
      borderSide: BorderSide(color: AppColors.primary, width: width),
    );
  }

  void _handleBookAppointment(DateTime selectedTime) async {
    print('🚀🚀🚀 BOOKING METHOD CALLED 🚀🚀🚀');
    print('🚀 Selected Time: $selectedTime');
    print('🚀 Selected Service: ${_selectedService?.name}');
    print('🚀 Selected Venue: ${_selectedVenue?.name}');
    
    if (_selectedService == null || _selectedVenue == null) {
      print('🚀 ❌ Missing service or venue - aborting booking');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a service and venue')),
      );
      return;
    }

    print('🚀 ✅ All validations passed - proceeding with booking');
    setState(() => _isBooking = true);

    try {
      final authProvider = Provider.of<AppAuthProvider>(context, listen: false);

      if (authProvider.ministerData == null) {
        throw Exception('Minister data not found');
      }

      print('Using minister data for booking: ${authProvider.ministerData}'); // Debug print

      // Fetch the single floor manager's ID and name from users collection
      final floorManagerQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'floorManager')
          .limit(1)
          .get();
      String floorManagerId = '';
      String floorManagerName = '';
      if (floorManagerQuery.docs.isNotEmpty) {
        final floorManagerDoc = floorManagerQuery.docs.first;
        floorManagerId = (floorManagerDoc.data()['uid'] ?? '').toString();
        final firstName = (floorManagerDoc.data()['firstName'] ?? '').toString();
        final lastName = (floorManagerDoc.data()['lastName'] ?? '').toString();
        floorManagerName = (firstName + ' ' + lastName).trim();
      }
      // Fallback in case not found
      if (floorManagerId.isEmpty) floorManagerId = 'FLOOR_MANAGER_NOT_FOUND';
      if (floorManagerName.isEmpty) floorManagerName = 'Unknown Floor Manager';
      print('DEBUG: floorManagerId to be written: $floorManagerId, floorManagerName: $floorManagerName');

      // Create appointment data
      // Ensure floor manager fields are always present
      print('DEBUG: About to write appointment with floorManagerId: ' + floorManagerId + ', floorManagerName: ' + floorManagerName);
      final referenceNumber = _generateReferenceNumber();
      final appointmentData = {
        'ministerId': authProvider.ministerData!['uid'],
        'ministerFirstName': authProvider.ministerData!['firstName'],
        'ministerLastName': authProvider.ministerData!['lastName'],
        'ministerEmail': authProvider.ministerData!['email'],
        'ministerPhone': authProvider.ministerData!['phoneNumber'] ?? 'Not provided',
        'serviceId': _selectedService!.id,
        'serviceName': _selectedService!.name,
        'serviceCategory': _selectedCategory?.name ?? '',
        'subServiceName': _selectedSubService?.name ?? '',
        'venueId': _selectedVenue!.id,
        'venueName': _selectedVenue!.name,
        'appointmentTime': selectedTime.toIso8601String(),
        'appointmentTimeUTC': Timestamp.fromDate(selectedTime.toUtc()),
        'duration': _selectedSubService?.maxDuration ?? _selectedService!.maxDuration,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'floorManagerId': floorManagerId,
        'floorManagerName': floorManagerName,
        'typeOfVip': 'VIP Client',
        'referenceNumber': referenceNumber, // Add reference number to appointment
      };
      print('DEBUG: appointmentData to be saved (should include floorManagerId/floorManagerName): $appointmentData');

      print('DEBUG: appointmentData to be saved => $appointmentData');



      // Create the appointment
      final appointmentRef = await FirebaseFirestore.instance
          .collection('appointments')
          .add(appointmentData);

      print('💾💾💾 APPOINTMENT SAVED TO FIRESTORE 💾💾💾');
      print('💾 Appointment ID: ${appointmentRef.id}');
      print('💾 Reference Number: $referenceNumber');

      // 🔥 ADD TO CALENDAR IMMEDIATELY AFTER FIRESTORE SAVE
      print('🔥🔥🔥 STARTING CALENDAR INTEGRATION 🔥🔥🔥');
      try {
        await _addAppointmentToCalendar(
          selectedTime,
          referenceNumber,
        );
        print('🔥🔥🔥 CALENDAR INTEGRATION COMPLETED 🔥🔥🔥');
      } catch (calendarError) {
        print('🔥 CALENDAR INTEGRATION ERROR: $calendarError');
        // Don't fail the booking if calendar fails
      }

      // Add the appointmentId to the data for notifications
      final notificationData = Map<String, dynamic>.from(appointmentData);
      notificationData['appointmentId'] = appointmentRef.id;

      try {
        print('Creating notification for floor manager directly in Firestore...');

        // Create a clean version of the notification data with string values for timestamps
        final cleanNotificationData = {
          'title': 'New Appointment Request',
          'body': 'Minister ${authProvider.ministerData!['firstName']} ${authProvider.ministerData!['lastName']} has requested an appointment',
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
          'role': 'floor_manager',
          'type': 'new_appointment', // Add a type field for better filtering
          'appointmentId': appointmentRef.id,
          'referenceNumber': referenceNumber, // Add reference number to notification
          'ministerId': authProvider.ministerData!['uid'],
          'ministerFirstName': authProvider.ministerData!['firstName'],
          'ministerLastName': authProvider.ministerData!['lastName'],
          'ministerEmail': authProvider.ministerData!['email'],
          'ministerPhone': authProvider.ministerData!['phoneNumber'] ?? '',
          'serviceId': _selectedService!.id,
          'serviceName': _selectedService!.name,
          'serviceCategory': _selectedCategory?.name ?? '',
          'subServiceName': _selectedSubService?.name,
          'venueId': _selectedVenue!.id,
          'venueName': _selectedVenue!.name,
          'appointmentTimeISO': selectedTime.toIso8601String(), // Add string version
          'appointmentTime': Timestamp.fromDate(selectedTime),
          'duration': _selectedService!.maxDuration,
          'status': 'pending',
          'sendAsPushNotification': true,
          'timestamp': FieldValue.serverTimestamp(),
          'assignedToId': floorManagerId,
          'receiverId': floorManagerId,
        };

        // Create notification in Firestore for the single floor manager
        print('DEBUG: Creating notification for floor manager. assignedToId: $floorManagerId, receiverId: $floorManagerId');
        await FirebaseFirestore.instance.collection('notifications').add(cleanNotificationData);
        print('Notification created for floor manager in Firestore');

        // Also send through the notification service for FCM
        // Make a copy with only string values for FCM
        final fcmData = {
          'appointmentId': appointmentRef.id,
          'referenceNumber': referenceNumber, // Add reference number to FCM data
          'type': 'new_appointment',
          'ministerId': authProvider.ministerData!['uid'],
          'ministerFirstName': authProvider.ministerData!['firstName'],
          'ministerLastName': authProvider.ministerData!['lastName'],
          'appointmentTimeISO': selectedTime.toIso8601String(),
          'serviceName': _selectedService!.name,
          'venueName': _selectedVenue!.name,
        };
        
        await _notificationService.sendFCMToFloorManager(
          title: 'New Appointment Request',
          body: 'Minister ${authProvider.ministerData!['firstName']} ${authProvider.ministerData!['lastName']} has requested an appointment',
          data: fcmData,
        );
        print('Also sent through FCM service');
      } catch (e) {
        print('Error sending notifications: $e');
      }

      print('💾💾💾 FIRESTORE SAVE COMPLETED 💾💾💾');
      print('💾 Appointment saved with ID: ${appointmentRef.id}');
      print('💾 Reference Number: $referenceNumber');
      print('💾 Now proceeding to calendar integration...');

      // Calendar integration already called above after Firestore save - no duplicate needed

      // Reset selections
      setState(() {
        _selectedCategory = null;
        _selectedService = null;
        _selectedSubService = null;
        _selectedVenue = null;
        _isBooking = false;
      });

      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Appointment booked successfully'),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate back
      Navigator.pop(context);
    } catch (e) {
      print('Error booking appointment: $e');
      
      if (!mounted) return;
      
      setState(() => _isBooking = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AppAuthProvider>(context);

    print('AppointmentBookingScreen - Minister Data: ${authProvider.ministerData}'); // Debug print

    final dropdownTheme = Theme.of(context).copyWith(
      inputDecorationTheme: InputDecorationTheme(
        border: _buildBorder(),
        enabledBorder: _buildBorder(),
        focusedBorder: _buildBorder(width: 2),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: TextStyle(color: AppColors.primary),
      ),
    );

    final dropdownDecoration = InputDecoration(
      filled: true,
      fillColor: Colors.black,
    );

    final dropdownStyle = TextStyle(color: AppColors.primary);
    final dropdownIcon = Icon(Icons.arrow_drop_down, color: AppColors.primary);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        actions: [],
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Book Appointment',
              style: TextStyle(color: AppColors.primary),
            ),
            if (authProvider.ministerData != null)
              Text(
                'Welcome, VIP ${authProvider.ministerData!['firstName']} ${authProvider.ministerData!['lastName']}',
                style: TextStyle(color: AppColors.primary, fontSize: 14),
              ),
          ],
        ),
      ),
      body: _isBooking
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (authProvider.ministerData == null)
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'Please log in to book appointments',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    else ...[
                      Theme(
                        data: dropdownTheme,
                        child: DropdownButtonFormField<ServiceCategory>(
                          value: _selectedCategory,
                          hint: Text('Select Category', style: dropdownStyle),
                          icon: dropdownIcon,
                          dropdownColor: Colors.black,
                          style: dropdownStyle,
                          decoration: dropdownDecoration,
                          items: serviceCategories.map((category) {
                            return DropdownMenuItem(
                              value: category,
                              child: Text(category.name),
                            );
                          }).toList(),
                          onChanged: (category) {
                            setState(() {
                              _selectedCategory = category;
                              _selectedService = null;
                              _selectedSubService = null;
                              _selectedVenue = null;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 16),

                      if (_selectedCategory != null) ...[
                        Theme(
                          data: dropdownTheme,
                          child: DropdownButtonFormField<Service>(
                            value: _selectedService,
                            hint: Text('Select Service', style: dropdownStyle),
                            icon: dropdownIcon,
                            dropdownColor: Colors.black,
                            style: dropdownStyle,
                            decoration: dropdownDecoration,
                            items: _selectedCategory!.services.map((service) {
                              return DropdownMenuItem(
                                value: service,
                                child: Text(service.name),
                              );
                            }).toList(),
                            onChanged: (service) {
                              setState(() {
                                _selectedService = service;
                                _selectedSubService = null;
                                _selectedVenue = null;
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      if (_selectedService != null &&
                          _selectedService!.subServices.isNotEmpty) ...[
                        Theme(
                          data: dropdownTheme,
                          child: DropdownButtonFormField<SubService>(
                            value: _selectedSubService,
                            hint: Text('Select Sub-Service', style: dropdownStyle),
                            icon: dropdownIcon,
                            dropdownColor: Colors.black,
                            style: dropdownStyle,
                            decoration: dropdownDecoration,
                            items: _selectedService!.subServices.map((subService) {
                              return DropdownMenuItem(
                                value: subService,
                                child: Text(subService.name),
                              );
                            }).toList(),
                            onChanged: (subService) {
                              setState(() {
                                _selectedSubService = subService;
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      if (_selectedService != null) ...[
                        Theme(
                          data: dropdownTheme,
                          child: DropdownButtonFormField<VenueType>(
                            value: _selectedVenue,
                            hint: Text('Select Venue', style: dropdownStyle),
                            icon: dropdownIcon,
                            dropdownColor: Colors.black,
                            style: dropdownStyle,
                            decoration: dropdownDecoration,
                            items: venueTypes.map((venue) {
                              return DropdownMenuItem(
                                value: venue,
                                child: Text(venue.name),
                              );
                            }).toList(),
                            onChanged: (venue) {
                              setState(() {
                                _selectedVenue = venue;
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      if (_selectedService != null && _selectedVenue != null)
                        TimeSlotCalendar(
                          selectedService: _selectedService!,
                          selectedVenue: _selectedVenue!,
                          serviceCategory: _selectedCategory!.name,
                          subServiceName: _selectedSubService?.name,
                          onTimeSelected: _handleBookAppointment,
                        ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}
