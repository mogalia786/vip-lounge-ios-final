import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/providers/app_auth_provider.dart';

class BreakManagementScreen extends StatefulWidget {
  const BreakManagementScreen({Key? key}) : super(key: key);

  @override
  State<BreakManagementScreen> createState() => _BreakManagementScreenState();
}

class _BreakManagementScreenState extends State<BreakManagementScreen> {
  bool _isLoading = false;
  bool _isOnBreak = false;
  DateTime? _breakStartTime;
  List<Map<String, dynamic>> _breakHistory = [];
  final TextEditingController _breakReasonController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _checkBreakStatus();
    _loadBreakHistory();
  }
  
  @override
  void dispose() {
    _breakReasonController.dispose();
    super.dispose();
  }
  
  Future<void> _checkBreakStatus() async {
    final user = Provider.of<AppAuthProvider>(context, listen: false).appUser;
    if (user == null) return;
    
    try {
      setState(() {
        _isLoading = true;
      });
      
      // Check for active break
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(Duration(days: 1));
      
      final querySnapshot = await FirebaseFirestore.instance
          .collection('breaks')
          .where('userId', isEqualTo: user.id)
          .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('startTime', isLessThan: Timestamp.fromDate(endOfDay))
          .where('endTime', isEqualTo: null)
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        final breakData = querySnapshot.docs.first.data();
        setState(() {
          _isOnBreak = true;
          _breakStartTime = (breakData['startTime'] as Timestamp).toDate();
        });
      } else {
        setState(() {
          _isOnBreak = false;
          _breakStartTime = null;
        });
      }
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error checking break status: $e')),
      );
    }
  }
  
  Future<void> _loadBreakHistory() async {
    final user = Provider.of<AppAuthProvider>(context, listen: false).appUser;
    if (user == null) return;
    
    try {
      // Get today's breaks
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(Duration(days: 1));
      
      final querySnapshot = await FirebaseFirestore.instance
          .collection('breaks')
          .where('userId', isEqualTo: user.id)
          .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('startTime', isLessThan: Timestamp.fromDate(endOfDay))
          .orderBy('startTime', descending: true)
          .get();
      
      setState(() {
        _breakHistory = querySnapshot.docs.map((doc) {
          return {
            'id': doc.id,
            ...doc.data(),
          };
        }).toList();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading break history: $e')),
      );
    }
  }
  
  Future<void> _startBreak() async {
    final user = Provider.of<AppAuthProvider>(context, listen: false).appUser;
    if (user == null) return;
    
    if (_breakReasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a reason for your break')),
      );
      return;
    }
    
    try {
      setState(() {
        _isLoading = true;
      });
      
      final now = DateTime.now();
      
      // Create break record
      await FirebaseFirestore.instance.collection('breaks').add({
        'userId': user.id,
        'userName': user.name,
        'reason': _breakReasonController.text.trim(),
        'startTime': Timestamp.fromDate(now),
        'endTime': null,
        'duration': 0,
        'date': Timestamp.fromDate(DateTime(now.year, now.month, now.day)),
      });
      
      // Create activity record
      await FirebaseFirestore.instance.collection('activities').add({
        'userId': user.id,
        'userName': user.name,
        'type': 'break_start',
        'detail': 'Started break: ${_breakReasonController.text.trim()}',
        'timestamp': Timestamp.fromDate(now),
      });
      
      _breakReasonController.clear();
      
      setState(() {
        _isOnBreak = true;
        _breakStartTime = now;
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Break started at ${DateFormat('h:mm a').format(now)}')),
      );
      
      await _loadBreakHistory();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting break: $e')),
      );
    }
  }
  
  Future<void> _endBreak() async {
    final user = Provider.of<AppAuthProvider>(context, listen: false).appUser;
    if (user == null) return;
    
    try {
      setState(() {
        _isLoading = true;
      });
      
      final now = DateTime.now();
      
      // Find active break record
      final querySnapshot = await FirebaseFirestore.instance
          .collection('breaks')
          .where('userId', isEqualTo: user.id)
          .where('endTime', isEqualTo: null)
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        final breakData = doc.data();
        final startTime = (breakData['startTime'] as Timestamp).toDate();
        
        // Calculate duration
        final durationMinutes = now.difference(startTime).inMinutes;
        
        // Update break record
        await FirebaseFirestore.instance
            .collection('breaks')
            .doc(doc.id)
            .update({
              'endTime': Timestamp.fromDate(now),
              'duration': durationMinutes,
            });
        
        // Create activity record
        await FirebaseFirestore.instance.collection('activities').add({
          'userId': user.id,
          'userName': user.name,
          'type': 'break_end',
          'detail': 'Ended break (Duration: $durationMinutes minutes)',
          'timestamp': Timestamp.fromDate(now),
        });
        
        setState(() {
          _isOnBreak = false;
          _breakStartTime = null;
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Break ended at ${DateFormat('h:mm a').format(now)}')),
        );
        
        await _loadBreakHistory();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error ending break: $e')),
      );
    }
  }
  
  String _getElapsedTimeString(DateTime startTime) {
    final difference = DateTime.now().difference(startTime);
    final hours = difference.inHours;
    final minutes = difference.inMinutes % 60;
    
    if (hours > 0) {
      return '$hours hr ${minutes.toString().padLeft(2, '0')} min';
    } else {
      return '$minutes min';
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          'Break Management',
          style: TextStyle(color: AppColors.gold),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: AppColors.gold),
            onPressed: () {
              _checkBreakStatus();
              _loadBreakHistory();
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.gold))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Current break status card
                  Card(
                    color: Colors.black,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: _isOnBreak ? Colors.red : AppColors.gold,
                        width: _isOnBreak ? 2 : 1,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(
                            'Current Status',
                            style: TextStyle(
                              color: AppColors.gold,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _isOnBreak ? Icons.coffee : Icons.work,
                                color: _isOnBreak ? Colors.red : Colors.green,
                                size: 48,
                              ),
                              SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _isOnBreak ? 'On Break' : 'Working',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (_isOnBreak && _breakStartTime != null)
                                    Text(
                                      'Started: ${DateFormat('h:mm a').format(_breakStartTime!)}',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  if (_isOnBreak && _breakStartTime != null)
                                    Text(
                                      'Duration: ${_getElapsedTimeString(_breakStartTime!)}',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          SizedBox(height: 16),
                          if (_isOnBreak)
                            ElevatedButton(
                              onPressed: _endBreak,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                minimumSize: Size(double.infinity, 45),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'END BREAK',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            )
                          else
                            Column(
                              children: [
                                TextField(
                                  controller: _breakReasonController,
                                  style: TextStyle(color: Colors.white),
                                  maxLength: 100,
                                  decoration: InputDecoration(
                                    hintText: 'Reason for break...',
                                    hintStyle: TextStyle(color: Colors.grey),
                                    filled: true,
                                    fillColor: Colors.black,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(color: Colors.grey),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(color: AppColors.gold),
                                    ),
                                    counterStyle: TextStyle(color: Colors.grey),
                                  ),
                                ),
                                SizedBox(height: 8),
                                ElevatedButton(
                                  onPressed: _startBreak,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    minimumSize: Size(double.infinity, 45),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Text(
                                    'START BREAK',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 24),
                  
                  // Break history
                  Text(
                    'Today\'s Break History',
                    style: TextStyle(
                      color: AppColors.gold,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  _breakHistory.isEmpty
                      ? Card(
                          color: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: Colors.grey),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Center(
                              child: Text(
                                'No breaks recorded today',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          itemCount: _breakHistory.length,
                          itemBuilder: (context, index) {
                            final breakData = _breakHistory[index];
                            final startTime = (breakData['startTime'] as Timestamp).toDate();
                            final endTime = breakData['endTime'] != null
                                ? (breakData['endTime'] as Timestamp).toDate()
                                : null;
                            final duration = breakData['duration'] ?? 0;
                            final reason = breakData['reason'] ?? '';
                            
                            return Card(
                              color: Colors.black,
                              margin: EdgeInsets.only(bottom: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(
                                  color: endTime == null ? Colors.red : Colors.grey,
                                ),
                              ),
                              child: ListTile(
                                leading: Icon(
                                  Icons.coffee,
                                  color: endTime == null ? Colors.red : Colors.white,
                                ),
                                title: Text(
                                  reason,
                                  style: TextStyle(color: Colors.white),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Started: ${DateFormat('h:mm a').format(startTime)}',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                    if (endTime != null)
                                      Text(
                                        'Ended: ${DateFormat('h:mm a').format(endTime)} (${duration} min)',
                                        style: TextStyle(color: Colors.grey),
                                      )
                                    else
                                      Text(
                                        'In progress...',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                  
                  SizedBox(height: 24),
                  
                  // Break rules reminder
                  Card(
                    color: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: AppColors.gold),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Break Policy Reminder',
                            style: TextStyle(
                              color: AppColors.gold,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '• Standard break: 15 minutes\n'
                            '• Lunch break: 30 minutes\n'
                            '• Maximum of 2 standard breaks per shift\n'
                            '• All breaks must be recorded in the system\n'
                            '• Extended breaks require manager approval',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
