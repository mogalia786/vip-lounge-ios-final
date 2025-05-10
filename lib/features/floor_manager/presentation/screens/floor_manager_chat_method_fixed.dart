import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:vip_lounge/core/constants/colors.dart';

void _showChatDialogWithData(BuildContext context, String appointmentId, 
      Map<String, dynamic> appointment, String ministerId, TextEditingController messageController) {
    // Get minister name from various possible fields
    String ministerName = 'Minister';
    if (appointment.containsKey('ministerName') && appointment['ministerName'] != null && appointment['ministerName'].toString().trim().isNotEmpty) {
      ministerName = appointment['ministerName'];
    } else if (appointment.containsKey('ministerFirstName') && appointment.containsKey('ministerLastName')) {
      final firstName = appointment['ministerFirstName'];
      final lastName = appointment['ministerLastName'];
      
      if (firstName != null && lastName != null) {
        ministerName = '$firstName $lastName';
      } else if (firstName != null) {
        ministerName = firstName;
      } else if (lastName != null) {
        ministerName = lastName;
      }
    }
    
    // Get minister email and phone if available
    final ministerEmail = appointment['ministerEmail'] ?? 'No email provided';
    final ministerPhone = appointment['ministerPhone'] ?? 'No phone provided';
    
    // Get appointment details for display
    DateTime appointmentTime;
    if (appointment.containsKey('appointmentTime')) {
      final appointmentTimeData = appointment['appointmentTime'];
      
      if (appointmentTimeData is Timestamp) {
        appointmentTime = appointmentTimeData.toDate();
      } else if (appointmentTimeData is String) {
        try {
          // Try to parse ISO 8601 format
          appointmentTime = DateTime.parse(appointmentTimeData);
        } catch (e) {
          print('Error parsing appointment time string: $e');
          appointmentTime = DateTime.now();  // fallback
        }
      } else {
        print('Appointment time is neither Timestamp nor String: ${appointmentTimeData.runtimeType}');
        appointmentTime = DateTime.now();  // fallback
      }
    } else {
      appointmentTime = DateTime.now();  // fallback
    }
    
    final appointmentDateFormatted = DateFormat('MMM d, yyyy').format(appointmentTime);
    final appointmentTimeFormatted = DateFormat('h:mm a').format(appointmentTime);
    
    // Get service and venue names
    final serviceName = appointment['serviceName'] ?? 'Unknown Service';
    final venueName = appointment['venueName'] ?? 'Unknown Venue';
    
    // Print debug info about the appointment
    print('Opening chat for appointment: $appointmentId');
    print('Minister ID: $ministerId');
    print('Minister Name: $ministerName');
    print('Staff assigned: Consultant: ${appointment['consultantId'] ?? 'None'}, Cleaner: ${appointment['cleanerId'] ?? 'None'}, Concierge: ${appointment['conciergeId'] ?? 'None'}');
    
    // Determine the role of the person we're chatting with
    String recipientRole = 'minister';
    String recipientId = ministerId;
    String recipientName = ministerName;
    
    // Check if any staff are assigned
    if (appointment['consultantId'] != null) {
      recipientRole = 'consultant';
      recipientId = appointment['consultantId'] ?? '';
      recipientName = appointment['consultantName'] ?? 'Consultant';
    } else if (appointment['cleanerId'] != null) {
      recipientRole = 'cleaner';
      recipientId = appointment['cleanerId'] ?? '';
      recipientName = appointment['cleanerName'] ?? 'Cleaner';
    } else if (appointment['conciergeId'] != null) {
      recipientRole = 'concierge';
      recipientId = appointment['conciergeId'] ?? '';
      recipientName = appointment['conciergeName'] ?? 'Concierge';
    }
    
    // Role colors for visual identification
    final Map<String, Color> roleColors = {
      'minister': Colors.purple,
      'floor_manager': AppColors.gold,
      'consultant': Colors.blue,
      'concierge': Colors.green,
      'cleaner': Colors.orange,
      'marketing_agent': Colors.red,
      'supervisor': Colors.teal,
      'staff': Colors.indigo,
      'default': Colors.grey,
    };
    
    // First create or update the chat document to ensure it exists
    FirebaseFirestore.instance
        .collection('chats')
        .doc(appointmentId)
        .set({
          'appointmentId': appointmentId,
          'ministerName': ministerName,
          'ministerId': ministerId,
          'serviceName': serviceName,
          'venueName': venueName,
          'appointmentDate': appointmentDateFormatted,
          'appointmentTime': appointmentTimeFormatted,
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true))
        .then((_) => print('Chat document created/updated for appointment $appointmentId'))
        .catchError((error) => print('Error creating chat document: $error'));
    
    // Mark any unread notifications for this appointment as read
    FirebaseFirestore.instance
        .collection('notifications')
        .where('appointmentId', isEqualTo: appointmentId)
        .where('role', isEqualTo: 'floor_manager')
        .where('notificationType', isEqualTo: 'chat')
        .where('isRead', isEqualTo: false)
        .get()
        .then((snapshot) {
          // Found unread notifications for this appointment, mark them as read
          for (final doc in snapshot.docs) {
            doc.reference.update({'isRead': true});
          }
        });
    
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (BuildContext context) {
          return Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.black,
              elevation: 0,
              title: Text(
                'Chat with $ministerName',
                style: TextStyle(
                  color: AppColors.gold,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              leading: IconButton(
                icon: Icon(Icons.arrow_back, color: AppColors.gold),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            body: Container(
              width: double.infinity,
              height: double.infinity,
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                children: [
                  // Appointment details section
                  Container(
                    margin: EdgeInsets.only(bottom: 12),
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[800]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$serviceName at $venueName',
                          style: TextStyle(color: Colors.white, fontSize: 14),
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.calendar_today, color: AppColors.gold, size: 14),
                            SizedBox(width: 4),
                            Text(
                              '$appointmentDateFormatted, $appointmentTimeFormatted',
                              style: TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                          ],
                        ),
                        if (recipientRole == 'minister') ...[
                          SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.phone, color: AppColors.gold, size: 14),
                              SizedBox(width: 4),
                              Text(
                                ministerPhone,
                                style: TextStyle(color: Colors.white70, fontSize: 14),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  // Messages list
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('chats')
                          .doc(appointmentId)
                          .collection('messages')
                          .orderBy('timestamp', descending: true)
                          .limit(50) // Limit to most recent 50 messages for performance
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return Center(child: CircularProgressIndicator(color: AppColors.gold));
                        }
                        
                        if (snapshot.hasError) {
                          print('ERROR FETCHING MESSAGES: ${snapshot.error}');
                          return Center(child: Text('Error loading messages', style: TextStyle(color: Colors.red)));
                        }
                        
                        final messages = snapshot.data?.docs ?? [];
                        if (messages.isEmpty) {
                          return Center(
                            child: Text(
                              'No messages yet. Start the conversation!',
                              style: TextStyle(color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                          );
                        }
                        
                        return ListView.builder(
                          padding: EdgeInsets.all(12),
                          reverse: true,
                          itemCount: messages.length,
                          shrinkWrap: false,
                          itemBuilder: (context, index) {
                            final message = messages[index].data() as Map<String, dynamic>;
                            final isFromFloorManager = message['senderRole'] == 'floor_manager';
                            final senderName = message['senderName'] ?? 'Unknown';
                            final senderRole = message['senderRole'] ?? 'unknown';
                            final senderInitial = message['senderInitial'] ?? '';
                            final text = message['text'] ?? '';
                            final timestamp = message['timestamp'] as Timestamp?;
                            final time = timestamp != null 
                                ? DateFormat('h:mm a').format(timestamp.toDate())
                                : '';
                            
                            // Determine bubble alignment and color based on sender
                            final alignment = isFromFloorManager 
                                ? CrossAxisAlignment.end 
                                : CrossAxisAlignment.start;
                            
                            final bubbleColor = isFromFloorManager 
                                ? AppColors.gold.withOpacity(0.2) 
                                : Colors.grey[800]!;
                            
                            final textColor = isFromFloorManager 
                                ? Colors.white 
                                : Colors.white;
                            
                            final borderColor = isFromFloorManager 
                                ? AppColors.gold.withOpacity(0.5) 
                                : Colors.grey[700]!;
                            
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Column(
                                crossAxisAlignment: alignment,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: isFromFloorManager ? MainAxisAlignment.end : MainAxisAlignment.start,
                                    children: [
                                      if (!isFromFloorManager) ...[
                                        Container(
                                          width: 24,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: roleColors[senderRole] ?? Colors.grey,
                                          ),
                                          child: Center(
                                            child: Text(
                                              senderInitial,
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                      ],
                                      Container(
                                        constraints: BoxConstraints(
                                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                                        ),
                                        padding: EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: bubbleColor,
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(color: borderColor),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            if (!isFromFloorManager) ...[
                                              Text(
                                                'Message from:',
                                                style: TextStyle(
                                                  color: Colors.grey[400],
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.arrow_back,
                                                    color: roleColors[senderRole] ?? Colors.grey,
                                                    size: 12,
                                                  ),
                                                  SizedBox(width: 4),
                                                  Text(
                                                    senderName,
                                                    style: TextStyle(
                                                      color: roleColors[senderRole] ?? Colors.grey,
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              SizedBox(height: 8),
                                            ],
                                            
                                            Text(
                                              text,
                                              style: TextStyle(
                                                color: textColor,
                                              ),
                                            ),
                                            
                                            SizedBox(height: 4),
                                            
                                            Text(
                                              time,
                                              style: TextStyle(
                                                color: Colors.grey,
                                                fontSize: 10,
                                              ),
                                              textAlign: TextAlign.right,
                                            ),
                                            
                                            // Display recipient indicators for minister messages
                                            if (senderRole == 'minister' && message.containsKey('recipientRoles')) ...[
                                              SizedBox(height: 8),
                                              Container(
                                                padding: EdgeInsets.all(6),
                                                decoration: BoxDecoration(
                                                  color: Colors.black54,
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: Colors.grey[800]!, width: 1),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Message for:',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                    SizedBox(height: 4),
                                                    Column(
                                                      mainAxisSize: MainAxisSize.min,
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: (message['recipientRoles'] as List<dynamic>).map<Widget>((role) {
                                                        // Get role display name
                                                        String roleName = '';
                                                        switch (role) {
                                                          case 'floor_manager':
                                                            roleName = 'Floor Manager';
                                                            break;
                                                          case 'consultant':
                                                            roleName = 'Consultant';
                                                            break;
                                                          case 'cleaner':
                                                            roleName = 'Cleaner';
                                                            break;
                                                          case 'concierge':
                                                            roleName = 'Concierge';
                                                            break;
                                                          default:
                                                            roleName = role;
                                                        }
                                                        
                                                        return Container(
                                                          margin: EdgeInsets.only(bottom: 4),
                                                          child: Row(
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: [
                                                              Icon(
                                                                Icons.arrow_forward,
                                                                color: roleColors[role] ?? Colors.grey,
                                                                size: 12,
                                                              ),
                                                              SizedBox(width: 2),
                                                              Container(
                                                                width: 10,
                                                                height: 10,
                                                                decoration: BoxDecoration(
                                                                  shape: BoxShape.circle,
                                                                  color: roleColors[role] ?? Colors.grey,
                                                                ),
                                                              ),
                                                              SizedBox(width: 4),
                                                              Text(
                                                                roleName,
                                                                style: TextStyle(
                                                                  color: roleColors[role] ?? Colors.grey,
                                                                  fontSize: 10,
                                                                  fontWeight: FontWeight.bold,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        );
                                                      }).toList(),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      if (isFromFloorManager) ...[
                                        SizedBox(width: 8),
                                        Container(
                                          width: 24,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: AppColors.gold,
                                          ),
                                          child: Center(
                                            child: Text(
                                              senderInitial,
                                              style: TextStyle(
                                                color: Colors.black,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  
                  // Input area
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: messageController,
                            style: TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Type a message...',
                              hintStyle: TextStyle(color: Colors.grey),
                              filled: true,
                              fillColor: Colors.grey[900],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                            onSubmitted: (text) {
                              if (text.trim().isNotEmpty) {
                                _sendMessageToMinister(appointmentId, text, recipientId);
                                messageController.clear();
                              }
                            },
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.send, color: AppColors.gold),
                          onPressed: () {
                            final message = messageController.text;
                            if (message.trim().isNotEmpty) {
                              _sendMessageToMinister(appointmentId, message, recipientId);
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
      ),
    );
  }

void _sendMessageToMinister(String appointmentId, String message, String recipientId) {
  // Implement message sending logic here, e.g. using VipNotificationService or Firestore
  print('Sending message to minister: $message');
  // Example: You could call VipNotificationService.sendMessageNotification from here if available
}
