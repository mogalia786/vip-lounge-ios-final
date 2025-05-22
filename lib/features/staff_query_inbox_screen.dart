import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:vip_lounge/core/providers/app_auth_provider.dart';

import 'package:vip_lounge/core/services/vip_notification_service.dart';
import 'package:vip_lounge/features/auth/data/services/user_service.dart';

Future<void> sendNotificationToMinister({
  required String ministerId,
  required String ministerName,
  required String refNum,
  required String query,
  required String newStatus,
  required String staffUid,
  required String staffName,
}) async {
  try {
    final UserService userService = UserService();
    final staffDetails = await userService.getUserById(staffUid);
    final staffPhone = staffDetails?['phoneNumber'] ?? '';
    final staffEmail = staffDetails?['email'] ?? '';
    final staffContact = (staffPhone != null && staffPhone.toString().isNotEmpty)
        ? 'Phone: $staffPhone'
        : '';
    final staffContactEmail = (staffEmail != null && staffEmail.toString().isNotEmpty)
        ? 'Email: $staffEmail'
        : '';
    final staffContactInfo = [staffContact, staffContactEmail].where((e) => e.isNotEmpty).join(' | ');
    final body = 'Dear $ministerName,\nYour query (Ref: $refNum, "$query") status has been updated to: $newStatus.\nHandled by: $staffName. $staffContactInfo';
    await VipNotificationService().createNotification(
      title: 'Query Status Updated',
      body: body,
      data: {
        'referenceNumber': refNum,
        'ministerName': ministerName,
        'query': query,
        'status': newStatus,
        'staffName': staffName,
        'staffPhone': staffPhone,
        'staffEmail': staffEmail,
        'staffUid': staffUid,
        'notificationType': 'query_status_update',
      },
      role: 'minister',
      assignedToId: ministerId,
      notificationType: 'query_status_update',
    );
  } catch (e) {
    print('[NOTIFY] Failed to notify minister of query status update: $e');
  }
}


class StaffQueryInboxScreen extends StatelessWidget {
  final String currentStaffUid;
  const StaffQueryInboxScreen({Key? key, required this.currentStaffUid}) : super(key: key);

  static const statusOptions = [
    'Assigned',
    'Minister Called',
    'Minister Emailed',
    'Awaiting Info',
    'Resolved',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Query Inbox')),
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
              .where('assignedTo', isEqualTo: currentStaffUid)
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text('No queries found.'));
            }
            final docs = snapshot.data!.docs;
            return ListView.builder(
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final data = docs[index].data() as Map<String, dynamic>;
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
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
  'Minister: ${ministerName.isNotEmpty ? ministerName : '(not provided)'}',
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
                                child: Text(value),
                              );
                            }).toList(),
                            onChanged: (String? newValue) async {
  if (newValue != null && newValue != status) {
    final queryId = docs[index].id;
    await FirebaseFirestore.instance
        .collection('queries')
        .doc(queryId)
        .update({'status': newValue});
    // Send notification to minister (real)
    final ministerId = data['ministerId'] ?? data['ministerUid'] ?? data['ministerEmail'] ?? '';
    final refNumForNotif = data['referenceNumber'] ?? '';
    final queryTextForNotif = data['query'] ?? '';
    final ministerNameForNotif = ((data['ministerFirstName'] ?? '').toString().isNotEmpty || (data['ministerLastName'] ?? '').toString().isNotEmpty)
        ? ((data['ministerFirstName'] ?? '') + ' ' + (data['ministerLastName'] ?? '')).trim()
        : (data['ministerName'] ?? data['ministerFullName'] ?? data['minister'] ?? '');
    String staffName = '';
    try {
      final provider = Provider.of<AppAuthProvider?>(context, listen: false);
      staffName = provider?.appUser?.fullName ?? '';
    } catch (_) {}
    if (staffName.isEmpty) staffName = 'Staff';
    await sendNotificationToMinister(
      ministerId: ministerId,
      ministerName: ministerNameForNotif,
      refNum: refNumForNotif,
      query: queryTextForNotif,
      newStatus: newValue,
      staffUid: currentStaffUid,
      staffName: staffName,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Query status updated to $newValue')),
    );
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
}
