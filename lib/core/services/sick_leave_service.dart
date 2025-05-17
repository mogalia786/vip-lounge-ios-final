import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/sick_leave.dart';

class SickLeaveService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Submit a sick leave request and notify the Floor Manager
  Future<void> submitSickLeave({
    required String userId,
    required String role,
    required DateTime startDate,
    required DateTime endDate,
    required String userName,
  }) async {
    // Create sick leave record
    final sickLeaveRef = await _firestore.collection('sick_leaves').add({
      'userId': userId,
      'role': role,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Notify all floor managers
    final floorManagers = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'floor_manager')
        .get();
    for (var doc in floorManagers.docs) {
      await _firestore.collection('notifications').add({
        'title': 'Sick Leave Request',
        'body': '$userName ($role) has requested sick leave from ${startDate.toLocal()} to ${endDate.toLocal()}.',
        'type': 'sickleave',
        'assignedToId': doc.id,
        'userId': userId,
        'role': role,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'sendAsPushNotification': true,
      });
    }

    // --- NEW: Notify floor manager of all affected appointments for re-assignment ---
    // Find all appointments for this user in the leave period (future or ongoing)
    final appointmentsQuery = await _firestore
        .collection('appointments')
        .where(role == 'consultant' ? 'consultantId' : 'conciergeId', isEqualTo: userId)
        .where('appointmentTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('appointmentTime', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .get();
    for (final appt in appointmentsQuery.docs) {
      final apptData = appt.data();
      for (var doc in floorManagers.docs) {
        await _firestore.collection('notifications').add({
          'title': 'Staff Sick Leave - Reassignment Needed',
          'body': '$userName ($role) cannot attend appointment on '
              + (apptData['appointmentTime'] is Timestamp ? (apptData['appointmentTime'] as Timestamp).toDate().toString() : '')
              + '. Please re-assign.',
          'type': 'reassign_required',
          'assignedToId': doc.id,
          'appointmentId': appt.id,
          'appointmentData': apptData,
          'sickUserId': userId,
          'sickRole': role,
          'status': 'pending',
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
          'sendAsPushNotification': true,
        });
      }
    }
  }

  /// Get all sick leaves for a user
  Future<List<SickLeave>> getUserSickLeaves(String userId) async {
    final query = await _firestore
        .collection('sick_leaves')
        .where('userId', isEqualTo: userId)
        .orderBy('startDate', descending: true)
        .get();
    return query.docs.map((doc) => SickLeave.fromDoc(doc)).toList();
  }

  /// Get all approved sick leaves for a date range (for exclusion in assignment)
  Future<List<SickLeave>> getSickLeavesForRange(DateTime date, String role) async {
    final query = await _firestore
        .collection('sick_leaves')
        .where('role', isEqualTo: role)
        .where('status', isEqualTo: 'approved')
        .where('startDate', isLessThanOrEqualTo: Timestamp.fromDate(date))
        .where('endDate', isGreaterThanOrEqualTo: Timestamp.fromDate(date))
        .get();
    return query.docs.map((doc) => SickLeave.fromDoc(doc)).toList();
  }
}
