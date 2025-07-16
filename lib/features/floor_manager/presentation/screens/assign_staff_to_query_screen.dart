import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:vip_lounge/core/services/vip_notification_service.dart';
import 'package:vip_lounge/core/constants/colors.dart';

class AssignStaffToQueryScreen extends StatefulWidget {
  final Map<String, dynamic> query;
  
  const AssignStaffToQueryScreen({
    Key? key,
    required this.query,
  }) : super(key: key);

  @override
  _AssignStaffToQueryScreenState createState() => _AssignStaffToQueryScreenState();
}

class _AssignStaffToQueryScreenState extends State<AssignStaffToQueryScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final VipNotificationService _notificationService;
  bool _isLoading = true;
  List<Map<String, dynamic>> _staffList = [];
  String? _selectedStaffId;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _notificationService = VipNotificationService();
    _loadStaffMembers();
  }

  Future<void> _loadStaffMembers() async {
    try {
      // First get all users to debug the roles
      final allUsers = await _firestore.collection('users').get();
      
      // Debug: Print all users and their roles
      debugPrint('All users and their roles:');
      for (var doc in allUsers.docs) {
        debugPrint('${doc.id}: ${doc.data()['role']} - ${doc.data()['email']}');
      }
      
      // Filter for staff members - check both 'role' and 'roles' fields
      final staffMembers = allUsers.docs.where((doc) {
        final data = doc.data();
        final role = data['role'] ?? data['roles'] ?? '';
        return role.toString().toLowerCase() == 'staff' || 
               role.toString().toLowerCase() == 'consultant';
      }).toList();
      
      debugPrint('Found ${staffMembers.length} staff/consultant users');

      setState(() {
        _staffList = staffMembers.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim(),
            'email': data['email'] ?? '',
            'phone': data['phone'] ?? data['phoneNumber'] ?? '',
            'role': data['role'] ?? 'staff',
          };
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error loading staff members')),
      );
    }
  }

  Future<void> _assignQuery() async {
    if (_selectedStaffId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a staff member')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final staff = _staffList.firstWhere((s) => s['id'] == _selectedStaffId);
      final now = DateTime.now();
      final currentUser = FirebaseAuth.instance.currentUser;
      
      // Update the query with assignment info
      await _firestore.collection('queries').doc(widget.query['id']).update({
        'assignedToId': _selectedStaffId,
        'assignedToName': staff['name'],
        'assignedToEmail': staff['email'],
        'assignedToPhone': staff['phone'],
        'assignedAt': FieldValue.serverTimestamp(),
        'status': 'assigned',
        'updatedAt': FieldValue.serverTimestamp(),
        'statusHistory': FieldValue.arrayUnion([
          {
            'status': 'assigned',
            'timestamp': now,
            'by': currentUser?.uid,
            'byName': currentUser?.displayName ?? 'Floor Manager',
            'details': 'Assigned to ${staff['name']}'
          }
        ]),
      });

      // Send notification to the assigned staff
      try {
        await _notificationService.createNotification(
          title: 'New Query Assigned',
          body: 'You have been assigned a new query from ${widget.query['ministerName'] ?? 'a minister'}. Reference #${widget.query['referenceNumber']}',
          data: {
            'queryId': widget.query['id'],
            'referenceNumber': widget.query['referenceNumber'],
            'ministerName': widget.query['ministerName'],
            'ministerPhone': widget.query['ministerPhone'],
            'query': widget.query['uery'] ?? widget.query['query'],
            'type': 'query_assigned',
            'timestamp': DateTime.now().toIso8601String(),
            'priority': 'high',
          },
          role: staff['role'],
          assignedToId: _selectedStaffId,
          notificationType: 'query_assignment',
        );
        debugPrint('Successfully sent notification to staff: ${staff['email']}');
      } catch (e) {
        debugPrint('Error sending notification to staff: $e');
        // Log the error but don't fail the operation
        await _notificationService.logNotificationDebug(
          trigger: 'assign_staff_to_query',
          eventType: 'staff_notification_error',
          recipient: staff['email'] ?? _selectedStaffId ?? 'unknown',
          body: 'Failed to send notification to staff',
          localSuccess: false,
          fcmSuccess: false,
          error: e.toString(),
        );
      }

      // Send notification to the minister with enhanced details
      try {
        final ministerId = widget.query['ministerId'];
        if (ministerId != null && ministerId.toString().isNotEmpty) {
          final notificationBody = '''Your query has been assigned to ${staff['name']}.
          
Contact Details:
Name: ${staff['name']}
Phone: ${staff['phone'] ?? 'Not provided'}
Email: ${staff['email'] ?? 'Not provided'}

Query: ${widget.query['uery'] ?? widget.query['query'] ?? 'No details'}
Reference: #${widget.query['referenceNumber']}''';

          await _notificationService.createNotification(
            title: 'Query #${widget.query['referenceNumber']} - Assigned',
            body: notificationBody,
            data: {
              'queryId': widget.query['id'],
              'referenceNumber': widget.query['referenceNumber'],
              'assignedToName': staff['name'],
              'assignedToPhone': staff['phone'] ?? '',
              'assignedToEmail': staff['email'] ?? '',
              'queryText': widget.query['uery'] ?? widget.query['query'] ?? 'No details',
              'queryDate': widget.query['createdAt']?.toDate().toString() ?? DateTime.now().toString(),
              'type': 'query_assignment',
              'showFullDetails': 'true',
              'priority': 'high',
              'timestamp': DateTime.now().toIso8601String(),
            },
            role: 'minister',
            assignedToId: ministerId,
            notificationType: 'query_assignment',
          );
          debugPrint('Successfully sent notification to minister: $ministerId');
        } else {
          debugPrint('No ministerId found in query: ${widget.query['id']}');
        }
      } catch (e) {
        debugPrint('Error sending notification to minister: $e');
        // Log the error but don't fail the operation
        await _notificationService.logNotificationDebug(
          trigger: 'assign_staff_to_query',
          eventType: 'minister_notification_error',
          recipient: widget.query['ministerId']?.toString() ?? 'unknown',
          body: 'Failed to send notification to minister',
          localSuccess: false,
          fcmSuccess: false,
          error: e.toString(),
        );
      }

      if (mounted) {
        Navigator.of(context).pop(true); // Return success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error assigning query. Please try again.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assign Staff to Query'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.blue,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Query summary
                Card(
                  margin: const EdgeInsets.all(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Query #${widget.query['referenceNumber'] ?? 'N/A'}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.query['uery'] ?? widget.query['query'] ?? 'No description',
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'From: ${widget.query['ministerName'] ?? 'N/A'}',
                          style: const TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Select a staff member to assign this query to:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _staffList.length,
                    itemBuilder: (context, index) {
                      final staff = _staffList[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        elevation: 1,
                        child: RadioListTile<String>(
                          title: Text(
                            staff['name'],
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Colors.red, // Staff name in red as requested
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${staff['role']} • ${staff['email']}',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              if (staff['phone']?.isNotEmpty == true)
                                Text(
                                  'Phone: ${staff['phone']}',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                            ],
                          ),
                          value: staff['id'],
                          groupValue: _selectedStaffId,
                          onChanged: (value) {
                            setState(() {
                              _selectedStaffId = value;
                            });
                          },
                          secondary: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.person_outline,
                              color: Colors.blue,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _assignQuery,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Assign Query',
                              style: TextStyle(fontSize: 16),
                            ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
