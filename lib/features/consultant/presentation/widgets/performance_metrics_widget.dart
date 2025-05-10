import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../../../core/constants/colors.dart';

class PerformanceMetricsWidget extends StatefulWidget {
  final String consultantId;
  final DateTime selectedDate;
  final Map<String, dynamic>? metricsData;

  const PerformanceMetricsWidget({
    Key? key,
    required this.consultantId,
    required this.selectedDate,
    this.metricsData,
  }) : super(key: key);

  @override
  State<PerformanceMetricsWidget> createState() => _PerformanceMetricsWidgetState();
}

class _PerformanceMetricsWidgetState extends State<PerformanceMetricsWidget> {
  Map<String, dynamic> _metrics = {};
  bool _isLoading = true;
  StreamSubscription? _appointmentsSubscription;
  StreamSubscription? _activitiesSubscription;
  
  @override
  void initState() {
    super.initState();
    _setupRealTimeMetrics();
  }
  
  @override
  void dispose() {
    _appointmentsSubscription?.cancel();
    _activitiesSubscription?.cancel();
    super.dispose();
  }
  
  void _setupRealTimeMetrics() {
    final today = widget.selectedDate;
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    
    // Set up real-time listener for appointments
    _appointmentsSubscription = FirebaseFirestore.instance
        .collection('appointments')
        .where('consultantId', isEqualTo: widget.consultantId)
        .where('appointmentTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('appointmentTime', isLessThan: Timestamp.fromDate(endOfDay))
        .snapshots()
        .listen((snapshot) {
          _updateMetricsFromAppointments(snapshot.docs);
        });
    
    // Set up real-time listener for break activities
    _activitiesSubscription = FirebaseFirestore.instance
        .collection('staff_activities')
        .where('staffId', isEqualTo: widget.consultantId)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('timestamp', isLessThan: Timestamp.fromDate(endOfDay))
        .snapshots()
        .listen((snapshot) {
          _updateMetricsFromActivities(snapshot.docs);
        });
  }
  
  void _updateMetricsFromAppointments(List<QueryDocumentSnapshot> appointmentDocs) {
    int totalAppointments = appointmentDocs.length;
    int completedAppointments = 0;
    int inProgressAppointments = 0;
    
    for (var doc in appointmentDocs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['endTime'] != null) {
        completedAppointments++;
      } else if (data['startTime'] != null) {
        inProgressAppointments++;
      }
    }
    
    setState(() {
      _metrics['totalAppointments'] = totalAppointments;
      _metrics['completedAppointments'] = completedAppointments;
      _metrics['inProgressAppointments'] = inProgressAppointments;
      _metrics['completionRate'] = totalAppointments > 0
          ? (completedAppointments / totalAppointments * 100).round()
          : 0;
      _isLoading = false;
    });
  }
  
  void _updateMetricsFromActivities(List<QueryDocumentSnapshot> activityDocs) {
    int totalBreakMinutes = 0;
    
    for (var doc in activityDocs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['activityType'] == 'break' && data['durationMinutes'] != null) {
        totalBreakMinutes += (data['durationMinutes'] as num).toInt();
      }
    }
    
    setState(() {
      _metrics['breakMinutes'] = totalBreakMinutes;
      _isLoading = false;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    // Use passed metrics data if available, otherwise use our collected data
    final metricsData = widget.metricsData ?? _metrics;
    
    if (_isLoading && metricsData.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.gold),
        ),
      );
    }
    
    // Extract metrics with fallbacks to 0
    final totalAppointments = metricsData['totalAppointments'] ?? 0;
    final completedAppointments = metricsData['completedAppointments'] ?? 0;
    final inProgressAppointments = metricsData['inProgressAppointments'] ?? 0;
    final breakMinutes = metricsData['breakMinutes'] ?? 0;
    final completionRate = metricsData['completionRate'] ?? 0;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Performance Dashboard',
            style: TextStyle(
              color: AppColors.gold,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          Text(
            DateFormat('EEEE, MMMM d, yyyy').format(widget.selectedDate),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          
          // Main metrics
          Row(
            children: [
              _buildMetricCard(
                'Appointments',
                '$totalAppointments',
                Icons.calendar_today,
                Colors.blue,
              ),
              const SizedBox(width: 12),
              _buildMetricCard(
                'Completed',
                '$completedAppointments',
                Icons.check_circle,
                Colors.green,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildMetricCard(
                'In Progress',
                '$inProgressAppointments',
                Icons.access_time,
                Colors.orange,
              ),
              const SizedBox(width: 12),
              _buildMetricCard(
                'Break Time',
                '${breakMinutes}m',
                Icons.free_breakfast,
                Colors.purple,
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Completion rate
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Completion Rate',
                style: TextStyle(
                  color: AppColors.gold,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: completionRate / 100,
                  backgroundColor: Colors.grey.shade800,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _getProgressColor(completionRate),
                  ),
                  minHeight: 24,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Align(
                  alignment: Alignment.center,
                  child: Text(
                    '$completionRate%',
                    style: TextStyle(
                      color: _getProgressColor(completionRate),
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.5), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Color _getProgressColor(int percentage) {
    if (percentage < 30) return Colors.red;
    if (percentage < 70) return Colors.orange;
    return Colors.green;
  }
}
