import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> sendNotificationToMinister(String ministerUidOrEmail, String ministerName, String refNum, String query, String newStatus) async {
  // Professional notification message
  final message =
      'Dear $ministerName,\nYour query (Ref: $refNum, "$query") status has been updated to: $newStatus.';
  // ignore: avoid_print
  print(message);
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
                                // Send notification to minister (placeholder)
                                final ministerUid = data['ministerUid'] ?? data['ministerEmail'] ?? '';
                                final refNumForNotif = data['referenceNumber'] ?? '';
                                final queryTextForNotif = data['query'] ?? '';
                                final ministerNameForNotif = data['ministerName'] ?? data['ministerFullName'] ?? data['minister'] ?? '';
                                await sendNotificationToMinister(ministerUid, ministerNameForNotif, refNumForNotif, queryTextForNotif, newValue);
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
