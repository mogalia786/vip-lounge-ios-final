import 'dart:async';
import 'dart:math';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../widgets/sick_leave_dialog.dart';
// import 'package:vip_lounge/core/widgets/standard_weekly_date_scroll.dart'; // (Reverted AI addition)

// Walking man icon usage example
// Place this widget where you want the icon to appear in your UI:
// Image.asset('assets/walking_man.png', width: 32, height: 32)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vip_lounge/core/constants/colors.dart';
import 'package:vip_lounge/core/services/vip_messaging_service.dart';
import 'package:vip_lounge/core/services/vip_notification_service.dart';
import 'package:vip_lounge/core/services/device_location_service.dart';
import 'package:vip_lounge/core/widgets/glass_card.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';
import 'package:vip_lounge/features/floor_manager/widgets/attendance_actions_widget.dart' show AttendanceActionsWidget;
import 'package:provider/provider.dart';
import '../../../../core/providers/app_auth_provider.dart';
import '../../../../core/widgets/unified_appointment_card.dart';
import 'package:vip_lounge/features/consultant/presentation/screens/appointment_detail_screen.dart';
import '../../../../core/widgets/role_notification_list.dart';
// import '../widgets/minister_search_dialog.dart'; // Removed: file not found
import 'package:vip_lounge/core/widgets/notification_bell_badge.dart';
import '../widgets/performance_metrics_widget.dart';

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

