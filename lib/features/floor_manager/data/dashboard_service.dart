import 'package:cloud_firestore/cloud_firestore.dart';

class DashboardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get count of unassigned queries
  Stream<int> getUnassignedQueriesCount() {
    return _firestore
        .collection('queries')
        .where('status', isNotEqualTo: 'resolved')
        .where('assignedToId', isNull: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Get count of overdue queries (older than 30 minutes)
  Stream<int> getOverdueQueriesCount() {
    final thirtyMinutesAgo = DateTime.now().subtract(const Duration(minutes: 30));
    
    return _firestore
        .collection('queries')
        .where('status', isNotEqualTo: 'resolved')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final createdAt = data['createdAt'] as Timestamp?;
            if (createdAt == null) return false;
            return createdAt.toDate().isBefore(thirtyMinutesAgo);
          }).length;
        });
  }

  // Get count of unassigned appointments
  Stream<int> getUnassignedAppointmentsCount() {
    return _firestore
        .collection('appointments')
        .where('status', isEqualTo: 'pending')
        .where('consultantId', isNull: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Search queries by reference number
  Stream<QuerySnapshot> searchQueries(String referenceNumber) {
    if (referenceNumber.isEmpty) {
      return const Stream.empty();
    }
    return _firestore
        .collection('queries')
        .where('referenceNumber', isGreaterThanOrEqualTo: referenceNumber)
        .where('referenceNumber', isLessThanOrEqualTo: referenceNumber + '\uf8ff')
        .snapshots();
  }

  // Search appointments by reference number
  Stream<QuerySnapshot> searchAppointments(String referenceNumber) {
    if (referenceNumber.isEmpty) {
      return const Stream.empty();
    }
    return _firestore
        .collection('appointments')
        .where('referenceNumber', isGreaterThanOrEqualTo: referenceNumber)
        .where('referenceNumber', isLessThanOrEqualTo: referenceNumber + '\uf8ff')
        .snapshots();
  }

  // Get unassigned queries
  Stream<QuerySnapshot> getUnassignedQueries() {
    return _firestore
        .collection('queries')
        .where('status', isNotEqualTo: 'resolved')
        .where('assignedToId', isNull: true)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Get overdue queries
  Stream<QuerySnapshot> getOverdueQueries() {
    final thirtyMinutesAgo = DateTime.now().subtract(const Duration(minutes: 30));
    
    return _firestore
        .collection('queries')
        .where('status', isNotEqualTo: 'resolved')
        .orderBy('createdAt')
        .snapshots()
        .map((snapshot) {
          final filteredDocs = snapshot.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final createdAt = data['createdAt'] as Timestamp?;
            if (createdAt == null) return false;
            return createdAt.toDate().isBefore(thirtyMinutesAgo);
          }).toList();
          
          return QuerySnapshot(
            snapshot.metadata,
            filteredDocs,
            snapshot.documentChanges,
            snapshot.isFromCache,
          );
        });
  }
}
