import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/colors.dart';


class DailySchedule extends StatelessWidget {
  final DateTime selectedDate;

  const DailySchedule({
    Key? key,
    required this.selectedDate,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final selectedDateString = DateFormat('yyyy-MM-dd').format(selectedDate);
    print('Selected date for appointments: $selectedDateString');
    
    // Format the selected date for the Firestore query
    final selectedDateStart = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );
    
    final selectedDateEnd = selectedDateStart.add(const Duration(days: 1));
    
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('appointmentTime', isGreaterThanOrEqualTo: Timestamp.fromDate(selectedDateStart))
          .where('appointmentTime', isLessThan: Timestamp.fromDate(selectedDateEnd))
          .orderBy('appointmentTime')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final appointments = snapshot.data!.docs;

        if (appointments.isEmpty) {
          return const Center(
            child: Text('No appointments scheduled for today'),
          );
        }

        return ListView.builder(
          itemCount: appointments.length,
          itemBuilder: (context, index) {
            final appointment = appointments[index].data() as Map<String, dynamic>;
            final appointmentId = appointments[index].id;
            
            // Use appointmentTime for display
            DateTime appointmentTime = (appointment['appointmentTime'] as Timestamp).toDate();
            final formattedTime = DateFormat('h:mm a').format(appointmentTime);
            
            // Debug appointment data structure
            print('Appointment data structure check: ${appointment.keys.toList()}');
            
            // Combine first and last name if available
            String ministerName = '';
            if (appointment.containsKey('ministerFirstName') && appointment.containsKey('ministerLastName')) {
              ministerName = '${appointment['ministerFirstName']} ${appointment['ministerLastName']}';
              print('Minister name constructed: $ministerName');
            } else if (appointment.containsKey('ministerName')) {
              ministerName = appointment['ministerName'];
              print('Minister name found directly: $ministerName');
            } else {
              print('No minister name components found in appointment');
              ministerName = 'Minister';
            }
            
            // Add ministerName to appointment data for easy access
            appointment['ministerName'] = ministerName;
            
            // Debug minister ID if available
            if (appointment.containsKey('ministerId')) {
              print('MinisterId found: ${appointment['ministerId']}');
            }
            
            // Debug staff assignment status
            print('Consultant ID: ${appointment['assignedConsultantId']}');
            print('Cleaner ID: ${appointment['assignedCleanerId']}');
            print('Concierge ID: ${appointment['assignedConciergeId']}');
            
            // Check if staff are assigned
            final bool consultantAssigned = appointment['assignedConsultantId'] != null;
            final bool cleanerAssigned = appointment['assignedCleanerId'] != null;
            final bool conciergeAssigned = appointment['assignedConciergeId'] != null;
            
            return Container(
              margin: const EdgeInsets.only(bottom: 10, left: 8, right: 8),
              decoration: BoxDecoration(
                color: Colors.grey[850],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.gold.withOpacity(0.3)),
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Left side - Status indicator
                    Container(
                      width: 8,
                      decoration: BoxDecoration(
                        color: _getStatusColor(appointment['status']),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(7),
                          bottomLeft: Radius.circular(7),
                        ),
                      ),
                    ),
                    
                    // Main content area
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Top row - Minister and time
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    _getMinisterName(appointment),
                                    style: TextStyle(
                                      color: Colors.white, 
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.gold.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    formattedTime,
                                    style: TextStyle(
                                      color: AppColors.gold,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            
                            // Service and venue
                             Padding(
                              padding: const EdgeInsets.only(top: 6.0),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    Icon(Icons.spa, size: 14, color: Colors.grey),
                                    SizedBox(width: 4),
                                    Text(
                                      '${appointment['serviceName'] ?? 'Not specified'}',
                                      style: TextStyle(color: Colors.white70, fontSize: 13),
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      _getStatusText(appointment['status']),
                                      style: TextStyle(
                                        color: _getStatusColor(appointment['status']),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            
                            // Venue
                            if (appointment['venueName'] != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Row(
                                  children: [
                                    Icon(Icons.place, size: 14, color: Colors.grey),
                                    SizedBox(width: 4),
                                    Text(
                                      '${appointment['venueName']}',
                                      style: TextStyle(color: Colors.white70, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                            
                            // Staff assignment buttons
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Row(
                                children: [
                                  // Consultant button
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () => _showStaffSelectionDialog(context, appointmentId, 'consultant'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: consultantAssigned ? Colors.green : AppColors.gold,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                        padding: const EdgeInsets.symmetric(vertical: 0),
                                        minimumSize: Size(0, 28),
                                        elevation: 0,
                                      ),
                                      child: Text(
                                        consultantAssigned ? (appointment['consultantName'] ?? 'Reassign') : 'Consultant',
                                        style: const TextStyle(color: Colors.black, fontSize: 11),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  
                                  // Cleaner button
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () => _showStaffSelectionDialog(context, appointmentId, 'cleaner'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: cleanerAssigned ? Colors.green : AppColors.gold,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                        padding: const EdgeInsets.symmetric(vertical: 0),
                                        minimumSize: Size(0, 28),
                                        elevation: 0,
                                      ),
                                      child: Text(
                                        cleanerAssigned ? (appointment['cleanerName'] ?? 'Reassign') : 'Cleaner',
                                        style: const TextStyle(color: Colors.black, fontSize: 11),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  
                                  // Concierge button
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () => _showStaffSelectionDialog(context, appointmentId, 'concierge'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: conciergeAssigned ? Colors.green : AppColors.gold,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                        padding: const EdgeInsets.symmetric(vertical: 0),
                                        minimumSize: Size(0, 28),
                                        elevation: 0,
                                      ),
                                      child: Text(
                                        conciergeAssigned ? (appointment['conciergeName'] ?? 'Reassign') : 'Concierge',
                                        style: const TextStyle(color: Colors.black, fontSize: 11),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _getMinisterName(Map<String, dynamic> appointment) {
    // Try different potential field names for minister
    if (appointment.containsKey('ministerName')) {
      return appointment['ministerName'];
    } else if (appointment.containsKey('minister_name')) {
      return appointment['minister_name'];
    } else if (appointment.containsKey('userName')) {
      return appointment['userName'];
    } else if (appointment.containsKey('minister')) {
      var minister = appointment['minister'];
      if (minister is Map<String, dynamic> && minister.containsKey('name')) {
        return minister['name'];
      }
      return minister?.toString() ?? 'Unknown Minister';
    }
    return 'Unknown Minister';
  }

  Color _getStatusColor(String? status) {
    if (status == null) return Colors.grey;
    
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'assigned':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String? status) {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'assigned':
        return 'Assigned';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return 'Unknown';
    }
  }
  
  void _showStaffSelectionDialog(BuildContext context, String appointmentId, String staffType) async {
    // Get the appropriate staff based on type
    String staffTitle;
    String roleValue;
    
    switch (staffType) {
      case 'consultant':
        staffTitle = 'Consultant';
        roleValue = 'consultant';
        break;
      case 'cleaner':
        staffTitle = 'Cleaner';
        roleValue = 'cleaner';
        break;
      case 'concierge':
        staffTitle = 'Concierge';
        roleValue = 'concierge';
        break;
      default:
        staffTitle = 'Staff';
        roleValue = 'staff';
    }
    
    // Debug the query to console
    print('Querying users with role: $roleValue');
    
    // Fetch available staff from Firestore
    final staffSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: roleValue)
        .get();
    
    print('Found ${staffSnapshot.docs.length} staff members with role $roleValue');
    
    if (staffSnapshot.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No $staffTitle available'))
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Select $staffTitle'),
          content: Container(
            width: double.maxFinite,
            height: 300,
            child: ListView.builder(
              itemCount: staffSnapshot.docs.length,
              itemBuilder: (context, index) {
                final staff = staffSnapshot.docs[index].data();
                final staffId = staffSnapshot.docs[index].id;
                
                // Get the name field - try different possible field names
                String staffName = 'Unknown';
                if (staff.containsKey('name')) {
                  staffName = staff['name'];
                } else if (staff.containsKey('userName')) {
                  staffName = staff['userName'];
                } else if (staff.containsKey('displayName')) {
                  staffName = staff['displayName'];
                } else if (staff.containsKey('firstName')) {
                  // If both first and last name exist, combine them
                  if (staff.containsKey('lastName')) {
                    staffName = '${staff['firstName']} ${staff['lastName']}';
                  } else {
                    staffName = staff['firstName'];
                  }
                }
                
                // Debug the staff data
                print('Staff data: $staff');
                print('Using staff name: $staffName');
                
                return ListTile(
                  title: Text(staffName),
                  subtitle: Text('ID: $staffId'),
                  onTap: () => _assignStaff(context, appointmentId, staffType, staffId, staffName),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
          ],
        );
      },
    );
  }
  
  void _assignStaff(BuildContext context, String appointmentId, String staffType, String staffId, String staffName) async {
    try {
      // Update the appointment with staff assignment
      Map<String, dynamic> updateData = {};
      
      // Set the appropriate fields based on staff type
      switch (staffType) {
        case 'consultant':
          updateData = {
            'assignedConsultantId': staffId,
            'consultantName': staffName,
            'status': 'assigned'
          };
          break;
        case 'cleaner':
          updateData = {
            'assignedCleanerId': staffId,
            'cleanerName': staffName,
          };
          break;
        case 'concierge':
          updateData = {
            'assignedConciergeId': staffId,
            'conciergeName': staffName,
          };
          break;
      }
      
      // Update the appointment in Firestore
      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(appointmentId)
          .update(updateData);
      
      // Create notification for the assigned staff
      await FirebaseFirestore.instance.collection('notifications').add({
        'title': 'New Assignment',
        'body': 'You have been assigned to an appointment',
        'timestamp': Timestamp.now(),
        'role': staffType,
        'isRead': false,
        'appointmentId': appointmentId,
        'assignedToId': staffId,
      });
      
      // Close the dialog and show success message
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$staffName has been assigned successfully'))
      );
    } catch (e) {
      // Handle errors
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error assigning staff: $e'))
      );
    }
  }
}
