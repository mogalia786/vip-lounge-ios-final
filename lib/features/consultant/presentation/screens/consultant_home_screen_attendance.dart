import 'dart:async';
import 'dart:math';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:vip_lounge/features/shared/utils/app_update_helper.dart';
import '../widgets/sick_leave_dialog.dart';
// import 'package:vip_lounge/core/widgets/standard_weekly_date_scroll.dart'; // (Reverted AI addition)

// Walking man icon usage example
// Place this widget where you want the icon to appear in your UI:
// Image.asset('assets/walking_man.png', width: 32, height: 32)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vip_lounge/core/constants/colors.dart';
import 'package:vip_lounge/core/services/vip_messaging_service.dart';
import 'package:vip_lounge/core/services/vip_notification_service.dart';
import 'package:vip_lounge/core/services/device_location_service.dart';
import 'package:vip_lounge/core/widgets/glass_card.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';
import 'package:vip_lounge/features/floor_manager/widgets/attendance_actions_widget.dart'
    show AttendanceActionsWidget;
import 'package:provider/provider.dart';
import '../../../../core/providers/app_auth_provider.dart';
import '../../../../core/widgets/unified_appointment_card.dart';
import 'package:vip_lounge/features/consultant/presentation/screens/appointment_detail_screen.dart';
import '../../../../core/widgets/role_notification_list.dart';
import '../widgets/minister_search_dialog.dart';
import 'package:vip_lounge/core/widgets/notification_bell_badge.dart';
import '../widgets/performance_metrics_widget.dart';

class LatLng {
  final double latitude;
  final double longitude;
  LatLng(this.latitude, this.longitude);
}

class ConsultantHomeScreenAttendance extends StatefulWidget {
  const ConsultantHomeScreenAttendance({Key? key}) : super(key: key);

  @override
  _ConsultantHomeScreenAttendanceState createState() =>
      _ConsultantHomeScreenAttendanceState();
}

