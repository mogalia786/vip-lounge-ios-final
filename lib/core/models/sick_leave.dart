import 'package:cloud_firestore/cloud_firestore.dart';

class SickLeave {
  final String id;
  final String userId;
  final String role;
  final DateTime startDate;
  final DateTime endDate;
  final String status; // pending, approved, rejected
  final Timestamp createdAt;

  SickLeave({
    required this.id,
    required this.userId,
    required this.role,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'role': role,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'status': status,
      'createdAt': createdAt,
    };
  }

  factory SickLeave.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SickLeave(
      id: doc.id,
      userId: data['userId'],
      role: data['role'],
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp).toDate(),
      status: data['status'],
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }
}
