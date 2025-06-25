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
  
  @override
  void initState() {
    super.initState();
    
    // Initialize after frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeUser();
    });
  }
  
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
      
      // Get all chat messages where this floor manager is a participant
      final messagesQuery = await _firestore
          .collection('chat_messages')
          .where('participants', arrayContains: _userId)
          .orderBy('timestamp', descending: true)
          .get();
      
      print('DEBUG: Found ${messagesQuery.docs.length} messages involving floor manager');
      
      // Group by appointments to create conversations
      final Map<String, Map<String, dynamic>> conversationsMap = {};
      
      for (var doc in messagesQuery.docs) {
        final data = doc.data();
        final String appointmentId = data['appointmentId'] ?? '';
        
        if (appointmentId.isEmpty) {
          print('DEBUG: Skipping message with empty appointmentId');
          continue;
        }
        
        final Timestamp timestamp = data['timestamp'] ?? Timestamp.now();
        final String message = data['message'] ?? 'No message content';
        final bool isRead = data['isRead'] ?? false;
        
        // Determine the conversation partner (the other person in the chat)
        final String senderId = data['senderId'] ?? '';
        final String senderName = data['senderName'] ?? 'Unknown';
        final String senderRole = data['senderRole'] ?? '';
        
        final String recipientId = data['recipientId'] ?? '';
        final String recipientName = data['recipientName'] ?? 'Unknown';
        
        // For conversations with ministers - log more detailed information
        print('DEBUG CHAT: Message has - senderId: $senderId, senderRole: $senderRole, recipientRole: ${data['recipientRole']}, appointmentId: $appointmentId');
          
        // Process all messages - temporarily removing filters to see what's available
        final String ministerId = senderId == _userId ? recipientId : senderId;
        final String ministerName = senderId == _userId ? recipientName : senderName;
        
        print('DEBUG CHAT: Processing message with ministerId: $ministerId and ministerName: $ministerName');
          
        // Create or update conversation
        if (!conversationsMap.containsKey(appointmentId)) {
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
          
          conversationsMap[appointmentId] = {
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
          final existingTimestamp = conversationsMap[appointmentId]!['latestMessageTimestamp'] as DateTime;
          if (timestamp.toDate().isAfter(existingTimestamp)) {
            conversationsMap[appointmentId]!['latestMessage'] = message;
            conversationsMap[appointmentId]!['latestMessageSender'] = senderName;
            conversationsMap[appointmentId]!['latestMessageTimestamp'] = timestamp.toDate();
          }
          
          // Update unread count
          if (senderId != _userId && !isRead) {
            conversationsMap[appointmentId]!['unreadCount'] = 
                (conversationsMap[appointmentId]!['unreadCount'] as int) + 1;
          }
        }
      }
      
      // Convert to list and sort by latest message timestamp
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
  Widget build(BuildContext context) {
    return Scaffold(
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
                  child: ListView.builder(
                    itemCount: _conversations.length,
                    itemBuilder: (context, index) {
                      final conversation = _conversations[index];
                      return _buildConversationItem(conversation);
                    },
                  ),
                ),
    );
  }
  
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
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: GlassCard(
        child: InkWell(
          onTap: () => _openChatDialog(conversation),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar circle
                Container(
                  width: 50,
                  height: 50,
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
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                
                // Message content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // First row: Name and time
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Name with unread indicator
                          Flexible(
                            child: Row(
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
                                    conversation['ministerName'] as String? ?? 'Unknown',
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
                          Text(
                            timeDisplay,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 4),
                      
                      // Service/venue info
                      Text(
                        '${conversation['serviceName'] ?? ''} • ${conversation['venueName'] ?? ''}',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      const SizedBox(height: 6),
                      
                      // Message preview with sender prefix
                      Row(
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
                              conversation['latestMessage'] as String? ?? '',
                              style: TextStyle(
                                color: hasUnread ? Colors.white : Colors.grey.shade300,
                                fontSize: 14,
                                fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          
                          // Unread count badge
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
                    ],
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
