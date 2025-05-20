import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class StaffQueryListScreen extends StatelessWidget {
  final String currentStaffUid;
  final void Function(Map<String, dynamic> query)? onQueryTap;
  const StaffQueryListScreen({Key? key, required this.currentStaffUid, this.onQueryTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Minister Queries')),
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
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final status = data['status'] ?? '';
              final assignedTo = data['assignedTo'];
              final assignedToName = data['assignedToName'] ?? '';
              final refNum = data['referenceNumber'] ?? '';
              final subject = data['subject'] ?? '';
              final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
              String statusLabel = status;
              Color statusColor = Colors.grey;
              if (status == 'pending') {
                statusLabel = 'Pending';
                statusColor = Colors.orange;
              } else if (status == 'being_attended') {
                statusLabel = 'Being Attended To';
                statusColor = Colors.blue;
              } else if (status == 'resolved') {
                statusLabel = 'Resolved';
                statusColor = Colors.green;
              }
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: CircleAvatar(child: Text(refNum.isNotEmpty ? refNum[0] : '?')),
                  title: Text(subject),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ref: $refNum'),
                      if (createdAt != null)
                        Text('Date: ${createdAt.toLocal()}'),
                      Text('Status: $statusLabel', style: TextStyle(color: statusColor)),
                      if (status == 'being_attended' && assignedToName.isNotEmpty)
                        Text('Assigned to: $assignedToName'),
                    ],
                  ),
                  trailing: status == 'pending'
                      ? ElevatedButton(
                          child: const Text('Attend'),
                          onPressed: () => onQueryTap?.call(data),
                        )
                      : Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => onQueryTap?.call(data),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
