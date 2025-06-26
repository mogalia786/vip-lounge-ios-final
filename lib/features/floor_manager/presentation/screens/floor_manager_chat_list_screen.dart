import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/providers/app_auth_provider.dart';
import '../../../../core/widgets/glass_card.dart';
import 'floor_manager_chat_dialog.dart';

class FloorManagerChatListScreen extends StatefulWidget {
  const FloorManagerChatListScreen({Key? key}) : super(key: key);

  @override
  State<FloorManagerChatListScreen> createState() => _FloorManagerChatListScreenState();
}

class _FloorManagerChatListScreenState extends State<FloorManagerChatListScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _userId = '';
  bool _isLoading = true;
  List<Map<String, dynamic>> _conversations = [];
  
 
  void _initializeUser() {
    final user = Provider.of<AppAuthProvider>(context, listen: false).appUser;
    if (user != null) {
      setState(() {
        _userId = user.uid;
      });
      _loadConversations();
    }
  }
  
  Future<void> _loadConversations() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      print('DEBUG: Loading chat conversations for floor manager: $_userId');
      
      // Get all chat messages involving this floor manager
      // Previously we used participants array, but that might be missing in some messages
      // So we use a more comprehensive query to catch all messages
      final messagesQuery = await _firestore
          .collection('chat_messages')
          .where('senderRole', isEqualTo: 'minister') // Get messages from ministers to floor manager
          .orderBy('timestamp', descending: true)
          .get();
      
      // Also get messages sent by the floor manager
      final sentMessagesQuery = await _firestore
          .collection('chat_messages')
          .where('senderId', isEqualTo: _userId) // Messages sent by this floor manager
          .orderBy('timestamp', descending: true)
          .get();
      
      // Combine both query results
      final allMessages = [...messagesQuery.docs, ...sentMessagesQuery.docs];
      
      print('DEBUG: Found ${allMessages.length} messages involving floor manager');
      
      // Group by appointments to create conversations
      final Map<String, Map<String, dynamic>> conversationsMap = {};
      
      for (var doc in allMessages) {
        final data = doc.data();
        final String appointmentId = data['appointmentId'] ?? '';
        
        // Create a conversation key - use appointmentId if available, otherwise use the chat participants
        String conversationKey;
        if (appointmentId.isNotEmpty) {
          conversationKey = 'appointment_$appointmentId';
          print('DEBUG: Using appointmentId for conversation key: $conversationKey');
        } else {
          // For messages without appointmentId, create a direct conversation key based on the participants
          // If the current user is the sender, the conversation should be with the recipient
          // Otherwise, the conversation should be with the sender
          final String senderId = data['senderId'] ?? '';
          final String recipientId = data['recipientId'] ?? '';
          final String otherPersonId = senderId == _userId ? recipientId : senderId;
          conversationKey = 'direct_${otherPersonId.isNotEmpty ? otherPersonId : "unknown"}';
          print('DEBUG: Created direct conversation key for message without appointmentId: $conversationKey');
        }
        
        print('DEBUG: Processing message with conversationKey: $conversationKey');

        final Timestamp timestamp = data['timestamp'] ?? Timestamp.now();
        final String message = data['message'] ?? 'No message content';
        final bool isRead = data['isRead'] ?? false;
        
        // Get sender information
        final String senderId = data['senderId'] ?? '';
        final String senderName = data['senderName'] ?? 'Unknown';
        final String senderRole = data['senderRole'] ?? '';
        
        // Get recipient information
        final String recipientId = data['recipientId'] ?? '';
        final String recipientName = data['recipientName'] ?? 'Unknown';
        
        // Log detailed message information
        print('DEBUG CHAT: Message has - senderId: $senderId, senderRole: $senderRole, recipientRole: ${data['recipientRole']}, appointmentId: $appointmentId, recipientId: $recipientId');
        
        // Determine minister details (the conversation partner)
        // If the message was sent by the floor manager, then the minister is the recipient
        // Otherwise, the minister is the sender
        final String ministerId = senderRole == 'floor_manager' ? recipientId : senderId;
        final String ministerName = senderRole == 'floor_manager' ? recipientName : senderName;
        
        print('DEBUG CHAT: Processing message with ministerId: $ministerId and ministerName: $ministerName');
          
        // Create or update conversation
        if (!conversationsMap.containsKey(conversationKey)) {
          // Get appointment details if possible
          Map<String, dynamic> appointmentDetails = {};
          try {
            final appointmentDoc = await _firestore.collection('bookings').doc(appointmentId).get();
            if (appointmentDoc.exists) {
              appointmentDetails = appointmentDoc.data() ?? {};
              print('DEBUG: Found appointment details for $appointmentId: ${appointmentDetails['serviceName']}');
            } else {
              print('DEBUG: No appointment document exists for ID: $appointmentId');
            }
          } catch (e) {
            print('Error fetching appointment details: $e');
          }
          
          conversationsMap[conversationKey] = {
            'appointmentId': appointmentId,
            'ministerId': ministerId,
            'ministerName': ministerName,
            'serviceName': appointmentDetails['serviceName'] ?? 'Appointment Service',
            'venueName': appointmentDetails['venueName'] ?? 'VIP Lounge',
            'latestMessage': message,
            'latestMessageSender': senderName,
            'latestMessageTimestamp': timestamp.toDate(),
            'unreadCount': senderId != _userId && !isRead ? 1 : 0,
          };
        } else {
          // Update latest message if this one is newer
          final existingTimestamp = conversationsMap[conversationKey]!['latestMessageTimestamp'] as DateTime;
          if (timestamp.toDate().isAfter(existingTimestamp)) {
            conversationsMap[conversationKey]!['latestMessage'] = message;
            conversationsMap[conversationKey]!['latestMessageSender'] = senderName;
            conversationsMap[conversationKey]!['latestMessageTimestamp'] = timestamp.toDate();
          }
          
          // Update unread count
          if (senderId != _userId && !isRead) {
            conversationsMap[conversationKey]!['unreadCount'] = 
                (conversationsMap[conversationKey]!['unreadCount'] as int) + 1;
          }
        }
      }
      
      // Convert to list and sort by latest message timestamp
      // More detailed logging about the conversations map
      print('DEBUG: Conversation map contains ${conversationsMap.length} unique conversation keys:');
      conversationsMap.forEach((key, value) {
        print('DEBUG: Conversation Key: $key');
        print('DEBUG: -> AppointmentId: ${value['appointmentId']}');
        print('DEBUG: -> MinisterName: ${value['ministerName']}');
        print('DEBUG: -> ServiceName: ${value['serviceName']}');
        print('DEBUG: -> Latest Message: ${value['latestMessage']}');
        print('DEBUG: -> Unread Count: ${value['unreadCount']}');
      });
      
      final List<Map<String, dynamic>> sortedConversations = conversationsMap.values.toList();
      sortedConversations.sort((a, b) {
        final DateTime timeA = a['latestMessageTimestamp'] as DateTime;
        final DateTime timeB = b['latestMessageTimestamp'] as DateTime;
        return timeB.compareTo(timeA);
      });
      
      print('DEBUG: Created ${sortedConversations.length} conversations');
      
      if (mounted) {
        setState(() {
          _conversations = sortedConversations;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('ERROR loading conversations: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _openChatDialog(Map<String, dynamic> conversation) {
    final String appointmentId = conversation['appointmentId'] ?? '';
    final String ministerName = conversation['ministerName'] ?? 'Unknown';
    
    print('Opening chat dialog for appointment: $appointmentId with minister: $ministerName');
    
    // Navigate to chat dialog
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FloorManagerChatDialog(conversation: conversation),
        fullscreenDialog: true,
      ),
    ).then((_) {
      // Refresh the list when returning from chat dialog
      _loadConversations();
    });
    
    // Mark messages as read
    _markMessagesAsRead(appointmentId);
  }
  
  Future<void> _markMessagesAsRead(String appointmentId) async {
    try {
      final unreadMessages = await _firestore
          .collection('chat_messages')
          .where('appointmentId', isEqualTo: appointmentId)
          .where('recipientId', isEqualTo: _userId)
          .where('isRead', isEqualTo: false)
          .get();
      
      for (var doc in unreadMessages.docs) {
        await doc.reference.update({'isRead': true});
      }
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }
  @override
  void initState() {
    super.initState();
    
    // Initialize after frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeUser();
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false, // Prevent keyboard from causing overflow
      appBar: AppBar(
        title: const Text('Messages', style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadConversations,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _conversations.isEmpty
              ? const Center(
                  child: Text(
                    'No conversations yet',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadConversations,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      children: _conversations.map((conversation) => 
                        _buildConversationItem(conversation)
                      ).toList(),
                    ),
                  ),
                ),
    );
  }
  
  // Updated to prevent overflow issues
  Widget _buildConversationItem(Map<String, dynamic> conversation) {
    final bool hasUnread = (conversation['unreadCount'] as int? ?? 0) > 0;
    final DateTime timestamp = conversation['latestMessageTimestamp'] as DateTime;
    
    // Format timestamp for display
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    String timeDisplay;
    if (difference.inDays == 0) {
      // Today - show time
      timeDisplay = DateFormat.jm().format(timestamp);
    } else if (difference.inDays < 7) {
      // This week - show day
      timeDisplay = DateFormat.E().format(timestamp);
    } else {
      // Older - show date
      timeDisplay = DateFormat.yMd().format(timestamp);
    }
    
    // Ensure we have valid strings for all text fields to prevent layout errors
    final String ministerName = (conversation['ministerName'] as String? ?? 'Unknown').trim();
    final String serviceName = (conversation['serviceName'] as String? ?? '').trim();
    final String venueName = (conversation['venueName'] as String? ?? '').trim();
    final String latestMessage = (conversation['latestMessage'] as String? ?? '').trim();
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Card(
        color: Colors.black54,
        elevation: 2,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _openChatDialog(conversation),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar circle
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: hasUnread ? AppColors.richGold : Colors.grey.shade400,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    (conversation['ministerName'] as String? ?? 'U').isNotEmpty
                        ? (conversation['ministerName'] as String).substring(0, 1).toUpperCase()
                        : 'U',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                
                // Message content - main column with all text content
                Expanded(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.1,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // First row: Name and time
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Name with unread indicator
                            Flexible(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  if (hasUnread)
                                    Container(
                                      margin: const EdgeInsets.only(right: 6),
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  Flexible(
                                    child: Text(
                                      ministerName, // Use pre-sanitized name
                                      style: TextStyle(
                                        fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                                        fontSize: 16,
                                        color: Colors.white,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            // Time
                            Padding(
                              padding: const EdgeInsets.only(left: 4.0),
                              child: Text(
                                timeDisplay,
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 4),
                        
                        // Service/venue info
                        Text(
                          // Use the pre-sanitized strings
                          serviceName.isNotEmpty && venueName.isNotEmpty
                              ? '$serviceName • $venueName'
                              : serviceName.isNotEmpty
                                  ? serviceName
                                  : venueName.isNotEmpty
                                      ? venueName
                                      : '',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        
                        const SizedBox(height: 6),
                        
                        // Last row: Message preview and unread count
                        // Wrapping in a ConstrainedBox to set max height and prevent overflow
                        ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxHeight: 60,  // Limit height to prevent overflow
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Message preview with sender prefix
                              Expanded(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Sender prefix
                                    Text(
                                      _getSenderPrefix(conversation['latestMessageSender']),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                  
                                    // Message text
                                    Expanded(
                                      child: Text(
                                        latestMessage,
                                        style: TextStyle(
                                          color: hasUnread ? Colors.white : Colors.grey.shade300,
                                          fontSize: 14,
                                          fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            
                              // Unread count badge (only shown if hasUnread)
                              if (hasUnread)
                                Container(
                                  margin: const EdgeInsets.only(left: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    conversation['unreadCount'].toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  String _getSenderPrefix(dynamic sender) {
    if (sender == null) return '';
    
    if (sender == 'Floor Manager' || 
        sender == _userId || 
        sender == 'You') {
      return 'You: ';
    } else {
      return '${sender is String ? sender : "Minister"}: ';
    }
  }
}
