import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String senderRole;
  final String recipientId;
  final String recipientName;
  final String recipientRole;
  final String message;
  final DateTime timestamp;
  final bool isRead;
  final String appointmentId; // Reference to appointment for context
  final String? appointmentTitle; // Optional appointment title for UI display

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.recipientId,
    required this.recipientName,
    required this.recipientRole,
    required this.message,
    required this.timestamp,
    required this.isRead,
    required this.appointmentId,
    this.appointmentTitle,
  });

  // Factory constructor to create a ChatMessage from a Firestore document
  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return ChatMessage(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? '',
      senderRole: data['senderRole'] ?? '',
      recipientId: data['recipientId'] ?? '',
      recipientName: data['recipientName'] ?? '',
      recipientRole: data['recipientRole'] ?? '',
      message: data['message'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      isRead: data['isRead'] ?? false,
      appointmentId: data['appointmentId'] ?? '',
      appointmentTitle: data['appointmentTitle'],
    );
  }

  // Convert ChatMessage to a Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'senderRole': senderRole,
      'recipientId': recipientId,
      'recipientName': recipientName,
      'recipientRole': recipientRole,
      'message': message,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
      'appointmentId': appointmentId,
      'appointmentTitle': appointmentTitle,
    };
  }
}
