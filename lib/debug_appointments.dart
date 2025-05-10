import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Debug Appointments',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.dark,
      ),
      home: const DebugAppointmentsScreen(),
    );
  }
}

class DebugAppointmentsScreen extends StatefulWidget {
  const DebugAppointmentsScreen({Key? key}) : super(key: key);

  @override
  State<DebugAppointmentsScreen> createState() => _DebugAppointmentsScreenState();
}

class _DebugAppointmentsScreenState extends State<DebugAppointmentsScreen> {
  List<Map<String, dynamic>> allAppointments = [];
  bool _isLoading = true;
  String _error = '';
  
  @override
  void initState() {
    super.initState();
    _fetchAllAppointments();
  }
  
  Future<void> _fetchAllAppointments() async {
    try {
      setState(() {
        _isLoading = true;
        _error = '';
      });
      
      // Get all appointments
      final appointmentsSnapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .get();
          
      print('Found ${appointmentsSnapshot.docs.length} total appointments');
      
      List<Map<String, dynamic>> appointments = [];
      
      for (var doc in appointmentsSnapshot.docs) {
        final data = doc.data();
        final appointmentTime = data['appointmentTime'] as Timestamp?;
        final consultantId = data['consultantId'] as String?;
        
        Map<String, dynamic> appointment = {
          'id': doc.id,
          ...data,
          'prettyTime': appointmentTime != null 
              ? DateFormat('yyyy-MM-dd HH:mm').format(appointmentTime.toDate())
              : 'No time',
        };
        
        print('Appointment: ${doc.id}');
        print('  Consultant: $consultantId');
        print('  Time: ${appointment['prettyTime']}');
        print('  Fields: ${data.keys.toList()}');
        
        appointments.add(appointment);
      }
      
      // Get all consultants for reference
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'consultant')
          .get();
          
      print('\nFound ${usersSnapshot.docs.length} consultants:');
      for (var doc in usersSnapshot.docs) {
        final data = doc.data();
        print('Consultant ID: ${doc.id}, Name: ${data['firstName']} ${data['lastName']}');
      }
      
      setState(() {
        allAppointments = appointments;
        _isLoading = false;
      });
    } catch (error) {
      print('Error fetching appointments: $error');
      setState(() {
        _error = 'Error: $error';
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Appointments'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(child: Text(_error, style: const TextStyle(color: Colors.red)))
              : allAppointments.isEmpty
                  ? const Center(child: Text('No appointments found'))
                  : ListView.builder(
                      itemCount: allAppointments.length,
                      itemBuilder: (context, index) {
                        final appointment = allAppointments[index];
                        return Card(
                          margin: const EdgeInsets.all(8),
                          child: ListTile(
                            title: Text(appointment['consultantId'] ?? 'No consultant'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Time: ${appointment['prettyTime']}'),
                                Text('Status: ${appointment['status'] ?? 'No status'}'),
                                Text('Client: ${appointment['clientName'] ?? 'No client name'}'),
                                Text('ID: ${appointment['id']}'),
                              ],
                            ),
                            isThreeLine: true,
                          ),
                        );
                      },
                    ),
      floatingActionButton: FloatingActionButton(
        onPressed: _fetchAllAppointments,
        tooltip: 'Refresh',
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
