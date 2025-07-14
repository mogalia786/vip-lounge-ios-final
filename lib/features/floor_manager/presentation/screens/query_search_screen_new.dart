import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

// Local colors
class _AppColors {
  static const Color primary = Color(0xFF1E88E5);
  static const Color secondary = Color(0xFF1976D2);
  static const Color accent = Color(0xFF64B5F6);
  static const Color background = Color(0xFFF5F5F5);
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color error = Color(0xFFD32F2F);
  static const Color success = Color(0xFF388E3C);
  static const Color warning = Color(0xFFFFA000);
  static const Color info = Color(0xFF1976D2);
}

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
  bool _isSearching = false;
  String? _errorMessage;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Format date from various possible formats
  DateTime? _parseDate(dynamic date) {
    if (date == null) return null;
    if (date is Timestamp) return date.toDate();
    if (date is Map && date['_seconds'] != null) {
      return DateTime.fromMillisecondsSinceEpoch(
        (date['_seconds'] as int) * 1000,
        isUtc: true,
      ).toLocal();
    }
    if (date is String) return DateTime.tryParse(date)?.toLocal();
    return null;
  }

  // Format status display
  String _formatStatus(String status) {
    if (status == null || status.isEmpty) return 'Pending';
    return status.split('_').map((s) => s[0].toUpperCase() + s.substring(1)).join(' ');
  }

  // Get status color
  Color _getStatusColor(String status) {
    if (status == null) return _AppColors.textSecondary;
    final statusLower = status.toLowerCase();
    if (statusLower.contains('pending')) return _AppColors.warning;
    if (statusLower.contains('progress')) return _AppColors.info;
    if (statusLower.contains('complete') || statusLower.contains('resolved')) {
      return _AppColors.success;
    }
    if (statusLower.contains('reject') || statusLower.contains('cancel')) {
      return _AppColors.error;
    }
    return _AppColors.textSecondary;
  }

  // Launch phone call
  Future<void> _launchPhoneCall(String phone) async {
    if (phone.isEmpty) return;
    final Uri phoneUri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch phone app')),
      );
    }
  }

  // Launch email
  Future<void> _launchEmail(String email) async {
    if (email.isEmpty) return;
    final Uri emailUri = Uri(scheme: 'mailto', path: email);
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch email app')),
      );
    }
  }

  // Search queries by reference number
  Future<void> _searchQueries(String referenceNumber) async {
    if (referenceNumber.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
        _errorMessage = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _isSearching = true;
      _errorMessage = null;
    });

    try {
      // First try to find by reference number (exact match)
      final refNumberQuery = await _firestore
          .collection('queries')
          .where('referenceNumber', isEqualTo: referenceNumber.trim().toUpperCase())
          .limit(1)
          .get();

      // If no results, try to find by name (partial match)
      if (refNumberQuery.docs.isEmpty) {
        final nameQuery = await _firestore
            .collection('queries')
            .where('ministerName', isGreaterThanOrEqualTo: referenceNumber.trim())
            .where('ministerName', isLessThanOrEqualTo: '${referenceNumber.trim()}\uf8ff')
            .limit(10)
            .get();

        if (nameQuery.docs.isNotEmpty) {
          final results = <String, Map<String, dynamic>>{};
          for (var doc in nameQuery.docs) {
            final data = doc.data();
            data['id'] = doc.id;
            results[doc.id] = data;
          }
          setState(() {
            _searchResults = results.values.toList();
          });
        } else {
          setState(() {
            _searchResults = [];
            _errorMessage = 'No queries found with reference or name matching: ${referenceNumber.trim()}';
          });
        }
      } else {
        // Found by reference number
        final queryData = refNumberQuery.docs.first.data();
        queryData['id'] = refNumberQuery.docs.first.id;
        setState(() {
          _searchResults = [queryData];
        });
      }
    } catch (e) {
      debugPrint('Error searching queries: $e');
      setState(() {
        _errorMessage = 'Error searching queries. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Build contact info row with proper null safety and formatting
  Widget _buildContactRow({
    required IconData icon,
    required String label,
    required dynamic value,
    bool isPhone = false,
    bool isEmail = false,
  }) {
    final String displayValue = _getDisplayValue(value);
    if (displayValue.isEmpty) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: _AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: _AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                GestureDetector(
                  onTap: isPhone || isEmail
                      ? () => isPhone
                          ? _launchPhoneCall(displayValue)
                          : _launchEmail(displayValue)
                      : null,
                  child: Text(
                    displayValue,
                    style: TextStyle(
                      fontSize: 14,
                      color: (isPhone || isEmail) 
                          ? _AppColors.primary 
                          : _AppColors.textPrimary,
                      decoration: (isPhone || isEmail)
                          ? TextDecoration.underline
                          : TextDecoration.none,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to safely get display value from dynamic input
  String _getDisplayValue(dynamic value) {
    if (value == null) return '';
    if (value is String) return value.trim();
    if (value is Map) {
      // Handle case where value might be a map with display text
      if (value['name'] != null) return value['name'].toString().trim();
      if (value['text'] != null) return value['text'].toString().trim();
      return value.toString().trim();
    }
    return value.toString().trim();
  }

  // Build status history
  Widget _buildStatusHistory(Map<String, dynamic> query) {
    final List<dynamic>? history = query['statusHistory'] is List
        ? query['statusHistory']
        : null;

    if (history == null || history.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 24),
        const Text(
          'Status History',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: _AppColors.primary,
          ),
        ),
        const SizedBox(height: 8),
        ...history.map<Widget>((entry) {
          final status = entry['status']?.toString() ?? '';
          final timestamp = _parseDate(entry['timestamp']);
          final formattedDate = timestamp != null
              ? DateFormat('MMM d, y • h:mm a').format(timestamp)
              : 'Unknown date';
          
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 6, right: 8),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status),
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatStatus(status),
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        formattedDate,
                        style: const TextStyle(
                          fontSize: 12,
                          color: _AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  // Build query card with all relevant information
  Widget _buildQueryCard(Map<String, dynamic> query) {
    // Parse dates
    final submittedAt = _parseDate(query['submittedAt']);
    final updatedAt = _parseDate(query['updatedAt']);
    
    // Format dates
    final formattedSubmittedDate = submittedAt != null
        ? DateFormat('MMM d, y • h:mm a').format(submittedAt)
        : 'Date not available';
    
    final formattedUpdatedDate = updatedAt != null
        ? DateFormat('MMM d, y • h:mm a').format(updatedAt)
        : null;

    // Get status and theme
    final status = query['status']?.toString().toLowerCase() ?? 'pending';
    final statusColor = _getStatusColor(status);
    final statusText = _formatStatus(status);

    // Get client information (from minister fields)
    final clientName = query['ministerName']?.toString().trim() ?? 'N/A';
    final clientEmail = query['ministerEmail']?.toString().trim();
    final clientPhone = query['ministerPhone']?.toString().trim();

    // Get assigned user information
    final assignedToName = query['assignedToName']?.toString().trim() ?? 'Unassigned';
    final assignedToEmail = query['assignedToEmail']?.toString().trim();
    final assignedToPhone = query['assignedToPhone']?.toString().trim();

    // Get query details
    final referenceNumber = query['referenceNumber']?.toString() ?? 'N/A';
    final description = query['description']?.toString().trim() ?? 'No description provided';
    final category = query['category']?.toString().trim();
    final priority = query['priority']?.toString().toLowerCase() ?? 'normal';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with reference and status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Query #$referenceNumber',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _AppColors.primary,
                        ),
                      ),
                      if (category != null) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            category,
                            style: const TextStyle(
                              color: _AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            
            // Dates section
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow('Submitted', formattedSubmittedDate),
                  if (formattedUpdatedDate != null && status != 'pending')
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: _buildInfoRow('Last Updated', formattedUpdatedDate),
                    ),
                ],
              ),
            ),

            // Priority indicator
            if (priority != 'normal')
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: priority == 'high' 
                      ? Colors.red[50] 
                      : priority == 'medium' 
                          ? Colors.orange[50] 
                          : Colors.blue[50],
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: priority == 'high' 
                        ? Colors.red[100]! 
                        : priority == 'medium' 
                            ? Colors.orange[100]! 
                            : Colors.blue[100]!,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      priority == 'high' 
                          ? Icons.error_outline 
                          : Icons.info_outline,
                      size: 16,
                      color: priority == 'high' 
                          ? Colors.red[600] 
                          : priority == 'medium' 
                              ? Colors.orange[600] 
                              : Colors.blue[600],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Priority: ${priority.toUpperCase()}',
                      style: TextStyle(
                        color: priority == 'high' 
                            ? Colors.red[800] 
                            : priority == 'medium' 
                                ? Colors.orange[800] 
                                : Colors.blue[800],
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

            // Query details section
            _buildSectionHeader('Query Details'),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Text(
                description,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: _AppColors.textPrimary,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Client Information section
            _buildSectionHeader('Client Information'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[100]!),
              ),
              child: Column(
                children: [
                  _buildContactRow(
                    icon: Icons.person_outline,
                    label: 'Name',
                    value: clientName,
                  ),
                  if (clientEmail != null)
                    _buildContactRow(
                      icon: Icons.email_outlined,
                      label: 'Email',
                      value: clientEmail,
                      isEmail: true,
                    ),
                  if (clientPhone != null)
                    _buildContactRow(
                      icon: Icons.phone_outlined,
                      label: 'Phone',
                      value: clientPhone,
                      isPhone: true,
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Assigned To section
            _buildSectionHeader('Assigned To'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[100]!),
              ),
              child: Column(
                children: [
                  _buildContactRow(
                    icon: Icons.person,
                    label: 'Name',
                    value: assignedToName,
                  ),
                  if (assignedToEmail != null)
                    _buildContactRow(
                      icon: Icons.email,
                      label: 'Email',
                      value: assignedToEmail,
                      isEmail: true,
                    ),
                  if (assignedToPhone != null)
                    _buildContactRow(
                      icon: Icons.phone,
                      label: 'Phone',
                      value: assignedToPhone,
                      isPhone: true,
                    ),
                ],
              ),
            ),

            // Status History
            _buildStatusHistory(query),

            // Action Buttons
            if (status != 'in_progress' && 
                status != 'resolved' &&
                status != 'completed') ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _updateStatus(query['id'], 'in_progress'),
                  icon: const Icon(Icons.check_circle_outline, size: 20),
                  label: const Text('Mark as In Progress'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Helper method to build section headers
  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: _AppColors.primary,
        letterSpacing: 0.5,
      ),
    );
  }

  // Helper method to build info rows
  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 13,
            color: _AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: _AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  // Update query status
  Future<void> _updateStatus(String queryId, String newStatus) async {
    if (!mounted) return;
    
    setState(() => _isLoading = true);

    try {
      final now = DateTime.now();
      final statusUpdate = {
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
        'statusHistory': FieldValue.arrayUnion([
          {
            'status': newStatus,
            'timestamp': now,
            'updatedBy': 'system', // TODO: Replace with actual user ID
          },
        ]),
      };

      await _firestore.collection('queries').doc(queryId).update(statusUpdate);

      // Update local state
      setState(() {
        final index = _searchResults.indexWhere((q) => q['id'] == queryId);
        if (index != -1) {
          _searchResults[index]['status'] = newStatus;
          if (_searchResults[index]['statusHistory'] == null) {
            _searchResults[index]['statusHistory'] = [];
          }
          (_searchResults[index]['statusHistory'] as List).add({
            'status': newStatus,
            'timestamp': now,
            'updatedBy': 'system',
          });
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Query status updated'),
            backgroundColor: _AppColors.success,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error updating query status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update query status'),
            backgroundColor: _AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _AppColors.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _AppColors.error.withOpacity(0.3)),
            ),
            child: Row(

    try {
      // Search by reference number
      final refNumberQuery = await _firestore
          .collection('queries')
          .where('referenceNumber', isGreaterThanOrEqualTo: query)
          .where('referenceNumber', isLessThanOrEqualTo: query + '\uf8ff')
          .get();

      // Search by name
      final nameQuery = await _firestore
          .collection('queries')
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThanOrEqualTo: query + '\uf8ff')
          .get();

      // Combine and deduplicate results
      final results = <String, Map<String, dynamic>>{};
      
      for (var doc in [...refNumberQuery.docs, ...nameQuery.docs]) {
        results[doc.id] = {'id': doc.id, ...doc.data()};
      }

      setState(() {
        _searchResults = results.values.toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error searching queries: $e');
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error searching queries')),
        );
      }
    }
  }

  Widget _buildContactInfoRow({
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              child: Text(
                value,
                style: TextStyle(
                  color: onTap != null ? _AppColors.primary : null,
                  decoration: onTap != null ? TextDecoration.underline : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(dynamic status) {
    if (status == null) return Colors.grey;
    
    final statusStr = status.toString().toLowerCase();
    
    switch (statusStr) {
      case 'new':
      case 'pending':
        return Colors.orange;
      case 'in_progress':
      case 'in progress':
        return Colors.blue;
      case 'resolved':
      case 'completed':
      case 'closed':
        return Colors.green;
      case 'rejected':
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _launchEmail(String email) async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: email,
    );
    if (await canLaunchUrl(emailLaunchUri)) {
      await launchUrl(emailLaunchUri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch email')),
      );
    }
  }

  Future<void> _launchPhoneCall(String phone) async {
    final Uri phoneLaunchUri = Uri(
      scheme: 'tel',
      path: phone,
    );
    if (await canLaunchUrl(phoneLaunchUri)) {
      await launchUrl(phoneLaunchUri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch phone')),
      );
    }
  }

  Widget _buildQueryCard(Map<String, dynamic> query) {
    // Handle different timestamp formats
    DateTime? submittedAt;
    if (query['submittedAt'] is Timestamp) {
      submittedAt = (query['submittedAt'] as Timestamp).toDate();
    } else if (query['submittedAt'] is Map && 
              query['submittedAt']?['_seconds'] != null) {
      submittedAt = DateTime.fromMillisecondsSinceEpoch(
        (query['submittedAt']['_seconds'] as int) * 1000,
        isUtc: true,
      ).toLocal();
    } else if (query['submittedAt'] is String) {
      submittedAt = DateTime.tryParse(query['submittedAt'])?.toLocal();
    }

    final formattedDate = submittedAt != null
        ? DateFormat('yyyy-MM-dd HH:mm').format(submittedAt)
        : 'No date';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Ref: ${query['referenceNumber'] ?? 'N/A'}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(query['status']).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    (query['status'] ?? 'pending').toString().toUpperCase(),
                    style: TextStyle(
                      color: _getStatusColor(query['status']),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildContactInfoRow(
              icon: Icons.person,
              label: 'Name',
              value: query['name']?.toString() ?? 'N/A',
            ),
            _buildContactInfoRow(
              icon: Icons.email,
              label: 'Email',
              value: query['email']?.toString() ?? 'N/A',
              onTap: query['email'] != null 
                  ? () => _launchEmail(query['email'].toString())
                  : null,
            ),
            _buildContactInfoRow(
              icon: Icons.phone,
              label: 'Phone',
              value: query['phone']?.toString() ?? 'N/A',
              onTap: query['phone'] != null 
                  ? () => _launchPhoneCall(query['phone'].toString())
                  : null,
            ),
            _buildContactInfoRow(
              icon: Icons.calendar_today,
              label: 'Submitted',
              value: formattedDate,
            ),
            if (query['description']?.toString().isNotEmpty == true) ...[
              const SizedBox(height: 8),
              const Text(
                'Description:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(query['description']),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (!_isSearching) {
      return const Center(
        child: Text('Enter a search term to find queries'),
      );
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchResults.isEmpty) {
      return const Center(
        child: Text('No queries found matching your search'),
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final query = _searchResults[index];
        return _buildQueryCard(query);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Queries'),
        backgroundColor: _AppColors.primary,
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
                hintText: 'Search by reference number or name...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
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
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onSubmitted: _searchQueries,
            ),
          ),
          Expanded(
            child: _buildSearchResults(),
          ),
        ],
      ),
    );
  }
}
