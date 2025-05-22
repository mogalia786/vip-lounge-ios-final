import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/colors.dart';

class FloorManagerSearchDialog extends StatefulWidget {
  final void Function(List<Map<String, dynamic>>) onResults;
  const FloorManagerSearchDialog({Key? key, required this.onResults}) : super(key: key);

  @override
  State<FloorManagerSearchDialog> createState() => _FloorManagerSearchDialogState();
}

class _FloorManagerSearchDialogState extends State<FloorManagerSearchDialog> {
  DateTime? _fromDate;
  DateTime? _toDate;
  bool _showAllDates = false;
  String? _selectedMinister;
  String? _selectedStatus;
  bool _loading = false;
  List<Map<String, dynamic>> _results = [];
  final List<String> _statusOptions = ['completed', 'pending', 'cancelled'];
  List<String> _ministerOptions = [];

  @override
  void initState() {
    super.initState();
    _fetchMinisters();
  }

  Future<void> _fetchMinisters() async {
    final snapshot = await FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'minister').get();
    setState(() {
      _ministerOptions = snapshot.docs.map((doc) {
        final data = doc.data();
        return (data['firstName'] ?? '') + ' ' + (data['lastName'] ?? '');
      }).where((name) => name.trim().isNotEmpty).toList();
    });
  }

  Future<void> _performSearch() async {
    setState(() { _loading = true; });
    Query query = FirebaseFirestore.instance.collection('appointments');
    // Date filter (always applied if not show all)
    if (!_showAllDates && _fromDate != null && _toDate != null) {
      final start = DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day);
      final end = DateTime(_toDate!.year, _toDate!.month, _toDate!.day).add(const Duration(days: 1));
      query = query.where('appointmentTime', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
                   .where('appointmentTime', isLessThan: Timestamp.fromDate(end));
    }
    // Minister filter
    if (_selectedMinister != null && _selectedMinister!.isNotEmpty) {
      query = query.where('ministerName', isEqualTo: _selectedMinister);
    }
    // Status filter
    if (_selectedStatus != null && _selectedStatus!.isNotEmpty) {
      if (_selectedStatus == 'completed') {
        query = query.where('status', isEqualTo: 'completed');
      } else if (_selectedStatus == 'cancelled') {
        query = query.where('status', isEqualTo: 'cancelled');
      } else if (_selectedStatus == 'pending') {
        query = query.where('status', whereNotIn: ['completed', 'cancelled']);
      }
    }
    // Always order by appointmentTime descending
    query = query.orderBy('appointmentTime', descending: true);
    final snapshot = await query.get();
    final results = snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
    setState(() {
      _results = results;
      _loading = false;
    });
    widget.onResults(_results);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.grey[900],
      title: Text('Search Appointments', style: TextStyle(color: AppColors.gold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date Range and Show All
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
                Text('Show All Dates', style: TextStyle(color: Colors.white)),
              ],
            ),
            if (!_showAllDates) ...[
              Text('From:', style: TextStyle(color: Colors.white)),
              SizedBox(height: 4),
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
                  padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[850],
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.gold.withOpacity(0.3)),
                  ),
                  child: Text(_fromDate != null ? DateFormat('yyyy-MM-dd').format(_fromDate!) : 'Select From Date', style: TextStyle(color: Colors.white)),
                ),
              ),
              SizedBox(height: 8),
              Text('To:', style: TextStyle(color: Colors.white)),
              SizedBox(height: 4),
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
                  padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[850],
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.gold.withOpacity(0.3)),
                  ),
                  child: Text(_toDate != null ? DateFormat('yyyy-MM-dd').format(_toDate!) : 'Select To Date', style: TextStyle(color: Colors.white)),
                ),
              ),
              SizedBox(height: 16),
            ],
            // Minister Dropdown
            Text('By Minister:', style: TextStyle(color: Colors.white)),
            SizedBox(height: 4),
            DropdownButtonFormField<String>(
              value: _selectedMinister,
              items: _ministerOptions.map((name) => DropdownMenuItem(
                value: name,
                child: Text(name, style: TextStyle(color: Colors.black)),
              )).toList(),
              onChanged: (val) => setState(() => _selectedMinister = val),
              decoration: InputDecoration(
                filled: true,
            // Status Dropdown
            Text('By Status:', style: TextStyle(color: Colors.white)),
            SizedBox(height: 4),
            DropdownButtonFormField<String>(
              value: _selectedStatus,
              items: _statusOptions.map((status) => DropdownMenuItem(
                value: status,
                child: Text(status[0].toUpperCase() + status.substring(1), style: TextStyle(color: Colors.black)),
              )).toList(),
              onChanged: (val) => setState(() => _selectedStatus = val),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.grey[850],
                border: OutlineInputBorder(),
              ),
              dropdownColor: Colors.white,
            ),
            SizedBox(height: 16),
            _loading ? Center(child: CircularProgressIndicator(color: AppColors.gold)) : SizedBox.shrink(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: AppColors.gold)),
        ),
        ElevatedButton(
          onPressed: _performSearch,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: Colors.black),
          child: Text('Search'),
        ),
      ],
    );
  }
}
