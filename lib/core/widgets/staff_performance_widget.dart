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
  Widget _buildStatusChip(String status) {
    Color color;
    String label;
    switch (status.toLowerCase()) {
      case 'pending':
        color = Colors.orange;
        label = 'Pending';
        break;
      case 'in-progress':
        color = Colors.green;
        label = 'In Progress';
        break;
      case 'completed':
        color = Colors.blue;
        label = 'Completed';
        break;
      case 'cancelled':
        color = Colors.red;
        label = 'Cancelled';
        break;
      default:
        color = Colors.grey;
        label = status.isNotEmpty ? status.substring(0, 1).toUpperCase() + status.substring(1) : 'Unknown';
    }
    return Container(
      width: 90,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildMetricBlock(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$value', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 20)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      ),
    );
  }

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
            .collection('appointments')
            .where(_role == 'consultant' ? 'consultantId' : _role == 'concierge' ? 'conciergeId' : 'cleanerId', isEqualTo: _userId)
            .where('appointmentTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
            .where('appointmentTime', isLessThan: Timestamp.fromDate(DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1)))
            .orderBy('appointmentTime', descending: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No performance data for this month.', style: TextStyle(color: Colors.white54)));
          }
          final docs = snapshot.data!.docs;

          // Aggregate metrics
          int totalAppointments = docs.length;
          int completedAppointments = 0;
          int inProgressAppointments = 0;
          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            if (data['endTime'] != null) {
              completedAppointments++;
            } else if (data['startTime'] != null) {
              inProgressAppointments++;
            }
          }
          int completionRate = totalAppointments > 0 ? ((completedAppointments / totalAppointments) * 100).round() : 0;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(child: _buildMetricBlock('Total', totalAppointments, Colors.amber)),
                    Expanded(child: _buildMetricBlock('Completed', completedAppointments, Colors.greenAccent)),
                    Expanded(child: _buildMetricBlock('In Progress', inProgressAppointments, Colors.blueAccent)),
                    Expanded(child: _buildMetricBlock('Completion %', completionRate, Colors.deepPurpleAccent)),
                  ],
                ),
              ),
              const Divider(color: Colors.white12),
              Expanded(
                child: ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final data = docs[i].data() as Map<String, dynamic>;
                    final apptTime = data['appointmentTime'] is Timestamp
                        ? (data['appointmentTime'] as Timestamp).toDate()
                        : data['appointmentTime'] is DateTime
                            ? data['appointmentTime']
                            : null;
                    if (apptTime == null) return const SizedBox();
                    final status = data['endTime'] != null
                        ? 'Completed'
                        : data['startTime'] != null
                            ? 'In Progress'
                            : 'Pending';
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
                                Text(DateFormat('EEEE, d MMM yyyy – HH:mm').format(apptTime), style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 16)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('Status: $status', style: const TextStyle(color: Colors.white, fontSize: 14)),
                            if (data['description'] != null) ...[
                              const SizedBox(height: 4),
                              Text(data['description'], style: const TextStyle(color: Colors.white70, fontSize: 14)),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      backgroundColor: Colors.black,
    );
  }
}
