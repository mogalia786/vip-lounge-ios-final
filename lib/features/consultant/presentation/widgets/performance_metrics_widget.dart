import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../../../core/constants/colors.dart';

class PerformanceMetricsWidget extends StatefulWidget {
  final String consultantId;
  final String? role;
  final DateTime selectedDate;
  final Map<String, dynamic>? metricsData;

  const PerformanceMetricsWidget({
    Key? key,
    required this.consultantId,
    required this.selectedDate,
    this.role,
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
  
  List<Map<String, dynamic>> _appointments = [];
  List<Map<String, dynamic>> _futureAppointments = [];
  bool _isLoadingAppointments = true;
  Set<String>? _allMinisters;

  @override
  void initState() {
    super.initState();
    _setupRealTimeMetrics();
    _fetchAppointmentsByMinister();
  }

  DateTime _getRangeStart() {
    // If selectedDate is start of year/month/week, use that. Otherwise, fallback to start of day.
    final d = widget.selectedDate;
    if (d.day == 1 && d.month == 1) {
      // Year
      return DateTime(d.year, 1, 1);
    } else if (d.day == 1) {
      // Month
      return DateTime(d.year, d.month, 1);
    } else if (d.weekday == DateTime.monday) {
      // Week
      return d;
    }
    return DateTime(d.year, d.month, d.day);
  }

  DateTime _getRangeEnd() {
    final d = widget.selectedDate;
    if (d.day == 1 && d.month == 1) {
      // Year
      return DateTime(d.year + 1, 1, 1);
    } else if (d.day == 1) {
      // Month
      return DateTime(d.year, d.month + 1, 1);
    } else if (d.weekday == DateTime.monday) {
      // Week (assume 7 days)
      return d.add(const Duration(days: 7));
    }
    return DateTime(d.year, d.month, d.day + 1);
  }

  Future<void> _fetchAppointmentsByMinister() async {
    setState(() { _isLoadingAppointments = true; });
    final now = DateTime.now();
    final start = _getRangeStart();
    final end = _getRangeEnd();
    try {
      String idField = 'consultantId';
      String? altIdField;
      if (widget.role == 'concierge') {
        idField = 'conciergeId';
        altIdField = 'assignedConciergeId';
      } else if (widget.role == 'cleaner') {
        idField = 'cleanerId';
        altIdField = 'assignedCleanerId';
      }
      final query1 = await FirebaseFirestore.instance
          .collection('appointments')
          .where(idField, isEqualTo: widget.consultantId)
          .get();
      List<QueryDocumentSnapshot> docs = query1.docs;
      if (altIdField != null) {
        final query2 = await FirebaseFirestore.instance
            .collection('appointments')
            .where(altIdField, isEqualTo: widget.consultantId)
            .get();
        // Merge and deduplicate by doc.id
        final ids = docs.map((d) => d.id).toSet();
        for (var doc in query2.docs) {
          if (!ids.contains(doc.id)) {
            docs.add(doc);
          }
        }
      }
      final List<Map<String, dynamic>> all = [];
      final List<Map<String, dynamic>> future = [];
      Set<String> ministerIdsToFetch = {};
      for (var doc in docs) {
        final data = Map<String, dynamic>.from(doc.data() as Map);
        final apptTime = (data['appointmentTime'] is Timestamp)
            ? (data['appointmentTime'] as Timestamp).toDate()
            : (data['appointmentTime'] is DateTime)
                ? data['appointmentTime']
                : null;
        if (apptTime == null) continue;
        final apptMap = {...data, 'docId': doc.id, 'appointmentTime': apptTime};
        if ((apptMap['ministerName'] == null || apptMap['ministerName'] == '') && apptMap['ministerId'] != null) {
          ministerIdsToFetch.add(apptMap['ministerId']);
        }
        if (apptTime.isAfter(now)) {
          future.add(Map<String, dynamic>.from(apptMap));
        }
        // Appointments in selected range
        if (!apptTime.isAfter(now) && apptTime.isAtSameMomentAs(start) || (apptTime.isAfter(start) && apptTime.isBefore(end))) {
          all.add(Map<String, dynamic>.from(apptMap));
        }
      }
      // Fetch missing minister names
      Map<String, String> ministerNames = {};
      if (ministerIdsToFetch.isNotEmpty) {
        final ministersQuery = await FirebaseFirestore.instance
            .collection('users')
            .where(FieldPath.documentId, whereIn: ministerIdsToFetch.toList())
            .get();
        for (var doc in ministersQuery.docs) {
          final data = Map<String, dynamic>.from(doc.data() as Map);
          ministerNames[doc.id] = (data['firstName'] ?? '') + ' ' + (data['lastName'] ?? '');
        }
        // Update names in all/future lists
        for (var appt in all) {
          if ((appt['ministerName'] == null || appt['ministerName'] == '') && appt['ministerId'] != null && ministerNames.containsKey(appt['ministerId'])) {
            appt['ministerName'] = ministerNames[appt['ministerId']];
          }
        }
        for (var appt in future) {
          if ((appt['ministerName'] == null || appt['ministerName'] == '') && appt['ministerId'] != null && ministerNames.containsKey(appt['ministerId'])) {
            appt['ministerName'] = ministerNames[appt['ministerId']];
          }
        }
      }
      setState(() {
        _appointments = all;
        _futureAppointments = future;
        _isLoadingAppointments = false;
      });
    } catch (e) {
      setState(() { _isLoadingAppointments = false; });
    }
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
  
  Color _getMinisterBgColor(int index) {
    return index % 2 == 0 ? Colors.grey.shade900 : Colors.black;
  }

  Widget _buildSummaryCard(String label, int value, Color color) {
    return Expanded(
      child: Card(
        color: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('$value', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMinisterSection(String ministerName, List<Map<String, dynamic>> appts, int index) {
    return Card(
      color: _getMinisterBgColor(index),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: AppColors.primary.withOpacity(0.3))),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ministerName,
              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 17),
            ),
            const SizedBox(height: 8),
            ...appts.map((appt) => Row(
                  children: [
                    Expanded(
                      child: Text(
                        DateFormat('MMM d, h:mm a').format(appt['appointmentTime']),
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      child: _buildStatusChip(appt['status'] ?? ''),
                    ),
                  ],
                )),
          ],
        ),
      ),
    );
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
        color = Colors.green;
        label = 'In Progress';
        break;
      case 'completed':
        color = Colors.blue;
        label = 'Completed';
        break;
      case 'cancelled':
        color = AppColors.primary;
        label = 'Cancelled';
        break;
      default:
        color = Colors.grey;
        label = status.isNotEmpty ? status.substring(0, 1).toUpperCase() + status.substring(1) : 'Unknown';
    }
    return Container(
      width: 90, // Fixed width for all status chips
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

  @override
  Widget build(BuildContext context) {
    // Use passed metrics data if available, otherwise use our collected data
    final metricsData = widget.metricsData ?? _metrics;
    
    if (_isLoading && metricsData.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      );
    }
    if (_isLoadingAppointments) {
      return const Center(child: CircularProgressIndicator());
    }
    
    // Extract metrics with fallbacks to 0
    final totalAppointments = metricsData['totalAppointments'] ?? 0;
    final completedAppointments = metricsData['completedAppointments'] ?? 0;
    final inProgressAppointments = metricsData['inProgressAppointments'] ?? 0;
    final breakMinutes = metricsData['breakMinutes'] ?? 0;
    final completionRate = metricsData['completionRate'] ?? 0;
    
    // Summary stats
    int total = _appointments.length;
    int completed = _appointments.where((a) => (a['status'] ?? '').toLowerCase() == 'completed').length;
    int cancelled = _appointments.where((a) => (a['status'] ?? '').toLowerCase() == 'cancelled').length;
    int pending = _appointments.where((a) {
      final status = (a['status'] ?? '').toLowerCase();
      return status != 'completed' && status != 'cancelled';
    }).length;

    // Group appointments by minister
    Map<String, List<Map<String, dynamic>>> ministerMap = {};
    Set<String> allMinisterNames = {};
    // Collect all ministers from both current range and future
    for (final appt in _appointments) {
      final ministerName = appt['ministerName'] ?? 'Unknown Minister';
      ministerMap.putIfAbsent(ministerName, () => []).add(appt);
      allMinisterNames.add(ministerName);
    }
    for (final appt in _futureAppointments) {
      final ministerName = appt['ministerName'] ?? 'Unknown Minister';
      allMinisterNames.add(ministerName);
    }
    // Fetch all ministers from Firestore (role == 'minister')
    // This is async, so we need to trigger a reload after fetching
    if (_allMinisters == null) {
      FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'minister')
        .get()
        .then((query) {
          final names = query.docs.map((doc) {
            final data = Map<String, dynamic>.from(doc.data() as Map);
            return (data['firstName'] ?? '') + ' ' + (data['lastName'] ?? '');
          }).toSet();
          if (mounted) {
            setState(() {
              _allMinisters = names.cast<String>();
            });
          }
        });
      // While loading, show what we have
    }
    final allMinistersToShow = {...allMinisterNames, ...?_allMinisters};
    for (final ministerName in allMinistersToShow) {
      // Sort each minister's appointments by date descending
      final appts = ministerMap[ministerName] ?? [];
      appts.sort((a, b) {
        final aTime = a['appointmentTime'] is DateTime
            ? a['appointmentTime']
            : (a['appointmentTime'] is Timestamp)
                ? (a['appointmentTime'] as Timestamp).toDate()
                : DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b['appointmentTime'] is DateTime
            ? b['appointmentTime']
            : (b['appointmentTime'] is Timestamp)
                ? (b['appointmentTime'] as Timestamp).toDate()
                : DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });
      ministerMap[ministerName] = appts;
    }
    // Group future appointments by minister (also sort)
    Map<String, List<Map<String, dynamic>>> futureMinisterMap = {};
    for (final appt in _futureAppointments) {
      final ministerName = appt['ministerName'] ?? 'Unknown Minister';
      futureMinisterMap.putIfAbsent(ministerName, () => []).add(appt);
    }
    for (final appts in futureMinisterMap.values) {
      appts.sort((a, b) {
        final aTime = a['appointmentTime'] is DateTime
            ? a['appointmentTime']
            : (a['appointmentTime'] is Timestamp)
                ? (a['appointmentTime'] as Timestamp).toDate()
                : DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b['appointmentTime'] is DateTime
            ? b['appointmentTime']
            : (b['appointmentTime'] is Timestamp)
                ? (b['appointmentTime'] as Timestamp).toDate()
                : DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });
    }

    return SingleChildScrollView(
      child: Container(
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
                color: AppColors.primary,
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
            const SizedBox(height: 16),
            // Summary row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSummaryCard('Total', total, Colors.blue),
                _buildSummaryCard('Pending', pending, Colors.orange),
                _buildSummaryCard('Completed', completed, Colors.green),
                _buildSummaryCard('Cancelled', cancelled, AppColors.primary),
              ],
            ),
            const SizedBox(height: 18),
            if (_futureAppointments.isNotEmpty) ...[
              Text('Future Appointments', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 18)),
              Card(
                color: Colors.grey[900],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: futureMinisterMap.entries.map((entry) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entry.key, style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 4),
                        ...entry.value.map((appt) => Row(
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
                        const SizedBox(height: 8),
                      ],
                    )).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 18),
            ],
            ...ministerMap.entries.where((entry) => entry.value.isNotEmpty).map((entry) {
              final idx = ministerMap.keys.toList().indexOf(entry.key);
              return _buildMinisterSection(entry.key, entry.value, idx);
            }).toList(),
          ],
        ),
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
    if (percentage < 30) return AppColors.primary;
    if (percentage < 70) return Colors.orange;
    return Colors.green;
  }
}
