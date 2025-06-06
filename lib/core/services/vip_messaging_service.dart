import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Ensure intl package is imported
import '../constants/colors.dart';
import 'vip_notification_service.dart';

/// Service that handles messaging between ministers, consultants, and concierges
class VipMessagingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final VipNotificationService _notificationService = VipNotificationService();

  /// Send a message from one user to another
  Future<void> sendMessage({
    required String appointmentId,
    required String senderId,
    required String senderName,
    required String senderRole,
    required String message,
    String? attachmentUrl,
    String? attachmentType,
  }) async {
    try {
      // First get appointment details to determine recipients
      final appointmentDoc = await _firestore.collection('appointments').doc(appointmentId).get();
      
      if (!appointmentDoc.exists) {
        throw Exception('Appointment not found');
      }
      
      final appointmentData = appointmentDoc.data()!;
      
      // Create the message document
      try {
        final messageRef = await _firestore.collection('messages').add({
          'appointmentId': appointmentId,
          'senderId': senderId,
          'senderName': senderName,
          'senderRole': senderRole,
          'message': message,
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
          'attachmentUrl': attachmentUrl,
          'attachmentType': attachmentType,
        });
        print('✅ [CHAT] Message sent: \u001b[32m${messageRef.id}\u001b[0m');
        // Determine recipient(s) based on sender role and appointment data
        if (senderRole == 'minister') {
          // Minister sent message - notify assigned staff
          await _notifyStaffOfMessage(appointmentData, senderName, message, appointmentId, messageRef.id);
        } else {
          // Staff sent message - notify minister
          await _notifyMinisterOfMessage(
            appointmentData,
            senderName,
            senderRole,
            message,
            appointmentId,
            messageRef.id,
          );
        }
      } catch (e) {
        print('❌ [CHAT] Failed to send message: \u001b[31m$e\u001b[0m');
        rethrow;
      }
      
    } catch (e) {
      print('Error sending message: $e');
      throw e;
    }
  }

  /// Get all messages for a specific appointment
  Stream<QuerySnapshot> getMessagesForAppointment(String appointmentId) {
    return _firestore
        .collection('messages')
        .where('appointmentId', isEqualTo: appointmentId)
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  /// Mark a message as read
  Future<void> markMessageAsRead(String messageId) async {
    try {
      await _firestore
          .collection('messages')
          .doc(messageId)
          .update({'isRead': true});
    } catch (e) {
      print('Error marking message as read: $e');
    }
  }

  /// Mark all messages for an appointment as read for a specific user
  Future<void> markAllMessagesAsRead(String appointmentId, String recipientId) async {
    try {
      final messagesQuery = await _firestore
          .collection('messages')
          .where('appointmentId', isEqualTo: appointmentId)
          .where('isRead', isEqualTo: false)
          .get();
      
      // Create a batch to update all documents at once
      final batch = _firestore.batch();
      
      for (var doc in messagesQuery.docs) {
        final senderId = doc.data()['senderId'];
        if (senderId != recipientId) {
          batch.update(doc.reference, {'isRead': true});
        }
      }
      
      await batch.commit();
    } catch (e) {
      print('Error marking all messages as read: $e');
    }
  }

  /// Get unread message count for a user
  Future<int> getUnreadMessageCount(String userId) async {
    try {
      // Get appointments where this user is involved
      final appointmentsAsMinister = await _firestore
          .collection('appointments')
          .where('ministerId', isEqualTo: userId)
          .get();
      
      final appointmentsAsConsultant = await _firestore
          .collection('appointments')
          .where('staff.consultant.id', isEqualTo: userId)
          .get();
      
      final appointmentsAsConcierge = await _firestore
          .collection('appointments')
          .where('staff.concierge.id', isEqualTo: userId)
          .get();
      
      // Combine all appointment IDs
      final appointmentIds = [
        ...appointmentsAsMinister.docs.map((doc) => doc.id),
        ...appointmentsAsConsultant.docs.map((doc) => doc.id),
        ...appointmentsAsConcierge.docs.map((doc) => doc.id),
      ];
      
      // Count unread messages across all these appointments
      int totalUnread = 0;
      
      for (var appointmentId in appointmentIds) {
        final messagesQuery = await _firestore
            .collection('messages')
            .where('appointmentId', isEqualTo: appointmentId)
            .where('senderId', isNotEqualTo: userId)
            .where('isRead', isEqualTo: false)
            .get();
        
        totalUnread += messagesQuery.docs.length;
      }
      
      return totalUnread;
    } catch (e) {
      print('Error getting unread message count: $e');
      return 0;
    }
  }

  /// Notify staff (consultant, concierge) of a new message from a minister
  Future<void> _notifyStaffOfMessage(
    Map<String, dynamic> appointmentData,
    String ministerName,
    String message,
    String appointmentId,
    String messageId,
  ) async {
    try {
      // Notify consultant if assigned
      if (appointmentData.containsKey('staff') && 
          appointmentData['staff'] is Map && 
          appointmentData['staff'].containsKey('consultant')) {
        final consultant = appointmentData['staff']['consultant'];
        if (consultant != null && consultant.containsKey('id')) {
          final consultantId = consultant['id'];
          final consultantName = consultant['name'] ?? '';
          print('🐞 [DEBUG] Notifying consultant $consultantId ($consultantName) of new message from minister $ministerName');
          try {
            await _notificationService.createNotification(
              title: 'New Message from $ministerName',
              body: message.length > 100 ? '${message.substring(0, 97)}...' : message,
              data: {
                'appointmentId': appointmentId,
                'messageId': messageId,
                'type': 'message',
              },
              role: 'consultant',
              assignedToId: consultantId,
              notificationType: 'message',
            );
            print('✅ [NOTIF] Notification created for consultant $consultantId');
          } catch (e) {
            print('❌ [NOTIF] Failed to create notification for consultant $consultantId: $e');
          }
          try {
            await _notificationService.sendFCMToUser(
              userId: consultantId,
              title: 'New Message from $ministerName',
              body: message.length > 100 ? '${message.substring(0, 97)}...' : message,
              data: {
                'appointmentId': appointmentId,
                'messageId': messageId,
                'type': 'message',
              },
              messageType: 'message',
            );
            print('✅ [FCM] Chat push sent to consultant \u001b[32m$consultantId\u001b[0m');
          } catch (e) {
            print('❌ [FCM] Failed to send chat push to consultant \u001b[31m$consultantId\u001b[0m: $e');
          }
        }
      }
      // Notify staff if assigned (generic staff role)
      if (appointmentData.containsKey('staff') && 
          appointmentData['staff'] is Map && 
          appointmentData['staff'].containsKey('staff')) {
        final staff = appointmentData['staff']['staff'];
        if (staff != null && staff.containsKey('id')) {
          final staffId = staff['id'];
          final staffName = staff['name'] ?? '';
          print('🐞 [DEBUG] Notifying staff $staffId ($staffName) of new message from minister $ministerName');
          try {
            await _notificationService.createNotification(
              title: 'New Message from $ministerName',
              body: message.length > 100 ? '${message.substring(0, 97)}...' : message,
              data: {
                'appointmentId': appointmentId,
                'messageId': messageId,
                'type': 'message',
              },
              role: 'staff',
              assignedToId: staffId,
              notificationType: 'message',
            );
            print('✅ [NOTIF] Notification created for staff $staffId');
          } catch (e) {
            print('❌ [NOTIF] Failed to create notification for staff $staffId: $e');
          }
          try {
            await _notificationService.sendFCMToUser(
              userId: staffId,
              title: 'New Message from $ministerName',
              body: message.length > 100 ? '${message.substring(0, 97)}...' : message,
              data: {
                'appointmentId': appointmentId,
                'messageId': messageId,
                'type': 'message',
              },
              messageType: 'message',
            );
            print('✅ [FCM] Chat push sent to staff \u001b[32m$staffId\u001b[0m');
          } catch (e) {
            print('❌ [FCM] Failed to send chat push to staff \u001b[31m$staffId\u001b[0m: $e');
          }
        }
      }
      // Notify concierge if assigned
      if (appointmentData.containsKey('staff') && 
          appointmentData['staff'] is Map && 
          appointmentData['staff'].containsKey('concierge')) {
        final concierge = appointmentData['staff']['concierge'];
        if (concierge != null && concierge.containsKey('id')) {
          final conciergeId = concierge['id'];
          final conciergeName = concierge['name'] ?? '';
          print('🐞 [DEBUG] Notifying concierge $conciergeId ($conciergeName) of new message from minister $ministerName');
          try {
            await _notificationService.createNotification(
              title: 'New Message from $ministerName',
              body: message.length > 100 ? '${message.substring(0, 97)}...' : message,
              data: {
                'appointmentId': appointmentId,
                'messageId': messageId,
                'type': 'message',
              },
              role: 'concierge',
              assignedToId: conciergeId,
              notificationType: 'message',
            );
            print('✅ [NOTIF] Notification created for concierge $conciergeId');
          } catch (e) {
            print('❌ [NOTIF] Failed to create notification for concierge $conciergeId: $e');
          }
          try {
            await _notificationService.sendFCMToUser(
              userId: conciergeId,
              title: 'New Message from $ministerName',
              body: message.length > 100 ? '${message.substring(0, 97)}...' : message,
              data: {
                'appointmentId': appointmentId,
                'messageId': messageId,
                'type': 'message',
              },
              messageType: 'message',
            );
            print('✅ [FCM] Chat push sent to concierge \u001b[32m$conciergeId\u001b[0m');
          } catch (e) {
            print('❌ [FCM] Failed to send chat push to concierge \u001b[31m$conciergeId\u001b[0m: $e');
          }
        }
      }
    } catch (e) {
      print('❌ [NOTIF] Error notifying staff of message: $e');
    }
  }

  /// Notify minister of a new message from staff
  Future<void> _notifyMinisterOfMessage(
    Map<String, dynamic> appointmentData,
    String staffName,
    String staffRole,
    String message,
    String appointmentId,
    String messageId,
  ) async {
    try {
      final ministerId = appointmentData['ministerId'];
      final ministerName = appointmentData['ministerName'] ?? 'Minister';
      if (ministerId != null && ministerId.toString().isNotEmpty) {
        final roleTitle = _getRoleTitle(staffRole);
        print('🐞 [DEBUG] Notifying minister $ministerId of new message from $staffName ($roleTitle)');
        try {
          await _notificationService.createNotification(
            title: 'New Message from $staffName ($roleTitle)',
            body: message.length > 100 ? '${message.substring(0, 97)}...' : message,
            data: {
              'appointmentId': appointmentId,
              'messageId': messageId,
              'type': 'message',
            },
            role: 'minister',
            assignedToId: ministerId,
            notificationType: 'message',
          );
          print('✅ [NOTIF] Notification created for minister $ministerId');
        } catch (e) {
          print('❌ [NOTIF] Failed to create notification for minister $ministerId: $e');
        }
        try {
          await _notificationService.sendFCMToUser(
            userId: ministerId,
            title: 'New Message from $staffName ($roleTitle)',
            body: message.length > 100 ? '${message.substring(0, 97)}...' : message,
            data: {
              'appointmentId': appointmentId,
              'messageId': messageId,
              'type': 'message',
            },
            messageType: 'message',
          );
          print('✅ [FCM] Chat push sent to minister \u001b[32m$ministerId\u001b[0m');
        } catch (e) {
          print('❌ [FCM] Failed to send chat push to minister \u001b[31m$ministerId\u001b[0m: $e');
        }
      }
    } catch (e) {
      print('❌ [NOTIF] Error notifying minister of message: $e');
    }
  }

  /// Helper method to get role title
  String _getRoleTitle(String role) {
    switch (role) {
      case 'floor_manager':
        return 'Floor Manager';
      case 'consultant':
        return 'Consultant';
      case 'concierge':
        return 'Concierge';
      case 'cleaner':
        return 'Cleaner';
      case 'minister':
        return 'Minister';
      default:
        return role.substring(0, 1).toUpperCase() + role.substring(1);
    }
  }
  
  /// Build a chat UI widget that can be reused across different screens
  Widget buildChatInterface({
    required BuildContext context,
    required String appointmentId,
    required String currentUserId,
    required String currentUserName,
    required String currentUserRole,
    String? recipientName,
    String? recipientRole,
  }) {
    // Controller for the message input
    final TextEditingController messageController = TextEditingController();
    
    // Gold color for accents
    final goldColor = Colors.amber[700] ?? Color(0xFFFFD700);
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: goldColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.message, color: goldColor),
                const SizedBox(width: 8),
                Text(
                  recipientName != null
                      ? 'Chat with $recipientName'
                      : 'Appointment Chat',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          
          // Messages list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: getMessagesForAppointment(appointmentId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(color: goldColor),
                  );
                }
                
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading messages: ${snapshot.error}',
                      style: TextStyle(color: Colors.red),
                    ),
                  );
                }
                
                final messages = snapshot.data?.docs ?? [];
                
                if (messages.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 48,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No messages yet',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Start the conversation by sending a message below.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                
                // Mark messages as read as they appear
                for (var message in messages) {
                  final data = message.data() as Map<String, dynamic>;
                  final senderId = data['senderId'];
                  final isRead = data['isRead'] ?? false;
                  
                  if (senderId != currentUserId && !isRead) {
                    markMessageAsRead(message.id);
                  }
                }
                
                return ListView.builder(
                  reverse: false,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index].data() as Map<String, dynamic>;
                    final senderId = message['senderId'];
                    final senderName = message['senderName'];
                    final senderRole = message['senderRole'];
                    final messageText = message['message'];
                    final timestamp = message['timestamp'] as Timestamp?;
                    final isSentByMe = senderId == currentUserId;
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        mainAxisAlignment: isSentByMe
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Avatar for recipient's messages
                          if (!isSentByMe)
                            Container(
                              width: 40,
                              height: 40,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: _getRoleColor(senderRole),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  senderName.isNotEmpty
                                      ? senderName[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                          
                          // Message content
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSentByMe
                                    ? goldColor.withOpacity(0.2)
                                    : Colors.grey[800],
                                borderRadius: BorderRadius.circular(16),
                                border: isSentByMe
                                    ? Border.all(color: goldColor.withOpacity(0.5))
                                    : null,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Sender name and role for recipient's messages
                                  if (!isSentByMe)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Text(
                                        '$senderName (${_getRoleTitle(senderRole)})',
                                        style: TextStyle(
                                          color: _getRoleColor(senderRole),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  
                                  // Message text
                                  Text(
                                    messageText,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                  
                                  // Timestamp
                                  if (timestamp != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        _formatTimestamp(timestamp.toDate()),
                                        style: TextStyle(
                                          color: Colors.grey[500],
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          
                          // Avatar for my messages
                          if (isSentByMe)
                            Container(
                              width: 40,
                              height: 40,
                              margin: const EdgeInsets.only(left: 8),
                              decoration: BoxDecoration(
                                color: _getRoleColor(currentUserRole),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  currentUserName.isNotEmpty
                                      ? currentUserName[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          
          // Input area
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.attach_file, color: Colors.grey[400]),
                  onPressed: () {
                    // TODO: Implement file attachment
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Attachments coming soon')),
                    );
                  },
                ),
                Expanded(
                  child: TextField(
                    controller: messageController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    minLines: 1,
                    maxLines: 4,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send, color: goldColor),
                  onPressed: () {
                    final messageText = messageController.text.trim();
                    if (messageText.isNotEmpty) {
                      sendMessage(
                        appointmentId: appointmentId,
                        senderId: currentUserId,
                        senderName: currentUserName,
                        senderRole: currentUserRole,
                        message: messageText,
                      );
                      messageController.clear();
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Helper method to get role color
  Color _getRoleColor(String role) {
    switch (role) {
      case 'minister':
        return Colors.purple[700] ?? Colors.purple;
      case 'consultant':
        return Colors.blue[700] ?? Colors.blue;
      case 'concierge':
        return Colors.green[700] ?? Colors.green;
      case 'cleaner':
        return Colors.orange[700] ?? Colors.orange;
      case 'floor_manager':
        return Colors.red[700] ?? Colors.red;
      default:
        return Colors.grey;
    }
  }

  /// Format timestamp for display in chat
  String _formatTimestamp(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
    
    // Use the imported DateFormat class
    final timeFormat = DateFormat('HH:mm');
    final dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');
    
    if (messageDate == today) {
      return 'Today at ${timeFormat.format(dateTime)}';
    } else if (messageDate == yesterday) {
      return 'Yesterday at ${timeFormat.format(dateTime)}';
    } else {
      // For messages older than yesterday, show the full date with time
      return dateTimeFormat.format(dateTime);
    }
  }
}
