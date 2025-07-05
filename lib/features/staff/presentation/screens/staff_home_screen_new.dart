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
  String? _userId;
  String? _name;
  String? _role;

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

  void _onDateChange(DateTime date) {
    setState(() => _selectedDate = date);
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
            // ... rest of your tab body implementation
          ],
        );
      // ... other cases
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2, // Number of tabs (Staff and Consultants)
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: Row(
            children: [
              Image.asset(
                'assets/Premium.ico',
                width: 40,
                height: 40,
                errorBuilder: (context, error, stackTrace) => 
                    const Icon(Icons.star, color: Colors.amber, size: 40),
              ),
              const SizedBox(width: 8),
              const Text(
                'Staff Dashboard',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.gold,
                ),
              ),
            ],
          ),
          backgroundColor: Colors.black,
          actions: [
            // Notification bell icon with badge
            IconButton(
              icon: Stack(
                children: [
                  const Icon(Icons.notifications, color: AppColors.gold, size: 28),
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
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NotificationsScreen(userRole: 'staff', userId: _userId ?? ''),
                  ),
                );
              },
            ),
            // Queries inbox icon
            IconButton(
              icon: Stack(
                children: [
                  const Icon(Icons.inbox, color: AppColors.gold, size: 28),
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
            // Logout button
            IconButton(
              icon: const Icon(Icons.logout, color: AppColors.gold, size: 28),
              onPressed: () => _handleLogout(context),
            ),
          ],
          bottom: TabBar(
            labelColor: AppColors.gold,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AppColors.gold,
            tabs: const [
              Tab(text: 'Staff'),
              Tab(text: 'Consultants'),
            ],
          ),
        ),
        body: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/page_bg.png'),
              fit: BoxFit.cover,
            ),
          ),
          child: TabBarView(
            children: [
              // Staff Tab Content
              _getTabBody(),
              // Consultants Tab Content
              const Center(child: Text('Consultants Content', style: TextStyle(color: Colors.white))),
            ],
          ),
        ),
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
