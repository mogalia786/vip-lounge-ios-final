import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:vip_lounge/core/constants/colors.dart';
import 'package:vip_lounge/core/providers/app_auth_provider.dart';
import 'package:vip_lounge/core/services/vip_notification_service.dart';
import 'package:vip_lounge/features/auth/data/services/user_service.dart';

// Add this line to fix the StatefulWidget issue
class ConsultantQueryInboxScreen extends StatefulWidget {
  final String currentConsultantUid;
  
  const ConsultantQueryInboxScreen({
    Key? key,
    required this.currentConsultantUid,
  }) : super(key: key);

  @override
  _ConsultantQueryInboxScreenState createState() => _ConsultantQueryInboxScreenState();
}

class _ConsultantQueryInboxScreenState extends State<ConsultantQueryInboxScreen> {
  static const statusOptions = [
    'Assigned',
    'VIP Called',
    'VIP Emailed',
    'Awaiting Info',
    'Resolved',
  ];

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'assigned':
        return Colors.blue;
      case 'vip called':
        return Colors.purple;
      case 'vip emailed':
        return Colors.indigo;
      case 'awaiting info':
        return Colors.amber;
      case 'resolved':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get the current consultant's name from the provider
    final consultantName = 'Consultant';
    
    return Scaffold(
      appBar: AppBar(
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.gold),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: const Text('My Query Inbox', style: TextStyle(color: AppColors.gold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/page_bg.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('queries')
              .where('assignedToId', isEqualTo: widget.currentConsultantUid)
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            // Debug: Print the current consultant UID
            print('Current consultant UID: ${widget.currentConsultantUid}');
            
            // Debug: Print snapshot data if available
            if (snapshot.hasData) {
              print('Query snapshot has ${snapshot.data!.docs.length} documents');
              for (var doc in snapshot.data!.docs) {
                print('Document ID: ${doc.id}');
                print('Document data: ${doc.data()}');
              }
            } else if (snapshot.hasError) {
              print('Query error: ${snapshot.error}');
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.amber),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.inbox_outlined,
                      size: 80,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No queries assigned to you',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                final data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                final queryId = snapshot.data!.docs[index].id;
                final refNum = data['referenceNumber'] ?? '';
                final ministerName =
                  ((data['ministerFirstName'] ?? '').toString().isNotEmpty || (data['ministerLastName'] ?? '').toString().isNotEmpty)
                    ? ((data['ministerFirstName'] ?? '') + ' ' + (data['ministerLastName'] ?? '')).trim()
                    : (data['ministerName'] ?? data['ministerFullName'] ?? data['minister'] ?? '');
                final ministerEmail = data['ministerEmail'] ?? '';
                final ministerPhone = data['ministerPhone'] ?? '';
                String status = (data['status'] ?? '').toString();
                if (status.isEmpty || !statusOptions.contains(status)) {
                  status = 'Assigned';
                }
                final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
                final query = data['query'] ?? '';
                String dropdownValue = status;
                
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        query,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        createdAt != null ? 'Date: ${createdAt.toString().substring(0, 16)}' : 'Date: -',
                        style: const TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 8),
                      Text('Ref: $refNum', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                      const SizedBox(height: 8),
                      Text(
                        'VIP: ${ministerName.isNotEmpty ? ministerName : '(not provided)'}',
                        style: const TextStyle(
                          color: Colors.deepOrange,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (ministerEmail.toString().isNotEmpty)
                        GestureDetector(
                          onTap: () async {
                            final uri = Uri(scheme: 'mailto', path: ministerEmail);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri);
                            }
                          },
                          child: Text(
                            'Email: $ministerEmail',
                            style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
                          ),
                        ),
                      if (ministerPhone.toString().isNotEmpty)
                        GestureDetector(
                          onTap: () async {
                            final uri = Uri(scheme: 'tel', path: ministerPhone);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri);
                            }
                          },
                          child: Text(
                            'Phone: $ministerPhone',
                            style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text('Status: ', style: TextStyle(color: Colors.black87)),
                          DropdownButton<String>(
                            value: dropdownValue,
                            items: statusOptions.map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value, style: const TextStyle(color: Colors.black)),
                              );
                            }).toList(),
                            onChanged: (String? newValue) async {
                              if (newValue != null && newValue != status) {
                                await FirebaseFirestore.instance
                                    .collection('queries')
                                    .doc(queryId)
                                    .update({'status': newValue});
                                
                                // Send notification to minister
                                final ministerId = data['ministerId'] ?? data['ministerUid'] ?? data['ministerEmail'] ?? '';
                                final refNumForNotif = data['referenceNumber'] ?? '';
                                final queryTextForNotif = data['query'] ?? '';
                                final ministerNameForNotif = ((data['ministerFirstName'] ?? '').toString().isNotEmpty || 
                                    (data['ministerLastName'] ?? '').toString().isNotEmpty)
                                    ? ((data['ministerFirstName'] ?? '') + ' ' + (data['ministerLastName'] ?? '')).trim()
                                    : (data['ministerName'] ?? data['ministerFullName'] ?? data['minister'] ?? '');
                                    
                                await sendNotificationToMinister(
                                  ministerId: ministerId,
                                  ministerName: ministerNameForNotif,
                                  refNum: refNumForNotif,
                                  query: queryTextForNotif,
                                  newStatus: newValue,
                                  consultantUid: widget.currentConsultantUid,
                                  consultantName: consultantName,
                                  showDialog: true,
                                );
                                
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Query status updated to $newValue')),
                                  );
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildQueryCard(Map<String, dynamic> query, String queryId) {
    final createdAt = query['createdAt'] as Timestamp?;
    final status = query['status'] ?? 'pending';
    final queryText = query['query'] ?? 'No query text';
    final contactInfo = query['contactInfo'] ?? {};
    final referenceNumber = query['referenceNumber'] ?? 'N/A';
    final ministerName = query['ministerName'] ?? 'Unknown Minister';
    final ministerEmail = query['ministerEmail'] ?? '';
    final ministerPhone = query['ministerPhone'] ?? '';

    // Calculate time difference for warning
    final now = DateTime.now();
    final createdTime = createdAt?.toDate() ?? now;
    final timeDiff = now.difference(createdTime).inMinutes;
    final isOverdue = timeDiff > 30 && status != 'resolved';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Minister: $ministerName',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
            ),
            const SizedBox(height: 8),
            Text(
              'Query: $queryText',
              style: const TextStyle(color: Colors.black87),
            ),
            const SizedBox(height: 8),
            Text(
              'Status: ${status.toString().toUpperCase()}',
              style: TextStyle(
                color: _getStatusColor(status),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (ministerEmail.isNotEmpty)
              GestureDetector(
                onTap: () async {
                  final uri = Uri(scheme: 'mailto', path: ministerEmail);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  }
                },
                child: Text(
                  'Email: $ministerEmail',
                  style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
                ),
              ),
            if (ministerPhone.isNotEmpty)
              GestureDetector(
                onTap: () async {
                  final uri = Uri(scheme: 'tel', path: ministerPhone);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  }
                },
                child: Text(
                  'Phone: $ministerPhone',
                  style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
                ),
              ),
            const SizedBox(height: 8),
            Text(
              'Reference: $referenceNumber',
              style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
            ),
            Text(
              'Created: ${createdAt?.toDate().toString() ?? 'Unknown date'}',
              style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> sendNotificationToMinister({
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
