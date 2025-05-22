import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/colors.dart';

class FloorManagerQueryInboxScreen extends StatefulWidget {
  const FloorManagerQueryInboxScreen({Key? key}) : super(key: key);

  @override
  State<FloorManagerQueryInboxScreen> createState() => _FloorManagerQueryInboxScreenState();
}

class _FloorManagerQueryInboxScreenState extends State<FloorManagerQueryInboxScreen> {
  DateTimeRange? _selectedRange;
  bool _loading = false;
  List<Map<String, dynamic>> _queries = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedRange = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: now,
    );
    _fetchQueries();
  }

  Future<void> _fetchQueries() async {
    if (_selectedRange == null) return;
    setState(() => _loading = true);
    final start = Timestamp.fromDate(_selectedRange!.start);
    final end = Timestamp.fromDate(_selectedRange!.end.add(const Duration(days: 1)));
    final snapshot = await FirebaseFirestore.instance
        .collection('queries')
        .where('createdAt', isGreaterThanOrEqualTo: start)
        .where('createdAt', isLessThan: end)
        .orderBy('createdAt', descending: true)
        .get();
    _queries = snapshot.docs.map((d) => d.data()).toList();
    setState(() => _loading = false);
  }

  Map<String, List<Map<String, dynamic>>> _groupByStaff(List<Map<String, dynamic>> queries) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var q in queries) {
      final staff = q['assignedToName'] ?? 'Unassigned';
      grouped.putIfAbsent(staff, () => []).add(q);
    }
    return grouped;
  }

  List<Map<String, dynamic>> _getTopStaff(List<Map<String, dynamic>> queries) {
    final Map<String, int> staffCount = {};
    for (var q in queries) {
      final staff = q['assignedToName'] ?? 'Unassigned';
      if (staff == 'Unassigned') continue;
      staffCount[staff] = (staffCount[staff] ?? 0) + 1;
    }
    final sorted = staffCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.map((e) => {'name': e.key, 'count': e.value}).toList();
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupByStaff(_queries);
    final topStaff = _getTopStaff(_queries);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Query Report'),
        backgroundColor: AppColors.black,
        foregroundColor: AppColors.gold,
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range, color: AppColors.gold),
            onPressed: () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2023, 1),
                lastDate: DateTime.now(),
                initialDateRange: _selectedRange,
              );
              if (picked != null) {
                setState(() => _selectedRange = picked);
                _fetchQueries();
              }
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (topStaff.isNotEmpty)
                  Card(
                    color: AppColors.gold.withOpacity(0.15),
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Top Performing Staff', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          const SizedBox(height: 8),
                          ...topStaff.take(3).map((s) => Row(
                                children: [
                                  Icon(Icons.emoji_events, color: AppColors.gold),
                                  const SizedBox(width: 8),
                                  Text('${s['name']}'),
                                  const SizedBox(width: 8),
                                  Text('(${s['count']})', style: const TextStyle(fontWeight: FontWeight.bold)),
                                ],
                              )),
                        ],
                      ),
                    ),
                  ),
                ...grouped.entries.map((entry) {
                  final staff = entry.key;
                  final queries = entry.value;
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF0D1333), Colors.black],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(staff, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.orange)),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.gold,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Text('${queries.length}', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ...queries.map((q) {
  final ministerName = (q['ministerFirstName'] ?? '') + ' ' + (q['ministerLastName'] ?? '');
  final staffName = (q['assignedToName'] ?? '').toString().trim();
  final hasStaff = staffName.isNotEmpty && staffName.toLowerCase() != 'unassigned';
  final queryText = q['query'] ?? '';
  DateTime? staffActionDate;
  if (q['statusHistory'] != null && q['statusHistory'] is List && (q['statusHistory'] as List).isNotEmpty) {
    final attendedHistory = (q['statusHistory'] as List).where((h) => (h['byName'] == staffName)).toList();
    if (attendedHistory.isNotEmpty) {
      attendedHistory.sort((a, b) => (b['timestamp'] as Timestamp).compareTo(a['timestamp'] as Timestamp));
      staffActionDate = (attendedHistory.first['timestamp'] as Timestamp).toDate();
    }
  }
  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.black.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            hasStaff
                ? const Icon(Icons.check_circle, color: AppColors.green)
                : const Icon(Icons.error_outline, color: AppColors.red),
            const SizedBox(width: 8),
            Flexible(
              fit: FlexFit.loose,
              child: Text(
                ministerName,
                style: const TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Staff: ', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13)),
            Text(
              hasStaff ? staffName : 'None',
              style: const TextStyle(color: Color(0xFFFFD700), fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Status: ', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13)),
            Text(q['status'] ?? '', style: const TextStyle(color: Color(0xFFFFD700), fontSize: 14)),
          ],
        ),
        if (!hasStaff)
          const Padding(
            padding: EdgeInsets.only(top: 2.0),
            child: Text('NOT ATTENDED', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Query: ', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13)),
            Flexible(
              fit: FlexFit.loose,
              child: Text(queryText, style: const TextStyle(color: Color(0xFFFFD700), fontSize: 14)),
            ),
          ],
        ),
        if (staffActionDate != null)
          Padding(
            padding: const EdgeInsets.only(top: 2.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Attended on: ', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13)),
                Text(DateFormat('yyyy-MM-dd HH:mm').format(staffActionDate), style: const TextStyle(color: Color(0xFFFFD700), fontSize: 14)),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 2.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Created: ', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13)),
              Text(
                q['createdAt'] != null ? DateFormat('yyyy-MM-dd HH:mm').format((q['createdAt'] as Timestamp).toDate()) : '',
                style: const TextStyle(color: Color(0xFFFFD700), fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}).toList(),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
      );
  }
}
