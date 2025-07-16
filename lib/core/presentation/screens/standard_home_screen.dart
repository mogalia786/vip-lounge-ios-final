import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../features/floor_manager/presentation/widgets/daily_schedule.dart';
import '../../../features/floor_manager/presentation/screens/notifications_screen.dart';
import '../../../features/floor_manager/presentation/screens/floor_manager_home_screen_new.dart';
import '../../../features/floor_manager/presentation/screens/appointment_search_screen_new.dart';
import '../../../features/floor_manager/presentation/screens/query_search_screen.dart';
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
  DateTime _selectedDate = DateTime.now();


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

    // Automatically redirect to FloorManagerHomeScreen for floor_manager
    if (user.role == 'floor_manager') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const FloorManagerHomeScreenNew())
        );
      });
      // Show a loading indicator while redirecting
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Handle unknown/empty role
    if (user.role == 'unknown' || user.role.isEmpty) {
      // If we're here, probably the role wasn't set correctly in database
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const FloorManagerHomeScreenNew())
        );
      });
    }

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
          backgroundColor: Colors.black,
          title: const Text('Home'),
          actions: [
            // Search Appointments
            IconButton(
              icon: const Icon(Icons.search, color: Colors.blue, size: 24),
              tooltip: 'Search Appointments',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AppointmentSearchScreen(),
                  ),
                );
              },
            ),
            
            // Search Queries
            IconButton(
              icon: const Icon(Icons.help_outline, color: Colors.blue, size: 24),
              tooltip: 'Search Queries',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const QuerySearchScreen(),
                  ),
                );
              },
            ),
            
            // Pickup Locations Management
            IconButton(
              icon: const Icon(Icons.location_on, color: Colors.blue),
              tooltip: 'Manage Pickup Locations',
              onPressed: () => Navigator.pushNamed(context, '/pickup-locations'),
            ),
            
            // Client Types Management
            IconButton(
              icon: const Icon(Icons.people, color: Colors.green),
              tooltip: 'Manage Client Types',
              onPressed: () => Navigator.pushNamed(context, '/client-types'),
            ),
            
            // Floor Manager Dashboard
            IconButton(
              icon: const Icon(Icons.dashboard, color: Colors.purple),
              tooltip: 'Floor Manager Dashboard',
              onPressed: () => Navigator.pushNamed(context, '/floor_manager/home'),
            ),
            
            // Notifications
            if (_unreadNotifications > 0)
              Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications, color: Colors.orange),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => NotificationsScreen(
                            userId: user.uid,
                            userRole: user.role,
                          ),
                        ),
                      );
                    },
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        '$_unreadNotifications',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            if (_unreadNotifications == 0)
              IconButton(
                icon: const Icon(Icons.notifications_none, color: AppColors.primary),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => NotificationsScreen(
                        userId: user.uid,
                        userRole: user.role,
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(width: 8),
            
            // Logout button
            IconButton(
              icon: const Icon(Icons.logout, color: AppColors.primary),
              onPressed: () {
                Provider.of<AppAuthProvider>(context, listen: false).signOut();
                Navigator.of(context).pushReplacementNamed('/login');
              },
            ),
          ],
        ),
        body: Container(
          color: Colors.black.withOpacity(0.6), // Semi-transparent overlay for better text readability
          child: DailySchedule(selectedDate: _selectedDate),
        ),
      ),
    );
  }
}
