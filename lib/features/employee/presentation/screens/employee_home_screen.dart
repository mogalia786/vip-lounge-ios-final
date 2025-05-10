import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/providers/app_auth_provider.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/services/attendance_location_service.dart';
import '../../../../core/services/device_location_service.dart';
import 'appointments_screen.dart';

class EmployeeHomeScreen extends StatefulWidget {
  const EmployeeHomeScreen({super.key});

  @override
  State<EmployeeHomeScreen> createState() => _EmployeeHomeScreenState();
}

class _EmployeeHomeScreenState extends State<EmployeeHomeScreen> {
  int _selectedIndex = 0;

  Future<void> _handleClockIn() async {
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

  Future<void> _handleClockOut() async {
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

  final List<Widget> _screens = const [
    AppointmentsScreen(),
    // Add more screens here as needed
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'Employee Dashboard',
          style: TextStyle(color: AppColors.gold),
        ),
        iconTheme: IconThemeData(color: AppColors.gold),
        actions: [
          IconButton(
            icon: Icon(Icons.logout, color: AppColors.gold),
            onPressed: () {
              Provider.of<AppAuthProvider>(context, listen: false).signOut();
              Navigator.of(context).pushReplacementNamed('/login');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Row(
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
                onPressed: _handleClockIn,
                icon: const Icon(Icons.login, color: Colors.black),
                label: const Text('Clock In', style: TextStyle(color: Colors.black)),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                onPressed: _handleClockOut,
                icon: const Icon(Icons.logout, color: Colors.white),
                label: const Text('Clock Out', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
          Expanded(child: _screens[_selectedIndex]),
        ],
      ),
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(canvasColor: Colors.black),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          selectedItemColor: AppColors.gold,
          unselectedItemColor: Colors.grey,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today),
              label: 'Appointments',
            ),
            // Add more items here as needed
          ],
        ),
      ),
    );
  }
}
