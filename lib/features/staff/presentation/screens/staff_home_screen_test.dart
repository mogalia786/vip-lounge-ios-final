// TEST VERSION: Staff Home Screen with Consultant Tab Integration
// This file is a safe testbed for the new tabbed structure. No production code is affected.

// Export for use in other files
export 'staff_home_screen_test.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/colors.dart';
import 'package:intl/intl.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import 'package:vip_lounge/features/floor_manager/widgets/attendance_actions_widget.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/app_auth_provider.dart';
import '../../../../core/services/device_location_service.dart';
import '../../../../core/services/attendance_location_service.dart';
import '../widgets/staff_todo_list_widget.dart';
import '../widgets/staff_activity_entry_widget.dart';
import '../widgets/staff_daily_activities_list_widget.dart';
import '../widgets/staff_scheduled_activities_list_widget.dart';
import '../widgets/staff_performance_metrics_widget.dart';
import '../../../../core/widgets/role_notification_list.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vip_lounge/features/staff/presentation/screens/_staff_performance_indicator.dart' show StaffPerformanceIndicator;
import '../../../../core/widgets/staff_performance_widget.dart';
import 'package:vip_lounge/features/staff_query_badge.dart';
import 'package:vip_lounge/features/staff_query_inbox_screen.dart';
import 'package:vip_lounge/features/staff_query_all_screen.dart';
import 'package:vip_lounge/features/floor_manager/presentation/screens/notifications_screen.dart';
import 'package:vip_lounge/core/widgets/unified_appointment_card.dart';

// Consultant imports (shared widgets only, no duplication)
import 'package:vip_lounge/features/consultant/presentation/screens/consultant_home_screen_attendance.dart' show ConsultantHomeScreenAttendance;
import 'package:vip_lounge/features/consultant/presentation/widgets/sick_leave_dialog.dart';
import 'package:vip_lounge/features/consultant/presentation/widgets/performance_metrics_widget.dart';

class StaffHomeScreenTest extends StatefulWidget {
  const StaffHomeScreenTest({Key? key}) : super(key: key);

  @override
  State<StaffHomeScreenTest> createState() => _StaffHomeScreenTestState();
}

