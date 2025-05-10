import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class StaffDailyActivitiesListWidget extends StatelessWidget {
  final String userId;
  final DateTime selectedDate;
  const StaffDailyActivitiesListWidget({Key? key, required this.userId, required this.selectedDate}) : super(key: key);

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
                const Icon(Icons.list_alt, color: Colors.amber),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'My Daily Activities',
                    style: TextStyle(color: Colors.amber[700], fontWeight: FontWeight.bold, fontSize: 18),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Spacer(),
                Text(DateFormat('yyyy-MM-dd').format(selectedDate), style: const TextStyle(color: Colors.white70)),
              ],
            ),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('staff_activities')
                  .where('userId', isEqualTo: userId)
                  .where('date', isGreaterThanOrEqualTo: DateTime(selectedDate.year, selectedDate.month, selectedDate.day))
                  .where('date', isLessThan: DateTime(selectedDate.year, selectedDate.month, selectedDate.day + 1))
                  .orderBy('date', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.amber));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(18.0),
                    child: Text('No activities for this day.', style: TextStyle(color: Colors.white54)),
                  );
                }
                final docs = snapshot.data!.docs;
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(color: Colors.white12),
                  itemBuilder: (context, i) {
                    final doc = docs[i];
                    final data = doc.data() as Map<String, dynamic>;
                    return Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Colors.amber, width: 2),
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
    Icon(data['isSale'] == true ? Icons.attach_money : Icons.work, color: data['isSale'] == true ? Colors.green : Colors.amber),
    const SizedBox(width: 12),
    Expanded(
      child: Text(
        data['description'] ?? '',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
      ),
    ),
  ],
),
const SizedBox(height: 4),
Row(
  children: [
    Icon(Icons.calendar_today, size: 16, color: Colors.amber[700]),
    const SizedBox(width: 6),
    Text(
      () {
        final date = data['date'];
        if (date == null) return '';
        final dt = date is Timestamp ? date.toDate() : date as DateTime;
        return DateFormat('d MMM yyyy, HH:mm').format(dt);
      }(),
      style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13),
    ),
  ],
),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.info_outline, size: 16, color: Colors.blueAccent),
                                const SizedBox(width: 6),
                                Text(
                                  data['isSale'] == true ? 'Sale' : 'Other',
                                  style: TextStyle(color: data['isSale'] == true ? Colors.green : Colors.amber, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.monetization_on, size: 16, color: Colors.greenAccent),
                                const SizedBox(width: 6),
                                Text(
                                  'R ${data['revenue']?.toStringAsFixed(2) ?? '0.00'}',
                                  style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 15),
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
