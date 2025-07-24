import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:vip_lounge/core/providers/app_auth_provider.dart';
import 'package:vip_lounge/core/services/vip_notification_service.dart';
import 'package:vip_lounge/features/auth/data/services/user_service.dart';

Future<void> sendNotificationToMinisterFromConsultant({
  required String ministerId,
  required String ministerName,
  required String refNum,
  required String query,
  required String newStatus,
  required String consultantUid,
  required String consultantName,
  bool showDialog = true,
}) async {
  try {
    final UserService userService = UserService();
    final consultantDetails = await userService.getUserById(consultantUid);
    final consultantPhone = consultantDetails?['phoneNumber'] ?? '';
    final consultantEmail = consultantDetails?['email'] ?? '';
    final consultantContact = (consultantPhone != null && consultantPhone.toString().isNotEmpty)
        ? 'Phone: $consultantPhone'
        : '';
    final consultantContactEmail = (consultantEmail != null && consultantEmail.toString().isNotEmpty)
        ? 'Email: $consultantEmail'
        : '';
    final consultantContactInfo = [consultantContact, consultantContactEmail].where((e) => e.isNotEmpty).join(' | ');
    final body = 'Dear $ministerName,\nYour query (Ref: $refNum, "$query") status has been updated to: $newStatus.\nHandled by: $consultantName. $consultantContactInfo';
    await VipNotificationService().createNotification(
      title: 'Query Status Updated',
      body: body,
      data: {
        'referenceNumber': refNum,
        'ministerName': ministerName,
        'query': query,
        'status': newStatus,
        'consultantName': consultantName,
        'consultantPhone': consultantPhone,
        'consultantEmail': consultantEmail,
        'consultantUid': consultantUid,
        'notificationType': 'query_status_update',
        'showRating': true, // Always show rating for any status
      },
      role: 'minister',
      assignedToId: ministerId,
      notificationType: 'query_status_update',
    );
  } catch (e) {
    print('[NOTIFY] Failed to notify minister of query status update: $e');
  }
}

class ConsultantQueryInboxScreen extends StatelessWidget {
  final String currentConsultantUid;
  const ConsultantQueryInboxScreen({Key? key, required this.currentConsultantUid}) : super(key: key);

  static const statusOptions = [
    'Assigned',
    'VIP Called',
    'VIP Emailed',
    'Awaiting Info',
    'Resolved',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: const Text('My Query Inbox'),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.grey.shade100,
              Colors.grey.shade200,
            ],
          ),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('queries')
              .where('assignedTo', isEqualTo: currentConsultantUid)
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No queries assigned to you',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  ],
                ),
              );
            }

            final queries = snapshot.data!.docs;

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: queries.length,
              itemBuilder: (context, index) {
                final queryDoc = queries[index];
                final queryData = queryDoc.data() as Map<String, dynamic>;
                final queryId = queryDoc.id;
                final ministerName = queryData['ministerName'] ?? 'Unknown Minister';
                final query = queryData['query'] ?? 'No query text';
                final status = queryData['status'] ?? 'pending';
                final refNum = queryData['referenceNumber'] ?? 'No Ref';
                final createdAt = queryData['createdAt'] as Timestamp?;
                final ministerId = queryData['ministerId'] ?? '';

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header with minister name and reference
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                ministerName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                            Text(
                              'Ref: $refNum',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        
                        // Query text
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Text(
                            query,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        // Status and timestamp
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getStatusColor(status),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                status.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (createdAt != null)
                              Text(
                                _formatTimestamp(createdAt),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        
                        // Status update dropdown
                        Row(
                          children: [
                            const Text(
                              'Update Status: ',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                            Expanded(
                              child: DropdownButton<String>(
                                value: null,
                                hint: const Text('Select Status'),
                                isExpanded: true,
                                items: statusOptions.map((String statusOption) {
                                  return DropdownMenuItem<String>(
                                    value: statusOption,
                                    child: Text(statusOption),
                                  );
                                }).toList(),
                                onChanged: (String? newStatus) {
                                  if (newStatus != null) {
                                    _updateQueryStatus(
                                      context,
                                      queryId,
                                      newStatus,
                                      ministerId,
                                      ministerName,
                                      refNum,
                                      query,
                                    );
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'assigned':
        return Colors.blue;
      case 'vip called':
        return Colors.purple;
      case 'vip emailed':
        return Colors.teal;
      case 'awaiting info':
        return Colors.amber;
      case 'resolved':
        return Colors.green;
      case 'being_attended':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  String _formatTimestamp(Timestamp timestamp) {
    final dateTime = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  void _updateQueryStatus(
    BuildContext context,
    String queryId,
    String newStatus,
    String ministerId,
    String ministerName,
    String refNum,
    String query,
  ) async {
    try {
      // Update query status in Firestore
      await FirebaseFirestore.instance
          .collection('queries')
          .doc(queryId)
          .update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
        'lastModifiedBy': currentConsultantUid,
      });

      // Get consultant details for notification
      final appUser = Provider.of<AppAuthProvider>(context, listen: false).appUser;
      final consultantName = appUser?.fullName ?? 'Consultant';

      // Send notification to minister
      if (ministerId.isNotEmpty) {
        await sendNotificationToMinisterFromConsultant(
          ministerId: ministerId,
          ministerName: ministerName,
          refNum: refNum,
          query: query,
          newStatus: newStatus,
          consultantUid: currentConsultantUid,
          consultantName: consultantName,
        );
      }

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Query status updated to: $newStatus'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating query status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
