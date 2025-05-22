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
  DateTime? _selectedDate;
  String? _selectedMinister;
  // Removed role filter",
  String? _selectedStatus;
  String? _selectedConsultant;
  bool _loading = false;
  List<Map<String, dynamic>> _results = [];
  // Removed role filter options
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
    DateTime? filterStart;
    DateTime? filterEnd;
    if (_selectedDate != null) {
      filterStart = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day);
      filterEnd = filterStart.add(const Duration(days: 1));
      query = query
        .where('appointmentTime', isGreaterThanOrEqualTo: filterStart)
        .where('appointmentTime', isLessThan: filterEnd);
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

    try {
      final snapshot = await query.get();
      var results = snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
      if (_selectedDate != null) {
        final selectedDateStr = "${_selectedDate!.year.toString().padLeft(4, '0')}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}";
        results = results.where((item) {
          String? dateStr;
          final rawTimestamp = item['appointmentTime'];
          final rawISO = item['appointmentTimeISO'];
          if (rawTimestamp is Timestamp) {
            final dt = rawTimestamp.toDate();
            dateStr = "${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
          } else if (rawISO is String) {
            if (rawISO.length >= 10) {
              final isoDate = rawISO.substring(0, 10);
              if (isoDate == selectedDateStr) {
                dateStr = isoDate;
              }
            }
          }
          if (dateStr == null) return false;
          return dateStr == selectedDateStr;
        }).toList();
      }
      if (_selectedMinister != null && _selectedMinister!.isNotEmpty) {
        results = results.where((item) =>
          ((item['ministerFirstName'] ?? '').toString().trim() + ' ' + (item['ministerLastName'] ?? '').toString().trim()).trim() == _selectedMinister
        ).toList();
      }
      if (_selectedStatus == 'pending') {
        results = results.where((item) => item['status'] != 'completed' && item['status'] != 'cancelled').toList();
      }
      results.sort((a, b) {
        DateTime? da, db;
        final ra = a['appointmentTime'], rb = b['appointmentTime'];
        final raISO = a['appointmentTimeISO'], rbISO = b['appointmentTimeISO'];
        if (ra is Timestamp) da = ra.toDate();
        else if (raISO is String) da = DateTime.tryParse(raISO);
        if (rb is Timestamp) db = rb.toDate();
        else if (rbISO is String) db = DateTime.tryParse(rbISO);
        if (da == null || db == null) return 0;
        return db.compareTo(da); // Descending
      });
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _results = [];
        _loading = false;
      });
      print('[DEBUG] Search failed: '+e.toString());
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
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _selectedDate ?? DateTime.now(),
                              firstDate: DateTime(2022, 1, 1),
                              lastDate: DateTime(2100, 12, 31),
                            );
                            if (picked != null) {
                              setState(() {
                                _selectedDate = picked;
                              });
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.gold,
                            foregroundColor: Colors.black,
                          ),
                          child: Text(_selectedDate == null
                              ? 'Select Appointment Date'
                              : DateFormat('yyyy-MM-dd').format(_selectedDate!)),
                        ),
                      ),
                    ],
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
                              role: appointment['role'] ?? '',
                              isConsultant: (appointment['role'] ?? '') == 'consultant',
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
