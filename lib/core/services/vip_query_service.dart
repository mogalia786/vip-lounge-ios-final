import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'package:vip_lounge/core/services/vip_notification_service.dart';

class VipQueryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Generates a random uppercase alphanumeric string of [length].
  String generateReferenceNumber({int length = 5}) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random.secure();
    return List.generate(length, (index) => chars[rand.nextInt(chars.length)]).join();
  }

  /// Submits a new minister query to Firestore and notifies the floor manager.
  Future<String> submitMinisterQuery({
    required String ministerId,
    required String ministerFirstName,
    required String ministerLastName,
    required String ministerEmail,
    required String ministerPhone,
    required String subject,
    required String queryText,
  }) async {
    final refNumber = generateReferenceNumber();
    final createdAt = Timestamp.now();

    final queryDoc = {
      'referenceNumber': refNumber,
      'ministerId': ministerId,
      'ministerFirstName': ministerFirstName,
      'ministerLastName': ministerLastName,
      'ministerEmail': ministerEmail,
      'ministerPhone': ministerPhone,
      'subject': subject,
      'query': queryText,
      'status': 'pending',
      'assignedTo': null,
      'assignedToName': null,
      'createdAt': createdAt,
      'statusHistory': [
        {
          'status': 'pending',
          'by': ministerId,
          'byName': '$ministerFirstName $ministerLastName',
          'timestamp': createdAt,
          'note': 'Query submitted',
        }
      ],
    };

    // Add to Firestore
    final docRef = await _firestore.collection('queries').add(queryDoc);

    // Notify floor manager(s)
    // Find all users with role == 'floor_manager'
    final floorManagers = await _firestore.collection('users').where('role', isEqualTo: 'floor_manager').get();
    for (final doc in floorManagers.docs) {
      final fm = doc.data();
      await VipNotificationService().createNotification(
        title: 'New Minister Query',
        body: 'Query from $ministerFirstName $ministerLastName: $subject',
        data: {
          'referenceNumber': refNumber,
          'ministerId': ministerId,
          'ministerFirstName': ministerFirstName,
          'ministerLastName': ministerLastName,
          'ministerEmail': ministerEmail,
          'ministerPhone': ministerPhone,
          'subject': subject,
          'query': queryText,
          'createdAt': createdAt,
        },
        role: 'floor_manager',
        assignedToId: doc.id,
        notificationType: 'minister_query',
      );
    }
    return refNumber;
  }

  /// Updates the status of a query and notifies the minister.
  Future<void> updateQueryStatus({
    required String queryId,
    required String newStatus,
    required String staffUid,
    required String staffName,
    String? note,
  }) async {
    final docRef = _firestore.collection('queries').doc(queryId);
    final docSnap = await docRef.get();
    if (!docSnap.exists) throw Exception('Query not found');
    final data = docSnap.data() as Map<String, dynamic>;
    final ministerId = data['ministerId'] as String?;
    final ministerFirstName = data['ministerFirstName'] ?? '';
    final ministerLastName = data['ministerLastName'] ?? '';
    final subject = data['subject'] ?? '';
    final now = Timestamp.now();
    // Update query status and history
    await docRef.update({
      'status': newStatus,
      'assignedTo': staffUid,
      'assignedToName': staffName,
      'statusHistory': FieldValue.arrayUnion([
        {
          'status': newStatus,
          'by': staffUid,
          'byName': staffName,
          'timestamp': now,
          'note': note ?? '',
        }
      ]),
    });
    // Notify the minister
    if (ministerId != null && ministerId.isNotEmpty) {
      await VipNotificationService().createNotification(
        title: 'Query Status Updated',
        body: 'Your query "$subject" status changed to $newStatus.',
        data: {
          'referenceNumber': data['referenceNumber'] ?? '',
          'ministerId': ministerId,
          'ministerFirstName': ministerFirstName,
          'ministerLastName': ministerLastName,
          'subject': subject,
          'status': newStatus,
          'updatedBy': staffName,
          'updatedAt': now,
        },
        role: 'minister',
        assignedToId: ministerId,
        notificationType: 'query_status_update',
      );
    }
  }
}
