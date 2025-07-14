import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../domain/entities/query.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/providers/app_auth_provider.dart';

class OverdueQueriesScreen extends StatelessWidget {
  const OverdueQueriesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AppAuthProvider>(context).appUser;
    if (user == null) return const Scaffold(body: Center(child: Text('User not found')));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Overdue Queries'),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      backgroundColor: Colors.grey[900],
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('queries')
            .where('status', isNotEqualTo: 'resolved')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No overdue queries found'));
          }

          final now = DateTime.now();
          final overdueQueries = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final createdAt = data['createdAt'] as Timestamp?;
            if (createdAt == null) return false;
            
            final difference = now.difference(createdAt.toDate()).inMinutes;
            return difference > 30; // More than 30 minutes old
          }).toList();

          if (overdueQueries.isEmpty) {
            return const Center(child: Text('No queries are currently overdue'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: overdueQueries.length,
            itemBuilder: (context, index) {
              final doc = overdueQueries[index];
              final data = doc.data() as Map<String, dynamic>;
              final query = Query.fromMap(data, doc.id);
              
              final createdAt = data['createdAt'] as Timestamp?;
              final duration = createdAt != null 
                  ? now.difference(createdAt.toDate())
                  : const Duration();
              
              final hours = duration.inHours;
              final minutes = duration.inMinutes % 60;
              
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                color: Colors.grey[850],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Colors.red, width: 1.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Query #${query.referenceNumber}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red[900]!.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Overdue by $hours h $minutes m',
                              style: const TextStyle(color: Colors.red, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        query.queryType ?? 'No type specified',
                        style: TextStyle(
                          color: AppColors.gold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (query.assignedToId != null && query.assignedToName != null) ...[
                        Text(
                          'Assigned to: ${query.assignedToName}',
                          style: TextStyle(color: Colors.grey[400], fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                      ],
                      Text(
                        'Created: ${DateFormat('MMM d, y • h:mm a').format(createdAt?.toDate() ?? DateTime.now())}',
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              // TODO: Navigate to query details
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.gold,
                            ),
                            child: const Text('View Details'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              // TODO: Implement reassign action
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[900],
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Reassign'),
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
    );
  }
}
