import 'package:vip_lounge/core/services/fcm_service.dart';
import 'package:vip_lounge/features/shared/utils/app_update_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/colors.dart';
import 'package:vip_lounge/core/widgets/app_bottom_nav_bar.dart';
import 'package:vip_lounge/core/widgets/notification_bell_badge.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/role_notification_list.dart';
import '../../../../core/providers/app_auth_provider.dart';
import '../../../../core/services/vip_messaging_service.dart';
import '../../../../core/services/vip_notification_service.dart';
import 'query_screen.dart';
import 'consultant_rating_screen.dart';
import '../../../floor_manager/presentation/screens/notifications_screen.dart';
import 'package:vip_lounge/features/minister/presentation/screens/marketing_tab_social_feed.dart';
import 'minister_chat_dialog.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:vip_lounge/core/services/device_location_service.dart';
import 'package:vip_lounge/features/floor_manager/presentation/widgets/notification_item.dart';
import 'package:vip_lounge/core/widgets/Send_My_FCM.dart';
import 'minister_feedback_screen.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/colors.dart';
import 'package:vip_lounge/core/widgets/app_bottom_nav_bar.dart';
import 'package:vip_lounge/core/widgets/notification_bell_badge.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/role_notification_list.dart';
import '../../../../core/providers/app_auth_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/services/vip_messaging_service.dart';
import '../../../../core/services/vip_notification_service.dart';
import 'query_screen.dart';
import 'consultant_rating_screen.dart';
import '../../../floor_manager/presentation/screens/notifications_screen.dart';
import 'package:vip_lounge/features/minister/presentation/screens/marketing_tab_social_feed.dart';
import 'package:vip_lounge/core/services/device_location_service.dart';
import 'package:vip_lounge/features/floor_manager/presentation/widgets/notification_item.dart';

class MinisterHomeScreen extends StatefulWidget {
  final String? initialChatAppointmentId;

  const MinisterHomeScreen({
    super.key,
    this.initialChatAppointmentId,
  });

  @override
  State<MinisterHomeScreen> createState() => _MinisterHomeScreenState();
}

class _MinisterHomeScreenState extends State<MinisterHomeScreen> {
  int _selectedIndex = 0;
  int _unreadNotifications = 0;
  
  // Add service instances
  final VipMessagingService _messagingService = VipMessagingService();
  final VipNotificationService _notificationService = VipNotificationService();
  
  // Define non-nullable map with proper initialization
  final Map<String, Map<String, dynamic>> _assignedStaff = {
    'floor_manager': {
      'id': '',
      'name': 'Floor Manager',
      'checked': true,
    },
    'consultant': {
      'id': '',
      'name': 'Consultant',
      'checked': false,
    },
    'concierge': {
      'id': '',
      'name': 'Concierge',
      'checked': false,
    },
    'cleaner': {
      'id': '',
      'name': 'Cleaner',
      'checked': false,
    },
  };

  // --- BEGIN: Ensure all required state fields exist ---
  List<Map<String, dynamic>> _unreadNotificationsList = [];
  Map<String, int> _unreadMessageCounts = {};
  Map<String, int> _notificationTypeCount = {
    'message': 0,
    'appointment': 0,
    'general': 0,
  };
  String? _highlightedAppointmentId;
  // --- END: Ensure all required state fields exist ---

