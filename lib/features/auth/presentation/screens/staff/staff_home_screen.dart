import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vip_lounge/core/constants/colors.dart';
import 'package:vip_lounge/features/floor_manager/widgets/attendance_actions_widget.dart';
import 'package:vip_lounge/core/providers/app_auth_provider.dart';
import 'package:vip_lounge/features/auth/presentation/screens/login_screen.dart';
import 'package:vip_lounge/features/floor_manager/presentation/screens/notifications_screen.dart';
import 'package:vip_lounge/features/staff_query_badge.dart';
import 'package:vip_lounge/features/staff_query_inbox_screen.dart';
import 'package:vip_lounge/features/staff_query_all_screen.dart';
import 'package:vip_lounge/features/staff/presentation/widgets/staff_todo_list_widget.dart';
import 'package:vip_lounge/features/staff/presentation/widgets/staff_activity_entry_widget.dart';
import 'package:vip_lounge/features/staff/presentation/widgets/staff_daily_activities_list_widget.dart';
import 'package:vip_lounge/features/staff/presentation/widgets/staff_scheduled_activities_list_widget.dart';
import 'package:vip_lounge/features/staff/presentation/widgets/staff_performance_metrics_widget.dart';
import 'package:vip_lounge/features/staff/presentation/widgets/staff_performance_indicator.dart';
import 'package:vip_lounge/core/widgets/unified_appointment_card.dart';

class StaffHomeScreen extends StatefulWidget {
  const StaffHomeScreen({super.key});

  @override
  State<StaffHomeScreen> createState() => _StaffHomeScreenState();
}

