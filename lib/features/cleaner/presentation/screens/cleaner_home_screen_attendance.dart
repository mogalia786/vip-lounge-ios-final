import 'package:flutter/material.dart';
import 'package:vip_lounge/features/shared/utils/app_update_helper.dart';
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
import '../widgets/performance_metrics_widget.dart';
import '../../../../features/floor_manager/widgets/attendance_actions_widget.dart';
import '../../../../core/services/device_location_service.dart';
import '../widgets/cleaner_appointment_widget.dart';
import '../../../../core/widgets/unified_appointment_card.dart'; // Import the new UnifiedAppointmentCard widget

class LatLng {
  final double latitude;
  final double longitude;
  LatLng(this.latitude, this.longitude);
}

class CleanerHomeScreenAttendance extends StatefulWidget {
  const CleanerHomeScreenAttendance({Key? key}) : super(key: key);

  @override
  State<CleanerHomeScreenAttendance> createState() => _CleanerHomeScreenAttendanceState();
}

class _CleanerHomeScreenAttendanceState extends State<CleanerHomeScreenAttendance> {
  String _cleanerId = '';
  String _cleanerName = '';
  DateTime _selectedDate = DateTime.now();
  List<DateTime> get _sevenDayRange {
    final now = DateTime.now();
    return List.generate(7, (i) => DateTime(now.year, now.month, now.day).add(Duration(days: i)));
  }
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

