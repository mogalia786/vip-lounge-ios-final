import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/colors.dart';

class FloorManagerHomeScreenClean extends StatefulWidget {
  const FloorManagerHomeScreenClean({Key? key}) : super(key: key);

  @override
  _FloorManagerHomeScreenCleanState createState() => _FloorManagerHomeScreenCleanState();
}

class _FloorManagerHomeScreenCleanState extends State<FloorManagerHomeScreenClean> {
  final TextEditingController _searchController = TextEditingController();
  Map<String, dynamic>? _appointmentData;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Appointment Search'),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black, Color(0xFF1a1a1a)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSearchBar(),
              const SizedBox(height: 20),
              _buildAppointmentDetails(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Card(
      color: Colors.grey[900],
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Search Appointment',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Enter reference number',
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      filled: true,
                      fillColor: Colors.grey[800],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _searchAppointment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.black,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Search',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentDetails() {
    if (_appointmentData == null) {
      return const Center(
        child: Text(
          'Search for an appointment using the reference number',
          style: TextStyle(color: Colors.grey, fontSize: 16),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Expanded(
      child: SingleChildScrollView(
        child: Card(
          color: Colors.grey[900],
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Appointment Details',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildDetailRow(
                  Icons.confirmation_number,
                  'Reference Number',
                  _appointmentData!['referenceNumber'] ?? 'N/A',
                ),
                _buildDetailRow(
                  Icons.person,
                  'Client Name',
                  _appointmentData!['clientName'] ?? 'N/A',
                ),
                _buildDetailRow(
                  Icons.calendar_today,
                  'Date',
                  _formatDate(_appointmentData!['appointmentTime']),
                ),
                _buildDetailRow(
                  Icons.schedule,
                  'Time',
                  _formatTime(_appointmentData!['appointmentTime']),
                ),
                _buildDetailRow(
                  Icons.work,
                  'Service',
                  _appointmentData!['serviceName'] ?? 'N/A',
                ),
                _buildDetailRow(
                  Icons.person_pin,
                  'Consultant',
                  _appointmentData!['consultantName'] ?? 'Not assigned',
                  isImportant: _appointmentData!['consultantName'] == null,
                ),
                _buildDetailRow(
                  Icons.info,
                  'Status',
                  _formatStatus(_appointmentData!['status'] ?? 'pending'),
                  isImportant: true,
                ),
                if (_appointmentData!['notes'] != null &&
                    _appointmentData!['notes'].toString().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Notes:',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _appointmentData!['notes'],
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value,
      {bool isImportant = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: isImportant ? AppColors.gold : Colors.grey[400],
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: isImportant ? AppColors.gold : Colors.white,
                    fontSize: 14,
                    fontWeight: isImportant ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _searchAppointment() async {
    final referenceNumber = _searchController.text.trim();
    
    if (referenceNumber.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a reference number';
        _appointmentData = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .where('referenceNumber', isEqualTo: referenceNumber)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        setState(() {
          _errorMessage = 'No appointment found with this reference number';
          _appointmentData = null;
        });
        return;
      }

      final doc = querySnapshot.docs.first;
      setState(() {
        _appointmentData = {
          ...doc.data(),
          'id': doc.id,
        };
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred. Please try again.';
        _appointmentData = null;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    
    try {
      final date = timestamp is Timestamp 
          ? timestamp.toDate() 
          : DateTime.parse(timestamp.toString());
      return DateFormat('MMMM d, yyyy').format(date);
    } catch (e) {
      return 'Invalid date';
    }
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    
    try {
      final date = timestamp is Timestamp 
          ? timestamp.toDate() 
          : DateTime.parse(timestamp.toString());
      return DateFormat('h:mm a').format(date);
    } catch (e) {
      return 'Invalid time';
    }
  }

  String _formatStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'confirmed':
        return 'Confirmed';
      case 'in_progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }
}
