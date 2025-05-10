import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class MarketingAgentClockInOutWidget extends StatelessWidget {
  final String agentId;
  final bool isClockedIn;
  final Function() onClockIn;
  final Function() onClockOut;
  final String? address;

  const MarketingAgentClockInOutWidget({
    Key? key,
    required this.agentId,
    required this.isClockedIn,
    required this.onClockIn,
    required this.onClockOut,
    this.address,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      color: Colors.black,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.amber[700]!, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Attendance',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.amber[700],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildStatusIndicator(),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isClockedIn ? 'Clocked In' : 'Not Clocked In',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: isClockedIn ? Colors.green : Colors.red,
                      ),
                    ),
                    if (address != null && isClockedIn)
                      Text(
                        'At: $address',
                        style: const TextStyle(fontSize: 14, color: Colors.white70),
                      ),
                    FutureBuilder<QuerySnapshot>(
                      future: _getLatestAttendanceRecord(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Text(
                            'Loading last activity...',
                            style: TextStyle(fontSize: 14, color: Colors.white70),
                          );
                        }
                        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return const Text(
                            'No recent activity',
                            style: TextStyle(fontSize: 14, color: Colors.white70),
                          );
                        }
                        final doc = snapshot.data!.docs.first;
                        final data = doc.data() as Map<String, dynamic>;
                        final timestamp = (data['timestamp'] as Timestamp).toDate();
                        final action = data['action'] as String;
                        return Text(
                          'Last $action: ${DateFormat('MMM d, h:mm a').format(timestamp)}',
                          style: const TextStyle(fontSize: 14, color: Colors.white70),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  label: 'Clock In',
                  icon: Icons.login,
                  onPressed: isClockedIn ? null : onClockIn,
                  color: Colors.green,
                ),
                _buildActionButton(
                  label: 'Clock Out',
                  icon: Icons.logout,
                  onPressed: isClockedIn ? onClockOut : null,
                  color: Colors.red,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator() {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isClockedIn ? Colors.green : Colors.red,
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    required Color color,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: onPressed == null ? Colors.grey : color,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.grey[700],
        disabledForegroundColor: Colors.white70,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
    );
  }

  Future<QuerySnapshot> _getLatestAttendanceRecord() {
    return FirebaseFirestore.instance
        .collection('attendance')
        .where('userId', isEqualTo: agentId)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();
  }
}
