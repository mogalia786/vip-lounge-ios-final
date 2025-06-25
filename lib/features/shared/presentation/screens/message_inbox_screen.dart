import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../core/models/chat_message.dart';
import '../../../../core/services/chat_service.dart';
import '../../../../core/providers/app_auth_provider.dart';
import '../../../../core/constants/colors.dart';

class MessageInboxScreen extends StatefulWidget {
  final Map<String, dynamic>? chatParams;

  const MessageInboxScreen({Key? key, this.chatParams}) : super(key: key);

  @override
  _MessageInboxScreenState createState() => _MessageInboxScreenState();
}

class _MessageInboxScreenState extends State<MessageInboxScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatService _chatService = ChatService();
  String? appointmentId;
  String? conversationPartnerId;
  String? conversationPartnerName;
  String? conversationPartnerRole;
  bool _isLoading = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _initChatParams();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _initChatParams() {
    if (widget.chatParams != null) {
      setState(() {
        appointmentId = widget.chatParams!['appointmentId'];
        conversationPartnerId = widget.chatParams!['senderId'] ?? widget.chatParams!['recipientId'];
        conversationPartnerName = widget.chatParams!['senderName'] ?? widget.chatParams!['recipientName'];
        conversationPartnerRole = widget.chatParams!['senderRole'] ?? widget.chatParams!['recipientRole'];
        _isLoading = false;
      });
      
      // If this came from a notification, mark messages as read
      _markMessagesRead();
    }
  }

  Future<void> _markMessagesRead() async {
    if (appointmentId == null || conversationPartnerId == null) return;
    
    final currentUser = Provider.of<AppAuthProvider>(context, listen: false).appUser;
    if (currentUser == null) return;
    
    // Get unread messages for this appointment
    final messagesSnapshot = await FirebaseFirestore.instance
      .collection('messages')
      .where('recipientId', isEqualTo: currentUser.id)
      .where('appointmentId', isEqualTo: appointmentId)
      .where('isRead', isEqualTo: false)
      .get();
    
    // Mark each as read
    for (var doc in messagesSnapshot.docs) {
      await _chatService.markMessageAsRead(doc.id);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || appointmentId == null) return;
    
    final currentUser = Provider.of<AppAuthProvider>(context, listen: false).appUser;
    if (currentUser == null) return;
    
    setState(() {
      _isSending = true;
    });
    
    try {
      // Get appointment details for context
      final appointmentDoc = await FirebaseFirestore.instance
          .collection('appointments')
          .doc(appointmentId)
          .get();
      
      final appointmentData = appointmentDoc.data();
      final appointmentTitle = appointmentData != null 
          ? '${appointmentData['serviceName'] ?? 'Appointment'} - ${DateFormat('MMM d, h:mm a').format((appointmentData['appointmentTime'] as Timestamp).toDate())}'
          : 'Appointment';
      
      await _chatService.sendMessage(
        senderId: currentUser.id,
        senderName: '${currentUser.firstName} ${currentUser.lastName}',
        senderRole: currentUser.role,
        recipientId: conversationPartnerId!,
        recipientName: conversationPartnerName ?? 'User',
        recipientRole: conversationPartnerRole ?? 'user',
        message: _messageController.text.trim(),
        appointmentId: appointmentId!,
        appointmentTitle: appointmentTitle,
      );
      
      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending message: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = Provider.of<AppAuthProvider>(context).appUser;
    
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('User not logged in')),
      );
    }
    
    if (_isLoading || appointmentId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Messages'),
          backgroundColor: AppColors.primary,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(conversationPartnerName ?? 'Chat'),
            Text(
              conversationPartnerRole != null 
                ? '${conversationPartnerRole![0].toUpperCase()}${conversationPartnerRole!.substring(1)}'
                : '',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _chatService.getChatMessagesForAppointment(appointmentId!),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                
                final messages = snapshot.data ?? [];
                if (messages.isEmpty) {
                  return const Center(
                    child: Text('No messages yet. Start the conversation!'),
                  );
                }
                
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToBottom();
                });
                
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(10),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderId == currentUser.id;
                    
                    return _buildMessageBubble(
                      message: message.message,
                      isMe: isMe,
                      senderName: isMe ? 'You' : message.senderName,
                      time: message.timestamp,
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Type a message',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(16),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: _isSending 
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ) 
                      : Icon(Icons.send, color: AppColors.richGold),
                  onPressed: _isSending ? null : _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble({
    required String message,
    required bool isMe,
    required String senderName,
    required DateTime time,
  }) {
    final bubbleColor = isMe ? AppColors.primary : AppColors.richGold;
    final textColor = Colors.white;
    final alignment = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final timeStr = DateFormat('h:mm a').format(time);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          Container(
            margin: EdgeInsets.only(
              left: isMe ? 80.0 : 0.0,
              right: isMe ? 0.0 : 80.0,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 10.0),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Text(
                    senderName,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                Text(
                  message,
                  style: TextStyle(color: textColor),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2.0, left: 8.0, right: 8.0),
            child: Text(
              timeStr,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
