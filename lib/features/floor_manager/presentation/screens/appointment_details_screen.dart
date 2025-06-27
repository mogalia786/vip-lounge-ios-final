import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/providers/app_auth_provider.dart';
import '../../../../core/services/vip_notification_service.dart';
import 'package:intl/intl.dart';

class AppointmentDetailsScreen extends StatefulWidget {
  final String appointmentId;
  final Map<String, dynamic>? notification;

  const AppointmentDetailsScreen({
    Key? key,
    required this.appointmentId,
    this.notification,
  }) : super(key: key);

  @override
  State<AppointmentDetailsScreen> createState() => _AppointmentDetailsScreenState();
}

class _AppointmentDetailsScreenState extends State<AppointmentDetailsScreen> {
  Map<String, dynamic>? appointment;
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _fetchAppointment();
  }

  Future<void> _fetchAppointment() async {
    setState(() {
      isLoading = true;
      error = null;
    });
    try {
      print('[DEBUG] Fetching appointment with id: \'${widget.appointmentId}\'');
      if (widget.notification != null) {
        print('[DEBUG] Notification data: \'${widget.notification}\'');
      }
      final doc = await FirebaseFirestore.instance
          .collection('appointments')
          .doc(widget.appointmentId)
          .get();
      if (doc.exists) {
        setState(() {
          appointment = doc.data();
          isLoading = false;
        });
      } else {
        setState(() {
          error = 'Appointment not found';
          isLoading = false;
        });
        print('[DEBUG] Appointment not found for id: \'${widget.appointmentId}\'');
        if (widget.notification != null) {
          print('[DEBUG] Notification data on not found: \'${widget.notification}\'');
        }
      }
    } catch (e) {
      setState(() {
        error = 'Error loading appointment: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _showStaffSelectionDialog(String staffType) async {
    if (appointment == null) return;
    final appointmentId = widget.appointmentId;
    final appointmentData = appointment!;
    final ministerId = appointmentData['ministerId'] as String?;
    Timestamp? appointmentTime;
    int duration = 60;
    if (appointmentData['appointmentTime'] is Timestamp) {
      appointmentTime = appointmentData['appointmentTime'] as Timestamp;
    }
    if (appointmentData['duration'] is int) {
      duration = appointmentData['duration'] as int;
    }
    if (appointmentTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot check availability: Appointment time not found')),
      );
      return;
    }
    if (staffType == 'consultant') {
      // Fetch both consultants and staff with role 'staff'
      final consultantsQuery = FirebaseFirestore.instance
          .collection('users')
          .where('role', whereIn: ['consultant', 'staff'])
          .get();
      final consultantsSnapshot = await consultantsQuery;
      List<DocumentSnapshot> availableConsultants = [];
      for (var consultant in consultantsSnapshot.docs) {
        final consultantId = consultant.id;
        // Use the user's actual role for availability check
        final userRole = (consultant.data() as Map<String, dynamic>)['role'] ?? 'consultant';
        final isAvailable = await _isStaffAvailable(
          consultantId,
          userRole,
          appointmentTime,
          duration,
          appointmentId,
        );
        if (isAvailable) {
          availableConsultants.add(consultant);
        }
      }
      if (availableConsultants.isEmpty && ministerId != null) {
        await _sendNoConsultantsMessage(appointmentId, ministerId);
        Navigator.of(context).pop();
        return;
      }
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.black,
          title: Text('Select $staffType', style: const TextStyle(color: AppColors.gold)),
          content: SizedBox(
            height: 300,
            width: 300,
            child: availableConsultants.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.warning, color: Colors.red, size: 48),
                        SizedBox(height: 16),
                        Text('No available consultants for this time slot', style: TextStyle(color: Colors.white), textAlign: TextAlign.center),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: availableConsultants.length,
                    itemBuilder: (context, index) {
                      final staffDoc = availableConsultants[index];
                      final staffData = staffDoc.data() as Map<String, dynamic>;
                      final staffId = staffDoc.id;
                      final firstName = staffData['firstName'] ?? '';
                      final lastName = staffData['lastName'] ?? '';
                      final staffName = '$firstName $lastName'.trim();
                      return ListTile(
                        title: Text(staffName.isNotEmpty ? staffName : 'Staff #$index', style: const TextStyle(color: Colors.white)),
                        trailing: const Icon(Icons.arrow_forward, color: AppColors.gold),
                        onTap: () async {
                          await _assignStaff(appointmentId, staffType, staffName, staffId);
                          await _fetchAppointment();
                          Navigator.of(context).pop();
                        },
                      );
                    },
                  ),
          ),
        ),
      );
    } else {
      // For concierge and cleaner
      final staffQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: staffType)
          .get();
      final staffList = staffQuery.docs;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.black,
          title: Text('Select $staffType', style: const TextStyle(color: AppColors.gold)),
          content: SizedBox(
            height: 300,
            width: 300,
            child: staffList.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.warning, color: Colors.red, size: 48),
                        const SizedBox(height: 16),
                        Text('No available $staffType for this time slot', style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: staffList.length,
                    itemBuilder: (context, index) {
                      final staffDoc = staffList[index];
                      final staffData = staffDoc.data() as Map<String, dynamic>;
                      final staffId = staffDoc.id;
                      final firstName = staffData['firstName'] ?? '';
                      final lastName = staffData['lastName'] ?? '';
                      final staffName = '$firstName $lastName'.trim();
                      return ListTile(
                        title: Text(staffName.isNotEmpty ? staffName : 'Staff #$index', style: const TextStyle(color: Colors.white)),
                        trailing: const Icon(Icons.arrow_forward, color: AppColors.gold),
                        onTap: () async {
                          await _assignStaff(appointmentId, staffType, staffName, staffId);
                          await _fetchAppointment();
                          Navigator.of(context).pop();
                        },
                      );
                    },
                  ),
          ),
        ),
      );
    }
  }

  Future<bool> _isStaffAvailable(String staffId, String staffType, Timestamp appointmentTime, int duration, String currentAppointmentId) async {
    // Check if staff is on sick leave
    final staffDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(staffId)
        .get();
    if (staffDoc.exists) {
      final staffData = staffDoc.data();
      if (staffData != null && (staffData['isSick'] == true || staffData['onSickLeave'] == true)) {
        print('[DEBUG][AVAILABILITY] Staff $staffId is on sick leave');
        return false;
      }
    }

    final appointmentStart = appointmentTime.toDate();
    final appointmentEnd = appointmentStart.add(Duration(minutes: duration));

    // Check for overlapping appointments
    final overlappingAppointments = await FirebaseFirestore.instance
        .collection('appointments')
        .where('${staffType}Id', isEqualTo: staffId)
        .get();

    for (var doc in overlappingAppointments.docs) {
      final data = doc.data();

      // Skip if looking at the same appointment
      if (doc.id == currentAppointmentId) continue;

      if (data['appointmentTime'] is Timestamp) {
        final otherAppointmentTime = data['appointmentTime'] as Timestamp;
        final otherStart = otherAppointmentTime.toDate();
        final otherDuration = data['duration'] is int ? data['duration'] as int : 60;
        final otherEnd = otherStart.add(Duration(minutes: otherDuration));

        // Check for overlap
        if (appointmentStart.isBefore(otherEnd) && appointmentEnd.isAfter(otherStart)) {
          print('[DEBUG][AVAILABILITY] Staff $staffId has conflict with appointment ${doc.id} ($otherStart - $otherEnd)');
          return false;
        }
      }
    }

    print('[DEBUG][AVAILABILITY] Staff $staffId is available for $appointmentStart - $appointmentEnd');
    return true;
  }

  Future<void> _sendNoConsultantsMessage(String appointmentId, String ministerId) async {
    await VipNotificationService().createNotification(
      title: 'No Consultants Available',
      body: 'Sorry, no consultants are available for your appointment time.',
      data: {'appointmentId': appointmentId},
      role: 'minister',
      assignedToId: ministerId,
      notificationType: 'no_consultants',
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No consultants available. Minister notified.')),
    );
  }

  Widget _buildAssignButton(String role, String? currentId, String? currentName) {
    final assigned = currentId != null && currentId.isNotEmpty;
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.gold,
        foregroundColor: Colors.black,
      ),
      onPressed: () {
        print('[DEBUG][ASSIGN BUTTON] Pressed for role: ' + role.toLowerCase());
        _showStaffSelectionDialog(role.toLowerCase());
      },
      child: assigned
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$role: '),
                Text(currentName ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                const Icon(Icons.edit, size: 18)
              ],
            )
          : Text('Assign $role'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool fromNotification = widget.notification != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Appointment Assign'),
        backgroundColor: AppColors.gold,
        foregroundColor: Colors.black,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Text(error!))
              : appointment == null
                  ? const Center(child: Text('No appointment data.'))
                  : Column(
                      children: [
                        if (fromNotification)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.amber[700]?.withOpacity(0.95) ?? Colors.amber,
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(16),
                                bottomRight: Radius.circular(16),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  offset: const Offset(0, 3),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.notifications_active, color: Colors.black, size: 22),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Opened from notification',
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Card(
                              color: Colors.grey[900],
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: Colors.grey[800]!,
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Top section with time and status
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: const BoxDecoration(
                                      color: Colors.black,
                                      borderRadius: BorderRadius.only(
                                        topLeft: Radius.circular(12),
                                        topRight: Radius.circular(12),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.schedule, color: AppColors.gold, size: 18),
                                            const SizedBox(width: 8),
                                            Text(
                                              appointment!['appointmentTime'] != null
                                                  ? DateFormat('h:mm a').format((appointment!['appointmentTime'] as Timestamp).toDate())
                                                  : 'Time not specified',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(color: Colors.blue),
                                          ),
                                          child: Text(
                                            appointment!['status'] ?? '',
                                            style: const TextStyle(
                                              color: Colors.blue,
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Main content
                                  Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Minister and Service details
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            CircleAvatar(
                                              radius: 24,
                                              backgroundColor: Colors.deepPurple,
                                              child: Text(
                                                (appointment!['ministerName'] ?? 'M').toString().isNotEmpty
                                                    ? (appointment!['ministerName'] ?? 'M')[0].toUpperCase()
                                                    : 'M',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 18,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    (appointment!['ministerName'] ?? appointment!['ministerFirstName'] ?? '') + (appointment!['ministerLastName'] != null ? ' ${appointment!['ministerLastName']}' : ''),
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 18,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    appointment!['serviceName'] ?? '',
                                                    style: TextStyle(
                                                      color: Colors.grey[400],
                                                      fontSize: 15,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        // Staff assignment buttons
                                        SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.start,
                                            children: [
                                              _buildAssignButton('Consultant', appointment!['consultantId'], appointment!['consultantName']),
                                              const SizedBox(width: 8),
                                              _buildAssignButton('Concierge', appointment!['conciergeId'], appointment!['conciergeName']),
                                              const SizedBox(width: 8),
                                              _buildAssignButton('Cleaner', appointment!['cleanerId'], appointment!['cleanerName']),
                                            ],
                                          ),
                                        ),
                                        const Divider(height: 32),
                                        Text('Date: '
                                              + (appointment!['appointmentTime'] != null
                                                  ? DateFormat('yyyy-MM-dd').format((appointment!['appointmentTime'] as Timestamp).toDate())
                                                  : 'Not specified'),
                                              style: const TextStyle(fontSize: 16)),
                                        const SizedBox(height: 8),
                                        Text('Venue: ${appointment!['venueName'] ?? ''}', style: const TextStyle(fontSize: 16)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
    );
  }

  Future<void> _assignStaff(String appointmentId, String staffType, String staffName, String staffId) async {
    try {
      final user = Provider.of<AppAuthProvider>(context, listen: false).appUser;
      final floorManagerId = user?.uid;
      final floorManagerName = user?.name ?? 'Floor Manager';
      final appointmentDoc = await FirebaseFirestore.instance
          .collection('appointments')
          .doc(appointmentId)
          .get();
      if (!appointmentDoc.exists) {
        throw Exception('Appointment not found');
      }
      final appointmentData = appointmentDoc.data();
      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
        'lastUpdatedBy': floorManagerId,
        'lastUpdatedByName': floorManagerName,
      };

      if (staffType == 'consultant') {
        updateData['consultantId'] = staffId;
        updateData['consultantName'] = staffName;
        // Reset session state fields for consultant
        updateData['consultantSessionStarted'] = false;
        updateData['consultantSessionEnded'] = false;
        // Fetch consultant contact info from users collection
        final consultantDoc = await FirebaseFirestore.instance.collection('users').doc(staffId).get();
        final consultantData = consultantDoc.data() ?? {};
        updateData['consultantPhone'] = consultantData['phoneNumber'] ?? '';
        updateData['consultantEmail'] = consultantData['email'] ?? '';
      }
      if (staffType == 'concierge') {
        updateData['conciergeId'] = staffId;
        updateData['conciergeName'] = staffName;
        // Reset session state fields for concierge
        updateData['conciergeSessionStarted'] = false;
        updateData['conciergeSessionEnded'] = false;
        // Fetch concierge contact info from users collection
        final conciergeDoc = await FirebaseFirestore.instance.collection('users').doc(staffId).get();
        final conciergeData = conciergeDoc.data() ?? {};
        updateData['conciergePhone'] = conciergeData['phoneNumber'] ?? '';
        updateData['conciergeEmail'] = conciergeData['email'] ?? '';
      }
      if (staffType == 'cleaner') {
        updateData['cleanerId'] = staffId;
        updateData['cleanerName'] = staffName;
      }
      // Always reset session state fields for assignment
      if (staffType == 'consultant' || staffType == 'concierge') {
        updateData['consultantSessionStarted'] = false;
        updateData['consultantSessionEnded'] = false;
        updateData['conciergeSessionStarted'] = false;
        updateData['conciergeSessionEnded'] = false;
      }
      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(appointmentId)
          .update(updateData);
      // Notify assigned staff (always)
      await VipNotificationService().createNotification(
        title: 'You have been assigned as $staffType',
        body: 'You have been assigned to an appointment as $staffType ($staffName).',
        data: {
          ...?appointmentData,
          'staffType': staffType,
          'staffName': staffName,
          'assignedBy': floorManagerName,
        },
        role: staffType,
        assignedToId: staffId,
        notificationType: 'booking_assigned',
      );
      // Notify minister only for consultant or concierge
      if (appointmentData != null && appointmentData['ministerId'] != null && (staffType == 'consultant' || staffType == 'concierge')) {
        if (staffType == 'consultant') {
          // Consultant message
          await VipNotificationService().createNotification(
            title: 'Consultant Assigned',
            body: '$staffName has been assigned to your appointment.\n\nService: ${appointmentData['serviceName'] ?? ''}\nTime: ${appointmentData['appointmentTime'] != null ? DateFormat('h:mm a').format((appointmentData['appointmentTime'] as Timestamp).toDate()) : ''}\nVenue: ${appointmentData['venueName'] ?? ''}',
            data: {
              ...appointmentData,
              'staffType': staffType,
              'staffName': staffName,
            },
            role: 'minister',
            assignedToId: appointmentData['ministerId'],
            notificationType: 'staff_assigned',
          );
        } else if (staffType == 'concierge') {
          // Concierge message
          final phone = appointmentData['conciergePhone'] ?? '';
          await VipNotificationService().createNotification(
            title: 'Concierge Assigned',
            body: '$staffName will meet you on arrival. Should you wish to contact or message him, these are his details:\nPhone Number: $phone',
            data: {
              ...appointmentData,
              'staffType': staffType,
              'staffName': staffName,
              'conciergePhone': phone,
              'showChatWithConcierge': true,
            },
            role: 'minister',
            assignedToId: appointmentData['ministerId'],
            notificationType: 'staff_assigned',
          );
        }
      }
      // Confirmation for Floor Manager
      await VipNotificationService().createNotification(
        title: 'Staff Assignment Successful',
        body: 'You assigned $staffType $staffName to appointment $appointmentId.',
        data: {
          ...?appointmentData,
          'staffType': staffType,
          'staffName': staffName,
          'assignedBy': floorManagerName,
        },
        role: 'floor_manager',
        assignedToId: floorManagerId,
        notificationType: 'staff_assigned',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$staffType assigned successfully')),
      );
      // Refresh appointment data
      await _fetchAppointment();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
}
