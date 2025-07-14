import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:vip_lounge/core/constants/colors.dart';
import 'package:vip_lounge/core/providers/app_auth_provider.dart';

class FloorManagerHomeScreenNew extends StatefulWidget {
  const FloorManagerHomeScreenNew({super.key});

  @override
  State<FloorManagerHomeScreenNew> createState() => _FloorManagerHomeScreenNewState();
}

class _FloorManagerHomeScreenNewState extends State<FloorManagerHomeScreenNew> {
  int _selectedIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  Map<String, dynamic>? _searchResult;
  bool _isSearching = false;
  bool _hasSearched = false;
  bool _isLoading = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Add search functionality
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
          _hasSearched = true;
        });
      } else {
        setState(() {
          _searchResult = null;
          _hasSearched = true;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No appointment found with this reference number')),
          );
        }
      }
    } catch (e) {
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
              hintText: 'Enter booking reference',
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
    if (_searchResult == null) {
      return const Center(
        child: Text('No appointment found'),
      );
    }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Floor Manager'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // Show search dialog or implement search functionality
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Search Appointments'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Enter booking reference',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16.0),
                      if (_isSearching)
                        const CircularProgressIndicator()
                      else
                        ElevatedButton(
                          onPressed: _searchAppointment,
                          child: const Text('Search'),
                        ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildMainContent(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
            // Add your navigation logic here
            switch (index) {
              case 0:
                // Home
                break;
              case 1:
                // Appointments
                break;
              case 2:
                // Staff
                break;
              case 3:
                // Notifications
                break;
              case 4:
                // Inbox
                break;
              case 5:
                // Register
                break;
            }
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Appointments',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Staff',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'Notifications',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inbox),
            label: 'Inbox',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_add),
            label: 'Register',
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return Column(
      children: [
        // Your existing content here
        const SizedBox(height: 20),
        const Text('Floor Manager Dashboard', style: TextStyle(fontSize: 24)),
        const SizedBox(height: 20),
        
        // Add search bar
        _buildSearchBar(),
        
        // Show search results if available
        if (_hasSearched && _searchResult != null)
          Expanded(child: _buildAppointmentDetails()),
      ],
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
