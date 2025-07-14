import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/app_auth_provider.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/services/notification_service.dart';

// Screens
import 'staff_management_screen.dart';
import 'notifications_screen.dart';
import 'floor_manager_chat_list_screen.dart';
import 'closed_days_screen.dart';
import 'appointment_details_screen.dart';

class FloorManagerHomeScreenNew extends StatefulWidget {
  const FloorManagerHomeScreenNew({super.key});

  @override
  State<FloorManagerHomeScreenNew> createState() => _FloorManagerHomeScreenNewState();
}

class _FloorManagerHomeScreenNewState extends State<FloorManagerHomeScreenNew> {
  // State variables
  int _unreadNotifications = 0;
  int _unreadMessages = 0;
  int _selectedIndex = 0;
  bool _isLoading = false;
  String _floorManagerId = '';
  String _floorManagerName = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  Map<String, dynamic>? _searchResult;

  // Controllers
  final ScrollController _horizontalScrollController = ScrollController();
  
  // Services
  final NotificationService _notificationService = NotificationService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _initializeUser();
    _initializePushNotificationDebug();
    _listenToUnreadNotifications();
    _listenToUnreadMessages();
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  // Initialize user data
  Future<void> _initializeUser() async {
    final currentUser = Provider.of<AppAuthProvider>(context, listen: false).appUser;
    if (currentUser != null) {
      setState(() {
        _floorManagerId = currentUser.id;
        _floorManagerName = currentUser.name;
      });
    }
  }
  
  // Initialize push notification debug
  void _initializePushNotificationDebug() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Got a message whilst in the foreground!');
      debugPrint('Message data: ${message.data}');

      if (message.notification != null) {
        debugPrint('Message also contained a notification: ${message.notification}');
      }
    });
  }

  // Listen to unread notifications
  void _listenToUnreadNotifications() {
    _notificationService.getUnreadNotificationsCount(_floorManagerId).listen((count) {
      if (mounted) {
        setState(() {
          _unreadNotifications = count;
        });
      }
    });
  }
  
  // Listen to unread messages
  void _listenToUnreadMessages() {
    // Implement message count listener here
    // This is a placeholder - replace with actual implementation
    if (mounted) {
      // Message count listener implementation will go here
    }
  }

  // Search appointments by reference number
  Future<void> _searchAppointment() async {
    final reference = _searchController.text.trim();
    if (reference.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a reference number')),
        );
      }
      return;
    }

    setState(() {
      _isSearching = true;
      _searchResult = null;
    });

    try {
      final querySnapshot = await _firestore
          .collection('appointments')
          .where('bookingReference', isEqualTo: reference)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        setState(() {
          _searchResult = {
            ...querySnapshot.docs.first.data(),
            'id': querySnapshot.docs.first.id,
          };
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No appointment found with this reference number')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error searching appointments: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error searching for appointment')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by reference number',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.0),
              ),
              suffixIcon: _isSearching
                  ? const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(),
                    )
                  : IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: _searchAppointment,
                    ),
            ),
            onSubmitted: (_) => _searchAppointment(),
          ),
          const SizedBox(height: 16.0),
        ],
      ),
    );
  }

  Widget _buildAppointmentDetails() {
    if (_searchResult == null) return const SizedBox.shrink();

    final appointment = _searchResult!;
    final appointmentTime = (appointment['appointmentTime'] as Timestamp).toDate();
    final formattedDate = DateFormat('EEEE, MMMM d, y').format(appointmentTime);
    final formattedTime = DateFormat('h:mm a').format(appointmentTime);

    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Appointment Details',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Divider(),
            _buildDetailRow(Icons.person, 'Client:', appointment['clientName'] ?? 'N/A'),
            _buildDetailRow(Icons.phone, 'Phone:', appointment['phoneNumber'] ?? 'N/A'),
            _buildDetailRow(Icons.calendar_today, 'Date:', formattedDate),
            _buildDetailRow(Icons.access_time, 'Time:', formattedTime),
            _buildDetailRow(Icons.confirmation_number, 'Reference:', appointment['bookingReference'] ?? 'N/A'),
            if (appointment['notes'] != null && appointment['notes'].isNotEmpty)
              _buildDetailRow(Icons.notes, 'Notes:', appointment['notes']),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20.0, color: AppColors.gold),
          const SizedBox(width: 8.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14.0,
                  ),
                ),
                const SizedBox(height: 2.0),
                Text(
                  value,
                  style: const TextStyle(fontSize: 16.0),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return AppBar(
      title: const Text('Floor Manager Dashboard'),
      backgroundColor: Colors.black,
      elevation: 0,
      actions: [
        // Notifications
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NotificationsScreen(),
                  ),
                );
              },
            ),
            if (_unreadNotifications > 0)
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
        // Messages
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.chat),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const FloorManagerChatListScreen(),
                  ),
                );
              },
            ),
            if (_unreadMessages > 0)
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
                    '$_unreadMessages',
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
      ],
    );
  }

  Widget _buildBody() {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              // Greeting
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Welcome, $_floorManagerName',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              
              // Search bar
              _buildSearchBar(),
              
              // Search results or main content
              if (_searchResult != null)
                _buildAppointmentDetails()
              else
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search,
                          size: 64.0,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16.0),
                        const Text(
                          'Search for an appointment by reference number',
                          style: TextStyle(color: Colors.white70),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
            // Navigation logic here
            switch (index) {
              case 0:
                // Home - already here
                break;
              case 1:
                // Staff Management
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const StaffManagementScreen(),
                  ),
                );
                break;
              case 2:
                // Closed Days
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ClosedDaysScreen(),
                  ),
                );
                break;
            }
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.black,
        selectedItemColor: AppColors.gold,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Staff',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Closed Days',
          ),
        ],
      ),
    );
  }
}
