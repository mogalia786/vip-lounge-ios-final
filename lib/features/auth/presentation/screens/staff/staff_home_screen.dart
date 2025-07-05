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
    // Total number of tabs (Home, Consultant, Daily, Scheduled, Performance)
    _tabController = TabController(length: 5, vsync: this, initialIndex: 0);
    _tabController.addListener(_handleTabChange);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      setState(() {
        _selectedIndex = _tabController.index;
      });
    }
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
            Tab(icon: Icon(Icons.bar_chart), text: 'Performance'),
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
    // Map tab indices to match between TabBar and BottomNavigationBar
    final tabToNavIndex = {
      0: 0, // Home
      1: 1, // Consultant
      2: 2, // Daily
      3: 3, // Scheduled
      4: 5, // Performance (index 5 in bottom nav)
    };

    // Map navigation indices back to tab indices
    final navToTabIndex = {
      0: 0, // Home
      1: 1, // Consultant
      2: 2, // Daily
      3: 3, // Scheduled
      5: 4, // Performance (tab index 4 corresponds to nav index 5)
    };

    return BottomNavigationBar(
      backgroundColor: Colors.black,
      selectedItemColor: AppColors.gold,
      unselectedItemColor: Colors.white70,
      currentIndex: tabToNavIndex[_selectedIndex] ?? 0,
      onTap: (navIndex) {
        // Handle Inbox navigation (special case)
        if (navIndex == 4) { // Inbox tab
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StaffQueryInboxScreen(currentStaffUid: _userId ?? ''),
            ),
          );
          return;
        }

        // For other tabs, update both the tab controller and selected index
        final tabIndex = navToTabIndex[navIndex] ?? 0;
        if (_tabController.index != tabIndex) {
          setState(() {
            _selectedIndex = tabIndex;
            _tabController.animateTo(tabIndex);
          });
        }
      },
      type: BottomNavigationBarType.fixed,
      elevation: 8,
      selectedFontSize: 12,
      unselectedFontSize: 12,
      items: [
        // Home
        const BottomNavigationBarItem(
          icon: Icon(Icons.home, size: 24),
          label: 'Home',
        ),
        // Consultant
        const BottomNavigationBarItem(
          icon: Icon(Icons.people, size: 24),
          label: 'Consultant',
        ),
        // Daily
        const BottomNavigationBarItem(
          icon: Icon(Icons.list_alt, size: 24),
          label: 'Daily',
        ),
        // Scheduled
        const BottomNavigationBarItem(
          icon: Icon(Icons.event_note, size: 24),
          label: 'Scheduled',
        ),
        // Inbox (special tab that doesn't correspond to a main tab)
        BottomNavigationBarItem(
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.inbox, size: 24),
              Positioned(
                right: -4,
                top: -4,
                child: StaffQueryBadge(
                  currentStaffUid: _userId ?? '',
                ),
              ),
            ],
          ),
          label: 'Inbox',
        ),
        // Performance
        const BottomNavigationBarItem(
          icon: Icon(Icons.bar_chart, size: 24),
          label: 'Performance',
        ),
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
      physics: const NeverScrollableScrollPhysics(), // Prevent horizontal swiping
      children: [
        // Home Tab
        _buildDashboardTab(),
        
        // Consultant Tab with Unified Appointment Cards
        Container(
          color: Colors.transparent,
          padding: const EdgeInsets.all(16.0),
          child: _buildConsultantAppointmentsList(),
        ),
        
        // Daily Activities Tab
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: StaffDailyActivitiesListWidget(
            userId: _userId ?? '',
            selectedDate: _selectedDate,
          ),
        ),
        
        // Scheduled Activities Tab
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: StaffScheduledActivitiesListWidget(
            userId: _userId ?? '',
            selectedDate: _selectedDate,
          ),
        ),
        
        // Performance Tab
        SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height - kToolbarHeight - kBottomNavigationBarHeight - 32,
              ),
              child: StaffPerformanceMetricsWidget(
                userId: _userId ?? '',
                selectedDate: _selectedDate,
              ),
            ),
          ),
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
    return _buildTabView();
  }

  Future<void> _handleLogout() async {
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Logout', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
        await authProvider.signOut();
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error during logout: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/page_bg.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Column(
          children: [
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  AppBar(
                    backgroundColor: Colors.black,
                    title: const Text(
                      'Staff',
                      style: TextStyle(
                        color: AppColors.gold,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    leading: IconButton(
                      icon: const Icon(
                        Icons.logout,
                        color: AppColors.gold,
                        size: 28.0,
                      ),
                      tooltip: 'Logout',
                      onPressed: _handleLogout,
                    ),
                    elevation: 0,
                    actions: [
                      // Notification Button
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
                        child: IconButton(
                          icon: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              const Icon(
                                Icons.notifications_outlined,
                                color: AppColors.gold,
                                size: 32.0,
                              ),
                              Positioned(
                                right: -2,
                                top: -2,
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
                                  child: const Text(
                                    '!',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => NotificationsScreen(
                                  userRole: 'staff',
                                  userId: _userId ?? '',
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      
                      // Inbox Button
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0, left: 4.0, top: 8.0, bottom: 8.0),
                        child: IconButton(
                          icon: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              const Icon(
                                Icons.inbox_outlined,
                                color: AppColors.gold,
                                size: 32.0,
                              ),
                              Positioned(
                                right: -4,
                                top: -4,
                                child: StaffQueryBadge(
                                  currentStaffUid: _userId ?? '',
                                ),
                              ),
                            ],
                          ),
                          tooltip: 'Queries Inbox',
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => StaffQueryInboxScreen(
                                  currentStaffUid: _userId ?? '',
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  _buildTabBar(),
                ],
              ),
            ),
            Expanded(
              child: _getTabBody(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }
}
