import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../providers/app_auth_provider.dart';
import '../../../features/floor_manager/presentation/widgets/daily_schedule.dart';
import '../../../features/floor_manager/presentation/screens/notifications_screen.dart';
import '../../constants/colors.dart';

class BaseHomeLayout extends StatefulWidget {
  final String title;
  final List<Widget> actions;
  final Widget mainContent;
  final List<BottomNavigationBarItem>? bottomNavItems;
  final int selectedIndex;
  final Function(int)? onNavItemSelected;

  const BaseHomeLayout({
    Key? key,
    required this.title,
    this.actions = const [],
    required this.mainContent,
    this.bottomNavItems,
    this.selectedIndex = 0,
    this.onNavItemSelected,
  }) : super(key: key);

  @override
  State<BaseHomeLayout> createState() => _BaseHomeLayoutState();
}

class _BaseHomeLayoutState extends State<BaseHomeLayout> {
  int _unreadNotifications = 0;

  @override
  void initState() {
    super.initState();
    _setupNotificationListener();
  }

  void _setupNotificationListener() {
    final user = Provider.of<AppAuthProvider>(context, listen: false).appUser;
    if (user == null) return;

    // Query for notifications based on role and assignedToId
    FirebaseFirestore.instance
        .collection('notifications')
        .where('role', isEqualTo: user.role)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          // Filter notifications that are either for the user's role or specifically assigned to them
          _unreadNotifications = snapshot.docs.where((doc) {
            final data = doc.data();
            return data['assignedToId'] == null || data['assignedToId'] == user.uid;
          }).length;
        });
      }
    });
  }

  List<BottomNavigationBarItem> _getDefaultNavItems() {
    final user = Provider.of<AppAuthProvider>(context, listen: false).appUser;
    if (user == null) return [];

    // Common navigation items for all roles
    final commonItems = <BottomNavigationBarItem>[
      const BottomNavigationBarItem(
        icon: Icon(Icons.home),
        label: 'Home',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.calendar_today),
        label: 'Schedule',
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
                    _unreadNotifications.toString(),
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
    ];

    // Add role-specific items
    if (user.role == 'minister') {
      commonItems.insert(1, const BottomNavigationBarItem(
        icon: Icon(Icons.calendar_today),
        label: 'Book',
      ));
      commonItems.insert(2, const BottomNavigationBarItem(
        icon: Icon(Icons.question_answer),
        label: 'Query',
      ));
    }

    return commonItems;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: AppColors.primary,
        actions: [
          ...widget.actions,
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Provider.of<AppAuthProvider>(context, listen: false).signOut();
              Navigator.of(context).pushReplacementNamed('/login');
            },
          ),
        ],
      ),
      body: widget.mainContent,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: widget.selectedIndex,
        onTap: widget.onNavItemSelected,
        items: widget.bottomNavItems ?? _getDefaultNavItems(),
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