  @override
  void initState() {
    super.initState();
    FCMService().init();
    // Silwela in-app update check
    _setupNotificationListener();
    _setupChatMessageListener();
    _setupMessageListener();
    
    // Process arguments passed to the screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic>) {
        // Check if we need to open a chat immediately
        if (args['openChat'] == true && args['appointmentId'] != null) {
          // Fetch the appointment details to open the chat
          _fetchAppointmentAndOpenChat(args['appointmentId']);
        }
        // Check if we need to open a specific appointment
        else if (args['openAppointmentTab'] == true && args['appointmentId'] != null) {
          // Switch to the bookings tab
          setState(() {
            _selectedIndex = 1; // Assuming 1 is the bookings tab
          });
          
          // Fetch and highlight the appointment
          _fetchAndHighlightAppointment(args['appointmentId']);
        }
        // Legacy check for initial chat appointment ID (from widget parameter)
        else if (widget.initialChatAppointmentId != null) {
          // Use a delay to ensure the widget is fully built
          Future.delayed(Duration(milliseconds: 500), () {
            if (mounted) {
              openChatForAppointment(widget.initialChatAppointmentId!);
            }
          });
        }
      }
    });
  }

  void _setupNotificationListener() {
    final user = Provider.of<AppAuthProvider>(context, listen: false).appUser;
    if (user == null) return;

    print('Setting up notification listener for minister: ${user.uid}');

    // Initialize notifications list to avoid spinning wheel
    setState(() {
      _unreadNotificationsList = [];
      _unreadNotifications = 0;
      _notificationTypeCount = {
        'message': 0,
        'appointment': 0,
        'general': 0,
      };
    });

    // Simple direct query for notifications - don't over-filter
    FirebaseFirestore.instance
        .collection('notifications')
        .where('role', isEqualTo: 'minister')
        .where('assignedToId', isEqualTo: user.uid)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
          if (mounted) {
            print('FOUND ${snapshot.docs.length} NOTIFICATIONS FOR MINISTER');
            
            // Debug what's in the notifications
            for (var doc in snapshot.docs) {
              print('NOTIFICATION DATA: ${doc.data()}');
            }
            
            // Process notifications - update counts and lists
            final List<Map<String, dynamic>> notificationsList = [];
            final Map<String, int> typeCount = {
              'message': 0,
              'appointment': 0,
              'general': 0,
            };
            
            for (var doc in snapshot.docs) {
              final data = doc.data();
              
              // Extract notification type, defaulting to 'general' if not specified
              final notificationType = data['notificationType'] as String? ?? 
                                     data['type'] as String? ?? 'general';
              
              // Get appointment ID from data map if available
              final appointmentId = data['appointmentId'] as String? ?? '';
              
              // Count notifications by type
              if (notificationType == 'message') {
                typeCount['message'] = (typeCount['message'] ?? 0) + 1;
              } else if (notificationType.contains('appointment') || 
                      notificationType == 'service_started' || 
                      notificationType == 'service_completed' ||
                      notificationType == 'rating_request' ||
                      notificationType == 'staff_assigned') {
                typeCount['appointment'] = (typeCount['appointment'] ?? 0) + 1;
              } else {
                typeCount['general'] = (typeCount['general'] ?? 0) + 1;
              }
              
              // Add to notifications list (always include isRead field)
              notificationsList.add({
                'id': doc.id,
                'title': data['title'] ?? '',
                'body': data['body'] ?? '',
                'type': notificationType,
                'notificationType': notificationType,
                'appointmentId': appointmentId,
                'createdAt': data['timestamp'] ?? data['createdAt'] ?? Timestamp.now(),
                'isRead': data['isRead'] ?? false,
              });
            }
            
            setState(() {
              _unreadNotificationsList = notificationsList;
              _unreadNotifications = snapshot.docs.length;
              _notificationTypeCount = typeCount;
            });
          }
        }, onError: (error) {
          print("Error in notification listener: $error");
          // Handle error by showing empty list instead of spinner
          setState(() {
            _unreadNotificationsList = [];
            _unreadNotifications = 0;
            _notificationTypeCount = {
              'message': 0,
              'appointment': 0,
              'general': 0,
            };
          });
        });
  }

  void _setupChatMessageListener() {
    final user = Provider.of<AppAuthProvider>(context, listen: false).appUser;
    if (user == null) return;
    
    print('Setting up chat message listener for minister: ${user.uid}');
    
    // Listen for unread messages and count them by appointment
    FirebaseFirestore.instance
        .collection('chat_messages')
        .where('recipientId', isEqualTo: user.uid)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
          if (mounted) {
            Map<String, int> newCounts = {};
            
            for (var doc in snapshot.docs) {
              final data = doc.data();
              final appointmentId = data['appointmentId'] as String? ?? '';
              
              if (appointmentId.isNotEmpty) {
                newCounts[appointmentId] = (newCounts[appointmentId] ?? 0) + 1;
                
                // Add messages to notification list if they aren't already there
                final String messageId = doc.id;
                final bool alreadyInList = _unreadNotificationsList.any((notif) => 
                  notif['messageId'] == messageId || 
                  (notif['type'] == 'message' && notif['appointmentId'] == appointmentId && notif['senderId'] == data['senderId'])
                );
                
                if (!alreadyInList) {
                  // Get sender information
                  final String senderId = data['senderId'] ?? '';
                  final String senderName = data['senderName'] ?? 'Staff Member';
                  final String senderRole = data['senderRole'] ?? 'consultant';
                  final String messageContent = data['message'] ?? 'New message';
                  
                  // Create notification object
                  final Map<String, dynamic> notification = {
                    'id': 'msg_${messageId}',  // Unique ID for the notification
                    'messageId': messageId,
                    'title': 'Message from $senderName',
                    'body': messageContent,
                    'type': 'message',
                    'notificationType': 'message',
                    'appointmentId': appointmentId,
                    'createdAt': data['timestamp'] ?? Timestamp.now(),
                    'senderName': senderName,
                    'senderId': senderId,
                    'senderRole': senderRole,
                  };
                  
                  // Add to notifications list
                  setState(() {
                    _unreadNotificationsList.add(notification);
                    _unreadNotifications = _unreadNotificationsList.length;
                    
                    // Update message count in notification type counts
                    _notificationTypeCount['message'] = (_notificationTypeCount['message'] ?? 0) + 1;
                  });
                }
              }
            }
            
            setState(() {
              _unreadMessageCounts = newCounts;
            });
          }
        });
  }

  void _setupMessageListener() {
    final user = Provider.of<AppAuthProvider>(context, listen: false).appUser;
    if (user == null) return;

    print('Setting up message listener for minister: ${user.uid}');

    // Listen for all messages where minister is recipient
    FirebaseFirestore.instance
        .collection('chat_messages')
        .where('recipientId', isEqualTo: user.uid)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .listen((snapshot) {
          for (var change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              final messageData = change.doc.data();
              
              if (messageData == null) continue;
              
              // Only create notifications for new messages
              final messageTimestamp = messageData['timestamp'] as Timestamp?;
              if (messageTimestamp == null) continue;
              
              final isRecent = DateTime.now().difference(messageTimestamp.toDate()).inMinutes < 5;
              
              final senderId = messageData['senderId'] as String?;
              if (isRecent && senderId != null && senderId != user.uid) {
                final senderName = messageData['senderName'] ?? 'Staff Member';
                final appointmentId = messageData['appointmentId'] ?? '';
                final senderRole = messageData['senderRole'] ?? 'staff';
                
                print('New message from $senderName with role $senderRole');
                
                // Create notification for bottom nav bar
                _notificationService.createNotification(
                  title: 'New Message',
                  body: 'You have received a message from $senderName',
                  assignedToId: user.uid,
                  role: 'minister',
                  data: {
                    'appointmentId': appointmentId,
                    'senderId': senderId,
                    'senderName': senderName,
                    'senderRole': senderRole,
                  },
                  notificationType: 'message'
                );
                
                // Send FCM notification
                _notificationService.sendFCMToUser(
                  userId: user.uid,
                  title: 'Message from $senderName',
                  body: messageData['message'] ?? '',
                  data: {
                    'type': 'message',
                    'appointmentId': appointmentId,
                    'senderId': senderId
                  },
                  messageType: 'message'
                );
                
                if (mounted) {
                  // Show in-app notification
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: Colors.black,
                      content: Text(
                        'New message from $senderName (${_capitalize(senderRole)})',
                        style: const TextStyle(color: Colors.white),
                      ),
                      action: SnackBarAction(
                        label: 'View',
                        textColor: AppColors.gold,
                        onPressed: () {
                          openChatForAppointment(appointmentId);
                        },
                      ),
                      duration: const Duration(seconds: 5),
                    ),
                  );
                }
              }
            }
          }
        });
  }

  void _onItemTapped(int index) {
    if (index == 1) {
      // Navigate to minister choice screen
      Navigator.pushNamed(context, '/minister/choice');
    } else if (index == 2) {
      // Navigate to query screen
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => QueryScreen()),
      );
    } else if (index == 3) { // Notifications tab
      setState(() {
        _selectedIndex = index;
      });
      // Don't navigate to a separate screen, show notifications in-app
    } else if (index == 4) { // Marketing tab
      setState(() {
        _selectedIndex = index;
      });
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  // Method to handle opening the notifications screen
  void _openNotificationsScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NotificationsScreen(
          userRole: 'minister',
          userId: Provider.of<AppAuthProvider>(context, listen: false).appUser?.uid ?? '',
          forMinister: true,
          ministerId: Provider.of<AppAuthProvider>(context, listen: false).appUser?.uid ?? '',
        ),
      ),
    );
  }

  // Method to handle opening chat for an appointment
  void openChatForAppointment(String appointmentId) async {
    try {
      // Get appointment details
      final appointmentDoc = await FirebaseFirestore.instance
          .collection('appointments')
          .doc(appointmentId)
          .get();
      
      if (!appointmentDoc.exists) {
        print('Appointment not found: $appointmentId');
        return;
      }
      
      final appointmentData = appointmentDoc.data()!;
      appointmentData['id'] = appointmentId; // Ensure ID is included
      
      // Mark any unread notifications for this appointment as read
      final user = Provider.of<AppAuthProvider>(context, listen: false).appUser;
      if (user != null) {
        // Mark notifications as read
        FirebaseFirestore.instance
            .collection('notifications')
            .where('appointmentId', isEqualTo: appointmentId)
            .where('assignedToId', isEqualTo: user.uid)
            .where('isRead', isEqualTo: false)
            .get()
            .then((snapshot) {
          for (var doc in snapshot.docs) {
            doc.reference.update({'isRead': true});
          }
        });
        
        // Mark chat messages as read
        FirebaseFirestore.instance
            .collection('chat_messages')
            .where('appointmentId', isEqualTo: appointmentId)
            .where('recipientId', isEqualTo: user.uid)
            .where('isRead', isEqualTo: false)
            .get()
            .then((snapshot) {
          for (var doc in snapshot.docs) {
            doc.reference.update({'isRead': true});
          }
          
          // Update local state if there were unread messages
          if (snapshot.docs.isNotEmpty && mounted) {
            setState(() {
              if (_unreadMessageCounts.containsKey(appointmentId)) {
                _unreadMessageCounts.remove(appointmentId);
              }
              
              // Remove from notification list
              _unreadNotificationsList.removeWhere((notif) => 
                notif['appointmentId'] == appointmentId && notif['type'] == 'message');
              
              // Update notification type count
              _notificationTypeCount['message'] = (_notificationTypeCount['message'] ?? 0) - snapshot.docs.length;
              if (_notificationTypeCount['message']! < 0) _notificationTypeCount['message'] = 0;
            });
          }
          
          // Open chat dialog for appointment
          _openChatDialog(appointmentData);
        });
      }
    } catch (e) {
      print('Error opening chat for appointment: $e');
    }
  }

  void _openChatDialog(Map<String, dynamic> appointment) {
    showDialog(
      context: context,
      builder: (context) => MinisterChatDialog(appointment: appointment),
    );
  }

  // Method to handle opening consultant rating screen
  void _openConsultantRatingScreen(Map<String, dynamic> appointmentData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ConsultantRatingScreen(appointmentData: appointmentData),
      ),
    ).then((rated) {
      // If rating was submitted successfully, show confirmation
      if (rated == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Thank you for your feedback!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    });
  }

  void _showRatingDialog(BuildContext context, Map<String, dynamic> appointment, String role) {
    final staffId = role == 'consultant' ? appointment['consultantId'] : appointment['conciergeId'];
    final staffName = role == 'consultant' ? appointment['consultantName'] : appointment['conciergeName'];
    int _selectedRating = 0;
    String _notes = '';
    bool _isSubmitting = false;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.black,
              title: Text(
                'Rate service rendered by $staffName',
                style: TextStyle(
                  color: Colors.blue,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Scrollbar(
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(5, (index) {
                          final starValue = index + 1;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 1.0),
                            child: IconButton(
                              icon: Icon(
                                starValue <= _selectedRating ? Icons.star : Icons.star_border,
                                color: starValue <= _selectedRating ? AppColors.gold : Colors.grey,
                              ),
                              onPressed: () {
                                setState(() {
                                  _selectedRating = starValue;
                                });
                              },
                              iconSize: 25,
                              padding: EdgeInsets.zero,
                              constraints: BoxConstraints(),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    minLines: 2,
                    maxLines: 4,
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Add notes (optional)',
                      hintStyle: TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: Colors.grey[900],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.gold),
                      ),
                    ),
                    onChanged: (val) {
                      _notes = val;
                    },
                  ),
                  SizedBox(height: 8),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: _isSubmitting
                      ? null
                      : () async {
                          if (_selectedRating == 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Please select a rating')),
                            );
                            return;
                          }
                          setState(() => _isSubmitting = true);
                          try {
                            final user = Provider.of<AppAuthProvider>(context, listen: false).appUser;
                            if (user == null) throw Exception('User not authenticated');
                            final appointmentId = appointment['id'] != null && appointment['id'].toString().isNotEmpty
      ? appointment['id'].toString()
      : null; // Only use the Firestore doc id
  print('[DEBUG] appointment map in _showRatingDialog: ' + appointment.toString());
                            print('[DEBUG] Using appointmentId for rating: $appointmentId');
                            // Write to ratings collection ONLY
                            try {
                              final ratingData = {
                                'appointmentId': appointmentId,
                                'staffId': staffId,
                                'staffName': staffName,
                                'role': role,
                                'rating': _selectedRating,
                                'notes': _notes,
                                'timestamp': FieldValue.serverTimestamp(),
                                'ministerId': user.uid,
                                'ministerName': user.name,
                                'type': 'Appointment Rating',
                              };
                              print('[DEBUG] Attempting to write rating: ' + ratingData.toString());
                              await FirebaseFirestore.instance.collection('ratings').add(ratingData);
                              print('[DEBUG] Rating written to ratings collection for $role, appointmentId: $appointmentId');
                            } catch (e) {
                              print('[ERROR] Failed to write rating to ratings collection: $e');
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error writing rating: $e')),
                              );
                              setState(() => _isSubmitting = false);
                              return;
                            }
                            // Send notification and FCM to staff
                            final notifService = VipNotificationService();
                            final notifTitle = 'You received a rating';
                            final notifBody = 'You received a rating from the minister: $_selectedRating stars. Notes: $_notes';
                            final notifData = {
                              'appointmentId': appointmentId,
                              'staffId': staffId,
                              'staffName': staffName,
                              'role': role,
                              'rating': _selectedRating,
                              'notes': _notes,
                              'ministerId': user.uid,
                              'ministerName': user.name,
                              'type': 'Appointment Rating',
                            };
                            await notifService.createNotification(
                              title: notifTitle,
                              body: notifBody,
                              data: notifData,
                              role: role,
                              assignedToId: staffId,
                              notificationType: 'rating',
                            );
                            if (mounted) {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Rating submitted successfully')),
                              );
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error submitting rating: $e')),
                            );
                          } finally {
                            setState(() => _isSubmitting = false);
                          }
                        },
                  child: _isSubmitting
                      ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold))
                      : const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AppAuthProvider>(context);
    final ministerData = authProvider.ministerData;
    
    print('MinisterHomeScreen - Minister Data: $ministerData'); // Debug print

    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/page_bg.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        bottomNavigationBar: AppBottomNavBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          items: [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.assignment),
              label: 'Bookings',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.question_answer),
              label: 'Query',
            ),
            BottomNavigationBarItem(
              icon: Builder(
                builder: (context) {
                  final userId = Provider.of<AppAuthProvider>(context, listen: false).appUser?.uid ?? '';
                  return NotificationBellBadge(userId: userId);
                },
              ),
              label: 'Notifications',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.campaign),
              label: 'Marketing',
            ),
          ],
        ),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/Premium.ico',
                  width: 40,
                  height: 40,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 8),
                Text(
                  'Premium Lounge',
                  style: TextStyle(
                    color: AppColors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            if (ministerData != null)
              Text(
                '${ministerData['firstName']} ${ministerData['lastName']}',
                style: TextStyle(color: AppColors.gold, fontSize: 14),
                textAlign: TextAlign.center,
              ),
          ],
        ),
        iconTheme: IconThemeData(color: AppColors.gold),
        actions: [
          IconButton(
            icon: Icon(Icons.directions, color: Colors.blue),
            tooltip: 'Get Directions to Business',
            onPressed: () async {
              try {
                // 1. Get minister's current location
                double? ministerLat;
                double? ministerLng;
                try {
                  final LatLng? userLocation = await DeviceLocationService.getCurrentUserLocation(context);
                  if (userLocation == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Could not get your current location. Please enable location services.')),
                    );
                    return;
                  }
                  ministerLat = userLocation.latitude;
                  ministerLng = userLocation.longitude;
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Could not get your current location. Please enable location services.')),
                  );
                  return;
                }
                // 2. Fetch business address from Firestore
                final doc = await FirebaseFirestore.instance.collection('business').doc('settings').get();
                if (!doc.exists || doc['latitude'] == null || doc['longitude'] == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Business address not set.')),
                  );
                  return;
                }
                final double businessLat = (doc['latitude'] as num).toDouble();
                final double businessLng = (doc['longitude'] as num).toDouble();
                // 3. Launch Google Maps with directions
                final url = 'https://www.google.com/maps/dir/?api=1&origin=${ministerLat},${ministerLng}&destination=${businessLat},${businessLng}&travelmode=driving';
                final uri = Uri.parse(url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Could not open Google Maps.')),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error launching directions: $e')),
                );
              }
            },
          ),
          IconButton(
            icon: Icon(Icons.logout, color: AppColors.gold),
            onPressed: () {
              final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
              authProvider.signOut();
              Navigator.of(context).pushReplacementNamed('/login');
            },
          ),
        ],
      ),
        body: _selectedIndex == 3 
          ? _buildNotificationsView() 
          : _selectedIndex == 4 
            ? const MarketingTabSocialFeed()
            : Column(
                children: [
                  // Tab controller for Marketing and Bookings
                  Expanded(
                    child: DefaultTabController(
                      length: 2,
                      child: Column(
                        children: [
                          TabBar(
                            labelColor: AppColors.gold,
                            unselectedLabelColor: Colors.grey,
                            indicatorColor: AppColors.gold,
                            tabs: const [
                              Tab(text: 'My Broadcast', icon: Icon(Icons.campaign)),
                              Tab(text: 'MY BOOKINGS', icon: Icon(Icons.calendar_today)),
                            ],
                          ),
                          Expanded(
                            child: TabBarView(
                              children: [
                                // Marketing tab
                                const MarketingTabSocialFeed(),
                                // Bookings tab
                                _buildBookingsTab(),
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
    );
  }

  // Simplified direct message sending method without trying to rely on services
  Future<void> _sendDirectMessage({
    required String appointmentId,
    required String text,
    required String recipientId,
    required String recipientRole,
    required String recipientName,
  }) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sending message to $recipientName...')),
      );
      
      final currentUser = Provider.of<AppAuthProvider>(context, listen: false).appUser;
      if (currentUser == null) return;
      
      // Get current user details
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      
      if (!userDoc.exists) return;
      
      final userData = userDoc.data()!;
      final String senderName = userData['name'] ?? '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'.trim();
      
      // Create message in Firestore directly
      await FirebaseFirestore.instance.collection('chat_messages').add({
        'senderId': currentUser.uid,
        'senderName': senderName.isEmpty ? 'Minister' : senderName,
        'senderRole': 'minister',
        'recipientId': recipientId,  
        'recipientRole': recipientRole,
        'message': text,
        'timestamp': FieldValue.serverTimestamp(),
        'appointmentId': appointmentId,
        'isRead': false,
      });
      
      // Use VipNotificationService to send both FCM and in-app notifications
      await _notificationService.sendMessageNotification(
        senderId: currentUser.uid,
        senderName: senderName.isEmpty ? 'Minister' : senderName,
        recipientId: recipientId,
        recipientRole: recipientRole,
        message: text,
        appointmentId: appointmentId,
        senderRole: 'minister',
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Message sent to $recipientName')),
      );
      
      // Reopen the chat dialog after sending the message
      final appointmentDoc = await FirebaseFirestore.instance
          .collection('appointments')
          .doc(appointmentId)
          .get();
      
      if (appointmentDoc.exists) {
        final appointmentData = appointmentDoc.data()!;
        appointmentData['id'] = appointmentId; // Ensure the ID is included
        appointmentData['selectedRole'] = recipientRole;
        
        // Wait a moment before reopening the chat to ensure message is saved
        await Future.delayed(const Duration(milliseconds: 500));
        
        if (mounted) {
          _openChatDialog(appointmentData);
        }
      }
    } catch (e) {
      print('Error sending message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message: $e')),
      );
    }
  }

  // Bookings tab content
  Widget _buildBookingsTab() {
    final user = Provider.of<AppAuthProvider>(context).appUser;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('ministerId', isEqualTo: user?.uid)
          .orderBy('appointmentTime', descending: true) // DESCENDING ORDER
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.calendar_today, size: 48, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  'No bookings yet',
                  style: TextStyle(color: Colors.grey, fontSize: 18),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your booked appointments will appear here',
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      '/minister/choice',
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text('Book an Appointment'),
                ),
              ],
            ),
          );
        }

        final docs = snapshot.data!.docs;
        final now = DateTime.now(); // Use true current local time
      // Check and update status for past pending bookings
      for (final doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final status = (data['status'] ?? '').toLowerCase();
           final rawAppointmentTime = data['appointmentTime'];
           DateTime? appointmentTime;
           if (rawAppointmentTime is Timestamp) {
             appointmentTime = rawAppointmentTime.toDate();
           } else if (rawAppointmentTime is String) {
             appointmentTime = DateTime.tryParse(rawAppointmentTime);
           } else {
             appointmentTime = null;
           }
          if (appointmentTime != null && appointmentTime.isBefore(now) && status == 'pending') {
            // Update status to 'Did Not Attend' in Firestore
            FirebaseFirestore.instance.collection('appointments').doc(doc.id).update({'status': 'Did Not Attend'});
            data['status'] = 'Did Not Attend';
          }
        }

        // --- STRICT DESCENDING ORDER BY appointmentTime ---
      final sortedDocs = List<QueryDocumentSnapshot>.from(docs);
      sortedDocs.sort((a, b) {
         DateTime? aTime;
         DateTime? bTime;
         final aRaw = a['appointmentTime'];
         final bRaw = b['appointmentTime'];
         if (aRaw is Timestamp) {
           aTime = aRaw.toDate();
         } else if (aRaw is String) {
           aTime = DateTime.tryParse(aRaw);
         }
         if (bRaw is Timestamp) {
           bTime = bRaw.toDate();
         } else if (bRaw is String) {
           bTime = DateTime.tryParse(bRaw);
         }
         if (aTime == null && bTime == null) return 0;
         if (aTime == null) return 1;
         if (bTime == null) return -1;
         return bTime.compareTo(aTime); // Descending
      });

        return ListView.builder(
          itemCount: sortedDocs.length,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          itemBuilder: (context, index) {
            final appointmentData = sortedDocs[index].data() as Map<String, dynamic>;
            final appointmentId = sortedDocs[index].id;
             final rawAppointmentTime = appointmentData['appointmentTime'];
             DateTime? appointmentTime;
             if (rawAppointmentTime is Timestamp) {
               appointmentTime = rawAppointmentTime.toDate();
             } else if (rawAppointmentTime is String) {
               appointmentTime = DateTime.tryParse(rawAppointmentTime);
             } else {
               appointmentTime = null;
             }
            final status = appointmentData['status'] as String? ?? 'pending';

            // Determine booking status
            String bookingStatus;
            Color statusColor;
            if (status.toLowerCase() == 'completed') {
              bookingStatus = 'Completed';
              statusColor = Colors.green;
            } else if (status.toLowerCase() == 'cancelled') {
              bookingStatus = 'Cancelled';
              statusColor = Colors.red;
            } else if (status.toLowerCase() == 'in_progress' || status.toLowerCase() == 'in progress') {
              bookingStatus = 'In Progress';
              statusColor = AppColors.gold;
            } else if (appointmentTime != null &&
                appointmentTime.day == now.day &&
                appointmentTime.month == now.month &&
                appointmentTime.year == now.year) {
              bookingStatus = 'Today';
              statusColor = Colors.orange;
            } else if (appointmentTime != null && appointmentTime.isAfter(now)) {
              final difference = appointmentTime.difference(now).inDays;
              bookingStatus = difference == 0
                  ? 'Today'
                  : '$difference days to go';
              statusColor = difference <= 3 ? Colors.orange : Colors.blue;
            } else {
              // If the appointment date has passed, set to 'Did Not Attend'
              bookingStatus = 'Did Not Attend';
              statusColor = Colors.redAccent;
              // Optionally, update Firestore if not already updated above
              if (status != 'Did Not Attend') {
                FirebaseFirestore.instance.collection('appointments').doc(appointmentId).update({'status': 'Did Not Attend'});
              }
            }

            final hasUnreadMessages = _unreadMessageCounts.containsKey(appointmentId) &&
                _unreadMessageCounts[appointmentId]! > 0;
            final unreadCount = _unreadMessageCounts[appointmentId] ?? 0;

            return Card(
              elevation: 4,
              color: Colors.grey[900],
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: statusColor.withOpacity(0.5), width: 1),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            appointmentData['serviceName'] ?? 'Unknown Service',
                            style: TextStyle(
                              color: AppColors.gold,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Icon(Icons.check_circle, color: Colors.green, size: 24), // TICK ICON FOR DEBUGGING
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            bookingStatus,
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 14, color: Colors.blue),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${appointmentData['venueName'] ?? 'Unknown Venue'} - ${appointmentData['serviceName'] ?? 'Unknown Service'}',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 14, color: Colors.grey[400]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            appointmentTime != null
                                ? DateFormat('E, MMM d, yyyy • h:mm a').format(appointmentTime)
                                : 'Unknown Time',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.info_outline, size: 14, color: statusColor),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            bookingStatus,
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider(color: Colors.grey),
                    ),
                    // Feedback status - shows either 'Rate my experience' or 'Feedback submitted'
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Builder(
                        builder: (context) {
                          final hasFeedback = appointmentData['feedbackSubmitted'] == true || 
                                            appointmentData['status'] == 'feedback_submitted';
                          
                          if (hasFeedback) {
                            // Show feedback submitted state
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle, color: Colors.green, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Feedback submitted',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            );
                          } else {
                            // Show rate experience button
                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => MinisterFeedbackScreen(
                                      appointmentId: appointmentId,
                                      ministerId: FirebaseAuth.instance.currentUser?.uid ?? '',
                                    ),
                                  ),
                                ).then((_) {
                                  // Refresh the booking card when returning from feedback screen
                                  if (mounted) {
                                    setState(() {});
                                  }
                                });
                              },
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.star_rate, color: Colors.blue, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Rate my experience',
                                    style: TextStyle(
                                      color: Colors.blue,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                        },
                      ),
                    ),
                    if (appointmentData['consultantId'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0, bottom: 2.0),
                        child: GestureDetector(
                          onTap: () {
                            final Map<String, dynamic> consultantAppointment = Map<String, dynamic>.from(appointmentData);
                            consultantAppointment['id'] = appointmentData['id'] ?? appointmentData['appointmentId'];
                            _showRatingDialog(context, consultantAppointment, 'consultant');
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Icon(Icons.star_border, color: AppColors.gold, size: 20),
                              const SizedBox(width: 5),
                              Text(
                                'Rate Consultant',
                                style: TextStyle(
                                  color: AppColors.gold,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  decoration: TextDecoration.underline,
                                  shadows: [Shadow(blurRadius: 2, color: Colors.black, offset: Offset(1,1))],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (appointmentData['conciergeId'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2.0, bottom: 4.0),
                        child: GestureDetector(
                          onTap: () {
                            final Map<String, dynamic> conciergeAppointment = Map<String, dynamic>.from(appointmentData);
                            conciergeAppointment['id'] = appointmentData['id'] ?? appointmentData['appointmentId'];
                            _showRatingDialog(context, conciergeAppointment, 'concierge');
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Icon(Icons.star_border, color: AppColors.gold, size: 20),
                              const SizedBox(width: 5),
                              Text(
                                'Rate Concierge',
                                style: TextStyle(
                                  color: AppColors.gold,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  decoration: TextDecoration.underline,
                                  shadows: [Shadow(blurRadius: 2, color: Colors.black, offset: Offset(1,1))],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (appointmentData['consultantId'] != null)
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Icon(Icons.person, size: 12, color: Colors.blue),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    'Consultant: ${appointmentData['consultantName'] ?? 'Assigned'}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Chat icon removed per requirements
                        ],
                      ),
                    if (appointmentData['conciergeId'] != null)
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Icon(Icons.support_agent, size: 12, color: Colors.green),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    'Concierge: ${appointmentData['conciergeName'] ?? 'Assigned'}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Chat icon removed per requirements
                        ],
                      ),
                    if (appointmentData['cleanerId'] != null)
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Icon(Icons.cleaning_services, size: 12, color: Colors.orange),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    'Cleaner: ${appointmentData['cleanerName'] ?? 'Assigned'}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('chat_messages')
                                .where('appointmentId', isEqualTo: appointmentId)
                                .where('recipientId', isEqualTo: user?.uid)
                                .where('isRead', isEqualTo: false)
                                .snapshots(),
                            builder: (context, snapshot) {
                              int unreadCount = snapshot.hasData ? snapshot.data!.docs.length : 0;
                              
                              return Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  OutlinedButton.icon(
                                    icon: Icon(Icons.chat, color: AppColors.richGold),
                                    label: Text(
                                      'Chat with Floor Manager',
                                      style: TextStyle(color: AppColors.richGold),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(color: AppColors.richGold),
                                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                    ),
                                    onPressed: () async {
                                      // Get floor manager ID
                                      String floorManagerId = _assignedStaff['floor_manager']?['id'] ?? '';
                                      
                                      // Set selectedRole to floor_manager to chat only with floor manager
                                      _openChatDialog({
                                        ...appointmentData,
                                        'id': appointmentId,
                                        'selectedRole': 'floor_manager'
                                      });
                                      
                                      // Mark all messages as read when opening the chat dialog
                                      FirebaseFirestore.instance
                                          .collection('chat_messages')
                                          .where('appointmentId', isEqualTo: appointmentId)
                                          .where('recipientId', isEqualTo: user?.uid)
                                          .where('isRead', isEqualTo: false)
                                          .get()
                                          .then((querySnapshot) {
                                        for (var doc in querySnapshot.docs) {
                                          doc.reference.update({'isRead': true});
                                        }
                                      });
                                    },
                                  ),
                                  if (unreadCount > 0)
                                    Positioned(
                                      top: -4,
                                      right: -4,
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        constraints: const BoxConstraints(
                                          minWidth: 16,
                                          minHeight: 16,
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          unreadCount.toString(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              );
                              
                              print('✅ [CHAT] Chat message sent to floor manager');
                            },
                          ),
                        ),
                        if (hasUnreadMessages)
                          Container(
                            margin: const EdgeInsets.only(left: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.mark_chat_unread, color: Colors.red, size: 14),
                                const SizedBox(width: 2),
                                Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    unreadCount.toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (appointmentTime != null && appointmentTime.isAfter(now) && status != 'cancelled' && status != 'completed')
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 120),
                            child: ElevatedButton(
                              onPressed: () => _showCancellationDialog(context, appointmentId),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red[800],
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              ),
                              child: const Text(
                                'Cancel Booking',
                                style: TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
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
      },
    );
  }

  void _showCancellationDialog(BuildContext context, String appointmentId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        title: Text(
          'Cancel Booking',
          style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to cancel this booking? This action cannot be undone.',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('No, Keep It'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[800],
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              _cancelAppointment(appointmentId);
              Navigator.of(context).pop();
            },
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelAppointment(String appointmentId) async {
    try {
      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(appointmentId)
          .update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appointment cancelled successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cancelling appointment: $e')),
      );
    }
  }

  Widget _buildRoleLegendItem(String role, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 4),
          Text(
            role, 
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
  
  String _getRoleTitle(String role) {
    switch (role) {
      case 'floor_manager':
        return 'Floor Manager';
      case 'consultant':
        return 'Consultants';
      case 'concierge':
        return 'Concierge';
      case 'cleaner':
        return 'Cleaner';
      default:
        return '';
    }
  }
  
  bool _hasMultipleAssignedStaff(Map<String, dynamic> appointment) {
    int assignedCount = 0;
    if (appointment['floorManagerId'] != null) assignedCount++;
    if (appointment['consultantId'] != null) assignedCount++;
    if (appointment['conciergeId'] != null) assignedCount++;
    if (appointment['cleanerId'] != null) assignedCount++;
    return assignedCount > 1;
  }
  
  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  Widget _buildAppointmentCard(Map<String, dynamic> appointment) {
    final appointmentId = appointment['id'] as String? ?? '';
    final serviceType = appointment['service'] ?? appointment['serviceName'] ?? 'VIP Service';
    final venue = appointment['venue'] ?? 'VIP Lounge';
    
    // Get appointment date and time
    final appointmentTime = appointment['appointmentTime'] as Timestamp?;
    final appointmentDate = appointmentTime != null ? appointmentTime.toDate() : DateTime.now();
    
    // Format date and time for display
    final formattedDate = DateFormat('EEEE, MMMM d').format(appointmentDate);
    final bool isCompleted = (appointment['status']?.toString()?.toLowerCase() == 'completed');
    final formattedTime = DateFormat('h:mm a').format(appointmentDate);
    
    // Check booking status
    final status = _capitalize(appointment['status'] ?? 'Pending');
    
    // Get assigned staff information
    final consultantId = appointment['consultantId'] as String?;
    final consultantName = appointment['consultantName'] as String? ?? 'Not assigned';
    
    final conciergeId = appointment['conciergeId'] as String?;
    final conciergeName = appointment['conciergeName'] as String? ?? 'Not assigned';
    
    final cleanerId = appointment['cleanerId'] as String?;
    final cleanerName = appointment['cleanerName'] as String? ?? 'Not assigned';
    
    // Determine border color based on status
    Color borderColor;
    if (status.toLowerCase() == 'completed') {
      borderColor = Colors.green;
    } else if (status.toLowerCase() == 'cancelled') {
      borderColor = Colors.red;
    } else if (status.toLowerCase() == 'in progress' || status.toLowerCase() == 'in_progress') {
      borderColor = AppColors.gold;
    } else {
      borderColor = Colors.grey;
    }
    
    // Check for unread messages - safely access the unread messages count
    final hasUnreadMessages = _unreadMessageCounts.containsKey(appointmentId) && 
                            _unreadMessageCounts[appointmentId]! > 0;
    final unreadCount = _unreadMessageCounts[appointmentId] ?? 0;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: 1),
      ),
      color: Colors.grey[900],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date and service header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Service name
                  Expanded(
                    child: Text(
                      serviceType,
                      style: TextStyle(
                        color: AppColors.gold,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  
                  // Status pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: borderColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: borderColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Date and time info
              Row(
                children: [
                  Icon(Icons.calendar_today, color: AppColors.gold, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    formattedDate,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (isCompleted) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.check_circle, color: Colors.green, size: 18),
                  ],
                ],
              ),
              
              const SizedBox(height: 4),
              
              Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: Colors.grey[400]),
                  const SizedBox(width: 8),
                  Text(
                    formattedTime,
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              
              GestureDetector(
                onTap: () async {
                  try {
                    final LatLng? userLocation = await DeviceLocationService.getCurrentUserLocation(context);
                    if (userLocation == null) {
                      // Error already handled by service
                      return;
                    }
                    // Show user location for debugging
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Your location: [${userLocation.latitude}, ${userLocation.longitude}]')),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Could not get your current location. Please enable location services.')),
                    );
                  }
                },
                child: Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      venue,
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(color: Colors.grey),
              ),
              
              // Staff section
              Text(
                'Assigned Staff',
                style: TextStyle(
                  color: AppColors.gold,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Build staff rows with individual chat functionality
               _buildStaffRow('Consultant', consultantName, consultantId, appointmentId, appointment),
               if (status.toLowerCase() == 'completed' && consultantId != null && consultantId.isNotEmpty)
                 Padding(
                   padding: const EdgeInsets.only(left: 32.0, top: 2.0, bottom: 2.0),
                   child: GestureDetector(
                     onTap: () {
  final Map<String, dynamic> appointmentWithId = Map<String, dynamic>.from(appointment);
  appointmentWithId['id'] = appointment['id'] ?? appointmentId;
  _showRatingDialog(context, appointmentWithId, 'consultant');
},
                     child: Flexible(
                       child: Row(
                         mainAxisSize: MainAxisSize.min,
                         children: [
                           Icon(Icons.star_border, color: AppColors.gold, size: 18),
                           const SizedBox(width: 6),
                           Flexible(
                             child: Text(
                               'Rate Experience',
                               style: TextStyle(
                                 color: AppColors.gold,
                                 decoration: TextDecoration.underline,
                                 fontWeight: FontWeight.w600,
                               ),
                               overflow: TextOverflow.ellipsis,
                               maxLines: 1,
                             ),
                           ),
                         ],
                       ),
                     ),
                   ),
                 ),
               _buildStaffRow('Concierge', conciergeName, conciergeId, appointmentId, appointment),
               if (status.toLowerCase() == 'completed' && conciergeId != null && conciergeId.isNotEmpty)
                 Padding(
                   padding: const EdgeInsets.only(left: 32.0, top: 2.0, bottom: 2.0),
                   child: GestureDetector(
                     onTap: () {
  final Map<String, dynamic> appointmentWithId = Map<String, dynamic>.from(appointment);
  appointmentWithId['id'] = appointment['id'] ?? appointmentId;
  _showRatingDialog(context, appointmentWithId, 'concierge');
},
                     child: Flexible(
                       child: Row(
                         mainAxisSize: MainAxisSize.min,
                         children: [
                           Icon(Icons.star_border, color: AppColors.gold, size: 18),
                           const SizedBox(width: 6),
                           Flexible(
                             child: Text(
                               'Rate Experience',
                               style: TextStyle(
                                 color: AppColors.gold,
                                 decoration: TextDecoration.underline,
                                 fontWeight: FontWeight.w600,
                               ),
                               overflow: TextOverflow.ellipsis,
                               maxLines: 1,
                             ),
                           ),
                         ],
                       ),
                     ),
                   ),
                 ),
              _buildStaffRow('Cleaner', cleanerName, cleanerId, appointmentId, appointment),
              
              // Actions section
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Rate My Experience label
                    if (status.toLowerCase() == 'completed' && 
                        (consultantId != null || conciergeId != null))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: GestureDetector(
                          onTap: () {
                            final Map<String, dynamic> appointmentWithId = Map<String, dynamic>.from(appointment);
                            appointmentWithId['id'] = appointment['id'] ?? appointmentId;
                            // Default to consultant if available, otherwise use concierge
                            final role = consultantId != null ? 'consultant' : 'concierge';
                            _showRatingDialog(context, appointmentWithId, role);
                          },
                          child: Text(
                            'Rate My Experience',
                            style: TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                    
                    // Rating button
                    if (status.toLowerCase() == 'completed' && 
                        (consultantId != null || conciergeId != null))
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 180),
                        child: ElevatedButton.icon(
                          onPressed: () {
                            final Map<String, dynamic> appointmentWithId = Map<String, dynamic>.from(appointment);
                            appointmentWithId['id'] = appointment['id'] ?? appointmentId;
                            // Default to consultant if available, otherwise use concierge
                            final role = consultantId != null ? 'consultant' : 'concierge';
                            _showRatingDialog(context, appointmentWithId, role);
                          },
                          icon: const Icon(Icons.star, size: 16),
                          label: const Text('Rate My Experience'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.gold,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      )
                    else if (status.toLowerCase() != 'completed' && status.toLowerCase() != 'cancelled')
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 150),
                        child: ElevatedButton(
                          onPressed: () => _showCancellationDialog(context, appointmentId),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[800],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          ),
                          child: const Text(
                            'Cancel Booking',
                            style: TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
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
    );
  }

  void _handleNotificationTap(Map<String, dynamic> notification) {
    final notificationType = notification['notificationType'] as String? ?? 'general';
    final appointmentId = notification['appointmentId'] as String? ?? '';
    
    // Mark notification as read in Firebase
    if (notification['id'] != null) {
      FirebaseFirestore.instance
          .collection('notifications')
          .doc(notification['id'])
          .update({'isRead': true});
      
      // Do NOT remove the notification from the local list; just mark as read in Firestore.
      // This allows ministers to return to the chat/notification later.
      // Optionally, you may want to update the UI to reflect its read status (e.g., fade or icon change),
      // but do NOT remove it from _unreadNotificationsList here.
      setState(() {
        // Never remove the notification from the list, just mark as read
        final notifIndex = _unreadNotificationsList.indexWhere((notif) => notif['id'] == notification['id']);
        if (notifIndex != -1) {
          _unreadNotificationsList[notifIndex]['isRead'] = true;
        }
        // Optionally update counters if you want to reflect "read" status in the UI
        final type = notification['notificationType'] as String? ?? 'general';
        if (_notificationTypeCount.containsKey(type) && _notificationTypeCount[type]! > 0) {
          _notificationTypeCount[type] = _notificationTypeCount[type]! - 1;
        }
        _unreadNotifications = _unreadNotificationsList.where((notif) => notif['isRead'] != true).length;
      });
    }
    
    // Find the corresponding appointment if this notification has an appointmentId
    if (appointmentId.isNotEmpty) {
      // Get appointment data from Firestore
      FirebaseFirestore.instance
          .collection('appointments')
          .doc(appointmentId)
          .get()
          .then((snapshot) {
            if (snapshot.exists) {
              final appointmentData = snapshot.data()!;
              appointmentData['id'] = appointmentId; // Ensure the ID is included
              // Switch to the Bookings tab
              setState(() {
                _selectedIndex = 1;
              });
              // Open the rating screen if notification is rating
              if ((notification['notificationType'] == 'rating' || (notification['data']?['showRating'] == true))) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ConsultantRatingScreen(appointmentData: appointmentData),
                  ),
                );
              } else {
                _openChatDialog({...appointmentData, 'id': appointmentId});
              }
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Appointment not found')),
              );
            }
          })
          .catchError((error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error retrieving appointment: $error')),
            );
          });
    }
  }

  void _handleChatAction(Map<String, dynamic> appointment) {
    final appointmentId = appointment['id'] as String? ?? '';
    final user = Provider.of<AppAuthProvider>(context, listen: false).appUser;
    
    if (user != null && appointmentId.isNotEmpty) {
      // Mark messages as read in Firestore
      FirebaseFirestore.instance
          .collection('chat_messages')
          .where('appointmentId', isEqualTo: appointmentId)
          .where('recipientId', isEqualTo: user.uid)
          .where('isRead', isEqualTo: false)
          .get()
          .then((snapshot) {
            // Update isRead status for all messages
            for (var doc in snapshot.docs) {
              doc.reference.update({'isRead': true});
            }
            
            // Clear unread count for this appointment
            if (mounted && _unreadMessageCounts.containsKey(appointmentId)) {
              setState(() {
                _unreadMessageCounts.remove(appointmentId);
                
                // Also remove from notifications list
                _unreadNotificationsList.removeWhere((notif) => 
                  notif['appointmentId'] == appointmentId && notif['type'] == 'message');
                
                // Update notification type count
                _notificationTypeCount['message'] = snapshot.docs.isNotEmpty 
                  ? (_notificationTypeCount['message'] ?? 0) - snapshot.docs.length 
                  : _notificationTypeCount['message'] ?? 0;
                if (_notificationTypeCount['message']! < 0) _notificationTypeCount['message'] = 0;
              });
            }
          });
    }
    
    // Open the chat dialog
    _openChatDialog(appointment);
  }

  Widget _buildStaffRow(
    String role, 
    String? staffName, 
    String? staffId, 
    String appointmentId,
    Map<String, dynamic> appointment
  ) {
    // Don't display anything if no staff is assigned
    if (staffId == null || staffName == null || staffName.isEmpty) {
      return const SizedBox.shrink();
    }
    
    // Format the name to show first name initial and full last name
    String formattedName = staffName;
    if (staffName.contains(" ")) {
      final nameParts = staffName.split(" ");
      if (nameParts.length >= 2) {
        String firstName = nameParts[0];
        String lastName = nameParts.sublist(1).join(" ");
        formattedName = "${firstName[0]}. $lastName";
      }
    }
    
    // Determine if chat should be shown (don't show for cleaners)
    bool showChat = role.toLowerCase() != 'cleaner';
    
    // Get role-based colors
    Color roleColor = Colors.grey;
    IconData roleIcon = Icons.person;
    
    if (role.toLowerCase() == 'consultant') {
      roleColor = Colors.blue;
      roleIcon = Icons.person;
    } else if (role.toLowerCase() == 'concierge') {
      roleColor = Colors.green;
      roleIcon = Icons.support_agent;
    } else if (role.toLowerCase() == 'cleaner') {
      roleColor = Colors.orange;
      roleIcon = Icons.cleaning_services;
    } else if (role.toLowerCase() == 'floor_manager') {
      roleColor = Colors.red;
      roleIcon = Icons.admin_panel_settings;
    }
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Staff role and name on one line
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(roleIcon, size: 12, color: roleColor),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '$role: $formattedName',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Chat button below the name if staff is eligible for chat
          if (showChat)
            Padding(
              padding: const EdgeInsets.only(top: 4.0, left: 24.0),
              child: Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chat_bubble_outline),
                    color: AppColors.gold,
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Message $staffName',
                    onPressed: () {
                      // Chat directly with staff
                      final Map<String, dynamic> chatData = {
                        ...appointment,
                        'id': appointmentId,
                        'selectedRole': role.toLowerCase(),
                        'recipientId': staffId,
                        'recipientName': staffName,
                      };
                      _openChatDialog(chatData);
                    },
                  ),
                  if (_unreadNotificationsList.any((notif) => 
                      notif['appointmentId'] == appointmentId && notif['type'] == 'message' && notif['senderRole'] == role.toLowerCase() && notif['recipientRole'] == 'minister'))
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          // Rate Experience button for consultant/concierge
          if (role.toLowerCase() == 'consultant' || role.toLowerCase() == 'concierge')
            Padding(
              padding: const EdgeInsets.only(top: 4.0, left: 24.0),
              child: GestureDetector(
                onTap: () async {
                  try {
                    final appointmentDoc = await FirebaseFirestore.instance
                        .collection('appointments')
                        .doc(appointmentId)
                        .get();
                    if (!appointmentDoc.exists) {
                      print('[ERROR] Appointment not found: ' + appointmentId);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Error: Appointment not found. Cannot submit rating.')),
                      );
                      return;
                    }
                    final appointmentData = appointmentDoc.data()!;
                    final Map<String, dynamic> appointmentWithId = Map<String, dynamic>.from(appointmentData);
                    appointmentWithId['id'] = appointmentDoc.id;
                    print('[DEBUG] appointmentData passed to _showRatingDialog: ' + appointmentWithId.toString());
                    if (!(appointmentWithId['id'] != null && appointmentWithId['id'].toString().isNotEmpty)) {
                      if (appointmentWithId['appointmentId'] != null && appointmentWithId['appointmentId'].toString().isNotEmpty) {
                        appointmentWithId['id'] = appointmentWithId['appointmentId'];
                      }
                    }
                    _showRatingDialog(context, appointmentWithId, role.toLowerCase());
                  } catch (e) {
                    print('[ERROR] Failed to fetch appointment for rating: $e');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: Failed to fetch appointment for rating.')),
                    );
                  }
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star_border, color: AppColors.gold, size: 18),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Rate Experience',
                        style: TextStyle(
                          color: AppColors.gold,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
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

  Widget _buildNotificationIcon() {
    final bool hasMessages = (_notificationTypeCount['message'] ?? 0) > 0;
    final bool hasAppointments = (_notificationTypeCount['appointment'] ?? 0) > 0;
    final bool hasGeneral = (_notificationTypeCount['general'] ?? 0) > 0;
    
    return Stack(
      children: [
        const Icon(Icons.notifications),
        
        // Show red dot for messages (top right)
        if (hasMessages)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(
                minWidth: 14,
                minHeight: 14,
              ),
              child: Text(
                _notificationTypeCount['message'].toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          
        // Show gold dot for appointment notifications (bottom right)
        if (hasAppointments)
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: AppColors.gold,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(
                minWidth: 14,
                minHeight: 14,
              ),
              child: Text(
                _notificationTypeCount['appointment'].toString(),
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        
        // Show blue dot for general notifications (bottom left)
        if (hasGeneral)
          Positioned(
            left: -2,
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(
                minWidth: 14,
                minHeight: 14,
              ),
              child: Text(
                _notificationTypeCount['general'].toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNotificationsView() {
    final user = Provider.of<AppAuthProvider>(context, listen: false).appUser;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('assignedToId', isEqualTo: user?.uid)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.gold));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No notifications', style: TextStyle(color: Colors.white70)));
        }
        final notifications = snapshot.data!.docs;
        return ListView.builder(
          itemCount: notifications.length,
          itemBuilder: (context, index) {
            final doc = notifications[index];
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;
            return NotificationItem(
              notification: data,
              onTapCallback: () {},
              onDismissCallback: () {},
            );
          },
        );
      },
    );
  }

  Future<void> _startConsultantSession(String appointmentId) async {
    final now = DateTime.now();
    await FirebaseFirestore.instance.collection('appointments').doc(appointmentId).update({
      'consultantSessionStart': now,
    });
  }

  Future<void> _endConsultantSession(String appointmentId) async {
    final now = DateTime.now();
    await FirebaseFirestore.instance.collection('appointments').doc(appointmentId).update({
      'consultantSessionEnd': now,
    });
  }

  Future<void> _startConciergeSession(String appointmentId) async {
    final now = DateTime.now();
    await FirebaseFirestore.instance.collection('appointments').doc(appointmentId).update({
      'conciergeSessionStart': now,
    });
  }

  Future<void> _endConciergeSession(String appointmentId) async {
    final now = DateTime.now();
    await FirebaseFirestore.instance.collection('appointments').doc(appointmentId).update({
      'conciergeSessionEnd': now,
    });
  }

  Future<void> _fetchAppointmentAndOpenChat(String appointmentId) async {
    try {
      final appointmentDoc = await FirebaseFirestore.instance
          .collection('appointments')
          .doc(appointmentId)
          .get();
          
      if (!appointmentDoc.exists) {
        print('Appointment not found for chat: $appointmentId');
        return;
      }
      
      final data = appointmentDoc.data()!;
      
      openChatForAppointment(appointmentId);
    } catch (e) {
      print('Error fetching appointment for chat: $e');
    }
  }
  
  Future<void> _fetchAndHighlightAppointment(String appointmentId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('appointments')
          .doc(appointmentId)
          .get();
          
      if (!doc.exists) {
        print('Appointment not found: $appointmentId');
        return;
      }
      
      final data = doc.data()!;
      
      setState(() {
        _highlightedAppointmentId = appointmentId;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Viewing appointment details')),
      );
    } catch (e) {
      print('Error fetching appointment: $e');
    }
  }
}

class _AddCommentBox extends StatefulWidget {
  final String postId;
  const _AddCommentBox({required this.postId});

  @override
  State<_AddCommentBox> createState() => _AddCommentBoxState();
}

class _AddCommentBoxState extends State<_AddCommentBox> {
  final TextEditingController _controller = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    if (_controller.text.trim().isEmpty) return;
    setState(() => _isSubmitting = true);
    try {
      final ministerData = Provider.of<AppAuthProvider>(context, listen: false).ministerData;
      final user = FirebaseAuth.instance.currentUser;
      final userName = ministerData != null ? (ministerData['fullName'] ?? 'Minister') : (user?.displayName ?? 'Anonymous');
      await FirebaseFirestore.instance
          .collection('marketing_posts')
          .doc(widget.postId)
          .collection('comments')
          .add({
        'text': _controller.text.trim(),
        'userId': user?.uid,
        'userName': userName,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _controller.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to add comment: $e')));
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              enabled: !_isSubmitting,
              decoration: InputDecoration(
                hintText: 'Add a comment...',
                hintStyle: TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              style: TextStyle(color: Colors.white),
              minLines: 1,
              maxLines: 4,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: _isSubmitting ? CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold) : Icon(Icons.send, color: AppColors.gold),
            onPressed: _isSubmitting ? null : _submitComment,
          )
        ],
      ),
    );
  }
}

