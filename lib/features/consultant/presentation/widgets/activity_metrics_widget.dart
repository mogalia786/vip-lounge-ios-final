import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ActivityMetricsWidget extends StatefulWidget {
  final String userId;

  const ActivityMetricsWidget({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  State<ActivityMetricsWidget> createState() => _ActivityMetricsWidgetState();
}

class _ActivityMetricsWidgetState extends State<ActivityMetricsWidget> {
  bool _isLoading = true;
  int _totalHours = 0;
  int _totalBreakMinutes = 0;
  DateTime? _firstClockIn;
  DateTime? _lastClockOut;

  @override
  void initState() {
    super.initState();
    _loadActivityMetrics();
  }

  Future<void> _loadActivityMetrics() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get today's date boundaries
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      // Query attendance records for today
      final attendanceQuery = await FirebaseFirestore.instance
          .collection('attendance')
          .where('userId', isEqualTo: widget.userId)
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('timestamp', isLessThan: Timestamp.fromDate(endOfDay))
          .orderBy('timestamp')
          .get();

      if (attendanceQuery.docs.isNotEmpty) {
        DateTime? lastClockIn;
        
        for (var doc in attendanceQuery.docs) {
          final data = doc.data();
          final timestamp = (data['timestamp'] as Timestamp).toDate();
          final action = data['action'] as String;
          
          if (action == 'clock_in') {
            if (_firstClockIn == null) {
              _firstClockIn = timestamp;
            }
            lastClockIn = timestamp;
          } else if (action == 'clock_out' && lastClockIn != null) {
            final duration = timestamp.difference(lastClockIn).inMinutes;
            _totalHours += duration ~/ 60;
            _lastClockOut = timestamp;
            lastClockIn = null;
          }
        }

        // If there's a clock-in without a clock-out, calculate up to now
        if (lastClockIn != null) {
          final duration = DateTime.now().difference(lastClockIn).inMinutes;
          _totalHours += duration ~/ 60;
        }
      }

      // Query break records for today
      final breakQuery = await FirebaseFirestore.instance
          .collection('breaks')
          .where('userId', isEqualTo: widget.userId)
          .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('startTime', isLessThan: Timestamp.fromDate(endOfDay))
          .get();

      for (var doc in breakQuery.docs) {
        final data = doc.data();
        final startTime = (data['startTime'] as Timestamp).toDate();
        DateTime endTime;
        
        if (data['endTime'] != null) {
          endTime = (data['endTime'] as Timestamp).toDate();
        } else {
          // If break hasn't ended, calculate up to now
          endTime = DateTime.now();
        }
        
        final breakDuration = endTime.difference(startTime).inMinutes;
        _totalBreakMinutes += breakDuration;
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading activity metrics: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      color: Colors.black,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.amber[700]!, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Today\'s Activity',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.amber[700],
              ),
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                ),
              )
            else
              Column(
                children: [
                  _buildMetricRow(
                    icon: Icons.access_time,
                    label: 'Hours Worked',
                    value: '$_totalHours hours',
                  ),
                  const SizedBox(height: 8),
                  _buildMetricRow(
                    icon: Icons.coffee,
                    label: 'Break Time',
                    value: '${_totalBreakMinutes ~/ 60}h ${_totalBreakMinutes % 60}m',
                  ),
                  const SizedBox(height: 8),
                  _buildMetricRow(
                    icon: Icons.login,
                    label: 'First Clock-in',
                    value: _firstClockIn != null 
                        ? DateFormat('h:mm a').format(_firstClockIn!) 
                        : 'Not yet clocked in',
                  ),
                  const SizedBox(height: 8),
                  _buildMetricRow(
                    icon: Icons.logout,
                    label: 'Last Clock-out',
                    value: _lastClockOut != null 
                        ? DateFormat('h:mm a').format(_lastClockOut!) 
                        : 'Not yet clocked out',
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: Colors.amber[700],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
