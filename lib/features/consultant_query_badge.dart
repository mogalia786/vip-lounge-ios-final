import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ConsultantQueryBadge extends StatelessWidget {
  final String currentConsultantUid;
  final VoidCallback? onTap;
  const ConsultantQueryBadge({Key? key, required this.currentConsultantUid, this.onTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('queries').snapshots(),
      builder: (context, snapshot) {
        int count = 0;
        if (snapshot.hasData) {
          final docs = snapshot.data!.docs;
          for (final doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final status = data['status'] ?? '';
            final assignedTo = data['assignedTo'];
            // Only count queries that are still pending or being attended by this consultant
            if (status == 'pending' || (status == 'being_attended' && assignedTo == currentConsultantUid)) {
              count++;
            }
          }
        }
        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.question_answer_outlined),
              tooltip: 'VIP Queries',
              onPressed: onTap,
            ),
            if (count > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
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
                    '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
