import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../core/widgets/unified_appointment_card.dart';
import '../../core/constants/colors.dart';

class UnifiedAppointmentSearchScreen extends StatefulWidget {
  const UnifiedAppointmentSearchScreen({Key? key}) : super(key: key);

  @override
  State<UnifiedAppointmentSearchScreen> createState() => _UnifiedAppointmentSearchScreenState();
}

class _UnifiedAppointmentSearchScreenState extends State<UnifiedAppointmentSearchScreen> {
  DateTime? _fromDate;
  DateTime? _toDate;
  bool _showAllDates = false;
  String? _selectedMinister;
  String? _selectedRole;
  String? _selectedStatus;
  String? _selectedConsultant;
  bool _loading = false;
  List<Map<String, dynamic>> _results = [];
  final List<String> _roleOptions = ['consultant', 'concierge', 'cleaner'];
  final List<String> _statusOptions = ['completed', 'pending', 'cancelled'];
  List<String> _ministerOptions = [];
  List<String> _consultantOptions = [];

  @override
  void initState() {
    super.initState();
    _fetchMinisters();
    _fetchConsultants();
  }

  Future<void> _fetchMinisters() async {
    final snapshot = await FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'minister').get();
    setState(() {
      _ministerOptions = snapshot.docs.map((doc) {
        final data = doc.data();
        return (data['firstName'] ?? '') + ' ' + (data['lastName'] ?? '');
      }).where((name) => name.trim().isNotEmpty).toList().cast<String>();
    });
  }

  Future<void> _fetchConsultants() async {
    final snapshot = await FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'consultant').get();
    setState(() {
      _consultantOptions = snapshot.docs.map((doc) {
        final data = doc.data();
        return (data['firstName'] ?? '') + ' ' + (data['lastName'] ?? '');
      }).where((name) => name.trim().isNotEmpty).toList().cast<String>();
    });
  }

  Future<void> _performSearch() async {
    setState(() { _loading = true; });
    Query query = FirebaseFirestore.instance.collection('appointments');
    if (!_showAllDates && _fromDate != null && _toDate != null) {
      final start = DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day);
      final end = DateTime(_toDate!.year, _toDate!.month, _toDate!.day).add(const Duration(days: 1));
      query = query.where('appointmentTime', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
                   .where('appointmentTime', isLessThan: Timestamp.fromDate(end));
    }
    if (_selectedMinister != null && _selectedMinister!.isNotEmpty) {
      query = query.where('ministerName', isEqualTo: _selectedMinister);
    }
    if (_selectedRole != null && _selectedRole!.isNotEmpty) {
      query = query.where('role', isEqualTo: _selectedRole);
    }
    if (_selectedStatus != null && _selectedStatus!.isNotEmpty) {
      if (_selectedStatus == 'completed') {
        query = query.where('status', isEqualTo: 'completed');
      } else if (_selectedStatus == 'cancelled') {
        query = query.where('status', isEqualTo: 'cancelled');
      }
    }
    if (_selectedConsultant != null && _selectedConsultant!.isNotEmpty) {
      query = query.where('consultantName', isEqualTo: _selectedConsultant);
    }
    query = query.orderBy('appointmentTime', descending: true);
    try {
      final snapshot = await query.get();
      var results = snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
      if (_selectedStatus == 'pending') {
        results = results.where((item) => item['status'] != 'completed' && item['status'] != 'cancelled').toList();
      }
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _results = [];
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Search failed: ' + e.toString()), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Appointment Search'),
        backgroundColor: AppColors.gold,
        foregroundColor: Colors.black,
      ),
      backgroundColor: Colors.grey[900],
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Checkbox(
                        value: _showAllDates,
                        onChanged: (val) {
                          setState(() {
                            _showAllDates = val ?? false;
                            if (_showAllDates) {
                              _fromDate = null;
                              _toDate = null;
                            }
                          });
                        },
                        activeColor: AppColors.gold,
                      ),
                      const Text('Show All Dates', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                  if (!_showAllDates) ...[
                    const SizedBox(height: 8),
                    const Text('From:', style: TextStyle(color: Colors.white)),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _fromDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                          builder: (context, child) => Theme(
                            data: ThemeData.dark(),
                            child: child!,
                          ),
                        );
                        if (picked != null) {
                          setState(() { _fromDate = picked; });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey[850],
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.gold.withOpacity(0.3)),
                        ),
                        child: Text(
                          _fromDate != null
                              ? DateFormat('yyyy-MM-dd').format(_fromDate!)
                              : 'Select From Date',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('To:', style: TextStyle(color: Colors.white)),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _toDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                          builder: (context, child) => Theme(
                            data: ThemeData.dark(),
                            child: child!,
                          ),
                        );
                        if (picked != null) {
                          setState(() { _toDate = picked; });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey[850],
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.gold.withOpacity(0.3)),
                        ),
                        child: Text(
                          _toDate != null
                              ? DateFormat('yyyy-MM-dd').format(_toDate!)
                              : 'Select To Date',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedMinister,
                    items: _ministerOptions.map((name) => DropdownMenuItem(
                      value: name,
                      child: Text(name, style: const TextStyle(color: Colors.black)),
                    )).toList(),
                    onChanged: (val) => setState(() => _selectedMinister = val),
                    decoration: const InputDecoration(
                      labelText: 'Minister',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(),
                    ),
                    dropdownColor: Colors.white,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedConsultant,
                    items: _consultantOptions.map((name) => DropdownMenuItem(
                      value: name,
                      child: Text(name, style: const TextStyle(color: Colors.black)),
                    )).toList(),
                    onChanged: (val) => setState(() => _selectedConsultant = val),
                    decoration: const InputDecoration(
                      labelText: 'Consultant',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(),
                    ),
                    dropdownColor: Colors.white,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedRole,
                    items: _roleOptions.map((role) => DropdownMenuItem(
                      value: role,
                      child: Text(role[0].toUpperCase() + role.substring(1), style: const TextStyle(color: Colors.black)),
                    )).toList(),
                    onChanged: (val) => setState(() => _selectedRole = val),
                    decoration: const InputDecoration(
                      labelText: 'Role',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(),
                    ),
                    dropdownColor: Colors.white,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedStatus,
                    items: _statusOptions.map((status) => DropdownMenuItem(
                      value: status,
                      child: Text(status[0].toUpperCase() + status.substring(1), style: const TextStyle(color: Colors.black)),
                    )).toList(),
                    onChanged: (val) => setState(() => _selectedStatus = val),
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(),
                    ),
                    dropdownColor: Colors.white,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _performSearch,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.gold,
                            foregroundColor: Colors.black,
                          ),
                          child: const Text('Search'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white24),
            _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
                : _results.isEmpty
                    ? const Center(child: Text('No results found', style: TextStyle(color: Colors.white70)))
                    : ListView.builder(
                        itemCount: _results.length,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemBuilder: (context, index) {
                          final appointment = _results[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                            child: UnifiedAppointmentCard(
                              role: _selectedRole ?? '',
                              isConsultant: _selectedRole == 'consultant',
                              ministerName: appointment['ministerName'] ?? '',
                              appointmentId: appointment['id'] ?? '',
                              appointmentInfo: appointment,
                              date: (appointment['appointmentTime'] is Timestamp)
                                  ? (appointment['appointmentTime'] as Timestamp).toDate()
                                  : null,
                              ministerId: appointment['ministerId'] ?? '',
                              disableStartSession: true,
                              viewOnly: true,
                            ),
                          );
                        },
                      ),
          ],
        ),
      ),
    );
  }
}
