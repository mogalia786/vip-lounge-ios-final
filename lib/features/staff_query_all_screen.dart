import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class StaffQueryAllScreen extends StatelessWidget {
  final String currentStaffUid;
  final void Function(Map<String, dynamic> query)? onAttend;
  const StaffQueryAllScreen({Key? key, required this.currentStaffUid, this.onAttend}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('All Minister Queries')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('queries')
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
          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final refNum = data['referenceNumber'] ?? '';
              final subject = data['subject'] ?? '';
              final status = data['status'] ?? '';
              final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
              final ministerName = (data['ministerFirstName'] ?? '') + ' ' + (data['ministerLastName'] ?? '');
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Date: ' + (createdAt != null ? createdAt.toLocal().toString() : ''), style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text('Minister: $ministerName'),
                          Text('Subject: $subject'),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Status: $status',
                            style: TextStyle(
                              color: status == 'pending'
                                  ? Colors.orange
                                  : status == 'resolved'
                                      ? Colors.green
                                      : status == 'awaiting info'
                                          ? Colors.blue
                                          : status == 'minister called'
                                              ? Colors.purple
                                              : status == 'minister emailed'
                                                  ? Colors.teal
                                                  : Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (status == 'pending')
                            TextButton(
                              onPressed: () {
                                onAttend?.call({...data, 'id': docs[index].id});
                              },
                              child: const Text('Attend', style: TextStyle(color: Colors.green)),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