class _StaffHomeScreenTestState extends State<StaffHomeScreenTest> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  DateTime _selectedDate = DateTime.now();
  late TabController _tabController;
  String? _userId;
  String? _name;
  String? _role;

  // Consultant tab nav state (only this is new)
  int _consultantCurrentIndex = 0;
  int _consultantUnreadNotifications = 0; // Wire this to actual unread count if needed


  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final appUser = Provider.of<AppAuthProvider>(context, listen: false).appUser;
    if (_userId != appUser?.uid || _name != appUser?.fullName || _role != appUser?.role) {
      setState(() {
        _userId = appUser?.uid ?? '';
        _name = appUser?.fullName ?? '';
        _role = appUser?.role ?? 'staff';
      });
    }
  }
 

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {}); // Update nav bar when switching tabs
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _tabController.index == 0
        ? AppBar(
            backgroundColor: Colors.black,
            title: const Text('Staff Dashboards',
                style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 20)),
            actions: [
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StaffQueryAllScreen(currentStaffUid: _userId ?? ''),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Icon(Icons.question_answer, color: Colors.red, size: 28),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.notifications, color: Colors.red),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => NotificationsScreen(),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.red),
                tooltip: 'Logout',
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.clear();
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                      (route) => false,
                    );
                  }
                },
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.red,
              labelColor: Colors.red,
              unselectedLabelColor: Colors.white,
              tabs: const [
                Tab(text: 'Staff'),
                Tab(text: 'Consultant'),
              ],
            ),
          )
        : AppBar(
            backgroundColor: Colors.black,
            title: const Text('Consultant Home',
                style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 20)),
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications, color: Colors.red),
                onPressed: () {
                  // Implement consultant notifications navigation (if any)
                },
              ),
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.red),
                tooltip: 'Logout',
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.clear();
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                      (route) => false,
                    );
                  }
                },
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.red,
              labelColor: Colors.red,
              unselectedLabelColor: Colors.white,
              tabs: const [
                Tab(text: 'Staff'),
                Tab(text: 'Consultant'),
              ],
            ),
          ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildStaffTab(),
          _buildConsultantTab(),
        ],
      ),
      bottomNavigationBar: _tabController.index == 0
          ? _buildStaffBottomNavBar()
          : _buildConsultantBottomNavBar(),
    );
  }

  Widget _buildDateScroll() {
    // Unified 71-day red-accented date scroll for both tabs
    final scrollController = ScrollController();
    final startDate = DateTime.now().subtract(const Duration(days: 30));
    final todayIndex = DateTime.now().difference(startDate).inDays;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Scroll to the selected date (current date by default)
      if (scrollController.hasClients) {
        final itemWidth = 56.0 + 6.0; // width + margin
        final targetIndex = _selectedDate.difference(startDate).inDays;
        scrollController.animateTo(
          (targetIndex - 2).clamp(0, 71) * itemWidth, // show selected near center
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
        );
      }
    });

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.red, width: 2),
        borderRadius: BorderRadius.circular(18),
      ),
      child: SingleChildScrollView(
        controller: scrollController,
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(71, (i) {
            final date = startDate.add(Duration(days: i));
            final isSelected = date.year == _selectedDate.year && date.month == _selectedDate.month && date.day == _selectedDate.day;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedDate = date;
                });
              },
              child: Container(
                width: 56,
                margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.red : Colors.black,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isSelected ? Colors.red : Colors.transparent, width: 2),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      DateFormat('E').format(date), // Day abbreviation
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.red[300],
                        fontWeight: FontWeight.w500,
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      DateFormat('MMM').format(date),
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.red[200],
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('d').format(date),
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.red[100],
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildStaffTab() {
    switch (_selectedIndex) {
      case 0:
      // Dashboard (restored: Attendance, Date Scroll, Performance, Todo, Activity Entry)
      return CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16.0),
            sliver: SliverToBoxAdapter(
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Colors.red, width: 2),
                ),
                color: Colors.black,
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: AttendanceActionsWidget(
                    userId: _userId ?? '',
                    name: _name ?? '',
                    role: _role ?? 'staff',
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: _buildDateScroll(),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: StaffPerformanceIndicator(
                userId: _userId ?? '',
                selectedDate: _selectedDate,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            sliver: SliverToBoxAdapter(
              child: StaffTodoListWidget(
                userId: _userId ?? '',
                selectedDate: _selectedDate,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            sliver: SliverToBoxAdapter(
              child: StaffActivityEntryWidget(
                userId: _userId ?? '',
                onActivityAdded: () {
                  setState(() {});
                },
              ),
            ),
          ),
        ],
      );
      case 1:
        // Daily Activities
        return ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            StaffDailyActivitiesListWidget(userId: _userId ?? '', selectedDate: _selectedDate),
          ],
        );
      case 2:
        // Scheduled Activities
        return ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            StaffScheduledActivitiesListWidget(userId: _userId ?? '', selectedDate: _selectedDate),
          ],
        );
      case 4:
        // Performance Metrics
        return ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            StaffPerformanceMetricsWidget(userId: _userId ?? '', selectedDate: _selectedDate),
          ],
        );
      default:
        // 3 (Inbox) and 5-8: do nothing or placeholder
        return const SizedBox.shrink();
    }
  }

  Widget _buildStaffBottomNavBar() {
    return BottomNavigationBar(
      backgroundColor: Colors.black,
      selectedItemColor: Colors.red,
      unselectedItemColor: Colors.white70,
      currentIndex: _selectedIndex,
      onTap: (idx) async {
        switch (idx) {
          case 0:
          case 1:
          case 2:
          case 4:
            setState(() => _selectedIndex = idx);
            break;
          case 3:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => StaffQueryInboxScreen(currentStaffUid: _userId ?? ''),
              ),
            );
            break;
          default:
            // 5-8: do nothing
            break;
        }
      },
      type: BottomNavigationBarType.fixed,
      elevation: 8,
      items: [
        BottomNavigationBarItem(icon: const Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: const Icon(Icons.list_alt), label: 'Daily'),
        BottomNavigationBarItem(icon: const Icon(Icons.event_note), label: 'Scheduled'),
        BottomNavigationBarItem(icon: const Icon(Icons.inbox), label: 'Inbox'),
        BottomNavigationBarItem(icon: const Icon(Icons.bar_chart), label: 'Performance'),
      ],
    );
  }

  // Consultant tab bottom nav bar (only for consultant tab)
  Widget _buildConsultantBottomNavBar() {
    return BottomNavigationBar(
      backgroundColor: Colors.black,
      selectedItemColor: Colors.amber,
      unselectedItemColor: Colors.grey,
      type: BottomNavigationBarType.fixed,
      currentIndex: _consultantCurrentIndex,
      onTap: (index) async {
        switch (index) {
          case 0:
          case 1:
          case 2:
            setState(() => _consultantCurrentIndex = index);
            break;
          case 3:
            showDialog(
              context: context,
              builder: (ctx) => SickLeaveDialog(
                userId: _userId ?? '',
                userName: _name ?? '',
                role: _role ?? 'consultant',
              ),
            );
            break;
        }
      },
      items: [
        const BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
        BottomNavigationBarItem(
          icon: _consultantUnreadNotifications > 0
              ? Stack(
                  children: [
                    Icon(Icons.notifications),
                    Positioned(
                      right: 0,
                      child: Container(
                        padding: EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        constraints: BoxConstraints(
                          minWidth: 12,
                          minHeight: 12,
                        ),
                        child: Text(
                          '$_consultantUnreadNotifications',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                )
              : const Icon(Icons.notifications),
          label: 'Notifications',
        ),
        const BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Performance'),
        const BottomNavigationBarItem(icon: Icon(Icons.sick, color: Colors.redAccent), label: 'Sick Leave'),
      ],
    );
  }

  // Consultant tab main content switcher
  Widget _buildConsultantTab() {
    switch (_consultantCurrentIndex) {
      case 0:
        // Dashboard
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Colors.red, width: 2),
                ),
                color: Colors.black,
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: AttendanceActionsWidget(
                    userId: _userId ?? '',
                    name: _name ?? '',
                    role: 'consultant',
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: _buildDateScroll(),
            ),
            Expanded(
              child: _buildConsultantAppointmentsList(),
            ),
          ],
        );
      case 1:
        // Notifications
        return Container(
          color: Colors.black,
          child: RoleNotificationList(
            userId: _userId ?? '',
          ),
        );
      case 2:
        // Consultant Performance Metrics (not staff's)
        return Container(
          color: Colors.black,
          child: PerformanceMetricsWidget(
            consultantId: _userId ?? '',
            selectedDate: _selectedDate,
            role: _role ?? 'consultant',
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildConsultantAppointmentsList() {
    if (_userId == null || _userId!.isEmpty) {
      return const Center(child: Text('No consultant ID', style: TextStyle(color: Colors.white)));
    }
    final startOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('consultantId', isEqualTo: _userId)
          .where('appointmentTime', isGreaterThanOrEqualTo: startOfDay)
          .where('appointmentTime', isLessThan: endOfDay)
          .orderBy('appointmentTime')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No appointments scheduled.', style: TextStyle(color: Colors.white)));
        }
        final appointments = snapshot.data!.docs;
        return ListView.builder(
          itemCount: appointments.length,
          itemBuilder: (context, index) {
            final appt = appointments[index].data() as Map<String, dynamic>;
            return UnifiedAppointmentCard(
              role: 'consultant',
              isConsultant: true,
              ministerName: appt['ministerName'] ?? '',
              appointmentId: appointments[index].id,
              appointmentInfo: appt,
              date: appt['appointmentTime'] is Timestamp
                  ? (appt['appointmentTime'] as Timestamp).toDate()
                  : (appt['appointmentTime'] is DateTime)
                      ? appt['appointmentTime']
                      : null,
              time: null,
              ministerId: appt['ministerId'],
              disableStartSession: false,
            );
          },
        );
      },
    );
  }


}
