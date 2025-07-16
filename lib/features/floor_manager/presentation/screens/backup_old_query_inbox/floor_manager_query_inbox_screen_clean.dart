import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:vip_lounge/core/constants/colors.dart';

class QueryInboxScreen extends StatefulWidget {
  const QueryInboxScreen({Key? key}) : super(key: key);

  @override
  _QueryInboxScreenState createState() => _QueryInboxScreenState();
}

class _QueryInboxScreenState extends State<QueryInboxScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _queries = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchQueries();
  }

  Future<void> _fetchQueries() async {
    try {
      setState(() => _isLoading = true);
      
      final snapshot = await _firestore
          .collection('queries')
          .orderBy('createdAt', descending: true)
          .get();

      setState(() {
        _queries = snapshot.docs
            .map((doc) => doc.data()..['id'] = doc.id)
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load queries: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'new':
        return Colors.blue;
      case 'in_progress':
        return Colors.orange;
      case 'resolved':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  bool _isQueryOverdue(Map<String, dynamic> query) {
    final createdAt = (query['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    return difference.inMinutes > 30 && query['status']?.toString().toLowerCase() != 'resolved';
  }

  Widget _buildQueryItem(Map<String, dynamic> query) {
    final isOverdue = _isQueryOverdue(query);
    final status = (query['status'] ?? 'new').toString();
    final createdAt = (query['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final formattedDate = DateFormat('MMM d, yyyy hh:mm a').format(createdAt);
    final referenceNumber = query['referenceNumber'] ?? 'N/A';
    final assignedToName = query['assignedToName'] ?? 'Unassigned';
    final assignedToEmail = query['assignedToEmail'] ?? '';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: InkWell(
        onTap: () => _showQueryDetails(context, query),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row with reference and status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '#$referenceNumber',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        color: _getStatusColor(status),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Query subject
              Text(
                query['subject'] ?? 'No subject',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              
              // Assigned to section
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Assigned to: $assignedToName',
                          style: TextStyle(
                            fontSize: 14,
                            color: isOverdue ? Colors.orange.shade800 : Colors.grey,
                            fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        if (assignedToEmail.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            assignedToEmail,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              
              // Date and time
              Row(
                children: [
                  const Icon(Icons.access_time, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    formattedDate,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              
              // Overdue warning
              if (isOverdue) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange),
                    const SizedBox(width: 4),
                    Text(
                      'Overdue - More than 30 minutes without resolution',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showQueryDetails(BuildContext context, Map<String, dynamic> query) {
    final status = (query['status'] ?? 'new').toString();
    final createdAt = (query['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final formattedDate = DateFormat('MMM d, yyyy hh:mm a').format(createdAt);
    final assignedDate = (query['assignedAt'] as Timestamp?)?.toDate();
    final assignedToName = query['assignedToName'] ?? 'Unassigned';
    final assignedToEmail = query['assignedToEmail'] ?? '';
    final isOverdue = _isQueryOverdue(query);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Query #${query['referenceNumber'] ?? 'N/A'}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Status
              Row(
                children: [
                  const Text('Status: ', style: TextStyle(fontWeight: FontWeight.bold)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        color: _getStatusColor(status),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Subject
              const Text('Subject:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(query['subject'] ?? 'No subject'),
              const SizedBox(height: 12),
              
              // Description
              const Text('Description:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(query['description'] ?? 'No description provided'),
              const SizedBox(height: 12),
              
              // Dates
              const Text('Timing:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('Created: $formattedDate'),
              if (assignedDate != null) ...[
                Text('Assigned: ${DateFormat('MMM d, yyyy hh:mm a').format(assignedDate)}'),
              ],
              const SizedBox(height: 12),
              
              // Assigned to
              const Text('Assigned To:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(assignedToName),
              if (assignedToEmail.isNotEmpty) Text(assignedToEmail),
              
              // Overdue warning
              if (isOverdue) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'This query is overdue. It has been more than 30 minutes without resolution.',
                        style: TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Query Inbox'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchQueries,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.red)))
              : _queries.isEmpty
                  ? const Center(child: Text('No queries found'))
                  : ListView.builder(
                      itemCount: _queries.length,
                      itemBuilder: (context, index) => _buildQueryItem(_queries[index]),
                    ),
      floatingActionButton: FloatingActionButton(
        onPressed: _fetchQueries,
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
