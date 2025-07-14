import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:vip_lounge/core/providers/app_auth_provider.dart';
import 'package:vip_lounge/core/constants/colors.dart';

class FloorManagerSearchScreen extends StatefulWidget {
  const FloorManagerSearchScreen({Key? key}) : super(key: key);

  @override
  _FloorManagerSearchScreenState createState() => _FloorManagerSearchScreenState();
}

class _FloorManagerSearchScreenState extends State<FloorManagerSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  Map<String, dynamic>? _searchResult;
  bool _searchPerformed = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Appointments'),
        backgroundColor: Colors.black,
        foregroundColor: AppColors.gold,
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/page_bg.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Search by Reference Number',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
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
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    suffixIcon: IconButton(
                      icon: _isSearching
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.gold,
                              ),
                            )
                          : const Icon(Icons.search, color: AppColors.gold),
                      onPressed: _searchAppointment,
                    ),
                  ),
                  onSubmitted: (_) => _searchAppointment(),
                ),
                const SizedBox(height: 24),
                if (_searchPerformed)
                  _searchResult == null
                      ? Expanded(
                          child: Center(
                            child: Text(
                              'No appointment found with this reference number',
                              style: TextStyle(color: Colors.grey, fontSize: 16),
                            ),
                          ),
                        )
                      : _buildAppointmentDetails(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _searchAppointment() async {
    final reference = _searchController.text.trim();
    if (reference.isEmpty) return;

    setState(() {
      _isSearching = true;
      _searchPerformed = true;
    });

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .where('referenceNumber', isEqualTo: reference)
          .limit(1)
          .get();

      if (mounted) {
        setState(() {
          _isSearching = false;
          _searchResult = querySnapshot.docs.isNotEmpty
              ? {
                  ...querySnapshot.docs.first.data(),
                  'id': querySnapshot.docs.first.id,
                }
              : null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _searchResult = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error searching for appointment: $e')),
        );
      }
    }
  }

  Widget _buildAppointmentDetails() {
    if (_searchResult == null) return const SizedBox.shrink();

    final appointment = _searchResult!;
    final dateTime = (appointment['appointmentTime'] as Timestamp).toDate();
    final formattedDate = DateFormat('MMM d, yyyy').format(dateTime);
    final formattedTime = DateFormat('h:mm a').format(dateTime);
    
    return Expanded(
      child: SingleChildScrollView(
        child: Card(
          color: Colors.grey[900],
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Appointment Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.gold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(appointment['status'] ?? '').withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _getStatusText(appointment['status'] ?? '').toUpperCase(),
                        style: TextStyle(
                          color: _getStatusColor(appointment['status'] ?? ''),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildDetailRow(Icons.person, 'Client', appointment['ministerName'] ?? 'N/A'),
                _buildDetailRow(Icons.phone, 'Phone', appointment['ministerPhone'] ?? 'N/A'),
                _buildDetailRow(Icons.calendar_today, 'Date', formattedDate),
                _buildDetailRow(Icons.access_time, 'Time', formattedTime),
                _buildDetailRow(Icons.assignment, 'Service', appointment['serviceName'] ?? 'N/A'),
                if (appointment['consultantName'] != null)
                  _buildDetailRow(Icons.person_outline, 'Consultant', appointment['consultantName']),
                if (appointment['conciergeName'] != null)
                  _buildDetailRow(Icons.support_agent, 'Concierge', appointment['conciergeName']),
                if (appointment['notes']?.toString().isNotEmpty ?? false) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Notes:',
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    appointment['notes'].toString(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[500]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value.isNotEmpty ? value : 'Not specified',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'in progress':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      case 'in progress':
        return 'In Progress';
      case 'confirmed':
        return 'Confirmed';
      default:
        return 'Pending';
    }
  }
}
