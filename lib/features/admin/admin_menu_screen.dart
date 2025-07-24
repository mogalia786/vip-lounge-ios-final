import 'package:flutter/material.dart';
import '../../admin/version_manager.dart';
import '../../core/constants/app_colors.dart';

class AdminMenuScreen extends StatelessWidget {
  const AdminMenuScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Version Manager Card
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.system_update,
                color: Colors.blue,
                size: 32,
              ),
              title: const Text(
                'Version Manager',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: const Text('Upload and manage app versions'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const VersionManagerScreen(),
                  ),
                );
              },
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Other admin functions can go here
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.settings,
                color: Colors.grey,
                size: 32,
              ),
              title: const Text(
                'App Settings',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: const Text('Configure app settings'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                // Navigate to app settings
              },
            ),
          ),
          
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.analytics,
                color: Colors.green,
                size: 32,
              ),
              title: const Text(
                'Analytics',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: const Text('View app usage statistics'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                // Navigate to analytics
              },
            ),
          ),
        ],
      ),
    );
  }
}
