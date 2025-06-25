import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/chat_message.dart';
import 'vip_notification_service.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Collection references
  final CollectionReference _messagesCollection = 
      FirebaseFirestore.instance.collection('messages');
  
  final CollectionReference _usersCollection = 
      FirebaseFirestore.instance.collection('users');

  // Singleton pattern
  static final ChatService _instance = ChatService._internal();
  
  factory ChatService() {
    return _instance;
  }
  
  ChatService._internal();

  // Send a message to a recipient - now restricted to Minister and Floor Manager roles only
  Future<bool> sendMessage({
    required String senderId,
    required String senderName, 
    required String senderRole,
    required String recipientId, 
    required String recipientName,
    required String recipientRole,
    required String message,
    required String appointmentId,
    String? appointmentTitle,
  }) async {
    try {
      // Enforce role restrictions: only allow chats between Minister and Floor Manager
      bool isValidChat = false;
      
      if ((senderRole == 'minister' && recipientRole == 'floor_manager') ||
          (senderRole == 'floor_manager' && recipientRole == 'minister')) {
        isValidChat = true;
      }
      
      if (!isValidChat) {
        print('[CHAT] Rejected chat message: Invalid role combination: $senderRole -> $recipientRole');
        return false;
      }
      
      // Create the message object
      final newMessage = {
        'senderId': senderId,
        'senderName': senderName,
        'senderRole': senderRole,
        'recipientId': recipientId,
        'recipientName': recipientName,
        'recipientRole': recipientRole,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'appointmentId': appointmentId,
        'appointmentTitle': appointmentTitle,
      };
      
      // Save the message to Firestore
      await _messagesCollection.add(newMessage);
      
      // Send FCM notification using VipNotificationService direct to user
      await VipNotificationService().sendFCMToUser(
        userId: recipientId,
        title: "Message from $senderName",
        body: message,
        data: {
          'messageType': 'chat',
          'appointmentId': appointmentId,
          'senderId': senderId,
          'senderName': senderName,
          'senderRole': senderRole,
          'message': message,
        },
        messageType: 'chat',
      );
      
      return true;
    } catch (e) {
      print('Error sending message: $e');
      return false;
    }
  }

  // Mark a message as read
  Future<bool> markMessageAsRead(String messageId) async {
    try {
      await _messagesCollection.doc(messageId).update({'isRead': true});
      return true;
    } catch (e) {
      print('Error marking message as read: $e');
      return false;
    }
  }

  // Get unread message count for a user
  Future<int> getUnreadMessageCount(String userId) async {
    try {
      final querySnapshot = await _messagesCollection
          .where('recipientId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();
          
      return querySnapshot.docs.length;
    } catch (e) {
      print('Error getting unread message count: $e');
      return 0;
    }
  }

  // Get unread message count for a specific appointment
  Future<int> getUnreadMessageCountForAppointment(String userId, String appointmentId) async {
    try {
      final querySnapshot = await _messagesCollection
          .where('recipientId', isEqualTo: userId)
          .where('appointmentId', isEqualTo: appointmentId)
          .where('isRead', isEqualTo: false)
          .get();
          
      return querySnapshot.docs.length;
    } catch (e) {
      print('Error getting unread appointment message count: $e');
      return 0;
    }
  }

  // Get chat history between two users for a specific appointment
  Stream<List<ChatMessage>> getChatMessagesForAppointment(String appointmentId) {
    return _messagesCollection
        .where('appointmentId', isEqualTo: appointmentId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return ChatMessage.fromFirestore(doc);
          }).toList();
        });
  }

  // Get all messages for a user (inbox)
  Stream<List<ChatMessage>> getUserMessages(String userId) {
    return _messagesCollection
        .where('recipientId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return ChatMessage.fromFirestore(doc);
          }).toList();
        });
  }

  // Get stream of unread message count for a user
  Stream<int> getUnreadMessagesCountStream(String userId) {
    return _messagesCollection
        .where('recipientId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Get list of unique appointments with messages for a user
  Stream<Map<String, dynamic>> getUserMessagedAppointments(String userId) {
    return _messagesCollection
        .where('recipientId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          Map<String, dynamic> appointments = {};
          
          for (var doc in snapshot.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final appointmentId = data['appointmentId'] as String;
            
            if (!appointments.containsKey(appointmentId)) {
              appointments[appointmentId] = {
                'appointmentId': appointmentId,
                'appointmentTitle': data['appointmentTitle'],
                'lastMessage': data['message'],
                'lastMessageTime': (data['timestamp'] as Timestamp).toDate(),
                'senderName': data['senderName'],
                'unreadCount': data['isRead'] ? 0 : 1,
              };
            } else if (data['isRead'] == false) {
              appointments[appointmentId]['unreadCount'] = 
                  (appointments[appointmentId]['unreadCount'] as int) + 1;
            }
          }
          
          return appointments;
        });
  }
}
