import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../features/floor_manager/presentation/widgets/daily_schedule.dart';
import '../../../features/floor_manager/presentation/screens/notifications_screen.dart';
import '../../../features/floor_manager/presentation/screens/floor_manager_home_screen_new.dart';
import '../../providers/app_auth_provider.dart';
import '../../constants/colors.dart';

class StandardHomeScreen extends StatefulWidget {
  const StandardHomeScreen({Key? key}) : super(key: key);

  @override
  State<StandardHomeScreen> createState() => _StandardHomeScreenState();
}

class _StandardHomeScreenState extends State<StandardHomeScreen> {
  int _selectedIndex = 0;
  int _unreadNotifications = 0;

  @override
  void initState() {
    super.initState();
    _setupNotificationListener();
  }

  void _setupNotificationListener() {
    final user = Provider.of<AppAuthProvider>(context, listen: false).appUser;
    if (user == null) return;

    print('Setting up notification listener for user: ${user.uid}, role: ${user.role}');

    // Different query for floor managers vs. other roles
    if (user.role == 'floor_manager') {
      print('Setting up floor manager notification listener');
      
      // Floor managers need to see all notifications sent to any floor manager
      FirebaseFirestore.instance
          .collection('notifications')
          .where('receiverId', isEqualTo: user.uid)
          .where('isRead', isEqualTo: false)
          .snapshots()
          .listen((snapshot) {
            print('Floor manager notification snapshot received: ${snapshot.docs.length} notifications');
            
            for (var doc in snapshot.docs) {
              print('Notification data: ${doc.data()}');
            }
            
            if (mounted) {
              setState(() {
                _unreadNotifications = snapshot.docs.length;
                print('Floor Manager notifications: $_unreadNotifications');
              });
            }
          });
    } else {
      // For other roles, filter by both role and assignedToId
      print('Setting up notification listener for role: ${user.role}, id: ${user.uid}');
      
      FirebaseFirestore.instance
          .collection('notifications')
          .where('role', isEqualTo: user.role)
          .where('isRead', isEqualTo: false)
          .where('assignedToId', isEqualTo: user.uid)
          .snapshots()
          .listen((snapshot) {
            print('User notification snapshot received: ${snapshot.docs.length} notifications');
            
            if (mounted) {
              setState(() {
                _unreadNotifications = snapshot.docs.length;
              });
            }
          });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AppAuthProvider>(context).appUser;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    // Debug print user role
    print('👉 STANDARD HOME SCREEN - USER ROLE: ${user.role}'); 

    // Automatically redirect to FloorManagerHomeScreenNew for floor_manager
    if (user.role == 'floor_manager') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const FloorManagerHomeScreenNew())
        );
      });
      // Show a loading indicator while redirecting
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Automatically redirect to FloorManagerHomeScreenNew
    if (user.role == 'unknown' || user.role.isEmpty) {
      // If we're here, probably the role wasn't set correctly in database
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const FloorManagerHomeScreenNew())
        );
      });
    }

    final List<Widget> pages = [
      // Daily Schedule Page
      Scaffold(
        appBar: AppBar(
          title: Text('Daily Schedule (Role: ${user.role})'),
          backgroundColor: AppColors.primary,
          actions: [
            IconButton(
              icon: const Icon(Icons.dashboard),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const FloorManagerHomeScreenNew()),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () {
                Provider.of<AppAuthProvider>(context, listen: false).signOut();
                Navigator.of(context).pushReplacementNamed('/login');
              },
            ),
          ],
        ),
        body: DailySchedule(selectedDate: DateTime.now()),
      ),

      // Notifications Page
      NotificationsScreen(userRole: user.role),
    ];

    final int navLength = 2; // Only 2 pages defined above

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex < navLength ? _selectedIndex : 0,
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: <BottomNavigationBarItem>[
          const BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Staff',
          ),
          BottomNavigationBarItem(
            icon: Stack(
              children: [
                const Icon(Icons.notifications),
                if (_unreadNotifications > 0)
                  Positioned(
                    right: 0,
                    top: 0,
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
                        '$_unreadNotifications',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            label: 'Notifications',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() {
            _selectedIndex = index < navLength ? index : 0;
          });
        },
      ),
    );
  }
}
