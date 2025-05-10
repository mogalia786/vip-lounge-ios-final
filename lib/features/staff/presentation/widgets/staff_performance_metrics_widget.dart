import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class StaffPerformanceMetricsWidget extends StatelessWidget {
  final String userId;
  final DateTime selectedDate;
  const StaffPerformanceMetricsWidget({Key? key, required this.userId, required this.selectedDate}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.black,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.amber[700]!, width: 2)),
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bar_chart, color: Colors.amber),
                const SizedBox(width: 8),
                Text('Performance', style: TextStyle(color: Colors.amber[700], fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('staff_activities')
                  .where('userId', isEqualTo: userId)
                  .where('date', isGreaterThanOrEqualTo: DateTime(selectedDate.year, selectedDate.month, selectedDate.day))
                  .where('date', isLessThan: DateTime(selectedDate.year, selectedDate.month, selectedDate.day + 1))
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.amber));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Text('No activities to show.', style: TextStyle(color: Colors.white54));
                }
                final docs = snapshot.data!.docs;
                final activities = docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
                int totalActivities = activities.length;
                final revenueActivities = activities.where((d) => d['revenue'] != null && (d['revenue'] is num ? d['revenue'] > 0 : false)).toList();
                final nonRevenueActivities = activities.where((d) => d['revenue'] == null || (d['revenue'] is num && d['revenue'] == 0)).toList();
                final totalRevenue = activities.fold<num>(0, (sum, d) => sum + (d['revenue'] is num ? d['revenue'] : 0));
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.bar_chart, color: Colors.amber),
                        const SizedBox(width: 8),
                        Text('Performance', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('Revenue Activities: ${revenueActivities.length}', style: const TextStyle(color: Colors.greenAccent, fontSize: 14)),
                    if (revenueActivities.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      ...revenueActivities.map<Widget>((d) {
                        final desc = d['description'] ?? 'No description';
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ', style: TextStyle(color: Colors.white, fontSize: 14)),
                            Expanded(child: Text(desc, style: const TextStyle(color: Colors.white70, fontSize: 14))),
                          ],
                        );
                      }).toList(),
                    ],
                    const SizedBox(height: 8),
                    Text('Total Revenue: R ${totalRevenue.toStringAsFixed(2)}', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 8),
                    Text('Non Revenue Activities: ${nonRevenueActivities.length}', style: const TextStyle(color: Colors.amberAccent, fontSize: 14)),
                    if (nonRevenueActivities.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      ...nonRevenueActivities.map<Widget>((d) {
                        final desc = d['description'] ?? 'No description';
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ', style: TextStyle(color: Colors.white, fontSize: 14)),
                            Expanded(child: Text(desc, style: const TextStyle(color: Colors.white70, fontSize: 14))),
                          ],
                        );
                      }).toList(),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetric(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.amber, size: 20),
        const SizedBox(width: 8),
        Text(label + ': ', style: const TextStyle(color: Colors.white70, fontSize: 14)),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }
}
