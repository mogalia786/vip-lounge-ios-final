import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StaffTodoListWidget extends StatefulWidget {
  final String userId;
  final DateTime selectedDate;
  const StaffTodoListWidget({Key? key, required this.userId, required this.selectedDate}) : super(key: key);

  @override
  State<StaffTodoListWidget> createState() => _StaffTodoListWidgetState();
}

class _StaffTodoListWidgetState extends State<StaffTodoListWidget> {
  final _taskController = TextEditingController();
  bool _isLoading = false;

  Future<void> _addTask() async {
    final task = _taskController.text.trim();
    if (task.isEmpty) return;
    setState(() => _isLoading = true);
    await FirebaseFirestore.instance.collection('staff_todos').add({
      'userId': widget.userId,
      'task': task,
      'date': DateTime(widget.selectedDate.year, widget.selectedDate.month, widget.selectedDate.day),
      'createdAt': FieldValue.serverTimestamp(),
      'completed': false,
    });
    _taskController.clear();
    setState(() => _isLoading = false);
  }

  Future<void> _toggleCompleted(String docId, bool completed) async {
    await FirebaseFirestore.instance.collection('staff_todos').doc(docId).update({'completed': completed});
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.black,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppColors.primary, width: 2)),
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.task, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'To-Do List',
                    style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 18),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Spacer(),
                Text(DateFormat('yyyy-MM-dd').format(widget.selectedDate), style: TextStyle(color: AppColors.primary)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _taskController,
                    decoration: const InputDecoration(
                      hintText: 'Enter task...',
                      hintStyle: TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: AppColors.black,
                      border: OutlineInputBorder(),
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isLoading ? null : _addTask,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.black, side: BorderSide(color: AppColors.primary)),
                  child: _isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)) : const Icon(Icons.add, color: AppColors.primary),
                ),
              ],
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('staff_todos')
                  .where('userId', isEqualTo: widget.userId)
                  .where('date', isEqualTo: DateTime(widget.selectedDate.year, widget.selectedDate.month, widget.selectedDate.day))
                  .orderBy('createdAt', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Text('No tasks for this day.', style: TextStyle(color: Colors.white54));
                }
                final docs = snapshot.data!.docs;
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(color: Colors.white12),
                  itemBuilder: (context, i) {
                    final doc = docs[i];
                    final data = doc.data() as Map<String, dynamic>;
                    return ListTile(
                      leading: Checkbox(
                        value: data['completed'] ?? false,
                        onChanged: (val) => _toggleCompleted(doc.id, val ?? false),
                        activeColor: AppColors.primary,
                      ),
                      title: Text(
                        data['task'] ?? '',
                        style: TextStyle(color: data['completed'] == true ? Colors.green : Colors.white),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
