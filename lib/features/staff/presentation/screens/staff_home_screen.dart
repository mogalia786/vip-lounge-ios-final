import 'package:flutter/material.dart';
import 'package:vip_lounge/features/shared/utils/app_update_helper.dart';
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
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vip_lounge/features/staff/presentation/screens/_staff_performance_indicator.dart' show StaffPerformanceIndicator;
import '../../../../core/widgets/staff_performance_widget.dart';
import 'package:vip_lounge/features/staff_query_badge.dart';
import 'package:vip_lounge/features/staff_query_inbox_screen.dart';
import 'package:vip_lounge/features/staff_query_all_screen.dart';
import 'package:vip_lounge/features/floor_manager/presentation/screens/notifications_screen.dart';

class StaffHomeScreen extends StatefulWidget {
  const StaffHomeScreen({Key? key}) : super(key: key);

  @override
  State<StaffHomeScreen> createState() => _StaffHomeScreenState();
}

class _StaffHomeScreenState extends State<StaffHomeScreen> {
  int _selectedIndex = 0;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Silwela in-app update check
  }

  void _onNavTap(int idx) {
    setState(() => _selectedIndex = idx);
    if (idx == 3) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StaffQueryInboxScreen(currentStaffUid: _userId ?? ''),
        ),
      );
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _handleClockIn(BuildContext context, String userId, String name, String role) async {
    try {
      bool testMode = false;
      final prefs = await SharedPreferences.getInstance();
      testMode = prefs.getBool('test_mode') ?? false;
      if (!testMode) {
        final userLocation = await DeviceLocationService.getCurrentUserLocation(context);
        if (userLocation == null) return;
        bool isAllowed = await AttendanceLocationService.isWithinAllowedDistance(userLocation: userLocation);
        if (!isAllowed) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You are not within the allowed area to clock in.')),
          );
          return;
        }
      }
      // ... original clock in logic ...
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error clocking in: $e')),
      );
    }
  }

  Future<void> _handleClockOut(BuildContext context, String userId, String name, String role) async {
    try {
      bool testMode = false;
      final prefs = await SharedPreferences.getInstance();
      testMode = prefs.getBool('test_mode') ?? false;
      if (!testMode) {
        final userLocation = await DeviceLocationService.getCurrentUserLocation(context);
        if (userLocation == null) return;
        bool isAllowed = await AttendanceLocationService.isWithinAllowedDistance(userLocation: userLocation);
        if (!isAllowed) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You are not within the allowed area to clock out.')),
          );
          return;
        }
      }
      // ... original clock out logic ...
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error clocking out: $e')),
      );
    }
  }

  String? _userId;
  String? _name;
  String? _role;

  Future<void> assignQueryToStaff(String queryId, String staffUid, String staffName) async {
    final firestore = FirebaseFirestore.instance;
    await firestore.collection('queries').doc(queryId).update({
      'assignedTo': staffUid,
      'assignedToName': staffName,
      'status': 'being_attended',
      'statusHistory': FieldValue.arrayUnion([
        {
          'status': 'being_attended',
          'by': staffUid,
          'byName': staffName,
          'timestamp': Timestamp.now(),
          'note': 'Staff took initiative to attend',
        }
      ]),
    });
  }

  void _onDateChange(DateTime d) {
    setState(() => _selectedDate = d);
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

  Widget _getTabBody() {
    switch (_selectedIndex) {
      case 0:
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(16.0),
              sliver: SliverToBoxAdapter(
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: AppColors.gold, width: 2),
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
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.amber, width: 2),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(30, (i) {
                        final date = DateTime.now().subtract(const Duration(days: 1)).add(Duration(days: i));
                        final isSelected = _selectedDate.year == date.year && _selectedDate.month == date.month && _selectedDate.day == date.day;
                        return GestureDetector(
                          onTap: () => _onDateChange(date),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
                            decoration: BoxDecoration(
                              gradient: isSelected
                                ? LinearGradient(colors: [AppColors.gold, Colors.orange.shade700])
                                : LinearGradient(colors: [Colors.black87, Colors.grey.shade800]),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: isSelected
                                ? [BoxShadow(color: Colors.amber.withOpacity(0.25), blurRadius: 12, offset: Offset(0, 2))]
                                : [],
                              border: isSelected ? Border.all(color: Colors.deepOrange, width: 3) : null,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  DateFormat('EEE').format(date),
                                  style: TextStyle(
                                    color: isSelected ? Colors.deepOrange : AppColors.gold,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  DateFormat('d').format(date),
                                  style: TextStyle(
                                    color: isSelected ? Colors.amber[900] : Colors.amber[100],
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
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              sliver: SliverToBoxAdapter(
                child: StaffPerformanceIndicator(userId: _userId ?? '', selectedDate: _selectedDate),
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
        return ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            StaffDailyActivitiesListWidget(userId: _userId ?? '', selectedDate: _selectedDate),
          ],
        );
      case 2:
        return ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            StaffScheduledActivitiesListWidget(userId: _userId ?? '', selectedDate: _selectedDate),
          ],
        );
      case 3:
        return StaffQueryInboxScreen(currentStaffUid: _userId ?? '');
      case 4:
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
      appBar: AppBar(
        title: const Text(
          'Staff Dashboards',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.black,
        foregroundColor: AppColors.gold,
        actions: [
          // Notification bell icon with badge
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.notifications, color: AppColors.gold),
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 14,
                      minHeight: 14,
                    ),
                    child: const Text(
                      '!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            tooltip: 'Notifications',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => NotificationsScreen(userRole: 'staff', userId: _userId ?? ''),
                ),
              );
            },
          ),
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.inbox, color: AppColors.gold),
                Positioned(
                  right: 0,
                  top: 0,
                  child: StaffQueryBadge(
                    currentStaffUid: _userId ?? '',
                  ),
                ),
              ],
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StaffQueryAllScreen(currentStaffUid: _userId ?? ''),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today, color: AppColors.gold),
            tooltip: 'Select Month',
            onPressed: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime(_selectedDate.year, _selectedDate.month, 1),
                firstDate: DateTime(now.year - 5, 1),
                lastDate: DateTime(now.year + 1, 12),
                initialEntryMode: DatePickerEntryMode.calendarOnly,
                selectableDayPredicate: (day) => day.day == 1,
                helpText: 'Select Month',
              );
              if (picked != null) {
                setState(() {
                  _selectedDate = DateTime(picked.year, picked.month, 1);
                  _selectedIndex = 4; // Switch to Performance tab
                });
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.gold),
            onPressed: () => _handleLogout(context),
          ),
        ],
      ),
      body: _getTabBody(),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.black,
        selectedItemColor: AppColors.gold,
        unselectedItemColor: Colors.white70,
        currentIndex: _selectedIndex,
        onTap: _onNavTap,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home, color: AppColors.gold), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.list_alt, color: AppColors.gold), label: 'My Daily Activities'),
          BottomNavigationBarItem(icon: Icon(Icons.event_note, color: AppColors.gold), label: 'My Scheduled Activities'),
          BottomNavigationBarItem(icon: Icon(Icons.inbox, color: AppColors.gold), label: 'Inbox'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart, color: AppColors.gold), label: 'Performance'),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Card(
      color: AppColors.black,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: 150,
          height: 150,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: AppColors.gold),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.gold,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}