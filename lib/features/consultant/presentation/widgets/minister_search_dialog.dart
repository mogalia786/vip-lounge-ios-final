import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MinisterSearchDialog extends StatefulWidget {
  final Function(Map<String, dynamic> minister) onMinisterSelected;
  final List<Map<String, dynamic>> appointments;
  const MinisterSearchDialog({Key? key, required this.onMinisterSelected, required this.appointments}) : super(key: key);

  @override
  State<MinisterSearchDialog> createState() => _MinisterSearchDialogState();
}

class _MinisterSearchDialogState extends State<MinisterSearchDialog> {
  List<Map<String, dynamic>> _ministers = [];
  List<Map<String, dynamic>> _filteredMinisters = [];
  bool _isLoading = true;
  String _searchText = '';

  // Add filter for assigned to
  String _assignedFilter = 'me'; // 'me' or 'all'

  @override
  void initState() {
    super.initState();
    _fetchMinisters();
  }

  Future<void> _fetchMinisters() async {
    final query = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'minister')
        .orderBy('firstName')
        .get();
    final ministers = query.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    setState(() {
      _ministers = ministers;
      _filteredMinisters = ministers;
      _isLoading = false;
    });
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchText = value;
      _filteredMinisters = _ministers
          .where((minister) =>
              (minister['firstName'] ?? '').toString().toLowerCase().contains(value.toLowerCase()) ||
              (minister['lastName'] ?? '').toString().toLowerCase().contains(value.toLowerCase()) ||
              (minister['email'] ?? '').toString().toLowerCase().contains(value.toLowerCase()))
          .toList();
    });
  }

  void _onAssignedFilterChanged(String? value) {
    if (value == null) return;
    setState(() {
      _assignedFilter = value;
    });
  }

  List<Map<String, dynamic>> _appointmentsForMinister(String ministerId) {
    // Only show appointments that are assigned (consultantId, assignedConsultantId, or status is not 'pending')
    return widget.appointments.where((appt) {
      final assigned = (appt['consultantId'] != null && appt['consultantId'].toString().isNotEmpty) ||
                      (appt['assignedConsultantId'] != null && appt['assignedConsultantId'].toString().isNotEmpty);
      return appt['ministerId'] == ministerId && assigned;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    return AlertDialog(
      backgroundColor: Colors.black,
      title: const Text('Select Minister', style: TextStyle(color: Colors.white)),
      content: SizedBox(
        width: 350,
        height: 460,
        child: Column(
          children: [
            // Change radio buttons from horizontal row to vertical column
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RadioListTile<String>(
                  value: 'me',
                  groupValue: _assignedFilter,
                  onChanged: _onAssignedFilterChanged,
                  activeColor: Colors.amber,
                  title: const Text('Assigned to Me', style: TextStyle(color: Colors.white, fontSize: 13)),
                ),
                RadioListTile<String>(
                  value: 'all',
                  groupValue: _assignedFilter,
                  onChanged: _onAssignedFilterChanged,
                  activeColor: Colors.amber,
                  title: const Text('Assigned to All', style: TextStyle(color: Colors.white, fontSize: 13)),
                ),
              ],
            ),
            TextField(
              onChanged: _onSearchChanged,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Search by name or email',
                hintStyle: TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.black54,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredMinisters.isEmpty
                      ? const Center(child: Text('No ministers found.', style: TextStyle(color: Colors.white70)))
                      : ListView.builder(
                          itemCount: _filteredMinisters.length,
                          itemBuilder: (context, index) {
                            final minister = _filteredMinisters[index];
                            return ListTile(
                              title: Text(
                                '${minister['firstName'] ?? ''} ${minister['lastName'] ?? ''}',
                                style: const TextStyle(color: Colors.white),
                              ),
                              subtitle: Text(
                                minister['email'] ?? '',
                                style: const TextStyle(color: Colors.white54),
                              ),
                              onTap: () {
                                final ministerData = {
                                  ...minister,
                                  'assignedFilter': _assignedFilter,
                                };
                                Navigator.pop(context, ministerData); // Pass data back
                              },
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
