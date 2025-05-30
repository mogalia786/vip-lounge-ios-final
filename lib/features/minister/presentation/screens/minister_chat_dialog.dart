import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/providers/app_auth_provider.dart';

class MinisterChatDialog extends StatelessWidget {
  final Map<String, dynamic> appointment;
  const MinisterChatDialog({Key? key, required this.appointment}) : super(key: key);

  String _getRoleTitle(String? role) {
    switch (role) {
      case 'consultant':
        return 'Consultant';
      case 'concierge':
        return 'Concierge';
      case 'floor_manager':
        return 'Floor Manager';
      case 'cleaner':
        return 'Cleaner';
      default:
        return 'Staff';
    }
  }

  @override
  Widget build(BuildContext context) {
    final appointmentId = appointment['id'] as String? ?? '';
    String recipientId = '';
    String recipientName = '';
    String recipientRole = '';

    if (appointment.containsKey('selectedRole') && appointment['selectedRole'] != null) {
      final selectedRole = appointment['selectedRole'];
      switch (selectedRole) {
        case 'consultant':
          recipientId = appointment['consultantId'] ?? '';
          recipientName = appointment['consultantName'] ?? 'Consultant';
          recipientRole = 'consultant';
          break;
        case 'concierge':
          recipientId = appointment['conciergeId'] ?? '';
          recipientName = appointment['conciergeName'] ?? 'Concierge';
          recipientRole = 'concierge';
          break;
        case 'floor_manager':
          recipientId = appointment['floorManagerId'] ?? '';
          recipientName = appointment['floorManagerName'] ?? 'Floor Manager';
          recipientRole = 'floor_manager';
          break;
        case 'cleaner':
          recipientId = appointment['cleanerId'] ?? '';
          recipientName = appointment['cleanerName'] ?? 'Cleaner';
          recipientRole = 'cleaner';
          break;
        default:
          recipientId = '';
          recipientName = 'Staff';
          recipientRole = 'staff';
          break;
      }
    }

    final Color roleColor = {
      'floor_manager': Colors.red,
      'consultant': Colors.blue,
      'concierge': Colors.green,
      'cleaner': Colors.orange,
      'default': Colors.grey,
    }[recipientRole] ?? Colors.grey;

    final TextEditingController textController = TextEditingController();
    String messageText = '';

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      backgroundColor: Colors.transparent,
      child: StatefulBuilder(
        builder: (context, setState) {
          return Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.black,
              title: Text(
                'Chat with ${_getRoleTitle(recipientRole)} $recipientName',
                style: TextStyle(
                  color: AppColors.gold,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              leading: IconButton(
                icon: Icon(Icons.close, color: AppColors.gold),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            body: Column(
              children: [

                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('messages')
                        .where('appointmentId', isEqualTo: appointmentId)
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final messages = snapshot.data?.docs ?? [];
                      final user = Provider.of<AppAuthProvider>(context, listen: false).appUser;
                      if (user == null) {
                        return const Center(
                          child: Text('User not authenticated', style: TextStyle(color: Colors.red)),
                        );
                      }
                      if (messages.isEmpty) {
                        return Center(
                          child: Text(
                            'No messages yet. Start the conversation!',
                            style: TextStyle(color: Colors.grey),
                          ),
                        );
                      }
                      return ListView.builder(
                        reverse: true,
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index].data() as Map<String, dynamic>;
                          final senderId = message['senderId'];
                          final senderName = message['senderName'];
                          final senderRole = message['senderRole'] ?? recipientRole;
                          final messageContent = message['message'];
                          final timestamp = message['timestamp'] as Timestamp?;
                          final isSentByCurrentUser = senderId == user.uid;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                            child: Row(
                              mainAxisAlignment: isSentByCurrentUser
                                  ? MainAxisAlignment.end
                                  : MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!isSentByCurrentUser)
                                  CircleAvatar(
                                    backgroundColor: roleColor,
                                    radius: 16,
                                    child: Text(
                                      senderName?.isNotEmpty == true
                                          ? senderName[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                if (!isSentByCurrentUser)
                                  const SizedBox(width: 8),
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isSentByCurrentUser
                                          ? AppColors.gold.withOpacity(0.2)
                                          : Colors.grey[800],
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (!isSentByCurrentUser)
                                          Padding(
                                            padding: const EdgeInsets.only(bottom: 4.0),
                                            child: Row(
                                              children: [
                                                Text(
                                                  senderName ?? 'Unknown',
                                                  style: TextStyle(
                                                    color: roleColor,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: roleColor.withOpacity(0.2),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Text(
                                                    _getRoleTitle(senderRole),
                                                    style: TextStyle(
                                                      color: roleColor,
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        Text(
                                          messageContent ?? 'No message content',
                                          style: const TextStyle(
                                            color: Colors.white,
                                          ),
                                        ),
                                        if (timestamp != null)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 4),
                                            child: Text(
                                              DateFormat('MMM d, yyyy · hh:mm a').format(timestamp.toDate()),
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
                                if (isSentByCurrentUser) const SizedBox(width: 8),
                                if (isSentByCurrentUser)
                                  CircleAvatar(
                                    backgroundColor: AppColors.gold,
                                    radius: 16,
                                    child: Text(
                                      user.name?.isNotEmpty == true
                                          ? user.name!.characters.first.toUpperCase()
                                          : 'M',
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.bold,
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    border: Border(
                      top: BorderSide(color: Colors.grey.withOpacity(0.3)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.grey[800],
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: TextField(
                            controller: textController,
                            onChanged: (value) {
                              messageText = value;
                            },
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              hintText: 'Type a message...',
                              hintStyle: TextStyle(color: Colors.grey),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.send, color: AppColors.gold),
                        onPressed: () {
                          String text = textController.text.trim();
                          if (text.isNotEmpty) {
                            Navigator.pop(context);
                            // The parent should handle sending the message after closing the dialog
                            // You may want to use a callback or event for this
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
