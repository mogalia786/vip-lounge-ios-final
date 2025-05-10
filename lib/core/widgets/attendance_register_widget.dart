import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// AttendanceRegisterWidget
/// Shows a daily breakdown and monthly summary of hours worked, clock-in/out times, breaks, and warnings for missing actions.
/// Usage: AttendanceRegisterWidget(uid: ..., month: DateTime(...))
class AttendanceRegisterWidget extends StatefulWidget {
  final String uid;
  final DateTime month; // Use DateTime(year, month)
  final TimeOfDay businessDayEnd;

  const AttendanceRegisterWidget({
    Key? key,
    required this.uid,
    required this.month,
    this.businessDayEnd = const TimeOfDay(hour: 18, minute: 0), // Default 18:00
  }) : super(key: key);

  @override
  State<AttendanceRegisterWidget> createState() => _AttendanceRegisterWidgetState();
}

class _AttendanceRegisterWidgetState extends State<AttendanceRegisterWidget> {
  late DateTime _startOfMonth;
  late DateTime _endOfMonth;

  @override
  void initState() {
    super.initState();
    _startOfMonth = DateTime(widget.month.year, widget.month.month, 1);
    _endOfMonth = DateTime(widget.month.year, widget.month.month + 1, 0); // Last day of month
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Attendance Register')),
      body: FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance
            .collectionGroup('logs')
            .where('userId', isEqualTo: widget.uid)
            .where('date', isGreaterThanOrEqualTo: DateFormat('yyyy-MM-dd').format(_startOfMonth))
            .where('date', isLessThanOrEqualTo: DateFormat('yyyy-MM-dd').format(_endOfMonth))
            .orderBy('date')
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('No attendance data found.'));
          }
          final docs = snapshot.data!.docs;
          print('[ATTENDANCE DEBUG] userId: \'${widget.uid}\'');
          print('[ATTENDANCE DEBUG] Date range: \'${DateFormat('yyyy-MM-dd').format(_startOfMonth)}\' to \'${DateFormat('yyyy-MM-dd').format(_endOfMonth)}\'');
          print('[ATTENDANCE DEBUG] Attendance docs found: \'${docs.length}\'');
          final daysInMonth = List.generate(_endOfMonth.day, (i) => DateTime(_startOfMonth.year, _startOfMonth.month, i + 1));
          // Group all logs by day
          final Map<String, List<Map<String, dynamic>>> dayLogs = {};
          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final dateField = doc['date'];
            String dateKey;
            if (dateField is Timestamp) {
              dateKey = DateFormat('yyyy-MM-dd').format(dateField.toDate());
            } else if (dateField is String) {
              dateKey = dateField;
            } else {
              dateKey = 'unknown';
            }
            dayLogs.putIfAbsent(dateKey, () => []).add(data);
          }

          double totalMonthHours = 0;
          final List<Widget> dayCards = [];

          DateTime? parseDateTime(dynamic value) {
            if (value is Timestamp) return value.toDate();
            if (value is String) {
              try {
                return DateTime.parse(value);
              } catch (_) {
                try {
                  return DateFormat('yyyy-MM-dd HH:mm').parse(value);
                } catch (_) {
                  return null;
                }
              }
            }
            return null;
          }

          for (final day in daysInMonth) {
            final key = DateFormat('yyyy-MM-dd').format(day);
            final logs = dayLogs[key] ?? [];
            if (logs.isEmpty) {
              dayCards.add(_buildDayCard(day, null, null, null, null, null, null, null, 'Did not clock in', null));
              continue;
            }
            // Enforce: cannot go on break if not clocked in
            final hasBreakEvent = logs.any((l) => l['event'] == 'break_start' || l['event'] == 'break_end');
            final hasClockIn = logs.any((l) => l['event'] == 'clock_in');
            if (hasBreakEvent && !hasClockIn) {
              // Just treat as 'Did not clock in', ignore break events
              dayCards.add(_buildDayCard(day, null, null, null, null, null, null, null, 'Did not clock in', null));
              continue;
            }
            // Find clock-in and clock-out from events
            final clockInEvents = logs.where((l) => l['event'] == 'clock_in').toList();
            final clockOutEvents = logs.where((l) => l['event'] == 'clock_out').toList();
            final clockIn = clockInEvents.isNotEmpty ? parseDateTime(clockInEvents.map((e) => e['timestamp']).reduce((a, b) => parseDateTime(a)!.isBefore(parseDateTime(b)!) ? a : b)) : null;
            final clockOut = clockOutEvents.isNotEmpty ? parseDateTime(clockOutEvents.map((e) => e['timestamp']).reduce((a, b) => parseDateTime(a)!.isAfter(parseDateTime(b)!) ? a : b)) : null;
            print('[ATTENDANCE DEBUG] Day: $key | Raw logs: ' + logs.toString() + ' | Parsed clockIn: ' + (clockIn?.toString() ?? 'null'));
            // TODO: add break aggregation if needed
            final breaks = <Map<String, dynamic>>[];
            final isOnBreak = false;
            final breakStart = null;
            final breakReason = null;
            String? warning;
            double workedHours = 0;
            if (clockIn == null) {
              warning = 'Did not clock in';
            } else if (isOnBreak && breakStart != null) {
              workedHours = breakStart.difference(clockIn).inMinutes / 60.0;
              warning = 'On break not ended - hours after break not counted';
            } else if (clockOut == null) {
              final businessDayEnd = DateTime(day.year, day.month, day.day, widget.businessDayEnd.hour, widget.businessDayEnd.minute);
              workedHours = businessDayEnd.difference(clockIn).inMinutes / 60.0;
              warning = 'Did not clock out - using end of business day';
            } else {
              workedHours = clockOut.difference(clockIn).inMinutes / 60.0;
            }
            if (workedHours < 0) workedHours = 0;
            totalMonthHours += workedHours;
            dayCards.add(_buildDayCard(day, clockIn, clockOut, breaks, isOnBreak, breakStart, breakReason, workedHours, warning, totalMonthHours));
          }
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              ...dayCards,
              const SizedBox(height: 24),
              Card(
                color: Colors.blueGrey[900],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Total hours worked this month: ' + totalMonthHours.toStringAsFixed(2),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDayCard(
    DateTime day,
    DateTime? clockIn,
    DateTime? clockOut,
    List<Map<String, dynamic>>? breaks,
    bool? isOnBreak,
    DateTime? breakStart,
    String? breakReason,
    double? workedHours,
    String? warning,
    double? totalMonthHours,
  ) {
    return Card(
      color: warning != null ? Colors.red[900] : Colors.grey[850],
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(DateFormat('EEEE, d MMM yyyy').format(day), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.amber)),
            const SizedBox(height: 6),
            if (clockIn != null) Text('Clock-in: ' + DateFormat('HH:mm').format(clockIn), style: const TextStyle(color: Colors.greenAccent)),
            if (clockOut != null) Text('Clock-out: ' + DateFormat('HH:mm').format(clockOut), style: const TextStyle(color: Colors.cyanAccent)),
            if (breaks != null && breaks.isNotEmpty) ...[
              const SizedBox(height: 6),
              const Text('Breaks:', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
              ...breaks.map((br) {
                final bStart = (br['startTime'] as Timestamp?)?.toDate();
                final bEnd = (br['endTime'] as Timestamp?)?.toDate();
                final reason = br['reason'] ?? '';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Text(
                    '• ${bStart != null ? DateFormat('HH:mm').format(bStart) : '--'} - ${bEnd != null ? DateFormat('HH:mm').format(bEnd) : 'Not ended'} (${reason.isNotEmpty ? reason : 'No reason'})',
                    style: TextStyle(color: bEnd == null ? Colors.redAccent : Colors.orangeAccent),
                  ),
                );
              }).toList(),
            ],
            const SizedBox(height: 6),
            Text('Hours worked: ' + (workedHours != null ? workedHours.toStringAsFixed(2) : '--'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            if (warning != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(warning, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
    );
  }
}
