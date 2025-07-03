import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class StaffPerformanceIndicator extends StatelessWidget {
  final String userId;
  final DateTime selectedDate;
  
  const StaffPerformanceIndicator({
    Key? key, 
    required this.userId, 
    required this.selectedDate
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final start = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, 0, 0, 0);
    final end = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, 23, 59, 59);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('activities')
          .where('userId', isEqualTo: userId)
          .where('timestamp', isGreaterThanOrEqualTo: start)
          .where('timestamp', isLessThanOrEqualTo: end)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        int totalTasks = 0;
        int completedTasks = 0;
        double totalRevenue = 0.0;

        for (var doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          if (data['type'] == 'task') {
            totalTasks++;
            if (data['status'] == 'completed') {
              completedTasks++;
            }
          }
          if (data['revenue'] != null) {
            totalRevenue += (data['revenue'] as num).toDouble();
          }
        }

        final completionRate = totalTasks > 0 ? (completedTasks / totalTasks) * 100 : 0;

        return Card(
          color: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Colors.red, width: 2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Performance Today',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatItem('Tasks', '$completedTasks/$totalTasks'),
                    _buildStatItem('Completion', '${completionRate.toStringAsFixed(1)}%'),
                    _buildStatItem('Revenue', 'R ${totalRevenue.toStringAsFixed(2)}'),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