class _RepliesList extends StatelessWidget {
  final String postId;
  final String commentId;
  const _RepliesList({required this.postId, required this.commentId});

  // Add a static helper for formatting comment dates
  static String _formatCommentDate(Timestamp? createdAt) {
    if (createdAt == null) return '';
    final dt = createdAt.toDate();
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return DateFormat('HH:mm').format(dt);
    }
    return DateFormat('MMM d, HH:mm').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('marketing_posts')
          .doc(postId)
          .collection('comments')
          .doc(commentId)
          .collection('replies')
          .orderBy('createdAt', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox();
        }
        final replies = snapshot.data?.docs ?? [];
        if (replies.isEmpty) return const SizedBox();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: replies.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final String userName = data['userName'] ?? 'Anonymous';
            final String text = data['text'] ?? '';
            final Timestamp? createdAt = data['createdAt'];
            final String? avatarUrl = data['avatarUrl'];
            final DateTime? date = createdAt != null ? createdAt.toDate() : null;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 10,
                    backgroundColor: AppColors.gold.withOpacity(0.15),
                    backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                    child: avatarUrl == null ? Icon(Icons.person, size: 12, color: AppColors.gold) : null,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(userName, style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 12)),
                            if (date != null) ...[
                              const SizedBox(width: 6),
                              Text(_formatCommentDate(createdAt), style: TextStyle(color: Colors.white38, fontSize: 10)),
                            ]
                          ],
                        ),
                        const SizedBox(height: 1),
                        Text(text, style: TextStyle(color: Colors.white, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _AddReplyBox extends StatefulWidget {
  final String postId;
  final String commentId;
  const _AddReplyBox({required this.postId, required this.commentId});
  @override
  State<_AddReplyBox> createState() => _AddReplyBoxState();
}

class _AddReplyBoxState extends State<_AddReplyBox> {
  final TextEditingController _controller = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submitReply() async {
    if (_controller.text.trim().isEmpty) return;
    setState(() => _isSubmitting = true);
    try {
      final ministerData = Provider.of<AppAuthProvider>(context, listen: false).ministerData;
      final user = FirebaseAuth.instance.currentUser;
      final userName = ministerData != null ? (ministerData['fullName'] ?? 'Minister') : (user?.displayName ?? 'Anonymous');
      await FirebaseFirestore.instance
          .collection('marketing_posts')
          .doc(widget.postId)
          .collection('comments')
          .doc(widget.commentId)
          .collection('replies')
          .add({
        'text': _controller.text.trim(),
        'userId': user?.uid,
        'userName': userName,
        'createdAt': FieldValue.serverTimestamp(),
        // 'avatarUrl': user?.photoURL, // Uncomment if available
      });
      _controller.clear();
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to add reply: $e')));
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                enabled: !_isSubmitting,
                decoration: InputDecoration(
                  hintText: 'Write a reply...',
                  hintStyle: TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                style: TextStyle(color: Colors.white),
                minLines: 1,
                maxLines: 4,
                autofocus: true,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: _isSubmitting ? CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold) : Icon(Icons.send, color: AppColors.gold),
              onPressed: _isSubmitting ? null : _submitReply,
            )
          ],
        ),
      ),
    );
  }
}

Color _getTypeColor(String? type) {
  switch (type?.toLowerCase()) {
    case 'offer':
      return Colors.deepPurple;
    case 'event':
      return Colors.teal;
    case 'announcement':
      return Colors.blueGrey;
    case 'reminder':
      return Colors.orange;
    default:
      return AppColors.gold;
  }
}
