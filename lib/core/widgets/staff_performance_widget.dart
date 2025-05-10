import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StaffPerformanceWidget extends StatefulWidget {
  final String? userId;
  final String? role;
  const StaffPerformanceWidget({Key? key, this.userId, this.role}) : super(key: key);

  @override
  State<StaffPerformanceWidget> createState() => _StaffPerformanceWidgetState();
}

class _StaffPerformanceWidgetState extends State<StaffPerformanceWidget> {
  late DateTime _selectedMonth;
  String? _userId;
  String? _role;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
    _initUser();
  }

  Future<void> _initUser() async {
    if (widget.userId != null && widget.role != null) {
      setState(() {
        _userId = widget.userId;
        _role = widget.role;
        _loading = false;
      });
      return;
    }
    // Fetch from FirebaseAuth and Firestore
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() { _loading = false; });
      return;
    }
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    setState(() {
      _userId = user.uid;
      _role = userDoc.data()?['role'] ?? '';
      _loading = false;
    });
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(DateTime.now().year - 3, 1),
      lastDate: DateTime(DateTime.now().year + 1, 12, 31),
      selectableDayPredicate: (date) => date.day == 1,
      helpText: 'Select Month',
      fieldLabelText: 'Month',
      fieldHintText: 'Month/Year',
      initialEntryMode: DatePickerEntryMode.calendar,
    );
    if (picked != null) {
      setState(() {
        _selectedMonth = DateTime(picked.year, picked.month);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_userId == null || _role == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: Text('User not found', style: TextStyle(color: Colors.white54))),
      );
    }
    final startOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final endOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1).subtract(const Duration(days: 1));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Performance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: _pickMonth,
            tooltip: 'Select Month',
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('staff_activities')
            .where('userId', isEqualTo: _userId)
            .where('date', isGreaterThanOrEqualTo: startOfMonth)
            .where('date', isLessThan: DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1))
            .orderBy('date', descending: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No performance data for this month.', style: TextStyle(color: Colors.white54)));
          }
          final docs = snapshot.data!.docs;
          final Map<String, List<Map<String, dynamic>>> dailyMap = {};
          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final date = data['date'];
            DateTime dt;
            if (date is Timestamp) {
              dt = date.toDate();
            } else if (date is DateTime) {
              dt = date;
            } else {
              continue;
            }
            final key = DateFormat('yyyy-MM-dd').format(dt);
            dailyMap.putIfAbsent(key, () => []).add(data);
          }
          final sortedDays = dailyMap.keys.toList()..sort();
          return ListView.builder(
            itemCount: sortedDays.length,
            itemBuilder: (context, i) {
              final day = sortedDays[i];
              final activities = dailyMap[day]!;
              final totalRevenue = activities.fold<num>(0, (sum, d) => sum + (d['revenue'] is num ? d['revenue'] : 0));
              final revenueActivities = activities.where((d) => d['revenue'] != null && (d['revenue'] is num ? d['revenue'] > 0 : false)).toList();
              final nonRevenueActivities = activities.where((d) => d['revenue'] == null || (d['revenue'] is num && d['revenue'] == 0)).toList();
              return Card(
                color: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.amber, width: 2)),
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.calendar_today, color: Colors.amber[700]),
                          const SizedBox(width: 8),
                          Text(DateFormat('EEEE, d MMM yyyy').format(DateTime.parse(day)), style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                      const SizedBox(height: 8),
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
                  ),
                ),
              );
            },
          );
        },
      ),
      backgroundColor: Colors.black,
    );
  }
}
