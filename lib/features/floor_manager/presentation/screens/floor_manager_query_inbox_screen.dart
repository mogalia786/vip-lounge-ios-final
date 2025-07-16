import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:vip_lounge/core/constants/colors.dart';
import 'package:vip_lounge/features/floor_manager/presentation/screens/assign_staff_to_query_screen.dart';

class FloorManagerQueryInboxScreen extends StatefulWidget {
  const FloorManagerQueryInboxScreen({Key? key}) : super(key: key);

  @override
  State<FloorManagerQueryInboxScreen> createState() => _FloorManagerQueryInboxScreenState();
}

class _FloorManagerQueryInboxScreenState extends State<FloorManagerQueryInboxScreen> {
  DateTimeRange? _selectedRange;
  bool _isLoading = false;
  List<Map<String, dynamic>> _queries = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedRange = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: now,
    );
    _fetchQueries();
  }

  Future<void> _fetchQueries() async {
    setState(() => _isLoading = true);
    try {
      Query query = FirebaseFirestore.instance
          .collection('queries')
          .orderBy('createdAt', descending: true);
          
      if (_selectedRange != null) {
        final start = Timestamp.fromDate(_selectedRange!.start);
        final end = Timestamp.fromDate(_selectedRange!.end.add(const Duration(days: 1)));
        query = query
            .where('createdAt', isGreaterThanOrEqualTo: start)
            .where('createdAt', isLessThan: end);
      }
      
      final snapshot = await query.get();
      
      setState(() {
        _queries = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {...data, 'id': doc.id};
        }).toList();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error loading queries')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Map<String, List<Map<String, dynamic>>> _groupByStaff(List<Map<String, dynamic>> queries) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    
    // First add unassigned queries
    final unassigned = queries.where((q) => 
      q['assignedToName'] == null || 
      q['assignedToName'].toString().isEmpty ||
      q['status']?.toString().toLowerCase() == 'unassigned' ||
      q['status']?.toString().toLowerCase() == 'new'
    ).toList();
    
    // Sort unassigned by creation date (newest first)
    unassigned.sort((a, b) {
      final aTime = a['createdAt'] is Timestamp 
          ? (a['createdAt'] as Timestamp).toDate() 
          : DateTime.now();
      final bTime = b['createdAt'] is Timestamp 
          ? (b['createdAt'] as Timestamp).toDate() 
          : DateTime.now();
      return bTime.compareTo(aTime);
    });
    
    if (unassigned.isNotEmpty) {
      grouped['Unassigned'] = unassigned;
    }
    
    // Group assigned queries by staff
    final assignedQueries = queries.where((q) => 
      q['assignedToName'] != null && 
      q['assignedToName'].toString().isNotEmpty &&
      q['status']?.toString().toLowerCase() != 'unassigned' &&
      q['status']?.toString().toLowerCase() != 'new'
    ).toList();
    
    // Sort assigned queries by staff name and then by creation date (newest first)
    assignedQueries.sort((a, b) {
      final staffCompare = (a['assignedToName'] ?? '').compareTo(b['assignedToName'] ?? '');
      if (staffCompare != 0) return staffCompare;
      
      final aTime = a['createdAt'] is Timestamp 
          ? (a['createdAt'] as Timestamp).toDate() 
          : DateTime.now();
      final bTime = b['createdAt'] is Timestamp 
          ? (b['createdAt'] as Timestamp).toDate() 
          : DateTime.now();
      return bTime.compareTo(aTime);
    });
    
    // Group by staff member
    for (var q in assignedQueries) {
      final staff = q['assignedToName'];
      grouped.putIfAbsent(staff, () => []).add(q);
    }
    
    return grouped;
  }

  List<Map<String, dynamic>> _getTopStaff(List<Map<String, dynamic>> queries) {
    final Map<String, int> staffCount = {};
    for (var q in queries) {
      final staff = q['assignedToName'] ?? 'Unassigned';
      if (staff == 'Unassigned') continue;
      staffCount[staff] = (staffCount[staff] ?? 0) + 1;
    }
    final sorted = staffCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.map((e) => {'name': e.key, 'count': e.value}).toList();
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'new':
      case 'unassigned':
        return Colors.orange;
      case 'in progress':
      case 'assigned':
        return Colors.blue;
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

  bool _isQueryOverdue(Map<String, dynamic> query) {
    if (query['createdAt'] == null) return false;
    
    final createdAt = query['createdAt'] is Timestamp 
        ? (query['createdAt'] as Timestamp).toDate()
        : DateTime.now();
    final now = DateTime.now();
    final difference = now.difference(createdAt).inMinutes;
    
    // If status is not resolved and it's been more than 30 minutes since creation
    return query['status']?.toString().toLowerCase() != 'resolved' && 
           query['status']?.toString().toLowerCase() != 'completed' &&
           difference > 30;
  }
  
  String _getOverdueTime(Map<String, dynamic> query) {
    if (query['createdAt'] == null) return '';
    
    final createdAt = query['createdAt'] is Timestamp 
        ? (query['createdAt'] as Timestamp).toDate()
        : DateTime.now();
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ${difference.inHours % 24}h';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ${difference.inMinutes % 60}m';
    } else {
      return '${difference.inMinutes}m';
    }
  }

  Widget _buildQueryItem(Map<String, dynamic> query) {
    final ministerName = query['ministerName'] ?? '${query['ministerFirstName'] ?? ''} ${query['ministerLastName'] ?? ''}'.trim();
    final queryText = query['query'] ?? query['uery'] ?? 'No query text';
    final status = query['status']?.toString().toLowerCase() ?? 'new';
    final isAssigned = status != 'new' && status != 'unassigned' && query['assignedToId'] != null;
    final assignedToName = query['assignedToName'] ?? '';
    final referenceNumber = query['referenceNumber'] ?? 'N/A';
    final createdAt = query['createdAt'] is Timestamp 
        ? (query['createdAt'] as Timestamp).toDate() 
        : DateTime.now();
    final formattedDate = DateFormat('MMM d, y hh:mm a').format(createdAt);
    final isOverdue = _isQueryOverdue(query);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.red.shade700, width: 1.5),
      ),
      color: const Color(0xFF0A1E3C), // Dark blue background
      child: InkWell(
        onTap: () {
          if (!isAssigned) {
            // Navigate to assign staff screen for unassigned queries
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AssignStaffToQueryScreen(
                  query: Map<String, dynamic>.from(query)..['id'] = query['id'] ?? (query['documentID'] ?? query['id']),
                ),
              ),
            ).then((assigned) {
              if (assigned == true) {
                // Refresh the query list if a staff member was assigned
                _fetchQueries();
              }
            });
          } else {
            // Show query details for assigned queries
            _showQueryDetails(context, query);
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity, // Ensure full width
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Reference number and status row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Ref: $referenceNumber',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white, // White text for better contrast
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _getStatusColor(status)),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        color: _getStatusColor(status),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Minister name and date
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 16, color: Colors.white70),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ministerName.isNotEmpty ? ministerName : 'No name provided',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white, // White text for better contrast
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              
              // Query preview
              Text(
                'Query: $queryText',
                style: const TextStyle(
                  fontSize: 14, 
                  color: Colors.white70, // Lighter text for better contrast
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              
              // Assigned to and date
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person, size: 14, color: Colors.white70),
                      const SizedBox(width: 4),
                      Text(
                        isAssigned ? 'Assigned to: $assignedToName' : 'Unassigned',
                        style: TextStyle(
                          fontSize: 12,
                          color: isAssigned ? Colors.white70 : Colors.orange[400],
                          fontWeight: isAssigned ? FontWeight.normal : FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    formattedDate,
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
              
              // Overdue indicator - show warning if query is overdue (30+ minutes since creation)
              if (_isQueryOverdue(query))
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red[900]?.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.red, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 18, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        'OVERDUE (${_getOverdueTime(query)})',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showQueryDetails(BuildContext context, Map<String, dynamic> query) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Query Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Reference', query['referenceNumber'] ?? 'N/A'),
              _buildDetailRow('Minister', query['ministerName'] ?? 'N/A'),
              _buildDetailRow('Email', query['ministerEmail'] ?? 'N/A'),
              _buildDetailRow('Phone', query['ministerPhone'] ?? query['ministerPhoneNumber'] ?? 'N/A'),
              _buildDetailRow('Query', query['query'] ?? query['uery'] ?? 'No details'),
              _buildDetailRow('Status', query['status']?.toString().toUpperCase() ?? 'UNKNOWN'),
              _buildDetailRow('Assigned To', query['assignedToName'] ?? 'Unassigned'),
              _buildDetailRow('Created', 
                query['createdAt'] is Timestamp 
                  ? DateFormat('MMM d, y hh:mm a').format((query['createdAt'] as Timestamp).toDate())
                  : 'N/A'
              ),
              if (query['assignedAt'] != null)
                _buildDetailRow('Assigned', 
                  query['assignedAt'] is Timestamp 
                    ? DateFormat('MMM d, y hh:mm a').format((query['assignedAt'] as Timestamp).toDate())
                    : 'N/A'
                ),
              if (_isQueryOverdue(query))
                _buildDetailRow('Status', 'OVERDUE', isError: true),
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

  Widget _buildDetailRow(String label, String value, {bool isError = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: isError ? Colors.red : Colors.black87,
              fontSize: 15,
              fontWeight: isError ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupedQueries = _groupByStaff(_queries);
    final topStaff = _getTopStaff(_queries);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Query Inbox'),
        backgroundColor: AppColors.black,
        foregroundColor: AppColors.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range, color: AppColors.primary),
            onPressed: () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2023, 1),
                lastDate: DateTime.now(),
                initialDateRange: _selectedRange,
              );
              
              if (picked != null) {
                setState(() => _selectedRange = picked);
                _fetchQueries();
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Top performers section
                if (topStaff.isNotEmpty)
                  Card(
                    margin: const EdgeInsets.all(16),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Top Performing Staff',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: topStaff.take(5).map((staff) {
                                return Container(
                                  margin: const EdgeInsets.only(right: 12),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: AppColors.primary),
                                  ),
                                  child: Text(
                                    '${staff['name']}: ${staff['count']}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                
                // Queries list
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    children: groupedQueries.entries.map((entry) {
                      final staff = entry.key;
                      final queries = entry.value;
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Staff header
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: staff == 'Unassigned' 
                                    ? Colors.orange[50] 
                                    : AppColors.primary.withOpacity(0.1),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(12),
                                  topRight: Radius.circular(12),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    staff,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: staff == 'Unassigned' 
                                          ? Colors.orange[800] 
                                          : AppColors.primary,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: staff == 'Unassigned' 
                                          ? Colors.orange.withOpacity(0.2) 
                                          : AppColors.primary.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${queries.length} ${queries.length == 1 ? 'Query' : 'Queries' }',
                                      style: TextStyle(
                                        color: staff == 'Unassigned' 
                                            ? Colors.orange[800] 
                                            : AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            // Queries list
                            ...queries.map((q) => _buildQueryItem(q)).toList(),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
    );
  }
}