class _StaffHomeScreenState extends State<StaffHomeScreen> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late TabController _tabController;
  DateTime _selectedDate = DateTime.now();
  String? _userId;
  String? _name;
  String? _role;
  int _consultantCurrentIndex = 0;
  int _consultantUnreadNotifications = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _selectedIndex = _tabController.index;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  PreferredSizeWidget _buildTabBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: Container(
        color: Colors.black,
        child: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppColors.gold,
          unselectedLabelColor: Colors.white70,
          indicatorColor: AppColors.gold,
          tabs: const [
            Tab(icon: Icon(Icons.home), text: 'Home'),
            Tab(icon: Icon(Icons.people), text: 'Consultant'),
            Tab(icon: Icon(Icons.list_alt), text: 'Daily'),
            Tab(icon: Icon(Icons.event_note), text: 'Scheduled'),
            Tab(icon: Icon(Icons.inbox), text: 'Inbox'),
          ],
        ),
      ),
    );
  }

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

  Widget _buildDateScroll() {
    final scrollController = ScrollController();
    final startDate = DateTime.now().subtract(const Duration(days: 30));
    final todayIndex = DateTime.now().difference(startDate).inDays;

    WidgetsBinding.instance.addPostFrameCallback((_) {
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
        border: Border.all(color: AppColors.primary, width: 2),
        borderRadius: BorderRadius.circular(18),
      ),
      child: SingleChildScrollView(
        controller: scrollController,
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(71, (i) {
            final date = startDate.add(Duration(days: i));
            final isSelected = date.year == _selectedDate.year && 
                            date.month == _selectedDate.month && 
                            date.day == _selectedDate.day;
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
                  color: isSelected ? AppColors.primary : AppColors.red,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : Colors.transparent, 
                    width: 2
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      DateFormat('E').format(date),
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

  Widget _buildDashboardTab() {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16.0),
          sliver: SliverToBoxAdapter(
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.primary, width: 2),
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
  }

  Widget _buildBottomNavBar() {
    return BottomNavigationBar(
      backgroundColor: Colors.black,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: Colors.white70,
      currentIndex: _selectedIndex,
      onTap: (index) {
        switch (index) {
          case 0: // Dashboard
          case 1: // Daily
          case 2: // Scheduled
          case 4: // Performance
            setState(() => _selectedIndex = index);
            break;
          case 3: // Inbox
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => StaffQueryInboxScreen(currentStaffUid: _userId ?? ''),
              ),
            );
            break;
        }
      },
      type: BottomNavigationBarType.fixed,
      elevation: 8,
      items: [
        const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        const BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Consultant'),
        const BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: 'Daily'),
        const BottomNavigationBarItem(icon: Icon(Icons.event_note), label: 'Scheduled'),
        BottomNavigationBarItem(
          icon: Stack(
            children: [
              const Icon(Icons.inbox),
              Positioned(
                right: 0,
                child: StaffQueryBadge(currentStaffUid: _userId ?? ''),
              ),
            ],
          ),
          label: 'Inbox',
        ),
        const BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Performance'),
      ],
    );
  }

  Widget _buildConsultantAppointmentsList() {
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
          return const Center(
            child: Text('No appointments scheduled.', style: TextStyle(color: Colors.white)),
          );
        }
        
        final appointments = snapshot.data!.docs;
        return ListView.builder(
          key: ValueKey(_selectedDate), // Force rebuild on date change
          itemCount: appointments.length,
          itemBuilder: (context, index) {
            final appt = appointments[index].data() as Map<String, dynamic>;
            final apptId = appointments[index].id;
            
            return UnifiedAppointmentCard(
              key: ValueKey('${apptId}_${appt['consultantSessionStarted']}_${appt['consultantSessionEnded']}'),
              role: 'consultant',
              isConsultant: true,
              ministerName: appt['ministerName'] ?? '',
              appointmentId: apptId,
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

  Widget _buildTabView() {
    return TabBarView(
      controller: _tabController,
      children: [
        // Dashboard Tab
        _buildDashboardTab(),
        
        // Consultant Tab with Unified Appointment Cards
        Container(
          color: Colors.transparent,
          padding: const EdgeInsets.all(16.0),
          child: _buildConsultantAppointmentsList(),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'scheduled':
        return Colors.blue;
      case 'in_progress':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _completeAppointment(String appointmentId) async {
    try {
      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(appointmentId)
          .update({
            'status': 'completed',
            'completedAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error completing appointment: $e')),
        );
      }
    }
  }

  void _onNavTap(int index) {
    setState(() => _selectedIndex = index);
    if (index == 3) { // Inbox tab
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StaffQueryInboxScreen(currentStaffUid: _userId ?? ''),
        ),
      );
    } else if (index == 4) { // Performance tab
      setState(() {
        _selectedDate = DateTime.now();
      });
    }
  }

  Widget _getTabBody() {
    switch (_selectedIndex) {
      case 0: // Home/Dashboard
        return _buildDashboardTab();
      case 1: // Consultant/Appointments
        return _buildTabView();
      case 2: // Daily Activities
        return ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            StaffDailyActivitiesListWidget(userId: _userId ?? '', selectedDate: _selectedDate),
          ],
        );
      case 4: // Performance
        return ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            StaffPerformanceMetricsWidget(userId: _userId ?? '', selectedDate: _selectedDate),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
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
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.black,
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
              const Text(
                'Staff',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          bottom: _buildTabBar(),
          actions: [
            IconButton(
              icon: Stack(
                children: [
                  const Icon(Icons.notifications, color: AppColors.primary),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: StaffQueryBadge(currentStaffUid: _userId ?? ''),
                  ),
                ],
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NotificationsScreen(),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.logout, color: AppColors.primary),
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
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            // Home Tab
            _getTabBody(),
            // Consultant Tab
            _buildConsultantAppointmentsList(),
            // Daily Tab
            ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                StaffDailyActivitiesListWidget(userId: _userId ?? '', selectedDate: _selectedDate),
              ],
            ),
            // Scheduled Tab
            ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                StaffScheduledActivitiesListWidget(
                  userId: _userId ?? '',
                  selectedDate: _selectedDate,
                ),
              ],
            ),
            // Inbox Tab
            const StaffQueryInboxScreen(currentStaffUid: ''),
          ],
        ),
      ),
    );
  }
}
