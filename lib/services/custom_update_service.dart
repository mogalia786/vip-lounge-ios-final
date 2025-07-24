import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';

class CustomUpdateService {
  static const String updateServerUrl = 'https://your-server.com/api/app-version';
  static const String apkDownloadUrl = 'https://your-server.com/downloads/vip-lounge-latest.apk';
  
  static Future<void> checkForUpdates(BuildContext context) async {
    try {
      // Get current app version
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final currentBuildNumber = int.parse(packageInfo.buildNumber);
      
      // Check server for latest version
      final response = await http.get(Uri.parse(updateServerUrl));
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> serverData = json.decode(response.body);
        final latestVersion = serverData['version'] as String;
        final latestBuildNumber = serverData['buildNumber'] as int;
        final downloadUrl = serverData['downloadUrl'] as String;
        final isForceUpdate = serverData['forceUpdate'] as bool? ?? false;
        final updateMessage = serverData['message'] as String? ?? 'A new version is available';
        
        // Compare versions
        if (latestBuildNumber > currentBuildNumber) {
          _showUpdateDialog(
            context,
            currentVersion: currentVersion,
            latestVersion: latestVersion,
            downloadUrl: downloadUrl,
            isForceUpdate: isForceUpdate,
            message: updateMessage,
          );
        }
      }
    } catch (e) {
      debugPrint('Error checking for updates: $e');
    }
  }
  
  static void _showUpdateDialog(
    BuildContext context, {
    required String currentVersion,
    required String latestVersion,
    required String downloadUrl,
    required bool isForceUpdate,
    required String message,
  }) {
    showDialog(
      context: context,
      barrierDismissible: !isForceUpdate,
      builder: (context) => WillPopScope(
        onWillPop: () async => !isForceUpdate,
        child: AlertDialog(
          title: Text(isForceUpdate ? 'Required Update' : 'Update Available'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              const SizedBox(height: 16),
              Text('Current Version: $currentVersion'),
              Text('Latest Version: $latestVersion'),
              if (isForceUpdate) ...[
                const SizedBox(height: 16),
                const Text(
                  'This update is required to continue using the app.',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            if (!isForceUpdate)
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Later'),
              ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _downloadAndInstallUpdate(context, downloadUrl);
              },
              child: const Text('Update Now'),
            ),
          ],
        ),
      ),
    );
  }
  
  static Future<void> _downloadAndInstallUpdate(BuildContext context, String downloadUrl) async {
    try {
      // Show download progress dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Downloading update...'),
            ],
          ),
        ),
      );
      
      // For Android, you can implement APK download and install
      if (Platform.isAndroid) {
        // Launch browser to download APK
        final Uri url = Uri.parse(downloadUrl);
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        }
      }
      
      Navigator.of(context).pop(); // Close download dialog
      
    } catch (e) {
      Navigator.of(context).pop(); // Close download dialog
      debugPrint('Error downloading update: $e');
      
      // Show error dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Update Error'),
          content: const Text('Failed to download update. Please try again later.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }
  
  // Initialize update checking in your main app
  static Future<void> initialize(BuildContext context) async {
    // Check for updates on app start
    await Future.delayed(const Duration(seconds: 2)); // Wait for app to load
    await checkForUpdates(context);
  }
}

// Server-side API response example (JSON):
/*
{
  "version": "2.1.0",
  "buildNumber": 15,
  "downloadUrl": "https://your-server.com/downloads/vip-lounge-v2.1.0.apk",
  "forceUpdate": false,
  "message": "New features: Enhanced attendance tracking and improved feedback system",
  "releaseNotes": [
    "Fixed staff attendance calculations",
    "Added corrupted timestamp detection",
    "Enhanced feedback management",
    "Improved ratings display"
  ]
}
*/
