import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../core/providers/app_auth_provider.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/services/workflow_service.dart';
import '../../../../core/services/notification_service.dart';
import 'appointments_screen_fixed.dart';
import 'staff_management_screen.dart';
import 'notifications_screen.dart';
import 'employee_registration_screen.dart';
import 'package:vip_lounge/core/services/vip_notification_service.dart';
import '../../../../../features/floor_manager/presentation/widgets/staff_assignment_dialog.dart';

class FloorManagerHomeScreenNew extends StatefulWidget {
  const FloorManagerHomeScreenNew({Key? key}) : super(key: key);

  @override
  State<FloorManagerHomeScreenNew> createState() => _FloorManagerHomeScreenNewState();
}

class _FloorManagerHomeScreenNewState extends State<FloorManagerHomeScreenNew> {
  int _unreadNotifications = 0;
  DateTime _selectedDate = DateTime.now();
  final TextEditingController _messageController = TextEditingController();
  int _selectedIndex = 0;
  String _floorManagerId = '';
  String _floorManagerName = '';
  final NotificationService _notificationService = NotificationService();
  final WorkflowService _workflowService = WorkflowService();
  bool _isClockedIn = false;
  bool _isOnBreak = false;
  bool _isLoading = false;
  List<Map<String, dynamic>> _breakHistory = [];
  List<Map<String, dynamic>> _activeBreaks = [];

