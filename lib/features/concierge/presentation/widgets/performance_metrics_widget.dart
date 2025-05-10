import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:math' show max;

import '../../../../core/constants/colors.dart';

class PerformanceMetricsWidget extends StatefulWidget {
  final String conciergeId;
  final DateTime selectedDate;
  final Map<String, dynamic>? metricsData;

  const PerformanceMetricsWidget({
    Key? key,
    required this.conciergeId,
    required this.selectedDate,
    this.metricsData,
  }) : super(key: key);

  @override
  State<PerformanceMetricsWidget> createState() => _PerformanceMetricsWidgetState();
}

class _PerformanceMetricsWidgetState extends State<PerformanceMetricsWidget> {
  bool _isLoading = true;
  Map<String, dynamic> _metrics = {};
  
  @override
  void initState() {
    super.initState();
    // If metrics data is provided, use it, otherwise load from Firestore
    if (widget.metricsData != null && widget.metricsData!.isNotEmpty) {
      setState(() {
        _metrics = widget.metricsData!;
        _isLoading = false;
      });
    } else {
      _loadMetrics();
    }
  }
  
  @override
  void didUpdateWidget(PerformanceMetricsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // If new metrics data is provided, update state
    if (widget.metricsData != null && 
        (oldWidget.metricsData == null || 
         oldWidget.metricsData.toString() != widget.metricsData.toString())) {
      setState(() {
        _metrics = widget.metricsData!;
        _isLoading = false;
      });
      return;
    }
    
    // Otherwise, reload metrics if needed
    if (oldWidget.selectedDate != widget.selectedDate || 
        oldWidget.conciergeId != widget.conciergeId) {
      _loadMetrics();
    }
  }
  
  @override
  void dispose() {
    super.dispose();
  }
  
  Future<void> _loadMetrics() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      // Get start and end date for the selected date
      final selectedDate = widget.selectedDate;
      final startDate = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
      final endDate = startDate.add(const Duration(days: 1));
      
      print('Loading metrics for concierge ${widget.conciergeId} on ${DateFormat('yyyy-MM-dd').format(startDate)}');
      
