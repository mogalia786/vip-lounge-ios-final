import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

class QuerySearchScreen extends StatefulWidget {
  const QuerySearchScreen({Key? key}) : super(key: key);

  @override
  _QuerySearchScreenState createState() => _QuerySearchScreenState();
}

class _QuerySearchScreenState extends State<QuerySearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  Map<String, dynamic>? _queryData;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchQuery() async {
    final referenceNumber = _searchController.text.trim();
    
    if (referenceNumber.isEmpty) {
      setState(() {
        _queryData = null;
        _errorMessage = 'Please enter a reference number';
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
          .where('referenceNumber', isEqualTo: referenceNumber)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        setState(() {
          _queryData = null;
          _errorMessage = 'No query found with reference: $referenceNumber';
        });
        return;
      }

      final queryDoc = querySnapshot.docs.first;
      setState(() {
        _queryData = {'id': queryDoc.id, ...queryDoc.data()};
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error searching: ${e.toString()}';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildContactRow(String label, String? value, {bool isClickable = false}) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          GestureDetector(
            onTap: isClickable 
                ? () => _launchContact(value)
                : null,
            child: Text(
              value,
              style: TextStyle(
                color: isClickable ? Colors.blue : null,
                decoration: isClickable ? TextDecoration.underline : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchContact(String value) async {
    final Uri uri = value.contains('@')
        ? Uri(scheme: 'mailto', path: value)
        : Uri(scheme: 'tel', path: value);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Widget _buildQueryCard() {
    if (_queryData == null) return const SizedBox.shrink();
    
    final query = _queryData!;
    final createdAt = query['createdAt'] is Timestamp 
        ? (query['createdAt'] as Timestamp).toDate()
        : null;
    
    final isResolved = query['status']?.toString().toLowerCase() == 'resolved';
    final isOverdue = !isResolved && 
        createdAt != null && 
        DateTime.now().difference(createdAt) > const Duration(minutes: 30);

    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with reference and status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Ref: ${query['referenceNumber'] ?? 'N/A'}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (isResolved)
                  const Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 20),
                      SizedBox(width: 4),
                      Text('Resolved', style: TextStyle(color: Colors.green)),
                    ],
                  ),
              ],
            ),
            const Divider(),
            
            // Created at
            if (createdAt != null) 
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  'Created: ${DateFormat('yyyy-MM-dd HH:mm').format(createdAt)}',
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ),

            // Overdue warning
            if (isOverdue)
              Container(
                padding: const EdgeInsets.all(8.0),
                margin: const EdgeInsets.only(bottom: 12.0),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(4.0),
                  border: Border.all(color: Colors.orange[200]!), 
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, 
                      color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This query has not been resolved. Please contact user and client.',
                        style: TextStyle(color: Colors.orange[800]),
                      ),
                    ),
                  ],
                ),
              ),

            // Client Information
            const Text(
              'Client Information',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            _buildContactRow('Name', query['clientName']?.toString()),
            _buildContactRow('Email', query['clientEmail']?.toString(), isClickable: true),
            _buildContactRow('Phone', query['clientPhone']?.toString(), isClickable: true),
            const SizedBox(height: 12),

            // Assigned User Information
            const Text(
              'Assigned To',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            _buildContactRow('Name', query['assignedToName']?.toString()),
            _buildContactRow('Email', query['assignedToEmail']?.toString(), isClickable: true),
            _buildContactRow('Phone', query['assignedToPhone']?.toString(), isClickable: true),
            const SizedBox(height: 16),

            // Query Details
            const Text(
              'Query',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(query['query']?.toString() ?? 'No query details available'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Query'),
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Enter Reference Number',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _searchQuery(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _searchQuery,
                  child: const Text('Search'),
                ),
              ],
            ),
          ),
          
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            )
          else
            Expanded(child: _buildQueryCard()),
        ],
      ),
    );
  }
}
