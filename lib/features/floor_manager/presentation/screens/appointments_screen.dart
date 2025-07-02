import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/providers/app_auth_provider.dart';

class AppointmentsScreen extends StatefulWidget {
  final DateTime? initialDate;
  
  const AppointmentsScreen({super.key, this.initialDate});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  late DateTime _selectedDate;
  bool _isAssigning = false;
  String? _currentAppointmentId;
  final NotificationService _notificationService = NotificationService();
  
  @override
  void initState() {
    super.initState();
    // Use the provided date or default to today
    _selectedDate = widget.initialDate ?? DateTime.now();
  }
  
  @override
  void didUpdateWidget(AppointmentsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update selected date if it changes from parent
    if (widget.initialDate != null && widget.initialDate != _selectedDate) {
      setState(() {
        _selectedDate = widget.initialDate!;
      });
    }
  }

  // Helper method for building info rows
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'rescheduled':
        return Colors.orange;
      case 'pending':
      default:
        return Colors.amber;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      case 'rescheduled':
        return 'Rescheduled';
      case 'pending':
      default:
        return 'Pending';
    }
  }
  
  Color _getAvatarColor(String userId) {
    final Map<String, Color> roleColors = {
      'minister': Colors.green, 
      'consultant': Colors.blue, 
      'cleaner': Colors.teal, 
      'concierge': Colors.purple,
    };
    
    // Default fallback color
    return roleColors[userId] ?? Colors.orange;
  }

  // Chat dialog for communicating with ministers and staff
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
    
    // Get floor manager ID from provider
    final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
    final floorManagerId = authProvider.appUser?.uid ?? '';
    
    if (floorManagerId.isEmpty) {
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
                style: TextStyle(color: AppColors.primary),
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
                      
                      final messages = snapshot.data!.docs;
                      List<QueryDocumentSnapshot> filteredMessages = [];
                      
                      if (chatWithRole == 'minister') {
                        // For ministers, show all messages
                        filteredMessages = messages;
                      } else {
                        // For other roles, only show messages between the floor manager and this specific role
                        filteredMessages = messages.where((msg) {
                          final data = msg.data() as Map<String, dynamic>;
                          return (data['senderId'] == userId && data['receiverId'] == floorManagerId) ||
                                 (data['senderId'] == floorManagerId && data['receiverId'] == userId);
                        }).toList();
                      }
                      
                      return ListView.builder(
                        reverse: true,
                        itemCount: filteredMessages.length,
                        itemBuilder: (context, index) {
                          final messageDoc = filteredMessages[index];
                          final messageData = messageDoc.data() as Map<String, dynamic>;
                          
                          final senderId = messageData['senderId'] ?? '';
                          final senderName = messageData['senderName'] ?? 'Unknown';
                          final isCurrentUser = senderId == floorManagerId;
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
                                    backgroundColor: _getAvatarColor(messageData['senderId']),
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
                                          ? AppColors.primary.withOpacity(0.9)
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
                                              style: TextStyle(
                                                color: _getAvatarColor(messageData['senderId']),
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
                                    child: const Text(
                                      'FM',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
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
                Divider(color: Colors.grey[700]),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: messageController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Type your message...',
                          hintStyle: TextStyle(color: Colors.grey[500]),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(color: Colors.grey[700]!),
                          ),
                          filled: true,
                          fillColor: Colors.grey[800],
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        maxLines: 3,
                        minLines: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      backgroundColor: AppColors.primary,
                      child: IconButton(
                        icon: const Icon(Icons.send, color: Colors.black),
                        onPressed: () async {
                          final messageText = messageController.text.trim();
                          if (messageText.isEmpty) return;
                          
                          messageController.clear();
                          
                          try {
                            // Add message to Firestore
                            await FirebaseFirestore.instance
                              .collection('appointments')
                              .doc(appointmentId)
                              .collection('messages')
                              .add({
                                'content': messageText,
                                'senderId': floorManagerId,
                                'senderName': 'Floor Manager',
                                'receiverId': userId,
                                'receiverName': userName,
                                'timestamp': FieldValue.serverTimestamp(),
                                'read': false,
                              });
                            
                            // Notify the recipient with an FCM message
                            final userDoc = await FirebaseFirestore.instance
                              .collection('users')
                              .doc(userId)
                              .get();
                            
                            if (userDoc.exists) {
                              final userToken = userDoc.data()?['fcmToken'];
                              if (userToken != null) {
                                final notificationData = {
                                  'appointmentId': appointmentId,
                                  'messageType': 'chat',
                                  'senderId': floorManagerId,
                                  'senderName': 'Floor Manager',
                                };
                                
                                try {
                                  await FirebaseMessaging.instance.sendMessage(
                                    to: userToken,
                                    data: Map<String, String>.from(
                                        notificationData.map((key, value) => MapEntry(key, value.toString()))),
                                    messageId: 'chat_${appointmentId}_${DateTime.now().millisecondsSinceEpoch}',
                                    collapseKey: 'chat_${appointmentId}',
                                  );
                                } catch (e) {
                                  print('Error sending FCM message: $e');
                                }
                              }
                            }
                            
                          } catch (e) {
                            print('Error sending message: $e');
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error sending message: $e')),
                              );
                            }
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWeeklySchedule() {
    // Calculate the start of the current week (Monday)
    final now = DateTime.now();
    final currentWeekStart = now.subtract(Duration(days: now.weekday - 1));
    
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              'This Week',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: List.generate(7, (index) {
                final day = currentWeekStart.add(Duration(days: index));
                final isSelected = day.year == _selectedDate.year &&
                    day.month == _selectedDate.month &&
                    day.day == _selectedDate.day;
                final isToday = day.year == now.year &&
                    day.month == now.month &&
                    day.day == now.day;
                
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDate = day;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4.0),
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : isToday
                              ? AppColors.primary.withOpacity(0.3)
                              : Colors.grey[900],
                      borderRadius: BorderRadius.circular(16.0),
                      border: isToday && !isSelected
                          ? Border.all(color: AppColors.primary, width: 1.0)
                          : null,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          DateFormat('E').format(day),
                          style: TextStyle(
                            color: isSelected ? Colors.black : Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4.0),
                        Text(
                          DateFormat('d').format(day),
                          style: TextStyle(
                            color: isSelected ? Colors.black : Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentsList() {
    // Format the selected date for the Firestore query
    final selectedDateStart = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    
    final selectedDateEnd = selectedDateStart.add(const Duration(days: 1));
    
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('date', isGreaterThanOrEqualTo: selectedDateStart)
          .where('date', isLessThan: selectedDateEnd)
          .orderBy('date')
          .orderBy('timeSlot')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          );
        }
        
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }
        
        final appointments = snapshot.data?.docs ?? [];
        
        if (appointments.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.event_busy,
                  size: 72,
                  color: Colors.grey[700],
                ),
                const SizedBox(height: 16),
                Text(
                  'No appointments for ${DateFormat('EEEE, MMMM d').format(_selectedDate)}',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }
        
        return ListView.builder(
          itemCount: appointments.length,
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          itemBuilder: (context, index) {
            final appointmentDoc = appointments[index];
            final appointment = appointmentDoc.data() as Map<String, dynamic>;
            final appointmentId = appointmentDoc.id;
            
            // Extract appointment details
            final ministerName = appointment['ministerName'] ?? 'Unknown';
            final ministerEmail = appointment['ministerEmail'] ?? 'N/A';
            final serviceType = appointment['serviceType'] ?? 'Standard';
            final notes = appointment['notes'] ?? 'No notes';
            final timeSlot = appointment['timeSlot'] ?? 'No time specified';
            final status = appointment['status'] ?? 'pending';
            
            // Extract assigned staff
            final consultantName = appointment['consultantName'] ?? 'Not assigned';
            final consultantId = appointment['consultantId'] ?? '';
            final cleanerName = appointment['cleanerName'] ?? 'Not assigned';
            final cleanerId = appointment['cleanerId'] ?? '';
            final conciergeName = appointment['conciergeName'] ?? 'Not assigned';
            final conciergeId = appointment['conciergeId'] ?? '';
            
            // Status colors
            final statusColor = _getStatusColor(status);
            final statusText = _getStatusText(status);
            
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              color: Colors.grey[900],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                childrenPadding: const EdgeInsets.only(
                  left: 16.0,
                  right: 16.0,
                  bottom: 16.0,
                ),
                title: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.primary,
                      child: Text(
                        ministerName.isNotEmpty
                            ? ministerName.substring(0, 1).toUpperCase()
                            : 'M',
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12.0),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ministerName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            timeSlot,
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8.0,
                        vertical: 4.0,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(
                          color: statusColor,
                          width: 1.0,
                        ),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    serviceType,
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                trailing: const Icon(
                  Icons.expand_more,
                  color: Colors.white,
                ),
                children: [
                  // Appointment Details
                  _buildInfoRow('Minister:', ministerName),
                  _buildInfoRow('Email:', ministerEmail),
                  _buildInfoRow('Service:', serviceType),
                  _buildInfoRow('Time:', timeSlot),
                  _buildInfoRow('Status:', statusText),
                  _buildInfoRow('Notes:', notes),
                  
                  const Divider(color: Colors.grey),
                  
                  // Staff Assignment Section
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'Staff Assignment',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  
                  // Consultant Assignment
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: _buildInfoRow(
                          'Consultant:',
                          consultantName,
                        ),
                      ),
                      if (consultantId.isNotEmpty)
                        IconButton(
                          icon: const Icon(
                            Icons.chat,
                            color: Colors.blue,
                          ),
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
                  
                  // Cleaner Assignment
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: _buildInfoRow(
                          'Cleaner:',
                          cleanerName,
                        ),
                      ),
                      if (cleanerId.isNotEmpty)
                        IconButton(
                          icon: const Icon(
                            Icons.chat,
                            color: Colors.teal,
                          ),
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
                  
                  // Concierge Assignment
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: _buildInfoRow(
                          'Concierge:',
                          conciergeName,
                        ),
                      ),
                      if (conciergeId.isNotEmpty)
                        IconButton(
                          icon: const Icon(
                            Icons.chat,
                            color: Colors.purple,
                          ),
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
                  
                  // Minister Chat Button
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.chat, color: Colors.black),
                      label: const Text(
                        'Chat with Minister',
                        style: TextStyle(color: Colors.black),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
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
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          'Appointments for ${DateFormat('MMMM d, yyyy').format(_selectedDate)}',
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          _buildWeeklySchedule(),
          Expanded(
            child: _buildAppointmentsList(),
          ),
        ],
      ),
    );
  }
}