import 'package:flutter/material.dart';
import 'attendance_register_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceRegisterWidgetMockScreen extends StatefulWidget {
  const AttendanceRegisterWidgetMockScreen({Key? key}) : super(key: key);

  @override
  State<AttendanceRegisterWidgetMockScreen> createState() => _AttendanceRegisterWidgetMockScreenState();
}

class _AttendanceRegisterWidgetMockScreenState extends State<AttendanceRegisterWidgetMockScreen> {
  String? _selectedUserId;
  String? _selectedUserName;
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() { _loading = true; });
    final snapshot = await FirebaseFirestore.instance.collection('users').orderBy('role').get();
    setState(() {
      _users = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'uid': doc.id,
          'name': ((data['firstName'] ?? '') + ' ' + (data['lastName'] ?? '')).trim(),
          'role': data['role'] ?? '',
        };
      })
      .where((user) => (user['role']?.toLowerCase() ?? '') != 'minister')
      .toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);
    return Scaffold(
      appBar: AppBar(title: const Text('Attendance Register (All Users)')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Select User',
                      border: OutlineInputBorder(),
                    ),
                    value: _selectedUserId,
                    items: _users.map((user) {
                      return DropdownMenuItem<String>(
                        value: user['uid'],
                        child: Text('${user['name']} (${user['role']})'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      final user = _users.firstWhere((u) => u['uid'] == val, orElse: () => {});
                      setState(() {
                        _selectedUserId = val;
                        _selectedUserName = user['name'] ?? '';
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  if (_selectedUserId != null)
                    Expanded(
                      child: AttendanceRegisterWidget(
                        uid: _selectedUserId!,
                        month: currentMonth,
                      ),
                    ),
                  if (_selectedUserId == null)
                    const Expanded(
                      child: Center(child: Text('Select a user to view attendance', style: TextStyle(color: Colors.white54))),
                    ),
                ],
              ),
            ),
    );
  }
}