class _ConsultantHomeScreenAttendanceState extends State<ConsultantHomeScreenAttendance>
    with TickerProviderStateMixin {
  // --- Performance Metrics Dropdown State ---
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

  final VipMessagingService _messagingService = VipMessagingService();
  final VipNotificationService _notificationService = VipNotificationService();

  String _consultantId = '';
  String _consultantName = '';
  bool _initialized = false;

  List<Map<String, dynamic>> _appointments = [];
  List<Map<String, dynamic>> _unreadNotificationsList = [];
  DateTime _selectedDate = DateTime.now();
  List<DateTime> get _sevenDayRange {
    final now = DateTime.now();
    return List.generate(7, (i) => DateTime(now.year, now.month, now.day).add(Duration(days: i)));
  }
  bool _isLoading = true;
  bool _isLoadingMetrics = false;
  int _currentIndex = 0;
  int _unreadNotifications = 0;
  Map<String, int> _appointmentUnreadCounts = {};
  Map<String, dynamic> _metricsData = {};
  Map<String, Map<String, dynamic>> _performanceHistory = {};
  bool _isCurrentDay = true;
  double _workplaceLatitude = -29.835930939846083;
  double _workplaceLongitude = 31.021569504380226;
  double _allowedDistanceInMeters = 1000.0;
  double _currentLatitude = 0.0;
  double _currentLongitude = 0.0;
  String _workplaceAddress = "VIP Lounge, King Shaka International Airport";
  StreamSubscription<List<Map<String, dynamic>>>? _notificationsSubscription;
  bool _isClockedIn = false;
  int _activeWorkMinutes = 0;
  DateTime? _clockInTime;

  // Map to track which appointment IDs have minister_arrived notification received
  final Map<String, bool> _ministerArrivedForAppointment = {};

  // Dropdown state for appointment selection
  String? _selectedAppointmentId;

  // --- CLOCK-IN STATE PERSISTENCE (MATCH CONCIERGE) ---
  Future<void> _clockIn() async {
    print('[DEBUG] _clockIn() called. _consultantId=$_consultantId, _isClockedIn=$_isClockedIn');
    if (_consultantId.isEmpty) return;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (_isClockedIn) {
      print('[DEBUG] Already clocked in. Skipping clock-in.');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You are already clocked in')),
      );
      return;
    }
    // Remove any time-of-day restriction for clock-in
    // Only block if already clocked in and out for today
    final clockInQuery = await FirebaseFirestore.instance
        .collection('staff_activities')
        .where('staffId', isEqualTo: _consultantId)
        .where('activityType', isEqualTo: 'clock_in')
        .where('date', isEqualTo: Timestamp.fromDate(today))
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();
    final clockOutQuery = await FirebaseFirestore.instance
        .collection('staff_activities')
        .where('staffId', isEqualTo: _consultantId)
        .where('activityType', isEqualTo: 'clock_out')
        .where('date', isEqualTo: Timestamp.fromDate(today))
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();
    final clockInDoc = clockInQuery.docs.isNotEmpty ? clockInQuery.docs.first : null;
    final clockOutDoc = clockOutQuery.docs.isNotEmpty ? clockOutQuery.docs.first : null;
    if (clockInDoc != null && clockOutDoc != null) {
      final clockInTime = (clockInDoc['timestamp'] as Timestamp).toDate();
      final clockOutTime = (clockOutDoc['timestamp'] as Timestamp).toDate();
      if (clockOutTime.isAfter(clockInTime)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You have already clocked in and out for today.')),
        );
        return;
      }
    }
    try {
      await FirebaseFirestore.instance.collection('staff_activities').add({
        'staffId': _consultantId,
        'staffName': _consultantName,
        'activityType': 'clock_in',
        'timestamp': Timestamp.fromDate(now),
        'date': Timestamp.fromDate(today),
      });
      // --- Ensure AttendanceActionsWidget sees clock-in ---
      await FirebaseFirestore.instance.collection('attendance').doc(_consultantId).set({
        'isClockedIn': true,
        'isOnBreak': false,
        'clockInTime': Timestamp.fromDate(now),
        'clockOutTime': null,
      }, SetOptions(merge: true));
      setState(() {
        _isClockedIn = true;
        _clockInTime = now;
      });
      // --- Refresh attendance status after clock-in ---
      await _checkClockInStatus();
      print('[DEBUG] Clocked in successfully at $now');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Clocked in at ${DateFormat('h:mm a').format(now)}')),
      );
    } catch (e) {
      print('[ERROR] Error clocking in: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error clocking in: $e')),
      );
    }
  }

  Future<void> _clockOut() async {
    print('[DEBUG] _clockOut() called. _consultantId=$_consultantId, _isClockedIn=$_isClockedIn');
    if (_consultantId.isEmpty) return;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    try {
      await FirebaseFirestore.instance.collection('staff_activities').add({
        'staffId': _consultantId,
        'staffName': _consultantName,
        'activityType': 'clock_out',
        'timestamp': Timestamp.fromDate(now),
        'date': Timestamp.fromDate(today),
      });
      // --- Ensure AttendanceActionsWidget sees clock-out ---
      await FirebaseFirestore.instance.collection('attendance').doc(_consultantId).set({
        'isClockedIn': false,
        'isOnBreak': false,
        'clockOutTime': Timestamp.fromDate(now),
      }, SetOptions(merge: true));
      setState(() {
        _isClockedIn = false;
        _clockInTime = null;
      });
      // --- Refresh attendance status after clock-out ---
      await _checkClockInStatus();
      print('[DEBUG] Clocked out successfully at $now');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Clocked out at ${DateFormat('h:mm a').format(now)}')),
      );
    } catch (e) {
      print('[ERROR] Error clocking out: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error clocking out: $e')),
      );
    }
  }

  // --- CLOCK-IN STATUS CHECK (MATCH CONCIERGE) ---
  Future<void> _checkClockInStatus() async {
    if (_consultantId.isEmpty) return;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Query Firestore for today's clock-in
    final clockInQuery = await FirebaseFirestore.instance
        .collection('staff_activities')
        .where('staffId', isEqualTo: _consultantId)
        .where('activityType', isEqualTo: 'clock_in')
        .where('date', isEqualTo: Timestamp.fromDate(today))
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();
    final clockInDoc = clockInQuery.docs.isNotEmpty ? clockInQuery.docs.first : null;
    // Query Firestore for today's clock-out
    final clockOutQuery = await FirebaseFirestore.instance
        .collection('staff_activities')
        .where('staffId', isEqualTo: _consultantId)
        .where('activityType', isEqualTo: 'clock_out')
        .where('date', isEqualTo: Timestamp.fromDate(today))
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();
    final clockOutDoc = clockOutQuery.docs.isNotEmpty ? clockOutQuery.docs.first : null;
    bool isClockedIn = false;
    DateTime? clockInTime;
    if (clockInDoc != null) {
      final clockInTimeVal = (clockInDoc['timestamp'] as Timestamp).toDate();
      if (clockOutDoc == null) {
        isClockedIn = true;
        clockInTime = clockInTimeVal;
      } else {
        final clockOutTimeVal = (clockOutDoc['timestamp'] as Timestamp).toDate();
        if (clockInTimeVal.isAfter(clockOutTimeVal)) {
          isClockedIn = true;
          clockInTime = clockInTimeVal;
        }
      }
    }
    setState(() {
      _isClockedIn = isClockedIn;
      _clockInTime = clockInTime;
    });
  }

  @override
  void initState() {
    super.initState();

    _initializeWithFirebase();
    _setupNotificationListener();
    _loadConsultantDetails();
  }

  Future<void> _loadConsultantDetails() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        setState(() {
          _consultantId = user.uid;
          _consultantName = userData != null ? '${userData['firstName']} ${userData['lastName']}' : 'consultant';
        });
      }
    }
    await Future.delayed(Duration.zero);
    _checkClockInStatus();
    _loadAppointmentsForDate(_selectedDate);
    _setupNotificationListener();
    _fetchNotificationsOnce();
    _initializePushNotificationDebug();
  }

  void _setupNotificationListener() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    _notificationsSubscription?.cancel();
    _notificationsSubscription = _notificationService
        .getConsultantNotificationsStream(currentUser.uid)
        .listen((notificationsList) {
      final unreadNotifications = notificationsList.where((n) => n['isRead'] != true).toList();
      // Track minister_arrived notifications
      for (final notif in notificationsList) {
        if ((notif['type'] == 'minister_arrived' || notif['notificationType'] == 'minister_arrived') && notif['appointmentId'] != null) {
          _ministerArrivedForAppointment[notif['appointmentId']] = true;
        }
      }
      setState(() {
        _unreadNotificationsList = notificationsList;
        _unreadNotifications = unreadNotifications.length;
      });
    }, onError: (error) {
      setState(() {
        _unreadNotificationsList = [];
        _unreadNotifications = 0;
      });
    });
  }

  @override
  void dispose() {
    _notificationsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeWithFirebase() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();
        if (userDoc.exists) {
          final userData = userDoc.data();
          if (userData != null) {
            setState(() {
              _consultantId = currentUser.uid;
              _consultantName = '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}';
              _initialized = true;
            });
          }
        }
      }
    } catch (e) {
      print('Error initializing with Firebase: $e');
    }
  }

  void _checkIfCurrentDay() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    _isCurrentDay = today.isAtSameMomentAs(selectedDay);
  }

  void _initializeLocationServices() async {
    // Removed location services initialization
  }

  void _loadWorkplaceCoordinates() async {
    // Removed workplace coordinates loading
  }

  void _loadPerformanceHistory() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('performance_metrics')
          .where('staffId', isEqualTo: _consultantId)
          .orderBy('date', descending: true)
          .limit(30)
          .get();
      final Map<String, Map<String, dynamic>> history = {};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final dateStr = data['dateStr'] as String?;
        if (dateStr != null) {
          history[dateStr] = data;
        }
      }
      setState(() {
        _performanceHistory = history;
      });
    } catch (e) {
      print('Error loading performance history: $e');
    }
  }

  void _updateActiveWorkTime() async {
    // Removed active work time updating
  }

  Future<void> _updatePerformanceMetrics() async {
    try {
      setState(() {
        _isLoadingMetrics = true;
      });
      final targetDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      final appointmentsQuery = await FirebaseFirestore.instance
          .collection('appointments')
          .where('consultantId', isEqualTo: _consultantId)
          .where('appointmentTime', isGreaterThanOrEqualTo: Timestamp.fromDate(targetDate))
          .where('appointmentTime', isLessThan: Timestamp.fromDate(targetDate.add(const Duration(days: 1))))
          .get();
      final appointments = appointmentsQuery.docs.map((doc) => doc.data()).toList();
      final staffActivitiesQuery = await FirebaseFirestore.instance
          .collection('staff_activities')
          .where('staffId', isEqualTo: _consultantId)
          .where('date', isEqualTo: Timestamp.fromDate(targetDate))
          .get();
      final staffActivities = staffActivitiesQuery.docs.map((doc) => doc.data()).toList();
      final totalAppointments = appointments.length;
      final completedAppointments = appointments.where((appointment) => appointment['status'] == 'completed').length;
      int totalMinutesWorked = 0;
      int breakMinutes = 0;
      staffActivities.sort((a, b) {
        final aTime = a['timestamp'] as Timestamp;
        final bTime = b['timestamp'] as Timestamp;
        return aTime.compareTo(bTime);
      });
      final breakActivities = staffActivities.where((activity) => activity['activityType'] == 'break_start' || activity['activityType'] == 'break_end').toList();
      for (int i = 0; i < breakActivities.length - 1; i++) {
        final current = breakActivities[i];
        final next = breakActivities[i + 1];
        if (current['activityType'] == 'break_start' && next['activityType'] == 'break_end') {
          final startTime = (current['timestamp'] as Timestamp).toDate();
          final endTime = (next['timestamp'] as Timestamp).toDate();
          final duration = endTime.difference(startTime).inMinutes;
          breakMinutes += duration;
        }
      }
      final clockActivities = staffActivities.where((activity) => activity['activityType'] == 'clock_in' || activity['activityType'] == 'clock_out').toList();
      for (int i = 0; i < clockActivities.length - 1; i++) {
        final current = clockActivities[i];
        final next = clockActivities[i + 1];
        if (current['activityType'] == 'clock_in' && next['activityType'] == 'clock_out') {
          final startTime = (current['timestamp'] as Timestamp).toDate();
          final endTime = (next['timestamp'] as Timestamp).toDate();
          final duration = endTime.difference(startTime).inMinutes;
          totalMinutesWorked += duration;
        }
      }
      if (clockActivities.isNotEmpty && clockActivities.last['activityType'] == 'clock_in' && targetDate.isAtSameMomentAs(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day))) {
        final lastClockIn = (clockActivities.last['timestamp'] as Timestamp).toDate();
        final now = DateTime.now();
        final duration = now.difference(lastClockIn).inMinutes;
        totalMinutesWorked += duration;
      }
      setState(() {
        _metricsData = {
          'appointmentsTotal': totalAppointments,
          'appointmentsCompleted': completedAppointments,
          'minutesWorked': totalMinutesWorked,
          'breakMinutes': breakMinutes,
          'activeMinutes': totalMinutesWorked - breakMinutes,
          'completionRate': totalAppointments > 0 ? ((completedAppointments / totalAppointments) * 100).toStringAsFixed(1) : '0',
          'isCurrentDay': targetDate.isAtSameMomentAs(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)),
        };
        _isLoadingMetrics = false;
      });
    } catch (e) {
      print('Error updating performance metrics: $e');
      setState(() {
        _isLoadingMetrics = false;
      });
    }
  }

  List<Map<String, dynamic>> _getLast7DaysData() {
    final List<Map<String, dynamic>> result = [];
    final now = DateTime.now();
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final dayLabel = DateFormat('E').format(date);
      final dayData = _performanceHistory[dateStr];
      result.add({
        'date': dateStr,
        'dayLabel': dayLabel,
        'totalAppointments': dayData?['totalAppointments'] ?? 0,
        'completedAppointments': dayData?['completedAppointments'] ?? 0,
        'hoursWorked': dayData?['hoursWorked'] ?? '0.0'
      });
    }
    return result;
  }

  Future<void> _loadAppointmentsForDate(DateTime date) async {
  print('[DEBUG] _loadAppointmentsForDate called for date: ' + date.toString());
    if (_consultantId.isEmpty) return;
    setState(() {
      _isLoading = true;
    });
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      // Query for consultantId
      final query1 = await FirebaseFirestore.instance
          .collection('appointments')
          .where('consultantId', isEqualTo: _consultantId)
          .where('appointmentTime', isGreaterThanOrEqualTo: startOfDay)
          .where('appointmentTime', isLessThan: endOfDay)
          .get();
      // Query for assignedConsultantId
      final query2 = await FirebaseFirestore.instance
          .collection('appointments')
          .where('assignedConsultantId', isEqualTo: _consultantId)
          .where('appointmentTime', isGreaterThanOrEqualTo: startOfDay)
          .where('appointmentTime', isLessThan: endOfDay)
          .get();
      final Set<String> seenIds = {};
      final appointments = <Map<String, dynamic>>[];
      for (var doc in [...query1.docs, ...query2.docs]) {
        if (seenIds.contains(doc.id)) continue;
        seenIds.add(doc.id);
        final data = doc.data();
        appointments.add({
          ...Map<String, dynamic>.from(data as Map),
          'id': doc.id,
          'docId': doc.id,
        });
      }
      print('[DEBUG] Appointments loaded: count = [33m${appointments.length}[0m');
    for (final appt in appointments) {
      print('[DEBUG] Appointment loaded: id=${appt['id']} status=${appt['status']} consultantSessionStarted=${appt['consultantSessionStarted']} consultantSessionEnded=${appt['consultantSessionEnded']}');
    }
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

  Future<void> _loadClockInStatus() async {
    try {
      if (_consultantId.isEmpty) return;
      final doc = await FirebaseFirestore.instance.collection('attendance').doc(_consultantId).get();
      if (!doc.exists) {
        setState(() {
          _isClockedIn = false;
        });
        return;
      }
      final data = doc.data();
      setState(() {
        _isClockedIn = data != null && data['isClockedIn'] == true;
      });
    } catch (e) {
      setState(() {
        _isClockedIn = false;
      });
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

  // --- NOTIFICATION DEBUG PRINTS ---
  void _initializePushNotificationDebug() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('[Debug] FCM notification with message ${message.notification?.body ?? message.data} OK');
    });
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('[Debug] FCM notification (opened app) with message ${message.notification?.body ?? message.data} OK');
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initializePushNotificationDebug();
  }

  Future<void> _fetchNotificationsOnce() async {
    // This is a placeholder to avoid errors. Add notification fetching logic if needed.
    return;
  }

  void _onDateSelected(DateTime day) {
    setState(() {
      _selectedDate = day;
    });
    _loadAppointmentsForDate(day);
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
                  _loadAppointmentsForDate(day);
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
  print('[DEBUG] _buildDashboardContent: _appointments.length = [32m${_appointments.length}[0m');
  for (final appt in _appointments) {
    print('[DEBUG] Rendering card for appointmentId=${appt['id']} status=${appt['status']} consultantSessionStarted=${appt['consultantSessionStarted']} consultantSessionEnded=${appt['consultantSessionEnded']}');
  }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _appointments.length,
          itemBuilder: (context, index) {
            final appt = Map<String, dynamic>.from(_appointments[index]);
            // DEBUG: Log the appointment ID and status for troubleshooting
            print('[DEBUG] UnifiedAppointmentCard: appt index=$index, id=' + (appt['id']?.toString() ?? 'NULL') + ', status=' + (appt['status']?.toString() ?? 'NULL'));
            // Only enable Start Session if status is 'minister_arrived'
            final bool enableStart = appt['status'] == 'minister_arrived';
            return UnifiedAppointmentCard(
              role: 'consultant',
              isConsultant: true,
              ministerName: appt['ministerName'] ?? '',
              appointmentId: appt['id'] ?? '',
              appointmentInfo: appt,
              // Always pass the correct appointment date if available
              date: appt['appointmentTime'] is DateTime
                  ? appt['appointmentTime']
                  : (appt['appointmentTime'] is Timestamp)
                      ? (appt['appointmentTime'] as Timestamp).toDate()
                      : null,
              time: null,
              ministerId: appt['ministerId'],
              disableStartSession: !_shouldEnableStartSession(appt),
            );
          },
        ),
      ],
    );
  }

  Widget _buildNotificationsTab() {
    if (_consultantId.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    // Use the new uniform notification widget
    return Expanded(
      child: RoleNotificationList(
        userId: _consultantId,
        userRole: 'consultant',
        showTitle: false,
      ),
    );
  }

  String _notificationTitleForType(String type, Map<String, dynamic> data) {
    switch (type) {
      case 'message':
        return 'New Message';
      case 'assignment':
      case 'booking_assigned':
        return 'Booking Assigned';
      case 'new_appointment':
        return 'New Appointment';
      case 'minister_arrived':
        return 'Minister Arrived';
      case 'minister_left':
        return 'Minister Left';
      case 'status_changed':
        return 'Status Changed';
      case 'booking_made':
        return 'Booking Made';
      default:
        return type.isNotEmpty ? type.replaceAll('_', ' ').toUpperCase() : 'Notification';
    }
  }

  String _notificationBodyForType(String type, Map<String, dynamic> data) {
    switch (type) {
      case 'message':
        return data['body'] ?? data['message'] ?? 'You have received a new message.';
      case 'assignment':
      case 'booking_assigned':
        return 'You have been assigned to a booking.';
      case 'new_appointment':
        return 'A new appointment has been created.';
      case 'minister_arrived':
        return 'The minister has arrived.';
      case 'minister_left':
        return 'The minister has left.';
      case 'status_changed':
        return 'The appointment status has changed.';
      case 'booking_made':
        return 'A new booking has been made.';
      default:
        return data['body'] ?? '';
    }
  }

  List<Map<String, String>> get _statusOptions => [
    {'value': 'pending', 'label': 'Pending'},
    {'value': 'in-progress', 'label': 'In Progress'},
    {'value': 'completed', 'label': 'Completed'},
    {'value': 'cancelled', 'label': 'Cancelled'},
    {'value': 'did_not_attend', 'label': 'Did Not Attend'},
  ];

  void _changeStatus(BuildContext context, Map<String, dynamic> appointment, String? status) async {
    final docId = (appointment['docId'] ?? appointment['id'])?.toString() ?? '';
    if (docId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Appointment ID missing, cannot update status.')),
      );
      return;
    }
    if (status == null) return;

    // --- FIX floorManagerId: fallback to lookup if missing ---
    String floorManagerId = appointment['floorManagerId']?.toString() ?? '';
    final ministerId = appointment['ministerId']?.toString() ?? '';
    print('[DEBUG] changeStatus: docId=$docId, floorManagerId=$floorManagerId, ministerId=$ministerId');

    // If floorManagerId is missing, try to fetch it from Firestore
    if (floorManagerId.isEmpty) {
      try {
        final doc = await FirebaseFirestore.instance.collection('appointments').doc(docId).get();
        if (doc.exists) {
          final data = doc.data();
          if (data != null && data['floorManagerId'] != null && data['floorManagerId'].toString().isNotEmpty) {
            floorManagerId = data['floorManagerId'].toString();
            print('[DEBUG] Looked up floorManagerId from Firestore: $floorManagerId');
          }
        }
      } catch (e) {
        print('[ERROR] Unable to lookup floorManagerId: $e');
      }
    }

    try {
      await FirebaseFirestore.instance.collection('appointments').doc(docId).update({'status': status});
      setState(() {
        appointment['status'] = status;
      });
      final notificationData = {
        'appointmentId': docId,
        'notificationType': 'Status Changed',
        'timestamp': Timestamp.now(),
        'status': status,
        'ministerId': ministerId,
      };

      // Send to ALL active floor managers (role: floor_manager, isActive: true) WITH FCM PUSH
      final floorManagersQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'floor_manager')
          .where('isActive', isEqualTo: true)
          .get();

      if (floorManagersQuery.docs.isNotEmpty) {
        for (var doc in floorManagersQuery.docs) {
          final fmId = doc.id;
          // Send FCM push notification if token exists
          await _notificationService.sendFCMToUser(
            userId: fmId,
            title: 'Consultant Updated Status',
            body: 'Consultant updated appointment status to "$status"',
            data: _notificationService.convertToStringMap(notificationData),
            messageType: 'Status Changed',
          );
          // Also create in-app notification
          await _notificationService.createNotification(
            title: 'Consultant Updated Status',
            body: 'Consultant updated appointment status to "$status"',
            data: notificationData,
            role: 'floor_manager',
            assignedToId: fmId,
            notificationType: 'Status Changed',
          );
        }
      } else {
        print('[WARN] No active floor managers found, skipping notification.');
      }

      if (ministerId.isNotEmpty) {
        await _notificationService.createNotification(
          title: 'Appointment Status Changed',
          body: 'Your appointment status is now "$status". Please rate your experience.',
          data: {
            ...appointment,
            'appointmentId': docId,
            'status': status,
            'notificationType': status == 'completed' ? 'appointment_completed' : 'status_changed',
            'showRating': status == 'completed',
          },
          role: 'minister',
          assignedToId: ministerId,
          notificationType: status == 'completed' ? 'appointment_completed' : 'status_changed',
        );
      } else {
        print('[WARN] Minister ID missing, skipping notification.');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status updated and notifications sent.')),
      );
    } catch (e, stack) {
      print('[ERROR] Status update failed: $e\n$stack');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating status: $e')),
      );
    }
  }

  Future<bool> _appointmentExists(String id) async {
    final doc = await FirebaseFirestore.instance.collection('appointments').doc(id).get();
    return doc.exists;
  }

  void _showNotesDialog(Map<String, dynamic> appt) {
    final notesController = TextEditingController(text: appt['consultantNotes'] ?? '');
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.black,
          title: const Text('Session Notes', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: notesController,
            maxLines: 5,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(hintText: 'Enter notes...', hintStyle: TextStyle(color: Colors.white54)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white)),
            ),
            TextButton(
              onPressed: () async {
                final notes = notesController.text.trim();
                if (appt['id'] != null && notes.isNotEmpty) {
                  await FirebaseFirestore.instance.collection('appointments').doc(appt['id']).update({'consultantNotes': notes});
                  setState(() {
                    appt['consultantNotes'] = notes;
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Notes saved.')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Error: Appointment ID missing or notes empty.')),
                  );
                }
              },
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _addNotes(String appointmentId) {
    final appt = _appointments.firstWhere((a) => a['id'] == appointmentId, orElse: () => {});
    if (appt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appointment not found.')),
      );
      return;
    }
    final notesController = TextEditingController(text: (appt['consultantNotes'] ?? '').toString());
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.black,
          title: const Text('Session Notes', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: notesController,
            maxLines: 5,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(hintText: 'Enter notes...', hintStyle: TextStyle(color: Colors.white54)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white)),
            ),
            TextButton(
              onPressed: () async {
                final notes = notesController.text.trim();
                if (appointmentId.isNotEmpty && notes.isNotEmpty) {
                  await FirebaseFirestore.instance.collection('appointments').doc(appointmentId).update({'consultantNotes': notes});
                  setState(() {
                    appt['consultantNotes'] = notes;
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Notes saved.')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Error: Appointment ID missing or notes empty.')),
                  );
                }
              },
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  bool _shouldEnableStartSession(Map<String, dynamic> appt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime apptTime;
    final raw = appt['appointmentTime'];
    if (raw is Timestamp) {
      apptTime = raw.toDate();
    } else if (raw is DateTime) {
      apptTime = raw;
    } else if (raw is String) {
      apptTime = DateTime.tryParse(raw) ?? now;
    } else {
      apptTime = now;
    }
    final bool isFuture = apptTime.isAfter(today);
    final bool consultantStarted = appt['consultantSessionStarted'] == true;
    final bool consultantEnded = appt['consultantSessionEnded'] == true;
    if (isFuture) {
      // Allow consultant to start future appointments regardless of concierge
      return !consultantStarted && !consultantEnded;
    }
    // Original logic for today/past
    bool isLegacy = apptTime.isBefore(today);
    final bool conciergeStarted = appt['conciergeSessionStarted'] == true;
    final bool conciergeMissing = !appt.containsKey('conciergeSessionStarted');
    return ((conciergeStarted || (conciergeMissing && isLegacy)) && !consultantStarted && !consultantEnded);
  }

  void _chatWithMinister(Map<String, dynamic> appointment) async {
    // Use docId if available, else fallback to id
    final appointmentId = appointment['docId'] ?? appointment['id'];
    final ministerId = appointment['ministerId'];
    if (appointmentId == null || appointmentId.toString().isEmpty || ministerId == null || ministerId.toString().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appointment or minister info missing for chat.')),
      );
      return;
    }
    final ministerName = appointment['ministerName'] ?? 'Minister';
    final consultantId = _consultantId;
    final consultantName = _consultantName;
    final consultantRole = 'consultant';
    final TextEditingController messageController = TextEditingController();
    final parentContext = context; // Capture context before await
    await showDialog(
      context: parentContext,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            title: Text(
              'Chat with Minister $ministerName',
              style: const TextStyle(color: Colors.amber),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('appointments')
                      .doc(appointmentId)
                      .collection('messages')
                      .orderBy('timestamp', descending: false)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Text('No messages yet.', style: TextStyle(color: Colors.white70)),
                      );
                    }
                    final messages = snapshot.data!.docs;
                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index].data() as Map<String, dynamic>;
                        final senderRole = msg['senderRole'] ?? '';
                        final senderName = msg['senderName'] ?? '';
                        final messageText = msg['message'] ?? '';
                        final timestamp = msg['timestamp'] as Timestamp?;
                        final isSentByMe = msg['senderId'] == consultantId;
                        return Align(
                          alignment: isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSentByMe ? Colors.amber[700] : Colors.grey[800],
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isSentByMe ? 'You ($consultantRole)' : '$senderName ($senderRole)',
                                  style: TextStyle(
                                    color: isSentByMe ? Colors.black : Colors.amber,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  messageText,
                                  style: const TextStyle(color: Colors.white, fontSize: 15),
                                ),
                                if (timestamp != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Text(
                                      DateFormat('MMM d, h:mm a').format(timestamp.toDate()),
                                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: messageController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          hintStyle: const TextStyle(color: Colors.grey),
                          filled: true,
                          fillColor: Colors.grey[900],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.send, color: Colors.amber),
                      onPressed: () async {
                        final text = messageController.text.trim();
                        if (text.isEmpty) return;
                        messageController.clear();
                        // Send message using VipMessagingService
                        await _messagingService.sendMessage(
                          appointmentId: appointmentId,
                          senderId: consultantId,
                          senderName: consultantName,
                          senderRole: consultantRole,
                          message: text,
                        );
                        // Send notification using VipNotificationService
                        await _notificationService.sendMessageNotification(
                          senderId: consultantId,
                          senderName: consultantName,
                          senderRole: consultantRole,
                          recipientId: ministerId,
                          recipientRole: 'minister',
                          message: text,
                          appointmentId: appointmentId,
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
  }

  void _endSession(Map<String, dynamic> appointment) async {
    try {
      await FirebaseFirestore.instance.collection('appointments').doc(appointment['id']).update({'status': 'completed', 'consultantEndTime': DateTime.now(), 'consultantSessionEnded': true});
      setState(() {
        appointment['status'] = 'completed';
        appointment['consultantSessionEnded'] = true;
      });
      // Send thank you notification to minister with consultant name and contact details and status, and trigger rating dialog
      final ministerId = appointment['ministerId'] ?? appointment['ministerUid'];
      final consultantId = appointment['consultantId'] ?? appointment['assignedConsultantId'];
      final conciergeId = appointment['conciergeId'] ?? appointment['assignedConciergeId'];
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
      final ministerDetails = await getUserDetails(ministerId?.toString());
      final consultantDetails = await getUserDetails(consultantId?.toString());
      final conciergeDetails = await getUserDetails(conciergeId?.toString());
      final consultantName = consultantDetails['firstName'] != null && consultantDetails['lastName'] != null
          ? (consultantDetails['firstName'] + ' ' + consultantDetails['lastName']).trim()
          : (appointment['consultantName'] ?? 'Consultant');
      final consultantPhone = consultantDetails['phone'] ?? appointment['consultantPhone'] ?? '';
      final consultantEmail = consultantDetails['email'] ?? appointment['consultantEmail'] ?? '';
      final appointmentTime = appointment['appointmentTime'] is DateTime
          ? appointment['appointmentTime']
          : (appointment['appointmentTime'] is Timestamp)
              ? (appointment['appointmentTime'] as Timestamp).toDate()
              : appointment['appointmentTime'];
      final formattedTime = appointmentTime is DateTime
          ? DateFormat('yyyy-MM-dd HH:mm').format(appointmentTime)
          : appointmentTime?.toString() ?? '';
      Map<String, dynamic> fullDetails = {
        ...appointment,
        'appointmentId': appointment['id'],
        'appointmentTimeFormatted': formattedTime,
        'minister': ministerDetails,
        'consultant': consultantDetails,
        'concierge': conciergeDetails,
      };
      if (ministerId != null && ministerId.toString().isNotEmpty) {
        await VipNotificationService().createNotification(
          title: 'Thank You',
          body: 'Thank you, VIP, for visiting the VIP Lounge.\n\nAppointment Status: ${appointment['status']}.\n\nWe hope you had a pleasant experience.\n\nPlease rate your experience using the link below.\n\nIf you have questions, contact your consultant at $consultantPhone or $consultantEmail.',
          data: {
            ...fullDetails,
            'notificationType': 'appointment_completed',
            'status': appointment['status'],
            'showRating': true,
          },
          role: 'minister',
          assignedToId: ministerId,
          notificationType: 'appointment_completed',
        );
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session ended and marked as completed.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to end session: $e')),
      );
    }
  }

  void _openAppointmentDetails(Map<String, dynamic> appt) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AppointmentDetailScreen(appointment: appt),
      ),
    );
  }

  void _openChatDialogFromNotification(Map<String, dynamic> notification) async {
    final appointmentId = notification['appointmentId'] ?? notification['data']?['appointmentId'] ?? notification['data']?['id'];
    if (appointmentId == null || appointmentId.toString().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No appointment ID found for this chat notification.')),
      );
      return;
    }
    // Find the appointment in the loaded appointments list
    final appointment = _appointments.firstWhere(
      (a) => (a['id']?.toString() ?? '') == appointmentId.toString(),
      orElse: () => {},
    );
    if (appointment.isEmpty) {
      // If not found, attempt to fetch directly from Firestore
      try {
        final apptDoc = await FirebaseFirestore.instance.collection('appointments').doc(appointmentId.toString()).get();
        if (apptDoc.exists) {
          // Optionally add to _appointments if needed
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No appointment details found for this chat notification.')),
          );
          return;
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error fetching appointment details.')),
        );
        return;
      }
    }
    final consultantId = _consultantId;
    final consultantName = _consultantName;
    Navigator.of(context).pushNamed(
      '/consultant/chat',
      arguments: {
        'appointmentId': appointmentId,
        'consultantId': consultantId,
        'consultantName': consultantName,
        'consultantRole': 'consultant',
      },
    );
  }

  void _handleNotificationTap(Map<String, dynamic> notification) async {
    final type = notification['notificationType'] ?? notification['type'] ?? '';
    final appointmentId = notification['appointmentId'] ?? notification['data']?['appointmentId'] ?? notification['data']?['id'] ?? '';
    if (notification['id'] != null) {
      await _notificationService.markNotificationAsRead(notification['id']);
    }
    if ((type == 'message' || type == 'chat' || type == 'message_received' || type == 'chat_message') && appointmentId.toString().isNotEmpty) {
      _openChatDialogFromNotification(notification);
      return;
    } else if (appointmentId.toString().isNotEmpty) {
      // Try to find appointment in local list
      final appointment = _appointments.firstWhere(
        (a) => (a['id']?.toString() ?? '') == appointmentId.toString(),
        orElse: () => {},
      );
      if (appointment.isNotEmpty) {
        _openAppointmentDetails(appointment);
        return;
      } else {
        // Try fetch from Firestore
        try {
          final apptDoc = await FirebaseFirestore.instance.collection('appointments').doc(appointmentId.toString()).get();
          if (apptDoc.exists) {
            final apptData = apptDoc.data() as Map<String, dynamic>;
            final apptMap = {'id': apptDoc.id, ...apptData};
            _openAppointmentDetails(apptMap);
            return;
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No appointment details found for this notification.')),
            );
            return;
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error fetching appointment details.')),
          );
          return;
        }
      }
    }
    // Fallback: No appointmentId or unable to open
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No details available for this notification')),
    );
  }

  void _startSession(dynamic appointmentId) {
    final id = appointmentId.toString();
    print('[DEBUG] onStartSession callback: id=' + id + ', appt=' + appointmentId.toString());
    if (id.isNotEmpty) {
      _startSession(id);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot start session: Appointment ID missing.')),
      );
    }
  }

  Widget _buildNotificationList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('receiverId', isEqualTo: _consultantId)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final notifications = snapshot.data!.docs;
        if (notifications.isEmpty) {
          return const Center(child: Text('No notifications'));
        }
        return ListView.builder(
          shrinkWrap: true,
          itemCount: notifications.length,
          itemBuilder: (context, index) {
            final notif = notifications[index].data() as Map<String, dynamic>;
            final notificationType = notif['type'] ?? notif['notificationType'] ?? '';
            final appointmentId = notif['appointmentId'] ?? notif['data']?['appointmentId'] ?? notif['data']?['id'] ?? '';
            return ListTile(
              title: Text(notif['title'] ?? 'Notification', style: const TextStyle(color: Colors.white)),
              subtitle: Text(notif['body'] ?? '', style: const TextStyle(color: Colors.white70)),
              onTap: () async {
                // Mark notification as read if possible
                if (notif['id'] != null) {
                  await _notificationService.markNotificationAsRead(notif['id']);
                }
                if ((notificationType == 'message' || notificationType == 'chat' || notificationType == 'message_received' || notificationType == 'chat_message') && appointmentId.toString().isNotEmpty) {
                  _openChatDialogFromNotification(notif);
                  return;
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
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/page_bg.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: Stack(
        children: [
          _buildMainContent(context),
        ],
      ),
    );
  }

  Widget _buildMainContent(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/page_logo.png',
                  width: 40,
                  height: 40,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 8),
                Center(
                  child: Text(
                    'Consultant',
                    style: TextStyle(
                      color: AppColors.gold,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      fontFamily: 'Cinzel',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.logout, color: AppColors.primary),
            tooltip: 'Logout',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
              }
            },
          ),
        ],
      ),
      body: _currentIndex == 0
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date selector remains pinned at the top
                _buildWeeklySchedule(),
                // Everything else (attendance widget + appointment list) scrolls
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                        child: AttendanceActionsWidget(
                          userId: _consultantId,
                          name: _consultantName,
                          role: 'consultant',
                        ),
                      ),
                      // Appointment cards/dashboard content
                      _buildDashboardContent(),
                    ],
                  ),
                ),
              ],
            )
          : _currentIndex == 1
              ? Column(
                  children: [
                    Expanded(
                      child: _buildNotificationsTab(),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                      child: Row(
                        children: [
                          Text(
                            'Performance Metrics',
                            style: TextStyle(color: AppColors.primary, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          DropdownButton<String>(
                            value: _performanceTimeframe,
                            dropdownColor: Colors.black,
                            style: const TextStyle(color: Colors.white),
                            icon: const Icon(Icons.arrow_drop_down, color: Colors.amber),
                            underline: Container(height: 2, color: Colors.amber),
                            items: const [
                              DropdownMenuItem(value: 'Year', child: Text('Year')),
                              DropdownMenuItem(value: 'Month', child: Text('Month')),
                              DropdownMenuItem(value: 'Week', child: Text('Week')),
                              DropdownMenuItem(value: 'Future', child: Text('Future')),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _performanceTimeframe = value);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: PerformanceMetricsWidget(
                        key: ValueKey(_performanceTimeframe + _getPerformanceDateForTimeframe(_performanceTimeframe).toIso8601String()),
                        consultantId: _consultantId,
                        role: _consultantName.isNotEmpty ? 'consultant' : null,
                        selectedDate: _getPerformanceDateForTimeframe(_performanceTimeframe),
                        metricsData: null,
                      ),
                    ),
                  ],
                ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.black,
        selectedItemColor: AppColors.primary,
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
                  role: 'consultant',
                ),
              );
            }
          } else {
            setState(() => _currentIndex = index);
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

String _getAssignedToText(Map<String, dynamic> appt) {
  if (appt['consultantName'] != null && appt['consultantName'].toString().isNotEmpty) {
    return 'Consultant: ${appt['consultantName']}';
  } else if (appt['conciergeName'] != null && appt['conciergeName'].toString().isNotEmpty) {
    return 'Concierge: ${appt['conciergeName']}';
  } else if (appt['cleanerName'] != null && appt['cleanerName'].toString().isNotEmpty) {
    return 'Cleaner: ${appt['cleanerName']}';
  }
  return 'Unassigned';
}
