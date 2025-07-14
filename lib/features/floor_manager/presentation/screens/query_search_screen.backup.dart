import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';

// Local colors since we can't access AppColors
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
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  
  // In-memory cache for user data to avoid repeated Firestore lookups
  final Map<String, Map<String, dynamic>> _userCache = {};
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;
  bool _isSearching = false;

  // Initialize Firestore instance
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );
    
    await _flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  // Simplified notification sending without NotificationService
  Future<void> _sendFCMToUser({
    required String userId,
    required String title,
    required String body,
    required Map<String, dynamic> data,
    String? messageType,
  }) async {
    try {
      // In a real app, you would send an HTTP request to your FCM endpoint here
      debugPrint('Sending FCM to user $userId: $title - $body');
      debugPrint('FCM data: $data');
    } catch (e) {
      debugPrint('Error sending FCM: $e');
    }
  }
  
  // Simplified notification creation without NotificationService
  Future<void> _createNotification({
    required String title,
    required String body,
    required Map<String, dynamic> data,
    String? role,
    String? assignedToId,
    String? notificationType,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'title': title,
        'body': body,
        'data': data,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
        'userId': assignedToId,
        'role': role,
        'type': notificationType,
      });
    } catch (e) {
      debugPrint('Error creating notification: $e');
    }
  }

  Future<void> _searchQueries(String query) async {
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
      final snapshot = await FirebaseFirestore.instance
          .collection('queries')
          .where('referenceNumber', isEqualTo: query)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final queryData = snapshot.docs.first.data();
        queryData['id'] = snapshot.docs.first.id;
        setState(() {
          _searchResults = [queryData];
        });
        _checkAndNotifyIfOverdue(queryData);
      } else {
        setState(() {
          _searchResults = [];
        });
      }
    } catch (e) {
      debugPrint('Error searching queries: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error searching queries')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _checkAndNotifyIfOverdue(Map<String, dynamic> query) {
    final submittedAt = query['submittedAt'] is Timestamp 
        ? (query['submittedAt'] as Timestamp).toDate() 
        : (query['submittedAt'] as DateTime?);
        
    if (submittedAt == null) return;

    final now = DateTime.now();
    final queryAge = now.difference(submittedAt);
    final isOverdue = queryAge.inMinutes > 30;

    if (isOverdue && query['overdueNotificationSent'] != true) {
      _sendOverdueNotification(query);
    }
  }

  Future<void> _sendOverdueNotification(Map<String, dynamic> query) async {
    final assignedTo = query['assignedToId'];
    if (assignedTo == null) return;

    try {
      // Update query to mark notification as sent
      await _firestore
          .collection('queries')
          .doc(query['id'])
          .update({'overdueNotificationSent': true});

      // Get user's data
      final userDoc = await _firestore
          .collection('users')
          .doc(assignedTo)
          .get();
          
      final userData = userDoc.data();
      if (userData == null) return;
      
      final userName = userData['name'] ?? 'Staff';
      final referenceNumber = query['referenceNumber']?.toString() ?? 'N/A';
      final message = 'Query #$referenceNumber is overdue for resolution';

      // Send FCM notification for overdue query
      await _sendFCMToUser(
        userId: assignedTo,
        title: 'Overdue Query',
        body: message,
        data: {
          'type': 'overdue_query',
          'queryId': query['id'].toString(),
          'referenceNumber': referenceNumber,
          'title': 'Overdue Query',
          'message': message,
          'timestamp': DateTime.now().toIso8601String(),
        },
        messageType: 'overdue_query',
      );
      
      // Also create a notification in the database
      await _createNotification(
        title: 'Overdue Query',
        body: message,
        data: {
          'type': 'overdue_query',
          'queryId': query['id'].toString(),
          'referenceNumber': referenceNumber,
          'assignedToId': assignedTo,
          'assignedToName': userName,
          'status': 'overdue',
        },
        role: 'floor_manager',
        assignedToId: assignedTo,
        notificationType: 'overdue_query',
      );
    } catch (e) {
      debugPrint('Error in _sendOverdueNotification: $e');
    }

    // Show local notification
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'overdue_queries',
      'Overdue Queries',
      channelDescription: 'Notifications for overdue queries',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: false,
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _flutterLocalNotificationsPlugin.show(
      0,
      'Overdue Query',
      'Query #${query['referenceNumber']} is overdue for resolution',
      platformChannelSpecifics,
      payload: 'query_${query['id']}',
    );
  }

  Future<void> _launchEmail(String email) async {
    try {
      final Uri emailLaunchUri = Uri(
        scheme: 'mailto',
        path: email,
      );
      if (await canLaunchUrl(emailLaunchUri)) {
        await launchUrl(emailLaunchUri);
      }
    } catch (e) {
      debugPrint('Error launching email: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch email')),
        );
      }
    }
  }

  Future<void> _launchPhoneCall(String phone) async {
    try {
      final Uri phoneLaunchUri = Uri(
        scheme: 'tel',
        path: phone,
      );
      if (await canLaunchUrl(phoneLaunchUri)) {
        await launchUrl(phoneLaunchUri);
      }
    } catch (e) {
      debugPrint('Error launching phone call: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch phone')),
        );
      }
    }
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
                hintText: 'Search by reference number',
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
                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              ),
              onSubmitted: _searchQueries,
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  // Contact info row widget
  // Contact info row widget as a method
  // Helper method to build a contact info row with icon, label, and value
  Widget _buildContactInfoRow({
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          GestureDetector(
            onTap: onTap,
            child: Text(
              value,
              style: TextStyle(
                color: onTap != null ? _AppColors.primary : null,
                decoration: onTap != null ? TextDecoration.underline : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (!_isSearching) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Enter a reference number to search for queries',
            style: TextStyle(fontSize: 16, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'No queries found with that reference number',
            style: TextStyle(fontSize: 16, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16.0),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        return _buildQueryCard(_searchResults[index]);
      },
    );
  }

  Widget _buildQueryCard(Map<String, dynamic> query) {
    // Handle different timestamp formats
    DateTime? submittedAt;
    if (query['submittedAt'] is Timestamp) {
      submittedAt = (query['submittedAt'] as Timestamp).toDate();
    } else if (query['submittedAt'] is Map && query['submittedAt']?['_seconds'] != null) {
      // Handle Firestore timestamp in map format
      submittedAt = DateTime.fromMillisecondsSinceEpoch(
        (query['submittedAt']['_seconds'] as int) * 1000,
        isUtc: true,
      ).toLocal();
    } else if (query['submittedAt'] is String) {
      // Handle ISO 8601 string format
      submittedAt = DateTime.tryParse(query['submittedAt'])?.toLocal();
    }
        
    final formattedDate = submittedAt != null
        ? DateFormat('yyyy-MM-dd HH:mm').format(submittedAt)
        : 'No date';

    final now = DateTime.now();
    final queryAge = submittedAt != null ? now.difference(submittedAt) : null;
    final isOverdue = queryAge != null && queryAge.inMinutes > 30;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with reference number and date
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'Query #${query['referenceNumber'] ?? 'N/A'}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  'Submitted: $formattedDate',
                  style: const TextStyle(
                    color: Colors.blue,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),

            // Overdue warning
            if (isOverdue) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'QUERY NOT RESOLVED PROMPTLY',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Status chip
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getStatusColor(query['status'] ?? 'Pending').withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _getStatusColor(query['status'] ?? 'Pending')),
              ),
              child: Text(
                'Status: ${query['status'] ?? 'Pending'}',
                style: TextStyle(
                  color: _getStatusColor(query['status'] ?? 'Pending'),
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),

            // Query details
            const SizedBox(height: 16),
            const Text(
              'Query Details:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              query['description']?.toString().trim() ?? 'No description provided',
              style: const TextStyle(fontSize: 15, height: 1.4),
            ),

            // Client details
            const SizedBox(height: 16),
            FutureBuilder<DocumentSnapshot>(
              future: query['clientId'] != null
                  ? FirebaseFirestore.instance
                      .collection('clients')
                      .doc(query['clientId'])
                      .get()
                  : null,
              builder: (context, clientSnapshot) {
                if (clientSnapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                }

                if (!clientSnapshot.hasData || !clientSnapshot.data!.exists) {
                  return const _ContactInfoRow(
                    label: 'Client',
                    value: 'No client information available',
                    icon: Icons.person_outline,
                  );
                }

                final clientData = clientSnapshot.data!.data() as Map<String, dynamic>;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ContactInfoRow(
                      label: 'Client',
                      value: clientData['name'] ?? 'No name',
                      icon: Icons.person_outline,
                    ),
                    _ContactInfoRow(
                      label: 'Email',
                      value: clientData['email'],
                      icon: Icons.email_outlined,
                      onTap: clientData['email'] != null
                          ? () => _launchEmail(clientData['email'])
                          : null,
                    ),
                    _ContactInfoRow(
                      label: 'Phone',
                      value: clientData['phone'],
                      icon: Icons.phone_outlined,
                      onTap: clientData['phone'] != null
                          ? () => _launchPhoneCall(clientData['phone'])
                          : null,
                    ),
                  ],
                );
              },
            ),

            // Assigned user details
            const SizedBox(height: 16),
            FutureBuilder<DocumentSnapshot>(
              future: query['assignedToId'] != null
                  ? FirebaseFirestore.instance
                      .collection('users')
                      .doc(query['assignedToId'])
                      .get()
                  : null,
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                }

                if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                  return _buildContactInfoRow(
                    icon: Icons.person,
                    label: 'Name',
                    value: query['name']?.toString() ?? 'N/A',
                  );
                }

                final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildContactInfoRow(
                      icon: Icons.person,
                      label: 'Name',
                      value: userData['name'] ?? 'No name',
                    ),
                    _buildContactInfoRow(
                      icon: Icons.email,
                      label: 'Email',
                      value: userData['email'],
                      onTap: userData['email'] != null ? () => _launchEmail(userData['email']) : null,
                    ),
                    _buildContactInfoRow(
                      icon: Icons.phone,
                      label: 'Phone',
                      value: userData['phone'],
                      onTap: userData['phone'] != null ? () => _launchPhoneCall(userData['phone']) : null,
                    ),
                  ],
                );
              },
            ),

            // Action buttons
            if (query['status'] != 'In Progress' && query['status'] != 'Resolved') ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    try {
                      await FirebaseFirestore.instance
                          .collection('queries')
                          .doc(query['id'])
                          .update({
                            'status': 'In Progress',
                            'updatedAt': FieldValue.serverTimestamp(),
                          });

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Query marked as In Progress'),
                            backgroundColor: Colors.green,
                          ),
                        );
                        setState(() {
                          query['status'] = 'In Progress';
                        });
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error updating query: ${e.toString()}'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.check_circle_outline, size: 20),
                  label: const Text('Mark as In Progress'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

// Helper method to get color based on status
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

class QuerySearchScreen extends StatefulWidget {
  const QuerySearchScreen({Key? key}) : super(key: key);

  @override
  _QuerySearchScreenState createState() => _QuerySearchScreenState();
}

class _QuerySearchScreenState extends State<QuerySearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  
  // In-memory cache for user data to avoid repeated Firestore lookups
  final Map<String, Map<String, dynamic>> _userCache = {};
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;
  bool _isSearching = false;

  // Initialize Firestore instance
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }
