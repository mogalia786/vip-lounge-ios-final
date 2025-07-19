import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class DashboardMockup extends StatelessWidget {
  const DashboardMockup({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21), // Dark blue background
      appBar: AppBar(
        title: const Text('VIP Lounge Dashboard'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // First Row - Main Actions
            Row(
              children: [
                _buildDashboardBox(
                  icon: Icons.calendar_today,
                  label: 'Appointments',
                  color: Colors.red,
                ),
                const SizedBox(width: 16),
                _buildDashboardBox(
                  icon: Icons.people,
                  label: 'Staff',
                  color: Colors.red,
                ),
                const SizedBox(width: 16),
                _buildDashboardBox(
                  icon: Icons.notifications,
                  label: 'Notifications',
                  color: Colors.red,
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Second Row - Management
            Row(
              children: [
                _buildDashboardBox(
                  icon: Icons.assignment,
                  label: 'Queries',
                  color: Colors.red,
                ),
                const SizedBox(width: 16),
                _buildDashboardBox(
                  icon: Icons.analytics,
                  label: 'Analytics',
                  color: Colors.red,
                ),
                const SizedBox(width: 16),
                _buildDashboardBox(
                  icon: Icons.settings,
                  label: 'Settings',
                  color: Colors.red,
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Third Row - Additional Features
            Row(
              children: [
                _buildDashboardBox(
                  icon: Icons.chat,
                  label: 'Chat',
                  color: Colors.red,
                ),
                const SizedBox(width: 16),
                _buildDashboardBox(
                  icon: Icons.history,
                  label: 'History',
                  color: Colors.red,
                ),
                const SizedBox(width: 16),
                _buildDashboardBox(
                  icon: Icons.help_outline,
                  label: 'Help',
                  color: Colors.red,
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Fourth Row - Additional Features
            Row(
              children: [
                _buildDashboardBox(
                  icon: Icons.assessment,
                  label: 'Reports',
                  color: Colors.red,
                ),
                const SizedBox(width: 16),
                _buildDashboardBox(
                  icon: Icons.person_add,
                  label: 'Add Staff',
                  color: Colors.red,
                ),
                const SizedBox(width: 16),
                _buildDashboardBox(
                  icon: Icons.calendar_view_day,
                  label: 'Schedule',
                  color: Colors.red,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardBox({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: const Color(0xFF0A0E21),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              // Add navigation or action here
            },
            borderRadius: BorderRadius.circular(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 36,
                  color: color,
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
