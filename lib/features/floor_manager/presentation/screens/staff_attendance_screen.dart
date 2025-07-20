import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/providers/app_auth_provider.dart';

class StaffAttendanceScreen extends StatefulWidget {
  const StaffAttendanceScreen({Key? key}) : super(key: key);

  @override
  _StaffAttendanceScreenState createState() => _StaffAttendanceScreenState();
}

class _StaffAttendanceScreenState extends State<StaffAttendanceScreen> {
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = true;
  List<Map<String, dynamic>> _attendanceRecords = [];
  Map<String, Map<String, dynamic>> _staffAttendance = {};
  int _presentCount = 0;
  int _absentCount = 0;
  int _onLeaveCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchAttendance();
  }

  Future<void> _fetchAttendance() async {
    setState(() => _isLoading = true);
    
    try {
      // Get the start and end of the selected day
      final startOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      final endOfDay = startOfDay.add(const Duration(days: 1)).subtract(const Duration(seconds: 1));
      
      debugPrint('Fetching attendance for ${startOfDay.toIso8601String()} to ${endOfDay.toIso8601String()}');
      
      // Fetch all staff members first
      final staffSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', whereIn: ['staff', 'consultant', 'concierge', 'admin'])
          .get();
          
      debugPrint('Found ${staffSnapshot.docs.length} staff members');
      
      // Fetch attendance records for the selected day
      final attendanceSnapshot = await FirebaseFirestore.instance
          .collection('attendance')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .get();
          
      debugPrint('Found ${attendanceSnapshot.docs.length} attendance records');
      
      // Initialize attendance records with all staff members
      _attendanceRecords = [];
      
      // Add attendance records
      _attendanceRecords.addAll(attendanceSnapshot.docs.map((doc) {
        final data = doc.data();
        debugPrint('Attendance data: ${data.toString()}');
        return {
          'id': doc.id,
          ...data,
        };
      }).toList());
      
      // Add missing staff members as absent
      for (var staffDoc in staffSnapshot.docs) {
        final staffId = staffDoc.id;
        final hasAttendance = _attendanceRecords.any((record) => record['staffId'] == staffId);
        
        if (!hasAttendance) {
          _attendanceRecords.add({
            'staffId': staffId,
            'staffName': staffDoc['displayName'] ?? 'Unknown Staff',
            'status': 'absent',
            'date': Timestamp.fromDate(_selectedDate),
          });
        }
      }

      _processAttendance();
    } catch (e) {
      print('Error fetching attendance: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading attendance: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _processAttendance() {
    _staffAttendance.clear();
    _presentCount = 0;
    _absentCount = 0;
    _onLeaveCount = 0;

    // Group attendance by staff member
    for (var record in _attendanceRecords) {
      final staffId = record['staffId'];
      final staffName = record['staffName'] ?? 'Unknown Staff';
      final status = record['status']?.toString().toLowerCase() ?? 'absent';
      
      // Update counts
      if (status == 'present') {
        _presentCount++;
      } else if (status == 'on_leave') {
        _onLeaveCount++;
      } else {
        _absentCount++;
      }

      // Initialize staff data if not exists
      if (!_staffAttendance.containsKey(staffId)) {
        _staffAttendance[staffId] = {
          'name': staffName,
          'status': status,
          'checkIn': null,
          'checkOut': null,
          'breaks': [],
          'totalHours': 0.0,
        };
      }

      // Update staff attendance data
      final staffData = _staffAttendance[staffId]!;
      
      if (record['type'] == 'check_in') {
        staffData['checkIn'] = record['timestamp'] is Timestamp 
            ? (record['timestamp'] as Timestamp).toDate() 
            : DateTime.now();
      } else if (record['type'] == 'check_out') {
        staffData['checkOut'] = record['timestamp'] is Timestamp 
            ? (record['timestamp'] as Timestamp).toDate() 
            : DateTime.now();
      } else if (record['type'] == 'break_start' || record['type'] == 'break_end') {
        final breakData = {
          'type': record['type'],
          'timestamp': record['timestamp'] is Timestamp 
              ? (record['timestamp'] as Timestamp).toDate() 
              : DateTime.now(),
          'reason': record['reason'] ?? 'No reason provided',
        };
        
        if (record['type'] == 'break_start') {
          staffData['breaks'].add(breakData);
        } else if (record['type'] == 'break_end' && staffData['breaks'].isNotEmpty) {
          // Find the most recent break without an end time
          for (var i = staffData['breaks'].length - 1; i >= 0; i--) {
            if (staffData['breaks'][i]['type'] == 'break_start' && 
                !staffData['breaks'][i].containsKey('end_time')) {
              staffData['breaks'][i]['end_time'] = breakData['timestamp'];
              break;
            }
          }
        }
      }

      // Calculate total hours if both check-in and check-out exist
      if (staffData['checkIn'] != null && staffData['checkOut'] != null) {
        final checkIn = staffData['checkIn'] as DateTime;
        final checkOut = staffData['checkOut'] as DateTime;
        staffData['totalHours'] = checkOut.difference(checkIn).inMinutes / 60.0;
      }
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDatePickerMode: DatePickerMode.day,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      await _fetchAttendance();
    }
  }

  Widget _buildAttendanceSummary() {
    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Attendance Summary',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem(
                  'Present',
                  _presentCount.toString(),
                  Icons.check_circle,
                  Colors.green,
                ),
                _buildSummaryItem(
                  'On Leave',
                  _onLeaveCount.toString(),
                  Icons.beach_access,
                  Colors.orange,
                ),
                _buildSummaryItem(
                  'Absent',
                  _absentCount.toString(),
                  Icons.cancel,
                  Colors.red,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 28, color: color),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildStaffAttendanceItem(String staffId, Map<String, dynamic> data) {
    final status = data['status'] as String;
    final checkIn = data['checkIn'] as DateTime?;
    final checkOut = data['checkOut'] as DateTime?;
    final breaks = (data['breaks'] as List<dynamic>?) ?? [];
    final totalHours = (data['totalHours'] as num?)?.toDouble() ?? 0.0;

    Color statusColor = Colors.grey;
    IconData statusIcon = Icons.help_outline;
    String statusText = 'Unknown';

    switch (status) {
      case 'present':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'Present';
        break;
      case 'on_leave':
        statusColor = Colors.orange;
        statusIcon = Icons.beach_access;
        statusText = 'On Leave';
        break;
      case 'absent':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        statusText = 'Absent';
        break;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary,
          child: Text(
            data['name'].toString().substring(0, 1).toUpperCase(),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(
          data['name'],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Row(
          children: [
            Icon(statusIcon, size: 16, color: statusColor),
            const SizedBox(width: 4),
            Text(statusText, style: TextStyle(color: statusColor)),
          ],
        ),
        trailing: checkIn != null
            ? Text(
                '${totalHours.toStringAsFixed(1)}h',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              )
            : null,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (checkIn != null) ...[
                  _buildAttendanceDetail(
                    'Checked In',
                    DateFormat('h:mm a').format(checkIn),
                    Icons.login,
                  ),
                  const SizedBox(height: 8),
                ],
                if (checkOut != null) ...[
                  _buildAttendanceDetail(
                    'Checked Out',
                    DateFormat('h:mm a').format(checkOut),
                    Icons.logout,
                  ),
                  const SizedBox(height: 8),
                ],
                if (breaks.isNotEmpty) ...[
                  const Text(
                    'Breaks',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...breaks.map<Widget>((breakData) {
                    if (breakData['type'] == 'break_start' && breakData['end_time'] != null) {
                      final start = breakData['timestamp'] as DateTime;
                      final end = breakData['end_time'] as DateTime;
                      final duration = end.difference(start);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            const Icon(Icons.free_breakfast, size: 16, color: Colors.blue),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${DateFormat('h:mm a').format(start)} - ${DateFormat('h:mm a').format(end)} (${duration.inMinutes} min)',
                              ),
                            ),
                            if (breakData['reason'] != null)
                              Text(
                                '(${breakData['reason']})\n',
                                style: const TextStyle(
                                  fontStyle: FontStyle.italic,
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                          ],
                        ),
                      );
                    } else if (breakData['type'] == 'break_start') {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            const Icon(Icons.free_breakfast, size: 16, color: Colors.orange),
                            const SizedBox(width: 8),
                            Text('On break since ${DateFormat('h:mm a').format(breakData['timestamp'])}'),
                            if (breakData['reason'] != null)
                              Text(
                                ' (${breakData['reason']})\n',
                                style: const TextStyle(
                                  fontStyle: FontStyle.italic,
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                          ],
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  }).toList(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceDetail(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        Text(value),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Attendance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _selectDate,
            tooltip: 'Select Date',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _staffAttendance.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.people_outline, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        'No attendance records found for ${DateFormat('MMM d, y').format(_selectedDate)}',
                        style: const TextStyle(fontSize: 16, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildAttendanceSummary(),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                            const SizedBox(width: 8),
                            Text(
                              'Showing attendance for ${DateFormat('EEEE, MMM d, y').format(_selectedDate)}',
                              style: const TextStyle(color: Colors.grey, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._staffAttendance.entries.map(
                        (entry) => _buildStaffAttendanceItem(entry.key, entry.value),
                      ),
                    ],
                  ),
                ),
    );
  }
}
