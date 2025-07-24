import 'package:in_app_update/in_app_update.dart';
import 'package:flutter/material.dart';

class AppUpdateService {
  static Future<void> checkForUpdate(BuildContext context) async {
    try {
      // Check if update is available
      final AppUpdateInfo updateInfo = await InAppUpdate.checkForUpdate();
      
      if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
        // Show update dialog
        _showUpdateDialog(context, updateInfo);
      }
    } catch (e) {
      debugPrint('Error checking for updates: $e');
    }
  }
  
  static void _showUpdateDialog(BuildContext context, AppUpdateInfo updateInfo) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Update Available'),
        content: const Text('A new version of VIP Lounge is available. Would you like to update now?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _performUpdate(updateInfo);
            },
            child: const Text('Update Now'),
          ),
        ],
      ),
    );
  }
  
  static Future<void> _performUpdate(AppUpdateInfo updateInfo) async {
    try {
      if (updateInfo.immediateUpdateAllowed) {
        // Immediate update - app restarts after update
        await InAppUpdate.performImmediateUpdate();
      } else if (updateInfo.flexibleUpdateAllowed) {
        // Flexible update - user can continue using app while downloading
        await InAppUpdate.startFlexibleUpdate();
      }
    } catch (e) {
      debugPrint('Error performing update: $e');
    }
  }
  
  // Call this in your main app widget
  static Future<void> initializeUpdateCheck(BuildContext context) async {
    // Check for updates on app start
    await checkForUpdate(context);
    
    // Set up periodic checks (optional)
    // Timer.periodic(const Duration(hours: 24), (_) => checkForUpdate(context));
  }
}
