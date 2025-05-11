import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/app_auth_provider.dart';
import 'dart:async';
import 'dart:math';

import '../../../../core/constants/colors.dart';
import '../../../../features/floor_manager/presentation/screens/notifications_screen.dart';
import '../../../../core/services/vip_notification_service.dart';
import '../../../../core/services/vip_messaging_service.dart';
import 'package:vip_lounge/core/widgets/staff_performance_widget.dart';
import 'package:vip_lounge/features/consultant/presentation/widgets/performance_metrics_widget.dart';
import '../widgets/concierge_appointment_widget.dart';
import '../../../../features/floor_manager/widgets/attendance_actions_widget.dart';
import '../../../../core/services/device_location_service.dart';
import '../../../../core/widgets/role_notification_list.dart';
import '../../../../core/widgets/unified_appointment_card.dart';

class LatLng {
  final double latitude;
  final double longitude;
  LatLng(this.latitude, this.longitude);
}

class ConciergeHomeScreenAttendance extends StatefulWidget {
  const ConciergeHomeScreenAttendance({Key? key}) : super(key: key);

  @override
  State<ConciergeHomeScreenAttendance> createState() => _ConciergeHomeScreenAttendanceState();
}

class _ConciergeHomeScreenAttendanceState extends State<ConciergeHomeScreenAttendance> {
  String _conciergeId = '';
  String _conciergeName = '';
  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _appointments = [];
  bool _isLoading = true;
  int _currentIndex = 0;
  int _unreadNotifications = 0;
  List<Map<String, dynamic>> _unreadNotificationsList = [];
  Map<String, dynamic> _metricsData = {
    'totalAppointments': 0,
    'completedAppointments': 0,
    'inProgressAppointments': 0,
    'completionRate': 0,
  };

  final VipNotificationService _notificationService = VipNotificationService();
  final VipMessagingService _messagingService = VipMessagingService();
  StreamSubscription? _notificationsSubscription;

  // Unread messages count per appointment (for badge)
  Map<String, int> _appointmentUnreadCounts = {};
  bool _isClockedIn = true; // TODO: Replace with real clock-in logic if needed
  double _allowedDistanceInMeters = 1000.0;
  double _currentLatitude = 0.0;
  double _currentLongitude = 0.0;

  // Current device location

  @override
  void initState() {
    super.initState();
    _loadConciergeDetails();
  }

