import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ConsultantQueryBadge extends StatelessWidget {
  final String currentConsultantUid;

  const ConsultantQueryBadge({
    Key? key,
    required this.currentConsultantUid,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('queries')
          .where('assignedTo', isEqualTo: currentConsultantUid)
          .where('status', isEqualTo: 'assigned')
          .snapshots()
          .handleError((error) {
            print('Error in query badge: $error');
            // Return null on error, which will be handled by the builder
            return null;
          })
          .map((snapshot) {
            print('Query badge - ${snapshot.docs.length} assigned queries found');
            if (snapshot.docs.isNotEmpty) {
              print('First assigned query: ${snapshot.docs.first.data()}');
            }
            return snapshot;
          }),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          print('Error in query badge stream: ${snapshot.error}');
          return const SizedBox.shrink();
        }

        if (!snapshot.hasData) {
          print('Query badge: No data yet');
          return const SizedBox.shrink();
        }

        final queryCount = snapshot.data!.docs.length;
        print('Query badge: $queryCount queries found');
        
        if (queryCount == 0) {
          print('Query badge: No queries found for consultant: $currentConsultantUid');
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(10),
          ),
          constraints: const BoxConstraints(
            minWidth: 16,
            minHeight: 16,
          ),
          child: Text(
            queryCount.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        );
      },
    );
  }
}
