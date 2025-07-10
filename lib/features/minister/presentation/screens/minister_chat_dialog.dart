import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/providers/app_auth_provider.dart';
import '../../../../core/services/vip_notification_service.dart';

class MinisterChatDialog extends StatefulWidget {
  final Map<String, dynamic> appointment;
  const MinisterChatDialog({Key? key, required this.appointment}) : super(key: key);

  @override
  State<MinisterChatDialog> createState() => _MinisterChatDialogState();
}

class _MinisterChatDialogState extends State<MinisterChatDialog> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final VipNotificationService _notificationService = VipNotificationService();
  
  late String appointmentId;
  String recipientId = '';
  String recipientName = 'Floor Manager';
  String recipientRole = 'floorManager';
  
  // Fetch floor manager ID from users collection
  Future<void> _fetchFloorManagerId() async {
    try {
      // Query users collection to find the floor manager
      final floorManagerUsers = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'floorManager')
          .limit(1) // We only need one floor manager
          .get();
      
      if (floorManagerUsers.docs.isNotEmpty) {
        // Get the first floor manager user ID
        final floorManagerDoc = floorManagerUsers.docs.first;
        setState(() {
          recipientId = floorManagerDoc.id; // Set the correct floor manager ID
          print('DEBUG: Found floor manager ID: $recipientId');
        });
      } else {
        print('ERROR: No floor manager found in users collection');
      }
    } catch (e) {
      print('Error fetching floor manager ID: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    
    // Get the EXACT appointmentId from the appointment object - this is critical
    // for proper message routing between minister and floor manager
    if (widget.appointment.containsKey('id')) {
      // If we have a document ID, use that as the primary ID
      appointmentId = widget.appointment['id'] as String;
      print('DEBUG: Using appointment document ID as appointmentId: $appointmentId');
    } else if (widget.appointment.containsKey('appointmentId') && 
               (widget.appointment['appointmentId'] as String? ?? '').isNotEmpty) {
      // Otherwise use the appointmentId field if available
      appointmentId = widget.appointment['appointmentId'] as String;
      print('DEBUG: Using existing appointmentId field: $appointmentId');
    } else {
      // Only as a last resort, create an ID based on ministers - ONLY if truly needed
      // This should be rare and only for general (non-appointment) chats
      final user = Provider.of<AppAuthProvider>(context, listen: false).appUser;
      if (user != null) {
        appointmentId = "";
        print('DEBUG: WARNING - No valid appointmentId found in appointment data:');
        print('DEBUG: Appointment data: ${widget.appointment}');
      }
    }
    
    print('DEBUG: Final appointmentId for chat: $appointmentId');
    
    // First fetch the floor manager ID from users collection
    _fetchFloorManagerId();
    
    // Then try to set up recipient info from appointment data as fallback
    // This will be overwritten by _fetchFloorManagerId() when it completes
    _setupRecipientInfo();
    
    // Mark messages as read when dialog opens
    _markMessagesAsRead();
    
    // Check if we need to create an initial message with appointment details
    _checkAndCreateInitialMessage();
  }
  
  void _setupRecipientInfo() {
    // Only set recipientId if it's not already set by _fetchFloorManagerId
    // This serves as a fallback if the fetch didn't work
    if (recipientId.isEmpty) {
      final String fallbackId = widget.appointment['floorManagerId'] as String? ?? '';
      if (fallbackId.isNotEmpty) {
        recipientId = fallbackId;
        print('DEBUG: Using fallback floor manager ID from appointment: $recipientId');
      }
    }
    
    // Always update the display name
    recipientName = widget.appointment['floorManagerName'] as String? ?? 'Floor Manager';
    recipientRole = 'floorManager';
    
    print('DEBUG: Chat setup with appointmentId: $appointmentId');
    print('DEBUG: Recipient - ID: $recipientId, Name: $recipientName, Role: $recipientRole');
  }
  
  // Creates an initial message with appointment details if none exists
  Future<void> _checkAndCreateInitialMessage() async {
    // Check if any messages already exist for this appointment
    try {
      final messagesQuery = await _firestore
          .collection('chat_messages')
          .where('appointmentId', isEqualTo: appointmentId)
          .limit(1)
          .get();
      
      // If no messages found, create an initial message with appointment details
      if (messagesQuery.docs.isEmpty) {
        await _createInitialMessage();
      }
    } catch (e) {
      print('Error checking for existing messages: $e');
    }
  }
  
  // Create an initial message containing appointment details
  Future<void> _createInitialMessage() async {
    final currentUser = Provider.of<AppAuthProvider>(context, listen: false).appUser;
    if (currentUser == null) return;
    
    try {
      // Get user information
      final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      if (!userDoc.exists) return;
      
      final userData = userDoc.data()!;
      final senderName = userData['name'] ?? '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'.trim();
      
      // Format appointment date and time
      String appointmentDate = 'Not specified';
      String appointmentTime = 'Not specified';
      
      // Get appointment date/time from appointmentTime
      if (widget.appointment['appointmentTime'] != null) {
        final timestamp = widget.appointment['appointmentTime'] as Timestamp;
        final dateTime = timestamp.toDate();
        appointmentDate = DateFormat('EEEE, MMMM d, yyyy').format(dateTime);
        appointmentTime = DateFormat('h:mm a').format(dateTime);
      } 
      // Try appointmentTimeUTC if appointmentTime is not available
      else if (widget.appointment['appointmentTimeUTC'] != null) {
        final timestamp = widget.appointment['appointmentTimeUTC'] as Timestamp;
        final dateTime = timestamp.toDate().toLocal();
        appointmentDate = DateFormat('EEEE, MMMM d, yyyy').format(dateTime);
        appointmentTime = DateFormat('h:mm a').format(dateTime);
      }
      
      // Get service name
      final serviceName = widget.appointment['serviceName'] as String? ?? 'Not specified';
      
      // Create the initial message with appointment details - use plain text formatting
      // that will display properly in the chat bubble
      final initialMessageText = 'APPOINTMENT DETAILS:\n\n'
          '📅 Date: $appointmentDate\n'
          '⏰ Time: $appointmentTime\n'
          '📋 Service: $serviceName';
      
      // Use the client timestamp to ensure immediate display
      final clientTimestamp = Timestamp.now();
      
      // Create message document in Firestore with a client-side timestamp
      // to ensure it appears immediately in the UI
      await _firestore.collection('chat_messages').add({
        'appointmentId': appointmentId,
        'message': initialMessageText,
        'timestamp': clientTimestamp,  // Use client timestamp for immediate display
        'isRead': true,  // Mark as read initially
        'senderId': 'system',  // Use system as sender to distinguish from user messages
        'senderName': 'Appointment Info',
        'senderRole': 'system',
        'recipientId': currentUser.uid,
        'recipientName': senderName.isEmpty ? 'Minister' : senderName,
        'recipientRole': 'minister',
        'participants': _createParticipantsArray(currentUser.uid),
        'chatId': appointmentId,
        // Add these fields explicitly for chat list display
        'appointmentDate': appointmentDate,
        'appointmentTime': appointmentTime,
        'serviceName': serviceName,
        'isSystemMessage': true,
      });
      
      print('DEBUG: Created initial message with appointment details');
      
    } catch (e) {
      print('Error creating initial message: $e');
    }
  }
  
  // Ensure participants array always includes both minister and floor manager IDs
  List<String> _createParticipantsArray(String ministerUserId) {
    final List<String> participants = [];
    
    // Add minister ID
    if (ministerUserId.isNotEmpty) {
      participants.add(ministerUserId);
    }
    
    // Add floor manager ID
    if (recipientId.isNotEmpty) {
      participants.add(recipientId);
    } else {
      // If we don't have a specific floor manager ID, try to get it from the appointment
      final String floorManagerId = widget.appointment['floorManagerId'] as String? ?? '';
      if (floorManagerId.isNotEmpty) {
        participants.add(floorManagerId);
        print('DEBUG: Added floor manager ID from appointment: $floorManagerId');
      } else {
        // Add a special ID that floor managers can query for
        participants.add('floorManager_recipient');
        print('DEBUG: Added generic floorManager_recipient ID to participants');
      }
    }
    
    print('DEBUG: Created participants array: $participants');
    return participants;
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
      
      // Format appointment date and time for metadata
      String appointmentDate = 'Not specified';
      String appointmentTime = 'Not specified';
      String serviceName = widget.appointment['serviceName'] as String? ?? 'Not specified';
      
      // Get appointment date/time from appointmentTime
      if (widget.appointment['appointmentTime'] != null) {
        final timestamp = widget.appointment['appointmentTime'] as Timestamp;
        final dateTime = timestamp.toDate();
        appointmentDate = DateFormat('EEEE, MMMM d, yyyy').format(dateTime);
        appointmentTime = DateFormat('h:mm a').format(dateTime);
      } 
      // Try appointmentTimeUTC if appointmentTime is not available
      else if (widget.appointment['appointmentTimeUTC'] != null) {
        final timestamp = widget.appointment['appointmentTimeUTC'] as Timestamp;
        final dateTime = timestamp.toDate().toLocal();
        appointmentDate = DateFormat('EEEE, MMMM d, yyyy').format(dateTime);
        appointmentTime = DateFormat('h:mm a').format(dateTime);
      }
      
      // Create message document in Firestore
      await _firestore.collection('chat_messages').add({
        'appointmentId': appointmentId,
        'message': messageText,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'senderId': currentUser.uid,
        'senderName': senderName.isEmpty ? 'Minister' : senderName,
        'senderRole': 'minister',
        'recipientId': recipientId,
        'recipientName': recipientName,
        'recipientRole': recipientRole,
        'participants': _createParticipantsArray(currentUser.uid),
        'chatId': appointmentId,
        // Add these fields explicitly for chat list display
        'appointmentDate': appointmentDate,
        'appointmentTime': appointmentTime,
        'serviceName': serviceName,
      });
      
      // Send notification to recipient
      await _notificationService.sendFCMToUser(
        userId: recipientId,
        title: 'New message from ${senderName.isEmpty ? 'Minister' : senderName}',
        body: messageText,
        messageType: 'chat',
        data: {
          'type': 'chat',
          'appointmentId': appointmentId,
          'senderId': currentUser.uid,
          'senderName': senderName.isEmpty ? 'Minister' : senderName,
          'senderRole': 'minister',
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
    
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      backgroundColor: Colors.transparent,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          title: Text(
            'Chat with Floor Manager',
            style: TextStyle(
              color: AppColors.richGold,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          leading: IconButton(
            icon: Icon(Icons.close, color: AppColors.richGold),
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
                    'Appointment ID: ${appointmentId}',
                    style: TextStyle(
                      color: AppColors.richGold,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Display formatted appointment date and time
                  Builder(builder: (context) {
                    String appointmentDate = 'Not specified';
                    String appointmentTime = 'Not specified';
                    
                    if (widget.appointment['appointmentTime'] != null) {
                      final timestamp = widget.appointment['appointmentTime'] as Timestamp;
                      final dateTime = timestamp.toDate();
                      appointmentDate = DateFormat('EEEE, MMMM d, yyyy').format(dateTime);
                      appointmentTime = DateFormat('h:mm a').format(dateTime);
                    } 
                    else if (widget.appointment['appointmentTimeUTC'] != null) {
                      final timestamp = widget.appointment['appointmentTimeUTC'] as Timestamp;
                      final dateTime = timestamp.toDate().toLocal();
                      appointmentDate = DateFormat('EEEE, MMMM d, yyyy').format(dateTime);
                      appointmentTime = DateFormat('h:mm a').format(dateTime);
                    }
                    
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Date: $appointmentDate',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        Text(
                          'Time: $appointmentTime',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        Text(
                          'Service: ${widget.appointment['serviceName'] ?? 'Not specified'}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        Text(
                          'Venue: ${widget.appointment['venueName'] ?? 'Not specified'}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
            
            // Chat messages
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
      ),
    );
  }
  
  Widget _buildMessageBubble(Map<String, dynamic> message, bool isFromCurrentUser) {
    final messageText = message['message'] as String? ?? '';
    final timestamp = message['timestamp'] as Timestamp?;
    final String senderName = message['senderName'] as String? ?? 'Unknown';
    final String senderRole = message['senderRole'] as String? ?? '';
    final bool isSystemMessage = message['isSystemMessage'] as bool? ?? false;
    
    String formattedTime = 'Just now';
    if (timestamp != null) {
      formattedTime = DateFormat('MMM d, h:mm a').format(timestamp.toDate());
    }
    
    // Use special styling for system messages (appointment details)
    final Color messageColor = isSystemMessage 
        ? Colors.black
        : (isFromCurrentUser ? AppColors.richGold : Colors.grey[700]!);
    
    final textColor = isSystemMessage ? Colors.white : Colors.black;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Align(
        // System messages are centered
        alignment: isSystemMessage 
            ? Alignment.center 
            : (isFromCurrentUser ? Alignment.centerRight : Alignment.centerLeft),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: isSystemMessage 
                ? MediaQuery.of(context).size.width * 0.85 
                : MediaQuery.of(context).size.width * 0.75,
          ),
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: messageColor,
            borderRadius: BorderRadius.circular(12),
            // Add a gold border for system messages
            border: isSystemMessage 
                ? Border.all(color: AppColors.richGold, width: 2) 
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Only show sender info for non-system messages
              if (!isSystemMessage)
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
                      isFromCurrentUser ? 'Minister' : _formatRoleDisplay(senderRole),
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
      case 'floorManager':
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