class _ConciergeHomeScreenAttendanceState extends State<ConciergeHomeScreenAttendance> with TickerProviderStateMixin {
  void _openChatWithSender(String senderId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        title: Text('Chat with Sender', style: TextStyle(color: AppColors.gold)),
        content: Text('Chat dialog with senderId: ' + senderId, style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close', style: TextStyle(color: AppColors.gold)),
          ),
        ],
      ),
    );
  }

  @override
 Widget build(BuildContext context) {
  return _buildMainContent(context);
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
        return now.subtract(Duration(days: weekDay - 1)); // Monday of this week
      case 'Future':
        return now.add(const Duration(days: 30));
      default:
        return now;
    }
  }

  Map<String, dynamic> _metricsData = {
    'totalAppointments': 0,
    'completedAppointments': 0,
    'inProgressAppointments': 0,
    'completionRate': 0,
  };
  bool _isLoadingMetrics = false;
  Timer? _metricsUpdateTimer;
  Map<String, Map<String, dynamic>> _performanceHistory = {};

  String _conciergeId = '';
  String _conciergeName = '';
  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _appointments = [];
  bool _isLoading = true;
  int _currentIndex = 0;
  int _unreadNotifications = 0;
  List<Map<String, dynamic>> _unreadNotificationsList = [];

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
    _metricsUpdateTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _updatePerformanceMetrics();
    });
  }

  void _updatePerformanceMetrics() {
    // Placeholder: implement actual metrics update logic if needed
    setState(() {
      _isLoadingMetrics = false;
      // _metricsData = ... // fetch or calculate metrics
    });
  }

  Future<void> _loadConciergeDetails() async {
    try {
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
    } catch (e) {
      print('Error loading concierge details: $e');
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

  // Dashboard content builder (fixes missing method error)
  Widget _buildDashboardContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildWeeklySchedule(),
        Expanded(
          child: _isLoading
              ? Center(child: CircularProgressIndicator())
              : ListView.builder(
                  itemCount: _appointments.length,
                  itemBuilder: (context, index) {
                    final appt = _appointments[index];
                    return UnifiedAppointmentCard(
                      role: 'concierge',
                      isConsultant: false,
                      ministerName: appt['ministerName'] ??
  (appt['minister'] != null && appt['minister']['name'] != null ? appt['minister']['name'] : null) ??
  (((appt['ministerFirstName'] ?? '') + ' ' + (appt['ministerLastName'] ?? '')).trim().isNotEmpty
    ? ((appt['ministerFirstName'] ?? '') + ' ' + (appt['ministerLastName'] ?? '')).trim()
    : 'Unknown Minister'),
                      appointmentId: appt['id'] ?? appt['appointmentId'] ?? '',
                      appointmentInfo: appt,
                      date: appt['appointmentTime'] is Timestamp ? (appt['appointmentTime'] as Timestamp).toDate() : null,
                      ministerId: appt['ministerId'] ?? appt['ministerUid'],
                      disableStartSession: false,
                      viewOnly: false,
                    );
                  },
                ),
        ),
      ],
    );
  }

  // --- Notifications Tab (copied from consultant) ---
  Widget _buildNotificationsTab() {
    if (_conciergeId.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    // Use the new uniform notification widget
    return Expanded(
      child: RoleNotificationList(
        userId: _conciergeId,
        userRole: 'concierge',
        showTitle: false,
      ),
    );
  }

  // --- Performance Tab (copied from consultant) ---
  Widget _buildPerformanceTab() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Performance:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _performanceTimeframe,
                  dropdownColor: Colors.black,
                  style: const TextStyle(color: Colors.white),
                  items: const [
                    DropdownMenuItem(value: 'Week', child: Text('Week')),
                    DropdownMenuItem(value: 'Month', child: Text('Month')),
                    DropdownMenuItem(value: 'Year', child: Text('Year')),
                    DropdownMenuItem(value: 'Future', child: Text('Future')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _performanceTimeframe = val;
                      });
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            ConciergePerformanceMetricsWidget(
              conciergeId: _conciergeId,
              selectedDate: _getPerformanceDateForTimeframe(_performanceTimeframe),
              timeframe: _performanceTimeframe,
            ),
          ],
        ),
      ),
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
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.gold : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.gold),
              ),
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

  Future<void> _endSession(String appointmentId) async {
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
      final appointmentData = appointmentDoc.data()!;

      // Fetch user details for enrichment
      Future<Map<String, dynamic>> getUserDetails(String? userId) async {
        if (userId == null || userId.isEmpty) return {};
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
        if (!userDoc.exists) return {};
        final data = userDoc.data() ?? {};
        return {
          'id': userId,
          'firstName': data['firstName'] ?? '',
          'lastName': data['lastName'] ?? '',
          'phone': data['phone'] ?? data['phoneNumber'] ?? '',
          'email': data['email'] ?? '',
        };
      }

      final ministerId = appointmentData['ministerId'] ?? appointmentData['ministerUid'];
      final consultantId = appointmentData['consultantId'] ?? appointmentData['assignedConsultantId'];
      final conciergeId = appointmentData['conciergeId'] ?? appointmentData['assignedConciergeId'];

      final ministerDetails = await getUserDetails(ministerId?.toString());
      final consultantDetails = await getUserDetails(consultantId?.toString());
      final conciergeDetails = await getUserDetails(conciergeId?.toString());

      // Mark appointment as completed
      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(appointmentId)
          .update({
        'status': 'completed',
        'conciergeEndTime': DateTime.now(),
      });

      // Build enriched appointment data for notifications
      Map<String, dynamic> fullDetails = {
        ...appointmentData,
        'appointmentId': appointmentId,
        'minister': ministerDetails,
        'consultant': consultantDetails,
        'concierge': conciergeDetails,
      };

      final venue = appointmentData['venue'] ?? appointmentData['venueName'] ?? 'Venue not specified';

      // Notify consultant
      if (consultantId != null && consultantId.toString().isNotEmpty) {
        await _notificationService.createNotification(
          title: 'Session Ended',
          body: 'Concierge has ended the session at $venue.',
          data: {
            ...fullDetails,
            'notificationType': 'session_ended',
          },
          role: 'consultant',
          assignedToId: consultantId,
          notificationType: 'session_ended',
        );
      }

      // Notify all floor managers
      final floorManagers = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'floor_manager')
          .get();
      for (var doc in floorManagers.docs) {
        await _notificationService.createNotification(
          title: 'Minister Departure',
          body: 'The minister has left the venue ($venue). Please review the appointment details.',
          data: {
            ...fullDetails,
            'notificationType': 'minister_departure',
          },
          role: 'floor_manager',
          assignedToId: doc.id,
          notificationType: 'minister_departure',
        );
      }

      // Send thank you notification to minister
      if (ministerId != null && ministerId.toString().isNotEmpty) {
        await _notificationService.createNotification(
          title: 'Thank You',
          body: 'Thank you for attending your appointment and we look forward to seeing you in the future. Please be safe, from Concierge',
          data: {
            ...fullDetails,
            'notificationType': 'thank_you',
          },
          role: 'minister',
          assignedToId: ministerId,
          notificationType: 'thank_you',
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error ending session: $e')),
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


  Widget _buildMainContent(BuildContext context) {
    Widget body;
    if (_currentIndex == 0) {
      body = _buildDashboardContent();
    } else if (_currentIndex == 1) {
      body = _buildNotificationsTab();
    } else {
      body = _buildPerformanceTab();
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
                fontSize: 20,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.verified, color: AppColors.gold, size: 22),
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
      body: SafeArea(
        child: _conciergeId.isNotEmpty
            ? NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) => [
                  SliverToBoxAdapter(child: _buildAttendanceContainer()),
                ],
                body: body,
              )
            : const Center(child: CircularProgressIndicator(color: AppColors.gold)),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.black,
        selectedItemColor: AppColors.gold,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) async {
          if (index == 3) {
            final user = Provider.of<AppAuthProvider>(context, listen: false).appUser;
            if (user != null) {
              await showDialog(
                context: context,
                builder: (ctx) => SickLeaveDialog(
                  userId: user.uid,
                  userName: user.firstName + ' ' + user.lastName,
                  role: 'concierge',
                ),
              );
            }
          } else {
            setState(() {
              _currentIndex = index;
            });
          }
        },
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Badge(
              isLabelVisible: _unreadNotifications > 0,
              label: Text(
                _unreadNotifications.toString(),
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
              child: const Icon(Icons.notifications),
            ),
            label: 'Notifications',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Performance',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.sick, color: Colors.redAccent),
            label: 'Sick Leave',
          ),
        ],
      ),
    );
  }
}