  // --- Start/End Session and Notes Logic ---
  Future<void> _startSession(dynamic appointmentId) async {
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
      final now = DateTime.now();
      await FirebaseFirestore.instance.collection('appointments').doc(appointmentId).update({
        'startTime': Timestamp.fromDate(now),
        'status': 'in-progress',
      });
      await FirebaseFirestore.instance.collection('staff_activities').add({
        'staffId': _cleanerId,
        'activityType': 'session_start',
        'appointmentId': appointmentId,
        'timestamp': now,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session started')),
      );
      _loadAppointments();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting session: $e')),
      );
    }
  }

  Future<void> _endSession(dynamic appointmentId) async {
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
      final now = DateTime.now();
      await FirebaseFirestore.instance.collection('appointments').doc(appointmentId).update({
        'endTime': Timestamp.fromDate(now),
        'status': 'completed',
      });
      await FirebaseFirestore.instance.collection('staff_activities').add({
        'staffId': _cleanerId,
        'activityType': 'session_end',
        'appointmentId': appointmentId,
        'timestamp': now,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session ended')),
      );
      _loadAppointments();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error ending session: $e')),
      );
    }
  }

  Future<void> _submitCleanerNotes(dynamic appointmentId, String notes) async {
    await FirebaseFirestore.instance.collection('appointments').doc(appointmentId).update({
      'cleanerNotes': notes,
    });
    // No status or time changes here.
  }

  // --- Notification Color Coding Helper ---
  Color _notificationColor(String type) {
    switch (type) {
      case 'message':
        return Colors.blue[900]!;
      case 'appointment':
        return Colors.green[900]!;
      case 'alert':
        return Colors.red[900]!;
      default:
        return Colors.grey[800]!;
    }
  }

  // --- Notification Tap Handler ---
  void _handleNotificationTap(Map<String, dynamic> notif) async {
    final type = notif['type'] ?? notif['notificationType'] ?? '';
    final appointmentId = notif['appointmentId'] ?? notif['data']?['appointmentId'] ?? notif['data']?['id'] ?? '';
    // Mark notification as read if possible
    if (notif['id'] != null) {
      await _notificationService.markNotificationAsRead(notif['id']);
    }
    if ((type == 'message') && appointmentId.toString().isNotEmpty) {
      final appointment = _appointments.firstWhere(
        (a) => a['id'] == appointmentId,
        orElse: () => {},
      );
      if (appointment.isNotEmpty && appointment['ministerId'] != null) {
        // TODO: Implement chat dialog for cleaner
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat dialog not yet implemented for cleaner.')),
        );
        return;
      }
    } else if ((type == 'assignment' || type == 'new_appointment' || type == 'booking_assigned' || type == 'minister_arrived' || type == 'status_changed' || type == 'booking_made' || type == 'appointment') && appointmentId.toString().isNotEmpty) {
      final appointment = _appointments.firstWhere(
        (a) => a['id'] == appointmentId,
        orElse: () => {},
      );
      if (appointment.isNotEmpty) {
        // TODO: Implement appointment details dialog for cleaner
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Appointment details dialog not yet implemented for cleaner.')),
        );
        return;
      } else {
        Navigator.of(context).pushNamed('/appointment_details', arguments: {
          'appointmentId': appointmentId,
        });
        return;
      }
    } else if (appointmentId.toString().isNotEmpty) {
      Navigator.of(context).pushNamed('/appointment_details', arguments: {
        'appointmentId': appointmentId,
      });
      return;
    }
    // Fallback: No appointmentId or unable to open
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No details available for this notification')),
    );
  }

  // --- Notifications View ---
  Widget _buildNotificationsView() {
    if (_unreadNotificationsList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.notifications_none, color: Colors.grey, size: 64),
            const SizedBox(height: 16),
            const Text('No new notifications', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: _unreadNotificationsList.length,
      itemBuilder: (context, index) {
        final notif = _unreadNotificationsList[index];
        final type = notif['type'] ?? '';
        final color = _notificationColor(type);
        return Card(
          color: color,
          child: ListTile(
            leading: Icon(Icons.notifications, color: AppColors.primary),
            title: Text(
              notif['title'] ?? 'Notification',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              notif['body'] ?? '',
              style: const TextStyle(color: Colors.white70),
            ),
            onTap: () => _handleNotificationTap(notif),
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    // Silwela in-app update check
    _setCleanerIdAndInit();
  }

  Future<void> _setCleanerIdAndInit() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        setState(() {
          _cleanerId = user.uid;
          _cleanerName = userData != null ? '${userData['firstName']} ${userData['lastName']}' : 'cleaner';
        });
      }
    }
    // Set the UID early so it is available for all subsequent calls
    await Future.delayed(Duration.zero);
    _loadAppointments();
  }

  Future<void> _loadCleanerDetails() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data();
        setState(() {
          _cleanerId = user.uid;
          _cleanerName = userData != null ? '${userData['firstName']} ${userData['lastName']}' : 'cleaner';
        });
      }
    }
  }

  void _setupNotificationListener() {
    if (_cleanerId.isEmpty) return;
    setState(() {
      _unreadNotificationsList = [];
      _unreadNotifications = 0;
    });
    _notificationsSubscription = FirebaseFirestore.instance
        .collection('notifications')
        .where('assignedToId', isEqualTo: _cleanerId)
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
    // Implement if needed for cleaner role
  }

  Future<void> _loadAppointments() async {
    if (_cleanerId.isEmpty) return;
    setState(() {
      _isLoading = true;
    });
    try {
      final startOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      // Query for cleanerId
      final appointmentsQuery1 = await FirebaseFirestore.instance
          .collection('appointments')
          .where('cleanerId', isEqualTo: _cleanerId)
          .where('appointmentTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('appointmentTime', isLessThan: Timestamp.fromDate(endOfDay))
          .get();
      // Query for assignedCleanerId
      final appointmentsQuery2 = await FirebaseFirestore.instance
          .collection('appointments')
          .where('assignedCleanerId', isEqualTo: _cleanerId)
          .where('appointmentTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('appointmentTime', isLessThan: Timestamp.fromDate(endOfDay))
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
      print('DEBUG: Appointments fetched for cleanerId=$_cleanerId, date=${startOfDay.toIso8601String()} count=${appointments.length}');
      for (var appt in appointments) {
        final ts = appt['appointmentTime'];
        if (ts is Timestamp) {
          final dt = ts.toDate();
          print('DEBUG: Appointment id=${appt['id']}, date=${dt.toIso8601String()}');
        }
      }
      setState(() {
        _appointments = appointments;
        _isLoading = false;
      });
    } catch (e) {
      print('DEBUG: Error fetching appointments for cleanerId=$_cleanerId: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildWeeklySchedule() {
    final days = _sevenDayRange;
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
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary),
                ),
                child: Column(
                  children: [
                    Text(
                      DateFormat('E').format(day),
                      style: TextStyle(
                        color: isSelected ? Colors.black : AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('d').format(day),
                      style: TextStyle(
                        color: isSelected ? Colors.black : AppColors.primary,
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

  Widget _buildDashboardContent() {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _buildWeeklySchedule(),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Appointments',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (_appointments.isEmpty)
          const Center(
            child: Text('No appointments scheduled.', style: TextStyle(color: Colors.white)),
          ),
        ...List.generate(_appointments.length, (index) {
          final appt = _appointments[index];
          return UnifiedAppointmentCard(
            role: 'cleaner',
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
        }),
      ],
    );
  }

  Widget _buildAttendanceContainer() {
    return AttendanceActionsWidget(
      userId: _cleanerId,
      name: _cleanerName,
      role: 'cleaner',
    );
  }

  Widget _buildPerformanceTab() {
    final total = _metricsData['totalAppointments'] ?? 0;
    final completed = _metricsData['completedAppointments'] ?? 0;
    final inProgress = _metricsData['inProgressAppointments'] ?? 0;
    final completionRate = _metricsData['completionRate'] ?? 0.0;
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text('Performance Metrics', style: TextStyle(color: AppColors.primary, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 32),
          _buildMetricRow('Total Appointments', total.toString()),
          _buildMetricRow('Completed Appointments', completed.toString()),
          _buildMetricRow('In Progress', inProgress.toString()),
          _buildMetricRow('Completion Rate', '${completionRate.toStringAsFixed(1)}%'),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 16)),
          Text(value, style: TextStyle(color: AppColors.primary, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _changeStatus(Map<String, dynamic> appt, String? status) {}

  Widget _buildMainContent(BuildContext context) {
    Widget body;
    if (_currentIndex == 0) {
      body = _buildDashboardContent();
    } else if (_currentIndex == 1) {
      body = _buildNotificationsView();
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
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Image.asset(
                'assets/Premium.ico',
                width: 24,
                height: 24,
                errorBuilder: (context, error, stackTrace) => 
                    const Icon(Icons.star, color: Colors.amber, size: 24),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Cleaner',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.verified, color: AppColors.primary, size: 22),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.primary),
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
        child: _cleanerId.isNotEmpty
            ? NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) => [
                  SliverToBoxAdapter(child: _buildAttendanceContainer()),
                ],
                body: body,
              )
            : const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.black,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
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
}
