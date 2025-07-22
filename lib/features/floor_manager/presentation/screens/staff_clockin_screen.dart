import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/colors.dart';

class StaffClockinScreen extends StatefulWidget {
  const StaffClockinScreen({Key? key}) : super(key: key);

  @override
  _StaffClockinScreenState createState() => _StaffClockinScreenState();
}

// Simple data model for clock-in records
class ClockInRecord {
  final String id;
  final String staffName;
  final String role;
  final DateTime clockInTime;
  final DateTime? clockOutTime;
  final String status;
  final String location;

  ClockInRecord({
    required this.id,
    required this.staffName,
    required this.role,
    required this.clockInTime,
    this.clockOutTime,
    required this.status,
    required this.location,
  });

  Duration get workedDuration {
    if (clockOutTime != null) {
      return clockOutTime!.difference(clockInTime);
    }
    return DateTime.now().difference(clockInTime);
  }

  String get formattedDuration {
    final duration = workedDuration;
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    return '${hours}h ${minutes}m';
  }
}

class _StaffClockinScreenState extends State<StaffClockinScreen> {
  DateTime _selectedMonth = DateTime.now();
  bool _isLoading = true;
  Map<String, List<ClockInRecord>> _staffClockIns = {};

  @override
  void initState() {
    super.initState();
    _fetchAllClockInData();
  }

  Future<void> _fetchAllClockInData() async {
    setState(() => _isLoading = true);
    try {
      debugPrint('🕐 Fetching clock-in data...');
      
      // Calculate date range
      final startOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      final endOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0, 23, 59, 59);
      
      debugPrint('📅 Date range: ${startOfMonth.toIso8601String()} to ${endOfMonth.toIso8601String()}');
      
      // Fetch all clock-in records (adjust collection name as needed)
      final clockInQuery = await FirebaseFirestore.instance
          .collection('staff_activities') // or 'clock_ins', 'attendance', etc.
          .where('clockInTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .where('clockInTime', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
          .orderBy('clockInTime', descending: true)
          .get();
          
      debugPrint('📊 Raw query returned ${clockInQuery.docs.length} documents');
      
      _staffClockIns.clear();
      
      for (final doc in clockInQuery.docs) {
        final data = doc.data() as Map<String, dynamic>;
        
        debugPrint('🔍 Processing document ${doc.id}: $data');
        
        final staffName = data['staffName']?.toString() ?? 
                         data['userName']?.toString() ?? 
                         data['name']?.toString() ?? 'Unknown Staff';
        final role = data['role']?.toString() ?? 
                    data['userRole']?.toString() ?? 
                    data['position']?.toString() ?? 'staff';
        final clockInTime = (data['clockInTime'] as Timestamp?)?.toDate() ?? 
                           (data['startTime'] as Timestamp?)?.toDate() ?? DateTime.now();
        final clockOutTime = (data['clockOutTime'] as Timestamp?)?.toDate() ?? 
                            (data['endTime'] as Timestamp?)?.toDate();
        final status = data['status']?.toString() ?? 'active';
        final location = data['location']?.toString() ?? 
                        data['venue']?.toString() ?? 'VIP Lounge';
        
        debugPrint('🔍 Processing clock-in: Staff="$staffName", Role="$role", Time=${clockInTime.toString()}');
        
        // Create clock-in record
        final clockInRecord = ClockInRecord(
          id: doc.id,
          staffName: staffName,
          role: role.toLowerCase(),
          clockInTime: clockInTime,
          clockOutTime: clockOutTime,
          status: status,
          location: location,
        );
        
        // Group by staff name
        if (!_staffClockIns.containsKey(staffName)) {
          _staffClockIns[staffName] = [];
        }
        _staffClockIns[staffName]!.add(clockInRecord);
        
        debugPrint('✅ Added clock-in for staff "$staffName" at ${clockInTime.toString()}');
      }
      
      setState(() => _isLoading = false);
      debugPrint('✅ Data fetch complete: ${_staffClockIns.length} staff members, ${clockInQuery.docs.length} total records');
      
    } catch (e) {
      debugPrint('❌ Error fetching clock-in data: $e');
      setState(() => _isLoading = false);
    }
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

  Widget _buildStaffClockInCard(String staffName, List<ClockInRecord> clockIns, int index) {
    // Get staff role from first record
    String staffRole = clockIns.isNotEmpty ? clockIns.first.role : 'staff';
    
    // Calculate total hours worked this month
    Duration totalWorked = Duration.zero;
    int activeDays = 0;
    
    for (final record in clockIns) {
      if (record.clockOutTime != null) {
        totalWorked += record.workedDuration;
        activeDays++;
      }
    }
    
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
              '${staffRole.toUpperCase()} • ${clockIns.length} record${clockIns.length != 1 ? 's' : ''} • ${activeDays} active day${activeDays != 1 ? 's' : ''}',
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
                  'Total: ${totalWorked.inHours}h ${totalWorked.inMinutes % 60}m',
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
        children: clockIns.map((record) => _buildClockInDetailItem(record, staffColor)).toList(),
      ),
    );
  }
  
  Widget _buildClockInDetailItem(ClockInRecord record, Color staffColor) {
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('EEEE, MMM dd, yyyy').format(record.clockInTime),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'Location: ${record.location}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: record.status == 'active' ? Colors.green[100] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  record.status.toUpperCase(),
                  style: TextStyle(
                    color: record.status == 'active' ? Colors.green[800] : Colors.grey[800],
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
                          'Clock In: ${DateFormat('h:mm a').format(record.clockInTime)}',
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
                          record.clockOutTime != null ? Icons.logout : Icons.schedule,
                          color: record.clockOutTime != null ? Colors.red[600] : Colors.orange[600],
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          record.clockOutTime != null 
                              ? 'Clock Out: ${DateFormat('h:mm a').format(record.clockOutTime!)}'
                              : 'Still Active',
                          style: TextStyle(
                            color: record.clockOutTime != null ? Colors.red[800] : Colors.orange[800],
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
                    'Duration',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    record.formattedDuration,
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
    if (_staffClockIns.isEmpty) return const SizedBox.shrink();
    
    int totalRecords = _staffClockIns.values.fold(0, (sum, records) => sum + records.length);
    int totalStaff = _staffClockIns.length;
    
    // Calculate total hours worked by all staff
    Duration totalHours = Duration.zero;
    for (final records in _staffClockIns.values) {
      for (final record in records) {
        if (record.clockOutTime != null) {
          totalHours += record.workedDuration;
        }
      }
    }
    
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
            'Staff Clock-In Summary - $monthName',
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
                    totalStaff.toString(),
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
                    totalRecords.toString(),
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
                    '${totalHours.inHours}h',
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
      _fetchAllClockInData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Staff Clock-In Times',
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
                
                // Staff clock-in list
                Expanded(
                  child: _staffClockIns.isEmpty
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
                                'No clock-in records found',
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
                          itemCount: _staffClockIns.keys.length,
                          itemBuilder: (context, index) {
                            final staffName = _staffClockIns.keys.elementAt(index);
                            final clockIns = _staffClockIns[staffName]!;
                            return _buildStaffClockInCard(staffName, clockIns, index);
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
