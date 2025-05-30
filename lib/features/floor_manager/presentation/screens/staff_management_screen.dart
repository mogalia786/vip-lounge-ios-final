import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/colors.dart';

class StaffManagementScreen extends StatefulWidget {
  final String? initialRole;
  
  const StaffManagementScreen({
    super.key,
    this.initialRole,
  });

  @override
  State<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends State<StaffManagementScreen> {
  String? _selectedRole;
  final List<String> _roles = ['All', 'floorManager', 'consultant', 'concierge', 'cleaner', 'marketingAgent'];
  
  @override
  void initState() {
    super.initState();
    _selectedRole = widget.initialRole;
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          'Staff Management',
          style: TextStyle(color: AppColors.gold),
        ),
        actions: [
          // Role filter dropdown
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: DropdownButton<String>(
              dropdownColor: Colors.grey[900],
              value: _selectedRole ?? 'All',
              icon: Icon(Icons.filter_list, color: AppColors.gold),
              underline: Container(
                height: 2,
                color: AppColors.gold,
              ),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedRole = newValue == 'All' ? null : newValue;
                });
              },
              items: _roles.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(
                    value.substring(0, 1).toUpperCase() + value.substring(1),
                    style: TextStyle(color: AppColors.gold),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _selectedRole == null
            ? FirebaseFirestore.instance
                .collection('users')
                .where('role', whereNotIn: ['minister'])
                .snapshots()
            : FirebaseFirestore.instance
                .collection('users')
                .where('role', isEqualTo: _selectedRole)
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          if (!snapshot.hasData) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.gold),
              ),
            );
          }

          final staff = snapshot.data!.docs;

          if (staff.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_off, size: 64, color: Colors.grey[700]),
                  const SizedBox(height: 16),
                  Text(
                    'No staff members found',
                    style: TextStyle(color: Colors.grey[400], fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: staff.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final staffMember = staff[index].data() as Map<String, dynamic>;
              final staffId = staff[index].id;
              final role = staffMember['role'] as String? ?? 'staff';
              final firstName = staffMember['firstName'] as String? ?? '';
              final lastName = staffMember['lastName'] as String? ?? '';
              final name = '$firstName $lastName'.trim();
              final email = staffMember['email'] as String? ?? 'No email';
              final phone = staffMember['phoneNumber'] as String? ?? 'No phone';

              return StaffCard(
                staffId: staffId,
                name: name,
                role: role,
                email: email,
                phone: phone,
                statusWidget: StaffStatusWidget(staffId: staffId),
              );
            },
          );
        },
      ),
    );
  }
}

class StaffCard extends StatelessWidget {
  final String staffId;
  final String name;
  final String role;
  final String email;
  final String phone;
  final Widget statusWidget;

  const StaffCard({
    Key? key,
    required this.staffId,
    required this.name,
    required this.role,
    required this.email,
    required this.phone,
    required this.statusWidget,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: _getRoleColor(role),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        role[0].toUpperCase() + role.substring(1),
                        style: TextStyle(color: _getRoleColor(role), fontWeight: FontWeight.w500, fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      FutureBuilder<QuerySnapshot>(
                        future: FirebaseFirestore.instance.collection('ratings').where('userId', isEqualTo: staffId).get(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return Text('Loading rating...', style: TextStyle(color: Colors.grey[400], fontSize: 13));
                          }
                          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                            return Text('No Ratings', style: TextStyle(color: Colors.grey[400], fontSize: 13));
                          }
                          final docs = snapshot.data!.docs;
                          double avg = 0;
                          int count = 0;
                          for (var doc in docs) {
                            final data = doc.data() as Map<String, dynamic>;
                            if (data['rating'] != null) {
                              avg += (data['rating'] as num).toDouble();
                              count++;
                            }
                          }
                          if (count == 0) {
                            return Text('No Ratings', style: TextStyle(color: Colors.grey[400], fontSize: 13));
                          }
                          avg /= count;
                          return Row(
                            children: [
                              Icon(Icons.star, color: Colors.amber, size: 16),
                              SizedBox(width: 4),
                              Text(avg.toStringAsFixed(1), style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 14)),
                              SizedBox(width: 4),
                              Text('($count)', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            statusWidget,
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.email, size: 16, color: Colors.grey[400]),
                const SizedBox(width: 8),
                Text(
                  email,
                  style: TextStyle(color: Colors.grey[300]),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.phone, size: 16, color: Colors.grey[400]),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () async {
                    final Uri telUri = Uri(scheme: 'tel', path: phone);
                    if (await canLaunchUrl(telUri)) {
                      await launchUrl(telUri);
                    }
                  },
                  child: Text(
                    phone,
                    style: TextStyle(color: Colors.blueAccent, decoration: TextDecoration.underline, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'floor_manager':
        return Colors.red;
      case 'consultant':
        return Colors.blue;
      case 'concierge':
        return Colors.green;
      case 'cleaner':
        return Colors.orange;
      case 'marketing_agent':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}

class StaffStatusWidget extends StatelessWidget {
  final String staffId;
  const StaffStatusWidget({required this.staffId, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('attendance')
          .doc(staffId)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return _statusText('Did not clock in', Colors.grey);
        }
        final data = snapshot.data!.data() as Map<String, dynamic>;
        final isClockedIn = data['isClockedIn'] == true;
        final clockInTime = (data['clockInTime'] as Timestamp?)?.toDate();
        final isOnBreak = data['isOnBreak'] == true;
        final breakReason = data['breakReason'] as String? ?? 'Break';
        final breakStart = (data['breakStartTime'] as Timestamp?)?.toDate();
        List<Widget> statusLines = [];
        if (isClockedIn && clockInTime != null) {
          statusLines.add(_statusText(
            'Clocked in at ' + TimeOfDay.fromDateTime(clockInTime).format(context),
            Colors.green,
          ));
        }
        if (isOnBreak && breakStart != null) {
          statusLines.add(_statusText(
            'On break ($breakReason) since ' + TimeOfDay.fromDateTime(breakStart).format(context),
            Colors.orange,
          ));
        }
        if (statusLines.isEmpty) {
          statusLines.add(_statusText('Did not clock in', Colors.grey));
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: statusLines,
        );
      },
    );
  }

  Widget _statusText(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 4.0, bottom: 2.0),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }
}
