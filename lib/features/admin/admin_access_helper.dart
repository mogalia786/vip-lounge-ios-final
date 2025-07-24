import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_menu_screen.dart';

class AdminAccessHelper {
  // Check if current user is admin
  static Future<bool> isAdmin(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final role = userData['role']?.toString().toLowerCase() ?? '';
        
        // Check for admin roles
        return role == 'admin' || 
               role == 'superadmin' || 
               role == 'floormanager' ||
               role == 'operationalmanager';
      }
      
      return false;
    } catch (e) {
      debugPrint('Error checking admin status: $e');
      return false;
    }
  }
  
  // Show admin access dialog
  static void showAdminAccessDialog(BuildContext context, String userId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.admin_panel_settings, color: Colors.blue),
            SizedBox(width: 8),
            Text('Admin Access'),
          ],
        ),
        content: const Text('Access admin panel to manage app versions and settings.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              
              // Check if user is admin
              final isAdminUser = await isAdmin(userId);
              
              if (isAdminUser) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AdminMenuScreen(),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Access denied: Admin privileges required'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Access'),
          ),
        ],
      ),
    );
  }
  
  // Add admin button to any screen (for testing)
  static Widget buildAdminButton(BuildContext context, String userId) {
    return FloatingActionButton(
      onPressed: () => showAdminAccessDialog(context, userId),
      backgroundColor: Colors.blue[800],
      child: const Icon(Icons.admin_panel_settings),
    );
  }
  
  // Hidden gesture detector (tap 5 times on logo/title)
  static Widget buildHiddenAdminAccess({
    required BuildContext context,
    required String userId,
    required Widget child,
  }) {
    int tapCount = 0;
    
    return GestureDetector(
      onTap: () {
        tapCount++;
        if (tapCount >= 5) {
          tapCount = 0;
          showAdminAccessDialog(context, userId);
        }
      },
      child: child,
    );
  }
}
