import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../utils/custom_file_opener.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;

class FirebaseUpdateService {
  static const String versionCollection = 'app_versions';
  static const String currentVersionDoc = 'current';
  
  static Future<void> checkForUpdates(BuildContext context) async {
    try {
      // Get current app version
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final currentBuildNumber = int.parse(packageInfo.buildNumber);
      
      debugPrint('🔍 Current app version: $currentVersion+$currentBuildNumber');
      
      // Get latest version from Firestore
      final DocumentSnapshot versionDoc = await FirebaseFirestore.instance
          .collection(versionCollection)
          .doc(currentVersionDoc)
          .get();
      
      if (!versionDoc.exists) {
        debugPrint('⚠️ No version document found in Firestore');
        return;
      }
      
      final Map<String, dynamic> versionData = versionDoc.data() as Map<String, dynamic>;
      
      final latestVersion = versionData['version'] as String;
      final latestBuildNumber = versionData['buildNumber'] as int;
      final apkFileName = versionData['apkFileName'] as String;
      final isForceUpdate = versionData['forceUpdate'] as bool? ?? false;
      final updateMessage = versionData['message'] as String? ?? 'A new version is available';
      final releaseNotes = List<String>.from(versionData['releaseNotes'] ?? []);
      
      debugPrint('📱 Latest version: $latestVersion+$latestBuildNumber');
      debugPrint('📦 APK file: $apkFileName');
      
      // Compare versions
      if (latestBuildNumber > currentBuildNumber) {
        debugPrint('🆕 Update available!');
        _showUpdateDialog(
          context,
          currentVersion: currentVersion,
          latestVersion: latestVersion,
          apkFileName: apkFileName,
          isForceUpdate: isForceUpdate,
          message: updateMessage,
          releaseNotes: releaseNotes,
        );
      } else {
        debugPrint('✅ App is up to date');
      }
      
    } catch (e) {
      debugPrint('❌ Error checking for updates: $e');
    }
  }
  
  static void _showUpdateDialog(
    BuildContext context, {
    required String currentVersion,
    required String latestVersion,
    required String apkFileName,
    required bool isForceUpdate,
    required String message,
    required List<String> releaseNotes,
  }) {
    showDialog(
      context: context,
      barrierDismissible: !isForceUpdate,
      builder: (context) => WillPopScope(
        onWillPop: () async => !isForceUpdate,
        child: AlertDialog(
          title: Row(
            children: [
              Icon(
                isForceUpdate ? Icons.warning : Icons.system_update,
                color: isForceUpdate ? Colors.red : Colors.blue,
              ),
              const SizedBox(width: 8),
              Text(isForceUpdate ? 'Required Update' : 'Update Available'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Current Version: $currentVersion'),
                      Text('Latest Version: $latestVersion'),
                    ],
                  ),
                ),
                if (releaseNotes.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    "What's New:",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...releaseNotes.map((note) => Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• '),
                        Expanded(child: Text(note)),
                      ],
                    ),
                  )),
                ],
                if (isForceUpdate) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info, color: Colors.red, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'This update is required to continue using the app.',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
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
                await _downloadAndInstallUpdate(context, apkFileName);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isForceUpdate ? Colors.red : null,
              ),
              child: const Text('Update Now'),
            ),
          ],
        ),
      ),
    );
  }
  
  static Future<void> _downloadAndInstallUpdate(BuildContext context, String apkFileName) async {
    try {
      // Request storage permission
      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          _showErrorDialog(context, 'Storage permission is required to download updates.');
          return;
        }
      }
      
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
              SizedBox(height: 8),
              Text(
                'Please wait while we download the latest version.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
      
      // Get download URL from Firebase Storage
      final Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('app_updates')
          .child(apkFileName);
      
      final String downloadUrl = await storageRef.getDownloadURL();
      debugPrint('📥 Download URL: $downloadUrl');
      
      // Download the APK
      final response = await http.get(Uri.parse(downloadUrl));
      
      if (response.statusCode == 200) {
        // Get downloads directory
        final Directory? downloadsDir = await getExternalStorageDirectory();
        if (downloadsDir == null) {
          throw Exception('Could not access downloads directory');
        }
        
        // Create app updates folder
        final Directory appUpdatesDir = Directory('${downloadsDir.path}/VIPLounge_Updates');
        if (!await appUpdatesDir.exists()) {
          await appUpdatesDir.create(recursive: true);
        }
        
        // Save APK file
        final File apkFile = File('${appUpdatesDir.path}/$apkFileName');
        await apkFile.writeAsBytes(response.bodyBytes);
        
        debugPrint('✅ APK downloaded to: ${apkFile.path}');
        
        Navigator.of(context).pop(); // Close download dialog
        
        // Show install dialog
        _showInstallDialog(context, apkFile.path);
        
      } else {
        throw Exception('Failed to download APK: ${response.statusCode}');
      }
      
    } catch (e) {
      Navigator.of(context).pop(); // Close download dialog
      debugPrint('❌ Error downloading update: $e');
      _showErrorDialog(context, 'Failed to download update: $e');
    }
  }
  
  static void _showInstallDialog(BuildContext context, String apkPath) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.install_mobile, color: Colors.green),
            SizedBox(width: 8),
            Text('Ready to Install'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('The update has been downloaded successfully.'),
            SizedBox(height: 16),
            Text(
              'Tap "Install" to install the update. You may need to enable "Install from unknown sources" in your device settings.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _installApk(apkPath);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Install'),
          ),
        ],
      ),
    );
  }
  
  static Future<void> _installApk(String apkPath) async {
    try {
      final success = await CustomFileOpener.openFile(apkPath);
      debugPrint('📱 Install open success: $success');
    } catch (e) {
      debugPrint('❌ Error installing APK: $e');
    }
  }
  
  static void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 8),
            Text('Update Error'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
  
  // Initialize update checking in your main app
  static Future<void> initialize(BuildContext context) async {
    try {
      // Wait for app to fully load
      await Future.delayed(const Duration(seconds: 3));
      
      // Check for updates
      await checkForUpdates(context);
      
      debugPrint('✅ Firebase update service initialized');
    } catch (e) {
      debugPrint('❌ Error initializing Firebase update service: $e');
    }
  }
  
  // Method to upload new APK (for admin use)
  static Future<void> uploadNewVersion({
    required String version,
    required int buildNumber,
    required String apkFilePath,
    required String message,
    required List<String> releaseNotes,
    bool forceUpdate = false,
  }) async {
    try {
      final File apkFile = File(apkFilePath);
      if (!await apkFile.exists()) {
        throw Exception('APK file not found: $apkFilePath');
      }
      
      final String apkFileName = 'vip-lounge-v$version-build$buildNumber.apk';
      
      // Upload APK to Firebase Storage
      final Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('app_updates')
          .child(apkFileName);
      
      final UploadTask uploadTask = storageRef.putFile(apkFile);
      await uploadTask;
      
      // Update version info in Firestore
      await FirebaseFirestore.instance
          .collection(versionCollection)
          .doc(currentVersionDoc)
          .set({
        'version': version,
        'buildNumber': buildNumber,
        'apkFileName': apkFileName,
        'forceUpdate': forceUpdate,
        'message': message,
        'releaseNotes': releaseNotes,
        'uploadedAt': FieldValue.serverTimestamp(),
        'uploadedBy': 'admin', // You can get this from Firebase Auth
      });
      
      debugPrint('✅ New version uploaded successfully: $version+$buildNumber');
      
    } catch (e) {
      debugPrint('❌ Error uploading new version: $e');
      rethrow;
    }
  }
}
