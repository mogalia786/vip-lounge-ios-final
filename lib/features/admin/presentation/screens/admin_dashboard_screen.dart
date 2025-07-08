import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/providers/app_auth_provider.dart';
import '../../../../features/floor_manager/presentation/screens/floor_manager_home_screen_new.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AppAuthProvider>(context).appUser;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Colors.black,
      ),
      body: GridView.count(
        padding: const EdgeInsets.all(16.0),
        crossAxisCount: 2,
        crossAxisSpacing: 16.0,
        mainAxisSpacing: 16.0,
        children: [
          _buildDashboardCard(
            context: context,
            icon: Icons.location_on,
            title: 'Pickup Locations',
            color: Colors.blue,
            onTap: () => Navigator.pushNamed(context, '/pickup-locations'),
          ),
          _buildDashboardCard(
            context: context,
            icon: Icons.people,
            title: 'Client Types',
            color: Colors.green,
            onTap: () => Navigator.pushNamed(context, '/client-types'),
          ),
          _buildDashboardCard(
            context: context,
            icon: Icons.assignment_ind,
            title: 'User Management',
            color: Colors.orange,
            onTap: () {
              // TODO: Navigate to User Management
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('User Management coming soon')),
              );
            },
          ),
          _buildDashboardCard(
            context: context,
            icon: Icons.analytics,
            title: 'Analytics',
            color: Colors.purple,
            onTap: () {
              // TODO: Navigate to Analytics
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Analytics coming soon')),
              );
            },
          ),
          if (user?.role == 'floor_manager')
            _buildDashboardCard(
              context: context,
              icon: Icons.dashboard,
              title: 'Floor Manager',
              color: Colors.red,
              onTap: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => const FloorManagerHomeScreenNew(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDashboardCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 48.0,
              color: color,
            ),
            const SizedBox(height: 16.0),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18.0,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
