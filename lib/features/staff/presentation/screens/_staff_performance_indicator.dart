import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/colors.dart';
import 'package:intl/intl.dart';

class StaffPerformanceIndicator extends StatelessWidget {
  final String userId;
  final DateTime selectedDate;
  const StaffPerformanceIndicator({Key? key, required this.userId, required this.selectedDate}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final start = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, 0, 0, 0);
    final end = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, 23, 59, 59);
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('staff_activities')
          .where('userId', isEqualTo: userId)
          .where('date', isGreaterThanOrEqualTo: DateTime(selectedDate.year, selectedDate.month, selectedDate.day))
          .where('date', isLessThan: DateTime(selectedDate.year, selectedDate.month, selectedDate.day + 1))
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.gold));
        }
        final docs = snapshot.data?.docs ?? [];
        final total = docs.length;
        final withRevenue = docs.where((d) {
          final revenue = d['revenue'];
          return revenue != null && (revenue is num ? revenue > 0 : false);
        }).length;
        final totalRevenue = docs.fold<num>(0, (sum, d) {
          final revenue = d['revenue'];
          return sum + (revenue is num ? revenue : 0);
        });
        // Always display the performance card, even if there are no activities.
        // If docs.isEmpty, metrics will all be zero below.
        return Card(
          color: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.gold, width: 2),
          ),
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.bar_chart, color: AppColors.gold, size: 32),
                    const SizedBox(width: 12),
                    Text(
                      'Performance',
                      style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  color: AppColors.gold,
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                  child: const Text(
                    'Revenue Activities',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                const SizedBox(height: 8),
                const SizedBox(height: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Activities: $total',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Produced Revenue: R ${totalRevenue.toStringAsFixed(2)}',
                      style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
