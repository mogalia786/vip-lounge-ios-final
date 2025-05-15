import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/colors.dart';

class ConciergePerformanceMetricsWidget extends StatefulWidget {
  final String conciergeId;
  final DateTime selectedDate;
  final String timeframe;

  const ConciergePerformanceMetricsWidget({
    Key? key,
    required this.conciergeId,
    required this.selectedDate,
    required this.timeframe,
  }) : super(key: key);

  @override
  State<ConciergePerformanceMetricsWidget> createState() => _ConciergePerformanceMetricsWidgetState();
}

class _ConciergePerformanceMetricsWidgetState extends State<ConciergePerformanceMetricsWidget> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _appointments = [];
  Map<String, List<Map<String, dynamic>>> _ministerAppointments = {};
  List<Map<String, dynamic>> _futureAppointments = [];

  @override
  void initState() {
    super.initState();
    _fetchAppointments();
  }

  @override
  void didUpdateWidget(covariant ConciergePerformanceMetricsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.timeframe != widget.timeframe || oldWidget.selectedDate != widget.selectedDate) {
      _fetchAppointments();
    }
  }

  DateTime _getRangeStart() {
    final d = widget.selectedDate;
    switch (widget.timeframe) {
      case 'Year':
        return DateTime(d.year, 1, 1);
      case 'Month':
        return DateTime(d.year, d.month, 1);
      case 'Week':
        return d.subtract(Duration(days: d.weekday - 1));
      case 'Future':
        return d.add(const Duration(days: 1));
      default:
        return d;
    }
  }

  DateTime _getRangeEnd() {
    final d = widget.selectedDate;
    switch (widget.timeframe) {
      case 'Year':
        return DateTime(d.year + 1, 1, 1);
      case 'Month':
        return DateTime(d.year, d.month + 1, 1);
      case 'Week':
        return d.add(Duration(days: 8 - d.weekday));
      case 'Future':
        return d.add(const Duration(days: 365));
      default:
        return d.add(const Duration(days: 1));
    }
  }

  Future<void> _fetchAppointments() async {
    setState(() { _isLoading = true; });
    final start = _getRangeStart();
    final end = _getRangeEnd();
    final futureStart = DateTime.now().add(const Duration(days: 1));
    try {
      final query1 = await FirebaseFirestore.instance
          .collection('appointments')
          .where('conciergeId', isEqualTo: widget.conciergeId)
          .get();
      final query2 = await FirebaseFirestore.instance
          .collection('appointments')
          .where('assignedConciergeId', isEqualTo: widget.conciergeId)
          .get();
      final docs = [...query1.docs, ...query2.docs];
      final Set<String> seenIds = {};
      final List<Map<String, dynamic>> appointments = [];
      final List<Map<String, dynamic>> futureAppointments = [];
      for (var doc in docs) {
        if (seenIds.contains(doc.id)) continue;
        seenIds.add(doc.id);
        final data = Map<String, dynamic>.from(doc.data() as Map);
        final apptTime = (data['appointmentTime'] is Timestamp)
            ? (data['appointmentTime'] as Timestamp).toDate()
            : (data['appointmentTime'] is DateTime)
                ? data['appointmentTime']
                : null;
        if (apptTime == null) continue;
        data['appointmentTime'] = apptTime;
        if (apptTime.isAfter(futureStart)) {
          futureAppointments.add({...data, 'docId': doc.id});
        } else if (apptTime.isAfter(start) && apptTime.isBefore(end)) {
          appointments.add({...data, 'docId': doc.id});
        }
      }
      // Group by minister
      final Map<String, List<Map<String, dynamic>>> ministerMap = {};
      for (final appt in appointments) {
        final ministerName = appt['ministerName'] ??
  (appt['minister'] != null && appt['minister']['name'] != null ? appt['minister']['name'] : null) ??
  (((appt['ministerFirstName'] ?? '') + ' ' + (appt['ministerLastName'] ?? '')).trim().isNotEmpty
    ? ((appt['ministerFirstName'] ?? '') + ' ' + (appt['ministerLastName'] ?? '')).trim()
    : 'Unknown Minister');
        ministerMap.putIfAbsent(ministerName, () => []).add(appt);
      }
      setState(() {
        _appointments = appointments;
        _futureAppointments = futureAppointments;
        _ministerAppointments = ministerMap;
        _isLoading = false;
      });
    } catch (e) {
      setState(() { _isLoading = false; });
    }
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String label;
    switch (status.toLowerCase()) {
      case 'pending':
        color = Colors.orange;
        label = 'Pending';
        break;
      case 'in-progress':
      case 'in_progress':
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
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildMinisterSection(String ministerName, List<Map<String, dynamic>> appts) {
    return Card(
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: AppColors.gold.withOpacity(0.3))),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ministerName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.gold),
            ),
            ...appts.map((appt) => Row(
                  children: [
                    Expanded(
                      child: Text(
                        DateFormat('MMM d, h:mm a').format(appt['appointmentTime']),
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ),
                    _buildStatusChip(appt['status'] ?? ''),
                  ],
                )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    // Calculate status breakdowns
    final int completedCount = _appointments.where((a) => (a['status'] ?? '').toLowerCase().contains('completed')).length;
    final int cancelledCount = _appointments.where((a) => (a['status'] ?? '').toLowerCase().contains('cancel')).length;
    final int pendingCount = _appointments.where((a) {
      final status = (a['status'] ?? '').toLowerCase();
      return !(status.contains('completed') || status.contains('cancel'));
    }).length;
    final int totalCount = completedCount + cancelledCount + pendingCount;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Row(
              children: [
                Flexible(child: _buildSummaryCard('Total', totalCount, AppColors.gold)),
                SizedBox(width: 8),
                Flexible(child: _buildSummaryCard('Pending', pendingCount, Colors.orange)),
                SizedBox(width: 8),
                Flexible(child: _buildSummaryCard('Completed', completedCount, Colors.blue)),
                SizedBox(width: 8),
                Flexible(child: _buildSummaryCard('Cancelled', cancelledCount, Colors.red)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Performance Breakdown by Minister',
              style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: _ministerAppointments.length,
            itemBuilder: (context, index) {
              final entry = _ministerAppointments.entries.elementAt(index);
              return _buildMinisterSection(entry.key, entry.value);
            },
          ),
          if (_futureAppointments.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 16.0, top: 16.0, bottom: 8.0),
              child: Text('Future Appointments', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ..._groupFutureAppointmentsByMinister().entries.map((entry) {
            final ministerName = entry.key;
            final appts = entry.value;
            return Card(
              color: Colors.grey[900],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: AppColors.gold.withOpacity(0.3))),
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ministerName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.gold),
                    ),
                    ...appts.map((appt) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(DateFormat('MMM d, yyyy h:mm a').format(appt['appointmentTime']), style: const TextStyle(color: Colors.white70)),
                          trailing: _buildStatusChip(appt['status'] ?? ''),
                        )),
                  ],
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String label, int value, Color color) {
    return Card(
      color: color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: EdgeInsets.zero,
      child: Container(
        constraints: BoxConstraints(minHeight: 90),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        alignment: Alignment.center,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                value.toString(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 10),
                textAlign: TextAlign.center,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Map<String, List<Map<String, dynamic>>> _groupFutureAppointmentsByMinister() {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final appt in _futureAppointments) {
      String ministerName = appt['ministerName'] ??
        (appt['minister'] != null && appt['minister']['name'] != null ? appt['minister']['name'] : null) ??
        (((appt['ministerFirstName'] ?? '') + ' ' + (appt['ministerLastName'] ?? '')).trim().isNotEmpty
          ? ((appt['ministerFirstName'] ?? '') + ' ' + (appt['ministerLastName'] ?? '')).trim()
          : 'Unknown Minister');
      grouped.putIfAbsent(ministerName, () => []).add(appt);
    }
    return grouped;
  }
}
