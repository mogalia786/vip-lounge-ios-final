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

class AppointmentBookingScreen extends StatefulWidget {
  const AppointmentBookingScreen({super.key});

  @override
  State<AppointmentBookingScreen> createState() => _AppointmentBookingScreenState();
}

class _AppointmentBookingScreenState extends State<AppointmentBookingScreen> {
  ServiceCategory? _selectedCategory;
  Service? _selectedService;
  SubService? _selectedSubService;
  VenueType? _selectedVenue;
  bool _isBooking = false;

  final NotificationService _notificationService = NotificationService();

  final _borderRadius = const BorderRadius.all(Radius.circular(12));

  OutlineInputBorder _buildBorder({double width = 1.0}) {
    return OutlineInputBorder(
      borderRadius: _borderRadius,
      borderSide: BorderSide(color: AppColors.gold, width: width),
    );
  }

  void _handleBookAppointment(DateTime selectedTime) async {
    if (_selectedService == null || _selectedVenue == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a service and venue')),
      );
      return;
    }

    setState(() => _isBooking = true);

    try {
      final authProvider = Provider.of<AppAuthProvider>(context, listen: false);

      if (authProvider.ministerData == null) {
        throw Exception('Minister data not found');
      }

      print('Using minister data for booking: ${authProvider.ministerData}'); // Debug print

      // Get all floor manager UIDs early in the booking process
      final floorManagerQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'floorManager')
          .get();
      final floorManagerUids = floorManagerQuery.docs
          .map((doc) => doc.data()['uid'] as String?)
          .where((uid) => uid != null && uid.isNotEmpty)
          .cast<String>()
          .toList();
      print('Floor Manager UIDs: ' + floorManagerUids.join(', '));

      // Create appointment data
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
        'duration': _selectedSubService?.maxDuration ?? _selectedService!.maxDuration,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        // Optionally, store the first floor manager's ID for reference
        'assignedFloorManagerId': floorManagerUids.isNotEmpty ? floorManagerUids.first : null,
      };

      print('Creating appointment with data: $appointmentData');

      // Create the appointment
      final appointmentRef = await FirebaseFirestore.instance
          .collection('appointments')
          .add(appointmentData);

      // Add the appointmentId to the data for notifications
      final notificationData = Map<String, dynamic>.from(appointmentData);
      notificationData['appointmentId'] = appointmentRef.id;
      // Also add all floor manager UIDs for downstream logic if needed
      notificationData['floorManagerUids'] = floorManagerUids;

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
        };
        
        // Create notification in Firestore for each floor manager
        for (var floorManagerUid in floorManagerUids) {
          print('DEBUG: Creating notification for floor manager. assignedToId: $floorManagerUid, receiverId: $floorManagerUid');
          await FirebaseFirestore.instance.collection('notifications').add({
            ...cleanNotificationData,
            'assignedToId': floorManagerUid,
            'receiverId': floorManagerUid,
          });
        }
        print('Notification(s) created for all floor managers in Firestore');
        
        // Also send through the notification service for FCM
        // Make a copy with only string values for FCM
        final fcmData = {
          'appointmentId': appointmentRef.id,
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
      setState(() => _isBooking = false);

      if (!mounted) return;

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
        textStyle: TextStyle(color: AppColors.gold),
      ),
    );

    final dropdownDecoration = InputDecoration(
      filled: true,
      fillColor: Colors.black,
    );

    final dropdownStyle = TextStyle(color: AppColors.gold);
    final dropdownIcon = Icon(Icons.arrow_drop_down, color: AppColors.gold);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Book Appointment',
              style: TextStyle(color: AppColors.gold),
            ),
            if (authProvider.ministerData != null)
              Text(
                'Welcome, Minister ${authProvider.ministerData!['firstName']} ${authProvider.ministerData!['lastName']}',
                style: TextStyle(color: AppColors.gold, fontSize: 14),
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
