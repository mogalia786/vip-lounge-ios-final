import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:vip_lounge/core/services/vip_query_service.dart';

class StaffQueryInboxScreen extends StatelessWidget {
  final String currentStaffUid;
  final void Function(Map<String, dynamic> query, String newStatus)? onStatusChanged;
  const StaffQueryInboxScreen({Key? key, required this.currentStaffUid, this.onStatusChanged}) : super(key: key);

  static const statusOptions = [
    'Minister Called',
    'Minister Emailed',
    'Awaiting Info',
    'Resolved',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Query Inbox')),
      body: StreamBuilder<QuerySnapshot>(
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
              final subject = data['subject'] ?? '';
              final status = data['status'] ?? '';
              final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
              String dropdownValue = status;
              final List<String> dropdownOptions = List<String>.from(statusOptions);
              if (dropdownValue.isNotEmpty && !dropdownOptions.contains(dropdownValue)) {
                dropdownOptions.insert(0, dropdownValue);
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
                      Text('Status: $status'),
                    ],
                  ),
                  trailing: DropdownButton<String>(
                    value: dropdownValue,
                    items: dropdownOptions.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (String? newValue) async {
                      if (newValue != null && newValue != status) {
                        // Call backend update logic
                        final queryId = docs[index].id;
                        final staffName = "You"; // Replace with actual staff name from auth/user provider
                        await VipQueryService().updateQueryStatus(
                          queryId: queryId,
                          newStatus: newValue,
                          staffUid: currentStaffUid,
                          staffName: staffName,
                        );
                        // Optionally show a snackbar or UI feedback
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Query status updated to $newValue')),
                        );
                        // Optionally call onStatusChanged if needed
                        onStatusChanged?.call(data, newValue);
                      }
                    },
                  ),
                  onTap: () {
                    // Optionally show query details
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
