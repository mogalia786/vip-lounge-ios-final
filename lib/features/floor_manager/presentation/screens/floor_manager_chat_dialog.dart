import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/providers/app_auth_provider.dart';
import '../../../../core/services/vip_notification_service.dart';

class FloorManagerChatDialog extends StatefulWidget {
  final Map<String, dynamic> conversation;
  const FloorManagerChatDialog({Key? key, required this.conversation}) : super(key: key);

  @override
  State<FloorManagerChatDialog> createState() => _FloorManagerChatDialogState();
}

class _FloorManagerChatDialogState extends State<FloorManagerChatDialog> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final VipNotificationService _notificationService = VipNotificationService();
  
  late String appointmentId;
  late String ministerId;
  late String ministerName;
  
  @override
  void initState() {
    super.initState();
    appointmentId = widget.conversation['appointmentId'] as String? ?? '';
    ministerId = widget.conversation['ministerId'] as String? ?? '';
    ministerName = widget.conversation['ministerName'] as String? ?? 'Minister';
    
    // Mark messages as read when dialog opens
    _markMessagesAsRead();
  }
  
  Future<void> _markMessagesAsRead() async {
    final currentUser = Provider.of<AppAuthProvider>(context, listen: false).appUser;
    if (currentUser == null) return;
    
    try {
      // Find unread messages for this appointment where the current user is the recipient
      final unreadMessages = await _firestore
          .collection('chat_messages')
          .where('appointmentId', isEqualTo: appointmentId)
          .where('recipientId', isEqualTo: currentUser.uid)
          .where('isRead', isEqualTo: false)
          .get();
      
      // Mark each message as read
      for (var doc in unreadMessages.docs) {
        await doc.reference.update({'isRead': true});
      }
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty) return;
    
    // Clear the text field immediately for better UX
    _messageController.clear();
    
    final currentUser = Provider.of<AppAuthProvider>(context, listen: false).appUser;
    if (currentUser == null) return;
    
    try {
      // Get user information
      final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      if (!userDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to find user information')),
        );
        return;
      }
      
      final userData = userDoc.data()!;
      final senderName = userData['name'] ?? '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'.trim();
      
      // Create message document in Firestore
      await _firestore.collection('chat_messages').add({
        'appointmentId': appointmentId,
        'message': messageText,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'senderId': currentUser.uid,
        'senderName': senderName.isEmpty ? 'Floor Manager' : senderName,
        'senderRole': 'floor_manager',
        'recipientId': ministerId,
        'recipientName': ministerName,
        'recipientRole': 'minister',
        'participants': [currentUser.uid, ministerId],
        'chatId': appointmentId,
      });
      
      // Send notification to minister
      await _notificationService.sendFCMToUser(
        userId: ministerId,
        title: 'New message from Floor Manager',
        body: messageText,
        messageType: 'chat',
        data: {
          'type': 'chat',
          'appointmentId': appointmentId,
          'senderId': currentUser.uid,
          'senderName': senderName.isEmpty ? 'Floor Manager' : senderName,
          'senderRole': 'floor_manager',
        },
      );
      
    } catch (e) {
      print('Error sending message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final currentUser = Provider.of<AppAuthProvider>(context).appUser;
    if (currentUser == null) {
      return const Center(child: Text('User not authenticated'));
    }
    
    // Get appointment details for header
    final serviceName = widget.conversation['serviceName'] ?? 'Unknown Service';
    final venueName = widget.conversation['venueName'] ?? 'Unknown Venue';
    
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          'Chat with $ministerName',
          style: TextStyle(
            color: AppColors.richGold,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.richGold),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          // Appointment info card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[850],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[700]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Appointment ID: $appointmentId',
                  style: TextStyle(
                    color: AppColors.richGold,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Service: $serviceName',
                  style: const TextStyle(color: Colors.white70),
                ),
                Text(
                  'Venue: $venueName',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          
          // Messages area
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                .collection('chat_messages')
                .where('appointmentId', isEqualTo: appointmentId)
                .orderBy('timestamp', descending: true)
                .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No messages yet. Start the conversation!',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }
                
                final messages = snapshot.data!.docs;
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(8.0),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index].data() as Map<String, dynamic>;
                    final bool isFromCurrentUser = message['senderId'] == currentUser.uid;
                    
                    return _buildMessageBubble(message, isFromCurrentUser);
                  },
                );
              },
            ),
          ),
          
          // Message input
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            color: Colors.grey[900],
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[800],
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.richGold,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: _sendMessage,
                    icon: const Icon(Icons.send, color: Colors.black),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMessageBubble(Map<String, dynamic> message, bool isFromCurrentUser) {
    final messageText = message['message'] as String? ?? '';
    final timestamp = message['timestamp'] as Timestamp?;
    final String senderName = message['senderName'] as String? ?? 'Unknown';
    final String senderRole = message['senderRole'] as String? ?? '';
    
    String formattedTime = 'Just now';
    if (timestamp != null) {
      formattedTime = DateFormat('MMM d, h:mm a').format(timestamp.toDate());
    }
    
    final mainColor = isFromCurrentUser ? AppColors.richGold : Colors.grey[700]!;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Align(
        alignment: isFromCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: mainColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isFromCurrentUser ? 'You' : senderName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isFromCurrentUser ? Colors.black : Colors.white,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isFromCurrentUser ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      isFromCurrentUser ? 'Floor Manager' : _formatRoleDisplay(senderRole),
                      style: TextStyle(
                        fontSize: 10,
                        color: isFromCurrentUser ? Colors.black : Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                messageText,
                style: TextStyle(
                  color: isFromCurrentUser ? Colors.black : Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Align(
                alignment: Alignment.bottomRight,
                child: Text(
                  formattedTime,
                  style: TextStyle(
                    fontSize: 10,
                    color: isFromCurrentUser ? Colors.black.withOpacity(0.7) : Colors.white.withOpacity(0.7),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  String _formatRoleDisplay(String role) {
    switch (role.toLowerCase()) {
      case 'floor_manager':
        return 'Floor Manager';
      case 'floormanager':
        return 'Floor Manager';
      case 'minister':
        return 'Minister';
      case 'consultant':
        return 'Consultant';
      case 'concierge':
        return 'Concierge';
      case 'cleaner':
        return 'Cleaner';
      default:
        return role.isEmpty ? 'Unknown' : role;
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}
