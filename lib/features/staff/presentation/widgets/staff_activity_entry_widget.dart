import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class StaffActivityEntryWidget extends StatefulWidget {
  final String userId;
  final VoidCallback? onActivityAdded;
  const StaffActivityEntryWidget({Key? key, required this.userId, this.onActivityAdded}) : super(key: key);

  @override
  State<StaffActivityEntryWidget> createState() => _StaffActivityEntryWidgetState();
}

class _StaffActivityEntryWidgetState extends State<StaffActivityEntryWidget> {
  final _descController = TextEditingController();
  final _revenueController = TextEditingController();
  bool _isSale = false;
  bool _isLoading = false;

  Future<void> _addActivity() async {
    final desc = _descController.text.trim();
    final revenue = double.tryParse(_revenueController.text.trim()) ?? 0.0;
    if (desc.isEmpty) return;
    setState(() => _isLoading = true);
    await FirebaseFirestore.instance.collection('staff_activities').add({
      'userId': widget.userId,
      'description': desc,
      'date': DateTime.now(),
      'revenue': revenue,
      'isSale': _isSale,
      'createdAt': FieldValue.serverTimestamp(),
    });
    _descController.clear();
    _revenueController.clear();
    setState(() {
      _isSale = false;
      _isLoading = false;
    });
    if (widget.onActivityAdded != null) {
      widget.onActivityAdded!();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.black,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppColors.richGold!, width: 2)),
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.add_task, color: AppColors.richGold),
                const SizedBox(width: 8),
                Text('Add Activity', style: TextStyle(color: AppColors.richGold, fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: 'Activity Description',
                labelStyle: TextStyle(color: AppColors.richGold),
                filled: true,
                fillColor: Colors.black54,
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _revenueController,
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Revenue Generated (ZAR)',
                      labelStyle: TextStyle(color: AppColors.richGold),
                      filled: true,
                      fillColor: Colors.black54,
                      border: OutlineInputBorder(),
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Row(
                  children: [
                    Checkbox(
                      value: _isSale,
                      onChanged: (val) => setState(() => _isSale = val ?? false),
                      activeColor: AppColors.richGold,
                    ),
                    const Text('Sale', style: TextStyle(color: AppColors.richGold)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('attendance')
                  .doc(widget.userId)
                  .collection('attendance')
                  .orderBy('clockInTime', descending: true)
                  .limit(1)
                  .snapshots(),
              builder: (context, snapshot) {
                bool disable = false;
                if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                  final data = snapshot.data!.docs.first.data();
                  final isOnBreak = data['isOnBreak'] == true;
                  final isClockedIn = data['isClockedIn'] == true;
                  disable = isOnBreak || !isClockedIn;
                }
                return SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading || disable ? null : _addActivity,
                    icon: _isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) : const Icon(Icons.add, color: Colors.black),
                    label: const Text('Add Activity', style: TextStyle(color: Colors.black)),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.richGold),
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
