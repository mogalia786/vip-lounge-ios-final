import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:vip_lounge/core/constants/colors.dart';
import 'package:vip_lounge/core/providers/app_auth_provider.dart';
import 'package:vip_lounge/core/services/vip_messaging_service.dart';
import 'package:vip_lounge/core/widgets/glass_card.dart';
import 'package:vip_lounge/features/minister/presentation/screens/minister_chat_dialog.dart';

class FloorManagerMessagesScreen extends StatefulWidget {
  const FloorManagerMessagesScreen({Key? key}) : super(key: key);

  @override
  _FloorManagerMessagesScreenState createState() => _FloorManagerMessagesScreenState();
}

class _FloorManagerMessagesScreenState extends State<FloorManagerMessagesScreen> {
  final VipMessagingService _messagingService = VipMessagingService();
  final DateFormat _dateFormat = DateFormat('MMM d, h:mm a');
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = Provider.of<AppAuthProvider>(context).appUser;
    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text('User not logged in')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {});  // Refresh the screen
            },
          ),
        ],
      ),
      body: _buildMessagesContent(currentUser.id),
    );
  }

  Widget _buildMessagesContent(String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
        .collection('appointments')
        .where('staff.floor_manager.id', isEqualTo: userId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots(),
      builder: (context, appointmentsSnapshot) {
        if (appointmentsSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (appointmentsSnapshot.hasError) {
          return Center(child: Text('Error: ${appointmentsSnapshot.error}'));
        }

        final appointments = appointmentsSnapshot.data?.docs ?? [];
        
        if (appointments.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.message, size: 64, color: AppColors.richGold),
                const SizedBox(height: 16),
                Text(
                  'No messages yet',
                  style: TextStyle(fontSize: 18, color: AppColors.primary),
                ),
              ],
            ),
          );
        }

        // Build a list of messages from appointments
        return _buildMessagesList(appointments);
      },
    );
  }

  Widget _buildMessagesList(List<QueryDocumentSnapshot> appointments) {
    return ListView.builder(
      controller: _scrollController,
      itemCount: appointments.length,
      itemBuilder: (context, index) {
        final appointmentData = appointments[index].data() as Map<String, dynamic>;
        final appointmentId = appointments[index].id;
        final ministerName = appointmentData['ministerName'] ?? 'Unknown Minister';
        final DateTime? appointmentTime = appointmentData['appointmentTime'] != null 
          ? (appointmentData['appointmentTime'] as Timestamp).toDate() 
          : null;
          
        // Get unread count for this appointment
        return FutureBuilder<int>(
          future: _getUnreadMessagesCount(appointmentId),
          builder: (context, unreadSnapshot) {
            final unreadCount = unreadSnapshot.data ?? 0;
            
            return GlassCard(
              onTap: () {
                _openChatDialog(context, appointmentId, ministerName);
              },
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    // Contact Avatar
                    CircleAvatar(
                      backgroundColor: AppColors.richGold,
                      child: Text(
                        ministerName.substring(0, 1).toUpperCase(),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 12),
                    
                    // Message info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Contact name
                              Text(
                                ministerName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              
                              // Time
                              Text(
                                appointmentTime != null 
                                  ? _dateFormat.format(appointmentTime)
                                  : 'No date',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          
                          // Last message preview (future enhancement)
                          Row(
                            children: [
                              Expanded(
                                child: FutureBuilder<String>(
                                  future: _getLastMessagePreview(appointmentId),
                                  builder: (context, previewSnapshot) {
                                    if (previewSnapshot.connectionState == ConnectionState.waiting) {
                                      return const Text('Loading...');
                                    }
                                    
                                    final preview = previewSnapshot.data ?? 'No messages yet';
                                    return Text(
                                      preview,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.grey[700],
                                      ),
                                    );
                                  },
                                ),
                              ),
                              
                              // Unread count badge
                              if (unreadCount > 0)
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    unreadCount.toString(),
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
            );
          },
        );
      },
    );
  }

  // Get unread messages count for a specific appointment
  Future<int> _getUnreadMessagesCount(String appointmentId) async {
    try {
      final currentUser = Provider.of<AppAuthProvider>(context, listen: false).appUser;
      if (currentUser == null) return 0;
      
      final query = await FirebaseFirestore.instance
        .collection('messages')
        .where('appointmentId', isEqualTo: appointmentId)
        .where('recipientId', isEqualTo: currentUser.id)
        .where('isRead', isEqualTo: false)
        .get();
        
      return query.docs.length;
    } catch (e) {
      print('Error getting unread count: $e');
      return 0;
    }
  }
  
  // Get the last message preview for a chat
  Future<String> _getLastMessagePreview(String appointmentId) async {
    try {
      final query = await FirebaseFirestore.instance
        .collection('messages')
        .where('appointmentId', isEqualTo: appointmentId)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();
        
      if (query.docs.isEmpty) {
        return 'No messages yet';
      }
      
      final lastMessage = query.docs.first.data();
      final messageText = lastMessage['message'] as String? ?? '';
      
      return messageText.length > 30 
          ? '${messageText.substring(0, 27)}...' 
          : messageText;
    } catch (e) {
      print('Error getting message preview: $e');
      return 'Error loading message';
    }
  }
  
  // Open chat dialog
  void _openChatDialog(BuildContext context, String appointmentId, String ministerName) {
    final currentUser = Provider.of<AppAuthProvider>(context, listen: false).appUser;
    if (currentUser == null) return;
    
    // Mark messages as read when opening the chat
    _messagingService.markAllMessagesAsRead(appointmentId, currentUser.id);
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: MinisterChatDialog(
          appointmentId: appointmentId,
          recipientName: ministerName,
          recipientRole: 'minister',
          isFloorManager: true,
        ),
      ),
    ).then((_) {
      // Refresh the list when dialog is closed
      setState(() {});
    });
  }
}
