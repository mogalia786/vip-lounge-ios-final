import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class StaffScheduledActivitiesListWidget extends StatelessWidget {
  final String userId;
  final DateTime selectedDate;
  const StaffScheduledActivitiesListWidget({Key? key, required this.userId, required this.selectedDate}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final start = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, 0, 0, 0);
    final end = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, 23, 59, 59);
    return Card(
      color: Colors.black,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppColors.richGold!, width: 2)),
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.event_note, color: AppColors.richGold),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'My Scheduled Activities',
                    style: TextStyle(color: AppColors.richGold, fontWeight: FontWeight.bold, fontSize: 18),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('staff_todos')
                  .where('userId', isEqualTo: userId)
                  .where('date', isGreaterThanOrEqualTo: start)
                  .where('date', isLessThanOrEqualTo: end)
                  .orderBy('date', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.richGold));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Text('No upcoming scheduled activities.', style: TextStyle(color: Colors.white54));
                }
                final docs = snapshot.data!.docs;
                return ListView.separated(
                  itemCount: docs.length,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  separatorBuilder: (_, __) => const Divider(color: Colors.white12),
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemBuilder: (context, i) {
                    final doc = docs[i];
                    final data = doc.data() as Map<String, dynamic>;
                    return Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: AppColors.richGold, width: 2),
                      ),
                      color: Colors.black,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.event, color: AppColors.richGold),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    data['task'] ?? '',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ),
                                Checkbox(
                                  value: data['completed'] ?? false,
                                  onChanged: null,
                                  activeColor: AppColors.richGold,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.calendar_today, size: 16, color: AppColors.richGold),
                                const SizedBox(width: 6),
                                Text(
                                  (() {
                                    final date = data['date'];
                                    if (date == null) return '';
                                    if (date is Timestamp) {
                                      return DateFormat('d MMM yyyy, HH:mm').format(date.toDate());
                                    } else if (date is DateTime) {
                                      return DateFormat('d MMM yyyy, HH:mm').format(date);
                                    } else {
                                      return date.toString();
                                    }
                                  })(),
                                  style: const TextStyle(color: AppColors.richGold, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            Row(
                              children: [
                                Icon(Icons.info_outline, size: 16, color: Colors.blueAccent),
                                const SizedBox(width: 6),
                                Text(
                                  data['completed'] == true ? 'Completed' : 'Pending',
                                  style: TextStyle(color: data['completed'] == true ? Colors.green : AppColors.richGold, fontWeight: FontWeight.bold, fontSize: 13),
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
          ],
        ),
      ),
    );
  }
}
