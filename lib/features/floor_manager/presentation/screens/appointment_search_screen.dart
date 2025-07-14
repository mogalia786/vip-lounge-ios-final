import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/colors.dart';

class AppointmentSearchScreen extends StatefulWidget {
  const AppointmentSearchScreen({super.key});

  @override
  _AppointmentSearchScreenState createState() => _AppointmentSearchScreenState();
}

class _AppointmentSearchScreenState extends State<AppointmentSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchAppointments(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _isSearching = true;
    });

    try {
      // First try exact match on booking reference
      final refSnapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .where('bookingReference', isEqualTo: query)
          .get();

      if (refSnapshot.docs.isNotEmpty) {
        setState(() {
          _searchResults = refSnapshot.docs
              .map((doc) => {...doc.data(), 'id': doc.id})
              .toList();
        });
        return;
      }

      // If no exact reference match, search across multiple fields
      final nameSnapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .where('clientName', isGreaterThanOrEqualTo: query)
          .where('clientName', isLessThanOrEqualTo: '$query\uf8ff')
          .get();

      final emailSnapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .where('clientEmail', isGreaterThanOrEqualTo: query)
          .where('clientEmail', isLessThanOrEqualTo: '$query\uf8ff')
          .get();

      // For phone, we'll do exact match as phone numbers should be exact
      final phoneSnapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .where('clientPhone', isEqualTo: query)
          .get();

      // Combine all results and remove duplicates by ID
      final allResults = [
        ...nameSnapshot.docs,
        ...emailSnapshot.docs,
        ...phoneSnapshot.docs,
      ];

      final uniqueResults = <String, DocumentSnapshot>{};
      for (var doc in allResults) {
        uniqueResults[doc.id] = doc;
      }

      setState(() {
        _searchResults = uniqueResults.values
            .map((doc) => {...doc.data() as Map<String, dynamic>, 'id': doc.id})
            .toList();
      });
    } catch (e) {
      debugPrint('Error searching appointments: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error searching appointments')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Appointments'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by reference, name, email or phone',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _isSearching
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchResults = [];
                            _isSearching = false;
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
              ),
              onSubmitted: _searchAppointments,
            ),
          ),
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildSearchResults(),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (!_isSearching) {
      return const Center(
        child: Text('Enter a reference number or client name to search'),
      );
    }

    if (_searchResults.isEmpty) {
      return const Center(child: Text('No appointments found'));
    }

    return Expanded(
      child: ListView.builder(
        itemCount: _searchResults.length,
        itemBuilder: (context, index) {
          final appointment = _searchResults[index];
          return _buildAppointmentCard(appointment);
        },
      ),
    );
  }

  Widget _buildAppointmentCard(Map<String, dynamic> appointment) {
    final date = appointment['appointmentTime'] != null
        ? (appointment['appointmentTime'] as Timestamp).toDate()
        : null;
    final formattedDate = date != null
        ? DateFormat('EEE, MMM d, y • h:mm a').format(date)
        : 'No date';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  appointment['ministerName'] ?? 'No Name',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(appointment['status'] ?? '').withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _getStatusColor(appointment['status'] ?? ''),
                    ),
                  ),
                  child: Text(
                    _getStatusText(appointment['status'] ?? ''),
                    style: TextStyle(
                      color: _getStatusColor(appointment['status'] ?? ''),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Ref: ${appointment['bookingReference'] ?? 'N/A'}',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text('Date: $formattedDate'),
            if (appointment['notes'] != null &&
                appointment['notes'].toString().isNotEmpty) ...{
              const SizedBox(height: 8),
              const Text(
                'Notes:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(appointment['notes']),
            },
            if (appointment['consultantName'] != null) ...{
              const SizedBox(height: 8),
              Text('Consultant: ${appointment['consultantName']}'),
            },
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'rescheduled':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return 'Confirmed';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      case 'rescheduled':
        return 'Rescheduled';
      default:
        return 'Pending';
    }
  }
}
