import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../shared/presentation/screens/message_inbox_screen.dart';
import '../../../../core/providers/app_auth_provider.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/models/chat_message.dart';
import '../../../../core/services/chat_service.dart';

class MinisterInboxScreen extends StatefulWidget {
  final Map<String, dynamic>? chatParams;

  const MinisterInboxScreen({Key? key, this.chatParams}) : super(key: key);

  @override
  _MinisterInboxScreenState createState() => _MinisterInboxScreenState();
}

class _MinisterInboxScreenState extends State<MinisterInboxScreen> with TickerProviderStateMixin {
  final ChatService _chatService = ChatService();
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // If we have specific chat parameters, go directly to the conversation
    if (widget.chatParams != null && widget.chatParams!.containsKey('appointmentId')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MessageInboxScreen(chatParams: widget.chatParams),
          ),
        );
      });
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
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
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.richGold,
          tabs: const [
            Tab(text: 'Appointments'),
            Tab(text: 'All Messages'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAppointmentsTab(currentUser.id),
          _buildAllMessagesTab(currentUser.id),
        ],
      ),
    );
  }

  Widget _buildAppointmentsTab(String userId) {
    return StreamBuilder<Map<String, dynamic>>(
      stream: _chatService.getUserMessagedAppointments(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final appointments = snapshot.data ?? {};
        if (appointments.isEmpty) {
          return const Center(child: Text('No messages yet'));
        }

        // Sort appointments by last message time
        final sortedAppointments = appointments.values.toList()
          ..sort((a, b) => (b['lastMessageTime'] as DateTime)
              .compareTo(a['lastMessageTime'] as DateTime));

        return ListView.builder(
          itemCount: sortedAppointments.length,
          itemBuilder: (context, index) {
            final appointment = sortedAppointments[index];
            final hasUnread = appointment['unreadCount'] > 0;

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ListTile(
                title: Text(
                  appointment['appointmentTitle'] ?? 'Appointment',
                  style: TextStyle(
                    fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                subtitle: Text(
                  '${appointment['lastMessage'] ?? 'No messages'}\n'
                  'From: ${appointment['senderName'] ?? 'Staff'}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: hasUnread
                    ? Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${appointment['unreadCount']}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      )
                    : null,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MessageInboxScreen(
                        chatParams: {
                          'appointmentId': appointment['appointmentId'],
                          'appointmentTitle': appointment['appointmentTitle'],
                        },
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAllMessagesTab(String userId) {
    return StreamBuilder<List<ChatMessage>>(
      stream: _chatService.getUserMessages(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final messages = snapshot.data ?? [];
        if (messages.isEmpty) {
          return const Center(child: Text('No messages yet'));
        }

        return ListView.builder(
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[index];
            
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ListTile(
                title: Text(
                  message.senderName,
                  style: TextStyle(
                    fontWeight: !message.isRead ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.message,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Re: ${message.appointmentTitle ?? 'Appointment'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                trailing: !message.isRead
                    ? Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      )
                    : null,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MessageInboxScreen(
                        chatParams: {
                          'appointmentId': message.appointmentId,
                          'senderId': message.senderId,
                          'senderName': message.senderName,
                          'senderRole': message.senderRole,
                          'recipientId': message.recipientId,
                          'recipientName': message.recipientName,
                          'recipientRole': message.recipientRole,
                        },
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
