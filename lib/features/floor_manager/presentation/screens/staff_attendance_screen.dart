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
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = true;
  Map<String, List<Map<String, dynamic>>> _staffAttendance = {};
  Map<String, dynamic> _businessHours = {};
  List<Map<String, dynamic>> _attendanceRecords = [];
  int _totalStaff = 0;
  int _totalRecords = 0;
  double _totalHours = 0.0;
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
      debugPrint('🔍 Fetching attendance data for month...');
      
      // First, fetch business hours settings
      await _fetchBusinessHours();
      
      // Calculate date range for the selected month
      final startOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      final endOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0, 23, 59, 59);
      
      debugPrint('📅 Date range: ${startOfMonth.toIso8601String()} to ${endOfMonth.toIso8601String()}');
      
      // Step 1: Fetch all users to get staff names and roles
      debugPrint('👥 Step 1: Fetching all users for staff info...');
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();
          
      debugPrint('👥 Found ${usersSnapshot.docs.length} users');
      
      // Create a map of userId -> user data
      final Map<String, Map<String, dynamic>> usersMap = {};
      for (final userDoc in usersSnapshot.docs) {
        final userData = userDoc.data() as Map<String, dynamic>;
        usersMap[userDoc.id] = userData;
        
        debugPrint('👤 User ${userDoc.id}:');
        debugPrint('  - Fields: ${userData.keys.toList()}');
        debugPrint('  - Data: $userData');
      }
      
      _staffAttendance.clear();
      _totalRecords = 0;
      _totalHours = 0.0;
      
      // Step 2: For each user, query their attendance using userId as document ID
      debugPrint('📊 Step 2: Querying attendance for each user...');
      
      for (final userId in usersMap.keys) {
        final userData = usersMap[userId]!;
        
        debugPrint('🔍 Processing user: $userId');
        
        // Extract staff name and role from user data
        final staffName = userData['displayName']?.toString() ??
                         userData['fullName']?.toString() ??
                         userData['name']?.toString() ??
                         userData['firstName']?.toString() ??
                         userData['lastName']?.toString() ??
                         userData['username']?.toString() ??
                         'Unknown Staff';
        
        final rawRole = userData['role']?.toString() ??
                       userData['userRole']?.toString() ??
                       userData['position']?.toString() ??
                       userData['jobTitle']?.toString() ??
                       'staff';
        final role = _normalizeRole(rawRole);
        
        debugPrint('👤 Staff: "$staffName", Role: "$rawRole" -> "$role"');
        
        // Query attendance collection using userId as document ID
        try {
          final attendanceDoc = await FirebaseFirestore.instance
              .collection('attendance')
              .doc(userId)
              .get();
              
          if (!attendanceDoc.exists) {
            debugPrint('📊 No attendance document found for user $userId');
            continue;
          }
          
          final attendanceData = attendanceDoc.data() as Map<String, dynamic>;
          debugPrint('📊 Attendance data for $userId: $attendanceData');
          
          // The attendance document has a flat structure with direct fields
          // Extract clock times directly from the document
          final clockInTime = _extractDateTime(attendanceData, ['clockInTime', 'checkInTime', 'timeIn']);
          final clockOutTime = _extractDateTime(attendanceData, ['clockOutTime', 'checkOutTime', 'timeOut']);
          
          debugPrint('🕐 Extracted times:');
          debugPrint('  - clockInTime: $clockInTime');
          debugPrint('  - clockOutTime: $clockOutTime');
          
          if (clockInTime != null) {
            // Convert timestamps to readable dates for debugging
            final clockInDate = DateFormat('yyyy-MM-dd HH:mm').format(clockInTime);
            final monthStart = DateFormat('yyyy-MM-dd HH:mm').format(startOfMonth);
            final monthEnd = DateFormat('yyyy-MM-dd HH:mm').format(endOfMonth);
            
            debugPrint('📅 Date comparison:');
            debugPrint('  - Clock In: $clockInDate');
            debugPrint('  - Month Start: $monthStart');
            debugPrint('  - Month End: $monthEnd');
            debugPrint('  - Is after start? ${clockInTime.isAfter(startOfMonth.subtract(const Duration(days: 1)))}');
            debugPrint('  - Is before end? ${clockInTime.isBefore(endOfMonth.add(const Duration(days: 1)))}');
            
            // Check if this attendance record is within the selected month range
            if (clockInTime.isAfter(startOfMonth.subtract(const Duration(days: 1))) &&
                clockInTime.isBefore(endOfMonth.add(const Duration(days: 1)))) {
              
              debugPrint('✅ Found attendance record for $staffName on ${DateFormat('yyyy-MM-dd').format(clockInTime)}');
              debugPrint('  - Clock In: $clockInTime');
              debugPrint('  - Clock Out: $clockOutTime');
              
              // Calculate worked hours
              final workedHours = _calculateActualWorkedHours(clockInTime, clockOutTime);
              
              debugPrint('🔧 Creating attendance record:');
              debugPrint('  - userId: $userId');
              debugPrint('  - staffName: "$staffName"');
              debugPrint('  - role: "$role"');
              debugPrint('  - workedHours: ${workedHours.toStringAsFixed(2)}');
              
              final attendanceRecord = {
                'id': userId,
                'userId': userId,
                'staffName': staffName,
                'role': role,
                'clockInTime': clockInTime,
                'clockOutTime': clockOutTime,
                'workedHours': workedHours,
                'date': DateFormat('yyyy-MM-dd').format(clockInTime),
                'status': clockOutTime != null ? 'completed' : 'active',
                ...attendanceData, // Include all original attendance data
              };
              
              debugPrint('📝 Attendance record created: $attendanceRecord');
              
              // Group by staff name
              debugPrint('🗂️ Adding to _staffAttendance map...');
              debugPrint('  - Current map keys: ${_staffAttendance.keys.toList()}');
              debugPrint('  - Adding for staff: "$staffName"');
              debugPrint('  - Map contains key? ${_staffAttendance.containsKey(staffName)}');
              
              if (!_staffAttendance.containsKey(staffName)) {
                debugPrint('  - Creating new list for staff: "$staffName"');
                _staffAttendance[staffName] = [];
              }
              
              _staffAttendance[staffName]!.add(attendanceRecord);
              
              debugPrint('  - Records for "$staffName": ${_staffAttendance[staffName]!.length}');
              debugPrint('  - Total map size: ${_staffAttendance.length}');
              
              _totalHours += workedHours;
              _totalRecords++;
              
              debugPrint('✅ Successfully added attendance for "$staffName": ${workedHours.toStringAsFixed(2)} hours');
              debugPrint('📊 Running totals: $_totalRecords records, ${_totalHours.toStringAsFixed(2)} hours');
            } else {
              debugPrint('❌ Attendance record for $staffName is outside selected month range');
              debugPrint('  - Record date: ${DateFormat('yyyy-MM-dd').format(clockInTime)}');
              debugPrint('  - Selected month: ${DateFormat('yyyy-MM').format(_selectedMonth)}');
            }
          } else {
            debugPrint('❌ No valid clock-in time found for $staffName');
          }
          
        } catch (e) {
          debugPrint('❌ Error fetching attendance for user $userId: $e');
          continue;
        }
      }
      
      _totalStaff = _staffAttendance.length;
      
      // Debug final results
      debugPrint('📊 === FINAL RESULTS ===');
      debugPrint('📊 Total staff in map: $_totalStaff');
      debugPrint('📊 Total records: $_totalRecords');
      debugPrint('📊 Total hours: ${_totalHours.toStringAsFixed(1)}');
      debugPrint('📊 Staff attendance map keys: ${_staffAttendance.keys.toList()}');
      debugPrint('📊 Staff attendance map: $_staffAttendance');
      debugPrint('📊 _staffAttendance.isEmpty: ${_staffAttendance.isEmpty}');
      
      setState(() => _isLoading = false);
      debugPrint('✅ Data fetch complete: $_totalStaff staff, $_totalRecords records, ${_totalHours.toStringAsFixed(1)} total hours');
      
    } catch (e) {
      debugPrint('❌ Error fetching attendance: $e');
      setState(() => _isLoading = false);
    }
  }
  
  DateTime? _extractDateTime(Map<String, dynamic> data, List<String> fieldNames) {
    for (final fieldName in fieldNames) {
      final value = data[fieldName];
      if (value != null) {
        if (value is Timestamp) {
          return value.toDate();
        } else if (value is String) {
          try {
            return DateTime.parse(value);
          } catch (e) {
            debugPrint('❌ Error parsing date string "$value": $e');
          }
        }
      }
    }
    return null;
  }
  
  Future<void> _fetchBusinessHours() async {
    try {
      debugPrint('🔍 Fetching business hours settings...');
      
      final businessSettingsSnapshot = await FirebaseFirestore.instance
          .collection('business')
          .doc('settings')
          .get();
      
      if (businessSettingsSnapshot.exists) {
        _businessHours = businessSettingsSnapshot.data() ?? {};
        debugPrint('✅ Business hours loaded: $_businessHours');
      } else {
        // Default business hours if not found
        _businessHours = {
          'close': '17:00',
          'businessHours': {
            'mon': 'open',
            'tue': 'open', 
            'wed': 'open',
            'thu': 'open',
            'fri': 'open',
            'sat': 'closed',
            'sun': 'closed',
          },
        };
        debugPrint('⚠️ Using default business hours: $_businessHours');
      }
    } catch (e) {
      debugPrint('❌ Error fetching business hours: $e');
      // Use default values
      _businessHours = {
        'close': '17:00',
        'businessHours': {
          'mon': 'open',
          'tue': 'open',
          'wed': 'open', 
          'thu': 'open',
          'fri': 'open',
          'sat': 'closed',
          'sun': 'closed',
        },
      };
    }
  }
  
  // Normalize role names to standard values
  String _normalizeRole(String rawRole) {
    final role = rawRole.toLowerCase().trim();
    
    if (role.contains('floor') && role.contains('manager')) {
      return 'floormanager';
    } else if (role.contains('consultant')) {
      return 'consultant';
    } else if (role.contains('concierge')) {
      return 'concierge';
    } else if (role.contains('clean')) {
      return 'cleaner';
    } else if (role.contains('staff')) {
      return 'staff';
    } else {
      // Default to staff for unknown roles
      return 'staff';
    }
  }

  double _calculateActualWorkedHours(DateTime clockInTime, DateTime? clockOutTime) {
    debugPrint('📈 === HOURS CALCULATION START ===');
    debugPrint('📈 Clock-in time: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(clockInTime)}');
    debugPrint('📈 Clock-out time: ${clockOutTime != null ? DateFormat('yyyy-MM-dd HH:mm:ss').format(clockOutTime) : 'NULL'}');
    
    // Get day of week (e.g., 'fri')
    final dayOfWeek = DateFormat('E').format(clockInTime).toLowerCase().substring(0, 3);
    debugPrint('📅 Day of week: $dayOfWeek');
    
    // Check if business is closed on this day
    final businessHours = _businessHours['businessHours'] as Map<String, dynamic>? ?? {};
    final dayStatus = businessHours[dayOfWeek]?.toString() ?? 'open';
    debugPrint('🏢 Business status for $dayOfWeek: $dayStatus');
    debugPrint('🏢 All business hours: $businessHours');
    
    if (dayStatus == 'closed') {
      debugPrint('🚫 Business closed on $dayOfWeek, returning 0 hours');
      return 0.0;
    }
    
    DateTime endTime;
    String calculationMethod;
    
    if (clockOutTime != null) {
      // Get business close time for comparison
      final closeTimeStr = _businessHours['close']?.toString() ?? '17:00';
      debugPrint('🕰️ Business close time string: "$closeTimeStr"');
      
      DateTime businessCloseTime;
      final closeTimeParts = closeTimeStr.split(':');
      if (closeTimeParts.length >= 2) {
        try {
          final closeHour = int.parse(closeTimeParts[0]);
          final closeMinute = int.parse(closeTimeParts[1]);
          businessCloseTime = DateTime(
            clockInTime.year,
            clockInTime.month, 
            clockInTime.day,
            closeHour,
            closeMinute,
          );
        } catch (e) {
          debugPrint('❌ Error parsing close time "$closeTimeStr": $e');
          // Default to 5 PM if parsing fails
          businessCloseTime = DateTime(
            clockInTime.year,
            clockInTime.month, 
            clockInTime.day,
            17,
            0,
          );
        }
      } else {
        debugPrint('❌ Invalid close time format: "$closeTimeStr"');
        // Default to 5 PM if format is invalid
        businessCloseTime = DateTime(
          clockInTime.year,
          clockInTime.month, 
          clockInTime.day,
          17,
          0,
        );
      }
      
      debugPrint('🕰️ Business close time: ${DateFormat('HH:mm').format(businessCloseTime)}');
      debugPrint('🕰️ Actual clock-out time: ${DateFormat('yyyy-MM-dd HH:mm').format(clockOutTime)}');
      
      // Check if clock-out is on a different day (next day) - indicates forgotten clock-out or very late clock-out
      final clockInDate = DateFormat('yyyy-MM-dd').format(clockInTime);
      final clockOutDate = DateFormat('yyyy-MM-dd').format(clockOutTime);
      final isNextDay = clockOutDate != clockInDate;
      
      debugPrint('📅 Clock-in date: $clockInDate');
      debugPrint('📅 Clock-out date: $clockOutDate');
      debugPrint('📅 Is next day? $isNextDay');
      
      // Check for corrupted timestamps (clock-out before clock-in)
      final isCorruptedTimestamp = clockOutTime.isBefore(clockInTime);
      
      if (isCorruptedTimestamp) {
        debugPrint('❌❌ CORRUPTED TIMESTAMP DETECTED! ❌❌');
        debugPrint('❌ Clock-out time is BEFORE clock-in time!');
        debugPrint('❌ This indicates data corruption or auto-clock-out bug');
        debugPrint('❌ Clock-in: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(clockInTime)}');
        debugPrint('❌ Clock-out: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(clockOutTime)}');
        debugPrint('❌ Using business close time instead');
      }
      
      // If clocked out on next day OR after business hours OR corrupted timestamp, use business close time
      if (isNextDay || clockOutTime.isAfter(businessCloseTime) || isCorruptedTimestamp) {
        endTime = businessCloseTime;
        if (isCorruptedTimestamp) {
          calculationMethod = 'business close time (corrupted timestamp - clock-out before clock-in)';
          debugPrint('⚠️ Corrupted timestamp fixed: using business close time ${DateFormat('HH:mm').format(businessCloseTime)}');
        } else if (isNextDay) {
          calculationMethod = 'business close time (clocked out next day - likely forgot to clock out)';
          debugPrint('⚠️ Next-day clock-out detected: ${DateFormat('yyyy-MM-dd HH:mm').format(clockOutTime)} -> using business close time ${DateFormat('HH:mm').format(businessCloseTime)}');
        } else {
          calculationMethod = 'business close time (clocked out after business hours)';
          debugPrint('⚠️ After-hours clock-out: ${DateFormat('HH:mm').format(clockOutTime)} -> capped at ${DateFormat('HH:mm').format(businessCloseTime)}');
        }
      } else {
        endTime = clockOutTime;
        calculationMethod = 'actual clock-out time (within business hours, same day)';
        debugPrint('✅ Using actual clock-out time: ${DateFormat('HH:mm').format(clockOutTime)}');
      }
    } else {
      // If no clock-out time, use business close time
      final closeTimeStr = _businessHours['close']?.toString() ?? '17:00';
      debugPrint('🕰️ Business close time string: "$closeTimeStr"');
      
      final closeTimeParts = closeTimeStr.split(':');
      if (closeTimeParts.length >= 2) {
        try {
          final closeHour = int.parse(closeTimeParts[0]);
          final closeMinute = int.parse(closeTimeParts[1]);
          endTime = DateTime(
            clockInTime.year,
            clockInTime.month, 
            clockInTime.day,
            closeHour,
            closeMinute,
          );
          calculationMethod = 'business close time';
          debugPrint('✅ Using business close time: ${DateFormat('HH:mm').format(endTime)}');
        } catch (e) {
          debugPrint('❌ Error parsing close time "$closeTimeStr": $e');
          // Default to 5 PM if parsing fails
          endTime = DateTime(
            clockInTime.year,
            clockInTime.month, 
            clockInTime.day,
            17,
            0,
          );
          calculationMethod = 'default 5 PM (parsing error)';
        }
      } else {
        debugPrint('❌ Invalid close time format: "$closeTimeStr"');
        // Default to 5 PM if format is invalid
        endTime = DateTime(
          clockInTime.year,
          clockInTime.month, 
          clockInTime.day,
          17,
          0,
        );
        calculationMethod = 'default 5 PM (invalid format)';
      }
    }
    
    // Calculate actual hours worked (including overtime)
    final duration = endTime.difference(clockInTime);
    final hoursWorked = duration.inMinutes / 60.0;
    
    debugPrint('📈 === DETAILED CALCULATION SUMMARY ===');
    debugPrint('📈 Method: $calculationMethod');
    debugPrint('📈 Clock-in time: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(clockInTime)}');
    debugPrint('📈 End time used: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(endTime)}');
    debugPrint('📈 Duration object: $duration');
    debugPrint('📈 Duration in milliseconds: ${duration.inMilliseconds}');
    debugPrint('📈 Duration in minutes: ${duration.inMinutes}');
    debugPrint('📈 Duration in hours (raw): ${duration.inMinutes / 60.0}');
    debugPrint('📈 Hours worked (calculated): ${hoursWorked.toStringAsFixed(4)}');
    debugPrint('📈 Hours worked > 0? ${hoursWorked > 0}');
    debugPrint('📈 Final return value: ${hoursWorked > 0 ? hoursWorked : 0.0}');
    
    // Additional debugging for negative durations
    if (duration.isNegative) {
      debugPrint('❌❌ NEGATIVE DURATION DETECTED! ❌❌');
      debugPrint('❌ Clock-in is AFTER end time!');
      debugPrint('❌ This suggests a date/time parsing issue');
      debugPrint('❌ Clock-in: ${clockInTime.millisecondsSinceEpoch}');
      debugPrint('❌ End time: ${endTime.millisecondsSinceEpoch}');
    }
    
    if (hoursWorked <= 0) {
      debugPrint('⚠️⚠️ ZERO OR NEGATIVE HOURS RESULT! ⚠️⚠️');
      debugPrint('⚠️ This indicates a calculation problem');
      debugPrint('⚠️ Check clock-in/out times and business hours settings');
    }
    
    debugPrint('📈 === HOURS CALCULATION END ===');
    
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
      case 'floormanager':
        return Icons.supervisor_account;
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

  Widget _buildStaffAttendanceCard(String staffName, List<Map<String, dynamic>> attendanceRecords, int index) {
    // Get staff role from first record
    String staffRole = attendanceRecords.isNotEmpty ? attendanceRecords.first['role'] ?? 'staff' : 'staff';
    
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
    final clockInTime = record['clockInTime'] is Timestamp 
        ? (record['clockInTime'] as Timestamp).toDate()
        : record['clockInTime'] as DateTime;
    final clockOutTime = record['clockOutTime'] != null
        ? (record['clockOutTime'] is Timestamp 
            ? (record['clockOutTime'] as Timestamp).toDate()
            : record['clockOutTime'] as DateTime)
        : null;
    final workedHours = (record['workedHours'] as num?)?.toDouble() ?? 0.0;
    final status = record['status']?.toString() ?? 'unknown';
    
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
