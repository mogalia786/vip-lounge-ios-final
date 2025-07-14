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

class FloorManagerHomeScreenUpdated extends StatefulWidget {
  const FloorManagerHomeScreenUpdated({super.key});

  @override
  State<FloorManagerHomeScreenUpdated> createState() => _FloorManagerHomeScreenUpdatedState();
}

class _FloorManagerHomeScreenUpdatedState extends State<FloorManagerHomeScreenUpdated> {
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
  
  // Navigation items
  final List<BottomNavigationBarItem> _bottomNavItems = const [
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
  ];

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
  
  // Build schedule management content
  Widget _buildScheduleManagementContent() {
    return const Center(
      child: Text(
        'Schedule Management',
        style: TextStyle(color: Colors.white),
      ),
    );
  }

  // Build search container
  Widget _buildSearchContainer() {
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
          if (_isSearching) ..._buildSearchResults(),
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
      const Text(
        'Search Results:',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(height: 8),
      ..._searchResults.map((appointment) => _buildAppointmentCard(appointment)),
    ];
  }
  
  // Format date
  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMM d, y').format(date);
    } catch (e) {
      return dateString;
    }
  }
  
  // Format time
  String _formatTime(String timeString) {
    try {
      final time = TimeOfDay(
        hour: int.parse(timeString.split(':')[0]),
        minute: int.parse(timeString.split(':')[1]),
      );
      return time.format(context);
    } catch (e) {
      return timeString;
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

  // Build appointment card
  Widget _buildAppointmentCard(Map<String, dynamic> appointment) {
    try {
      final dateTime = DateTime.parse(appointment['date'] ?? DateTime.now().toString());
      final formattedDate = '${dateTime.day}/${dateTime.month}/${dateTime.year}';
      final formattedTime = '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
      
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
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
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        color: Colors.grey[850],
        child: const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Error loading appointment details',
            style: TextStyle(color: Colors.red),
          ),
        ),
      );
    }
  }

  // Build the app bar
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
              icon: const Icon(Icons.notifications_none),
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
              icon: const Icon(Icons.chat_bubble_outline),
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

  // Build the bottom navigation bar
  Widget _buildBottomNavBar() {
    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      onTap: (index) {
        setState(() {
          _selectedIndex = index;
        });
        
        // Handle navigation
        switch (index) {
          case 0: // Home
            // Already on home
            break;
          case 1: // Staff
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const StaffManagementScreen(),
              ),
            );
            break;
          case 2: // Schedule
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ClosedDaysScreen(),
              ),
            );
            break;
        }
      },
      backgroundColor: Colors.black,
      selectedItemColor: AppColors.gold,
      unselectedItemColor: Colors.grey,
      items: _bottomNavItems,
    );
  }

  // Build the main content based on selected tab
  Widget _buildMainContent() {
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

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.all(16.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Search Appointments',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18.0,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12.0),
          TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Enter reference number',
              hintStyle: TextStyle(color: Colors.grey[500]),
              filled: true,
              fillColor: Colors.grey[800],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 14.0,
              ),
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchResults = [];
                          _isSearching = false;
                        });
                      },
                    )
                  : null,
            ),
            onChanged: (value) {
              if (value.isEmpty) {
                setState(() {
                  _searchResults = [];
                  _isSearching = false;
                });
              }
            },
            onSubmitted: _searchAppointments,
          ),
          const SizedBox(height: 12.0),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _searchAppointments(_searchController.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                padding: const EdgeInsets.symmetric(vertical: 14.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20.0,
                      height: 20.0,
                      child: CircularProgressIndicator(
                        color: Colors.black,
                        strokeWidth: 2.0,
                      ),
                    )
                  : const Text(
                      'Search',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 16.0,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
  
  // Build search results
  List<Widget> _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'No appointments found with that reference number.',
            style: TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ),
      ];
    }
    
    return [
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Text(
          'Search Results:',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16.0,
          ),
        ),
      ),
      ..._searchResults.map((appointment) => _buildAppointmentCard(appointment)).toList(),
    ];
  }
  
  // Build appointment card
  Widget _buildAppointmentCard(Map<String, dynamic> appointment) {
    final dateTime = appointment['dateTime'] is Timestamp 
        ? (appointment['dateTime'] as Timestamp).toDate()
        : DateTime.parse(appointment['dateTime'].toString());
    final formattedDate = DateFormat('MMM d, y').format(dateTime);
    final formattedTime = DateFormat('h:mm a').format(dateTime);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      color: Colors.grey[900],
      child: ListTile(
        title: Text(
          appointment['clientName'] ?? 'No Name',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          '$formattedDate at $formattedTime\n${appointment['service'] ?? 'No service specified'}',
          style: const TextStyle(color: Colors.grey),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: () => _navigateToAppointmentDetails(appointment),
      ),
    );
  }
  
  // Build dashboard content
  Widget _buildDashboardContent() {
    return Column(
      children: [
        _buildSearchBar(),
        if (_isSearching) ..._buildSearchResults(),
      ],
    );
  }
  
  // Build schedule management content
  Widget _buildScheduleManagementContent() {
    return const Center(
      child: Text(
        'Schedule Management',
        style: TextStyle(color: Colors.white),
      ),
    );
  }
  
  // Build the main body
  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0: // Home
        return _buildHomeContent();
      case 1: // Staff Management
        return const StaffManagementScreen();
      case 2: // Schedule Management
        return _buildScheduleManagementContent();
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
      onTap: _onItemTapped,
      backgroundColor: Colors.black,
      selectedItemColor: AppColors.gold,
      unselectedItemColor: Colors.grey[600],
      items: _bottomNavItems,
    );
  }
  
  // Handle bottom navigation item tap
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

          
          const SizedBox(height: 20),
        ],
      ),
    );
  }
  
  Widget _buildDashboardContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildWeeklySchedule(),
        const SizedBox(height: 20),
        const Text(
          'Upcoming Appointments',
          style: TextStyle(
            fontSize: 18, 
            fontWeight: FontWeight.bold, 
            color: Colors.white
          ),
        ),
        const SizedBox(height: 10),
        _buildAppointmentsList(),
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
              icon: const Icon(Icons.notifications_none),
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
              icon: const Icon(Icons.chat_bubble_outline),
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
      case 1: // Staff Management
        return const StaffManagementScreen();
      case 2: // Schedule Management
        return _buildScheduleManagementContent();
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
        
        // Handle navigation
        switch (index) {
          case 0: // Home
            if (ModalRoute.of(context)?.settings.name != '/floor_manager/home') {
              Navigator.pushReplacementNamed(context, '/floor_manager/home');
            }
            break;
          case 1: // Staff
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const StaffManagementScreen()),
            );
            break;
          case 2: // Schedule
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ClosedDaysScreen()),
            );
            break;
        }
      },
      backgroundColor: Colors.black,
      selectedItemColor: AppColors.gold,
      unselectedItemColor: Colors.grey[600],
      items: _bottomNavItems,
    );
  }
}
