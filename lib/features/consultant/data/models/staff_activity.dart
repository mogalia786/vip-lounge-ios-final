import 'package:cloud_firestore/cloud_firestore.dart';

/// Model class for staff activities associated with appointments
class StaffActivity {
  final String id;
  final String appointmentId;
  final String userId;
  final String userName;
  final String type;
  final String detail;
  final DateTime timestamp;
  
  StaffActivity({
    required this.id,
    required this.appointmentId,
    required this.userId,
    required this.userName,
    required this.type,
    required this.detail,
    required this.timestamp,
  });
  
  /// Create a StaffActivity from a Firestore document
  factory StaffActivity.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StaffActivity(
      id: doc.id,
      appointmentId: data['appointmentId'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      type: data['type'] ?? '',
      detail: data['detail'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
  }
  
  /// Convert to a map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'appointmentId': appointmentId,
      'userId': userId,
      'userName': userName,
      'type': type,
      'detail': detail,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
  
  /// Activity types
  static const String typeSessionStart = 'session_start';
  static const String typeSessionEnd = 'session_end';
  static const String typeService = 'service';
  static const String typeDocumentUpload = 'document_upload';
  static const String typeRecording = 'recording';
  static const String typeBreakStart = 'break_start';
  static const String typeBreakEnd = 'break_end';
}
