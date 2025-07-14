import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class QuerySearchScreen extends StatefulWidget {
  const QuerySearchScreen({Key? key}) : super(key: key);

  @override
  _QuerySearchScreenState createState() => _QuerySearchScreenState();
}

class _QuerySearchScreenState extends State<QuerySearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchQueries(String referenceNumber) async {
    if (referenceNumber.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _errorMessage = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final querySnapshot = await _firestore
          .collection('queries')
          .where('referenceNumber', isEqualTo: referenceNumber.trim().toUpperCase())
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final queryData = querySnapshot.docs.first.data();
        queryData['id'] = querySnapshot.docs.first.id;
        
        // Debug: Print all available fields in the document
        print('Query document fields:');
        queryData.forEach((key, value) {
          print('$key: $value (${value.runtimeType})');
        });
        
        setState(() {
          _searchResults = [queryData];
        });
      } else {
        setState(() {
          _searchResults = [];
          _errorMessage = 'No queries found with reference #${referenceNumber.trim()}';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error searching queries. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Build a timeline item for status history
  Widget _buildTimelineItem(String status, DateTime timestamp, bool isFirst, bool isLast) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline line
        Column(
          children: [
            // Top connector (hidden for first item)
            if (!isFirst) Container(
              width: 1.5,
              height: 20,
              color: Colors.grey[400],
            ),
            // Dot
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: _getStatusColor(status),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
            // Bottom connector (hidden for last item)
            if (!isLast) Container(
              width: 1.5,
              height: 20,
              color: Colors.grey[400],
            ),
          ],
        ),
        const SizedBox(width: 12),
        // Status and timestamp
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formatStatus(status),
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              Text(
                DateFormat('MMM d, y • h:mm a').format(timestamp),
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
              if (!isLast) const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }

  // Helper to format status for display
  String _formatStatus(String status) {
    // Convert camelCase to Title Case
    String result = status.replaceAllMapped(
      RegExp(r'^([a-z])|([A-Z][a-z]+)'),
      (Match m) => '${m[0]?[0].toUpperCase()}${m[0]?.substring(1) ?? ''} ',
    ).trim();
    return result;
  }

  // Helper to get color based on status
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'new':
      case 'created':
        return Colors.blue;
      case 'in progress':
      case 'processing':
        return Colors.orange;
      case 'resolved':
      case 'completed':
        return Colors.green;
      case 'rejected':
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // Build the status history section
  Widget _buildStatusHistory(Map<String, dynamic> query) {
    // Try different possible field names for status history
    final statusHistory = (query['statusHistory'] ?? 
                         query['history'] ?? 
                         query['statusChanges'] ?? 
                         []) as List<dynamic>;
    
    // If no history, show a message
    if (statusHistory.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: Text(
          'No status history available',
          style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
        ),
      );
    }

    // Convert history to a list of maps and sort by timestamp
    final sortedHistory = statusHistory.map((item) {
      if (item is Map<String, dynamic>) {
        return item;
      } else if (item is Map) {
        return Map<String, dynamic>.from(item);
      }
      return <String, dynamic>{};
    }).where((item) => item['status'] != null && item['timestamp'] != null).toList()
      ..sort((a, b) => (b['timestamp'] as Timestamp).compareTo(a['timestamp'] as Timestamp));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Status History',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...List.generate(sortedHistory.length, (index) {
          final item = sortedHistory[index];
          final timestamp = (item['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
          final status = item['status']?.toString() ?? '';
          final changedBy = item['changedBy']?.toString() ?? 'System';
          
          return _buildTimelineItem(
            status,
            timestamp,
            index == 0,
            index == sortedHistory.length - 1,
          );
        }),
      ],
    );
  }

  Widget _buildQueryCard(Map<String, dynamic> query) {
    // Debug: Print the query data being used to build the card
    print('Building card with query data: $query');
    
    // Get the minister info - check multiple possible field names
    final ministerName = query['ministerName'] ?? 
                        '${query['MinisterFirstname'] ?? ''} ${query['MinisterLastname'] ?? ''}'.trim();
    final ministerEmail = query['ministerEmail'] ?? query['MinisterEmail'];
    final ministerPhone = query['ministerPhone'] ?? query['MinisterPhone'] ?? query['ministerPhoneNumber'];
    
    // Get assigned user info - check multiple possible field names
    final assignedToName = query['assignedToName'] ?? 
                          '${query['assignedToFirstName'] ?? ''} ${query['assignedToLastName'] ?? ''}'.trim();
    final assignedToEmail = query['assignedToEmail'] ?? query['assignedToEmail'];
    final assignedToPhone = query['assignedToPhone'] ?? query['assignedToPhoneNumber'];
    
    // Get description from 'uery' field (without the 'q' as per user specification)
    final description = query['uery'] ?? 
                       query['query'] ?? 
                       query['description'] ?? 
                       query['queryDescription'] ?? 
                       query['Description'] ?? 
                       query['details'] ?? 
                       query['queryDetails'] ?? 
                       'No description provided';
    
    // Debug: Print all available fields to help with troubleshooting
    print('Available fields in query document:');
    query.forEach((key, value) {
      print('$key: $value');
    });
    
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Query #${query['referenceNumber'] ?? 'N/A'}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Status: ${query['status'] ?? 'Pending'}',
              style: const TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            if (description != null && description.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'DESCRIPTION',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: Colors.grey,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14.0),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(10.0),
                  border: Border.all(color: Colors.blue[100]!),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Colors.blueGrey[800],
                  ),
                ),
              ),
            ] else 
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 14.0),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(10.0),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: const Text(
                  'No description available',
                  style: TextStyle(
                    fontStyle: FontStyle.italic, 
                    color: Colors.grey,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            const Text(
              'Client Information:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            if (ministerName.isNotEmpty) Text('Name: $ministerName'),
            if (ministerEmail != null && ministerEmail.isNotEmpty) 
              Text('Email: $ministerEmail'),
            if (ministerPhone != null && ministerPhone.isNotEmpty)
              Text('Phone: $ministerPhone'),
            const SizedBox(height: 16),
            const Text(
              'Assigned To:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            if (assignedToName.isNotEmpty) 
              Text('Name: $assignedToName'),
            if (assignedToEmail != null && assignedToEmail.isNotEmpty)
              Text('Email: $assignedToEmail'),
            if (assignedToPhone != null && assignedToPhone.isNotEmpty)
              Text('Phone: $assignedToPhone'),
            
            // Add status history section
            const SizedBox(height: 24),
            _buildStatusHistory(query),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_rounded, size: 28.0, color: Colors.white),
            const SizedBox(width: 12.0),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Query Search', 
                  style: TextStyle(
                    fontSize: 18.0, 
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 0.5
                  ),
                ),
                Text(
                  'Search by reference number', 
                  style: TextStyle(
                    fontSize: 12.0,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: Theme.of(context).primaryColor,
        centerTitle: false,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Enter reference number...',
                border: const OutlineInputBorder(),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchResults = [];
                          });
                        },
                      )
                    : null,
              ),
              onSubmitted: _searchQueries,
            ),
          ),
          if (_isLoading) const CircularProgressIndicator(),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          if (_searchResults.isEmpty && !_isLoading && _searchController.text.isNotEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('No queries found'),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                return _buildQueryCard(_searchResults[index]);
              },
            ),
          ),
        ],
      ),
    );
  }
}