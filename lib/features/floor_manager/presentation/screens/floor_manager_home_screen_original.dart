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

class FloorManagerHomeScreen extends StatefulWidget {
  const FloorManagerHomeScreen({super.key});

  @override
  State<FloorManagerHomeScreen> createState() => _FloorManagerHomeScreenState();
}

class _FloorManagerHomeScreenState extends State<FloorManagerHomeScreen> {
  // State variables
  int _unreadNotifications = 0;
  int _unreadMessages = 0;
  int _selectedIndex = 0;
  bool _isLoading = false;
  String _floorManagerId = '';
  String _floorManagerName = '';
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  // Controllers
  final ScrollController _horizontalScrollController = ScrollController();
  
  // Services
  final NotificationService _notificationService = NotificationService();
  
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
  Future<void> _searchAppointments(String reference) async {
    if (reference.isEmpty) return;
    
    setState(() {
      _isLoading = true;
      _isSearching = true;
    });
    
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .where('referenceNumber', isEqualTo: reference)
          .get();
          
      setState(() {
        _searchResults = querySnapshot.docs.map((doc) => {
          'id': doc.id,
          ...doc.data() as Map<String, dynamic>,
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error searching appointments: $e');
      setState(() {
        _isLoading = false;
      });
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error searching appointments')),
        );
      }
    }
  }

  // Navigate to appointment details
  void _navigateToAppointmentDetails(Map<String, dynamic> appointment) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AppointmentDetailsScreen(
          appointment: appointment,
        ),
      ),
    );
  }
  
  // Build home content
  Widget _buildHomeContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
          
          // Search container
          _buildSearchBar(),
          
          // Search results or empty state
          if (_isSearching) ..._buildSearchResults(),
          
          // Add some spacing at the bottom
          const SizedBox(height: 80),
        ],
      ),
    );
  }
  
  // Build search bar
  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.all(16.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Search Appointments',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Enter reference number',
              hintStyle: TextStyle(color: Colors.grey[400]),
              filled: true,
              fillColor: Colors.grey[800],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              suffixIcon: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : null,
            ),
            onSubmitted: (_) => _searchAppointments(_searchController.text),
          ),
        ],
      ),
    );
  }
  
  // Build search results
  List<Widget> _buildSearchResults() {
    if (_isLoading) {
      return [
        const SizedBox(height: 16),
        const Center(
          child: CircularProgressIndicator(),
        ),
      ];
    }

    if (_searchResults.isEmpty) {
      return [
        const SizedBox(height: 16),
        const Center(
          child: Text(
            'No appointments found',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      ];
    }

    return [
      const SizedBox(height: 16),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.0),
        child: Text(
          'Search Results:',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      const SizedBox(height: 8),
      ..._searchResults.map((appointment) => _buildAppointmentCard(appointment)),
    ];
  }

  // Build appointment card
  Widget _buildAppointmentCard(Map<String, dynamic> appointment) {
    try {
      final dateTime = appointment['date'] != null 
          ? (appointment['date'] is Timestamp 
              ? (appointment['date'] as Timestamp).toDate()
              : DateTime.parse(appointment['date'].toString()))
          : DateTime.now();
      
      final formattedDate = DateFormat('dd/MM/yyyy').format(dateTime);
      final formattedTime = DateFormat('HH:mm').format(dateTime);
      
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        color: Colors.grey[850],
        child: InkWell(
          onTap: () => _navigateToAppointmentDetails(appointment),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Ref: ${appointment['referenceNumber'] ?? 'N/A'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(appointment['status'] ?? ''),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        (appointment['status']?.toString().toUpperCase() ?? 'UNKNOWN'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${appointment['clientName'] ?? 'N/A'}\n',
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  'Date: $formattedDate at $formattedTime',
                  style: const TextStyle(color: Colors.grey),
                ),
                if (appointment['consultantName'] != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Consultant: ${appointment['consultantName']}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error building appointment card: $e');
      return const SizedBox.shrink();
    }
  }

  // Get status color
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      case 'completed':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  // Build the main app bar
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('Floor Manager Dashboard'),
      backgroundColor: Colors.black,
      elevation: 0,
      actions: [
        // Notifications
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_none, color: Colors.white),
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
                    _unreadNotifications.toString(),
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
              icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
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
                    _unreadMessages.toString(),
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

  // Build the main body
  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0: // Home
        return _buildHomeContent();
      case 1: // Staff
        return const StaffManagementScreen();
      case 2: // Schedule
        return const ClosedDaysScreen();
      default:
        return const Center(
          child: Text(
            'Page not found',
            style: TextStyle(color: Colors.white),
          ),
        );
    }
  }
  
  // Build bottom navigation bar
  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      onTap: (index) {
        setState(() {
          _selectedIndex = index;
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
          label: 'Schedule',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _buildAppBar(),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }
}
