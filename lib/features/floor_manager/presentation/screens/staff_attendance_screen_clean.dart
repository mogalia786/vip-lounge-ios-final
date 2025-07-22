import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/colors.dart';

class StaffAttendanceScreen extends StatefulWidget {
  const StaffAttendanceScreen({Key? key}) : super(key: key);

  @override
  _StaffAttendanceScreenState createState() => _StaffAttendanceScreenState();
}

class _StaffAttendanceScreenState extends State<StaffAttendanceScreen> {
  DateTime _selectedMonth = DateTime.now();
  bool _isLoading = true;
  Map<String, List<Map<String, dynamic>>> _staffAttendance = {};
  Map<String, dynamic> _businessHours = {};
  int _totalStaff = 0;
  int _totalRecords = 0;
  double _totalHours = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchAttendance();
  }

  Future<void> _fetchAttendance() async {
    setState(() => _isLoading = true);
    
    try {
      debugPrint('🔍 Fetching attendance data for month...');
      
      // First, fetch business hours settings
      await _fetchBusinessHours();
      
      // Calculate date range for the selected month
      final startOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      final endOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0, 23, 59, 59);
      
      debugPrint('📅 Date range: ${startOfMonth.toIso8601String()} to ${endOfMonth.toIso8601String()}');
      
      // Fetch attendance records from attendance collection
      final attendanceSnapshot = await FirebaseFirestore.instance
          .collection('attendance')
          .where('clockInTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .where('clockInTime', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
          .orderBy('clockInTime', descending: true)
          .get();
          
      debugPrint('📊 Found ${attendanceSnapshot.docs.length} attendance records');
      
      _staffAttendance.clear();
      _totalRecords = attendanceSnapshot.docs.length;
      _totalHours = 0.0;
      
      for (final doc in attendanceSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        
        debugPrint('🔍 Processing attendance record ${doc.id}: $data');
        
        final staffName = data['staffName']?.toString() ?? 
                         data['userName']?.toString() ?? 
                         data['name']?.toString() ?? 'Unknown Staff';
        final role = data['role']?.toString() ?? 
                    data['userRole']?.toString() ?? 'staff';
        final clockInTime = (data['clockInTime'] as Timestamp?)?.toDate();
        final clockOutTime = (data['clockOutTime'] as Timestamp?)?.toDate();
        
        if (clockInTime == null) continue;
        
        // Calculate worked hours using business hours logic
        final workedHours = _calculateWorkedHours(clockInTime, clockOutTime);
        
        final attendanceRecord = {
          'id': doc.id,
          'staffName': staffName,
          'role': role,
          'clockInTime': clockInTime,
          'clockOutTime': clockOutTime,
          'workedHours': workedHours,
          'date': DateFormat('yyyy-MM-dd').format(clockInTime),
          'status': clockOutTime != null ? 'completed' : 'active',
          ...data, // Include all original data
        };
        
        // Group by staff name
        if (!_staffAttendance.containsKey(staffName)) {
          _staffAttendance[staffName] = [];
        }
        _staffAttendance[staffName]!.add(attendanceRecord);
        
        _totalHours += workedHours;
        
        debugPrint('✅ Added attendance for "$staffName": ${workedHours.toStringAsFixed(2)} hours');
      }
      
      _totalStaff = _staffAttendance.length;
      
      setState(() => _isLoading = false);
      debugPrint('✅ Data fetch complete: $_totalStaff staff, $_totalRecords records, ${_totalHours.toStringAsFixed(1)} total hours');
      
    } catch (e) {
      debugPrint('❌ Error fetching attendance: $e');
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _fetchBusinessHours() async {
    try {
      debugPrint('🔍 Fetching business hours settings...');
      
      final businessSettingsSnapshot = await FirebaseFirestore.instance
          .collection('business_settings')
          .doc('settings') // or whatever document contains business hours
          .get();
      
      if (businessSettingsSnapshot.exists) {
        _businessHours = businessSettingsSnapshot.data() ?? {};
        debugPrint('✅ Business hours loaded: $_businessHours');
      } else {
        // Default business hours if not found
        _businessHours = {
          'openTime': '08:00',
          'closeTime': '17:00',
          'businessHours': 9.0,
        };
        debugPrint('⚠️ Using default business hours: $_businessHours');
      }
    } catch (e) {
      debugPrint('❌ Error fetching business hours: $e');
      // Use default values
      _businessHours = {
        'openTime': '08:00',
        'closeTime': '17:00', 
        'businessHours': 9.0,
      };
    }
  }
  
  double _calculateWorkedHours(DateTime clockInTime, DateTime? clockOutTime) {
    // Get business end time for the clock-in date
    final clockInDate = DateTime(clockInTime.year, clockInTime.month, clockInTime.day);
    
    // Parse business close time (e.g., "17:00")
    final closeTimeStr = _businessHours['closeTime']?.toString() ?? '17:00';
    final closeTimeParts = closeTimeStr.split(':');
    final businessEndTime = DateTime(
      clockInDate.year,
      clockInDate.month, 
      clockInDate.day,
      int.parse(closeTimeParts[0]),
      int.parse(closeTimeParts[1]),
    );
    
    DateTime endTime;
    
    if (clockOutTime != null && clockOutTime.isBefore(businessEndTime)) {
      // Use actual clock-out time if it's before business end time
      endTime = clockOutTime;
      debugPrint('🕰️ Using actual clock-out time: ${DateFormat('HH:mm').format(clockOutTime)}');
    } else {
      // Use business end time
      endTime = businessEndTime;
      debugPrint('🕰️ Using business end time: ${DateFormat('HH:mm').format(businessEndTime)}');
    }
    
    // Calculate hours worked
    final duration = endTime.difference(clockInTime);
    final hoursWorked = duration.inMinutes / 60.0;
    
    debugPrint('📈 Clock-in: ${DateFormat('HH:mm').format(clockInTime)}, End: ${DateFormat('HH:mm').format(endTime)}, Hours: ${hoursWorked.toStringAsFixed(2)}');
    
    return hoursWorked > 0 ? hoursWorked : 0.0;
  }
  
  // Get alternating colors for staff members (same pattern as ratings screen)
  Color _getStaffColor(int index) {
    final colors = [
      Colors.blue.shade600,
      Colors.green.shade600,
      Colors.orange.shade600,
      Colors.purple.shade600,
      Colors.teal.shade600,
      Colors.red.shade600,
    ];
    return colors[index % colors.length];
  }
  
  // Get role icon
  IconData _getRoleIcon(String role) {
    switch (role.toLowerCase()) {
      case 'consultant':
        return Icons.person;
      case 'concierge':
        return Icons.support_agent;
      case 'cleaner':
        return Icons.cleaning_services;
      case 'staff':
      default:
        return Icons.work;
    }
  }
  
  Widget _buildStaffAttendanceCard(String staffName, List<Map<String, dynamic>> attendanceRecords, int index) {
    // Get staff role from first record
    String staffRole = attendanceRecords.isNotEmpty ? attendanceRecords.first['role'] : 'staff';
    
    // Calculate total hours worked this month
    double totalWorked = attendanceRecords.fold(0.0, (sum, record) => sum + (record['workedHours'] ?? 0.0));
    int activeDays = attendanceRecords.where((record) => record['status'] == 'completed').length;
    
    // Get alternating color for this staff member
    final staffColor = _getStaffColor(index);
    final roleIcon = _getRoleIcon(staffRole);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: staffColor,
          child: Icon(
            roleIcon,
            color: Colors.white,
          ),
        ),
        title: Text(
          staffName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${staffRole.toUpperCase()} • ${attendanceRecords.length} record${attendanceRecords.length != 1 ? 's' : ''} • ${activeDays} completed day${activeDays != 1 ? 's' : ''}',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.access_time, color: staffColor, size: 16),
                const SizedBox(width: 4),
                Text(
                  'Total: ${totalWorked.toStringAsFixed(1)}h',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: staffColor,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],
        ),
        children: attendanceRecords.map((record) => _buildAttendanceDetailItem(record, staffColor)).toList(),
      ),
    );
  }
  
  Widget _buildAttendanceDetailItem(Map<String, dynamic> record, Color staffColor) {
    final clockInTime = record['clockInTime'] as DateTime;
    final clockOutTime = record['clockOutTime'] as DateTime?;
    final workedHours = record['workedHours'] as double;
    final status = record['status'] as String;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with date and status
          Row(
            children: [
              Expanded(
                child: Text(
                  DateFormat('EEEE, MMM dd, yyyy').format(clockInTime),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: status == 'completed' ? Colors.green[100] : Colors.orange[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: status == 'completed' ? Colors.green[800] : Colors.orange[800],
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // Clock in/out times
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.login, color: Colors.green[600], size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'Clock In: ${DateFormat('h:mm a').format(clockInTime)}',
                          style: TextStyle(
                            color: Colors.green[800],
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          clockOutTime != null ? Icons.logout : Icons.schedule,
                          color: clockOutTime != null ? Colors.red[600] : Colors.orange[600],
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          clockOutTime != null 
                              ? 'Clock Out: ${DateFormat('h:mm a').format(clockOutTime)}'
                              : 'Business End Time',
                          style: TextStyle(
                            color: clockOutTime != null ? Colors.red[800] : Colors.orange[800],
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Hours Worked',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    '${workedHours.toStringAsFixed(1)}h',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: staffColor,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildMonthlySummaryCard() {
    if (_staffAttendance.isEmpty) return const SizedBox.shrink();
    
    final monthName = DateFormat('MMMM yyyy').format(_selectedMonth);
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Staff Attendance - $monthName',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(
                children: [
                  const Text(
                    'Total Staff',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _totalStaff.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                height: 60,
                width: 1,
                color: Colors.white30,
              ),
              Column(
                children: [
                  const Text(
                    'Total Records',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _totalRecords.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                height: 60,
                width: 1,
                color: Colors.white30,
              ),
              Column(
                children: [
                  const Text(
                    'Total Hours',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_totalHours.toStringAsFixed(0)}h',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Future<void> _selectMonth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year,
    );
    
    if (picked != null && picked != _selectedMonth) {
      setState(() {
        _selectedMonth = DateTime(picked.year, picked.month, 1);
      });
      _fetchAttendance();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Staff Attendance',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _selectMonth,
            tooltip: 'Select Month',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : Column(
              children: [
                // Monthly summary card at top
                _buildMonthlySummaryCard(),
                
                // Staff attendance list
                Expanded(
                  child: _staffAttendance.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No attendance records found',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'for ${DateFormat('MMMM yyyy').format(_selectedMonth)}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _staffAttendance.keys.length,
                          itemBuilder: (context, index) {
                            final staffName = _staffAttendance.keys.elementAt(index);
                            final attendanceRecords = _staffAttendance[staffName]!;
                            return _buildStaffAttendanceCard(staffName, attendanceRecords, index);
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
