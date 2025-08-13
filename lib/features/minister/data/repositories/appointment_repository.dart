import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform, kIsWeb;
import 'package:vip_lounge/core/services/ios_calendar_service.dart';
import '../models/appointment.dart';
import '../../../../core/constants/service_options.dart';

class AppointmentRepository {
  final FirebaseFirestore _firestore;
  final FirebaseMessaging _messaging;

  AppointmentRepository({
    FirebaseFirestore? firestore,
    FirebaseMessaging? messaging,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _messaging = messaging ?? FirebaseMessaging.instance;

  Future<bool> isSlotAvailable(
    DateTime startTime,
    DateTime endTime,
    String venueId,
  ) async {
    try {
      final appointments = await _firestore
          .collection('appointments')
          .where('venueId', isEqualTo: venueId)
          .where('startTime', isLessThanOrEqualTo: endTime)
          .where('endTime', isGreaterThanOrEqualTo: startTime)
          .where('status', whereIn: ['pending', 'confirmed'])
          .get();

      return appointments.docs.isEmpty;
    } catch (e) {
      print('Error checking slot availability: $e');
      return false;
    }
  }

  Future<void> blockTimeSlot(
    DateTime startTime,
    String venueId,
    int durationMinutes,
  ) async {
    try {
      final endTime = startTime.add(Duration(minutes: durationMinutes));
      
      // Double-check availability before blocking
      final isAvailable = await isSlotAvailable(startTime, endTime, venueId);
      if (!isAvailable) {
        throw Exception('Time slot is no longer available');
      }

      // Create a temporary block
      await _firestore.collection('appointments').add({
        'venueId': venueId,
        'startTime': startTime,
        'endTime': endTime,
        'status': 'blocked',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error blocking time slot: $e');
      throw Exception('Failed to block time slot');
    }
  }

  Future<void> createAppointment({
    required String ministerUid,
    required String ministerName,
    required ServiceCategory category,
    required Service service,
    SubService? subService,
    required VenueType venue,
    required DateTime startTime,
    String? notes,
  }) async {
    try {
      // Calculate end time based on service duration and venue cleaning buffer
      final serviceDuration = Duration(
        minutes: subService?.maxDuration ?? service.maxDuration,
      );
      final cleaningBuffer = Duration(minutes: venue.cleaningBuffer);
      final endTime = startTime.add(serviceDuration).add(cleaningBuffer);

      // Check if slot is available
      final isAvailable = await isSlotAvailable(startTime, endTime, venue.id);
      if (!isAvailable) {
        throw Exception('Selected time slot is not available');
      }

      // Create the appointment
      final appointment = Appointment(
        id: '', // Will be set by Firestore
        ministerUid: ministerUid,
        ministerName: ministerName,
        category: category.name,
        service: service.name,
        subService: subService?.name,
        venue: venue.name,
        venueId: venue.id,
        startTime: startTime,
        endTime: endTime,
        notes: notes,
        status: 'pending',
        createdAt: DateTime.now(),
      );

      // Save to Firestore
      final docRef = await _firestore
          .collection('appointments')
          .add(appointment.toMap());

      // Update the appointment with its ID
      await docRef.update({'id': docRef.id});

      // iOS only: add event to user's calendar via EventKit
      try {
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
          final calendar = IOSCalendarService();
          final added = await calendar.addBookingToCalendar(
            title: 'VIP Lounge: ${service.name}${subService != null ? ' - ${subService.name}' : ''}',
            start: startTime,
            end: endTime,
            location: venue.name,
            description: 'Minister: $ministerName\nNotes: ${notes ?? ''}',
          );
          if (!added) {
            // ignore: avoid_print
            print('[Calendar][iOS] Event insert failed or skipped');
          }
        }
      } catch (e) {
        // ignore: avoid_print
        print('[Calendar][iOS] Error adding to calendar: $e');
      }

      // Get admin FCM tokens
      final adminTokens = await _getAdminFcmTokens();

      // Send FCM notifications to admins (Android only)
      for (final token in adminTokens) {
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
          await _messaging.sendMessage(
            to: token,
            data: {
              'type': 'new_appointment',
              'appointmentId': docRef.id,
            },
            messageId: docRef.id,
          );
        } else {
          // iOS/web: skip SDK send; rely on server/Cloud Function
          // ignore: avoid_print
          print('[FCM] sendMessage skipped on this platform (iOS/web). Token=$token');
        }
      }
    } catch (e) {
      print('Error creating appointment: $e');
      throw e;
    }
  }

  Future<void> updateAppointmentStatus(
    String appointmentId,
    String newStatus,
  ) async {
    try {
      await _firestore.collection('appointments').doc(appointmentId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // If appointment is confirmed, notify the minister
      if (newStatus == 'confirmed') {
        final appointment = await _firestore
            .collection('appointments')
            .doc(appointmentId)
            .get();

        if (appointment.exists) {
          final data = appointment.data()!;
          final ministerUid = data['ministerUid'] as String;
          final ministerToken = await _getMinisterFcmToken(ministerUid);

          if (ministerToken != null) {
            if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
              await _messaging.sendMessage(
                to: ministerToken,
                data: {
                  'type': 'appointment_confirmed',
                  'appointmentId': appointmentId,
                },
                messageId: '${appointmentId}_confirmed',
              );
            } else {
              // iOS/web: skip SDK send; rely on server/Cloud Function
              // ignore: avoid_print
              print('[FCM] sendMessage skipped on this platform (iOS/web). Token=$ministerToken');
            }
          }
        }
      }
    } catch (e) {
      print('Error updating appointment status: $e');
      throw e;
    }
  }

  Future<String?> _getMinisterFcmToken(String ministerUid) async {
    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(ministerUid)
          .get();

      if (userDoc.exists) {
        return userDoc.data()?['fcmToken'] as String?;
      }
      return null;
    } catch (e) {
      print('Error getting minister FCM token: $e');
      return null;
    }
  }

  Future<List<String>> _getAdminFcmTokens() async {
    try {
      final adminTokensDoc = await _firestore.collection('admin_tokens').get();
      return adminTokensDoc.docs.map((doc) => doc['token'] as String).toList();
    } catch (e) {
      print('Error getting admin FCM tokens: $e');
      return [];
    }
  }

  Stream<List<Appointment>> getMinisterAppointments(String ministerUid) {
    return _firestore
        .collection('appointments')
        .where('ministerUid', isEqualTo: ministerUid)
        .orderBy('startTime', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Appointment.fromFirestore(doc)).toList());
  }

  Future<void> assignConsultant(
    String appointmentId,
    String consultantId,
  ) async {
    await _firestore.collection('appointments').doc(appointmentId).update({
      'assignedConsultantId': consultantId,
      'status': 'confirmed',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
