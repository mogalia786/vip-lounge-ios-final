import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/app_auth_provider.dart';
import '../../../../core/constants/colors.dart';

class AppointmentsScreen extends StatelessWidget {
  const AppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AppAuthProvider>(context).appUser;

    if (user == null) {
      return const Center(child: Text('User not found'));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'My Appointments',
          style: TextStyle(color: AppColors.gold),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('appointments')
            .where('status', whereIn: ['assigned', 'in_progress'])
            .orderBy('appointmentTime', descending: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.white),
              ),
            );
          }

          if (!snapshot.hasData) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.gold),
              ),
            );
          }

          final appointments = snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {
              ...data,
              'id': doc.id,
              'docId': doc.id,
            };
          }).where((doc) {
            return doc['assignedToId'] == user.uid || 
                   (doc['role'] == user.role && doc['assignedToId'] == null);
          }).toList();

          if (appointments.isEmpty) {
            return const Center(
              child: Text(
                'No appointments scheduled',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          return ListView.builder(
            itemCount: appointments.length,
            itemBuilder: (context, index) {
              final appointment = appointments[index];
              final appointmentId = appointment['id'];
              final appointmentTime = DateTime.parse(appointment['appointmentTime'] ?? DateTime.now().toIso8601String());
              final ministerFirstName = appointment['ministerFirstName'] ?? 'Unknown';
              final ministerLastName = appointment['ministerLastName'] ?? '';
              final ministerName = '$ministerFirstName $ministerLastName'.trim();
              final ministerEmail = appointment['ministerEmail'] ?? 'No email provided';
              final ministerPhone = appointment['ministerPhone'] ?? 'No phone provided';
              
              // Get assigned staff
              final consultantId = appointment['consultantId'] ?? '';
              final consultantName = appointment['consultantName'] ?? 'Not assigned';
              final cleanerId = appointment['cleanerId'] ?? '';
              final cleanerName = appointment['cleanerName'] ?? 'Not assigned';
              final conciergeId = appointment['conciergeId'] ?? '';
              final conciergeName = appointment['conciergeName'] ?? 'Not assigned';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.grey[900],
                child: ExpansionTile(
                  title: Text(
                    ministerName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    DateFormat('EEEE, MMMM d, y').format(appointmentTime),
                    style: const TextStyle(color: Colors.white70),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: appointmentTime.isAfter(DateTime.now())
                          ? Colors.blue.withOpacity(0.2)
                          : Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      appointmentTime.isAfter(DateTime.now())
                          ? Icons.upcoming
                          : Icons.event_available,
                      color: appointmentTime.isAfter(DateTime.now())
                          ? Colors.blue
                          : Colors.green,
                    ),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(color: Colors.white24),
                          Text(
                            'Minister Details',
                            style: TextStyle(
                              color: AppColors.gold,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Email: $ministerEmail',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          Text(
                            'Phone: $ministerPhone',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Appointment Details',
                            style: TextStyle(
                              color: AppColors.gold,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Time: ${DateFormat('h:mm a').format(appointmentTime)}',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          Text(
                            'Service: ${appointment['serviceName'] ?? 'Unknown'}',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          if (appointment['serviceCategory'] != null)
                            Text(
                              'Category: ${appointment['serviceCategory']}',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          if (appointment['subServiceName'] != null)
                            Text(
                              'Sub-Service: ${appointment['subServiceName']}',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          Text(
                            'Venue: ${appointment['venueName'] ?? 'Unknown'}',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          Text(
                            'Duration: ${appointment['duration'] ?? 'Unknown'} minutes',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          
                          // Staff Assignment Section
                          const SizedBox(height: 16),
                          const Divider(color: Colors.white24),
                          Text(
                            'Staff Assignment',
                            style: TextStyle(
                              color: AppColors.gold,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          
                          // Minister Chat Button
                          if (user.role != 'minister')
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.chat, color: Colors.black),
                                label: const Text(
                                  'Chat with Minister',
                                  style: TextStyle(color: Colors.black),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.gold,
                                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                ),
                                onPressed: () {
                                  _openChatDialog(
                                    context,
                                    appointmentId,
                                    appointment,
                                    'minister',
                                  );
                                },
                              ),
                            ),
                          
                          // Consultant - Separate standalone container
                          if (consultantId.isNotEmpty && user.role != 'consultant')
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: Colors.grey[850],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue.withOpacity(0.5), width: 1),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: Colors.blue,
                                    radius: 16,
                                    child: Text(
                                      consultantName.isNotEmpty ? consultantName.substring(0, 1).toUpperCase() : 'C',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Consultant: ',
                                    style: TextStyle(color: Colors.grey[400], fontSize: 14),
                                  ),
                                  Expanded(
                                    child: Text(
                                      consultantName,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.chat, color: Colors.blue),
                                    onPressed: () {
                                      _openChatDialog(
                                        context,
                                        appointmentId,
                                        appointment,
                                        'consultant',
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          
                          // Cleaner - Separate standalone container
                          if (cleanerId.isNotEmpty && user.role != 'cleaner')
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: Colors.grey[850],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.teal.withOpacity(0.5), width: 1),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: Colors.teal,
                                    radius: 16,
                                    child: Text(
                                      cleanerName.isNotEmpty ? cleanerName.substring(0, 1).toUpperCase() : 'C',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Cleaner: ',
                                    style: TextStyle(color: Colors.grey[400], fontSize: 14),
                                  ),
                                  Expanded(
                                    child: Text(
                                      cleanerName,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.chat, color: Colors.teal),
                                    onPressed: () {
                                      _openChatDialog(
                                        context,
                                        appointmentId,
                                        appointment,
                                        'cleaner',
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          
                          // Concierge - Separate standalone container
                          if (conciergeId.isNotEmpty && user.role != 'concierge')
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: Colors.grey[850],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.purple.withOpacity(0.5), width: 1),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: Colors.purple,
                                    radius: 16,
                                    child: Text(
                                      conciergeName.isNotEmpty ? conciergeName.substring(0, 1).toUpperCase() : 'C',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Concierge: ',
                                    style: TextStyle(color: Colors.grey[400], fontSize: 14),
                                  ),
                                  Expanded(
                                    child: Text(
                                      conciergeName,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.chat, color: Colors.purple),
                                    onPressed: () {
                                      _openChatDialog(
                                        context,
                                        appointmentId,
                                        appointment,
                                        'concierge',
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
  
  // Chat dialog function
  void _openChatDialog(BuildContext context, String appointmentId, Map<String, dynamic> appointment, String chatWithRole) {
    // Determine user details based on role
    String userId;
    String userName;
    
    if (chatWithRole == 'minister') {
      userId = appointment['ministerId'] ?? '';
      userName = appointment['ministerName'] ?? 'Minister';
    } else if (chatWithRole == 'consultant') {
      userId = appointment['consultantId'] ?? '';
      userName = appointment['consultantName'] ?? 'Consultant';
    } else if (chatWithRole == 'cleaner') {
      userId = appointment['cleanerId'] ?? '';
      userName = appointment['cleanerName'] ?? 'Cleaner';
    } else if (chatWithRole == 'concierge') {
      userId = appointment['conciergeId'] ?? '';
      userName = appointment['conciergeName'] ?? 'Concierge';
    } else {
      // Default fallback
      userId = '';
      userName = 'Unknown';
    }
    
    if (userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('No $chatWithRole ID found for this appointment'),
        backgroundColor: Colors.red,
      ));
      return;
    }
    
    // Get current user ID from provider
    final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
    final currentUserId = authProvider.appUser?.uid ?? '';
    final currentUserRole = authProvider.appUser?.role ?? '';
    final currentUserName = authProvider.appUser?.displayName ?? 'User';
    
    if (currentUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('You must be logged in to send messages'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    final messageController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.black,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Chat with $userName',
                style: TextStyle(color: AppColors.gold),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
          content: Container(
            width: double.maxFinite,
            height: 400,
            child: Column(
              children: [
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('appointments')
                        .doc(appointmentId)
                        .collection('messages')
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
                      }
                      
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(
                          child: Text(
                            'No messages yet. Start the conversation!',
                            style: TextStyle(color: Colors.grey),
                          ),
                        );
                      }
                      
                      // Get all messages from this appointment
                      final messages = snapshot.data!.docs;
                      List<QueryDocumentSnapshot> filteredMessages = [];
                      
                      if (chatWithRole == 'minister') {
                        // For minister chat, show ALL messages from all roles
                        filteredMessages = messages;
                      } else {
                        // For other roles (consultant, cleaner, concierge),
                        // ONLY show messages between current user and this specific role
                        filteredMessages = messages.where((msg) {
                          final data = msg.data() as Map<String, dynamic>;
                          final msgSenderId = data['senderId'] ?? '';
                          final msgReceiverId = data['receiverId'] ?? '';
                          
                          // Either: current user sent to this staff OR this staff sent to current user
                          final isConversationBetweenThisStaffAndCurrentUser = 
                              (msgSenderId == currentUserId && msgReceiverId == userId) ||
                              (msgSenderId == userId && msgReceiverId == currentUserId);
                              
                          return isConversationBetweenThisStaffAndCurrentUser;
                        }).toList();
                      }
                      
                      if (filteredMessages.isEmpty) {
                        return const Center(
                          child: Text(
                            'No messages yet between you and this person.\nStart the conversation!',
                            style: TextStyle(color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        );
                      }
                      
                      return ListView.builder(
                        reverse: true,
                        itemCount: filteredMessages.length,
                        itemBuilder: (context, index) {
                          final messageDoc = filteredMessages[index];
                          final messageData = messageDoc.data() as Map<String, dynamic>;
                          
                          final senderId = messageData['senderId'] ?? '';
                          final senderName = messageData['senderName'] ?? 'Unknown';
                          final isCurrentUser = senderId == currentUserId;
                          final timestamp = messageData['timestamp'] as Timestamp?;
                          final messageTime = timestamp != null
                              ? DateFormat('MMM d, h:mm a').format(timestamp.toDate())
                              : 'Just now';
                          
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              mainAxisAlignment: isCurrentUser
                                  ? MainAxisAlignment.end
                                  : MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!isCurrentUser)
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: Colors.orange,
                                    child: Text(
                                      senderName.isNotEmpty
                                          ? senderName.substring(0, 1).toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12),
                                    ),
                                  ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isCurrentUser
                                          ? AppColors.gold.withOpacity(0.9)
                                          : Colors.grey[800],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (!isCurrentUser)
                                          Padding(
                                            padding: const EdgeInsets.only(bottom: 4),
                                            child: Text(
                                              senderName,
                                              style: const TextStyle(
                                                color: Colors.lightBlue,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        Text(
                                          messageData['content'] ?? '',
                                          style: TextStyle(
                                            color: isCurrentUser ? Colors.black : Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Align(
                                          alignment: Alignment.bottomRight,
                                          child: Text(
                                            messageTime,
                                            style: TextStyle(color: Colors.grey[400], fontSize: 10),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (isCurrentUser)
                                  CircleAvatar(
                                    backgroundColor: Colors.blue,
                                    radius: 16,
                                    child: Text(
                                      currentUserRole.isNotEmpty ? currentUserRole.substring(0, 1).toUpperCase() : 'U',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
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
                const Divider(color: Colors.grey),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: messageController,
                          decoration: const InputDecoration(
                            hintText: 'Type a message...',
                            hintStyle: TextStyle(color: Colors.grey),
                            border: InputBorder.none,
                          ),
                          style: const TextStyle(color: Colors.white),
                          maxLines: 3,
                          minLines: 1,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send, color: Colors.white),
                        onPressed: () {
                          if (messageController.text.trim().isNotEmpty) {
                            _sendChatMessage(appointmentId, messageController.text.trim(), userId, currentUserId, currentUserName);
                            messageController.clear();
                          }
                        },
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
  }
  
  // Send chat message
  Future<void> _sendChatMessage(String appointmentId, String text, String receiverId, String senderId, String senderName) async {
    try {
      final messageData = {
        'content': text,
        'senderId': senderId,
        'senderName': senderName,
        'receiverId': receiverId,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      };
      
      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(appointmentId)
          .collection('messages')
          .add(messageData);
          
      // Create notification for the receiver
      await FirebaseFirestore.instance.collection('notifications').add({
        'title': 'New Message',
        'body': 'You have a new message from $senderName',
        'type': 'chat_message',
        'appointmentId': appointmentId,
        'senderId': senderId,
        'receiverId': receiverId,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'sendAsPushNotification': true,
      });
    } catch (e) {
      print('Error sending message: $e');
    }
  }
}