  Future<void> _loadConciergeDetails() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data();
        setState(() {
          _conciergeId = user.uid;
          _conciergeName = userData != null ? '${userData['firstName']} ${userData['lastName']}' : 'concierge';
        });
      }
    }
    // Set the UID early so it is available for all subsequent calls
    await Future.delayed(Duration.zero);
    _loadAppointments();
    _setupNotificationListener();
    _setupMessageListener();
  }

  void _setupNotificationListener() {
    if (_conciergeId.isEmpty) return;
    setState(() {
      _unreadNotificationsList = [];
      _unreadNotifications = 0;
    });
    _notificationsSubscription = FirebaseFirestore.instance
        .collection('notifications')
        .where('assignedToId', isEqualTo: _conciergeId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      List<Map<String, dynamic>> notificationsList = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        // Use the full notification data, including nested 'data' field if present
        notificationsList.add({...data, 'id': doc.id});
      }
      setState(() {
        _unreadNotificationsList = notificationsList;
        _unreadNotifications = notificationsList.length;
      });
    }, onError: (error) {
      setState(() {
        _unreadNotificationsList = [];
        _unreadNotifications = 0;
      });
    });
  }

  void _setupMessageListener() {
    if (_conciergeId.isEmpty) return;
    FirebaseFirestore.instance
        .collection('messages')
        .where('recipientId', isEqualTo: _conciergeId)
        .where('recipientRole', isEqualTo: 'concierge')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .listen((snapshot) {
      print('DEBUG: Messages received for conciergeId=$_conciergeId: count = \u001b[32m'+snapshot.docs.length.toString()+'\u001b[0m');
      // Implement message handling logic if needed
    }, onError: (error) {
      print('DEBUG: Error receiving messages: '+error.toString());
      // Handle error
    });
  }

  Future<void> _loadAppointments() async {
    if (_conciergeId.isEmpty) return;
    setState(() {
      _isLoading = true;
    });
    try {
      final startOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      // Query for conciergeId
      final appointmentsQuery1 = await FirebaseFirestore.instance
          .collection('appointments')
          .where('conciergeId', isEqualTo: _conciergeId)
          .where('appointmentTime', isGreaterThanOrEqualTo: startOfDay)
          .where('appointmentTime', isLessThan: endOfDay)
          .get();
      // Query for assignedConciergeId
      final appointmentsQuery2 = await FirebaseFirestore.instance
          .collection('appointments')
          .where('assignedConciergeId', isEqualTo: _conciergeId)
          .where('appointmentTime', isGreaterThanOrEqualTo: startOfDay)
          .where('appointmentTime', isLessThan: endOfDay)
          .get();
      List<Map<String, dynamic>> appointments = [];
      final Set<String> seenIds = {};
      for (var doc in [...appointmentsQuery1.docs, ...appointmentsQuery2.docs]) {
        if (seenIds.contains(doc.id)) continue;
        seenIds.add(doc.id);
        final data = doc.data();
        data['id'] = doc.id;
        appointments.add(data);
      }
      for (var appt in appointments) {
        final ts = appt['appointmentTime'];
        if (ts is Timestamp) {
          final dt = ts.toDate();
          print('DEBUG: Appointment id=${appt['id']}, date=\x1b[33m${dt.toIso8601String()}\x1b[0m');
        }
      }
      print('DEBUG: Appointments loaded for date \x1b[33m'+startOfDay.toIso8601String()+'\x1b[0m: count = \x1b[32m'+appointments.length.toString()+'\x1b[0m');
      setState(() {
        _appointments = appointments;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Attendance widget integration
  Widget _buildAttendanceContainer() {
    return AttendanceActionsWidget(
      userId: _conciergeId,
      name: _conciergeName,
      role: 'concierge',
    );
  }

  // Weekly schedule selector for the dashboard (mirrors consultant)
  Widget _buildWeeklySchedule() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final days = List.generate(7, (i) => startOfWeek.add(Duration(days: i)));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: days.map((day) {
            final isSelected = _selectedDate.year == day.year && _selectedDate.month == day.month && _selectedDate.day == day.day;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedDate = day;
                  _loadAppointments();
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.gold : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.gold),
                ),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                child: Column(
                  children: [
                    Text(
                      DateFormat('E').format(day),
                      style: TextStyle(
                        color: isSelected ? Colors.black : AppColors.gold,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('d').format(day),
                      style: TextStyle(
                        color: isSelected ? Colors.black : AppColors.gold,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // Appointment card widget for the dashboard (mirrors consultant)
  Widget _buildDashboardContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildWeeklySchedule(),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Appointments',
                style: TextStyle(
                  color: AppColors.gold,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _appointments.isEmpty
              ? const Center(
                  child: Text('No appointments scheduled.', style: TextStyle(color: Colors.white)),
                )
              : ListView.builder(
                  itemCount: _appointments.length,
                  itemBuilder: (context, index) {
                    final appt = _appointments[index];
                    return UnifiedAppointmentCard(
                      role: 'concierge',
                      isConsultant: false,
                      ministerName: appt['ministerName'] ?? '',
                      appointmentId: appt['id'] ?? '',
                      appointmentInfo: appt,
                      date: appt['appointmentTime'] is DateTime
                          ? appt['appointmentTime']
                          : (appt['appointmentTime'] is Timestamp)
                              ? (appt['appointmentTime'] as Timestamp).toDate()
                              : DateTime.now(),
                      time: null,
                      ministerId: appt['ministerId'],
                      disableStartSession: false,
                    );
                  },
                ),
        ),
      ],
    );
  }

  // Notifications view
  Widget _buildNotificationsView() {
    if (_conciergeId.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    // Use the new uniform notification widget
    return RoleNotificationList(
      userId: _conciergeId,
      userRole: 'concierge',
      showTitle: false,
    );
  }

  String _performanceTimeframe = 'Month';

  DateTime _getPerformanceDateForTimeframe(String timeframe) {
    final now = DateTime.now();
    switch (timeframe) {
      case 'Year':
        return DateTime(now.year, 1, 1);
      case 'Month':
        return DateTime(now.year, now.month, 1);
      case 'Week':
        final weekDay = now.weekday;
        return now.subtract(Duration(days: weekDay - 1)); // Monday
      case 'Future':
        return now.add(const Duration(days: 30));
      default:
        return now;
    }
  }

  Widget _buildPerformanceTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              const Text('Show:', style: TextStyle(color: Colors.white70)),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _performanceTimeframe,
                dropdownColor: Colors.black,
                iconEnabledColor: Colors.white,
                style: const TextStyle(color: Colors.white),
                items: ['Year', 'Month', 'Week', 'Future']
                    .map((val) => DropdownMenuItem(
                          value: val,
                          child: Text(val),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _performanceTimeframe = val;
                      _selectedDate = _getPerformanceDateForTimeframe(val);
                    });
                  }
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            children: [
              Flexible(
                child: PerformanceMetricsWidget(
                  consultantId: _conciergeId,
                  role: 'concierge',
                  selectedDate: _selectedDate,
                ),
              ),
              StaffPerformanceWidget(
                userId: _conciergeId,
                role: 'concierge',
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Opens the full chat dialog for the given appointment and minister
  Future<void> _openFullChatDialog(BuildContext context, Map<String, dynamic> appointment, String ministerId) async {
    final appointmentId = appointment['id'];
    final ministerName = appointment['ministerName'] ?? 'Minister';
    // Mark messages as read first (mirroring consultant)
    await _markMessagesAsRead(appointmentId);
    final TextEditingController messageController = TextEditingController();
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Scaffold(
              backgroundColor: Colors.black,
              appBar: AppBar(
                backgroundColor: Colors.black,
                title: Text(
                  'Chat with Minister $ministerName',
                  style: TextStyle(
                    color: AppColors.gold,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                leading: IconButton(
                  icon: Icon(Icons.arrow_back, color: AppColors.gold),
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
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        final messages = snapshot.data?.docs ?? [];
                        if (messages.isEmpty) {
                          return Center(
                            child: Text(
                              'No messages yet. Start the conversation!',
                              style: TextStyle(color: Colors.grey[600]),
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
                            final messageContent = message['message'];
                            final timestamp = message['timestamp'] as Timestamp?;
                            final isSentByCurrentUser = senderId == _conciergeId;
                            IconData notificationIcon;
                            Color iconColor;
                            if (isSentByCurrentUser) {
                              notificationIcon = Icons.person;
                              iconColor = Colors.blue;
                            } else {
                              notificationIcon = Icons.person_add;
                              iconColor = AppColors.gold;
                            }
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
                                      backgroundColor: iconColor,
                                      radius: 16,
                                      child: Text(
                                        senderName?.isNotEmpty == true
                                            ? senderName[0].toUpperCase()
                                            : 'M',
                                        style: const TextStyle(
                                          color: Colors.black,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  if (!isSentByCurrentUser)
                                    const SizedBox(width: 8),
                                  Flexible(
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: isSentByCurrentUser ? Colors.blue[100] : AppColors.gold.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            messageContent ?? '',
                                            style: TextStyle(
                                              color: isSentByCurrentUser ? Colors.black : AppColors.gold,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          if (timestamp != null)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 4.0),
                                              child: Text(
                                                DateFormat('h:mm a').format(timestamp.toDate()),
                                                style: TextStyle(
                                                  color: Colors.grey[500],
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                        ],
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    color: Colors.black,
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Type a message...',
                              hintStyle: TextStyle(color: Colors.grey[600]),
                              filled: true,
                              fillColor: Colors.grey[900],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(Icons.send, color: AppColors.gold),
                          onPressed: () async {
                            final text = '';
                            if (text.isEmpty) return;
                            await _sendDirectMessage(
                              appointmentId: appointmentId,
                              message: text,
                              recipientId: ministerId,
                              recipientRole: 'minister',
                              recipientName: ministerName,
                            );
                          },
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
    );
  }

  // Mark all unread messages as read for this appointment (mirrors consultant logic)
  Future<void> _markMessagesAsRead(String appointmentId) async {
    try {
      final unreadMessages = await FirebaseFirestore.instance
          .collection('messages')
          .where('appointmentId', isEqualTo: appointmentId)
          .where('recipientId', isEqualTo: _conciergeId)
          .where('recipientRole', isEqualTo: 'concierge')
          .where('isRead', isEqualTo: false)
          .get();
      for (var doc in unreadMessages.docs) {
        await doc.reference.update({'isRead': true});
      }
      // Also mark any related notifications as read
      final unreadNotifications = await FirebaseFirestore.instance
          .collection('notifications')
          .where('appointmentId', isEqualTo: appointmentId)
          .where('assignedToId', isEqualTo: _conciergeId)
          .where('type', isEqualTo: 'message')
          .where('isRead', isEqualTo: false)
          .get();
      for (var doc in unreadNotifications.docs) {
        await doc.reference.update({'isRead': true});
      }
      setState(() {
        _appointmentUnreadCounts.remove(appointmentId);
        _unreadNotificationsList.removeWhere(
          (notif) => notif['appointmentId'] == appointmentId && notif['type'] == 'message'
        );
        _unreadNotifications = _unreadNotificationsList.length;
      });
    } catch (e) {
      // Optionally log error
    }
  }

  // Send a direct message to the minister (mirrors consultant logic, fixes recipientId param)
  Future<void> _sendDirectMessage({
    required String appointmentId,
    required String message,
    required String recipientId,
    required String recipientRole,
    required String recipientName,
  }) async {
    try {
      final appointmentDoc = await FirebaseFirestore.instance
          .collection('appointments')
          .doc(appointmentId)
          .get();
      if (!appointmentDoc.exists) {
        throw Exception('Appointment not found');
      }
      final appointmentData = appointmentDoc.data()!;
      await FirebaseFirestore.instance.collection('messages').add({
        'appointmentId': appointmentId,
        'message': message,
        'senderId': _conciergeId,
        'senderName': _conciergeName,
        'senderRole': 'concierge',
        'recipientId': recipientId,
        'recipientRole': recipientRole,
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
        'appointmentData': {
          'id': appointmentId,
          'ministerId': recipientId,
          'ministerName': recipientName
        },
      });
      _notificationService.createNotification(
        title: 'New Message',
        body: "Message from $_conciergeName",
        data: {
          'appointmentId': appointmentId,
          'type': 'message',
          'senderId': _conciergeId,
          'senderName': _conciergeName,
          'message': message
        },
        role: recipientRole,
        assignedToId: recipientId,
        notificationType: 'message'
      );
      _notificationService.sendFCMToUser(
        userId: recipientId,
        title: 'Message from $_conciergeName',
        body: message.length > 100 ? '${message.substring(0, 97)}...' : message,
        data: {
          'appointmentId': appointmentId,
          'type': 'message',
          'messageId': appointmentId
        },
        messageType: 'message'
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message sent')),
      );
    } catch (e) {
      print('Error sending message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending message: $e')),
      );
    }
  }

  // Start session logic for concierge
  Future<void> _startSession(String appointmentId) async {
    try {
      final appointmentDoc = await FirebaseFirestore.instance
          .collection('appointments')
          .doc(appointmentId)
          .get();
      if (!appointmentDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Appointment not found')),
        );
        return;
      }
      // Only set the flag to enable consultant start, do not set status!
      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(appointmentId)
          .update({
        'conciergeSessionStarted': true,
        // Optionally, record the time
        'ministerArrivedAt': DateTime.now(),
      });
      // Send notification to consultant and floor manager that minister has arrived
      final appointmentData = appointmentDoc.data()!;
      final consultantId = appointmentData['consultantId'] ?? appointmentData['assignedConsultantId'];
      final floorManagerId = appointmentData['floorManagerId'] ?? appointmentData['assignedFloorManagerId'];
      final notificationService = VipNotificationService();
      if (consultantId != null && consultantId.toString().isNotEmpty) {
        await notificationService.createNotification(
          title: 'Minister Has Arrived',
          body: 'Minister ${appointmentData['ministerName'] ?? ''} has arrived at ${appointmentData['venueName'] ?? ''}. Please prepare for your appointment.',
          data: {
            ...appointmentData,
            'appointmentId': appointmentId,
            'ministerArrivedAt': DateTime.now(),
            'venueName': appointmentData['venueName'] ?? '',
            'ministerName': appointmentData['ministerName'] ?? '',
            'notificationType': 'minister_arrived',
          },
          role: 'consultant',
          assignedToId: consultantId,
          notificationType: 'minister_arrived',
        );
      }
      if (floorManagerId != null && floorManagerId.toString().isNotEmpty) {
        await notificationService.createNotification(
          title: 'Minister Has Arrived',
          body: 'Minister ${appointmentData['ministerName'] ?? ''} has arrived at ${appointmentData['venueName'] ?? ''}.',
          data: {
            ...appointmentData,
            'appointmentId': appointmentId,
            'ministerArrivedAt': DateTime.now(),
            'venueName': appointmentData['venueName'] ?? '',
            'ministerName': appointmentData['ministerName'] ?? '',
            'notificationType': 'minister_arrived',
          },
          role: 'floor_manager',
          assignedToId: floorManagerId,
          notificationType: 'minister_arrived',
        );
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session started (consultant can now start)')),
      );
      _loadAppointments();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting session: $e')),
      );
    }
  }

  // Shows the appointment details dialog for the given appointment
  void _showAppointmentDetailsDialog(Map<String, dynamic> appointment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          'Appointment Details',
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Minister:  ${appointment['ministerName'] ?? 'N/A'}', style: const TextStyle(color: Colors.white)),
            Text('Service: ${appointment['serviceName'] ?? 'N/A'}', style: const TextStyle(color: Colors.white)),
            Text('Time: ${appointment['appointmentTime'] ?? 'N/A'}', style: const TextStyle(color: Colors.white)),
            // Add more fields as needed
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close', style: TextStyle(color: Colors.amber)),
          ),
        ],
      ),
    );
  }

  Future<LatLng?> _getDeviceLocation() async {
    try {
      final gmLatLng = await DeviceLocationService.getCurrentUserLocation(context);
      if (gmLatLng == null) return null;
      return LatLng(gmLatLng.latitude, gmLatLng.longitude);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting device location: $e')),
      );
      return null;
    }
  }

  Future<bool> _verifyLocation() async {
    try {
      final userLocation = await _getDeviceLocation();
      if (userLocation == null) return false;
      final businessLocation = await _getBusinessLocation();
      if (businessLocation == null) return false;
      print('[ATTENDANCE DEBUG] Device Location: lat=${userLocation.latitude}, lng=${userLocation.longitude}');
      print('[ATTENDANCE DEBUG] Business Location: lat=${businessLocation['lat']}, lng=${businessLocation['lng']}');
      final double distanceInMeters = _calculateDistance(
        userLocation.latitude,
        userLocation.longitude,
        businessLocation['lat'],
        businessLocation['lng'],
      );
      final isWithinAllowedDistance = distanceInMeters <= _allowedDistanceInMeters;
      if (!isWithinAllowedDistance) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('You must be within 1km of the workplace to clock in/out.')),
        );
      }
      return isWithinAllowedDistance;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error verifying location: $e')),
      );
      return false;
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // meters
    final double dLat = _deg2rad(lat2 - lat1);
    final double dLon = _deg2rad(lon2 - lon1);
    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) * cos(_deg2rad(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _deg2rad(double deg) {
    return deg * (pi / 180);
  }

  Future<Map<String, dynamic>?> _getBusinessLocation() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('business').doc('settings').get();
      if (!doc.exists) return null;
      final data = doc.data()!;
      return {
        'lat': data['latitude'],
        'lng': data['longitude'],
      };
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching business location: $e')),
      );
      return null;
    }
  }

  // Provide status options for concierge
  List<Map<String, String>> get _statusOptions => [
    {'value': 'pending', 'label': 'Pending'},
    {'value': 'in_progress', 'label': 'In Progress'},
    {'value': 'completed', 'label': 'Completed'},
  ];

  void _endSession(String id) {}
  void _addNotes(String appointmentId) async {
    try {
      // Find the appointment by ID
      final appointment = _appointments.firstWhere(
        (a) => a['id'] == appointmentId,
        orElse: () => {},
      );
      if (appointment.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Appointment not found.')),
        );
        return;
      }
      final currentNotes = appointment['conciergeNotes'] ?? '';
      await _showNotesDialog(appointmentId, currentNotes);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening notes dialog: $e')),
      );
    }
  }
  void _chatWithMinister(Map<String, dynamic> appointment) {}
  void _changeStatus(Map<String, dynamic> appointment, String? val) {}

  Future<void> _sendMinisterArrivedNotification(Map<String, dynamic> appointment) async {
    final consultantId = appointment['consultantId'] ?? appointment['assignedConsultantId'];
    if (consultantId != null && consultantId.toString().isNotEmpty) {
      final notificationService = VipNotificationService();
      await notificationService.notifyAppointmentStart(
        appointmentId: appointment['id'],
        staffId: _conciergeId,
        staffRole: 'concierge',
      );
    }
  }

  // Show dialog to edit/add notes for appointment
  Future<void> _showNotesDialog(String appointmentId, String currentNotes) async {
    final TextEditingController notesController = TextEditingController(text: currentNotes);
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        title: const Text('Session Notes', style: TextStyle(color: AppColors.gold)),
        content: TextField(
          controller: notesController,
          decoration: const InputDecoration(hintText: 'Enter session notes'),
          maxLines: 5,
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.gold)),
          ),
          TextButton(
            onPressed: () async {
              final notes = notesController.text.trim();
              if (notes.isNotEmpty) {
                try {
                  await FirebaseFirestore.instance
                      .collection('appointments')
                      .doc(appointmentId)
                      .update({'conciergeNotes': notes});
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Notes saved successfully')),
                  );
                  _loadAppointments();
                } catch (e) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error saving notes: $e')),
                  );
                }
              } else {
                Navigator.pop(context);
              }
            },
            child: const Text('Save', style: TextStyle(color: AppColors.gold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _buildMainContent(context),
      ],
    );
  }

  Widget _buildMainContent(BuildContext context) {
    Widget body;
    if (_currentIndex == 0) {
      body = _buildDashboardContent();
    } else if (_currentIndex == 1) {
      body = _buildNotificationsView();
    } else {
      body = Center(child: Text('Profile', style: TextStyle(color: Colors.white)));
    }
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Row(
          children: [
            Text(
              'Role: Concierge',
              style: TextStyle(
                color: AppColors.gold,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.gold),
            tooltip: 'Logout',
            onPressed: () async {
              await Provider.of<AppAuthProvider>(context, listen: false).signOut();
              if (context.mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
              }
            },
          ),
        ],
      ),
      body: body,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        backgroundColor: Colors.black,
        selectedItemColor: AppColors.gold,
        unselectedItemColor: Colors.white,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'Notifications',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