      // Get appointments for the day - using appointmentTime instead of appointmentDate
      final appointmentSnapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .where('conciergeId', isEqualTo: widget.conciergeId)
          .where('appointmentTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('appointmentTime', isLessThan: Timestamp.fromDate(endDate))
          .get();
      
      print('Found ${appointmentSnapshot.docs.length} appointments');
      
      // Calculate metrics based on appointments
      final totalAppointments = appointmentSnapshot.docs.length;
      int completedAppointments = 0;
      int totalDuration = 0;
      double avgDuration = 0;
      
      for (var doc in appointmentSnapshot.docs) {
        final data = doc.data();
        final status = data['status'] ?? '';
        
        if (status == 'completed') {
          completedAppointments++;
          
          // Calculate appointment duration if available
          if (data['startTime'] != null && data['endTime'] != null) {
            final startTime = (data['startTime'] as Timestamp).toDate();
            final endTime = (data['endTime'] as Timestamp).toDate();
            final durationMinutes = endTime.difference(startTime).inMinutes;
            totalDuration += durationMinutes;
          }
        }
      }
      
      // Calculate average duration if there are completed appointments
      if (completedAppointments > 0) {
        avgDuration = totalDuration / completedAppointments;
      }
      
      // Get clock-in/out data from staff_activities
      final clockInSnapshot = await FirebaseFirestore.instance
          .collection('staff_activities')
          .where('staffId', isEqualTo: widget.conciergeId)
          .where('activityType', isEqualTo: 'clock_in')
          .where('date', isEqualTo: Timestamp.fromDate(startDate))
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();
      
      // Get clock-out data
      final clockOutSnapshot = await FirebaseFirestore.instance
          .collection('staff_activities')
          .where('staffId', isEqualTo: widget.conciergeId)
          .where('activityType', isEqualTo: 'clock_out')
          .where('date', isEqualTo: Timestamp.fromDate(startDate))
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();
      
      // Calculate hours worked
      int hoursWorked = 0;
      if (clockInSnapshot.docs.isNotEmpty) {
        DateTime clockInTime = (clockInSnapshot.docs.first.data()['timestamp'] as Timestamp).toDate();
        
        DateTime clockOutTime;
        if (clockOutSnapshot.docs.isNotEmpty) {
          // Use clock-out time if available
          clockOutTime = (clockOutSnapshot.docs.first.data()['timestamp'] as Timestamp).toDate();
        } else {
          // Use current time if no clock-out
          clockOutTime = DateTime.now();
        }
        
        // Calculate total minutes worked
        final minutesWorked = clockOutTime.difference(clockInTime).inMinutes;
        
        // Get break time
        final breakSnapshot = await FirebaseFirestore.instance
            .collection('staff_activities')
            .where('staffId', isEqualTo: widget.conciergeId)
            .where('activityType', whereIn: ['break_start', 'break_end'])
            .where('date', isEqualTo: Timestamp.fromDate(startDate))
            .orderBy('timestamp')
            .get();
        
        // Calculate break minutes
        List<DateTime> breakStarts = [];
        List<DateTime> breakEnds = [];
        int totalBreakMinutes = 0;
        
        for (var doc in breakSnapshot.docs) {
          final data = doc.data();
          final activityType = data['activityType'] as String;
          final timestamp = (data['timestamp'] as Timestamp).toDate();
          
          if (activityType == 'break_start') {
            breakStarts.add(timestamp);
          } else if (activityType == 'break_end') {
            breakEnds.add(timestamp);
          }
        }
        
        // Match break starts with ends
        for (int i = 0; i < breakStarts.length; i++) {
          if (i < breakEnds.length) {
            totalBreakMinutes += breakEnds[i].difference(breakStarts[i]).inMinutes;
          } else {
            // If no matching end, assume break is until current time or clock-out
            final endTime = clockOutTime.isBefore(DateTime.now()) ? clockOutTime : DateTime.now();
            totalBreakMinutes += endTime.difference(breakStarts[i]).inMinutes;
          }
        }
        
        // Adjust work time by subtracting breaks
        final adjustedMinutesWorked = max(0, minutesWorked - totalBreakMinutes);
        hoursWorked = (adjustedMinutesWorked / 60).floor();
        
        print('Minutes worked: $minutesWorked, Break minutes: $totalBreakMinutes, Adjusted: $adjustedMinutesWorked');
        
        // Update metrics
        setState(() {
          _metrics = {
            'totalAppointments': totalAppointments,
            'completedAppointments': completedAppointments,
            'completionRate': totalAppointments > 0 ? (completedAppointments / totalAppointments) * 100 : 0,
            'hoursWorked': hoursWorked,
            'avgDuration': avgDuration,
            'totalBreakMinutes': totalBreakMinutes,
            // Default values for ratings
            'avgRating': 0.0,
            'totalRatings': 0,
          };
          _isLoading = false;
        });
      } else {
        // No clock-in data for today
        setState(() {
          _metrics = {
            'totalAppointments': totalAppointments,
            'completedAppointments': completedAppointments,
            'completionRate': totalAppointments > 0 ? (completedAppointments / totalAppointments) * 100 : 0,
            'hoursWorked': 0,
            'avgDuration': avgDuration,
            'totalBreakMinutes': 0,
            'avgRating': 0.0,
            'totalRatings': 0,
          };
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading metrics: $e');
      setState(() {
        _isLoading = false;
        _metrics = {
          'totalAppointments': 0,
          'completedAppointments': 0,
          'completionRate': 0,
          'hoursWorked': 0,
          'avgDuration': 0,
          'totalBreakMinutes': 0,
          'avgRating': 0.0,
          'totalRatings': 0,
        };
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.black87,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade800),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isLoading
            ? const Center(
                child: SizedBox(
                  height: 150,
                  child: CircularProgressIndicator(
                    color: Color(0xFFD4AF37),
                  ),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Performance Metrics',
                        style: TextStyle(
                          color: Color(0xFFD4AF37),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        DateFormat('MMM d, yyyy').format(widget.selectedDate),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12.0,
                    runSpacing: 16.0,
                    alignment: WrapAlignment.spaceAround,
                    children: [
                      _buildMetricItem(
                        'Appointments',
                        '${_metrics['completedAppointments'] ?? 0}/${_metrics['totalAppointments'] ?? 0}',
                        Icons.calendar_today,
                      ),
                      _buildMetricItem(
                        'Completion',
                        '${(_metrics['completionRate'] ?? 0).toStringAsFixed(0)}%',
                        Icons.check_circle,
                      ),
                      _buildMetricItem(
                        'Hours Worked',
                        '${_metrics['hoursWorked'] ?? 0}h',
                        Icons.access_time,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12.0,
                    runSpacing: 16.0,
                    alignment: WrapAlignment.spaceAround,
                    children: [
                      _buildMetricItem(
                        'Avg Duration',
                        '${(_metrics['avgDuration'] ?? 0).toStringAsFixed(0)}m',
                        Icons.hourglass_bottom,
                      ),
                      _buildMetricItem(
                        'Break Time',
                        '${_metrics['totalBreakMinutes'] ?? 0}m',
                        Icons.free_breakfast,
                      ),
                      _buildMetricItem(
                        'Rating',
                        (_metrics['totalRatings'] ?? 0) > 0
                            ? '${(_metrics['avgRating'] ?? 0).toStringAsFixed(1)}/5'
                            : 'N/A',
                        Icons.star,
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
  
  Widget _buildMetricItem(String label, String value, IconData icon) {
    return SizedBox(
      width: 80,
      child: Column(
        children: [
          Icon(
            icon,
            color: const Color(0xFFD4AF37),
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
