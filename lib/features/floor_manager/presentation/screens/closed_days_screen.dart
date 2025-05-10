import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ClosedDaysScreen extends StatefulWidget {
  const ClosedDaysScreen({Key? key}) : super(key: key);

  @override
  State<ClosedDaysScreen> createState() => _ClosedDaysScreenState();
}

class _ClosedDaysScreenState extends State<ClosedDaysScreen> {
  final List<DateTime> _closedDays = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchClosedDays();
  }

  Future<void> _fetchClosedDays() async {
    final doc = await FirebaseFirestore.instance.collection('business').doc('settings').get();
    final data = doc.data();
    if (data != null && data['closedDays'] != null) {
      final List<dynamic> days = data['closedDays'];
      setState(() {
        _closedDays.clear();
        _closedDays.addAll(days.map((e) => DateTime.parse(e.toString())));
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _saveClosedDays() async {
    await FirebaseFirestore.instance.collection('business').doc('settings').set({
      'closedDays': _closedDays.map((d) => DateFormat('yyyy-MM-dd').format(d)).toList(),
    }, SetOptions(merge: true));
    // Update timeslots for each closed day
    for (final day in _closedDays) {
      final dayStr = DateFormat('yyyy-MM-dd').format(day);
      await FirebaseFirestore.instance
        .collection('business')
        .doc('settings')
        .collection('timeslots')
        .doc(dayStr)
        .set({
          'slots': [],
          'closed': true,
        }, SetOptions(merge: true));
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Closed days updated and timeslots cleared.')),
    );
  }

  void _addClosedDay() async {
    DateTime now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year, 1, 1),
      lastDate: DateTime(now.year + 2, 12, 31),
    );
    if (picked != null && !_closedDays.contains(picked)) {
      setState(() {
        _closedDays.add(picked);
        _closedDays.sort();
      });
    }
  }

  void _removeClosedDay(DateTime day) {
    setState(() {
      _closedDays.remove(day);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Closed Days'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveClosedDays,
            tooltip: 'Save',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addClosedDay,
        child: const Icon(Icons.add),
        tooltip: 'Add Closed Day',
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _closedDays.isEmpty
              ? const Center(child: Text('No closed days set.'))
              : ListView.builder(
                  itemCount: _closedDays.length,
                  itemBuilder: (context, idx) {
                    final day = _closedDays[idx];
                    return ListTile(
                      title: Text(
                        DateFormat('EEE, MMM d, yyyy').format(day),
                        style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _removeClosedDay(day),
                      ),
                    );
                  },
                ),
    );
  }
}
