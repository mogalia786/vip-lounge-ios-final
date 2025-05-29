import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppColors.gold!, width: 2)),
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
                Text('VIP Performance', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            const SizedBox(height: 12),
            
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('staff_activities')
                  .where('userId', isEqualTo: userId)
                  .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime(selectedDate.year, selectedDate.month, 1)))
                  .where('date', isLessThan: Timestamp.fromDate(
                    selectedDate.month == 12
                      ? DateTime(selectedDate.year + 1, 1, 1)
                      : DateTime(selectedDate.year, selectedDate.month + 1, 1)
                  ))
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.amber));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  // DEBUG: Show all document fields fetched (if any)
                  if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('DEBUG: Documents fetched but filtered out:', style: TextStyle(color: Colors.red)),
                        ...snapshot.data!.docs.map((doc) => Text('ID: ' + doc.id + ' DATA: ' + doc.data().toString(), style: const TextStyle(color: Colors.red, fontSize: 10))).toList(),
                      ],
                    );
                  }
                  return const Text('No activities to show.', style: TextStyle(color: Colors.white54));
                }
                final docs = snapshot.data!.docs;
                final activities = docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  data['date'] = (doc['date'] is Timestamp)
                    ? (doc['date'] as Timestamp).toDate()
                    : doc['date'];
                  return data;
                }).toList();

                // Group activities by day
                Map<String, List<Map<String, dynamic>>> activitiesByDay = {};
                for (var activity in activities) {
                  final date = activity['date'] as DateTime;
                  final dayKey = DateFormat('yyyy-MM-dd').format(date);
                  activitiesByDay.putIfAbsent(dayKey, () => []).add(activity);
                }

                final sortedDays = activitiesByDay.keys.toList()..sort();

                int totalActivities = activities.length;
                final revenueActivities = activities.where((d) => d['revenue'] != null && (d['revenue'] is num ? d['revenue'] > 0 : false)).toList();
                final nonRevenueActivities = activities.where((d) => d['revenue'] == null || (d['revenue'] is num && d['revenue'] == 0)).toList();
                final totalRevenue = activities.fold<num>(0, (sum, d) => sum + (d['revenue'] is num ? d['revenue'] : 0));

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    ...sortedDays.map((dayKey) {
                      final dayActivities = activitiesByDay[dayKey]!;
                      final dayRevenueActivities = dayActivities.where((d) => d['revenue'] != null && (d['revenue'] is num ? d['revenue'] > 0 : false)).toList();
                      final dayNonRevenueActivities = dayActivities.where((d) => d['revenue'] == null || (d['revenue'] is num && d['revenue'] == 0)).toList();
                      final dayRevenue = dayRevenueActivities.fold<num>(0, (sum, d) => sum + (d['revenue'] is num ? d['revenue'] : 0));
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat('EEEE, dd MMMM yyyy').format(DateTime.parse(dayKey)),
                            style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          Text('Activities: ${dayActivities.length}', style: const TextStyle(color: Colors.white, fontSize: 13)),
                          Text('Revenue: R ${dayRevenue.toStringAsFixed(2)}', style: const TextStyle(color: Colors.greenAccent, fontSize: 13)),
                          const SizedBox(height: 4),
                          if (dayRevenueActivities.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.only(top: 4, bottom: 2),
                              child: Text('Revenue Generated', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                            ),
                            ...dayRevenueActivities.map((d) {
                              final desc = d['description'] ?? 'No description';
                              final revenue = d['revenue'] ?? 0;
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 1.5),
                                child: Row(
                                  children: [
                                    Expanded(child: Text(desc, style: const TextStyle(color: Colors.white70, fontSize: 13))),
                                    Text('R ${revenue.toStringAsFixed(2)}', style: const TextStyle(color: Colors.greenAccent, fontSize: 13)),
                                  ],
                                ),
                              );
                            }).toList(),
                            Text('Total Revenue: R ${dayRevenue.toStringAsFixed(2)}', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                          if (dayNonRevenueActivities.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.only(top: 4, bottom: 2),
                              child: Text('Non-Revenue Generated', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 14)),
                            ),
                            ...dayNonRevenueActivities.map((d) {
                              final desc = d['description'] ?? 'No description';
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 1.5),
                                child: Row(
                                  children: [
                                    Expanded(child: Text(desc, style: const TextStyle(color: Colors.white70, fontSize: 13))),
                                  ],
                                ),
                              );
                            }).toList(),
                            Text('Total Non-Revenue: ${dayNonRevenueActivities.length}', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                          const Divider(color: Colors.amber, thickness: 0.7),
                        ],
                      );
                    }).toList(),
                    // Summary Card at End
                    Card(
                      color: Colors.black87,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: AppColors.gold!, width: 1)),
                      margin: const EdgeInsets.only(top: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Total for ${DateFormat('MMMM yyyy').format(selectedDate)}', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 8),
                            Text('Total Revenue Activities: ${revenueActivities.length}', style: const TextStyle(color: Colors.greenAccent, fontSize: 14)),
                            Text('Total Non-Revenue Activities: ${nonRevenueActivities.length}', style: const TextStyle(color: Colors.amber, fontSize: 14)),
                            Text('Total Revenue: R ${totalRevenue.toStringAsFixed(2)}', style: const TextStyle(color: Colors.greenAccent, fontSize: 15, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
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