  // Add controllers for all horizontal scrollbars
  final ScrollController _clockBarController = ScrollController();
  final ScrollController _visualBarController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Show a toast/snackbar with the home screen name for confirmation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = this.context;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('FloorManagerHomeScreenNew'),
          duration: Duration(seconds: 3),
          backgroundColor: Colors.blueGrey,
        ),
      );
    });
    super.initState();
    _listenToUnreadNotifications();
    _loadActiveBreaksForToday();
    final floorManager = Provider.of<AppAuthProvider>(context, listen: false).appUser;
    if (floorManager != null) {
      setState(() {
        _floorManagerId = floorManager.uid;
        _floorManagerName = '${floorManager.firstName} ${floorManager.lastName}'.trim();
      });
      _loadAttendanceStatus();
      _loadBreakHistory();
    }
  }

  @override
  void dispose() {
    _clockBarController.dispose();
    _visualBarController.dispose();
    super.dispose();
  }

  Future<void> _loadAttendanceStatus() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('attendance').doc(_floorManagerId).get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _isClockedIn = data['isClockedIn'] ?? false;
          _isOnBreak = data['isOnBreak'] ?? false;
        });
      }
    } catch (e) {
      // Handle error, optionally show a snackbar
    }
  }

  Future<void> _loadBreakHistory() async {
    print('Querying breaks for userId: _floorManagerId=$_floorManagerId');
    if (_floorManagerId.isEmpty) return;
    final querySnapshot = await FirebaseFirestore.instance
        .collection('breaks')
        .where('userId', isEqualTo: _floorManagerId)
        .orderBy('startTime', descending: true)
        .limit(10)
        .get();
    print('Breaks fetched: _floorManagerId=$_floorManagerId, count=${querySnapshot.docs.length}');
    for (var doc in querySnapshot.docs) {
      print('Break doc: ' + doc.data().toString());
    }
    setState(() {
      _breakHistory = querySnapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }).toList();
    });
  }

  void _listenToUnreadNotifications() {
    FirebaseFirestore.instance
        .collection('notifications')
        .where('role', isEqualTo: 'floor_manager')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _unreadNotifications = snapshot.docs.length;
        });
      }
    });
  }

  void _showStaffSelectionDialog(BuildContext context, String appointmentId, String staffType) {
    // Get appointment details first to check for conflicts
    FirebaseFirestore.instance
        .collection('appointments')
        .doc(appointmentId)
        .get()
        .then((appointmentDoc) async {
          if (!appointmentDoc.exists) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Appointment not found')),
            );
            return;
          }
          
          final appointmentData = appointmentDoc.data()!;
          final ministerId = appointmentData['ministerId'] as String?;
          
          // Get appointmentTime and duration
          Timestamp? appointmentTime;
          int duration = 60; // Default to 60 minutes if not specified
          
          if (appointmentData['appointmentTime'] is Timestamp) {
            appointmentTime = appointmentData['appointmentTime'] as Timestamp;
          }
          
          if (appointmentData['duration'] is int) {
            duration = appointmentData['duration'] as int;
          }
          
          if (appointmentTime == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Cannot check availability: Appointment time not found')),
            );
            return;
          }
          
          // For consultants, we need to check availability
          if (staffType == 'consultant') {
            // First check if any consultants are available at all
            final consultants = await FirebaseFirestore.instance
                .collection('users')
                .where('role', isEqualTo: 'consultant')
                .get();
                
            // Check each consultant's availability
            List<DocumentSnapshot> availableConsultants = [];
            
            for (var consultant in consultants.docs) {
              final consultantId = consultant.id;
              final isAvailable = await _isStaffAvailable(
                consultantId, 
                'consultant', 
                appointmentTime, 
                duration,
                appointmentId
              );
              
              if (isAvailable) {
                availableConsultants.add(consultant);
              }
            }
            
            // If no consultants are available
            if (availableConsultants.isEmpty && ministerId != null) {
              // Inform the minister
              await _sendNoConsultantsMessage(appointmentId, ministerId);
              
              Navigator.of(context).pop(); // Close dialog
              return;
            }
            
            // Continue with showing available consultants
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                backgroundColor: Colors.black,
                title: Text(
                  'Select $staffType',
                  style: TextStyle(color: AppColors.gold),
                ),
                content: Container(
                  height: 300,
                  width: 300,
                  child: availableConsultants.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.warning, color: Colors.red, size: 48),
                              SizedBox(height: 16),
                              Text(
                                'No available consultants for this time slot',
                                style: TextStyle(color: Colors.white),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: availableConsultants.length,
                          itemBuilder: (context, index) {
                            final staffDoc = availableConsultants[index];
                            final staffData = staffDoc.data() as Map<String, dynamic>;
                            final staffId = staffDoc.id;
                            final firstName = staffData['firstName'] ?? '';
                            final lastName = staffData['lastName'] ?? '';
                            final staffName = '$firstName $lastName'.trim();

                            return ListTile(
                              title: Text(
                                staffName.isNotEmpty ? staffName : 'Staff #$index',
                                style: TextStyle(color: Colors.white),
                              ),
                              trailing: Icon(Icons.arrow_forward, color: AppColors.gold),
                              onTap: () async {
                                await _assignStaff(appointmentId, staffType, staffName, staffId);
                                setState(() {}); // Triggers UI refresh
                                Navigator.of(context).pop();
                              },
                            );
                          },
                        ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Cancel', style: TextStyle(color: AppColors.gold)),
                  ),
                ],
              ),
            );
          } else {
            // For other staff types, just show the regular selection dialog
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                backgroundColor: Colors.black,
                title: Text(
                  'Select $staffType',
                  style: TextStyle(color: AppColors.gold),
                ),
                content: Container(
                  height: 300,
                  width: 300,
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .where('role', isEqualTo: staffType)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return Center(child: CircularProgressIndicator(color: AppColors.gold));
                      }

                      final staffList = snapshot.data!.docs;
                      
                      return ListView.builder(
                        itemCount: staffList.length,
                        itemBuilder: (context, index) {
                          final staffDoc = staffList[index];
                          final staffData = staffDoc.data() as Map<String, dynamic>;
                          final staffId = staffDoc.id;
                          final firstName = staffData['firstName'] ?? '';
                          final lastName = staffData['lastName'] ?? '';
                          final staffName = '$firstName $lastName'.trim();

                          return ListTile(
                            title: Text(
                              staffName.isNotEmpty ? staffName : 'Staff #$index',
                              style: TextStyle(color: Colors.white),
                            ),
                            trailing: Icon(Icons.arrow_forward, color: AppColors.gold),
                            onTap: () async {
                              await _assignStaff(appointmentId, staffType, staffName, staffId);
                              setState(() {}); // Triggers UI refresh
                              Navigator.of(context).pop();
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Cancel', style: TextStyle(color: AppColors.gold)),
                  ),
                ],
              ),
            );
          }
        });
  }

  Future<bool> _isStaffAvailable(String staffId, String staffType, Timestamp appointmentTime, int duration, String currentAppointmentId) async {
    // Get the start and end times for this appointment
    final appointmentStart = appointmentTime.toDate();
    final appointmentEnd = appointmentStart.add(Duration(minutes: duration));
    
    // Check for overlapping appointments
    final overlappingAppointments = await FirebaseFirestore.instance
        .collection('appointments')
        .where('${staffType}Id', isEqualTo: staffId)
        .get();
    
    // Check each appointment for time conflicts
    for (var doc in overlappingAppointments.docs) {
      final data = doc.data();
      
      // Skip if looking at the same appointment
      if (doc.id == currentAppointmentId) continue;
      
      // Get appointment time
      if (data['appointmentTime'] is Timestamp) {
        final otherAppointmentTime = data['appointmentTime'] as Timestamp;
        final otherStart = otherAppointmentTime.toDate();
        
        // Get duration (default to 60 minutes if not specified)
        final otherDuration = data['duration'] is int ? data['duration'] as int : 60;
        final otherEnd = otherStart.add(Duration(minutes: otherDuration));
        
        // Check for overlap - if this appointment's start time is before the other's end time
        // and this appointment's end time is after the other's start time
        if (appointmentStart.isBefore(otherEnd) && appointmentEnd.isAfter(otherStart)) {
          return false; // Conflict found
        }
      }
    }
    
    return true; // No conflicts
  }

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
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                            
                                            SizedBox(height: 4),
                                            
                                            Text(
                                              time,
                                              style: TextStyle(
                                                color: Colors.grey,
                                                fontSize: 10,
                                              ),
                                              textAlign: TextAlign.right,
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
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

  Future<void> _sendMessageToMinister(String appointmentId, String message, String recipientId) async {
    final floorManager = Provider.of<AppAuthProvider>(context, listen: false).appUser;
    if (floorManager == null) return;

    // Get appointment data to determine recipient details
    FirebaseFirestore.instance
        .collection('appointments')
        .doc(appointmentId)
        .get()
        .then((appointmentDoc) async {
          if (!appointmentDoc.exists) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Appointment not found')),
            );
            return;
          }

          final appointmentData = appointmentDoc.data()!;

          // Determine recipient role based on the ID passed
          String recipientRole = 'minister';
          if (recipientId != appointmentData['ministerId']) {
            if (recipientId == appointmentData['consultantId']) {
              recipientRole = 'consultant';
            } else if (recipientId == appointmentData['cleanerId']) {
              recipientRole = 'cleaner';
            } else if (recipientId == appointmentData['conciergeId']) {
              recipientRole = 'concierge';
            }
          }

          // Get sender info
          final senderName = '${floorManager.firstName} ${floorManager.lastName}'.trim();
          final senderRole = 'floor_manager';
          final now = DateTime.now();
          final formattedDate = DateFormat('MMM d, yyyy').format(now);
          final formattedTime = DateFormat('h:mm a').format(now);
          final appointmentTime = appointmentData['appointmentTime'] is Timestamp
              ? (appointmentData['appointmentTime'] as Timestamp).toDate()
              : null;
          final appointmentTimeStr = appointmentTime != null
              ? DateFormat('MMM d, yyyy h:mm a').format(appointmentTime)
              : '';
          final serviceName = appointmentData['serviceName'] ?? '';
          final venueName = appointmentData['venueName'] ?? '';

          // Create message document with extra context
          final messageData = {
            'text': message,
            'senderId': floorManager.uid,
            'senderName': senderName,
            'senderRole': senderRole,
            'senderInitial': floorManager.firstName?.isNotEmpty == true ? floorManager.firstName![0].toUpperCase() : 'F',
            'recipientId': recipientId,
            'recipientRole': recipientRole,
            'timestamp': FieldValue.serverTimestamp(),
            'isRead': false,
            'serviceName': serviceName,
            'venueName': venueName,
            'appointmentTime': appointmentTimeStr,
            'dateSent': formattedDate,
            'timeSent': formattedTime,
          };

          // Store in Firestore
          await FirebaseFirestore.instance
              .collection('chats')
              .doc(appointmentId)
              .collection('messages')
              .add(messageData);

          // Update lastUpdated timestamp on chat document
          await FirebaseFirestore.instance
              .collection('chats')
              .doc(appointmentId)
              .set({
                'lastUpdated': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));

          // Create notification for recipient with rich info
          await FirebaseFirestore.instance.collection('notifications').add({
            'title': 'New Message from Floor Manager',
            'body': 'Message: $message\nFrom: $senderRole\nAt: $formattedDate $formattedTime',
            'type': 'chat',
            'notificationType': 'chat',
            'appointmentId': appointmentId,
            'receiverId': recipientId,
            'senderId': floorManager.uid,
            'senderName': senderName,
            'senderRole': senderRole,
            'timestamp': FieldValue.serverTimestamp(),
            'isRead': false,
            'role': recipientRole,
            'serviceName': serviceName,
            'venueName': venueName,
            'appointmentTime': appointmentTimeStr,
            'dateSent': formattedDate,
            'timeSent': formattedTime,
            'message': message,
            'sendAsPushNotification': true,
          });

          print('Message sent to $recipientRole with ID: $recipientId');
        });
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'in progress':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'rescheduled':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'in progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      case 'rescheduled':
        return 'Rescheduled';
      default:
        return 'Unknown';
    }
  }

  Widget _buildWeeklySchedule() {
    final DateTime today = DateTime.now();
    final List<DateTime> dateSliderDays = List.generate(
      30,
      (i) => today.subtract(Duration(days: 2)).add(Duration(days: i)),
    );

    return Container(
      height: 90, // Increased height to avoid overflow
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: dateSliderDays.length,
        itemBuilder: (context, index) {
          final date = dateSliderDays[index];
          final isSelected = DateFormat('yyyy-MM-dd').format(date) == 
                            DateFormat('yyyy-MM-dd').format(_selectedDate);
          
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedDate = date;
              });
            },
            child: Container(
              width: 60,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.gold : Colors.grey[900],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? AppColors.gold : Colors.grey,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Column(
                  mainAxisSize: MainAxisSize.min, // Use min size
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      DateFormat('E').format(date), // Day of week (Mon, Tue, etc.)
                      style: TextStyle(
                        color: isSelected ? Colors.black : Colors.white,
                        fontSize: 10, // Reduced font size
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      DateFormat('d').format(date), // Day number
                      style: TextStyle(
                        color: isSelected ? Colors.black : Colors.white,
                        fontSize: 18, // Reduced font size
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      DateFormat('MMM').format(date), // Month (Jan, Feb, etc.)
                      style: TextStyle(
                        color: isSelected ? Colors.black : Colors.white,
                        fontSize: 10, // Reduced font size
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAppointmentsList() {
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

    // Use the timestamp range approach directly since date fields are inconsistent
    final DateTime startOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 0, 0, 0);
    final DateTime endOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59);

    final Timestamp startTimestamp = Timestamp.fromDate(startOfDay);
    final Timestamp endTimestamp = Timestamp.fromDate(endOfDay);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          // Try to find appointments that match either the date string or timestamp range
          .where('appointmentTime', isGreaterThanOrEqualTo: startTimestamp)
          .where('appointmentTime', isLessThanOrEqualTo: endTimestamp)
          .snapshots(),
      builder: (context, snapshot) {
        // First attempt with timestamp range
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: AppColors.gold));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          // If timestamp range didn't work, try with date string fields
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('appointments')
                .where('appointmentDateStr', isEqualTo: dateStr)
                .orderBy('appointmentTime')
                .snapshots(),
            builder: (context, dateStrSnapshot) {
              if (dateStrSnapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator(color: AppColors.gold));
              }

              if (!dateStrSnapshot.hasData || dateStrSnapshot.data!.docs.isEmpty) {
                // Last attempt with another possible date field name
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('appointments')
                      .where('dateStr', isEqualTo: dateStr)
                      .orderBy('appointmentTime')
                      .snapshots(),
                  builder: (context, dateStrAltSnapshot) {
                    if (dateStrAltSnapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator(color: AppColors.gold));
                    }

                    if (!dateStrAltSnapshot.hasData || dateStrAltSnapshot.data!.docs.isEmpty) {
                      // For debugging, let's also try to find appointments with a similar date format
                      FirebaseFirestore.instance
                          .collection('appointments')
                          .get()
                          .then((QuerySnapshot querySnapshot) {
                            if (querySnapshot.docs.isNotEmpty) {
                              print('All appointments available:');
                              for (var doc in querySnapshot.docs) {
                                final data = doc.data() as Map<String, dynamic>;
                                // Print date related fields to debug
                                print('Appointment ID: ${doc.id}');
                                if (data.containsKey('appointmentDateStr')) {
                                  print('appointmentDateStr: ${data['appointmentDateStr']}');
                                }
                                if (data.containsKey('dateStr')) {
                                  print('dateStr: ${data['dateStr']}');
                                }
                                if (data.containsKey('appointmentDate')) {
                                  print('appointmentDate: ${data['appointmentDate']}');
                                }
                                if (data.containsKey('appointmentTime') && data['appointmentTime'] is Timestamp) {
                                  final timestamp = data['appointmentTime'] as Timestamp;
                                  final dateTime = timestamp.toDate();
                                  final formattedDate = DateFormat('yyyy-MM-dd').format(dateTime);
                                  print('Derived date from appointmentTime: $formattedDate');
                                  // If this date matches our target date, we should be showing it
                                  if (formattedDate == dateStr) {
                                    print('⚠️ This appointment SHOULD be visible for date: $dateStr');
                                  }
                                }
                                print('---');
                              }
                            } else {
                              print('No appointments found in database at all');
                            }
                          });

                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.event_busy, color: Colors.grey[700], size: 64),
                              SizedBox(height: 16),
                              Text(
                                'No appointments scheduled for this day',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 16,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 16),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.gold,
                                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                ),
                                onPressed: () {
                                  // Try a different query approach - update date strings
                                  _fetchAppointmentsByTimestampRange();
                                },
                                child: Text(
                                  'Refresh Appointments',
                                  style: TextStyle(color: Colors.black),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return _buildAppointmentListView(dateStrAltSnapshot.data!.docs);
                  },
                );
              }

              return _buildAppointmentListView(dateStrSnapshot.data!.docs);
            },
          );
        }

        return _buildAppointmentListView(snapshot.data!.docs);
      },
    );
  }

  Widget _buildAppointmentListView(List<QueryDocumentSnapshot> appointments) {
    return ListView.builder(
      padding: EdgeInsets.all(8),
      itemCount: appointments.length,
      itemBuilder: (context, index) {
        final appointment = appointments[index].data() as Map<String, dynamic>;
        final appointmentId = appointments[index].id;

        // Get the minister name - properly combine first and last names
        String ministerName = '';
        if (appointment.containsKey('ministerName') && appointment['ministerName'] != null && appointment['ministerName'].toString().trim().isNotEmpty && appointment['ministerName'] != 'Unknown Minister') {
          ministerName = appointment['ministerName'];
        } else if (appointment.containsKey('ministerFirstName') && appointment['ministerFirstName'] != null && appointment['ministerFirstName'].toString().trim().isNotEmpty) {
          ministerName = appointment['ministerFirstName'];
          if (appointment.containsKey('ministerLastName') && appointment['ministerLastName'] != null && appointment['ministerLastName'].toString().trim().isNotEmpty) {
            ministerName += ' ' + appointment['ministerLastName'];
          }
          ministerName = ministerName.trim();
        }
        if (ministerName.isEmpty) {
          ministerName = 'Minister';
        }

        final serviceName = appointment['serviceName'] ?? 'Unknown Service';

        // Get appointment time
        String appointmentTimeDisplay = 'Time not specified';
        if (appointment['appointmentTime'] is Timestamp) {
          final timestamp = appointment['appointmentTime'] as Timestamp;
          final dateTime = timestamp.toDate();
          appointmentTimeDisplay = DateFormat('h:mm a').format(dateTime);
          print('Appointment time: $appointmentTimeDisplay from timestamp');
        } else if (appointment['timeSlot'] != null) {
          appointmentTimeDisplay = appointment['timeSlot'];
          print('Appointment time: $appointmentTimeDisplay from timeSlot');
        }

        // Status display
        final status = appointment['status'] ?? 'pending';
        final statusColor = _getStatusColor(status);
        final statusText = _getStatusText(status);

        // Check staff assignments
        final hasConsultant = appointment['consultantId'] != null;
        final hasCleaner = appointment['cleanerId'] != null;
        final hasConcierge = appointment['conciergeId'] != null;

        // Message indicator
        final hasMessages = appointment['hasUnreadMessages'] == true;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: Card(
            color: Colors.grey[900],
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: hasMessages ? AppColors.gold : Colors.grey[800]!,
                width: hasMessages ? 2 : 1,
              ),
            ),
            child: InkWell(
              onTap: () {
                // First get minister ID
                final ministerId = appointment['ministerId'];
                if (ministerId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Minister information not found for this appointment')),
                  );
                  return;
                }

                // Show chat dialog
                _showChatDialogWithData(
                  context,
                  appointmentId,
                  appointment,
                  ministerId,
                  _messageController,
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top section with time and status
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.schedule, color: AppColors.gold, size: 18),
                            SizedBox(width: 8),
                            Text(
                              appointmentTimeDisplay,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: statusColor),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Main content
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Minister and Service details
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: Colors.deepPurple,
                              child: Text(
                                ministerName.isNotEmpty ? ministerName[0].toUpperCase() : 'M',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ministerName,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    serviceName,
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Always show chat icon, but highlight it when there are unread messages
                            Container(
                              padding: EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: hasMessages ? AppColors.gold : Colors.grey[800],
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: hasMessages ? Colors.amber : Colors.grey[600]!,
                                  width: hasMessages ? 2 : 1,
                                ),
                              ),
                              child: Icon(
                                Icons.chat,
                                color: hasMessages ? Colors.black : Colors.white,
                                size: 20,
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 16),

                        // Additional booking details
                        _buildDetailRow(Icons.person, 'Minister ID:', appointment['ministerId'] ?? 'None'),

                        if (appointment['notes'] != null && appointment['notes'].toString().isNotEmpty)
                          _buildDetailRow(Icons.note, 'Notes:', appointment['notes']),

                        if (appointment['serviceDuration'] != null)
                          _buildDetailRow(Icons.timelapse, 'Duration:', '${appointment['serviceDuration']} minutes'),

                        if (appointment['bookingReference'] != null)
                          _buildDetailRow(Icons.confirmation_number, 'Ref:', appointment['bookingReference']),

                        // Add created date
                        Builder(builder: (context) {
                          if (appointment['createdAt'] != null && appointment['createdAt'] is Timestamp) {
                            final createdTimestamp = appointment['createdAt'] as Timestamp;
                            final createdDateTime = createdTimestamp.toDate();
                            return _buildDetailRow(Icons.calendar_today, 'Booked on:', DateFormat('MMM dd, yyyy').format(createdDateTime));
                          }
                          return SizedBox.shrink();
                        }),

                        // Add formatted appointment date
                        Builder(builder: (context) {
                          if (appointment['appointmentTime'] != null && appointment['appointmentTime'] is Timestamp) {
                            final appointmentTimestamp = appointment['appointmentTime'] as Timestamp;
                            final appointmentDateTime = appointmentTimestamp.toDate();
                            return _buildDetailRow(Icons.event, 'Date:', DateFormat('EEEE, MMM dd, yyyy').format(appointmentDateTime));
                          }
                          return SizedBox.shrink();
                        }),

                        // Replace static staff assignment indicators with interactive assign buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Consultant Assign Button
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  _showStaffSelectionDialog(context, appointmentId, 'consultant');
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: hasConsultant ? Colors.green : Colors.blue,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                  padding: const EdgeInsets.symmetric(vertical: 0),
                                  minimumSize: Size(0, 32),
                                ),
                                child: Text(
                                  hasConsultant ? (appointment['consultantName'] ?? 'Reassign') : 'Assign Consultant',
                                  style: const TextStyle(color: Colors.white, fontSize: 11),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            // Cleaner Assign Button
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  _showStaffSelectionDialog(context, appointmentId, 'cleaner');
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: hasCleaner ? Colors.green : Colors.orange,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                  padding: const EdgeInsets.symmetric(vertical: 0),
                                  minimumSize: Size(0, 32),
                                ),
                                child: Text(
                                  hasCleaner ? (appointment['cleanerName'] ?? 'Reassign') : 'Assign Cleaner',
                                  style: const TextStyle(color: Colors.white, fontSize: 11),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            // Concierge Assign Button
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  _showStaffSelectionDialog(context, appointmentId, 'concierge');
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: hasConcierge ? Colors.green : Colors.green,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                  padding: const EdgeInsets.symmetric(vertical: 0),
                                  minimumSize: Size(0, 32),
                                ),
                                child: Text(
                                  hasConcierge ? (appointment['conciergeName'] ?? 'Reassign') : 'Assign Concierge',
                                  style: const TextStyle(color: Colors.white, fontSize: 11),
                                  overflow: TextOverflow.ellipsis,
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
        );
      },
    );
  }

  // Helper method to build detail rows
  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.gold),
          SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: label + ' ',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextSpan(
                    text: value,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchAppointmentsByTimestampRange() async {
    final DateTime startOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 0, 0, 0);
    final DateTime endOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59);

    final Timestamp startTimestamp = Timestamp.fromDate(startOfDay);
    final Timestamp endTimestamp = Timestamp.fromDate(endOfDay);

    print('Querying for appointments between: ${startOfDay.toString()} and ${endOfDay.toString()}');

    try {
      final QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .where('appointmentTime', isGreaterThanOrEqualTo: startTimestamp)
          .where('appointmentTime', isLessThanOrEqualTo: endTimestamp)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        print('Found ${querySnapshot.docs.length} appointments for date range');

        // Update each appointment to include the dateStr field if it's missing
        for (var doc in querySnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          if (data['appointmentTime'] is Timestamp) {
            final timestamp = data['appointmentTime'] as Timestamp;
            final dateTime = timestamp.toDate();
            final dateStr = DateFormat('yyyy-MM-dd').format(dateTime);

            if (!data.containsKey('appointmentDateStr') || data['appointmentDateStr'] != dateStr) {
              print('Updating appointment ${doc.id} with appointmentDateStr: $dateStr');

              // Update the document with the correct date string
              await FirebaseFirestore.instance
                  .collection('appointments')
                  .doc(doc.id)
                  .update({
                    'appointmentDateStr': dateStr,
                  });
            }
          }
        }

        // Refresh the screen
        setState(() {
          // This will trigger a rebuild with the updated data
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Found ${querySnapshot.docs.length} appointments'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        print('Still no appointments found for date range');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No appointments found for selected date'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('Error fetching appointments by timestamp: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error refreshing appointments: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _sendNoConsultantsMessage(String appointmentId, String ministerId) async {
    final floorManager = Provider.of<AppAuthProvider>(context, listen: false).appUser;
    if (floorManager == null) return;

    // Get minister's contact details
    FirebaseFirestore.instance
        .collection('appointments')
        .doc(appointmentId)
        .get()
        .then((appointmentDoc) {
          if (appointmentDoc.exists) {
            final appointmentData = appointmentDoc.data() as Map<String, dynamic>;
            final ministerPhone = appointmentData['ministerPhone'] ?? '';
            final ministerName = appointmentData['ministerName'] ?? 'Minister';

            final message = "I apologize, but all consultants are booked for this time slot. Could you please select a different date or time for your appointment?";

            // Use the existing message method
            _sendMessageToMinister(appointmentId, message, ministerId);

            // Show confirmation to the floor manager with contact info
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Message sent to $ministerName${ministerPhone.isNotEmpty ? " (Phone: $ministerPhone)" : ""}')),
            );
          } else {
            _sendMessageToMinister(appointmentId, "I apologize, but all consultants are booked for this time slot. Could you please select a different date or time for your appointment?", ministerId);

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Message sent to minister requesting a new appointment time')),
            );
          }
        });
  }

  Future<void> _handleClockIn() async {
    setState(() {
      _isLoading = true;
    });
    await FirebaseFirestore.instance.collection('attendance').doc(_floorManagerId).set({
      'isClockedIn': true,
      'isOnBreak': false,
      'clockInTime': DateTime.now(),
      'clockOutTime': null,
      'breaks': [],
    }, SetOptions(merge: true));
    await logAttendanceAction(
      userId: _floorManagerId,
      event: 'clock_in',
      name: _floorManagerName,
      role: 'floor_manager',
      timestamp: DateTime.now(),
    );
    setState(() {
      _isClockedIn = true;
      _isOnBreak = false;
      _isLoading = false;
    });
  }

  Future<void> _handleClockOut() async {
    setState(() {
      _isLoading = true;
    });
    await FirebaseFirestore.instance.collection('attendance').doc(_floorManagerId).set({
      'isClockedIn': false,
      'isOnBreak': false,
      'clockOutTime': DateTime.now(),
    }, SetOptions(merge: true));
    await logAttendanceAction(
      userId: _floorManagerId,
      event: 'clock_out',
      name: _floorManagerName,
      role: 'floor_manager',
      timestamp: DateTime.now(),
    );
    setState(() {
      _isClockedIn = false;
      _isOnBreak = false;
      _isLoading = false;
    });
  }

  void _showBreakDialog() {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        title: Text('Start Break', style: TextStyle(color: AppColors.gold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Please provide a reason for your break:', style: TextStyle(color: Colors.white)),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Reason for break',
                hintStyle: TextStyle(color: Colors.grey),
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              final reason = reasonController.text.trim();
              await _startBreakWithReason(reason);
            },
            child: Text('Start Break', style: TextStyle(color: AppColors.gold)),
          ),
        ],
      ),
    );
  }

  Future<void> _startBreakWithReason(String reason) async {
    print('Writing break for userId: _floorManagerId=$_floorManagerId');
    Navigator.of(context).pop();
    setState(() { _isLoading = true; });
    if (_floorManagerId.isEmpty) return;
    final now = DateTime.now();
    await FirebaseFirestore.instance.collection('breaks').add({
      'userId': _floorManagerId,
      'userName': _floorManagerName,
      'startTime': Timestamp.fromDate(now),
      'reason': reason,
      'role': 'floor_manager',
      'endTime': null,
    });
    await logAttendanceAction(
      userId: _floorManagerId,
      event: 'break_start',
      name: _floorManagerName,
      role: 'floor_manager',
      timestamp: now,
      breakReason: reason,
    );
    print('Break written for userId: _floorManagerId=$_floorManagerId at $now');
    setState(() {
      _isOnBreak = true;
      _isLoading = false;
    });
    await _loadBreakHistory();
    await _loadActiveBreaksForToday();
  }

  Future<void> _endBreak() async {
    setState(() { _isLoading = true; });
    if (_floorManagerId.isEmpty) return;
    final now = DateTime.now();
    final query = await FirebaseFirestore.instance
        .collection('breaks')
        .where('endTime', isEqualTo: null)
        .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(now.subtract(Duration(days: 1))))
        .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(now))
        .orderBy('startTime', descending: true)
        .limit(1)
        .get();
    if (query.docs.isNotEmpty) {
      await query.docs.first.reference.update({
        'endTime': Timestamp.fromDate(now),
      });
    }
    await logAttendanceAction(
      userId: _floorManagerId,
      event: 'break_end',
      name: _floorManagerName,
      role: 'floor_manager',
      timestamp: now,
    );
    setState(() {
      _isOnBreak = false;
      _isLoading = false;
    });
    await _loadBreakHistory();
    await _loadActiveBreaksForToday();
  }

  void _showBreakDetailsDialog(Map<String, dynamic> breakData) {
    final startTime = breakData['startTime'] is Timestamp
        ? (breakData['startTime'] as Timestamp).toDate()
        : breakData['startTime'] as DateTime?;
    final endTime = breakData['endTime'] is Timestamp
        ? (breakData['endTime'] as Timestamp).toDate()
        : breakData['endTime'] as DateTime?;
    final reason = breakData['reason'] ?? '';
    final name = breakData['name'] ?? breakData['floorManagerName'] ?? breakData['userName'] ?? 'Unknown';
    final role = breakData['role'] ?? 'Unknown';
    final duration = (startTime != null && endTime != null)
        ? endTime.difference(startTime).inMinutes
        : null;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        title: Text('Break Details', style: TextStyle(color: AppColors.gold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Name: $name', style: TextStyle(color: Colors.white)),
            Text('Role: $role', style: TextStyle(color: Colors.white)),
            if (startTime != null)
              Text('Started: ${DateFormat('h:mm a').format(startTime)}', style: TextStyle(color: Colors.white)),
            if (endTime != null)
              Text('Ended: ${DateFormat('h:mm a').format(endTime)}', style: TextStyle(color: Colors.white)),
            if (duration != null)
              Text('Duration: $duration min', style: TextStyle(color: duration != null ? Colors.white : Colors.orange, fontWeight: FontWeight.bold, fontSize: 13)),
            if (endTime == null)
              Text('Status: In progress', style: TextStyle(color: Colors.orange)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close', style: TextStyle(color: AppColors.gold)),
          ),
        ],
      ),
    );
  }

  Future<void> _loadActiveBreaksForToday() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final querySnapshot = await FirebaseFirestore.instance
        .collection('breaks')
        .where('endTime', isEqualTo: null)
        .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .orderBy('startTime', descending: true)
        .get();
    List<Map<String, dynamic>> breaks = [];
    List<String> missingNameUserIds = [];
    Map<String, int> indexMap = {};
    for (int i = 0; i < querySnapshot.docs.length; i++) {
      final doc = querySnapshot.docs[i];
      final data = doc.data();
      final role = (data['role'] ?? '').toString().trim().toLowerCase();
      if (role.isEmpty || role == 'floor_manager') continue;
      final userName = (data['userName'] ?? '').toString().trim();
      final userId = (data['userId'] ?? '').toString();
      if (userName.isEmpty && userId.isNotEmpty) {
        missingNameUserIds.add(userId);
        indexMap[userId] = breaks.length;
      }
      breaks.add({
        'id': doc.id,
        ...data,
      });
    }
    if (missingNameUserIds.isNotEmpty) {
      for (int i = 0; i < missingNameUserIds.length; i += 10) {
        final batchIds = missingNameUserIds.skip(i).take(10).toList();
        print('Fetching user docs for IDs: ' + batchIds.toString());
        final usersSnap = await FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereIn: batchIds)
          .get();
        for (var userDoc in usersSnap.docs) {
          final userId = userDoc.id;
          final data = userDoc.data();
          final userName = data['name'] ?? data['displayName'] ?? '';
          print('Fetched for userId=$userId: name=$userName');
          final idx = indexMap[userId];
          if (idx != null && userName.toString().trim().isNotEmpty) {
            breaks[idx]['userName'] = userName.toString();
          } else if (idx != null) {
            print('WARNING: No name/displayName for userId=$userId');
          }
        }
      }
    }
    setState(() {
      _activeBreaks = breaks;
    });
  }

  Future<void> logAttendanceAction({
    required String userId,
    required String event,
    required String name,
    required String role,
    DateTime? timestamp,
    String? breakReason,
    Map<String, dynamic>? extraData,
  }) async {
    final now = timestamp ?? DateTime.now();
    final doc = {
      'event': event,
      'timestamp': Timestamp.fromDate(now),
      'name': name,
      'role': role,
      'userId': userId,
      if (breakReason != null) 'breakReason': breakReason,
      if (extraData != null) ...extraData,
    };
    await FirebaseFirestore.instance
        .collection('attendance')
        .doc(userId)
        .collection('history')
        .add(doc);
  }

  Widget _buildCurrentlyOnBreakView() {
    if (_activeBreaks.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 18.0),
        child: Text('No staff currently on break today.', style: TextStyle(color: Colors.grey)),
      );
    }
    return SizedBox(
      height: 160,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _activeBreaks.length,
        itemBuilder: (context, index) {
          final breakData = _activeBreaks[index];
          final name = (breakData['userName'] ?? '').toString().trim();
          final userId = (breakData['userId'] ?? '').toString();
          final role = (breakData['role'] ?? '').toString().trim();
          final startTime = breakData['startTime'] is Timestamp
              ? (breakData['startTime'] as Timestamp).toDate()
              : breakData['startTime'] as DateTime?;
          final reason = breakData['reason'] ?? '';
          if (name.isEmpty && userId.isEmpty) return SizedBox.shrink();
          return SizedBox(
            width: 220,
            child: Card(
              color: Colors.grey[900],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.person, color: Colors.white, size: 18),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            name.isNotEmpty ? name : userId,
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.badge, color: Colors.white, size: 15),
                        const SizedBox(width: 4),
                        Text(role, style: TextStyle(color: Colors.white, fontSize: 13, fontStyle: FontStyle.italic),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.coffee, color: Colors.white, size: 16),
                        const SizedBox(width: 4),
                        Text('Started: ' + (startTime != null ? DateFormat('h:mm a').format(startTime) : '-'),
                          style: TextStyle(color: Colors.white, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                    if (reason.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline, color: Colors.orange, size: 14),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                reason,
                                style: TextStyle(color: Colors.orange, fontStyle: FontStyle.italic, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 2),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _assignStaff(String appointmentId, String staffType, String staffName, String staffId) async {
    try {
      print('======= [DEBUG] _assignStaff called (floor_manager_home_screen_new) =======');
      print('[DEBUG] appointmentId: $appointmentId');
      print('[DEBUG] staffType: $staffType');
      print('[DEBUG] staffName: $staffName');
      print('[DEBUG] staffId: $staffId');
      // Get the current floor manager's ID
      final user = Provider.of<AppAuthProvider>(context, listen: false).appUser;
      final floorManagerId = user?.uid;
      final floorManagerName = user?.name ?? 'Floor Manager';
      
      // Get the appointment data first to include in activity log
      final appointmentDoc = await FirebaseFirestore.instance
          .collection('appointments')
          .doc(appointmentId)
          .get();
      
      if (!appointmentDoc.exists) {
        throw Exception('Appointment not found');
      }
      
      final appointmentData = appointmentDoc.data();
      
      // Get full minister data to ensure we have the complete name
      String ministerName = 'Unknown Minister';
      if (appointmentData != null && appointmentData['ministerId'] != null) {
        final ministerDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(appointmentData['ministerId'])
            .get();
        if (ministerDoc.exists) {
          final ministerData = ministerDoc.data() as Map<String, dynamic>;
          final firstName = ministerData['firstName'] ?? '';
          final lastName = ministerData['lastName'] ?? '';
          ministerName = ('$firstName $lastName').trim();
        }
      }
      
      // Build the update data for Firestore
      final updateData = <String, dynamic>{
        '${staffType}Id': staffId,
        '${staffType}Name': staffName,
        'lastUpdated': FieldValue.serverTimestamp(),
      };
      
      // Clear other staff assignments if reassigning
      if (staffType == 'consultant') {
        updateData['consultantId'] = staffId;
        updateData['consultantName'] = staffName;
      } else if (staffType == 'concierge') {
        updateData['conciergeId'] = staffId;
        updateData['conciergeName'] = staffName;
      } else if (staffType == 'cleaner') {
        updateData['cleanerId'] = staffId;
        updateData['cleanerName'] = staffName;
      }
      
      // Update the appointment document
      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(appointmentId)
          .update(updateData);
      
      // Send notification to the assigned staff
      await _sendAssignmentNotification(staffId, staffType, appointmentId);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$staffType assigned successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  // Sends notification to assigned staff and, if not cleaner, to the minister as confirmation
  Future<void> _sendAssignmentNotification(String staffId, String staffType, String appointmentId) async {
    try {
      // Get appointment details to include in the notification
      final appointmentDoc = await FirebaseFirestore.instance
          .collection('appointments')
          .doc(appointmentId)
          .get();
      
      if (!appointmentDoc.exists) {
        print('Appointment not found when creating notification');
        return;
      }
      
      final appointmentData = appointmentDoc.data() as Map<String, dynamic>;
      String ministerName = '';
      if (appointmentData.containsKey('ministerName') && appointmentData['ministerName'] != null && appointmentData['ministerName'].toString().trim().isNotEmpty) {
        ministerName = appointmentData['ministerName'];
      } else if (appointmentData.containsKey('ministerFirstName') && appointmentData.containsKey('ministerLastName')) {
        final firstName = appointmentData['ministerFirstName'];
        final lastName = appointmentData['ministerLastName'];
        
        if (firstName != null && lastName != null) {
          ministerName = '$firstName $lastName';
        } else if (firstName != null) {
          ministerName = firstName;
        } else if (lastName != null) {
          ministerName = lastName;
        }
      }
      if (ministerName.isEmpty) {
        ministerName = 'Minister';
      }
      final ministerId = appointmentData['ministerId'] ?? '';
      final appointmentTime = appointmentData['appointmentTime'] as Timestamp?;
      final formattedTime = appointmentTime != null 
          ? DateFormat('dd MMM yyyy, hh:mm a').format(appointmentTime.toDate()) 
          : 'Unknown time';
      final venueName = appointmentData['venueName'] ?? 'Unknown venue';
      final serviceName = appointmentData['serviceName'] ?? '';
      final consultantName = appointmentData['consultantName'] ?? '';
      final consultantId = appointmentData['consultantId'] ?? '';
      final conciergeName = appointmentData['conciergeName'] ?? '';
      final cleanerName = appointmentData['cleanerName'] ?? '';
      
      // Get the current floor manager information
      final user = Provider.of<AppAuthProvider>(context, listen: false).appUser;
      final floorManagerName = user?.name ?? 'Floor Manager';
      
      // Create notification content for staff
      final title = 'New $staffType Assignment';
      final body = 'You have been assigned to assist $ministerName on $formattedTime at $venueName';
      
      // 1. Create in-app display notification in Firestore for staff
      await FirebaseFirestore.instance.collection('notifications').add({
        'title': title,
        'body': body,
        'receiverId': staffId,
        'type': 'appointment_assigned',
        'appointmentId': appointmentId,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'role': staffType,
        'senderName': floorManagerName,
        'ministerName': ministerName,
        'appointmentTime': appointmentTime,
        'venueName': venueName,
      });
      
      // 2. Attempt to send FCM push notification if token is available (to staff)
      try {
        final staffDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(staffId)
            .get();
            
        if (staffDoc.exists) {
          final fcmToken = staffDoc.data()?['fcmToken'];
          
          if (fcmToken != null) {
            await NotificationService().createNotification(
              title: title,
              body: body,
              data: {
                'type': 'appointment_assigned',
                'appointmentId': appointmentId,
                'staffType': staffType,
                'ministerName': ministerName,
                'appointmentTime': appointmentTime,
                'venueName': venueName,
              },
              role: staffType,
              assignedToId: staffId,
            );
            print('Push notification sent to $staffType with ID: $staffId');
          } else {
            print('No FCM token found for $staffType with ID: $staffId');
          }
        }
      } catch (e) {
        print('Error sending push notification: $e');
      }
      
      // 3. If not cleaner, notify the minister of assignment
      if (staffType != 'cleaner' && ministerId != '') {
        final ministerTitle = 'Your Appointment Has Been Assigned';
        final ministerBody = staffType == 'consultant'
          ? 'Your appointment has been assigned to Consultant $consultantName. They will assist you on $formattedTime at $venueName.'
          : staffType == 'concierge'
            ? 'Your appointment has been assigned to Concierge $conciergeName. They will assist you on $formattedTime at $venueName.'
            : '';
        if (ministerBody.isNotEmpty) {
          // In-app notification for minister
          await FirebaseFirestore.instance.collection('notifications').add({
            'title': ministerTitle,
            'body': ministerBody,
            'receiverId': ministerId,
            'type': 'assignment_confirmed',
            'appointmentId': appointmentId,
            'timestamp': FieldValue.serverTimestamp(),
            'isRead': false,
            'role': 'minister',
            'senderName': floorManagerName,
            'appointmentTime': appointmentTime,
            'venueName': venueName,
            'serviceName': serviceName,
            'assignedStaffType': staffType,
            'assignedStaffName': staffType == 'consultant' ? consultantName : conciergeName,
          });
          // FCM push notification to minister
          try {
            final ministerDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(ministerId)
                .get();
            if (ministerDoc.exists) {
              final ministerFcmToken = ministerDoc.data()?['fcmToken'];
              if (ministerFcmToken != null) {
                await NotificationService().createNotification(
                  title: ministerTitle,
                  body: ministerBody,
                  data: {
                    'type': 'assignment_confirmed',
                    'appointmentId': appointmentId,
                    'assignedStaffType': staffType,
                    'assignedStaffName': staffType == 'consultant' ? consultantName : conciergeName,
                    'appointmentTime': appointmentTime,
                    'venueName': venueName,
                    'serviceName': serviceName,
                  },
                  role: 'minister',
                  assignedToId: ministerId,
                );
                print('Push notification sent to minister $ministerId');
              } else {
                print('No FCM token found for minister $ministerId');
              }
            }
          } catch (e) {
            print('Error sending push notification to minister: $e');
          }
        }
      }
    } catch (e) {
      print('Error in notification system: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Row(
          children: [
            Icon(Icons.calendar_today, color: AppColors.gold),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                DateFormat('MMM d, yyyy').format(_selectedDate),
                style: TextStyle(
                  color: AppColors.gold,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.logout, color: AppColors.gold),
            onPressed: () {
              // Sign out with proper confirmation dialog
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: Colors.black,
                  title: Text('Confirm Logout', style: TextStyle(color: AppColors.gold)),
                  content: Text('Are you sure you want to log out?', style: TextStyle(color: Colors.white)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text('Cancel', style: TextStyle(color: Colors.grey)),
                    ),
                    TextButton(
                      onPressed: () {
                        Provider.of<AppAuthProvider>(context, listen: false).signOut();
                        Navigator.of(context).pop(); // close dialog
                        Navigator.of(context).pop(); // go back to login
                      },
                      child: Text('Logout', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildWeeklySchedule(),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: Scrollbar(
                                  controller: _clockBarController,
                                  thumbVisibility: true,
                                  thickness: 6,
                                  radius: const Radius.circular(8),
                                  child: SingleChildScrollView(
                                    controller: _clockBarController,
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: [
                                        if (!_isClockedIn)
                                          ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
                                            onPressed: _handleClockIn,
                                            icon: const Icon(Icons.login, color: Colors.black),
                                            label: const Text('Clock In', style: TextStyle(color: Colors.black)),
                                          ),
                                        if (_isClockedIn && !_isOnBreak)
                                          ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
                                            onPressed: _showBreakDialog,
                                            icon: const Icon(Icons.coffee, color: Colors.black),
                                            label: const Text('Start Break', style: TextStyle(color: Colors.black)),
                                          ),
                                        if (_isClockedIn && _isOnBreak)
                                          ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                            onPressed: _isLoading ? null : _endBreak,
                                            icon: const Icon(Icons.stop_circle, color: Colors.white),
                                            label: const Text('End Break', style: TextStyle(color: Colors.white)),
                                          ),
                                        if (_isClockedIn)
                                          ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                            onPressed: _handleClockOut,
                                            icon: const Icon(Icons.logout, color: Colors.white),
                                            label: const Text('Clock Out', style: TextStyle(color: Colors.white)),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Breaks',
                                style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                              const SizedBox(height: 8),
                              _buildBreaksViewForFloorManager(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 320, // Adjust as needed for your layout
                child: _buildAppointmentsList(),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.black,
        selectedItemColor: AppColors.gold,
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });

          // Navigate based on index
          switch (index) {
            case 0: // Already on appointments screen
              break;
            case 1: // Staff Management
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => StaffManagementScreen()),
              );
              break;
            case 2: // Notifications
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => NotificationsScreen()),
              );
              break;
            case 3: // Employee Registration
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => EmployeeRegistrationScreen()),
              );
              break;
          }
        },
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Appointments',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Staff',
          ),
          BottomNavigationBarItem(
            icon: Badge(
              label: _unreadNotifications > 0
                  ? Text(_unreadNotifications.toString(), style: TextStyle(color: Colors.white))
                  : null,
              backgroundColor: _unreadNotifications > 0 ? Colors.red : Colors.transparent,
              child: Icon(Icons.notifications),
            ),
            label: 'Notifications',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_add),
            label: 'Register',
          ),
        ],
      ),
    );
  }

  Widget _buildBreaksViewForFloorManager() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_breakHistory.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 4, top: 8),
            child: Text('Your Break History', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
          ),
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _breakHistory.length,
            itemBuilder: (context, index) {
              final breakData = _breakHistory[index];
              final startTime = breakData['startTime'] is Timestamp
                  ? (breakData['startTime'] as Timestamp).toDate()
                  : breakData['startTime'] as DateTime?;
              final endTime = breakData['endTime'] is Timestamp
                  ? (breakData['endTime'] as Timestamp).toDate()
                  : breakData['endTime'] as DateTime?;
              final reason = breakData['reason'] ?? '';
              final duration = (startTime != null && endTime != null)
                  ? endTime.difference(startTime).inMinutes
                  : null;
              return SizedBox(
                width: 220,
                child: Card(
                  color: Colors.grey[900],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.coffee, color: AppColors.gold, size: 18),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                startTime != null ? DateFormat('h:mm a').format(startTime) : '-',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (reason.isNotEmpty)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.info_outline, color: Colors.orange, size: 14),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  reason,
                                  style: TextStyle(color: Colors.orange, fontStyle: FontStyle.italic, fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.timer, color: Colors.grey, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              duration != null ? '$duration min' : 'In progress',
                              style: TextStyle(color: duration != null ? Colors.white : Colors.orange, fontWeight: FontWeight.bold, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
